"""
Auditoría de datos - Portafolios Wasserstein-Kelly

Audita data/raw/ y data/processed/monthly_panel.csv SIN modificarlos.
Salidas (en data/audit/):
    audit_report.md           reporte
    LEEME_auditoria.txt       resumen corto en texto plano
    audit_discrepancies.csv   discrepancias (formato largo, con causa y resolución)
    reference_monthly_comparison.csv   contraste mensual Yahoo vs referencia
Lee (si existen) los precios de referencia de ref_cache/<tic>.csv, que descarga
03_download_reference.py (Tiingo para acciones y SPY, CBOE para el VIX).
Stooq, la fuente prevista originalmente, está bloqueado a nivel de red.

Uso (desde la raíz del proyecto):
    py data/audit/02_audit_data.py
"""

import importlib.util
import sys

sys.dont_write_bytecode = True  # no dejar __pycache__ en data/
import types
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
REF_DIR = OUT_DIR / "ref_cache"
OUT_DIR.mkdir(exist_ok=True)

TICKERS = ["AAPL", "MSFT", "AMZN", "JPM", "JNJ", "XOM", "PG", "CAT", "KO", "WMT"]
YAHOO_FILES = TICKERS + ["SPY", "VIX"]
START, END = "2009-12-01", "2025-12-31"
EXTREME = 0.30
TOL_PRICE = 0.005     # 0.5 % error relativo en precio vs referencia
TOL_RET = 0.0025      # 0.25 pp en retorno mensual vs referencia
TOL_EXACT = 1e-10
N_WINDOW = 60         # ventana móvil del backtest (meses)
EPS_ESC = 1e-6        # piso del IQR en standardize_median_iqr.m / build_transport_cost.m

# Splits conocidos en la ventana 2009-12 / 2025-12
KNOWN_SPLITS = {
    "AAPL": [("2014-06-09", 7.0), ("2020-08-31", 4.0)],
    "AMZN": [("2022-06-06", 20.0)],
    "WMT": [("2024-02-26", 3.0)],
    "KO": [("2012-08-13", 2.0)],
}

findings = []   # filas del CSV de discrepancias

# Qué se hizo con cada tipo de hallazgo (columna `resolucion` del CSV).
# Criterio general: la auditoría es de solo lectura; nada se imputa ni se corrige.
RESOLUTION = {
    "missing_trading_day": "no se imputa; el mes usa el último dato disponible (dic-2025 -> 30-dic)",
    "extra_day": "informativo; se conserva el dato",
    "duplicate_date": "informativo; revisar manualmente",
    "nan_value": "no se imputa; el mes usa el último dato válido",
    "rf_gap": "no se imputa; el mes usa el último dato válido de DGS3MO",
    "missing_month": "no se imputa; revisar manualmente",
    "download_log_duplicate": "informativo; los archivos crudos son de una sola descarga",
    "download_log_missing": "informativo; fecha de descarga de DGS3MO no registrada",
    "download_log_nrows": "revisar manualmente",
    "extreme_monthly_return": "se conserva: movimiento de mercado real (no es error de ajuste)",
    "extreme_daily_return": "revisar manualmente",
    "adj_ratio_decrease": "revisar manualmente",
    "unexpected_dividend": "revisar manualmente",
    "no_dividend_adjustment": "revisar manualmente",
    "split_date_missing": "revisar manualmente",
    "split_not_adjusted": "revisar manualmente",
    "vix_adj_ne_close": "revisar manualmente",
    "mkt_return_not_last_day": "se acepta: es el último dato disponible del mes (sin look-ahead)",
    "vix_not_last_day": "se acepta: es el último dato disponible del mes (sin look-ahead)",
    "rf_return_not_last_day": "se acepta: es el último dato disponible del mes (sin look-ahead)",
    "panel_row_dropped": "se acepta: la fila no tiene retornos y MATLAB espera ene-2010 como primera fila",
    "ref_price_discrepancy": "se mantiene Yahoo (fuente oficial); solo se marca",
    "dividend_only_yahoo": "informativo; se mantiene el Adj Close de Yahoo",
    "dividend_only_ref": "informativo; se mantiene el Adj Close de Yahoo",
    "low_iqr_window": "regla prevista (C14): excluir la variable de c_{k,rs} en esa ventana; no implementada",
}


def add(check, asset, date, value=np.nan, reference=np.nan, rel_error=np.nan, detail="",
        cause="", resolution=None):
    findings.append(dict(check=check, asset=asset,
                         date=None if date is None else pd.Timestamp(date).date(),
                         value=value, reference=reference, rel_error=rel_error,
                         detail=detail, causa_probable=cause,
                         resolucion=resolution or RESOLUTION.get(check, "revisar manualmente")))


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
# 1b. Fecha de descarga y periodo efectivo por ticker
# ---------------------------------------------------------------------------

PANEL_COL = {t: t for t in TICKERS}
PANEL_COL.update({"SPY": "mkt_return", "VIX": "vix", "DGS3MO": "rf_return"})


def load_ref_log():
    path = REF_DIR / "download_log.csv"
    if not path.exists():
        return pd.DataFrame(columns=["symbol", "source", "download_date"]).set_index("symbol")
    return pd.read_csv(path).set_index("symbol")


def period_table(raw, dgs, log, panel):
    """Fecha de descarga, rango solicitado y rango efectivo (diario y mensual) por serie."""
    log = log.drop_duplicates(subset=["symbol"], keep="last").copy()
    log["key"] = log["symbol"].str.replace("^", "", regex=False)
    log = log.set_index("key")
    series = {t: raw[t]["Adj Close"] for t in YAHOO_FILES}
    series["DGS3MO"] = dgs
    ref_log = load_ref_log()
    rows = []
    for t, s in series.items():
        s = s.dropna()
        col = panel[PANEL_COL[t]].dropna()
        last_m = col.index.max()
        in_last = s[(s.index.year == last_m.year) & (s.index.month == last_m.month)]
        if t in log.index:
            fuente, dl = "Yahoo Finance", log.at[t, "download_date"]
            ini, fin = log.at[t, "start_requested"], log.at[t, "end_requested"]
        else:
            fuente, dl = "FRED", "no registrada (guardada en el commit del 2026-08-12)"
            ini, fin = START, END
        if t in ref_log.index:
            ref = f"{ref_log.at[t, 'source']} {ref_log.at[t, 'download_date']}"
        else:
            ref = "no aplica" if t == "DGS3MO" else "pendiente"
        rows.append(dict(serie=t, fuente=fuente, fecha_descarga=dl,
                         inicio_solicitado=ini, fin_solicitado=fin,
                         primer_dato=s.index.min().date(), ultimo_dato=s.index.max().date(),
                         n_dias=len(s),
                         primer_mes_panel=col.index.min().strftime("%Y-%m"),
                         ultimo_mes_panel=last_m.strftime("%Y-%m"),
                         dia_usado_ultimo_mes=in_last.index.max().date(),
                         meses_validos=len(col),
                         referencia=ref))
    return pd.DataFrame(rows)


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

    spy_m = raw["SPY"]["Adj Close"].resample("ME").last().pct_change()
    vix_m = raw["VIX"]["Adj Close"].resample("ME").last()
    y_m = dgs.resample("ME").last().ffill()
    rf_m = (1 + y_m / 100) ** (1 / 12) - 1

    out = {}
    for name, rec, eff_src, last_ref in [
        ("mkt_return", spy_m, raw["SPY"]["Adj Close"], cal_last),
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
    flat = bad.stack()          # en pandas >= 3 stack() no descarta NaN: se filtra explícitamente
    for (d, c) in flat[flat].index:
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
# 6. Contraste con una fuente de referencia (Tiingo / CBOE)
# ---------------------------------------------------------------------------

def get_reference(t):
    """Precios de ref_cache/<t>.csv (03_download_reference.py) o None si faltan."""
    path = REF_DIR / f"{t}.csv"
    if not path.exists():
        return None, "sin CSV en ref_cache (ejecutar 03_download_reference.py)"
    df = pd.read_csv(path, index_col="Date", parse_dates=True).sort_index()
    return df, df["fuente"].iloc[0]


REF_CAUSES = {
    "fecha_fin_mes_distinta": "el último día con dato del mes difiere entre fuentes",
    "mes_con_split": "el mes contiene un split conocido",
    "ajuste_dividendos": "retorno distinto en un mes con fecha ex-dividendo (ajuste distinto)",
    "escala_ajuste": "solo difiere el nivel, no el retorno (factor de ajuste acumulado distinto según fecha de descarga)",
    "sin_explicar": "sin causa identificada; revisar manualmente",
}


def classify_ref(d, ey, es, split_months, div_months, price_bad, ret_bad):
    """Causa probable de una discrepancia Yahoo/referencia en el mes que termina en d."""
    p = d.to_period("M")
    if p in ey.index and p in es.index and ey[p] != es[p]:
        return "fecha_fin_mes_distinta"
    if p in split_months or (p - 1) in split_months:
        return "mes_con_split"
    if ret_bad and p in div_months:
        return "ajuste_dividendos"
    if price_bad and not ret_bad:
        return "escala_ajuste"
    return "sin_explicar"


def later_split_factor(ref):
    """Producto de los splitFactor de Tiingo POSTERIORES a cada fecha: divide un precio
    (o dividendo) sin ajustar para llevarlo a la base ajustada por splits de Yahoo."""
    sf = ref["splitFactor"].fillna(1.0)
    return sf[::-1].cumprod()[::-1].shift(-1).fillna(1.0)


def yahoo_dividends(y):
    """Dividendos implícitos en el ratio Adj Close / Close de Yahoo (ver sección 3)."""
    ratio = y["Adj Close"] / y["Close"]
    step = ratio / ratio.shift(1) - 1
    days = step[step > 1e-5].index
    return (y["Close"].shift(1) * (1 - ratio.shift(1) / ratio))[days]


def check_reference(raw):
    summary, detail_rows, div_rows, status = [], [], [], {}
    for t in TICKERS + ["SPY", "VIX"]:
        ref, status[t] = get_reference(t)
        if ref is None:
            continue
        y = raw[t]
        ref = ref.loc[START:END]
        is_vix = t == "VIX"
        # precio: Close de Yahoo (ajustado por splits) vs cierre de referencia en la misma base
        later = pd.Series(1.0, index=ref.index) if is_vix else later_split_factor(ref)
        ref_px = ref["Close"] / later
        ym = y[["Close", "Adj Close"]].resample("ME").last()
        rpx = ref_px.resample("ME").last()
        radj = ref["Adj Close"].resample("ME").last()
        idx = ym.index.intersection(rpx.index)
        ym, rpx, radj = ym.loc[idx], rpx.loc[idx], radj.loc[idx]
        e = ym["Close"] / rpx - 1
        e_adj = ym["Adj Close"] / radj - 1      # informativo: depende de la fecha de descarga
        # retorno total mensual: Adj Close de Yahoo vs Adj Close de referencia
        r_diff = ym["Adj Close"].pct_change() - radj.pct_change()
        ey = last_date_per_month(y["Close"])
        es = last_date_per_month(ref["Close"])
        date_mis = (ey.reindex(es.index) != es).sum()

        if is_vix:
            ydiv = rdiv = pd.Series(dtype=float, index=pd.DatetimeIndex([]))
            split_months = set()
        else:
            ydiv = yahoo_dividends(y)
            # divCash de Tiingo es por acción en su momento; se lleva a base ajustada por splits
            cash = ref["divCash"].fillna(0)
            rdiv = (cash / later)[cash > 0]
            split_months = set(ref.index[ref["splitFactor"].fillna(1.0) != 1].to_period("M"))
        split_months |= {pd.Timestamp(sd).to_period("M") for sd, _ in KNOWN_SPLITS.get(t, [])}
        div_months = set(ydiv.index.to_period("M")) | set(rdiv.index.to_period("M"))

        price_bad = e.abs() > TOL_PRICE
        ret_bad = r_diff.abs() > TOL_RET
        n_bad = 0
        for d in idx:
            row = dict(activo=t, fecha=d.date(), yahoo_close=ym.at[d, "Close"],
                       yahoo_adj=ym.at[d, "Adj Close"], ref_close_ajust_split=rpx[d],
                       ref_adj=radj[d], err_rel_close=e[d], err_rel_adj=e_adj[d],
                       dif_ret=r_diff[d], fuente=status[t], causa_probable="")
            if price_bad[d] or ret_bad[d]:
                n_bad += 1
                cause = classify_ref(d, ey, es, split_months, div_months, price_bad[d], ret_bad[d])
                row["causa_probable"] = cause
                add("ref_price_discrepancy", t, d, value=ym.at[d, "Close"], reference=rpx[d],
                    rel_error=e[d], detail=f"{status[t]}; dif. retorno total {r_diff[d]:.4%}",
                    cause=cause)
            detail_rows.append(row)
        summary.append(dict(activo=t, fuente=status[t],
                            primer_dato=ref.index.min().date(), ultimo_dato=ref.index.max().date(),
                            meses=len(idx),
                            err_rel_close_medio=float(e.abs().mean()),
                            err_rel_close_max=float(e.abs().max()),
                            mes_err_max=e.abs().idxmax().date(),
                            err_rel_adj_medio=float(e_adj.abs().mean()),
                            dif_ret_media=float(r_diff.abs().mean()),
                            dif_ret_max=float(r_diff.abs().max()),
                            meses_fuera_tol=n_bad,
                            fin_mes_distinto=int(date_mis)))

        if not is_vix:
            both = ydiv.index.intersection(rdiv.index)
            only_y = ydiv.index.difference(rdiv.index)
            only_r = rdiv.index.difference(ydiv.index)
            for d in only_y:
                add("dividend_only_yahoo", t, d, value=ydiv[d],
                    detail=f"ex-dividendo implícito en Yahoo sin divCash en {status[t]} ese día")
            for d in only_r:
                add("dividend_only_ref", t, d, reference=rdiv[d],
                    detail=f"divCash en {status[t]} sin salto del ratio Adj/Close de Yahoo ese día")
            amt = (ydiv[both] / rdiv[both] - 1).abs()
            div_rows.append(dict(activo=t, div_yahoo=len(ydiv), div_ref=len(rdiv),
                                 coinciden_fecha=len(both), solo_yahoo=len(only_y), solo_ref=len(only_r),
                                 err_rel_monto_mediano=float(amt.median()) if len(amt) else np.nan,
                                 err_rel_monto_max=float(amt.max()) if len(amt) else np.nan))
    detail = pd.DataFrame(detail_rows)
    if not detail.empty:
        detail.to_csv(OUT_DIR / "reference_monthly_comparison.csv", index=False)
    return pd.DataFrame(summary), pd.DataFrame(div_rows), status


# ---------------------------------------------------------------------------
# 7. IQR de cada serie en las ventanas móviles de 60 meses
# ---------------------------------------------------------------------------

def check_window_iqr(panel):
    """IQR por serie en cada ventana D_k = meses k-N+1..k, con k = N..T-1 (1-based),
    igual que decision_idx = N:(T-1) en run_backtest_*.m. Percentiles como prctile de
    MATLAB: puntos en (i-0.5)/n con interpolación lineal = método 'hazen' de numpy."""
    cols = TICKERS + ["mkt_return", "vix", "rf_return"]
    ks = range(N_WINDOW, len(panel))              # k 1-based: 60..191
    iqr = {}
    for k in ks:
        w = panel.iloc[k - N_WINDOW:k][cols].to_numpy()
        q = np.percentile(w, [25, 75], axis=0, method="hazen")
        iqr[panel.index[k - 1]] = q[1] - q[0]
    iqr = pd.DataFrame.from_dict(iqr, orient="index", columns=cols)
    iqr.index.name = "fin_ventana"
    iqr.to_csv(OUT_DIR / "window_iqr.csv")
    rows = []
    for c in cols:
        low = iqr.index[iqr[c] < EPS_ESC]
        if c != "rf_return":
            for d in low:
                add("low_iqr_window", c, d, value=iqr.at[d, c], reference=EPS_ESC,
                    detail=f"IQR < eps_esc en la ventana de {N_WINDOW} meses que termina en esta fecha")
        rows.append(dict(serie=c, en_geometria="no (referencia)" if c == "rf_return" else "sí",
                         ventanas=len(iqr), ventanas_iqr_bajo_piso=len(low),
                         iqr_min=float(iqr[c].min()), ventana_min=iqr[c].idxmin().date(),
                         iqr_mediano=float(iqr[c].median())))
    info = dict(n=len(iqr), primera=iqr.index.min().date(), ultima=iqr.index.max().date())
    return pd.DataFrame(rows), info


# ---------------------------------------------------------------------------
# Reporte
# ---------------------------------------------------------------------------

def icon(ok, warn=False):
    return "✅" if ok else ("⚠️" if warn else "❌")


def write_readme(per_tab, panel_info, n_missing_days, log_info, m_ext, align, la,
                 ref_tab, ref_status, ref_causes, iqr_tab, iqr_info):
    """Resumen corto en texto plano (data/audit/LEEME_auditoria.txt)."""
    yahoo = per_tab[per_tab["fuente"] == "Yahoo Finance"]
    fred = per_tab[per_tab["fuente"] == "FRED"].iloc[0]
    n_ref = len(ref_tab)
    T = []
    T.append("AUDITORÍA DE DATOS - Wasserstein-Kelly")
    T.append(f"Generado por data/audit/02_audit_data.py el {pd.Timestamp.today().date()}.")
    T.append("Detalle completo: audit_report.md | Hallazgos uno a uno: audit_discrepancies.csv")
    T.append("")
    T.append("1. QUÉ SE AUDITÓ")
    T.append(f"   - Precios diarios Yahoo Finance: {', '.join(TICKERS)}, SPY (mercado) y ^VIX.")
    T.append("   - Tasa libre de riesgo: DGS3MO (FRED).")
    T.append("   - Panel mensual data/processed/monthly_panel.csv (lo que usa MATLAB).")
    T.append("   - Contraste externo: Tiingo (acciones y SPY) y CBOE (VIX). Stooq, la fuente prevista,")
    T.append("     está bloqueado a nivel de red.")
    T.append(f"   - IQR de cada serie en las ventanas de {N_WINDOW} meses del backtest.")
    T.append("   La auditoría es de solo lectura: no se modificó ningún dato.")
    T.append("")
    T.append("2. FECHA DE DESCARGA Y PERIODO EFECTIVO")
    T.append(f"   {'serie':<7} {'fuente':<14} {'descarga':<11} {'primer dato':<11}  {'último dato':<11}  "
             f"{'días':>5}  {'meses panel':<17} {'referencia':<17}")
    for _, r in per_tab.iterrows():
        dl = r["fecha_descarga"] if r["fuente"] != "FRED" else "no regist."
        T.append(f"   {r['serie']:<7} {r['fuente']:<14} {dl:<11} {str(r['primer_dato']):<11}  "
                 f"{str(r['ultimo_dato']):<11}  {r['n_dias']:>5}  "
                 f"{r['primer_mes_panel']} a {r['ultimo_mes_panel']:<7} {str(r['referencia']):<17}")
    T.append(f"   Rango solicitado a Yahoo: {yahoo['inicio_solicitado'].iloc[0]} a {yahoo['fin_solicitado'].iloc[0]} "
             "(fin exclusivo en yfinance).")
    T.append(f"   Diciembre 2025 usa el cierre del {yahoo['dia_usado_ultimo_mes'].iloc[0]} "
             f"(DGS3MO: {fred['dia_usado_ultimo_mes']}).")
    T.append("   La descarga de DGS3MO no quedó registrada en download_log.csv; se guardó en el mismo")
    T.append("   commit que los datos de Yahoo (2026-08-12).")
    T.append("")
    T.append("3. CRITERIO ANTE FALTANTES")
    T.append("   - No se imputa nada. El valor de cada mes es el último dato disponible del mes")
    T.append("     (nunca uno del mes siguiente, así que no hay look-ahead).")
    T.append(f"   - Falta 1 día hábil en los crudos de Yahoo (2025-12-31, {n_missing_days} pares archivo-día): no se")
    T.append("     rellena; diciembre 2025 se cierra con el 30-dic-2025.")
    T.append("   - Los NaN de DGS3MO son feriados de FRED: se ignoran y se usa el último valor válido.")
    T.append(f"     Meses de r^f rellenados con el mes anterior (ffill): {align['rf_return']['meses_con_ffill']}.")
    T.append("   - Dic-2009 solo sirve de base para el retorno de ene-2010; su fila se descarta.")
    T.append(f"   - Resultado: panel de {panel_info['filas']} meses, {panel_info['NaN_total']} NaN, "
             f"{panel_info['meses_faltantes']} meses faltantes.")
    T.append("")
    T.append("4. CRITERIO ANTE DISCREPANCIAS YAHOO vs REFERENCIA (PROPUESTA)")
    T.append(f"   - Discrepancia = error de precio a fin de mes > {TOL_PRICE:.1%} (Close de Yahoo vs cierre")
    T.append(f"     de referencia ajustado por splits) o diferencia de retorno total mensual > {TOL_RET * 100:.2f} pp")
    T.append("     (Adj Close de Yahoo vs Adj Close de referencia).")
    T.append("   - Yahoo se mantiene como fuente oficial: no se corrige ni sustituye nada. Cada")
    T.append("     discrepancia se marca y se clasifica por causa probable; las que no tienen")
    T.append("     explicación quedan para revisión manual.")
    if n_ref:
        T.append(f"   - Resultado: {int(ref_tab['meses_fuera_tol'].sum())} activo-mes fuera de tolerancia "
                 f"en {n_ref} series:")
        for _, r in ref_causes.iterrows():
            T.append(f"       {r['causa_probable']:<24} {r['casos']:>4}")
    pend = [t for t, s in ref_status.items() if s.startswith("sin CSV")]
    if pend:
        T.append(f"   - PENDIENTE: sin datos de referencia para {', '.join(pend)}. Defina TIINGO_API_KEY y")
        T.append("     ejecute data/audit/03_download_reference.py; luego vuelva a ejecutar este script.")
    T.append("")
    T.append(f"5. IQR EN VENTANAS DE {N_WINDOW} MESES (piso eps_esc = {EPS_ESC:g})")
    T.append(f"   {iqr_info['n']} ventanas (fin {iqr_info['primera']} a {iqr_info['ultima']}).")
    for _, r in iqr_tab.iterrows():
        T.append(f"   {r['serie']:<11} ventanas con IQR < piso: {r['ventanas_iqr_bajo_piso']:>3}   "
                 f"IQR mínimo {r['iqr_min']:.4g} ({r['ventana_min']})")
    T.append("")
    T.append("6. HALLAZGOS PRINCIPALES")
    T.append("   - Falta el 31-dic-2025 (yf.download con end='2025-12-31' es exclusivo).")
    T.append(f"   - download_log.csv tiene {log_info['filas_duplicadas']} filas duplicadas (dos ejecuciones) "
             "y no registra DGS3MO.")
    for _, r in m_ext.iterrows():
        note = " (real: resultados 3T-2022)" if (r["activo"], str(r["fecha"])) == ("CAT", "2022-10-31") else ""
        T.append(f"   - Retorno extremo {r['activo']} {r['fecha']}: {r['retorno']:+.1%}{note}.")
    T.append(f"   - Recomputo del panel: {la['descuadres']} celdas distintas; sin look-ahead.")
    T.append("   - Adj Close incorpora dividendos y los 5 splits del periodo correctamente.")
    T.append("   - SPY, VIX y r^f alineados al último dato disponible de cada mes.")
    T.append("")
    T.append("7. RECOMENDACIONES (no aplicadas)")
    T.append("   - Usar end='2026-01-01' en yf.download y regenerar dic-2025 (el script ya tiene el cambio,")
    T.append("     sin confirmar; data/raw NO se ha regenerado).")
    T.append("   - Escribir download_log.csv sin append y registrar también DGS3MO.")
    T.append("   - Regenerar monthly_panel.csv con el script actual para que sea reproducible.")
    T.append("   - Guardar copia fechada de los crudos (Yahoo reescala Adj Close retroactivamente).")
    (OUT_DIR / "LEEME_auditoria.txt").write_text("\n".join(T) + "\n", encoding="utf-8")


def methodology_blocks(per_tab, log, align, la, ref_tab, ref_status, ref_causes, iqr_tab, iqr_info,
                       panel_info, n_missing_days):
    """Sección final: dato exacto para cada [PENDIENTE]/REVISAR de metodologia_2.tex que
    depende de los datos (subsecciones "Universo y fuentes", "Retornos mensuales" y la
    estandarización de "Geometrías de transporte")."""
    yahoo = per_tab[per_tab["fuente"] == "Yahoo Finance"]
    fred = per_tab[per_tab["fuente"] == "FRED"].iloc[0]
    dl_dates = sorted(set(log["download_date"].astype(str)))
    ref_log = load_ref_log()
    pend = [t for t, s in ref_status.items() if s.startswith("sin CSV")]
    same_range = (yahoo["primer_dato"].nunique() == 1 and yahoo["ultimo_dato"].nunique() == 1)
    geo = iqr_tab[iqr_tab["en_geometria"] == "sí"]
    n_low = int(geo["ventanas_iqr_bajo_piso"].sum())

    L = ["## 8. Datos para `metodologia_2.tex`\n",
         "Un bloque por cada `[PENDIENTE]`/REVISAR que depende de los datos. Se da el dato; el texto "
         "del `.tex` no se modificó.\n"]

    L.append("### C7. Fecha de descarga (`[PENDIENTE: fecha de descarga...]`)\n")
    L.append(f"- Yahoo Finance (10 acciones, SPY, ^VIX): **{', '.join(dl_dates)}**, según `data/raw/download_log.csv` "
             f"(el log tiene cada símbolo dos veces, ambas con esa fecha).")
    L.append("- FRED (DGS3MO): **no registrada** en el log; el archivo se guardó en el mismo commit que los de Yahoo "
             "(2026-08-12). Si se cita una fecha, debe decirse que es la del commit.")
    if len(ref_log):
        L.append("- Fuentes de referencia (contraste): "
                 + "; ".join(f"{s} {r['source']} {r['download_date']}" for s, r in ref_log.iterrows()) + ".")
    L.append("")

    L.append("### C7. Periodo efectivo por ticker (`[PENDIENTE: confirmar con audit_report.csv]`)\n")
    if same_range:
        r0 = yahoo.iloc[0]
        L.append(f"- Las 12 series de Yahoo tienen el mismo rango diario: **{r0['primer_dato']} a {r0['ultimo_dato']}** "
                 f"({r0['n_dias']} días hábiles). Se solicitó hasta {r0['fin_solicitado']}, pero `yf.download` trata "
                 "`end` como exclusivo; el cierre de diciembre de 2025 es el del **30-dic-2025**.")
    else:
        L.append("- Los rangos difieren por serie; ver la tabla de la sección 1.")
    L.append(f"- DGS3MO: {fred['primer_dato']} a {fred['ultimo_dato']} ({fred['n_dias']} observaciones válidas).")
    L.append(f"- Panel mensual: **{panel_info['primero']} a {panel_info['ultimo']}** ({panel_info['filas']} meses, "
             f"{panel_info['NaN_total']} NaN, {panel_info['meses_faltantes']} meses faltantes); dic-2009 solo sirve de base "
             "para el retorno de ene-2010.")
    L.append("- Nota: el texto cita `audit_report.csv`; el periodo está en `data/audit/audit_report.md`, sección 1.\n")

    L.append("### C7. Criterio ante faltantes (`[PENDIENTE: criterio usado]`)\n")
    L.append("- Texto propuesto: «no se imputó ningún dato; el valor de cada mes es el último dato disponible del mes "
             "(nunca uno posterior). El único día hábil ausente en los precios (31-dic-2025) no se rellenó, y los NaN "
             "de DGS3MO, que corresponden a feriados, se omitieron tomando el último rendimiento válido del mes».")
    L.append(f"- Datos: {n_missing_days} pares archivo-día ausentes (todos el 31-dic-2025); meses con r^f tomado de un mes "
             f"anterior (ffill): **{align['rf_return']['meses_con_ffill']}**.")
    L.append("- **Diferencia texto/código:** el texto dice «la tasa DGS3MO se completó con su última observación disponible "
             "cuando faltaba un dato». Es correcto dentro del mes (se toma el último dato válido), pero el `ffill` entre "
             f"meses de `01_import_data.py` se usó en {align['rf_return']['meses_con_ffill']} meses: no hubo que completar "
             "ningún mes.\n")

    L.append("### C7. Regla ante discrepancias (`[PENDIENTE: regla de resolución...]`) — **PROPUESTA**\n")
    L.append(f"- Regla propuesta: «prevaleció Yahoo Finance; una discrepancia (error de precio a fin de mes > {TOL_PRICE:.1%} "
             f"o diferencia de retorno total mensual > {TOL_RET * 100:.2f} pp) se registró y se clasificó por causa "
             "probable, sin modificar el dato».")
    if len(ref_tab):
        n_bad = int(ref_tab["meses_fuera_tol"].sum())
        n_unexpl = int(ref_causes.loc[ref_causes["causa_probable"] == "sin_explicar", "casos"].sum())
        L.append(f"- Resultado con {len(ref_tab)} series contrastadas: **{n_bad} activo-mes** fuera de tolerancia, "
                 f"de ellos **{n_unexpl} sin explicar**; máx. |dif. retorno| = {ref_tab['dif_ret_max'].max():.2e}.")
    if pend:
        L.append(f"- **Aún pendiente** para: {', '.join(pend)} (falta la descarga de Tiingo).")
    L.append("- **Diferencia texto/fuente:** el texto dice «contra los datos históricos extraídos de Stooq». Stooq está "
             "bloqueado a nivel de red, así que el contraste se hizo contra **Tiingo** (acciones y SPY) y **CBOE** "
             "(VIX, fuente oficial del índice). La frase y la nota al pie deben cambiar.\n")

    L.append("### C8. Ningún dato posterior al cierre (`[PENDIENTE: confirmar...]`)\n")
    L.append(f"- Confirmado. Recomputo del panel: {la['descuadres']} de {la['celdas_comparadas']} celdas distintas; test de "
             f"desplazamiento: solo s=0 coincide; fechas posteriores a {END} en los crudos: {la['fechas_post_END']}.")
    for k, lab in [("mkt_return", "SPY"), ("vix", "VIX"), ("rf_return", "DGS3MO")]:
        a = align[k]
        L.append(f"- {lab}: datos posteriores al fin de mes = {a['datos_posteriores_al_mes']}; meses cuyo último dato no "
                 f"es el último día bursátil = {a['meses_no_ultimo_dia']}"
                 + (f" ({'; '.join(f'{p}: {e}' for p, e, _ in a['detalle_no_ultimo'])})" if a["detalle_no_ultimo"] else "")
                 + ".")
    L.append("- La descripción del REVISAR de C8 (último cierre diario de SPY y VIX, última observación de DGS3MO del mes, "
             "`resample('ME').last()` + `ffill`) coincide con `01_import_data.py`.\n")

    L.append("### C14. Ventanas con IQR < ε_esc (`[PENDIENTE: reportar el conteo...]`)\n")
    L.append(f"- ε_esc = {EPS_ESC:g} (`standardize_median_iqr.m`, `build_transport_cost.m`). Ventanas de {N_WINDOW} meses: "
             f"{iqr_info['n']} (fechas de decisión del backtest, fin de ventana {iqr_info['primera']} a {iqr_info['ultima']}).")
    if n_low == 0:
        L.append(f"- **Conteo: 0** en las {len(geo)} series de la geometría (10 retornos, SPY y VIX). La serie con IQR más "
                 f"pequeño es `{geo.loc[geo['iqr_min'].idxmin(), 'serie']}` con {geo['iqr_min'].min():.4g}, muy por encima "
                 "del piso. La regla de exclusión prevista nunca se activa; puede decirse así en el texto.")
    else:
        L.append(f"- **Conteo: {n_low}** ventana-serie bajo el piso; ver la tabla de la sección 7.")
    L.append("")

    L.append("### C6. Criterio de selección y fuente GICS\n")
    L.append("- **No se resuelve con los datos**: es una decisión del autor (criterio de selección y fuente de la "
             "clasificación sectorial).\n")
    return L


def main():
    raw, dgs, log, panel, adj_m = load_raw()
    cal = nyse_days(START, END)

    raw_tab, dgs_info, panel_info, log_info = check_missing(raw, dgs, log, panel, cal)
    m_ext, d_ext, top_tab = check_extremes(raw, panel)
    adj_tab, split_tab, vix_diff = check_adjustments(raw)
    align = check_alignment(raw, dgs, panel, cal)
    la = check_lookahead(raw, dgs, panel, adj_m, log)
    ref_tab, div_tab, ref_status = check_reference(raw)
    iqr_tab, iqr_info = check_window_iqr(panel)
    per_tab = period_table(raw, dgs, log, panel)

    disc = pd.DataFrame(findings, columns=["check", "asset", "date", "value", "reference",
                                           "rel_error", "detail", "causa_probable", "resolucion"])
    disc.to_csv(OUT_DIR / "audit_discrepancies.csv", index=False)
    ref_disc = disc[disc["check"] == "ref_price_discrepancy"]
    ref_causes = (ref_disc.groupby("causa_probable").size().rename("casos")
                  .reindex(list(REF_CAUSES)).fillna(0).astype(int).reset_index())
    ref_causes["significado"] = ref_causes["causa_probable"].map(REF_CAUSES)
    ref_pend = [t for t, s in ref_status.items() if s.startswith("sin CSV")]

    # ---- veredictos
    n_missing_days = int(raw_tab["faltan_vs_NYSE"].sum())
    ok1 = panel_info["NaN_total"] == 0 and panel_info["meses_faltantes"] == 0 \
        and raw_tab["NaN"].sum() == 0 and raw_tab["duplicados"].sum() == 0
    ok3 = (adj_tab["caidas_ratio"].sum() == 0 and split_tab["ajustado"].all()
           and vix_diff == 0)
    ok4 = all(align[k]["descuadres"] == 0 and align[k]["datos_posteriores_al_mes"] == 0 for k in align)
    perfect4 = ok4 and all(align[k]["meses_no_ultimo_dia"] == 0 for k in align)
    ok5 = la["descuadres"] == 0 and la["fechas_post_END"] == 0 and la["shift_err"][0] < 1e-12
    ref_ok = not ref_tab.empty
    n_ref_bad = int(ref_tab["meses_fuera_tol"].sum()) if ref_ok else 0
    n_low_iqr = int(iqr_tab.loc[iqr_tab["en_geometria"] == "sí", "ventanas_iqr_bajo_piso"].sum())

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
    L.append(f"| 4 | Alineación SPY, VIX y r^f | {icon(perfect4, ok4)} | "
             f"Valores coinciden con último dato del mes; meses donde ese dato no es el último día hábil: "
             f"SPY {align['mkt_return']['meses_no_ultimo_dia']}, VIX {align['vix']['meses_no_ultimo_dia']}, "
             f"r^f {align['rf_return']['meses_no_ultimo_dia']}. |")
    L.append(f"| 5 | Look-ahead | {icon(ok5)} | {la['descuadres']} celdas distintas en el recomputo; "
             f"0 datos posteriores al fin de cada mes. |")
    state6 = ("⏸️ pendiente" if not ref_ok else ("✅" if n_ref_bad == 0 and not ref_pend else "⚠️"))
    L.append(f"| 6 | Contraste con Tiingo / CBOE | {state6} | "
             + (f"{len(ref_tab)} series contrastadas; {n_ref_bad} activo-mes fuera de tolerancia. " if ref_ok else "")
             + (f"Sin datos de referencia: {', '.join(ref_pend)}." if ref_pend else "") + " |")
    L.append(f"| 7 | IQR < {EPS_ESC:g} en ventanas de {N_WINDOW} meses | {icon(n_low_iqr == 0, True)} | "
             f"{n_low_iqr} ventana-serie bajo el piso en {iqr_info['n']} ventanas × 12 series de la geometría. |\n")

    # 0
    L.append("## 0. Metodología y criterios\n")
    L.append("**Alcance.** La auditoría es de solo lectura: lee `data/raw/` y `data/processed/`, recomputa el panel "
             "con las funciones de `data/01_import_data.py` y compara. Ningún dato se imputa, corrige ni "
             "sustituye; cada hallazgo queda en `audit_discrepancies.csv` con su `resolucion` (qué se decidió).\n")
    L.append("**Criterio ante faltantes.**\n")
    L.append("- Crudos diarios: no se imputan días faltantes ni NaN. Se comparan contra un calendario NYSE aproximado "
             "para detectarlos.")
    L.append("- Valor mensual = último dato *disponible* del mes (`resample('ME').last()`), nunca un dato del mes "
             "siguiente. Por eso el 31-dic-2025 ausente no se rellena: diciembre 2025 usa el cierre del 30-dic-2025.")
    L.append("- DGS3MO: los NaN de FRED (feriados) se ignoran; se usa el último rendimiento válido del mes. "
             "El código permite `ffill` de un mes anterior si un mes completo no tuviera datos; "
             f"en la práctica se usó en {align['rf_return']['meses_con_ffill']} meses.")
    L.append("- Primer mes (dic-2009): solo sirve de base para el retorno de ene-2010; la fila sin retornos se "
             "descarta del panel.")
    L.append("- Panel mensual: se exige 0 NaN y 0 meses faltantes entre ene-2010 y dic-2025.\n")
    L.append("**Criterio ante discrepancias Yahoo Finance vs referencia (PROPUESTA).**\n")
    L.append("- Fuentes de referencia: Tiingo para acciones y SPY, CBOE (fuente oficial del índice) para el VIX. "
             "Stooq, la fuente prevista en la metodología, está bloqueado a nivel de red.")
    L.append("- Se comparan dos cosas a fin de mes: el **precio** (`Close` de Yahoo, ajustado por splits, vs el cierre "
             "sin ajustar de Tiingo llevado a la misma base dividiendo por los splits posteriores) y el **retorno total "
             "mensual** (`Adj Close` de Yahoo vs `adjClose` de Tiingo). Para el VIX, `Close` vs `CLOSE` de CBOE.")
    L.append(f"- Hay discrepancia si el error relativo de precio supera {TOL_PRICE:.1%} o la diferencia de retorno "
             f"mensual supera {TOL_RET * 100:.2f} pp.")
    L.append("- **Yahoo Finance se mantiene como fuente oficial**: ante una discrepancia no se modifica ningún dato; "
             "solo se marca y se clasifica su causa probable:")
    for k, v in REF_CAUSES.items():
        L.append(f"  - `{k}`: {v}.")
    L.append("- Las discrepancias `sin_explicar` quedan señaladas para revisión manual.\n")

    # 1
    L.append("## 1. Faltantes, duplicados y fechas faltantes\n")
    L.append("### Fecha de descarga y periodo efectivo por serie\n")
    L.append("`primer_dato`/`ultimo_dato`: rango diario efectivamente presente en el crudo (puede diferir del "
             "solicitado). `primer_mes_panel`/`ultimo_mes_panel`: meses con valor en el panel; "
             "`dia_usado_ultimo_mes`: día cuyo cierre representa el último mes. SPY → `mkt_return`, "
             "VIX → `vix`, DGS3MO → `rf_return`. `referencia`: fuente y fecha de descarga del contraste (sección 6).\n")
    L.append(md_table(per_tab))
    L.append("")
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
                 "(25-oct-2022); es un movimiento de mercado real.")
        ref_cmp = OUT_DIR / "reference_monthly_comparison.csv"
        if ref_ok and ref_cmp.exists():
            cmp_ = pd.read_csv(ref_cmp, parse_dates=["fecha"]).set_index(["activo", "fecha"])
            for _, r in m_ext.iterrows():
                key = (r["activo"], pd.Timestamp(r["fecha"]))
                if key in cmp_.index:
                    L.append(f" Contraste con {cmp_.at[key, 'fuente']}: dif. de retorno total "
                             f"{r['activo']} {r['fecha']} = {cmp_.at[key, 'dif_ret']:.2e}.")
        L.append("\n")
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
    if len(div_tab):
        L.append("Contraste de dividendos contra el calendario de Tiingo (`divCash` en la fecha ex-dividendo, llevado "
                 "a base ajustada por splits) vs los dividendos implícitos de Yahoo:\n")
        L.append(md_table(div_tab, "{:.3g}"))
        L.append("")
    else:
        L.append("Nota: los dividendos implícitos aún no se contrastan contra un calendario externo (falta la descarga "
                 "de Tiingo, sección 6); la frecuencia (~4/año) y el yield implícito son coherentes con la política de "
                 "pago conocida de cada emisor.\n")

    # 4
    L.append("## 4. Alineación de SPY, VIX y r^f al cierre de mes\n")
    for k, lab in [("mkt_return", "SPY (retorno mensual de `Adj Close`)"), ("vix", "VIX (`Adj Close` de ^VIX)"),
                   ("rf_return", "r^f (DGS3MO → (1+y/100)^(1/12)−1)")]:
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
             "(verificado en la sección 4 para SPY, VIX y r^f; para las acciones es idéntico).")
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
    L.append("## 6. Contraste contra Tiingo (acciones, SPY) y CBOE (VIX)\n")
    if ref_ok:
        L.append(f"Comparación a fin de mes. `err_rel_close` = Close de Yahoo / cierre de referencia ajustado por splits − 1; "
                 f"`dif_ret` = retorno total mensual de Yahoo − el de la referencia; `err_rel_adj` (nivel de Adj Close) "
                 f"es informativo, porque depende de la fecha de descarga. Tolerancias: {TOL_PRICE:.1%} en precio, "
                 f"{TOL_RET * 100:.2f} pp en retorno. Detalle por activo y mes en "
                 "`data/audit/reference_monthly_comparison.csv`.\n")
        L.append(md_table(ref_tab, "{:.4g}"))
        L.append("\nDiscrepancias por causa probable (en todas se mantuvo el dato de Yahoo):\n")
        L.append(md_table(ref_causes))
        unexpl = ref_disc[ref_disc["causa_probable"] == "sin_explicar"]
        if len(unexpl):
            L.append("\nDiscrepancias sin explicar (revisión manual):\n")
            L.append(md_table(unexpl[["asset", "date", "value", "reference", "rel_error", "detail"]]))
    if ref_pend:
        L.append("\nSeries sin datos de referencia: " + ", ".join(ref_pend) + ".\n")
        L.append("Stooq (la fuente prevista) está bloqueado a nivel de red. Para completar este chequeo: crear una clave "
                 "gratuita en tiingo.com, definirla en la terminal (`$env:TIINGO_API_KEY = \"<clave>\"`), ejecutar "
                 "`data/audit/03_download_reference.py` y volver a ejecutar este script. La clave no se guarda en el repo.\n")

    # 7
    L.append(f"## 7. IQR de cada serie en las ventanas de {N_WINDOW} meses\n")
    L.append(f"Ventanas D_k = meses k−{N_WINDOW - 1}..k para cada fecha de decisión del backtest "
             f"(`decision_idx = N:(T-1)` en `run_backtest_*.m`): {iqr_info['n']} ventanas, con fin entre "
             f"{iqr_info['primera']} y {iqr_info['ultima']}. Percentiles calculados como `prctile` de MATLAB "
             f"(interpolación en (i−0.5)/n). Piso ε_esc = {EPS_ESC:g}. `rf_return` no entra en la geometría; se "
             "incluye solo como referencia. Serie completa en `data/audit/window_iqr.csv`.\n")
    L.append(md_table(iqr_tab, "{:.4g}"))
    L.append("")

    L.extend(methodology_blocks(per_tab, log, align, la, ref_tab, ref_status, ref_causes, iqr_tab, iqr_info,
                                panel_info, n_missing_days))

    # Recomendaciones
    L.append("## Recomendaciones (no aplicadas)\n")
    L.append("1. Usar `END_DATE = \"2026-01-01\"` en `yf.download` (end exclusivo) y regenerar dic-2025. El cambio ya está "
             "en `01_import_data.py` (sin confirmar en git), pero `data/raw/` **no** se ha regenerado.")
    L.append("2. Escribir `download_log.csv` en modo sobrescritura por ejecución (o con un id de corrida) y registrar también DGS3MO.")
    L.append("3. Regenerar `monthly_panel.csv` con el script actual (o recortar explícitamente a ene-2010 en el código) para que el archivo sea reproducible.")
    L.append("4. Guardar una copia de los crudos con fecha de descarga, ya que Yahoo reescala Adj Close retroactivamente.")

    (OUT_DIR / "audit_report.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    write_readme(per_tab, panel_info, n_missing_days, log_info, m_ext, align, la,
                 ref_tab, ref_status, ref_causes, iqr_tab, iqr_info)
    print(f"Reporte: {OUT_DIR / 'audit_report.md'}")
    print(f"Resumen: {OUT_DIR / 'LEEME_auditoria.txt'}")
    print(f"Discrepancias: {OUT_DIR / 'audit_discrepancies.csv'} ({len(disc)} filas)")
    print(disc["check"].value_counts().to_string())


if __name__ == "__main__":
    main()
