# Portafolios Wasserstein–Kelly con costos de transacción

Práctica investigativa (EAFIT, director: Prof. Diego Fonseca). Se comparan tres estrategias de asignación mensual sobre 10 acciones de EE. UU. (AAPL, AMZN, CAT, JNJ, JPM, KO, MSFT, PG, WMT, XOM) más un activo de bajo riesgo:

1. **Kelly nominal**: maximiza el crecimiento logarítmico esperado bajo la distribución empírica.
2. **Wasserstein–Kelly, Geometría 1 (G1)**: versión robusta en una bola de Wasserstein cuyo costo de transporte usa solo los retornos de las acciones.
3. **Wasserstein–Kelly, Geometría 2 (G2)**: el costo de transporte combina retornos de las acciones, retorno de SPY y nivel del VIX, con pesos fijos (0.70, 0.15, 0.15).

El texto del trabajo está en `main_6.tex`, que incluye `metodologia_6.tex`, `resultados_6.tex` y `discusion_6.tex`.

## Diseño experimental

| Elemento | Valor |
|---|---|
| Datos | mensuales, ene-2010 a dic-2025 (Yahoo Finance; tasa libre de riesgo DGS3MO de FRED) |
| Ventana móvil | N = 60 meses |
| Costo de transacción | τ = 0.001 |
| Límite por acción | x̄ = 0.25 |
| Exposición riesgosa total máxima | γ = 1 |
| Validación | 2015–2018 (48 meses) |
| Prueba | 2019–2025 (84 meses) |
| Malla δ | {0.50, 0.60, 0.70, 0.75, 0.80, 0.90} |
| Malla η | {0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.10, 0.15, 0.30, 0.50, 1.00} (η = 0 equivale al Kelly nominal) |
| Solver | CVX + MOSEK |

**Selección de parámetros** (solo con validación, por geometría; `select_parameters.m`, `main_seleccion_parametros.m`): η > 0; fracción de meses con solución óptima ≥ 0.95; máxima riqueza final de validación; empate si la brecha relativa es < 5e-4; desempate por menor η y luego mayor δ. Elegidos: **G1 → (δ, η) = (0.90, 0.01)**, **G2 → (0.80, 0.01)**.

Con δ ≤ 0.90 el problema siempre es factible; cualquier mes "no factible" es un fallo numérico, no factibilidad teórica.

## Estructura

```
Wasserstein-Kelly/
├── data/
│   ├── 01_import_data.py          descarga (Yahoo, FRED) y construcción del panel mensual
│   ├── build_hybrid_panel.py      panel híbrido con el cierre del 31-dic-2025
│   ├── audit/, audit_2026-01-01/  auditoría de datos y discrepancias entre fuentes
│   ├── raw/, raw_2026-01-01/      precios diarios descargados (no se modifican)
│   └── processed/, processed_2026-01-01/   paneles mensuales
├── *.m                            MATLAB común y de la Geometría 1 (solvers, backtests, métricas, mallas, selección, bootstrap)
├── wdro-market/                   Geometría 2 (costo de transporte con SPY y VIX, malla de validación)
├── results_*/                     resultados de la línea base (cierre del 30-dic-2025)
├── results_v2/                    resultados vigentes (panel híbrido, cierre del 31-dic-2025)
├── results_finales/               tablas, figuras, inferencia, verificación cruzada (scripts r2_* a r6_*)
└── main_6.tex, metodologia_6.tex, resultados_6.tex, discusion_6.tex
```

## Requisitos

- MATLAB R2026a con CVX 2.2 y MOSEK 9.1.9 (el que viene con CVX).
- Python 3.13 con los paquetes de `requirements.txt`: `pip install -r requirements.txt`.

Las versiones exactas están en `results_finales/MANIFIESTO.md`.

## Cómo ejecutar

**Datos** (escribe en carpetas nuevas; se niega a sobrescribir):

```bash
py data/01_import_data.py --end 2026-01-01 --raw-dir <nueva> --proc-dir <nueva>
py data/audit/02_audit_data.py --raw-dir ... --proc-dir ... --out-dir <nueva>
```

**MATLAB**: las rutas se leen en `config_rutas.m` desde dos variables de entorno. Para los resultados vigentes, desde la raíz del proyecto:

```matlab
setenv('WK_PANEL', fullfile(pwd, 'data', 'processed_2026-01-01', 'monthly_panel_hibrido.csv'));
setenv('WK_RESULTS_ROOT', fullfile(pwd, 'results_v2'));
```

El orden del pipeline (malla G1 → validación → malla G2 → verificaciones → selección → prueba → bootstrap → régimen) está en la tabla de `results_finales/MANIFIESTO.md`. `preparar_salida.m` detiene un script si su carpeta de salida ya tiene archivos (se puede forzar con `WK_PERMITIR_SOBRESCRIBIR=1`). Las mallas completas son pesadas: conviene probar antes con una sola combinación.

## Resultados

- Resultados vigentes: `results_v2/`.
- Índice de tablas y figuras del documento: `results_finales/RESULTADOS.md`.
- Todas las cifras de tablas y figuras se generan con scripts a partir de los CSV/.mat; ninguna se escribe a mano.

## Archivos retirados

En la rama `limpieza-readme` se retiraron los experimentos descartados (`wdro-hypercube/`, `wdro-return/`), los resultados heredados (`results_out/`, `results_out_wdro/`, `results_prueba_fuera_muestra/`, `wdro-market/results_geometria_mercado/`, `wdro-market/results_comparacion_modelos/`) y reportes de fases cerradas. Se recuperan desde `main` o el historial:

```bash
git checkout main -- wdro-hypercube
```
