# Reporte de auditoría de datos — Wasserstein-Kelly

Generado por `data/audit/02_audit_data.py` el 2026-10-16. No se modificó ningún archivo en `data/raw/` ni `data/processed/`. Discrepancias detalladas en `data/audit/audit_discrepancies.csv` (28 filas).

## Resumen ejecutivo

| # | Chequeo | Estado | Resumen |
|---|---|---|---|
| 1 | Faltantes / duplicados / fechas | ⚠️ | Panel: 192 meses, 0 NaN, 0 meses faltantes. Crudos: 12 pares archivo-día hábil NYSE ausentes (días: 2025-12-31); sin NaN ni duplicados. Log de descarga con 12 filas duplicadas. |
| 2 | Retornos extremos > 30% | ⚠️ | 1 mensuales, 0 diarios. |
| 3 | Adj Close con dividendos y splits | ✅ | 0 caídas del ratio Adj/Close; 5/5 splits correctamente ajustados. |
| 4 | Alineación VIX y r^f | ⚠️ | Valores coinciden con último dato del mes; meses donde ese dato no es el último día hábil: VIX 1, r^f 0. |
| 5 | Look-ahead | ✅ | 0 celdas distintas en el recomputo; 0 datos posteriores al fin de cada mes. |
| 6 | Contraste con Stooq | ⏸️ pendiente | Stooq bloquea la descarga automática; ver sección 6. |

## 1. Faltantes, duplicados y fechas faltantes

### Crudos diarios (Yahoo Finance)

Calendario de referencia: días hábiles NYSE aproximados (feriados federales de bolsa, Viernes Santo, Juneteenth desde 2022 y cierres especiales 2012-10-29/30, 2018-12-05, 2025-01-09).

| activo | n | primero | ultimo | NaN | duplicados | monotono | faltan_vs_NYSE | extra_vs_NYSE | faltan_vs_union | precios_no_pos | volumen_cero |
|---|---|---|---|---|---|---|---|---|---|---|---|
| AAPL | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| MSFT | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| AMZN | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| JPM | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| JNJ | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| XOM | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| PG | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| CAT | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| KO | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| WMT | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| SPY | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |
| VIX | 4045 | 2009-12-01 | 2025-12-30 | 0 | 0 | True | 1 | 0 | 0 | 0 | 0 |


Días hábiles ausentes (unión de activos): 2025-12-31.  
Fechas extra vs. calendario: ninguna.

> **Hallazgo:** `yf.download(..., end='2025-12-31')` trata `end` como exclusivo, así que el 31-dic-2025 (día hábil) no se descargó. El "cierre de diciembre 2025" de acciones, SPY y VIX es en realidad el del 30-dic-2025.

### DGS3MO (FRED)

| n | NaN | primero | ultimo | duplicados | dias_habiles_ausentes | huecos_mayores_5d |
|---|---|---|---|---|---|---|
| 4197 | 174 | 2009-12-01 | 2025-12-31 | 0 | 0 | 0 |


Los NaN de DGS3MO corresponden a feriados de FRED (no afectan: se toma el último valor válido del mes).

### Panel mensual

| filas | primero | ultimo | duplicados | meses_faltantes | meses_extra | fechas_no_fin_de_mes | NaN_total |
|---|---|---|---|---|---|---|---|
| 192 | 2010-01-31 | 2025-12-31 | 0 | 0 | 0 | 0 | 0 |


### Log de descarga (`data/raw/download_log.csv`)

| filas | simbolos_unicos | filas_duplicadas | dgs3mo_registrado | n_rows_log |
|---|---|---|---|---|
| 24 | 12 | 12 | False | [4045] |


El log tiene cada símbolo dos veces (el script se ejecutó dos veces y el log se abre en modo append); `n_rows`=[4045] coincide con las filas de los CSV (4045). La descarga de DGS3MO no queda registrada.

## 2. Retornos mensuales extremos (|r| > 30%)

| fecha | activo | retorno |
|---|---|---|
| 2022-10-31 | CAT | 0.328062 |


Ninguno proviene de un error de ajuste: no hay retornos diarios > 30 % y el retorno con `Close` es consistente con el de `Adj Close`. CAT oct-2022 (+32.8 %) coincide con su reporte del 3T-2022 (25-oct-2022); es un movimiento de mercado real. Conviene confirmarlo también contra Stooq (sección 6).


Cinco mayores |r| mensuales del panel (contexto):

| fecha | activo | retorno |
|---|---|---|
| 2022-10-31 | CAT | 0.328062 |
| 2011-10-31 | CAT | 0.286334 |
| 2022-07-31 | AMZN | 0.270596 |
| 2022-10-31 | XOM | 0.269156 |
| 2020-04-30 | AMZN | 0.2689 |


Retornos **diarios** con |r| > 30% (en Adj Close o Close; detectaría splits sin ajustar):

_(sin filas)_


## 3. ¿Adj Close incorpora dividendos y splits?

Método: el ratio `Adj Close / Close` debe ser creciente en el tiempo, con saltos solo en fechas ex-dividendo (dividendo implícito `D = Close_{t-1}·(1 − ratio_{t-1}/ratio_t)`). `Close` de Yahoo ya viene ajustado por splits, por lo que ninguna de las dos series debe saltar en la fecha de un split. `TR−PR` es la diferencia media anual entre el retorno total (Adj Close) y el de precio (Close).

| activo | ratio_inicio | ratio_fin | eventos_div | div_por_año_mediana | yield_implicito_medio | TR_menos_PR_anual_medio | caidas_ratio |
|---|---|---|---|---|---|---|---|
| AAPL | 0.8375 | 0.9973 | 54 | 4 | 0.01084 | 0.01381 | 0 |
| MSFT | 0.744 | 0.9956 | 64 | 4 | 0.0182 | 0.02199 | 0 |
| AMZN | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| JPM | 0.6562 | 0.986 | 64 | 4 | 0.02467 | 0.02997 | 0 |
| JNJ | 0.618 | 0.989 | 64 | 4 | 0.02935 | 0.03227 | 0 |
| XOM | 0.5405 | 0.9867 | 64 | 4 | 0.03778 | 0.04044 | 0 |
| PG | 0.6149 | 0.9782 | 64 | 4 | 0.02891 | 0.03125 | 0 |
| CAT | 0.667 | 0.9939 | 64 | 4 | 0.02452 | 0.02987 | 0 |
| KO | 0.6033 | 0.9868 | 64 | 4 | 0.03071 | 0.03307 | 0 |
| WMT | 0.7106 | 0.9961 | 65 | 4 | 0.02072 | 0.02351 | 0 |
| SPY | 0.7423 | 0.9947 | 65 | 4 | 0.01808 | 0.02036 | 0 |


Splits conocidos en la ventana:

| activo | fecha | ratio | r_close | r_adj | salto_sin_ajuste | ajustado |
|---|---|---|---|---|---|---|
| AAPL | 2014-06-09 | 7:1 | 1.6001% | 1.6001% | -85.7143% | True |
| AAPL | 2020-08-31 | 4:1 | 3.3912% | 3.3912% | -75.0000% | True |
| AMZN | 2022-06-06 | 20:1 | 1.9943% | 1.9943% | -95.0000% | True |
| KO | 2012-08-13 | 2:1 | -0.2412% | -0.2411% | -50.0000% | True |
| WMT | 2024-02-26 | 3:1 | 1.8455% | 1.8455% | -66.6667% | True |


VIX: Adj Close ≠ Close en 0 días (debe ser 0).

Nota: los dividendos implícitos no se contrastaron contra un calendario externo de dividendos (yfinance no está instalado en este entorno); la frecuencia (~4/año) y el yield implícito son coherentes con la política de pago conocida de cada emisor.

## 4. Alineación del VIX y r^f al cierre de mes

**VIX (`Adj Close` de ^VIX):** 192 meses comparados; máx. |panel − recomputo| = 3.55e-15; descuadres = 0; meses cuyo último dato no es el último día hábil = 1; datos posteriores al fin de mes = 0.  
Meses afectados (mes, último dato usado, último día hábil esperado): 2025-12: 2025-12-30 vs 2025-12-31

**r^f (DGS3MO → (1+y/100)^(1/12)−1):** 192 meses comparados; máx. |panel − recomputo| = 9.89e-17; descuadres = 0; meses cuyo último dato no es el último día hábil = 0; datos posteriores al fin de mes = 0.  


Referencia de "último día hábil": calendario NYSE (feriados como Memorial Day o Viernes Santo, en que FRED publica NaN, no cuentan). En todos los casos se usó el último dato *disponible* del mes, que es lo que exige la ecuación 58; no se usan datos de meses posteriores.

Meses de r^f rellenados con ffill: 0; meses con r^f = 0 exacto: 2015-09-30; meses con r^f < 1 pb: 79 (tasas cercanas a cero 2010-2015 y 2020-2021; valores reales, no faltantes).

Nota metodológica: DGS3MO es un rendimiento anualizado en base *bond-equivalent*; la conversión `(1+y)^(1/12)−1` es una aproximación razonable (diferencias < 1 pb mensual).

## 5. Look-ahead

- Recomputo del panel desde `data/raw/` con las funciones de `data/01_import_data.py`: 2496 celdas comparadas, 0 distintas (máx. |dif| = 3.55e-15).
- `monthly_adj_close.csv` vs recomputo: máx. |dif| = 2.84e-14.
- Test de desplazamiento (error medio |panel − retornos desplazados s meses|): s=-1: 7.12e-02, s=0: 7.42e-17, s=1: 7.12e-02 → el panel coincide solo con s=0 (sin adelanto ni rezago).
- Todos los valores del mes m usan `resample('ME').last()`, es decir, datos con fecha ≤ fin de m (verificado en la sección 4 para VIX y r^f; para precios es idéntico).
- Fechas en los crudos posteriores a END=2025-12-31: 0; posteriores a la fecha de descarga (2026-08-12): 0.
- El código actual produciría también la(s) fila(s) 2009-12-31 (retornos NaN, VIX y r^f válidos) que **no** están en el CSV guardado: el CSV fue generado con una versión ligeramente distinta del script o recortado después. No afecta a MATLAB (que espera ene-2010 como primera fila), pero el código y el archivo no son reproducibles 1:1.
- Uso en MATLAB (`run_backtest_wdro_kelly.m`): en la fecha k se usan `R(k−N+1:k)` y `rf_return(k)` (tasa observada al cierre de k) para decidir, y se aplica `R(k+1)`; r^f de k se acumula durante k+1, lo cual es conocido ex-ante → sin look-ahead. El VIX de la ventana (wdro-market) también usa k−N+1..k.
- Advertencia: Yahoo reescala `Adj Close` retroactivamente con cada nuevo dividendo; los *niveles* dependen de la fecha de descarga, pero los *retornos* no. No es look-ahead en retornos.

## 6. Contraste de precios de cierre contra Stooq


Activos sin datos de Stooq: AAPL (bloqueado (verificación JavaScript / sin CSV)), MSFT (bloqueado (verificación JavaScript / sin CSV)), AMZN (bloqueado (verificación JavaScript / sin CSV)), JPM (bloqueado (verificación JavaScript / sin CSV)), JNJ (bloqueado (verificación JavaScript / sin CSV)), XOM (bloqueado (verificación JavaScript / sin CSV)), PG (bloqueado (verificación JavaScript / sin CSV)), CAT (bloqueado (verificación JavaScript / sin CSV)), KO (bloqueado (verificación JavaScript / sin CSV)), WMT (bloqueado (verificación JavaScript / sin CSV)), SPY (error de red: <urlopen error [WinError 10060] Se produjo un error durante el intento de conexión ya que la parte conectada no respondió adecuadamente tras un periodo de tiempo, o bien se produjo un error en la conexión establecida ya que el host conectado no ha podido responder>), VIX (error de red: <urlopen error [WinError 10060] Se produjo un error durante el intento de conexión ya que la parte conectada no respondió adecuadamente tras un periodo de tiempo, o bien se produjo un error en la conexión establecida ya que el host conectado no ha podido responder>).

Stooq protege su endpoint CSV con una verificación JavaScript (proof-of-work), así que no se puede descargar desde un script. Para completar este chequeo, descargue manualmente desde el navegador `https://stooq.com/q/d/l/?s=<símbolo>&d1=20091201&d2=20251231&i=d` (símbolos: AAPL→`aapl.us`, MSFT→`msft.us`, AMZN→`amzn.us`, JPM→`jpm.us`, JNJ→`jnj.us`, XOM→`xom.us`, PG→`pg.us`, CAT→`cat.us`, KO→`ko.us`, WMT→`wmt.us`, SPY→`spy.us`, VIX→`^vix`) y guarde cada archivo como `data/audit/stooq_cache/<TICKER>.csv` (p. ej. `AAPL.csv`, `VIX.csv`). Luego vuelva a ejecutar el script.

## Recomendaciones (no aplicadas)

1. Usar `END_DATE = "2026-01-01"` en `yf.download` (end exclusivo) y regenerar dic-2025.
2. Escribir `download_log.csv` en modo sobrescritura por ejecución (o con un id de corrida) y registrar también DGS3MO.
3. Regenerar `monthly_panel.csv` con el script actual (o recortar explícitamente a ene-2010 en el código) para que el archivo sea reproducible.
4. Guardar una copia de los crudos con fecha de descarga, ya que Yahoo reescala Adj Close retroactivamente.
