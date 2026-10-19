"""
Descarga de precios de referencia para el contraste externo de la auditoría
(sustituye a Stooq, que está bloqueado a nivel de red; ver 03_download_stooq.py).

    Acciones y SPY -> Tiingo (https://api.tiingo.com), requiere clave gratuita.
    VIX            -> CBOE, CSV oficial del índice (sin clave).

Guarda data/audit/ref_cache/<TICKER>.csv con columnas comunes
    Date, Close, Adj Close, divCash, splitFactor, fuente
(`Close` de Tiingo es el cierre SIN ajustar; para el VIX, Adj Close = Close)
y data/audit/ref_cache/download_log.csv (la URL se guarda sin la clave).

Uso (desde la raíz del proyecto, PowerShell):
    $env:TIINGO_API_KEY = "<su clave>"
    .venv\\Scripts\\python -I data/audit/03_download_reference.py
La clave solo se lee de la variable de entorno; no se escribe en ningún archivo.
"""

import io
import os
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path

import certifi
import pandas as pd

OUT_DIR = Path(__file__).resolve().parent / "ref_cache"
OUT_DIR.mkdir(exist_ok=True)

START, END = "2009-12-01", "2025-12-31"
TICKERS = ["AAPL", "MSFT", "AMZN", "JPM", "JNJ", "XOM", "PG", "CAT", "KO", "WMT", "SPY"]
COLS = ["Close", "Adj Close", "divCash", "splitFactor", "fuente"]

TIINGO_URL = ("https://api.tiingo.com/tiingo/daily/{t}/prices"
              "?startDate={start}&endDate={end}&format=csv&resampleFreq=daily")
CBOE_URL = "https://cdn.cboe.com/api/global/us_indices/daily_prices/VIX_History.csv"


# El almacén de certificados de Python en Windows rechaza la cadena de CBOE
# ("certificate has expired"); se usa el paquete de certifi.
SSL_CTX = ssl.create_default_context(cafile=certifi.where())


def fetch(url):
    # urllib sigue la redirección 307 de CBOE por defecto
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return urllib.request.urlopen(req, timeout=60, context=SSL_CTX).read().decode("utf-8", "replace")


def tiingo(t, token):
    url = TIINGO_URL.format(t=t.lower(), start=START, end=END)
    txt = fetch(f"{url}&token={token}")
    if not txt.lstrip().lower().startswith("date"):
        raise ValueError(f"respuesta inesperada: {txt[:120]!r}")
    df = pd.read_csv(io.StringIO(txt))
    df["Date"] = pd.to_datetime(df["date"]).dt.tz_localize(None).dt.normalize()
    df = df.rename(columns={"close": "Close", "adjClose": "Adj Close"})
    df["fuente"] = "Tiingo"
    return df.set_index("Date")[COLS], url


def cboe_vix():
    df = pd.read_csv(io.StringIO(fetch(CBOE_URL)))
    df.columns = [c.strip().upper() for c in df.columns]
    df["Date"] = pd.to_datetime(df["DATE"], format="%m/%d/%Y")
    df = df.set_index("Date").loc[START:END]
    out = pd.DataFrame({"Close": df["CLOSE"], "Adj Close": df["CLOSE"],
                        "divCash": pd.NA, "splitFactor": pd.NA, "fuente": "CBOE"})
    return out, CBOE_URL


def main():
    token = os.environ.get("TIINGO_API_KEY", "").strip()
    jobs = [("VIX", cboe_vix)]
    if token:
        jobs += [(t, lambda t=t: tiingo(t, token)) for t in TICKERS]
    else:
        print("TIINGO_API_KEY no está definida: solo se descarga el VIX de CBOE.\n"
              "Defínala con  $env:TIINGO_API_KEY = \"<su clave>\"  y vuelva a ejecutar.")

    today = pd.Timestamp.today().date()
    log, failed = [], {}
    for t, job in jobs:
        try:
            df, url = job()
        except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
            failed[t] = f"{type(e).__name__}: {e}"
            print(f"{t:<5} ERROR  {failed[t]}")
            continue
        df = df.sort_index()
        df.index.name = "Date"
        df.to_csv(OUT_DIR / f"{t}.csv")
        log.append(dict(symbol=t, source=df["fuente"].iloc[0], url=url, download_date=today,
                        n_rows=len(df), first=df.index.min().date(), last=df.index.max().date()))
        print(f"{t:<5} OK     {len(df)} filas, {df.index.min().date()} -> {df.index.max().date()}")

    if log:
        # se conserva la última descarga de cada símbolo (sin duplicar filas entre ejecuciones)
        path = OUT_DIR / "download_log.csv"
        new = pd.DataFrame(log)
        if path.exists():
            old = pd.read_csv(path)
            new = pd.concat([old[~old["symbol"].isin(new["symbol"])], new])
        new.to_csv(path, index=False)

    print(f"\nDescargados: {len(log)}/{len(jobs)} en {OUT_DIR}")
    if failed:
        print("Fallidos: " + ", ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
