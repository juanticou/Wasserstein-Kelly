# Inventario de dependencias de la fecha final y de rutas fijas (R0, paso 2)

Etiqueta base: `base-dic30` (commit 7938ca3, rama `resultados-finales`).

## Conclusión
- **El MATLAB no necesita cambios de lógica para pasar al cierre del 31-dic.** El panel se arma con `resample("ME").last()`, así que el último mes se etiqueta 2025-12-31 aunque el precio usado sea el del 30-dic. Los backtests usan `decision_idx = N:(T-1)` (`run_backtest_wdro_kelly.m:48`, `run_backtest_nominal_kelly.m:55`, `wdro-market/run_backtest_wdro_kelly_market.m:56`). Con T=192 y N=60 salen 132 decisiones (dic-2014 a nov-2025), y dic-2025 solo entra como el último retorno realizado. Las fechas escritas a mano y los conteos de 48 y 84 meses siguen siendo válidos.
- Lo que sí depende de la descarga son **rutas** (datos y resultados) y **textos de la auditoría** que dicen "30-dic".

## A. Python

| Archivo:línea | Qué | Tipo | Acción |
|---|---|---|---|
| `data/01_import_data.py:33` | `END_DATE = "2026-01-01"` (cambiado a mano; `data/raw` se bajó con `2025-12-31`) | fecha | parámetro `--end` |
| `data/01_import_data.py:35-38` | `RAW_DIR`/`PROC_DIR` fijos; los crea y escribe sin preguntar | ruta datos | `--raw-dir`, `--proc-dir` y negarse a escribir en carpetas con archivos |
| `data/01_import_data.py:67-78` | agrega filas a `download_log.csv` (hoy tiene filas duplicadas de dos descargas) | ruta datos | va en la carpeta nueva |
| `data/01_import_data.py:211` | `dropna(how="all")` **no** elimina la fila 2009-12-31: tiene VIX y r^f válidos y retornos NaN. El panel guardado empieza en ene-2010 porque se generó con otra versión o se recortó a mano (`data/audit/audit_report.md:216`). Si se corre tal cual, el panel nuevo tendría 193 filas con NaN en la primera, y las ventanas del backtest se correrían un mes | **lógica** | descartar las filas sin retornos de acciones (`dropna(subset=TICKERS, how="all")`), así el panel queda igual al guardado |
| `data/audit/02_audit_data.py:33-38` | `RAW_DIR`, `PROC_DIR`, `OUT_DIR` fijos | ruta datos | `--raw-dir`, `--proc-dir`, `--out-dir` |
| `data/audit/02_audit_data.py:42` | `END = "2025-12-31"` (inclusivo, calendario NYSE) | fecha | sin cambio; vale para ambas descargas |
| `data/audit/02_audit_data.py:63, 705-714, 745-759, 797, 808, 937, 975-978, 1114-1117` | textos fijos sobre el "30-dic" y el `end` exclusivo | texto | **pendiente R1**: si se audita la descarga nueva, esos textos quedan desactualizados (no se tocan en R0) |
| `data/audit/03_download_reference.py:33`, `03_download_stooq.py:25` | fechas de referencia hasta 2025-12-31 | fecha | sin cambio |

## B. MATLAB: pipeline vigente (se parametriza)

Patrón común: `CSV_PATH = fullfile(PROJECT_DIR,'data','processed','monthly_panel.csv')` y `fullfile(PROJECT_DIR,'results_*')`.

| Script | Panel | Lee | Escribe |
|---|---|---|---|
| `main_grid_delta_eta.m` | :24 | — | `results_eta_delta_grid_wdro` (:49, **relativo al directorio actual**) |
| `main_validation_grid.m` | — | `results_eta_delta_grid_wdro` (:28, relativo) | `results_validacion_grid` (:41, relativo) |
| `wdro-market/main_validation_grid_market.m` | :46 | `results_validacion_grid/pm_validacion.mat` (:77) | `wdro-market/results_validacion_grid_market` (:71) |
| `verify_eta0_backtest.m` | :24 | malla G1 (:33) | `results_verificaciones` (:25) |
| `test_wdro_nominal_equivalence.m` | :31 | — | `results_verificaciones` (:32) |
| `verify_backtest_constraints.m` | :17 | mallas G1/G2 (:27-28) | `results_verificaciones` (:18) |
| `rebuild_validation_tables.m` | :18 | mallas G1/G2 (:29-31) | `results_validacion_metricas_v2` (:19) |
| `analyze_solver_status.m` | :29 | mallas G1/G2 (:39-43), **heredados** `wdro-market/results_geometria_mercado` (:47) y `results_comparacion_modelos` (:54), nominal (:62, ya condicional) | `results_estado_solver` (:30) |
| `diagnostico_seleccion.m` | :25 | mallas G1/G2 (:41-42), `results_validacion_metricas_v2` (:144) | `results_seleccion` (:26) |
| `main_seleccion_parametros.m` | — | `results_validacion_metricas_v2` (:17) | `results_seleccion` (:18) |
| `main_test_evaluation_v2.m` | :29 | malla G1 (:44), malla G2 (:46), nominal (:49) | `results_prueba_v2` (:30) |
| `test_bootstrap_block_diff.m` | — | — | `results_bootstrap` (:15) |
| `main_bootstrap_contrasts.m` | — | `results_prueba_v2` (:32), malla G1 (:33), nominal (:34) | `results_bootstrap` (:21) |
| `main_regime_breakdown.m` | :19 | igual que el anterior (:32-34) | `results_regimen` (:20) |

Fechas y conteos fijos (válidos con ambas descargas, sin cambio): `VALIDATION_*`/`TEST_*` en `diagnostico_seleccion.m:31-33`, `rebuild_validation_tables.m:24-25`, `main_test_evaluation_v2.m:38-39,193`, `main_bootstrap_contrasts.m:25-26`, `main_regime_breakdown.m:24-25`, `wdro-market/main_validation_grid_market.m:87-88`, `main_validation_grid.m:68-69` (derivadas de los datos); asserts de 48 meses (`diagnostico_seleccion.m:69`, `main_seleccion_parametros.m:51`) y 84 meses (`main_bootstrap_contrasts.m:56`, `main_regime_breakdown.m:56,83`); `analyze_solver_status.m:119-120` (corte 2022); `test_wdro_nominal_equivalence.m:52` (fechas de instancias). `test_bootstrap_block_diff.m:21` (T=84 simulado).

Semillas: `bootstrap_block_diff.m:35` y `test_bootstrap_block_diff.m:44` → 20261019; `main_bootstrap_contrasts.m:29` → 20261019.

## C. MATLAB heredado (fuera del pipeline; no se toca)
`main_nominal_kelly.m`, `main_wdro_kelly.m`, `main_grid_delta_eta_high.m`, `main_test_evaluation.m` (v1), `generate_extra_metrics_test.m`, `generate_missing_returns_plots.m`, `regenerate_grid_tables.m`, `wdro-market/main_geometria_mercado.m`, `wdro-market/main_comparacion_modelos.m` y los `plot_*.m` (salida por defecto `results_out`, siempre se llaman con carpeta explícita). Única dependencia del pipeline hacia ellos: `analyze_solver_status.m` carga dos `.mat` heredados; se vuelve condicional (si no existen en la raíz nueva, se omiten esas filas).

## D. Comprobación del paso 4
`results_finales/check_r0_no_cambio.csv`: 12 meses, diferencia exactamente 0 en x, x0, factor de crecimiento y riqueza para G1 (0.90, 0.01), G1 (0.90, 0) contra la malla y contra el nominal, y G2 (0.80, 0.01) contra la validación.
