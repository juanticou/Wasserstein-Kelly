# R1 — Regeneración con el cierre del 31-dic-2025

Fecha: 2026-10-21. Rama `resultados-finales`. **No se reemplazó nada**: la línea base (`data/raw/`, `data/processed/`, `results_*`) está intacta, verificado con SHA-256 antes y después. Los resultados nuevos están en `results_v2/`, que **todavía no reemplaza** a la línea base: falta tu aprobación.

## 1. Descarga
- `py -B data/01_import_data.py --end 2026-01-01 --raw-dir data/raw_2026-01-01 --proc-dir data/processed_2026-01-01`.
- Yahoo Finance el 2026-10-21: 4046 días hábiles por serie, con el último el 31-dic-2025. FRED: DGS3MO.
- Panel descargado: 192 meses (ene-2010 a dic-2025), 0 NaN.

## 2. Comparación ene-2010 a nov-2025 con la descarga anterior → **criterio de 1e-8 NO cumplido**
- 1790 celdas con |dif| > 1e-8; el máximo es 1.4e-6 (CAT). AMZN, VIX y r^f coinciden exactamente. Detalle en `results_finales/r1_comparacion_panel.csv`.
- Causa, revisada en los crudos: `Close` es idéntico en todas las series. `Adj Close` se reescaló con un factor casi constante: 0.99407 en KO y 0.99752 en SPY, por los dividendos de diciembre de 2025; ≈1 en las demás. Además, el redondeo de Yahoo añade un ruido relativo de ~2e-7 (unos 7 dígitos significativos). Es ruido de precisión, no un error de datos.
- **Decisión del autor: panel híbrido.** `data/build_hybrid_panel.py` crea `data/processed_2026-01-01/monthly_panel_hibrido.csv`: ene-2010 a nov-2025 copiados como texto del panel anterior (byte a byte iguales) y solo la fila de dic-2025 tomada de la descarga nueva.

Fila de dic-2025, antes (cierre del 30-dic) y después (31-dic):

| Serie | 30-dic | 31-dic |
|---|---|---|
| AAPL | −0.020692 | −0.025067 |
| MSFT | −0.009207 | −0.017053 |
| AMZN | −0.002959 | −0.010291 |
| JPM | 0.033027 | 0.029194 |
| JNJ | −0.000048 | 0.000145 |
| XOM | 0.043737 | 0.038130 |
| PG | −0.027740 | −0.032735 |
| CAT | 0.002831 | −0.005019 |
| KO | −0.034982 | −0.037185 |
| WMT | 0.014824 | 0.010199 |
| SPY (mkt_return) | 0.008268 | 0.000797 |
| VIX | 14.33 | 14.95 |
| r^f | 0.003008 | 0.003008 |

## 3. Ejecución (`results_finales/r1_ejecutar.m`, log en `results_v2/log_ejecucion.csv`)
- **Prueba corta previa:** ≈0.12 s por mes con η ∈ {0, 0.01, 0.15, 0.30, 1.00} en G1 y G2.
- **Tiempos:**
  - Malla G1: 1112 s.
  - Validación G2: 426 s.
  - Nominales: 78 s.
  - Prueba: 52 s.
  - Resto: < 40 s cada paso.
  - Total: ≈ 30 min.
- En todas las celdas, 100 % de meses con solución óptima.
- `main_test_evaluation_v2`: G2 en 132 meses reproduce exactamente sus primeros 48 meses de validación (`verificacion_G2_reproduce_validacion.csv`: dx = dG = dW = 0).

## 4. Comparación con la línea base
**Mallas y selección** (`results_finales/r1_comparacion_mallas.csv`):
- 138 trayectorias: 66 de G1, 66 de G2 de validación y 6 nominales.
- Decisiones: max |Δx| = **0**. Factores realizados hasta nov-2025: max |ΔG| = **0**. Se cumple la tolerancia de 1e-6.
- Solo cambia el último factor (dic-2025): entre −6.4e-3 y −2e-8.
- `seleccion_G1.csv`, `seleccion_G2.csv`, `sensibilidad_seleccion.csv` y las 4 tablas de `results_validacion_metricas_v2/` son **idénticas**. La selección de T9 no cambia: G1 (0.90, 0.01) y G2 (0.80, 0.01).

**Prueba** (`results_finales/r1_comparacion_prueba.csv`). Riqueza final en prueba, re-basada al inicio de 2019, 84 meses:

| Estrategia | Cierre 30-dic | Cierre 31-dic | Cambio relativo | CAGR 30-dic | CAGR 31-dic |
|---|---|---|---|---|---|
| G1 (0.90, 0.01) | 4.0241 | 3.9995 | −0.61 % | 22.01 % | 21.90 % |
| G2 (0.80, 0.01) | 3.8964 | 3.8730 | −0.60 % | 21.45 % | 21.34 % |
| G2 (0.90, 0.01) | 3.8975 | 3.8734 | −0.62 % | 21.45 % | 21.34 % |
| G1 (0.80, 0.01) | 3.7078 | 3.6856 | −0.60 % | 20.59 % | 20.48 % |
| Nominal (0.90) | 3.7651 | 3.7413 | −0.63 % | 20.85 % | 20.74 % |
| Nominal (0.80) | 3.6469 | 3.6248 | −0.61 % | 20.30 % | 20.20 % |

- Validación: max |dif| = 0 en todas las métricas.
- Contrastes de prueba (`contrastes_prueba.csv`): max |dif| = 2.2e-4. La media de D_k cambia como mucho 2e-6 y la proporción de meses con D_k > 0 no cambia.
- Bootstrap (`tabla_bootstrap_contrastes.csv`): max |dif| = 2.9e-5. 6 de 27 intervalos excluyen el 0, antes y después; **ninguna conclusión cambia**.
- Régimen (`desglose_regimen.csv`): max |dif| = 2.0e-4, con los mismos 63 renglones.

## 5. Frases a actualizar en `metodologia_6.tex` (no se editó el .tex)
1. **Línea 69:** «Los datos de Yahoo Finance se descargaron el 12 de agosto de 2026… cubren… al 30 de diciembre de 2025 (4045 días hábiles): se solicitó hasta el 31 de diciembre, pero el parámetro de fin… es exclusivo, de modo que el cierre de diciembre de 2025… corresponde al 30 de diciembre» y «el único día hábil ausente (31 de diciembre de 2025) no se rellenó». Hay que explicar que dic-2025 viene de una segunda descarga (2026-10-21, 4046 días hábiles, hasta el 31-dic) y que ene-2010 a nov-2025 se conservan de la primera, porque las diferencias entre descargas son de ~1e-6 por el reescalado de `Adj Close`.
2. **Línea 71:** «10 se explican porque el último día con dato del mes difiere entre fuentes (todos asociados al cierre de diciembre de 2025)». Esas 10 discrepancias deberían desaparecer con el cierre del 31-dic, pero **no se ha vuelto a auditar**; queda pendiente.
3. **Línea 93:** «en diciembre de 2025, SPY y el VIX usan el cierre del 30 de diciembre (el último dato descargado)». También el «0 de 2496» del recomputo, que es de la auditoría vieja.
4. **Línea 420** (limitaciones): «además, el cierre de diciembre de 2025 corresponde al 30 de diciembre y no al 31». Si apruebas `results_v2`, esto deja de ser una limitación; puede reemplazarse por la nota del panel híbrido.
5. **Línea 67:** «los niveles dependen de la fecha de descarga, pero los retornos no». Con dos descargas, los retornos difieren ~1e-6 por redondeo; conviene matizarlo.
6. Todas las cifras de prueba del texto (riqueza final, CAGR, contrastes, bootstrap, régimen) cambian en el último mes. Se actualizan en R2–R4, que leerán de `results_v2/`.
7. Los comentarios `%%% [C7b]` (línea 65) y `%%% [C7c]` (línea 419) mencionan la decisión de regenerar; ya está tomada.

## 6. Pendientes y notas
- **Re-auditoría de la descarga nueva:** `02_audit_data.py --raw-dir data/raw_2026-01-01 --proc-dir … --out-dir data/audit_2026-01-01` no se ha corrido. Además, sus textos fijos sobre el «30-dic» no aplican y la auditoría compara contra el panel descargado, no contra el híbrido.
- **`plot_wealth_by_delta.m:85`:** `grid on` fallaba porque `grid` es el argumento de entrada. Ya está corregido y las figuras «riqueza por δ = 0.90» se generaron en `results_v2/results_validacion_grid/` y `results_v2/wdro-market/results_validacion_grid_market/`. Para R3 queda que, con 11 valores de η, los colores de `lines` se repiten.
- **Para que R2–R6 lean de `results_v2/`:** falta tu aprobación.
