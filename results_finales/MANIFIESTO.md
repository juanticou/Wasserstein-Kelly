# Manifiesto de reproducibilidad

Rama `resultados-finales`. Etiquetas: `base-dic30` (estado antes de parametrizar, datos con cierre del 30-dic-2025) y `scripts-parametrizados` (este estado).

## Software
| Componente | Versión |
|---|---|
| MATLAB | 26.1.0.3312084 (R2026a) Update 4 |
| CVX | 2.2, build 1148 (62bfcca), en `D:\descargas\cvx-w64\cvx` |
| MOSEK | 9.1.9 (el que viene con CVX, `mosek64_9_1.dll`) |
| Python (`py`) | 3.13.3: yfinance 1.7.0, pandas 2.2.3, numpy 2.2.5, pandas_datareader 0.11.1, matplotlib 3.10.1 |
| Python (anaconda3) | 3.13.5: yfinance 1.1.0, pandas 2.2.3, numpy 2.1.3 |

`data/raw/download_log.csv` no dice qué intérprete se usó en la descarga del 2026-08-12. Para R1 se usará `py` (3.13.3).

## Datos de la línea base (`base-dic30`)
Descarga de Yahoo del 2026-08-12 con `end=2025-12-31`; el último cierre es el del 30-dic-2025. `download_log.csv` tiene las filas de las acciones repetidas (dos ejecuciones).

| Archivo | SHA-256 |
|---|---|
| `data/raw/AAPL_daily.csv` | `47db68e31528b3acef03a584eacc96ba454cbf7ffd86fca57a768421ce5a4f55` |
| `data/raw/AMZN_daily.csv` | `f757216395b1c0113082278f4147e43cf6985bbc06c667bfbfb68acbab72bc63` |
| `data/raw/CAT_daily.csv` | `11613e899e139a903379b6bdfa07a4a3f3af63564172e704e31742d7ade3cd6b` |
| `data/raw/DGS3MO_daily.csv` | `08ad7e795748140eb61215f7fa8cd5ba9d3e5ebcf4e752e9429836f53accfbc9` |
| `data/raw/JNJ_daily.csv` | `8d8936d4b0027b7c66e34cefa04cc6df845a2a0b970c98a3664051ec64ba5bc8` |
| `data/raw/JPM_daily.csv` | `1692104ab97f2f8434a5fc1b94aaa23c2f31cbb948f6f43dc5266426395ecd80` |
| `data/raw/KO_daily.csv` | `b1cbf83a9bba7c7373dbb04244c2ca4dbf3c16609cdb42365cce848e6c590b8e` |
| `data/raw/MSFT_daily.csv` | `cc5f362199d35bb6449ac7b2ffa4422999a51bf3fbfdf9caca3528ee5789bc7d` |
| `data/raw/PG_daily.csv` | `c6ccec6a02a4be3a9d4e51968558480e55e5e2e3bcbe6bc46bd3c37fc9e390e0` |
| `data/raw/SPY_daily.csv` | `6f144194c12143b5dcd8fa984de71cd6a4bad36bc45c65162444a185bed6ae43` |
| `data/raw/VIX_daily.csv` | `03cba07d8e8e61e88abd13e8938c441daa3d5cf74448ba883cfe7f21d7cc6f0b` |
| `data/raw/WMT_daily.csv` | `959a529d58abcf04dc95e8b18a7e8c0c70047dfacec7c022baf37fe57479283d` |
| `data/raw/XOM_daily.csv` | `8b16e960cf8c9f6cd81e91eceb087a6d93f8a73a80e82250a761119a82e49fd0` |
| `data/raw/download_log.csv` | `bf4973d213dc402b58652f3ef91c2e556280a1cd8b7d99f8a948cba786bb1c01` |
| `data/processed/monthly_panel.csv` | `f5d0fd44d1be3f34680461979c237aab253868308a599de173cfce4de83e4896` |
| `data/processed/monthly_adj_close.csv` | `46b60adbe5f1f9dcab8c8ccd3077bf4291387dee6fcd62c1ff1128eb552bdab9` |

Panel: 192 meses (2010-01-31 a 2025-12-31), 0 NaN. Al reconstruirlo desde `data/raw/` con el `01_import_data.py` parametrizado, la diferencia máxima es 3.6e-15 y el índice es idéntico.

## Cómo se eligen las rutas
- **Python:** `py data/01_import_data.py --end 2026-01-01 --raw-dir <nueva> --proc-dir <nueva>`. Se niega a escribir en carpetas que ya tengan archivos. `py data/audit/02_audit_data.py --raw-dir ... --proc-dir ... --out-dir <nueva>`.
- **MATLAB:** `config_rutas.m` lee `WK_PANEL` (ruta del panel) y `WK_RESULTS_ROOT` (raíz de los `results_*`; las de G2 van en `<raíz>/wdro-market/`). Si están vacías, se usan las rutas históricas.
- **Protección:** `preparar_salida.m` detiene el script si, con la raíz histórica, la carpeta de salida ya tiene archivos. Para permitirlo a propósito: `WK_PERMITIR_SOBRESCRIBIR=1`.

Ejemplo para R1, desde la raíz del proyecto en MATLAB:
```matlab
setenv('WK_PANEL', fullfile(pwd, 'data', 'processed_2026-01-01', 'monthly_panel.csv'));
setenv('WK_RESULTS_ROOT', fullfile(pwd, 'results_v2'));
```

## Orden de ejecución del pipeline
Las rutas son relativas a la raíz de resultados (`R`): hoy la raíz del proyecto, en R1 `results_v2/`.

| # | Script | Lee | Escribe |
|---|---|---|---|
| 1 | `data/01_import_data.py` | Yahoo, FRED | `raw-dir/*`, `proc-dir/monthly_panel.csv`, `monthly_adj_close.csv`, `audit_report.csv` |
| 2 | `data/audit/02_audit_data.py` | raw, panel, `data/audit/ref_cache` | `out-dir/audit_report.md`, … |
| 3 | `main_grid_delta_eta.m` (G1, 132 meses, 6×11) | panel | `R/results_eta_delta_grid_wdro/grid_delta_eta.mat`, tablas, figuras |
| 4 | `main_validation_grid.m` | paso 3 | `R/results_validacion_grid/pm_validacion.mat`, … |
| 5 | `wdro-market/main_validation_grid_market.m` (G2, 48 meses, 6×11) | panel, paso 4 | `R/wdro-market/results_validacion_grid_market/grid_delta_eta_market_validacion.mat`, … |
| 6 | `verify_eta0_backtest.m` | panel, paso 3 | `R/results_verificaciones/nominal_backtests.mat`, `equivalencia_eta0_backtest.csv` |
| 7 | `test_wdro_nominal_equivalence.m` | panel | `R/results_verificaciones/equivalencia_eta0_instancias.csv`, … |
| 8 | `verify_backtest_constraints.m` | panel, pasos 3 y 5 | `R/results_verificaciones/verificacion_restricciones.csv` |
| 9 | `rebuild_validation_tables.m` | panel, pasos 3 y 5 | `R/results_validacion_metricas_v2/` |
| 10 | `analyze_solver_status.m` | panel, pasos 3, 5 y 6 (y los .mat heredados si existen) | `R/results_estado_solver/` |
| 11 | `diagnostico_seleccion.m` | panel, pasos 3, 5 y 9 | `R/results_seleccion/` (ruido, cota activa) |
| 12 | `main_seleccion_parametros.m` | pasos 9 y 11 | `R/results_seleccion/seleccion_G*.csv`, … |
| 13 | `main_test_evaluation_v2.m` | panel, pasos 3, 5 y 6 | `R/results_prueba_v2/` |
| 14 | `test_bootstrap_block_diff.m` | — | `R/results_bootstrap/` (prueba con datos simulados) |
| 15 | `main_bootstrap_contrasts.m` | pasos 3, 6 y 13 | `R/results_bootstrap/tabla_bootstrap_contrastes.csv` |
| 16 | `main_regime_breakdown.m` | panel, pasos 3, 6 y 13 | `R/results_regimen/desglose_regimen.csv` |

`main_test_evaluation_v2.m` tiene fijas las configuraciones de T9: (0.90, 0.01) y (0.80, 0.01). En R1 hay que comprobar que el paso 12 da la misma selección antes de correr el paso 13.

Semillas: 20261019 (`bootstrap_block_diff.m:35`, `main_bootstrap_contrasts.m:29`, `test_bootstrap_block_diff.m:44`).

## Resultados existentes (línea base, no se sobrescriben)
`results_eta_delta_grid_wdro/`, `results_validacion_grid/`, `wdro-market/results_validacion_grid_market/`, `results_verificaciones/`, `results_validacion_metricas_v2/`, `results_estado_solver/`, `results_seleccion/`, `results_prueba_v2/`, `results_bootstrap/`, `results_regimen/`. Los heredados están en `results_out*`, `results_prueba_fuera_muestra/`, `wdro-market/results_geometria_mercado/` y `wdro-market/results_comparacion_modelos/`.

## Comprobación de no-cambio
`results_finales/check_r0_no_cambio.m`, con salida en `check_r0_no_cambio.csv`, se corrió antes y después de parametrizar. En los 12 primeros meses de decisión la diferencia fue 0 exacto para G1 (0.90, 0.01), para G1 (0.90, 0) contra la malla y contra el nominal, y para G2 (0.80, 0.01) contra la validación.
