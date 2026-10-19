# Reporte de auditoría de datos — Wasserstein-Kelly

Generado por `data/audit/02_audit_data.py` el 2026-10-19. No se modificó ningún archivo en `data/raw/` ni `data/processed/`. Discrepancias detalladas en `data/audit/audit_discrepancies.csv` (43 filas).

## Resumen ejecutivo

| # | Chequeo | Estado | Resumen |
|---|---|---|---|
| 1 | Faltantes / duplicados / fechas | ⚠️ | Panel: 192 meses, 0 NaN, 0 meses faltantes. Crudos: 12 pares archivo-día hábil NYSE ausentes (días: 2025-12-31); sin NaN ni duplicados. Log de descarga con 12 filas duplicadas. |
| 2 | Retornos extremos > 30% | ⚠️ | 1 mensuales, 0 diarios. |
| 3 | Adj Close con dividendos y splits | ✅ | 0 caídas del ratio Adj/Close; 5/5 splits correctamente ajustados. |
| 4 | Alineación SPY, VIX y r^f | ⚠️ | Valores coinciden con último dato del mes; meses donde ese dato no es el último día hábil: SPY 1, VIX 1, r^f 0. |
| 5 | Look-ahead | ✅ | 0 celdas distintas en el recomputo; 0 datos posteriores al fin de cada mes. |
| 6 | Contraste con Tiingo / CBOE | ⚠️ | 12 series contrastadas; 14 activo-mes fuera de tolerancia.  |
| 7 | IQR < 1e-06 en ventanas de 60 meses | ✅ | 0 ventana-serie bajo el piso en 132 ventanas × 12 series de la geometría. |

## 0. Metodología y criterios

**Alcance.** La auditoría es de solo lectura: lee `data/raw/` y `data/processed/`, recomputa el panel con las funciones de `data/01_import_data.py` y compara. Ningún dato se imputa, corrige ni sustituye; cada hallazgo queda en `audit_discrepancies.csv` con su `resolucion` (qué se decidió).

**Criterio ante faltantes.**

- Crudos diarios: no se imputan días faltantes ni NaN. Se comparan contra un calendario NYSE aproximado para detectarlos.
- Valor mensual = último dato *disponible* del mes (`resample('ME').last()`), nunca un dato del mes siguiente. Por eso el 31-dic-2025 ausente no se rellena: diciembre 2025 usa el cierre del 30-dic-2025.
- DGS3MO: los NaN de FRED (feriados) se ignoran; se usa el último rendimiento válido del mes. El código permite `ffill` de un mes anterior si un mes completo no tuviera datos; en la práctica se usó en 0 meses.
- Primer mes (dic-2009): solo sirve de base para el retorno de ene-2010; la fila sin retornos se descarta del panel.
- Panel mensual: se exige 0 NaN y 0 meses faltantes entre ene-2010 y dic-2025.

**Criterio ante discrepancias Yahoo Finance vs referencia (PROPUESTA).**

- Fuentes de referencia: Tiingo para acciones y SPY, CBOE (fuente oficial del índice) para el VIX. Stooq, la fuente prevista en la metodología, está bloqueado a nivel de red.
- Se comparan dos cosas a fin de mes: el **precio** (`Close` de Yahoo, ajustado por splits, vs el cierre sin ajustar de Tiingo llevado a la misma base dividiendo por los splits posteriores) y el **retorno total mensual** (`Adj Close` de Yahoo vs `adjClose` de Tiingo). Para el VIX, `Close` vs `CLOSE` de CBOE.
- Hay discrepancia si el error relativo de precio supera 0.5% o la diferencia de retorno mensual supera 0.25 pp.
- **Yahoo Finance se mantiene como fuente oficial**: ante una discrepancia no se modifica ningún dato; solo se marca y se clasifica su causa probable:
  - `fecha_fin_mes_distinta`: el último día con dato del mes difiere entre fuentes.
  - `mes_con_split`: el mes contiene un split conocido.
  - `ajuste_dividendos`: retorno distinto en un mes con fecha ex-dividendo (ajuste distinto).
  - `escala_ajuste`: solo difiere el nivel, no el retorno (factor de ajuste acumulado distinto según fecha de descarga).
  - `sin_explicar`: sin causa identificada; revisar manualmente.
- Las discrepancias `sin_explicar` quedan señaladas para revisión manual.

## 1. Faltantes, duplicados y fechas faltantes

### Fecha de descarga y periodo efectivo por serie

`primer_dato`/`ultimo_dato`: rango diario efectivamente presente en el crudo (puede diferir del solicitado). `primer_mes_panel`/`ultimo_mes_panel`: meses con valor en el panel; `dia_usado_ultimo_mes`: día cuyo cierre representa el último mes. SPY → `mkt_return`, VIX → `vix`, DGS3MO → `rf_return`. `referencia`: fuente y fecha de descarga del contraste (sección 6).

| serie | fuente | fecha_descarga | inicio_solicitado | fin_solicitado | primer_dato | ultimo_dato | n_dias | primer_mes_panel | ultimo_mes_panel | dia_usado_ultimo_mes | meses_validos | referencia |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AAPL | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| MSFT | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| AMZN | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| JPM | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| JNJ | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| XOM | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| PG | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| CAT | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| KO | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| WMT | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| SPY | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | Tiingo 2026-10-19 |
| VIX | Yahoo Finance | 2026-08-12 | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-30 | 4045 | 2010-01 | 2025-12 | 2025-12-30 | 192 | CBOE 2026-10-19 |
| DGS3MO | FRED | no registrada (guardada en el commit del 2026-08-12) | 2009-12-01 | 2025-12-31 | 2009-12-01 | 2025-12-31 | 4023 | 2010-01 | 2025-12 | 2025-12-31 | 192 | no aplica |


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


Ninguno proviene de un error de ajuste: no hay retornos diarios > 30 % y el retorno con `Close` es consistente con el de `Adj Close`. CAT oct-2022 (+32.8 %) coincide con su reporte del 3T-2022 (25-oct-2022); es un movimiento de mercado real.
 Contraste con Tiingo: dif. de retorno total CAT 2022-10-31 = 5.05e-04.



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

Contraste de dividendos contra el calendario de Tiingo (`divCash` en la fecha ex-dividendo, llevado a base ajustada por splits) vs los dividendos implícitos de Yahoo:

| activo | div_yahoo | div_ref | coinciden_fecha | solo_yahoo | solo_ref | err_rel_monto_mediano | err_rel_monto_max |
|---|---|---|---|---|---|---|---|
| AAPL | 54 | 54 | 54 | 0 | 0 | 4.05e-05 | 0.000211 |
| MSFT | 64 | 64 | 64 | 0 | 0 | 2.54e-05 | 0.00012 |
| AMZN | 0 | 0 | 0 | 0 | 0 |  |  |
| JPM | 64 | 64 | 64 | 0 | 0 | 2.15e-05 | 0.000351 |
| JNJ | 64 | 64 | 64 | 0 | 0 | 1.1e-05 | 7.07e-05 |
| XOM | 64 | 64 | 64 | 0 | 0 | 1.06e-05 | 0.000112 |
| PG | 64 | 64 | 64 | 0 | 0 | 0.000327 | 0.000854 |
| CAT | 64 | 64 | 64 | 0 | 0 | 2.65e-05 | 9.47e-05 |
| KO | 64 | 64 | 64 | 0 | 0 | 1.51e-05 | 7.42e-05 |
| WMT | 65 | 65 | 65 | 0 | 0 | 3.42e-05 | 0.00244 |
| SPY | 65 | 65 | 65 | 0 | 0 | 0.000217 | 0.0021 |


## 4. Alineación de SPY, VIX y r^f al cierre de mes

**SPY (retorno mensual de `Adj Close`):** 192 meses comparados; máx. |panel − recomputo| = 3.33e-16; descuadres = 0; meses cuyo último dato no es el último día hábil = 1; datos posteriores al fin de mes = 0.  
Meses afectados (mes, último dato usado, último día hábil esperado): 2025-12: 2025-12-30 vs 2025-12-31

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
- Todos los valores del mes m usan `resample('ME').last()`, es decir, datos con fecha ≤ fin de m (verificado en la sección 4 para SPY, VIX y r^f; para las acciones es idéntico).
- Fechas en los crudos posteriores a END=2025-12-31: 0; posteriores a la fecha de descarga (2026-08-12): 0.
- El código actual produciría también la(s) fila(s) 2009-12-31 (retornos NaN, VIX y r^f válidos) que **no** están en el CSV guardado: el CSV fue generado con una versión ligeramente distinta del script o recortado después. No afecta a MATLAB (que espera ene-2010 como primera fila), pero el código y el archivo no son reproducibles 1:1.
- Uso en MATLAB (`run_backtest_wdro_kelly.m`): en la fecha k se usan `R(k−N+1:k)` y `rf_return(k)` (tasa observada al cierre de k) para decidir, y se aplica `R(k+1)`; r^f de k se acumula durante k+1, lo cual es conocido ex-ante → sin look-ahead. El VIX de la ventana (wdro-market) también usa k−N+1..k.
- Advertencia: Yahoo reescala `Adj Close` retroactivamente con cada nuevo dividendo; los *niveles* dependen de la fecha de descarga, pero los *retornos* no. No es look-ahead en retornos.

## 6. Contraste contra Tiingo (acciones, SPY) y CBOE (VIX)

Comparación a fin de mes. `err_rel_close` = Close de Yahoo / cierre de referencia ajustado por splits − 1; `dif_ret` = retorno total mensual de Yahoo − el de la referencia; `err_rel_adj` (nivel de Adj Close) es informativo, porque depende de la fecha de descarga. Tolerancias: 0.5% en precio, 0.25 pp en retorno. Detalle por activo y mes en `data/audit/reference_monthly_comparison.csv`.

| activo | fuente | primer_dato | ultimo_dato | meses | err_rel_close_medio | err_rel_close_max | mes_err_max | err_rel_adj_medio | dif_ret_media | dif_ret_max | meses_fuera_tol | fin_mes_distinto |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AAPL | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 4.054e-05 | 0.004488 | 2025-12-31 | 9.16e-05 | 6.594e-05 | 0.004375 | 3 | 1 |
| MSFT | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 5.889e-05 | 0.007981 | 2025-12-31 | 0.002004 | 8.72e-05 | 0.007845 | 1 | 1 |
| AMZN | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 4.078e-05 | 0.007408 | 2025-12-31 | 4.078e-05 | 4.347e-05 | 0.007332 | 1 | 1 |
| JPM | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 3.144e-05 | 0.003724 | 2025-12-31 | 0.005179 | 6.392e-05 | 0.003833 | 1 | 1 |
| JNJ | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 1.024e-06 | 0.0001933 | 2025-12-31 | 0.004716 | 1.592e-05 | 0.0001934 | 0 | 1 |
| XOM | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 2.801e-05 | 0.005401 | 2025-12-31 | 0.006968 | 5.957e-05 | 0.005607 | 1 | 1 |
| PG | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 2.678e-05 | 0.005164 | 2025-12-31 | 0.0004243 | 4.451e-05 | 0.004995 | 1 | 1 |
| CAT | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 4.099e-05 | 0.00789 | 2025-12-31 | 0.0003388 | 7.182e-05 | 0.00785 | 1 | 1 |
| KO | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 1.211e-05 | 0.002289 | 2025-12-31 | 0.006004 | 3.017e-05 | 0.002142 | 0 | 1 |
| WMT | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 2.374e-05 | 0.004578 | 2025-12-31 | 0.002331 | 3.758e-05 | 0.004649 | 1 | 1 |
| SPY | Tiingo | 2009-12-01 | 2025-12-31 | 193 | 4.542e-05 | 0.007464 | 2025-12-31 | 0.003049 | 5.697e-05 | 0.007496 | 1 | 1 |
| VIX | CBOE | 2009-12-01 | 2025-12-31 | 193 | 0.0002625 | 0.04147 | 2025-12-31 | 0.0002625 | 0.0002958 | 0.03792 | 3 | 1 |


Discrepancias por causa probable (en todas se mantuvo el dato de Yahoo):

| causa_probable | casos | significado |
|---|---|---|
| fecha_fin_mes_distinta | 10 | el último día con dato del mes difiere entre fuentes |
| mes_con_split | 0 | el mes contiene un split conocido |
| ajuste_dividendos | 0 | retorno distinto en un mes con fecha ex-dividendo (ajuste distinto) |
| escala_ajuste | 0 | solo difiere el nivel, no el retorno (factor de ajuste acumulado distinto según fecha de descarga) |
| sin_explicar | 4 | sin causa identificada; revisar manualmente |


Discrepancias sin explicar (revisión manual):

| asset | date | value | reference | rel_error | detail |
|---|---|---|---|---|---|
| AAPL | 2015-09-30 | 27.575 | 27.4875 | 0.00318329 | Tiingo; dif. retorno total 0.3104% |
| AAPL | 2015-10-31 | 29.875 | 29.875 | 0 | Tiingo; dif. retorno total -0.3449% |
| VIX | 2014-08-31 | 12.09 | 11.98 | 0.00918198 | CBOE; dif. retorno total 0.6490% |
| VIX | 2014-09-30 | 16.31 | 16.31 | -3.27442e-08 | CBOE; dif. retorno total -1.2387% |

## 7. IQR de cada serie en las ventanas de 60 meses

Ventanas D_k = meses k−59..k para cada fecha de decisión del backtest (`decision_idx = N:(T-1)` en `run_backtest_*.m`): 132 ventanas, con fin entre 2014-12-31 y 2025-11-30. Percentiles calculados como `prctile` de MATLAB (interpolación en (i−0.5)/n). Piso ε_esc = 1e-06. `rf_return` no entra en la geometría; se incluye solo como referencia. Serie completa en `data/audit/window_iqr.csv`.

| serie | en_geometria | ventanas | ventanas_iqr_bajo_piso | iqr_min | ventana_min | iqr_mediano |
|---|---|---|---|---|---|---|
| AAPL | sí | 132 | 0 | 0.08678 | 2015-05-31 | 0.1065 |
| MSFT | sí | 132 | 0 | 0.05641 | 2018-11-30 | 0.07478 |
| AMZN | sí | 132 | 0 | 0.0925 | 2021-11-30 | 0.1117 |
| JPM | sí | 132 | 0 | 0.06346 | 2018-08-31 | 0.08544 |
| JNJ | sí | 132 | 0 | 0.03784 | 2016-07-31 | 0.04889 |
| XOM | sí | 132 | 0 | 0.05062 | 2017-12-31 | 0.07126 |
| PG | sí | 132 | 0 | 0.04956 | 2017-09-30 | 0.05793 |
| CAT | sí | 132 | 0 | 0.07555 | 2017-06-30 | 0.1072 |
| KO | sí | 132 | 0 | 0.03176 | 2018-05-31 | 0.05255 |
| WMT | sí | 132 | 0 | 0.05709 | 2019-11-30 | 0.06545 |
| mkt_return | sí | 132 | 0 | 0.02562 | 2018-11-30 | 0.04192 |
| vix | sí | 132 | 0 | 3.42 | 2017-08-31 | 6.333 |
| rf_return | no (referencia) | 132 | 0 | 4.997e-05 | 2015-08-31 | 0.001357 |


## 8. Datos para `metodologia_2.tex`

Un bloque por cada `[PENDIENTE]`/REVISAR que depende de los datos. Se da el dato; el texto del `.tex` no se modificó.

### C7. Fecha de descarga (`[PENDIENTE: fecha de descarga...]`)

- Yahoo Finance (10 acciones, SPY, ^VIX): **2026-08-12**, según `data/raw/download_log.csv` (el log tiene cada símbolo dos veces, ambas con esa fecha).
- FRED (DGS3MO): **no registrada** en el log; el archivo se guardó en el mismo commit que los de Yahoo (2026-08-12). Si se cita una fecha, debe decirse que es la del commit.
- Fuentes de referencia (contraste): VIX CBOE 2026-10-19; AAPL Tiingo 2026-10-19; MSFT Tiingo 2026-10-19; AMZN Tiingo 2026-10-19; JPM Tiingo 2026-10-19; JNJ Tiingo 2026-10-19; XOM Tiingo 2026-10-19; PG Tiingo 2026-10-19; CAT Tiingo 2026-10-19; KO Tiingo 2026-10-19; WMT Tiingo 2026-10-19; SPY Tiingo 2026-10-19.

### C7. Periodo efectivo por ticker (`[PENDIENTE: confirmar con audit_report.csv]`)

- Las 12 series de Yahoo tienen el mismo rango diario: **2009-12-01 a 2025-12-30** (4045 días hábiles). Se solicitó hasta 2025-12-31, pero `yf.download` trata `end` como exclusivo; el cierre de diciembre de 2025 es el del **30-dic-2025**.
- DGS3MO: 2009-12-01 a 2025-12-31 (4023 observaciones válidas).
- Panel mensual: **2010-01-31 a 2025-12-31** (192 meses, 0 NaN, 0 meses faltantes); dic-2009 solo sirve de base para el retorno de ene-2010.
- Nota: el texto cita `audit_report.csv`; el periodo está en `data/audit/audit_report.md`, sección 1.

### C7. Criterio ante faltantes (`[PENDIENTE: criterio usado]`)

- Texto propuesto: «no se imputó ningún dato; el valor de cada mes es el último dato disponible del mes (nunca uno posterior). El único día hábil ausente en los precios (31-dic-2025) no se rellenó, y los NaN de DGS3MO, que corresponden a feriados, se omitieron tomando el último rendimiento válido del mes».
- Datos: 12 pares archivo-día ausentes (todos el 31-dic-2025); meses con r^f tomado de un mes anterior (ffill): **0**.
- **Diferencia texto/código:** el texto dice «la tasa DGS3MO se completó con su última observación disponible cuando faltaba un dato». Es correcto dentro del mes (se toma el último dato válido), pero el `ffill` entre meses de `01_import_data.py` se usó en 0 meses: no hubo que completar ningún mes.

### C7. Regla ante discrepancias (`[PENDIENTE: regla de resolución...]`) — **PROPUESTA**

- Regla propuesta: «prevaleció Yahoo Finance; una discrepancia (error de precio a fin de mes > 0.5% o diferencia de retorno total mensual > 0.25 pp) se registró y se clasificó por causa probable, sin modificar el dato».
- Resultado con 12 series contrastadas: **14 activo-mes** fuera de tolerancia, de ellos **4 sin explicar**; máx. |dif. retorno| = 3.79e-02.
- **Diferencia texto/fuente:** el texto dice «contra los datos históricos extraídos de Stooq». Stooq está bloqueado a nivel de red, así que el contraste se hizo contra **Tiingo** (acciones y SPY) y **CBOE** (VIX, fuente oficial del índice). La frase y la nota al pie deben cambiar.

### C8. Ningún dato posterior al cierre (`[PENDIENTE: confirmar...]`)

- Confirmado. Recomputo del panel: 0 de 2496 celdas distintas; test de desplazamiento: solo s=0 coincide; fechas posteriores a 2025-12-31 en los crudos: 0.
- SPY: datos posteriores al fin de mes = 0; meses cuyo último dato no es el último día bursátil = 1 (2025-12: 2025-12-30).
- VIX: datos posteriores al fin de mes = 0; meses cuyo último dato no es el último día bursátil = 1 (2025-12: 2025-12-30).
- DGS3MO: datos posteriores al fin de mes = 0; meses cuyo último dato no es el último día bursátil = 0.
- La descripción del REVISAR de C8 (último cierre diario de SPY y VIX, última observación de DGS3MO del mes, `resample('ME').last()` + `ffill`) coincide con `01_import_data.py`.

### C14. Ventanas con IQR < ε_esc (`[PENDIENTE: reportar el conteo...]`)

- ε_esc = 1e-06 (`standardize_median_iqr.m`, `build_transport_cost.m`). Ventanas de 60 meses: 132 (fechas de decisión del backtest, fin de ventana 2014-12-31 a 2025-11-30).
- **Conteo: 0** en las 12 series de la geometría (10 retornos, SPY y VIX). La serie con IQR más pequeño es `mkt_return` con 0.02562, muy por encima del piso. La regla de exclusión prevista nunca se activa; puede decirse así en el texto.

### C6. Criterio de selección y fuente GICS

- **No se resuelve con los datos**: es una decisión del autor (criterio de selección y fuente de la clasificación sectorial).

## Recomendaciones (no aplicadas)

1. Usar `END_DATE = "2026-01-01"` en `yf.download` (end exclusivo) y regenerar dic-2025. El cambio ya está en `01_import_data.py` (sin confirmar en git), pero `data/raw/` **no** se ha regenerado.
2. Escribir `download_log.csv` en modo sobrescritura por ejecución (o con un id de corrida) y registrar también DGS3MO.
3. Regenerar `monthly_panel.csv` con el script actual (o recortar explícitamente a ene-2010 en el código) para que el archivo sea reproducible.
4. Guardar una copia de los crudos con fecha de descarga, ya que Yahoo reescala Adj Close retroactivamente.
