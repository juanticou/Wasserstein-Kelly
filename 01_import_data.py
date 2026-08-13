"""
Importación y construcción de datos mensuales
Propuesta de Práctica Investigativa - Portafolios Wasserstein-Kelly

Descarga precios diarios (acciones, SPY), VIX y la tasa de Tesoro a 3 meses,
y construye el panel mensual descrito en la Sección 15 de la propuesta.

Requisitos:
    pip install yfinance pandas pandas_datareader numpy

Nota: pandas_datareader + FRED requiere acceso a fred.stlouisfed.org.
Si falla, se ofrece una ruta alterna descargando el CSV directamente.
"""

import os
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd
import yfinance as yf

# ---------------------------------------------------------------------------
# 1. Configuración (Sección 15 de la propuesta)
# ---------------------------------------------------------------------------

TICKERS = ["AAPL", "MSFT", "AMZN", "JPM", "JNJ", "XOM", "PG", "CAT", "KO", "WMT"]
MARKET_TICKER = "SPY"
VIX_TICKER = "^VIX"
FRED_SERIES_RF = "DGS3MO"  # Tasa del Tesoro a 3 meses (FRED)

START_DATE = "2009-12-01"   # precios diarios desde diciembre de 2009
END_DATE = "2025-12-31"     # hasta diciembre de 2025

RAW_DIR = Path("data/raw")
PROC_DIR = Path("data/processed")
RAW_DIR.mkdir(parents=True, exist_ok=True)
PROC_DIR.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# 2. Descarga desde Yahoo Finance (acciones, SPY, VIX)
# ---------------------------------------------------------------------------

def download_yahoo(ticker: str, start: str, end: str) -> pd.DataFrame:
    """Descarga OHLCV diario para un ticker y conserva el archivo crudo."""
    df = yf.download(
        ticker,
        start=start,
        end=end,
        auto_adjust=False,   # conservamos Close y Adj Close por separado
        progress=False,
    )
    if df.empty:
        raise ValueError(f"No se obtuvieron datos para {ticker}. Verifique el símbolo.")

    # yfinance a veces devuelve columnas multiindex incluso para un solo ticker
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)

    df.index.name = "Date"

    raw_path = RAW_DIR / f"{ticker.replace('^', '')}_daily.csv"
    df.to_csv(raw_path)

    # Registro mínimo de procedencia, tal como pide la Sección 15.4
    log_path = RAW_DIR / "download_log.csv"
    log_row = pd.DataFrame([{
        "symbol": ticker,
        "source": "Yahoo Finance",
        "start_requested": start,
        "end_requested": end,
        "download_date": datetime.today().strftime("%Y-%m-%d"),
        "file": str(raw_path),
        "n_rows": len(df),
    }])
    header = not log_path.exists()
    log_row.to_csv(log_path, mode="a", header=header, index=False)

    return df


def download_all_yahoo(tickers, market_ticker, vix_ticker, start, end):
    prices = {}
    for t in tickers + [market_ticker, vix_ticker]:
        print(f"Descargando {t} ...")
        prices[t] = download_yahoo(t, start, end)
    return prices


# ---------------------------------------------------------------------------
# 3. Descarga de la tasa de Tesoro a 3 meses (FRED, DGS3MO)
# ---------------------------------------------------------------------------

def download_fred_series(series_id: str, start: str, end: str) -> pd.Series:
    """
    Descarga una serie de FRED. Intenta primero con pandas_datareader;
    si no está disponible, usa el endpoint CSV directo de FRED.
    """
    try:
        import pandas_datareader.data as web
        s = web.DataReader(series_id, "fred", start, end)[series_id]
    except Exception as e:
        print(f"pandas_datareader falló ({e}); intentando CSV directo de FRED...")
        url = (
            f"https://fred.stlouisfed.org/graph/fredgraph.csv?id={series_id}"
        )
        df = pd.read_csv(url, index_col=0, parse_dates=True)
        s = df[series_id]
        s = s.loc[start:end]

    s.index.name = "Date"
    s.name = series_id
    s = pd.to_numeric(s, errors="coerce")  # FRED usa "." para NA

    raw_path = RAW_DIR / f"{series_id}_daily.csv"
    s.to_csv(raw_path)
    return s


# ---------------------------------------------------------------------------
# 4. Construcción de retornos mensuales (Sección 15.5-15.8)
# ---------------------------------------------------------------------------

def to_monthly_last(series: pd.Series) -> pd.Series:
    """Último valor disponible de cada mes calendario."""
    return series.resample("ME").last()


def monthly_simple_return(monthly_prices: pd.Series) -> pd.Series:
    """r_{j,m} = P_{j,m}/P_{j,m-1} - 1  (ecuación 55)."""
    return monthly_prices.pct_change()


def build_stock_monthly_returns(prices: dict, tickers: list) -> pd.DataFrame:
    adj_close = {t: prices[t]["Adj Close"] for t in tickers}
    adj_close = pd.DataFrame(adj_close)
    monthly_px = adj_close.resample("ME").last()
    monthly_ret = monthly_px.pct_change()
    return monthly_ret, monthly_px


def build_market_return(prices: dict, market_ticker: str) -> pd.Series:
    """m_m = P^M_m / P^M_{m-1} - 1  (ecuación 56)."""
    px = prices[market_ticker]["Adj Close"]
    monthly_px = px.resample("ME").last()
    return monthly_px.pct_change().rename("mkt_return")


def build_vix_monthly(prices: dict, vix_ticker: str) -> pd.Series:
    """V_m: último valor diario del VIX en el mes (ecuación 57)."""
    vix = prices[vix_ticker]["Adj Close"]
    return vix.resample("ME").last().rename("vix")


def build_riskfree_monthly(rf_daily: pd.Series) -> pd.Series:
    """
    r^f_k = (1 + y_k/100)^(1/12) - 1   (ecuación 58)
    y_k: última observación disponible de DGS3MO hasta el cierre del mes.
    """
    y_monthly = rf_daily.resample("ME").last().ffill()
    rf_monthly = (1 + y_monthly / 100.0) ** (1 / 12) - 1
    return rf_monthly.rename("rf_return")


# ---------------------------------------------------------------------------
# 5. Auditoría mínima (Sección 15.4)
# ---------------------------------------------------------------------------

def audit_report(monthly_ret: pd.DataFrame, mkt_ret: pd.Series, vix: pd.Series,
                  rf: pd.Series) -> pd.DataFrame:
    panel = monthly_ret.copy()
    panel["mkt_return"] = mkt_ret
    panel["vix"] = vix
    panel["rf_return"] = rf

    report = pd.DataFrame({
        "n_missing": panel.isna().sum(),
        "n_obs": panel.notna().sum(),
        "min": panel.min(numeric_only=True),
        "max": panel.max(numeric_only=True),
        "first_valid": panel.apply(lambda c: c.first_valid_index()),
        "last_valid": panel.apply(lambda c: c.last_valid_index()),
    })
    report.to_csv(PROC_DIR / "audit_report.csv")
    return report


# ---------------------------------------------------------------------------
# 6. Ejecución principal
# ---------------------------------------------------------------------------

def main():
    print("=== Descarga de precios diarios (Yahoo Finance) ===")
    prices = download_all_yahoo(TICKERS, MARKET_TICKER, VIX_TICKER, START_DATE, END_DATE)

    print("=== Descarga de tasa de bajo riesgo (FRED: DGS3MO) ===")
    rf_daily = download_fred_series(FRED_SERIES_RF, START_DATE, END_DATE)

    print("=== Construcción de retornos mensuales ===")
    stock_ret_monthly, stock_px_monthly = build_stock_monthly_returns(prices, TICKERS)
    mkt_ret_monthly = build_market_return(prices, MARKET_TICKER)
    vix_monthly = build_vix_monthly(prices, VIX_TICKER)
    rf_monthly = build_riskfree_monthly(rf_daily)

    # Panel mensual consolidado (retornos mensuales enero 2010 - diciembre 2025)
    panel = stock_ret_monthly.copy()
    panel["mkt_return"] = mkt_ret_monthly
    panel["vix"] = vix_monthly
    panel["rf_return"] = rf_monthly
    panel = panel.dropna(how="all")

    panel.to_csv(PROC_DIR / "monthly_panel.csv")
    stock_px_monthly.to_csv(PROC_DIR / "monthly_adj_close.csv")

    print("=== Auditoría mínima ===")
    report = audit_report(stock_ret_monthly, mkt_ret_monthly, vix_monthly, rf_monthly)
    print(report)

    print(f"\nPanel mensual guardado en: {PROC_DIR / 'monthly_panel.csv'}")
    print(f"Rango de fechas: {panel.index.min().date()} -> {panel.index.max().date()}")
    print(f"Número de meses: {len(panel)}")

    return panel


if __name__ == "__main__":
    monthly_panel = main()
