"""
Tercera fuente (Alpha Vantage) para las discrepancias Yahoo vs Tiingo en las acciones.

La serie diaria completa de Alpha Vantage es de pago (outputsize=full es premium; ver
alphavantage_cache/download_log.csv del 2026-10-21), así que se usa TIME_SERIES_MONTHLY,
gratuita y con historia completa: cierre SIN ajustar del último día hábil de cada mes.
Cubre el evento de fin de mes AAPL 2015-09-30 (y contrasta todos los fines de mes de las
10 acciones y SPY, que es lo que entra al panel). No cubre el VIX ni los eventos intra-mes.

Uso (desde la raíz del proyecto, PowerShell):
    $env:ALPHAVANTAGE_API_KEY = "<su_clave>"
    .venv\\Scripts\\python -I data/audit_2026-01-01/discrepancias/tercera_fuente_alphavantage.py
La clave solo se lee de la variable de entorno; no se escribe en ningún archivo.
Las series ya guardadas en la caché no se vuelven a descargar.
"""

import os
import ssl
import sys
import time
import urllib.request
from datetime import date
from pathlib import Path

import certifi
import pandas as pd

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = ROOT / "data" / "raw_2026-01-01"
REF = ROOT / "data" / "audit" / "ref_cache"
CACHE = HERE / "alphavantage_cache"
CACHE_M = CACHE / "mensual"
CACHE_M.mkdir(parents=True, exist_ok=True)

TICKERS = ["AAPL", "MSFT", "AMZN", "JPM", "JNJ", "XOM", "PG", "CAT", "KO", "WMT", "SPY"]
AV_URL = ("https://www.alphavantage.co/query?function=TIME_SERIES_MONTHLY"
          "&symbol={t}&datatype=csv")
START, END = "2009-12-01", "2025-12-31"
TOL = 0.0005            # 0.05 %
PAUSE = 15              # segundos entre llamadas (límite por minuto del plan gratuito)
EVENT = ("AAPL", "2015-09")                       # evento de fin de mes a resolver
CONTROLS = [("MSFT", "2015-09"), ("SPY", "2015-09"), ("AAPL", "2015-08"), ("AAPL", "2015-10")]
SSL_CTX = ssl.create_default_context(cafile=certifi.where())


def later_split_factor(ref):
    """Igual que data/audit/02_audit_data.py: splits de Tiingo posteriores a cada fecha."""
    sf = ref["splitFactor"].fillna(1.0)
    return sf[::-1].cumprod()[::-1].shift(-1).fillna(1.0)


def download(t, key, log):
    url = AV_URL.format(t=t)
    req = urllib.request.Request(f"{url}&apikey={key}", headers={"User-Agent": "Mozilla/5.0"})
    txt = urllib.request.urlopen(req, timeout=60, context=SSL_CTX).read().decode("utf-8", "replace")
    ok = txt.lstrip().lower().startswith("timestamp")
    if ok:
        (CACHE_M / f"{t}.csv").write_text(txt, encoding="utf-8")
    log.append(dict(simbolo=t, fecha_descarga=date.today().isoformat(), url=url,
                    estado="ok" if ok else "error", respuesta="" if ok else txt[:200].replace("\n", " ")))
    print(f"{t}: {'ok' if ok else 'ERROR ' + txt[:200]}")


def last_of_month(s):
    """Último valor de cada mes, indexado por periodo, con la fecha del día usado."""
    s = s.dropna()
    g = s.groupby(s.index.to_period("M"))
    return pd.DataFrame(dict(valor=g.last(), dia=g.apply(lambda x: x.index.max())))


def main():
    key = os.environ.get("ALPHAVANTAGE_API_KEY")
    pending = [t for t in TICKERS if not (CACHE_M / f"{t}.csv").exists()]
    if pending and not key:
        sys.exit("Defina ALPHAVANTAGE_API_KEY (faltan: " + ", ".join(pending) + ")")
    log = []
    for i, t in enumerate(pending):
        if i:
            time.sleep(PAUSE)
        download(t, key, log)
    if log:
        lp = CACHE / "download_log.csv"
        pd.DataFrame(log).to_csv(lp, mode="a", header=not lp.exists(), index=False)

    rows, summary = [], []
    for t in TICKERS:
        path = CACHE_M / f"{t}.csv"
        if not path.exists():
            summary.append(dict(serie=t, estado="sin dato"))
            continue
        y = pd.read_csv(RAW / f"{t}_daily.csv", index_col="Date", parse_dates=True).loc[START:END]
        ref = pd.read_csv(REF / f"{t}.csv", index_col="Date", parse_dates=True).sort_index().loc[START:END]
        later = later_split_factor(ref)
        ym = last_of_month(y["Close"] * later.reindex(y.index))       # Yahoo llevado a base sin ajustar
        tm = last_of_month(ref["Close"])
        av = pd.read_csv(path, index_col="timestamp", parse_dates=True).sort_index().loc[START:END, "close"]
        am = last_of_month(av)
        for p in ym.index.intersection(am.index):
            yv, tv, avv = ym.at[p, "valor"], tm["valor"].get(p, float("nan")), am.at[p, "valor"]
            rows.append(dict(serie=t, mes=str(p), dia_yahoo=ym.at[p, "dia"].date(),
                             dia_av=am.at[p, "dia"].date(), yahoo_sin_ajustar=yv, tiingo=tv,
                             alphavantage=avv, av_vs_yahoo=avv / yv - 1, av_vs_tiingo=avv / tv - 1))
        summary.append(dict(serie=t, estado="ok", meses=len(ym.index.intersection(am.index))))
    out = pd.DataFrame(rows)
    if out.empty:
        print(pd.DataFrame(summary).to_string(index=False))
        return
    out["coincide_yahoo"] = out["av_vs_yahoo"].abs() <= TOL
    out["coincide_tiingo"] = out["av_vs_tiingo"].abs() <= TOL
    out["mismo_dia"] = out["dia_yahoo"] == out["dia_av"]
    out.to_csv(HERE / "tercera_fuente_av_mensual.csv", index=False)

    s = out.groupby("serie", sort=False).agg(
        meses=("mes", "size"), dia_distinto=("mismo_dia", lambda x: int((~x).sum())),
        av_distinta_yahoo=("coincide_yahoo", lambda x: int((~x).sum())),
        av_distinta_tiingo=("coincide_tiingo", lambda x: int((~x).sum())),
        max_abs_av_vs_yahoo=("av_vs_yahoo", lambda x: x.abs().max()))
    print("== Resumen por serie (fines de mes 2009-12 a 2025-12) ==")
    print(s.to_string())

    print("\n== Meses donde Alpha Vantage no coincide con Yahoo o con Tiingo ==")
    bad = out[~out["coincide_yahoo"] | ~out["coincide_tiingo"] | ~out["mismo_dia"]]
    print(bad.to_string(index=False) if len(bad) else "(ninguno)")

    print("\n== Evento AAPL 2015-09-30 y controles ==")
    keys = [EVENT] + CONTROLS
    ev = out.set_index(["serie", "mes"]).reindex(keys)
    print(ev[["dia_yahoo", "yahoo_sin_ajustar", "tiingo", "alphavantage", "av_vs_yahoo",
              "av_vs_tiingo"]].to_string())
    ctrl_ok = all(ev.loc[k, "coincide_yahoo"] and ev.loc[k, "coincide_tiingo"]
                  for k in CONTROLS if k[0] == "AAPL")
    e = ev.loc[EVENT]
    if pd.isna(e["alphavantage"]):
        v = "sin dato"
    elif not ctrl_ok:
        v = "control no coincide (sin veredicto)"
    else:
        v = ("AV=Yahoo=Tiingo" if e["coincide_yahoo"] and e["coincide_tiingo"] else
             "AV=Yahoo" if e["coincide_yahoo"] else "AV=Tiingo" if e["coincide_tiingo"] else
             "AV distinta de ambas")
    print(f"\nVeredicto AAPL 2015-09-30: {v}")


if __name__ == "__main__":
    main()
