# Proyecto: Portafolios Wasserstein–Kelly con costos de transacción

Práctica investigativa (EAFIT, director: Prof. Diego Fonseca). Compara tres estrategias de asignación mensual sobre 10 acciones de EE. UU.: Kelly nominal, Wasserstein–Kelly con Geometría 1 (solo retornos) y Wasserstein–Kelly con Geometría 2 (retornos + retorno de SPY + VIX). El texto del trabajo está en `main_1.tex` y `metodologia_1.tex`.

## Cómo leer los documentos
- `metodologia_1.tex` describe lo que el código DEBE hacer. Los marcadores `[PENDIENTE: ...]` son trabajo por hacer; los comentarios `%%% [C#]` son correcciones del director ya aplicadas al texto; `REVISAR` indica que el texto debe coincidir con el código y hay que verificarlo.
- La fuente de verdad es el código: si el texto y el código difieren, no cambies el texto en silencio; repórtalo.

## Estructura de carpetas
- Raíz `Wasserstein-Kelly/`: Python (`01_import_data.py`, `02_visualize_data.py`), `data/raw/`, `data/processed/monthly_panel.csv`, y el MATLAB común y de la Geometría 1 (`solve_nominal_kelly.m`, `solve_wdro_kelly.m`, `run_backtest_*.m`, `compute_metrics.m`, `extract_period_results.m`, `main_*.m`).
- `wdro-market/`: Geometría 2 (`build_transport_cost_market.m`, `run_backtest_wdro_kelly_market.m`, `main_geometria_mercado.m`).
- `wdro-hypercube/` y `wdro-return/`: experimentos DESCARTADOS de la metodología. No los modifiques ni los uses.

## Diseño experimental (no lo cambies sin preguntar)
- Datos mensuales ene-2010 a dic-2025. Ventana móvil N=60. Costo τ=0.001, x̄=0.25, γ=1. Solver: CVX + MOSEK.
- Validación: 2015–2018. Prueba: 2019–2025. La prueba se usó UNA vez con δ=0.90, η=0.01 (Geometría 1). Prohibido elegir o ajustar parámetros mirando resultados de prueba.
- Mallas: δ ∈ {0.50,0.60,0.70,0.75,0.80,0.90}; η ∈ {0,0.01,0.02,0.03,0.04,0.05,0.10,0.15,0.30,0.50,1.00}. η=0 equivale al nominal. Nunca δ>1.
- Geometría 2: pesos (0.70, 0.15, 0.15) fijos; VIX solo en nivel.
- Hecho matemático importante: con δ≤0.90 el problema SIEMPRE es factible (se puede ir todo a bajo riesgo). Cualquier "no factible" en los resultados es un fallo numérico o de software, no factibilidad teórica; hay que registrarlo así.

## Reglas de trabajo
- Nunca modifiques `data/raw/` ni sobrescribas resultados existentes: escribe en carpetas nuevas con nombre claro.
- No ejecutes mallas completas (son pesadas) sin antes probar con una combinación pequeña y estimar el tiempo.
- No inventes datos, citas ni cifras: si algo falta, repórtalo como pendiente.
- Antes de cambiar código existente, explica el cambio; después de cambiarlo, verifica que con η=0 se recupera el Kelly nominal.
- Trabaja en modo plan primero y espera aprobación en tareas que modifican código.
- Responde en español.
