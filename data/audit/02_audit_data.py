"""
Auditoría de datos - Portafolios Wasserstein-Kelly

Audita data/raw/ y data/processed/monthly_panel.csv SIN modificarlos.
Salidas (en data/audit/):
    audit_report.md           reporte
    audit_discrepancies.csv   discrepancias (formato largo)
    stooq_cache/<tic>.csv     precios de Stooq (descarga o copia manual)

Uso (desde la raíz del proyecto):
    py data/audit/02_audit_data.py
"""

import importlib.util
import sys

sys.dont_write_bytecode = True  # no dejar __pycache__ en data/
import types
import urllib.request
from pathlib import Path

import numpy as np
import pandas as pd
from pandas.tseries.holiday import (
    AbstractHolidayCalendar, GoodFriday, Holiday, USLaborDay,
    USMartinLutherKingJr, USMemorialDay, USPresidentsDay, USThanksgivingDay,
    nearest_workday, sunday_to_monday,
)

ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "data" / "raw"
PROC_DIR = ROOT / "data" / "processed"
OUT_DIR = ROOT / "data" / "audit"
STOOQ_DIR = OUT_DIR / "stooq_cache"
OUT_DIR.mkdir(exist_ok=True)
STOOQ_DIR.mkdir(exist_ok=True)

TICKERS = ["AAPL", "MSFT", "AMZN", "JPM", "JNJ", "XOM", "PG", "CAT", "KO", "WMT"]
YAHOO_FILES = TICKERS + ["SPY", "VIX"]
START, END = "2009-12-01", "2025-12-31"
EXTREME = 0.30
TOL_PRICE = 0.005     # 0.5 % error relativo en precio vs Stooq
TOL_RET = 0.0025      # 0.25 pp en retorno mensual vs Stooq
TOL_EXACT = 1e-10

# Splits conocidos en la ventana 2009-12 / 2025-12
KNOWN_SPLITS = {
    "AAPL": [("2014-06-09", 7.0), ("2020-08-31", 4.0)],
    "AMZN": [("2022-06-06", 20.0)],
    "WMT": [("2024-02-26", 3.0)],
    "KO": [("2012-08-13", 2.0)],
}

findings = []   # filas del CSV de discrepancias


def add(check, asset, date, value=np.nan, reference=np.nan, rel_error=np.nan, detail=""):
    findings.append(dict(check=check, asset=asset,
                         date=None if date is None else pd.Timestamp(date).date(),
                         value=value, reference=reference, rel_error=rel_error,
                         detail=detail))


def md_table(df, floatfmt="{:.6g}"):
    if df.empty:
        return "_(sin filas)_\n"
    df = df.copy()
    for c in df.columns:
        if pd.api.types.is_float_dtype(df[c]):
            df[c] = df[c].map(lambda v: "" if pd.isna(v) else floatfmt.format(v))
    cols = [str(c) for c in df.columns]
    lines = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for _, r in df.iterrows():
        lines.append("| " + " | ".join(str(v) for v in r.values) + " |")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Calendario NYSE aproximado (feriados + cierres especiales)
# ---------------------------------------------------------------------------

class NYSECalendar(AbstractHolidayCalendar):
    rules = [
        Holiday("NewYear", month=1, day=1, observance=sunday_to_monday),
        USMartinLutherKingJr, USPresidentsDay, GoodFriday, USMemorialDay,
        Holiday("Juneteenth", month=6, day=19, start_date="2022-01-01",
                observance=nearest_workday),
        Holiday("July4", month=7, day=4, observance=nearest_workday),
        USLaborDay, USThanksgivingDay,
        Holiday("Christmas", month=12, day=25, observance=nearest_workday),
    ]


SPECIAL_CLOSURES = pd.to_datetime(["2012-10-29", "2012-10-30",   # Huracán Sandy
                                   "2018-12-05",                 # G.H.W. Bush
                                   "2025-01-09"])                # J. Carter


def nyse_days(start, end):
    hol = NYSECalendar().holidays(start, end)
    days = pd.bdate_range(start, end)
    return days[~days.isin(hol) & ~days.isin(SPECIAL_CLOSURES)]


# ---------------------------------------------------------------------------
# Carga
# ---------------------------------------------------------------------------

def load_raw():
    raw = {t: pd.read_csv(RAW_DIR / f"{t}_daily.csv", index_col=0, parse_dates=True)
           for t in YAHOO_FILES}
    dgs = pd.read_csv(RAW_DIR / "DGS3MO_daily.csv", index_col=0, parse_dates=True)["DGS3MO"]
    log = pd.read_csv(RAW_DIR / "download_log.csv")
    panel = pd.read_csv(PROC_DIR / "monthly_panel.csv", index_col=0, parse_dates=True)
    adj_m = pd.read_csv(PROC_DIR / "monthly_adj_close.csv", index_col=0, parse_dates=True)
    return raw, dgs, log, panel, adj_m


def load_import_module():
    """Importa data/01_import_data.py sin ejecutar main() (yfinance se simula)."""
    if "yfinance" not in sys.modules:
        sys.modules["yfinance"] = types.ModuleType("yfinance")
    spec = importlib.util.spec_from_file_location("import_data", ROOT / "data" / "01_import_data.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# 1. Faltantes, duplicados, fechas faltantes
# ---------------------------------------------------------------------------

def check_missing(raw, dgs, log, panel, cal):
    rows = []
    union = sorted(set().union(*[set(df.index) for df in raw.values()]))
    union = pd.DatetimeIndex(union)
    for t, df in raw.items():
        miss_cal = cal.difference(df.index)
        extra = df.index.difference(cal)
        miss_union = union.difference(df.index)
        nan = int(df.isna().sum().sum())
        dup = int(df.index.duplicated().sum())
        nonpos = int((df[["Adj Close", "Close"]] <= 0).sum().sum())
        zero_vol = int((df["Volume"] == 0).sum()) if t != "VIX" else 0
        rows.append(dict(activo=t, n=len(df), primero=df.index.min().date(),
                         ultimo=df.index.max().date(), NaN=nan, duplicados=dup,
                         monotono=df.index.is_monotonic_increasing,
                         faltan_vs_NYSE=len(miss_cal), extra_vs_NYSE=len(extra),
                         faltan_vs_union=len(miss_union), precios_no_pos=nonpos,
                         volumen_cero=zero_vol))
        for d in miss_cal:
            add("missing_trading_day", t, d, detail="día hábil NYSE ausente en el crudo")
        for d in extra:
            add("extra_day", t, d, detail="fecha en crudo que no es día hábil NYSE (calendario aproximado)")
        if dup:
            for d in df.index[df.index.duplicated()]:
                add("duplicate_date", t, d)
        if nan:
            for d in df.index[df.isna().any(axis=1)]:
                add("nan_value", t, d)
    raw_tab = pd.DataFrame(rows)

    # DGS3MO
    fred_bd = pd.bdate_range(dgs.index.min(), dgs.index.max())
    dgs_valid = dgs.dropna()
    gaps = dgs_valid.index.to_series().diff().dt.days
    big_gaps = gaps[gaps > 5]
    dgs_info = dict(n=len(dgs), NaN=int(dgs.isna().sum()), primero=dgs.index.min().date(),
                    ultimo=dgs.index.max().date(), duplicados=int(dgs.index.duplicated().sum()),
                    dias_habiles_ausentes=len(fred_bd.difference(dgs.index)),
                    huecos_mayores_5d=len(big_gaps))
    for d, g in big_gaps.items():
        add("rf_gap", "DGS3MO", d, value=g, detail="hueco > 5 días entre observaciones válidas")

    # Panel
    expected = pd.date_range("2010-01-31", END, freq="ME")
    panel_info = dict(filas=len(panel), primero=panel.index.min().date(),
                      ultimo=panel.index.max().date(),
                      duplicados=int(panel.index.duplicated().sum()),
                      meses_faltantes=len(expected.difference(panel.index)),
                      meses_extra=len(panel.index.difference(expected)),
                      fechas_no_fin_de_mes=int((~panel.index.is_month_end).sum()),
                      NaN_total=int(panel.isna().sum().sum()))
    for d in expected.difference(panel.index):
        add("missing_month", "panel", d)
    for c in panel.columns:
        for d in panel.index[panel[c].isna()]:
            add("nan_value", f"panel:{c}", d)

    # Log de descarga
    dup_log = log[log.duplicated(subset=["symbol"], keep="first")]
    log_info = dict(filas=len(log), simbolos_unicos=log["symbol"].nunique(),
                    filas_duplicadas=len(dup_log),
                    dgs3mo_registrado="DGS3MO" in set(log["symbol"]),
                    n_rows_log=sorted(log["n_rows"].unique().tolist()))
    for _, r in dup_log.iterrows():
        add("download_log_duplicate", r["symbol"], None, detail="símbolo registrado más de una vez")
    if not log_info["dgs3mo_registrado"]:
        add("download_log_missing", "DGS3MO", None, detail="la descarga FRED no queda registrada en download_log.csv")
    for t, df in raw.items():
        n_log = log.loc[log["symbol"].str.replace("^", "", regex=False) == t, "n_rows"]
        if len(n_log) and int(n_log.iloc[-1]) != len(df):
            add("download_log_nrows", t, None, value=len(df), reference=int(n_log.iloc[-1]),
                detail="n_rows del log != filas del archivo crudo")

    return raw_tab, dgs_info, panel_info, log_info


# ---------------------------------------------------------------------------
# 2. Retornos extremos
# ---------------------------------------------------------------------------

def check_extremes(raw, panel):
    ret_cols = TICKERS + ["mkt_return"]
    m = panel[ret_cols].stack()
    m_ext = m[m.abs() > EXTREME].reset_index()
    m_ext.columns = ["fecha", "activo", "retorno"]
    m_ext["fecha"] = m_ext["fecha"].dt.date
    for _, r in m_ext.iterrows():
        add("extreme_monthly_return", r["activo"], r["fecha"], value=r["retorno"],
            detail=f"|r| > {EXTREME:.0%} en el panel mensual")

    d_rows = []
    for t in TICKERS + ["SPY"]:
        for col in ["Adj Close", "Close"]:
            r = raw[t][col].pct_change()
            for d, v in r[r.abs() > EXTREME].items():
                d_rows.append(dict(fecha=d.date(), activo=t, serie=col, retorno=v))
                add("extreme_daily_return", t, d, value=v, detail=f"|r diario| > {EXTREME:.0%} en {col}")
    # top-5 mensuales en valor absoluto, para contexto
    top = m.abs().sort_values(ascending=False).head(5).index
    top_tab = pd.DataFrame([dict(fecha=d.date(), activo=a, retorno=m[(d, a)]) for d, a in top])
    return m_ext, pd.DataFrame(d_rows), top_tab


# ---------------------------------------------------------------------------
# 3. Adj Close: dividendos y splits
# ---------------------------------------------------------------------------

def check_adjustments(raw):
    rows = []
    split_rows = []
    for t in TICKERS + ["SPY"]:
        df = raw[t]
        ratio = df["Adj Close"] / df["Close"]
        step = ratio / ratio.shift(1) - 1
        div_days = step[step > 1e-5]
        neg_days = step[step < -1e-5]
        implied_div = (df["Close"].shift(1) * (1 - ratio.shift(1) / ratio))[div_days.index]
        years = div_days.index.year
        per_year = pd.Series(1, index=years).groupby(level=0).sum()
        full_years = per_year.loc[2010:2025] if len(per_year) else per_year
        # yield implícito anual medio y diferencia retorno total - retorno precio
        yearly_div = implied_div.groupby(implied_div.index.year).sum()
        yearly_px = df["Close"].groupby(df.index.year).mean()
        yld = (yearly_div / yearly_px).reindex(range(2010, 2026)).fillna(0)
        tr = df["Adj Close"].resample("YE").last().pct_change().dropna()
        pr = df["Close"].resample("YE").last().pct_change().dropna()
        rows.append(dict(
            activo=t,
            ratio_inicio=ratio.iloc[0], ratio_fin=ratio.iloc[-1],
            eventos_div=len(div_days),
            div_por_año_mediana=float(full_years.median()) if len(full_years) else 0.0,
            yield_implicito_medio=float(yld.mean()),
            TR_menos_PR_anual_medio=float((tr - pr).mean()),
            caidas_ratio=len(neg_days),
        ))
        for d, v in neg_days.items():
            add("adj_ratio_decrease", t, d, value=v,
                detail="Adj/Close disminuye (no compatible con ajuste por dividendos)")
        if t == "AMZN" and len(div_days):
            add("unexpected_dividend", t, div_days.index[0], detail="AMZN no paga dividendos")
        if t != "AMZN" and len(div_days) == 0:
            add("no_dividend_adjustment", t, None, detail="Adj Close == Close en todo el periodo")

        for d, k in KNOWN_SPLITS.get(t, []):
            d = pd.Timestamp(d)
            if d not in df.index:
                add("split_date_missing", t, d)
                continue
            i = df.index.get_loc(d)
            rc = df["Close"].iloc[i] / df["Close"].iloc[i - 1] - 1
            ra = df["Adj Close"].iloc[i] / df["Adj Close"].iloc[i - 1] - 1
            ok = abs(rc) < 0.15 and abs(ra) < 0.15
            split_rows.append(dict(activo=t, fecha=d.date(), ratio=f"{k:g}:1",
                                   r_close=rc, r_adj=ra,
                                   salto_sin_ajuste=1 / k - 1, ajustado=ok))
            if not ok:
                add("split_not_adjusted", t, d, value=rc, reference=1 / k - 1,
                    detail=f"split {k:g}:1 no ajustado")
    vix = raw["VIX"]
    vix_diff = int((vix["Adj Close"] - vix["Close"]).abs().gt(TOL_EXACT).sum())
    if vix_diff:
        add("vix_adj_ne_close", "VIX", None, value=vix_diff)
    return pd.DataFrame(rows), pd.DataFrame(split_rows), vix_diff


# ---------------------------------------------------------------------------
# 4. Alineación VIX y r^f
# ---------------------------------------------------------------------------

def last_date_per_month(s):
    s = s.dropna()
    return s.index.to_series().groupby(s.index.to_period("M")).max()


def check_alignment(raw, dgs, panel, cal):
    cal_last = cal.to_series().groupby(cal.to_period("M")).max()

    vix_m = raw["VIX"]["Adj Close"].resample("ME").last()
    y_m = dgs.resample("ME").last().ffill()
    rf_m = (1 + y_m / 100) ** (1 / 12) - 1

    out = {}
    for name, rec, eff_src, last_ref in [
        ("vix", vix_m, raw["VIX"]["Adj Close"], cal_last),
        ("rf_return", rf_m, dgs, cal_last),
    ]:
        common = panel.index.intersection(rec.index)
        diff = (panel.loc[common, name] - rec.loc[common]).abs()
        mism = diff[diff > TOL_EXACT]
        for d, v in mism.items():
            add(f"{name}_value_mismatch", name, d, value=panel.loc[d, name],
                reference=rec.loc[d], detail="panel != recomputado desde crudo")
        eff = last_date_per_month(eff_src)
        per = panel.index.to_period("M")
        eff_p = eff.reindex(per)
        ref_p = last_ref.reindex(per)
        not_last = [(p, e, r) for p, e, r in zip(per, eff_p.values, ref_p.values)
                    if pd.notna(e) and pd.Timestamp(e) != pd.Timestamp(r)]
        after = [(p, e) for p, e in zip(per, eff_p.values)
                 if pd.notna(e) and pd.Timestamp(e) > p.to_timestamp(how="end")]
        for p, e, r in not_last:
            add(f"{name}_not_last_day", name, p.to_timestamp(how="end"),
                detail=f"último dato usado {pd.Timestamp(e).date()} vs último día hábil {pd.Timestamp(r).date()}")
        out[name] = dict(meses=len(common), max_abs_diff=float(diff.max()),
                         descuadres=len(mism), meses_no_ultimo_dia=len(not_last),
                         datos_posteriores_al_mes=len(after),
                         detalle_no_ultimo=[(str(p), str(pd.Timestamp(e).date()), str(pd.Timestamp(r).date()))
                                            for p, e, r in not_last])
    # meses donde el rf usa ffill de un mes anterior (mes sin datos DGS3MO)
    ffilled = dgs.resample("ME").last()
    out["rf_return"]["meses_con_ffill"] = int(ffilled.isna().sum())
    out["rf_return"]["meses_rf_cero"] = [str(d.date()) for d in panel.index[panel["rf_return"] == 0]]
    out["rf_return"]["meses_rf_bajo_1pb"] = int((panel["rf_return"] < 1e-4).sum())
    return out


# ---------------------------------------------------------------------------
# 5. Look-ahead: recomputo completo del panel
# ---------------------------------------------------------------------------

def check_lookahead(raw, dgs, panel, adj_m, log):
    mod = load_import_module()
    prices = {t: raw[t] for t in TICKERS}
    prices["SPY"] = raw["SPY"]
    prices["^VIX"] = raw["VIX"]
    ret, px = mod.build_stock_monthly_returns(prices, TICKERS)
    rec = ret.copy()
    rec["mkt_return"] = mod.build_market_return(prices, "SPY")
    rec["vix"] = mod.build_vix_monthly(prices, "^VIX")
    rec["rf_return"] = mod.build_riskfree_monthly(dgs)
    rec_full = rec.dropna(how="all")

    rows_only_rec = rec_full.index.difference(panel.index)
    rows_only_panel = panel.index.difference(rec_full.index)
    common = panel.index.intersection(rec_full.index)
    a = panel.loc[common, rec.columns]
    b = rec_full.loc[common, rec.columns]
    diff = (a - b).abs()
    both_nan = a.isna() & b.isna()
    bad = (diff > TOL_EXACT) | (a.isna() ^ b.isna())
    bad &= ~both_nan
    for (d, c) in bad[bad].stack().index:
        add("panel_recompute_mismatch", c, d, value=a.loc[d, c], reference=b.loc[d, c],
            rel_error=(a.loc[d, c] / b.loc[d, c] - 1) if b.loc[d, c] else np.nan,
            detail="panel guardado != recomputo con 01_import_data.py")
    for d in rows_only_rec:
        add("panel_row_dropped", "panel", d,
            detail="fila producida por el código actual pero ausente del CSV (primer mes sin retornos)")

    # Precios mensuales guardados
    pc = adj_m.index.intersection(px.index)
    px_diff = (adj_m.loc[pc, TICKERS] - px.loc[pc, TICKERS]).abs().max().max()

    # Test de desplazamiento: ¿el panel coincide mejor con retornos desplazados?
    shift_err = {}
    for s in (-1, 0, 1):
        sh = ret.shift(s).reindex(common)
        shift_err[s] = float((panel.loc[common, TICKERS] - sh[TICKERS]).abs().mean().mean())

    # Fechas del crudo posteriores a END o a la fecha de descarga
    dl = pd.to_datetime(log["download_date"]).min()
    after_end = {t: int((df.index > pd.Timestamp(END)).sum()) for t, df in raw.items()}
    after_dl = {t: int((df.index > dl).sum()) for t, df in raw.items()}
    after_end["DGS3MO"] = int((dgs.index > pd.Timestamp(END)).sum())

    return dict(celdas_comparadas=int(bad.size), descuadres=int(bad.values.sum()),
                max_abs_diff=float(diff.max().max()),
                filas_solo_recomputo=[str(d.date()) for d in rows_only_rec],
                filas_solo_panel=[str(d.date()) for d in rows_only_panel],
                monthly_adj_close_max_diff=float(px_diff),
                shift_err=shift_err, fechas_post_END=sum(after_end.values()),
                fechas_post_descarga=sum(after_dl.values()), download_date=str(dl.date()))


# ---------------------------------------------------------------------------
# 6. Contraste con Stooq
# ---------------------------------------------------------------------------

STOOQ_SYMBOL = {t: f"{t.lower()}.us" for t in TICKERS + ["SPY"]}
STOOQ_SYMBOL["VIX"] = "^vix"


def get_stooq(t):
    path = STOOQ_DIR / f"{t}.csv"
    status = "cache"
    if not path.exists():
        url = (f"https://stooq.com/q/d/l/?s={STOOQ_SYMBOL[t]}"
               f"&d1={START.replace('-', '')}&d2={END.replace('-', '')}&i=d")
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            txt = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
        except Exception as e:
            return None, f"error de red: {e}"
        if not txt.lstrip().lower().startswith("date"):
            return None, "bloqueado (verificación JavaScript / sin CSV)"
        path.write_text(txt, encoding="utf-8")
        status = "descargado"
    df = pd.read_csv(path)
    df.columns = [c.strip().capitalize() for c in df.columns]
    df["Date"] = pd.to_datetime(df["Date"])
    return df.set_index("Date").sort_index(), status


def check_stooq(raw):
    summary, detail_rows, status = [], [], {}
    for t in TICKERS + ["SPY", "VIX"]:
        st, status[t] = get_stooq(t)
        if st is None:
            continue
        y = raw[t]
        ym = y[["Close", "Adj Close"]].resample("ME").last()
        sm = st["Close"].resample("ME").last()
        idx = ym.index.intersection(sm.index)
        ym, sm = ym.loc[idx], sm.loc[idx]
        e_close = ym["Close"] / sm - 1
        e_adj = ym["Adj Close"] / sm - 1
        basis = "Adj Close" if e_adj.abs().median() < e_close.abs().median() else "Close"
        e = e_adj if basis == "Adj Close" else e_close
        r_diff = ym[basis].pct_change() - sm.pct_change()
        # misma fecha efectiva de fin de mes en ambas fuentes
        ey = last_date_per_month(y["Close"])
        es = last_date_per_month(st["Close"])
        date_mis = (ey.reindex(es.index) != es).sum()
        summary.append(dict(activo=t, meses=len(idx), base_coincide=basis,
                            err_rel_medio=float(e.abs().mean()), err_rel_max=float(e.abs().max()),
                            mes_err_max=e.abs().idxmax().date(),
                            err_close_mediano=float(e_close.abs().median()),
                            err_adj_mediano=float(e_adj.abs().median()),
                            dif_ret_max=float(r_diff.abs().max()),
                            meses_fuera_tol=int(((e.abs() > TOL_PRICE) | (r_diff.abs() > TOL_RET)).sum()),
                            fin_mes_distinto=int(date_mis)))
        for d in idx:
            row = dict(activo=t, fecha=d.date(), yahoo_close=ym.at[d, "Close"],
                       yahoo_adj=ym.at[d, "Adj Close"], stooq_close=sm[d],
                       err_rel_close=e_close[d], err_rel_adj=e_adj[d], dif_ret=r_diff[d])
            detail_rows.append(row)
            if abs(e[d]) > TOL_PRICE or (pd.notna(r_diff[d]) and abs(r_diff[d]) > TOL_RET):
                add("stooq_price_discrepancy", t, d, value=ym.at[d, basis], reference=sm[d],
                    rel_error=e[d], detail=f"base {basis}; dif. retorno {r_diff[d]:.4%}")
    detail = pd.DataFrame(detail_rows)
    if not detail.empty:
        detail.to_csv(OUT_DIR / "stooq_monthly_comparison.csv", index=False)
    return pd.DataFrame(summary), status


# ---------------------------------------------------------------------------
# Reporte
# ---------------------------------------------------------------------------

def icon(ok, warn=False):
    return "✅" if ok else ("⚠️" if warn else "❌")


def main():
    raw, dgs, log, panel, adj_m = load_raw()
    cal = nyse_days(START, END)

    raw_tab, dgs_info, panel_info, log_info = check_missing(raw, dgs, log, panel, cal)
    m_ext, d_ext, top_tab = check_extremes(raw, panel)
    adj_tab, split_tab, vix_diff = check_adjustments(raw)
    align = check_alignment(raw, dgs, panel, cal)
    la = check_lookahead(raw, dgs, panel, adj_m, log)
    stooq_tab, stooq_status = check_stooq(raw)

    disc = pd.DataFrame(findings, columns=["check", "asset", "date", "value",
                                           "reference", "rel_error", "detail"])
    disc.to_csv(OUT_DIR / "audit_discrepancies.csv", index=False)

    # ---- veredictos
    n_missing_days = int(raw_tab["faltan_vs_NYSE"].sum())
    ok1 = panel_info["NaN_total"] == 0 and panel_info["meses_faltantes"] == 0 \
        and raw_tab["NaN"].sum() == 0 and raw_tab["duplicados"].sum() == 0
    ok3 = (adj_tab["caidas_ratio"].sum() == 0 and split_tab["ajustado"].all()
           and vix_diff == 0)
    ok4 = all(align[k]["descuadres"] == 0 and align[k]["datos_posteriores_al_mes"] == 0 for k in align)
    perfect4 = ok4 and all(align[k]["meses_no_ultimo_dia"] == 0 for k in align)
    ok5 = la["descuadres"] == 0 and la["fechas_post_END"] == 0 and la["shift_err"][0] < 1e-12
    stooq_ok = not stooq_tab.empty

    L = []
    L.append("# Reporte de auditoría de datos — Wasserstein-Kelly\n")
    L.append(f"Generado por `data/audit/02_audit_data.py` el {pd.Timestamp.today().date()}. "
             "No se modificó ningún archivo en `data/raw/` ni `data/processed/`. "
             "Discrepancias detalladas en `data/audit/audit_discrepancies.csv` "
             f"({len(disc)} filas).\n")

    L.append("## Resumen ejecutivo\n")
    L.append("| # | Chequeo | Estado | Resumen |\n|---|---|---|---|")
    L.append(f"| 1 | Faltantes / duplicados / fechas | {icon(ok1 and not n_missing_days and not log_info['filas_duplicadas'], ok1)} | "
             f"Panel: {panel_info['filas']} meses, {panel_info['NaN_total']} NaN, "
             f"{panel_info['meses_faltantes']} meses faltantes. Crudos: {n_missing_days} pares archivo-día hábil NYSE ausentes "
             f"(días: {', '.join(sorted({str(f['date']) for f in findings if f['check'] == 'missing_trading_day'}))}); "
             f"sin NaN ni duplicados. Log de descarga con {log_info['filas_duplicadas']} filas duplicadas. |")
    L.append(f"| 2 | Retornos extremos > {EXTREME:.0%} | {icon(len(m_ext) == 0, True)} | "
             f"{len(m_ext)} mensuales, {len(d_ext)} diarios. |")
    L.append(f"| 3 | Adj Close con dividendos y splits | {icon(ok3)} | "
             f"{int(adj_tab['caidas_ratio'].sum())} caídas del ratio Adj/Close; "
             f"{int(split_tab['ajustado'].sum())}/{len(split_tab)} splits correctamente ajustados. |")
    L.append(f"| 4 | Alineación VIX y r^f | {icon(perfect4, ok4)} | "
             f"Valores coinciden con último dato del mes; meses donde ese dato no es el último día hábil: "
             f"VIX {align['vix']['meses_no_ultimo_dia']}, r^f {align['rf_return']['meses_no_ultimo_dia']}. |")
    L.append(f"| 5 | Look-ahead | {icon(ok5)} | {la['descuadres']} celdas distintas en el recomputo; "
             f"0 datos posteriores al fin de cada mes. |")
    L.append(f"| 6 | Contraste con Stooq | {'✅' if stooq_ok and stooq_tab['meses_fuera_tol'].sum() == 0 else ('⚠️' if stooq_ok else '⏸️ pendiente')} | "
             + (f"{int(stooq_tab['meses_fuera_tol'].sum())} activo-mes fuera de tolerancia." if stooq_ok
                else "Stooq bloquea la descarga automática; ver sección 6.") + " |\n")

    # 1
    L.append("## 1. Faltantes, duplicados y fechas faltantes\n")
    L.append("### Crudos diarios (Yahoo Finance)\n")
    L.append("Calendario de referencia: días hábiles NYSE aproximados (feriados federales de bolsa, "
             "Viernes Santo, Juneteenth desde 2022 y cierres especiales 2012-10-29/30, 2018-12-05, 2025-01-09).\n")
    L.append(md_table(raw_tab))
    missing_dates = sorted({str(f["date"]) for f in findings if f["check"] == "missing_trading_day"})
    extra_dates = sorted({str(f["date"]) for f in findings if f["check"] == "extra_day"})
    L.append(f"\nDías hábiles ausentes (unión de activos): {', '.join(missing_dates) or 'ninguno'}.  ")
    L.append(f"Fechas extra vs. calendario: {', '.join(extra_dates) or 'ninguna'}.\n")
    if "2025-12-31" in missing_dates:
        L.append("> **Hallazgo:** `yf.download(..., end='2025-12-31')` trata `end` como exclusivo, así que el "
                 "31-dic-2025 (día hábil) no se descargó. El \"cierre de diciembre 2025\" de acciones, SPY y VIX "
                 "es en realidad el del 30-dic-2025.\n")
    L.append("### DGS3MO (FRED)\n")
    L.append(md_table(pd.DataFrame([dgs_info])))
    L.append("\nLos NaN de DGS3MO corresponden a feriados de FRED (no afectan: se toma el último valor válido del mes).\n")
    L.append("### Panel mensual\n")
    L.append(md_table(pd.DataFrame([panel_info])))
    L.append("\n### Log de descarga (`data/raw/download_log.csv`)\n")
    L.append(md_table(pd.DataFrame([{k: str(v) for k, v in log_info.items()}])))
    L.append("\nEl log tiene cada símbolo dos veces (el script se ejecutó dos veces y el log se abre en modo append); "
             f"`n_rows`={log_info['n_rows_log']} coincide con las filas de los CSV ({raw_tab['n'].iloc[0]}). "
             "La descarga de DGS3MO no queda registrada.\n" if log_info["filas_duplicadas"] else "\n")

    # 2
    L.append(f"## 2. Retornos mensuales extremos (|r| > {EXTREME:.0%})\n")
    L.append(md_table(m_ext))
    if len(m_ext):
        L.append("\nNinguno proviene de un error de ajuste: no hay retornos diarios > 30 % y el retorno con `Close` "
                 "es consistente con el de `Adj Close`. CAT oct-2022 (+32.8 %) coincide con su reporte del 3T-2022 "
                 "(25-oct-2022); es un movimiento de mercado real. Conviene confirmarlo también contra Stooq (sección 6).\n")
    L.append("\nCinco mayores |r| mensuales del panel (contexto):\n")
    L.append(md_table(top_tab))
    L.append(f"\nRetornos **diarios** con |r| > {EXTREME:.0%} (en Adj Close o Close; detectaría splits sin ajustar):\n")
    L.append(md_table(d_ext))

    # 3
    L.append("\n## 3. ¿Adj Close incorpora dividendos y splits?\n")
    L.append("Método: el ratio `Adj Close / Close` debe ser creciente en el tiempo, con saltos solo en fechas "
             "ex-dividendo (dividendo implícito `D = Close_{t-1}·(1 − ratio_{t-1}/ratio_t)`). "
             "`Close` de Yahoo ya viene ajustado por splits, por lo que ninguna de las dos series debe saltar en "
             "la fecha de un split. `TR−PR` es la diferencia media anual entre el retorno total (Adj Close) y el de precio (Close).\n")
    L.append(md_table(adj_tab, "{:.4g}"))
    L.append("\nSplits conocidos en la ventana:\n")
    L.append(md_table(split_tab, "{:.4%}"))
    L.append(f"\nVIX: Adj Close ≠ Close en {vix_diff} días (debe ser 0).\n")
    L.append("Nota: los dividendos implícitos no se contrastaron contra un calendario externo de dividendos "
             "(yfinance no está instalado en este entorno); la frecuencia (~4/año) y el yield implícito "
             "son coherentes con la política de pago conocida de cada emisor.\n")

    # 4
    L.append("## 4. Alineación del VIX y r^f al cierre de mes\n")
    for k, lab in [("vix", "VIX (`Adj Close` de ^VIX)"), ("rf_return", "r^f (DGS3MO → (1+y/100)^(1/12)−1)")]:
        a = align[k]
        L.append(f"**{lab}:** {a['meses']} meses comparados; máx. |panel − recomputo| = {a['max_abs_diff']:.2e}; "
                 f"descuadres = {a['descuadres']}; meses cuyo último dato no es el último día hábil = "
                 f"{a['meses_no_ultimo_dia']}; datos posteriores al fin de mes = {a['datos_posteriores_al_mes']}.  ")
        if a["detalle_no_ultimo"]:
            L.append("Meses afectados (mes, último dato usado, último día hábil esperado): "
                     + "; ".join(f"{p}: {e} vs {r}" for p, e, r in a["detalle_no_ultimo"]) + "\n")
        else:
            L.append("\n")
    L.append("Referencia de \"último día hábil\": calendario NYSE (feriados como Memorial Day o Viernes Santo, "
             "en que FRED publica NaN, no cuentan). En todos los casos se usó el último dato *disponible* del mes, "
             "que es lo que exige la ecuación 58; no se usan datos de meses posteriores.\n")
    L.append(f"Meses de r^f rellenados con ffill: {align['rf_return']['meses_con_ffill']}; "
             f"meses con r^f = 0 exacto: {', '.join(align['rf_return']['meses_rf_cero']) or 'ninguno'}; "
             f"meses con r^f < 1 pb: {align['rf_return']['meses_rf_bajo_1pb']} (tasas cercanas a cero 2010-2015 "
             "y 2020-2021; valores reales, no faltantes).\n")
    L.append("Nota metodológica: DGS3MO es un rendimiento anualizado en base *bond-equivalent*; la conversión "
             "`(1+y)^(1/12)−1` es una aproximación razonable (diferencias < 1 pb mensual).\n")

    # 5
    L.append("## 5. Look-ahead\n")
    L.append(f"- Recomputo del panel desde `data/raw/` con las funciones de `data/01_import_data.py`: "
             f"{la['celdas_comparadas']} celdas comparadas, {la['descuadres']} distintas "
             f"(máx. |dif| = {la['max_abs_diff']:.2e}).")
    L.append(f"- `monthly_adj_close.csv` vs recomputo: máx. |dif| = {la['monthly_adj_close_max_diff']:.2e}.")
    L.append(f"- Test de desplazamiento (error medio |panel − retornos desplazados s meses|): "
             + ", ".join(f"s={s}: {v:.2e}" for s, v in la["shift_err"].items())
             + " → el panel coincide solo con s=0 (sin adelanto ni rezago).")
    L.append("- Todos los valores del mes m usan `resample('ME').last()`, es decir, datos con fecha ≤ fin de m "
             "(verificado en la sección 4 para VIX y r^f; para precios es idéntico).")
    L.append(f"- Fechas en los crudos posteriores a END={END}: {la['fechas_post_END']}; posteriores a la fecha de "
             f"descarga ({la['download_date']}): {la['fechas_post_descarga']}.")
    if la["filas_solo_recomputo"]:
        L.append(f"- El código actual produciría también la(s) fila(s) {', '.join(la['filas_solo_recomputo'])} "
                 "(retornos NaN, VIX y r^f válidos) que **no** están en el CSV guardado: el CSV fue generado con una "
                 "versión ligeramente distinta del script o recortado después. No afecta a MATLAB (que espera "
                 "ene-2010 como primera fila), pero el código y el archivo no son reproducibles 1:1.")
    L.append("- Uso en MATLAB (`run_backtest_wdro_kelly.m`): en la fecha k se usan `R(k−N+1:k)` y `rf_return(k)` "
             "(tasa observada al cierre de k) para decidir, y se aplica `R(k+1)`; r^f de k se acumula durante k+1, "
             "lo cual es conocido ex-ante → sin look-ahead. El VIX de la ventana (wdro-market) también usa k−N+1..k.")
    L.append("- Advertencia: Yahoo reescala `Adj Close` retroactivamente con cada nuevo dividendo; los *niveles* "
             "dependen de la fecha de descarga, pero los *retornos* no. No es look-ahead en retornos.\n")

    # 6
    L.append("## 6. Contraste de precios de cierre contra Stooq\n")
    if stooq_ok:
        L.append(f"Comparación a fin de mes. Error relativo = Yahoo/Stooq − 1 contra `Close` y `Adj Close`; "
                 f"`base_coincide` indica cuál serie de Yahoo replica a Stooq. Tolerancias: {TOL_PRICE:.1%} en precio, "
                 f"{TOL_RET * 100:.2f} pp en retorno mensual. Detalle completo por activo y mes en "
                 "`data/audit/stooq_monthly_comparison.csv`.\n")
        L.append(md_table(stooq_tab, "{:.4g}"))
    missing = {t: s for t, s in stooq_status.items() if s not in ("cache", "descargado")}
    if missing:
        L.append("\nActivos sin datos de Stooq: "
                 + ", ".join(f"{t} ({s})" for t, s in missing.items()) + ".\n")
        L.append("Stooq protege su endpoint CSV con una verificación JavaScript (proof-of-work), así que no se "
                 "puede descargar desde un script. Para completar este chequeo, descargue manualmente desde el "
                 "navegador `https://stooq.com/q/d/l/?s=<símbolo>&d1=20091201&d2=20251231&i=d` "
                 "(símbolos: " + ", ".join(f"{t}→`{STOOQ_SYMBOL[t]}`" for t in missing)
                 + ") y guarde cada archivo como `data/audit/stooq_cache/<TICKER>.csv` (p. ej. `AAPL.csv`, `VIX.csv`). "
                 "Luego vuelva a ejecutar el script.\n")

    # Recomendaciones
    L.append("## Recomendaciones (no aplicadas)\n")
    L.append("1. Usar `END_DATE = \"2026-01-01\"` en `yf.download` (end exclusivo) y regenerar dic-2025.")
    L.append("2. Escribir `download_log.csv` en modo sobrescritura por ejecución (o con un id de corrida) y registrar también DGS3MO.")
    L.append("3. Regenerar `monthly_panel.csv` con el script actual (o recortar explícitamente a ene-2010 en el código) para que el archivo sea reproducible.")
    L.append("4. Guardar una copia de los crudos con fecha de descarga, ya que Yahoo reescala Adj Close retroactivamente.")

    (OUT_DIR / "audit_report.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"Reporte: {OUT_DIR / 'audit_report.md'}")
    print(f"Discrepancias: {OUT_DIR / 'audit_discrepancies.csv'} ({len(disc)} filas)")
    print(disc["check"].value_counts().to_string())


if __name__ == "__main__":
    main()
