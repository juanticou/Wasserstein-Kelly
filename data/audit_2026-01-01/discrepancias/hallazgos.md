# Hallazgos: las 4 discrepancias `sin_explicar` (borrador, 2026-10-21)

Script: `investigar_discrepancias.py`, de solo lectura. Lee `data/raw_2026-01-01/`, `data/audit/ref_cache/` y `data/processed_2026-01-01/monthly_panel_hibrido.csv`, y no modifica ningún dato.

## 1. Las 4 discrepancias son 2 cierres diarios
| Evento | Yahoo | Referencia | Rango L–H de Yahoo ese día | Día siguiente |
|---|---|---|---|---|
| AAPL 30-sep-2015, miércoles, fin de trimestre (×4 = sin ajustar) | 110.30 | Tiingo 109.95 | 108.73–111.54 | coinciden exactamente |
| VIX 29-ago-2014, viernes antes de Labor Day | 12.09 | CBOE 11.98 | 11.78–12.44 | coinciden exactamente |

El cierre en disputa define el nivel del mes y es la base del retorno del mes siguiente. Por eso cada evento produce dos meses fuera de tolerancia, y de signo opuesto: AAPL sep +0.31 pp y oct −0.34 pp; VIX ago y sep.

## 2. No son casos aislados (contraste diario, `discrepancias_diarias.csv`)
En el contraste diario de las 12 series (4046 días cada una) aparecen **17 eventos del mismo tipo**:
- un solo día con un cierre distinto (0.3 %–3.7 %);
- el día siguiente las dos fuentes coinciden exactamente;
- los niveles de ajuste, los dividendos y los splits nunca difieren.

| Serie | Días con cierre distinto |
|---|---|
| AAPL | 2015-09-30 |
| JPM | 2011-10-27 |
| JNJ | 2010-02-18, 2011-10-27 |
| XOM | 2010-02-05, 2010-05-10, 2014-07-28 |
| PG | 2010-01-19 |
| CAT | 2010-04-21, 2014-08-12 |
| VIX | 2014-08-29, 2014-10-15, 2014-12-01, 2014-12-05, 2014-12-09, 2021-08-11 |
| MSFT, AMZN, KO, WMT, SPY | ninguno > 0.5 % |

Solo 2 de los 17 caen en el último día del mes. Esos 2 son las 4 discrepancias de la auditoría mensual. Los demás no afectan el panel, porque este solo usa cierres de fin de mes.

Las acciones se concentran en 2010–2015. En el VIX, 5 de los 6 casos están en ago–dic de 2014. También el 30-sep-2015 MSFT difiere 0.14 % y SPY difiere un poco en los días cercanos, todo dentro de la tolerancia.

Aparte: CBOE publica el VIX en 27 feriados de la NYSE (2022–2025) que Yahoo no trae. Ninguno es fin de mes, así que no afecta el panel.

## 3. Lectura por hipótesis
- **H4 (patrón sistemático): se confirma.** Es un fenómeno recurrente de «cierre de un día» entre proveedores, no un error de ajuste ni de alineación.
- **VIX 29-ago-2014 → H2/H3, con la fuente oficial a favor de CBOE.** CBOE calcula el índice, así que 11.98 es por definición el cierre oficial y lo de Yahoo es otro registro. Lo respalda que Yahoo tenga 5 casos similares en ago–dic de 2014. En dos de ellos (2014-12-09 y 2021-08-11) el cierre oficial de CBOE queda **fuera** del rango alto-bajo que da Yahoo para ese día, lo que indica que la barra de Yahoo no es la oficial. La causa exacta (hora de la toma, 16:00 frente a 16:15, o un tick tardío) **no se puede verificar** sin datos intradía. Queda como hipótesis.
- **AAPL 30-sep-2015 → Yahoo es el valor atípico.** Alpha Vantage, como tercera fuente (sección 4), da 109.95, igual que Tiingo; Yahoo da 110.30. Ese mismo día MSFT tiene el mismo patrón (Yahoo 44.26 frente a 44.20 en Tiingo y Alpha Vantage). Lo más probable es que Yahoo registre otro precio como cierre (H1/H3), pero la causa exacta no se puede verificar.
  - En los 8 eventos de acciones, Yahoo está por encima de Tiingo en 7.
  - La excepción, CAT 2014-08-12, tiene el valor de Tiingo **fuera** del rango de Yahoo ese día; ahí el sospechoso es Tiingo.
- **Paso 3 (coherencia frente a SPY y MSFT):** no discrimina. El 30-sep-2015 AAPL sube 1.14 % según Yahoo y 0.82 % según Tiingo, mientras SPY sube 1.87 % y MSFT 1.75–1.89 %. Ambos valores son plausibles.

## 4. Terceras fuentes (`terceras_fuentes.csv`)

### Alpha Vantage, serie mensual (2026-10-21; `tercera_fuente_alphavantage.py`, `tercera_fuente_av_mensual.csv`)
La serie diaria completa es de pago (`outputsize=full` premium; consta en `alphavantage_cache/download_log.csv`), así que se usó `TIME_SERIES_MONTHLY`: el cierre sin ajustar del último día hábil de cada mes. Abarca 10 acciones y SPY, con 193 fines de mes cada una (dic-2009 a dic-2025), 2123 en total.

- **Alpha Vantage coincide con Tiingo en los 2123 fines de mes, con diferencia 0.**
- El día usado como fin de mes es el mismo en las tres fuentes en todos los casos.
- Yahoo difiere de ambas en 5 fines de mes:

| Serie | Mes | Yahoo | Tiingo = Alpha Vantage | Dif. |
|---|---|---|---|---|
| AAPL | 2015-09 | 110.30 | 109.95 | 0.32 % |
| MSFT | 2015-09 | 44.26 | 44.20 | 0.14 % |
| JPM | 2009-12 | 41.67 | 41.62 | 0.12 % |
| JPM | 2010-03 | 44.75 | 44.70 | 0.11 % |
| SPY | 2015-08 | 197.67 | 197.54 | 0.07 % |

Solo AAPL 2015-09 supera la tolerancia de la auditoría (0.5 % en precio o 0.25 pp en retorno). Los otros 4 son menores, pero tienen el mismo sentido: Yahoo un poco por encima.

**Veredicto AAPL 2015-09-30: Alpha Vantage = Tiingo.** Los controles (AAPL ago-2015 y oct-2015) coinciden en las tres fuentes.

**Limitación:** no se sabe si Alpha Vantage y Tiingo comparten un proveedor de origen; si lo comparten, no son del todo independientes. La conclusión es «Yahoo es el atípico frente a dos proveedores», no «el cierre oficial de Nasdaq es 109.95». Para confirmarlo haría falta el cierre oficial de Nasdaq o CRSP.

### Intentos fallidos o pendientes
No se obtuvo ninguna hoy:
- FRED `VIXCLS`: servidor en mantenimiento.
- Stooq: bloqueo anti-bot con JavaScript.
- Nasdaq.com: solo tiene unos 10 años de historia.
- Tiingo OHLC, Alpha Vantage y Polygon: necesitan una clave que no está definida.
- Prensa: ningún resultado verificable.

Lo que falta para cerrar los dos casos:
- **VIX:** reintentar FRED `VIXCLS`, que es independiente de Yahoo y reproduce la serie de CBOE.
- **AAPL:** una fuente con el cierre oficial de Nasdaq, como CRSP vía WRDS si EAFIT tiene acceso, o Tiingo OHLC con clave.

## 5. Impacto (`impacto_ventanas.csv`), sin backtest
Celdas del panel que cambiarían si se usara el valor de la referencia:

| Celda | Panel | Con la referencia |
|---|---|---|
| AAPL sep-2015 | −2.18 % | −2.49 % |
| AAPL oct-2015 | +8.34 % | +8.69 % |
| VIX ago-2014 | 12.09 | 11.98 |

| Serie | Ventanas afectadas (validación / prueba) | Máx. cambio relativo del IQR | Máx. cambio de la mediana |
|---|---|---|---|
| AAPL | 40 / 21 (fin 2015-09 a 2020-09) | 1.8 % / 3.1 % | 0 |
| VIX | 49 / 7 (fin 2014-12 a 2019-07) | 0 | 0 |

- **VIX:** la estandarización por mediana e IQR de la Geometría 2 **no cambia** en ninguna ventana, porque 12.09 y 11.98 no alteran los cuantiles.
- **AAPL:** el IQR cambia como máximo un 3 %. Además, 2 de las 60 observaciones de retorno de cada ventana cambian en unos 0.3 pp.

El efecto esperado sobre los portafolios es despreciable, pero **no se ha medido con un backtest**.

## 6. Propuesta de clasificación para la auditoría (no aplicada)
Nueva causa `cierre_diario_distinto`: el cierre de un solo día difiere entre proveedores y coincide al día siguiente. Las 4 filas pasan de `sin_explicar` a esa causa, y Yahoo se mantiene como fuente oficial. En el VIX conviene anotar que el oficial es el de CBOE (11.98).
