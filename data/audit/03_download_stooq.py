"""
Descarga de precios diarios de Stooq para el contraste de la auditoría.

Guarda data/audit/stooq_cache/<TICKER>.csv (Date,Open,High,Low,Close,Volume),
el formato que lee 02_audit_data.py.

pandas_datareader >= 0.11 eliminó el lector de Stooq; aquí se hace lo mismo que hacía
(leer con pandas el CSV de https://stooq.com/q/d/l/).

Uso (desde la raíz del proyecto):
    py data/audit/03_download_stooq.py
"""

import socket
from datetime import datetime
from pathlib import Path

import pandas as pd

OUT_DIR = Path(__file__).resolve().parent / "stooq_cache"
OUT_DIR.mkdir(exist_ok=True)
socket.setdefaulttimeout(30)   # read_csv sobre URL no tiene timeout propio

START = datetime(2009, 12, 1)
END = datetime(2025, 12, 31)

TICKERS = ["AAPL", "MSFT", "AMZN", "JPM", "JNJ", "XOM", "PG", "CAT", "KO", "WMT", "SPY"]
STOOQ_SYMBOL = {t: f"{t.lower()}.us" for t in TICKERS}
STOOQ_SYMBOL["VIX"] = "^vix"
URL = "https://stooq.com/q/d/l/?s={sym}&d1={d1:%Y%m%d}&d2={d2:%Y%m%d}&i=d"


def main():
    ok, failed = [], {}
    for t, sym in STOOQ_SYMBOL.items():
        try:
            df = pd.read_csv(URL.format(sym=sym, d1=START, d2=END),
                             index_col="Date", parse_dates=True)
        except (ValueError, pd.errors.ParserError):
            failed[t] = "Stooq no devolvió un CSV (verificación JavaScript)"
            print(f"{t:<5} ERROR  {failed[t]}")
            continue
        except OSError as e:          # sin conexión a Stooq: no tiene sentido seguir
            failed[t] = f"{type(e).__name__}: {e}"
            print(f"{t:<5} ERROR  {failed[t]}")
            print("Sin conexión a stooq.com; se omiten los tickers restantes.")
            break
        if df.empty:
            failed[t] = "respuesta vacía"
            print(f"{t:<5} ERROR  respuesta vacía")
            continue
        df = df.sort_index()
        df.index.name = "Date"
        df.to_csv(OUT_DIR / f"{t}.csv")
        ok.append(t)
        print(f"{t:<5} OK     {len(df)} filas, {df.index.min().date()} -> {df.index.max().date()}")

    print(f"\nDescargados: {len(ok)}/{len(STOOQ_SYMBOL)} en {OUT_DIR}")
    if failed:
        print("Fallidos: " + ", ".join(failed))


if __name__ == "__main__":
    main()
