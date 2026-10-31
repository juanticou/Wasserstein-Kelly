# Notas sobre la auditoría de la descarga del 2026-10-21

Comando (2026-10-21):
`py -B data/audit/02_audit_data.py --raw-dir data/raw_2026-01-01 --proc-dir data/processed_2026-01-01 --out-dir data/audit_2026-01-01`

Se audita la descarga nueva y su panel completo (`monthly_panel.csv`). El panel que usa `results_v2/` es `monthly_panel_hibrido.csv`. Su fila de dic-2025 es idéntica a la de este panel; ene-2010 a nov-2025 vienen de la línea base, auditada en `data/audit/`, y difieren de esta descarga en ≤ 1.4e-6 (`results_finales/r1_comparacion_panel.csv`).

## Resultado frente a la auditoría anterior (`data/audit/`)
| Chequeo | Línea base (30-dic) | Descarga nueva (31-dic) |
|---|---|---|
| Pares archivo-día hábil ausentes | 12 (todos el 31-dic-2025) | **0** |
| Filas duplicadas en `download_log.csv` | 12 | **0** |
| SPY / VIX cuyo dato de dic-2025 no es el último día hábil | 1 / 1 | **0 / 0** |
| Discrepancias contra Tiingo/CBOE | 14 (10 por el cierre de dic-2025 y 4 sin explicar) | **4** (las mismas sin explicar: AAPL sep y oct de 2015; VIX ago y sep de 2014) |
| Retornos mensuales > 30 % | 1 (CAT oct-2022) | 1 (el mismo) |
| Recomputo del panel desde los crudos | 0 de 2496 celdas distintas | 0 de 2496 |
| Test de desplazamiento | solo s=0 coincide | solo s=0 coincide |
| Splits ajustados | 5/5 | 5/5 |

## Falso ❌ en el chequeo 5 (look-ahead) y «ffill en 1 mes»
FRED trata la fecha final como **inclusiva**, a diferencia de yfinance. Con `--end 2026-01-01`, `DGS3MO_daily.csv` trae una fila del 2026-01-01 sin valor, porque es feriado. Por eso:
- el chequeo 5 cuenta «1 fecha posterior a END=2025-12-31» en los crudos y queda marcado ❌;
- el conteo de meses de r^f completados con ffill da 1, que es ene-2026, un mes vacío.

Ninguno de los dos afecta al panel. La fila de ene-2026 se descarta (`dropna(subset=TICKERS)`), el panel termina en 2025-12-31 y r^f es idéntico al de la línea base en los 192 meses. Además, `DGS3MO_daily.csv` coincide línea por línea con el de `data/raw/` hasta el 31-dic-2025. En el chequeo 5, las 2496 celdas recomputadas y el test de desplazamiento salen bien.

Posible corrección de código, **no aplicada**: en `01_import_data.py`, pedir a FRED hasta `end − 1 día`.

## Textos fijos de `02_audit_data.py` que no aplican a esta descarga
El reporte se generó con el script tal cual, así que estas frases están desactualizadas aquí:
- «Por eso el 31-dic-2025 ausente no se rellena: diciembre 2025 usa el cierre del 30-dic-2025»: en esta descarga no falta ningún día.
- «0 pares archivo-día ausentes (todos el 31-dic-2025)».
- «No se modificó ningún archivo en `data/raw/` ni `data/processed/`» y «Discrepancias detalladas en `data/audit/…`»: las rutas reales son `data/raw_2026-01-01/`, `data/processed_2026-01-01/` y `data/audit_2026-01-01/`.
- La fecha de descarga de DGS3MO se da como «no registrada (guardada en el commit del 2026-08-12)»; en esta descarga fue el 2026-10-21, la misma ejecución que Yahoo.
- `LEEME_auditoria.txt` contiene las mismas frases.

Las cifras de las tablas del reporte sí corresponden a esta descarga.
