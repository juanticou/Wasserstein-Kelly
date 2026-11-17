# Portafolios Wasserstein–Kelly con costos de transacción

Práctica investigativa (EAFIT, director: Prof. Diego Fonseca). Se comparan tres estrategias de asignación mensual sobre 10 acciones de EE. UU. (AAPL, AMZN, CAT, JNJ, JPM, KO, MSFT, PG, WMT, XOM) más un activo de bajo riesgo:

1. **Kelly nominal**: maximiza el crecimiento logarítmico esperado bajo la distribución empírica.
2. **Wasserstein–Kelly, Geometría 1 (G1)**: versión robusta en una bola de Wasserstein cuyo costo de transporte usa solo los retornos de las acciones.
3. **Wasserstein–Kelly, Geometría 2 (G2)**: el costo de transporte combina retornos de las acciones, retorno de SPY y nivel del VIX, con pesos fijos (0.70, 0.15, 0.15).

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
├── iniciar_rutas.m          agrega codigo/ al path de MATLAB
├── requirements.txt         paquetes de Python
├── data/                    datos y su preparación (Python)
│   ├── 01_import_data.py        descarga (Yahoo, FRED) y panel mensual
│   ├── build_hybrid_panel.py    panel híbrido con el cierre del 31-dic-2025
│   ├── audit/, audit_2026-01-01/    auditoría de datos
│   ├── raw/, raw_2026-01-01/        precios diarios (no se modifican)
│   └── processed/, processed_2026-01-01/   paneles mensuales
├── codigo/                  MATLAB
│   ├── nucleo/                  funciones comunes y G1: solvers, backtests, métricas, rutas, selección, bootstrap
│   ├── geometria2/              costo de transporte con SPY y VIX, backtest y malla de validación de G2
│   ├── pipeline/                scripts que se ejecutan, en el orden del MANIFIESTO (mallas, verificaciones, selección, prueba, bootstrap, régimen)
│   ├── graficos/                funciones plot_*
│   ├── resultados_finales/      r1_* a r8_*: tablas, figuras, inferencia, verificación cruzada e índice
│   └── historico/               scripts de etapas previas, fuera del pipeline (se conservan como referencia)
└── resultados/
    ├── v2/                      resultados vigentes (panel híbrido, cierre del 31-dic-2025)
    ├── linea_base/              resultados anteriores (cierre del 30-dic-2025)
    └── finales/                 tablas (.csv/.tex), figuras (.pdf/.png), inferencia, MANIFIESTO.md, RESULTADOS.md
```

## Requisitos

- MATLAB R2026a con CVX 2.2 y MOSEK 9.1.9 (el que viene con CVX).
- Python 3.13 con los paquetes de `requirements.txt`: `pip install -r requirements.txt`.

Las versiones exactas están en `resultados/finales/MANIFIESTO.md`.

## Cómo ejecutar

**Datos** (escribe en carpetas nuevas; se niega a sobrescribir):

```bash
py data/01_import_data.py --end 2026-01-01 --raw-dir <nueva> --proc-dir <nueva>
py data/audit/02_audit_data.py --raw-dir ... --proc-dir ... --out-dir <nueva>
```

**MATLAB**, desde la raíz del proyecto:

```matlab
iniciar_rutas                      % una vez por sesión (cada script también lo hace por su cuenta)
setenv('WK_PANEL', fullfile(pwd, 'data', 'processed_2026-01-01', 'monthly_panel_hibrido.csv'));
setenv('WK_RESULTS_ROOT', fullfile(pwd, 'resultados', '<carpeta nueva>'));
run('codigo/pipeline/main_grid_delta_eta.m')   % o r1_ejecutar({...}) para varios pasos
```

`config_rutas.m` lee `WK_PANEL` y `WK_RESULTS_ROOT`; si están vacías usa `data/processed/monthly_panel.csv` y `resultados/linea_base/`. `preparar_salida.m` detiene un script si su carpeta de salida en la línea base ya tiene archivos (se puede forzar con `WK_PERMITIR_SOBRESCRIBIR=1`). Las mallas completas son pesadas: conviene probar antes con una sola combinación.

El orden del pipeline (malla G1 → validación → malla G2 → verificaciones → selección → prueba → bootstrap → régimen) está en la tabla de `resultados/finales/MANIFIESTO.md`. Las tablas y figuras finales se regeneran con `r2_tablas`, `r3_figuras`, `r4_inferencia`, `r5_verificacion_cruzada`, `r6_resultados` y `r8_tiempos_adversarial`, que solo leen `resultados/v2/` y escriben en `resultados/finales/`.

## Resultados

- Resultados vigentes: `resultados/v2/`.
- Índice de tablas y figuras: `resultados/finales/RESULTADOS.md`.
- Todas las cifras de tablas y figuras se generan con scripts a partir de los CSV/.mat; ninguna se escribe a mano.

## Rutas antiguas → nuevas

`MANIFIESTO.md` y los reportes de `resultados/finales/` (`REPORTE_R1.md`, `REPORTE_SESION_2026-11-04.md`, `ANALISIS_RESULTADOS_DISCUSION.md`) se escribieron con las rutas anteriores a la reorganización:

| Antes | Ahora |
|---|---|
| `*.m` en la raíz | `codigo/nucleo/`, `codigo/pipeline/`, `codigo/graficos/` o `codigo/historico/` |
| `wdro-market/*.m` | `codigo/geometria2/` (`main_geometria_mercado.m` y `main_comparacion_modelos.m` en `codigo/historico/`) |
| `results_finales/*.m` | `codigo/resultados_finales/` |
| `results_finales/` (salidas) | `resultados/finales/` |
| `results_v2/` | `resultados/v2/` |
| `results_*` de la raíz y `wdro-market/results_validacion_grid_market/` | `resultados/linea_base/` (misma estructura interna) |

## Archivos retirados

Se retiraron del repositorio los `.tex` del artículo (`main_6.tex`, `metodologia_6.tex`, `resultados_6.tex`, `discusion_6.tex`), los experimentos descartados (`wdro-hypercube/`, `wdro-return/`) y los resultados heredados de etapas previas. Se recuperan desde el historial, por ejemplo:

```bash
git checkout b4db6d5 -- metodologia_6.tex
```
