# Proyecto: Portafolios Wasserstein–Kelly con costos de transacción

Práctica investigativa (EAFIT, director: Prof. Diego Fonseca). Compara tres estrategias de asignación mensual sobre 10 acciones de EE. UU.: Kelly nominal, Wasserstein–Kelly con Geometría 1 (solo retornos) y Wasserstein–Kelly con Geometría 2 (retornos + retorno de SPY + VIX). Los `.tex` del artículo (`main_6.tex`, `metodologia_6.tex`, `resultados_6.tex`, `discusion_6.tex`) se retiraron del repositorio; se recuperan con `git checkout b4db6d5 -- metodologia_6.tex`.

## Cómo leer los documentos
- `metodologia_6.tex` (en el historial, commit `b4db6d5`) describe lo que el código DEBE hacer. Los marcadores `[PENDIENTE: ...]` son trabajo por hacer; los comentarios `%%% [C#]`, `%%% [R#]` y `%%% [D-p#]` son correcciones ya aplicadas al texto; `REVISAR` indica que el texto debe coincidir con el código y hay que verificarlo.
- La fuente de verdad es el código: si el texto y el código difieren, no cambies el texto en silencio; repórtalo.

## Estructura de carpetas
- `data/`: Python (`01_import_data.py`, `build_hybrid_panel.py`, `audit/`), `data/raw/`, `data/processed/` y `data/processed_2026-01-01/` (panel vigente `monthly_panel_hibrido.csv`).
- `codigo/nucleo/`: funciones comunes y de la Geometría 1 (`solve_*`, `run_backtest_*`, `compute_metrics.m`, `extract_period_results.m`, `select_parameters.m`, `config_rutas.m`, `raiz_proyecto.m`, …).
- `codigo/geometria2/`: Geometría 2 (`build_transport_cost_market.m`, `run_backtest_wdro_kelly_market.m`, `main_validation_grid_market.m`, …).
- `codigo/pipeline/`: scripts de los pasos 3–16 del MANIFIESTO y complementarios (`main_*.m`, `verify_*.m`, `test_*.m`, …). `codigo/graficos/`: `plot_*.m`. `codigo/resultados_finales/`: `r1_*.m` a `r8_*.m`. `codigo/historico/`: scripts de etapas previas, fuera del pipeline.
- Rutas: cada script agrega `codigo/` al path (o `iniciar_rutas.m` en la raíz). `config_rutas.m` lee `WK_PANEL` (panel) y `WK_RESULTS_ROOT` (raíz de los `results_*`); vacía, usa `resultados/linea_base/`. Resultados vigentes y aprobados: `resultados/v2/`. Ver `resultados/finales/MANIFIESTO.md` (escrito con las rutas antiguas; la tabla de equivalencias está en `README.md`).
- `resultados/linea_base/`: resultados con el cierre del 30-dic-2025 (antes `results_*` en la raíz). `resultados/finales/`: tablas, figuras, inferencia, verificación cruzada e índice (`RESULTADOS.md`) de la fase de resultados.
- `wdro-hypercube/` y `wdro-return/`: experimentos DESCARTADOS de la metodología; se retiraron (recuperables desde el historial). No los uses.

## Diseño experimental (no lo cambies sin preguntar)
- Datos mensuales ene-2010 a dic-2025. Ventana móvil N=60. Costo τ=0.001, x̄=0.25, γ=1. Solver: CVX + MOSEK.
- Validación: 2015–2018 (48 meses). Prueba: 2019–2025 (84 meses). Prohibido elegir o ajustar parámetros mirando resultados de prueba.
- Uso previo de la prueba (limitación de `metodologia_6.tex`): antes de fijar la regla de selección hubo corridas sobre la trayectoria completa (incluida la prueba) para comprobar la optimización y explorar la factibilidad; la malla se construyó con ese criterio, no con el desempeño. Ningún parámetro se eligió con la prueba, pero la prueba no es estrictamente virgen ni es una validación externa ciega.
- Mallas: δ ∈ {0.50,0.60,0.70,0.75,0.80,0.90}; η ∈ {0,0.01,0.02,0.03,0.04,0.05,0.10,0.15,0.30,0.50,1.00}. η=0 equivale al nominal. Nunca δ>1.
- Regla de selección (T9, `select_parameters.m` y `main_seleccion_parametros.m`, por geometría y solo con validación): η>0; fracción de meses con solución óptima ≥ 0.95; máxima riqueza final de validación; empate si la brecha relativa es < TOL = 5e-4 (calibrada con el ruido entre celdas equivalentes); desempate por menor η y luego mayor δ. Elegidas: G1 → (0.90, 0.01); G2 → (0.80, 0.01).
- Geometría 2: pesos (0.70, 0.15, 0.15) fijos; VIX solo en nivel.
- Hecho matemático importante: con δ≤0.90 el problema SIEMPRE es factible (se puede ir todo a bajo riesgo). Cualquier "no factible" en los resultados es un fallo numérico o de software, no factibilidad teórica; hay que registrarlo así. La columna `fraccion_factible` mide la fracción de meses con solución óptima (`fraccion_optima`), no factibilidad teórica.

## Reglas de trabajo
- Nunca modifiques `data/raw/` ni sobrescribas resultados existentes: escribe en carpetas nuevas con nombre claro.
- No ejecutes mallas completas (son pesadas) sin antes probar con una combinación pequeña y estimar el tiempo.
- No inventes datos, citas ni cifras: si algo falta, repórtalo como pendiente.
- Antes de cambiar código existente, explica el cambio; después de cambiarlo, verifica que con η=0 se recupera el Kelly nominal.
- Trabaja en modo plan primero y espera aprobación en tareas que modifican código.
- Responde en español.

## Reglas de la fase de resultados
- No se elige ni se ajusta ningún parámetro con resultados de prueba. No hay mallas nuevas ni se refina η por debajo de 0.01.
- Ninguna cifra de tablas, figuras o índices se escribe a mano: cada una sale de un script que lee los CSV/.mat existentes.
- Los resultados de prueba son descriptivos. Sin intervalo del bootstrap no se afirma superioridad; el contraste principal es G2 frente a G1 con parámetros emparejados y los demás son exploratorios.
- Tablas en `.tex` insertables con `\input`, con `\hline` (el documento no carga `booktabs` ni `multirow`); figuras en PDF y PNG, legibles en blanco y negro.
