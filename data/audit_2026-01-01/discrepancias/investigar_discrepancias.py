"""
Investigación de las 4 discrepancias `sin_explicar` de la auditoría del 2026-10-21
(AAPL sep/oct-2015 y VIX ago/sep-2014). Solo lectura: no modifica datos existentes.

    1. Contraste DIARIO Yahoo vs referencia (Tiingo / CBOE) en las 12 series.
    3. Coherencia interna de Yahoo en los días en disputa (vs SPY y MSFT).
    5. Impacto en las ventanas de 60 meses (IQR y mediana) si se usara el valor de referencia.

Uso (desde la raíz del proyecto):
    .venv\\Scripts\\python -I data/audit_2026-01-01/discrepancias/investigar_discrepancias.py
"""

from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw_2026-01-01"
REF = ROOT / "data" / "audit" / "ref_cache"
PANEL = ROOT / "data" / "processed_2026-01-01" / "monthly_panel_hibrido.csv"
OUT = Path(__file__).resolve().parent

START, END = "2009-12-01", "2025-12-31"
SERIES = ["AAPL", "MSFT", "AMZN", "JPM", "JNJ", "XOM", "PG", "CAT", "KO", "WMT", "SPY", "VIX"]
TOL_PRICE, TOL_RET = 0.005, 0.0025      # mismas tolerancias que 02_audit_data.py
N_WINDOW = 60


def later_split_factor(ref):
    """Igual que 02_audit_data.py: splits de Tiingo posteriores a cada fecha."""
    sf = ref["splitFactor"].fillna(1.0)
    return sf[::-1].cumprod()[::-1].shift(-1).fillna(1.0)


def load(t):
    y = pd.read_csv(RAW / f"{t}_daily.csv", index_col="Date", parse_dates=True).sort_index()
    r = pd.read_csv(REF / f"{t}.csv", index_col="Date", parse_dates=True).sort_index()
    return y.loc[START:END], r.loc[START:END]


# ---------------------------------------------------------------------------
# 1. Contraste diario
# ---------------------------------------------------------------------------
rows, summary, daily = [], [], {}
for t in SERIES:
    y, r = load(t)
    later = pd.Series(1.0, index=r.index) if t == "VIX" else later_split_factor(r)
    rpx = r["Close"] / later
    idx = y.index.intersection(rpx.index)
    e = y.loc[idx, "Close"] / rpx[idx] - 1
    dret = y.loc[idx, "Adj Close"].pct_change() - r.loc[idx, "Adj Close"].pct_change()
    daily[t] = (y.loc[idx], rpx[idx], r.loc[idx, "Adj Close"])
    bad = (e.abs() > TOL_PRICE) | (dret.abs() > TOL_RET)
    for d in idx[bad.to_numpy()]:
        rows.append(dict(serie=t, fecha=d.date(), dia_semana=d.day_name(),
                         fin_de_mes=d == y.loc[d.strftime("%Y-%m")].index.max(),
                         yahoo_close=y.at[d, "Close"], ref_close_base_yahoo=rpx[d],
                         yahoo_low=y.at[d, "Low"], yahoo_high=y.at[d, "High"],
                         err_rel_close=e[d], dif_ret_diario=dret[d]))
    summary.append(dict(serie=t, dias=len(idx), solo_en_yahoo=len(y.index.difference(rpx.index)),
                        solo_en_ref=len(rpx.index.difference(y.index)),
                        dias_err_close_gt_0_1pct=int((e.abs() > 0.001).sum()),
                        dias_err_close_gt_0_5pct=int((e.abs() > TOL_PRICE).sum()),
                        dias_dif_ret_gt_0_25pp=int((dret.abs() > TOL_RET).sum()),
                        err_close_max=float(e.abs().max()), fecha_err_max=e.abs().idxmax().date()))

disc = pd.DataFrame(rows)
disc.to_csv(OUT / "discrepancias_diarias.csv", index=False)
summ = pd.DataFrame(summary)
summ.to_csv(OUT / "resumen_diario.csv", index=False)
print("== 1. Resumen diario ==")
print(summ.to_string(index=False))
print("\n== 1. Días fuera de tolerancia ==")
print(disc.to_string(index=False))

# ---------------------------------------------------------------------------
# 3. Coherencia interna en los días en disputa
# ---------------------------------------------------------------------------
print("\n== 3. Retornos diarios de cierre (Yahoo vs referencia) ==")
coh = []
for t, peers, days in [("AAPL", ["SPY", "MSFT"], ("2015-09-25", "2015-10-05")),
                       ("VIX", ["SPY"], ("2014-08-25", "2014-09-04"))]:
    for s in [t] + peers:
        y, rpx, _ = daily[s]
        ry = y["Close"].pct_change().loc[days[0]:days[1]]
        rr = rpx.pct_change().loc[days[0]:days[1]]
        for d in ry.index:
            coh.append(dict(evento=t, serie=s, fecha=d.date(), ret_yahoo=ry[d], ret_ref=rr[d]))
coh = pd.DataFrame(coh)
coh.to_csv(OUT / "coherencia_dias.csv", index=False)
print(coh.pivot_table(index=["evento", "fecha"], columns="serie",
                      values=["ret_yahoo", "ret_ref"]).round(5).to_string())

# ---------------------------------------------------------------------------
# 5. Impacto en ventanas de 60 meses
# ---------------------------------------------------------------------------
panel = pd.read_csv(PANEL, index_col="Date", parse_dates=True)
alt = panel.copy()
_, _, radj = daily["AAPL"]
m_aapl = radj.resample("ME").last().pct_change()
for d in ["2015-09-30", "2015-10-31"]:
    alt.at[pd.Timestamp(d), "AAPL"] = m_aapl[pd.Timestamp(d)]
alt.at[pd.Timestamp("2014-08-31"), "vix"] = daily["VIX"][1].loc["2014-08-29"]

print("\n== 5. Celdas del panel afectadas ==")
for d, c in [("2015-09-30", "AAPL"), ("2015-10-31", "AAPL"), ("2014-08-31", "vix")]:
    print(f"{c} {d}: panel={panel.at[pd.Timestamp(d), c]:.6f}  con_referencia={alt.at[pd.Timestamp(d), c]:.6f}")

imp = []
for k in range(N_WINDOW, len(panel)):              # igual que decision_idx = N:(T-1)
    end = panel.index[k - 1]
    for c in ["AAPL", "vix"]:
        a = panel[c].iloc[k - N_WINDOW:k].to_numpy()
        b = alt[c].iloc[k - N_WINDOW:k].to_numpy()
        if np.array_equal(a, b):
            continue
        qa = np.percentile(a, [25, 50, 75], method="hazen")
        qb = np.percentile(b, [25, 50, 75], method="hazen")
        imp.append(dict(fin_ventana=end.date(), anio_decision=end.year, serie=c,
                        periodo="validación" if end.year <= 2018 else "prueba",
                        iqr_panel=qa[2] - qa[0], iqr_ref=qb[2] - qb[0],
                        dif_rel_iqr=(qb[2] - qb[0]) / (qa[2] - qa[0]) - 1,
                        mediana_panel=qa[1], mediana_ref=qb[1], dif_mediana=qb[1] - qa[1]))
imp = pd.DataFrame(imp)
imp.to_csv(OUT / "impacto_ventanas.csv", index=False)
print("\n== 5. Ventanas afectadas ==")
print(imp.groupby(["serie", "periodo"]).agg(
    ventanas=("fin_ventana", "size"), primera=("fin_ventana", "min"), ultima=("fin_ventana", "max"),
    max_abs_dif_rel_iqr=("dif_rel_iqr", lambda s: s.abs().max()),
    max_abs_dif_mediana=("dif_mediana", lambda s: s.abs().max())).to_string())
