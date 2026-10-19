# Tareas pendientes (una por sesión de trabajo)

Cómo usarlo: abre Claude Code en la carpeta del proyecto, activa el modo plan (Shift+Tab) y pega SOLO una tarea a la vez. Cada una termina con un criterio de "terminado" para que Claude sepa cuándo parar. Todas dependen de que `CLAUDE.md` y `metodologia_1.tex` estén en la carpeta.


## T2. Alinear métricas con la metodología
Lee `compute_metrics.m` y la sección "Métricas y evaluación estadística" de `metodologia_1.tex`. Compara definición por definición y reporta las diferencias antes de editar: CVaR con la formulación empírica de Rockafellar–Uryasev (hoy promedia pérdidas ≥ VaR), Sharpe con excesos sobre r_f y √12, Sortino con objetivo cero, convención ante denominador nulo, N_eff=0 sin exposición riesgosa y proporción invertida en riesgo, costo fraccional Σ τ·TO_k y costo monetario Σ W_k τ TO_k / W_0.
Terminado cuando: `compute_metrics.m` coincida con el texto (o el texto con el código, si lo apruebo) y una prueba con η=0 reproduzca las métricas anteriores del nominal.

## T3. Estado del solucionador y "meses sin optimización"
Revisa cómo `run_backtest_*.m` y `solve_*.m` guardan el estado del solver. Debe quedar registrado por mes: estado exacto de MOSEK/CVX, y una clasificación en {óptimo, inaccurate, infeasible certificado, fallo numérico}. Los meses sin solución óptima mantienen el portafolio heredado y se cuentan como "mes sin optimización" para TODAS las estrategias. Con los resultados ya guardados, calcula por (δ, η) cuántos meses sin optimización hay y desde qué fecha; explícame, en especial, las trayectorias casi planas de η≥0.15 después de 2022.
Terminado cuando: exista una tabla (δ, η, geometría, meses sin optimización, por clasificación) y yo pueda reescribir el párrafo de factibilidad de la metodología con datos.

## T4. Malla de validación de la Geometría 2
Replica `main_validation_grid.m` para la Geometría 2 (en `wdro-market/`), con datos truncados a dic-2018. Primero una combinación de prueba y el tiempo estimado; pídeme confirmación antes de correr la malla completa. Salidas en una carpeta nueva. Genera la misma tabla maestra y los mismos gráficos que la Geometría 1.
Terminado cuando: haya tabla maestra comparable a la de la Geometría 1 y se haya verificado que con η=0 ambas geometrías coinciden.

## T5. Verificaciones numéricas con tolerancia explícita
Revisa `test_wdro_nominal_equivalence.m`. Debe comparar valores objetivo y factibilidad con una tolerancia explícita, y las ponderaciones solo si la solución es única o estable. Reporta las tolerancias usadas y los resultados para el texto de la subsección "Implementación y verificación" (incluye: η=0 ⇒ ambas geometrías coinciden; balance x0+Σxj = 1−τ·TO; cotas por activo; cota δ en la ventana).



## T6. Bootstrap móvil por bloques (Künsch, 1989)
Implementa en MATLAB `bootstrap_block_diff.m`: entrada, dos series de factores de crecimiento realizados alineadas por mes; calcula D_k = log G^A − log G^B; remuestrea bloques solapados de longitud ℓ=6 manteniendo la alineación de los pares; B=10 000 réplicas; intervalo percentil 2.5–97.5 de la media de D_k; reporta además la media, la mediana y la proporción de meses con D_k>0. Semilla fija. Sensibilidad con ℓ=3 y ℓ=12. Pruébalo primero con datos simulados de media conocida.
Terminado cuando: haya una tabla con los contrastes (i) G1 vs nominal, (ii) G2 vs G1, (iii) G2 vs nominal, tanto con (δ,η) emparejados como con las configuraciones seleccionadas, SOLO usando resultados ya existentes del periodo de prueba (sin reelegir parámetros).

## T7. Desglose por régimen (descriptivo)
Clasifica cada mes k+1 con información disponible en k: VIX al cierre de k por encima/debajo de la mediana del VIX de la ventana D_k, y retorno de SPY en k negativo/no negativo. Reporta media de D_k y proporción de meses con D_k>0 por régimen. No elijas umbrales mirando el periodo de prueba.

## T8. Confirmar la condición inicial de la prueba
Lee `extract_period_results.m` y `main_test_evaluation.m` y dime, con la línea de código, si el tramo 2019–2025 se obtiene recortando la trayectoria completa (heredando posiciones de 2018) o si reinicia desde 100 % efectivo. Compara con lo que dice la subsección "Backtest de origen móvil" y propón la corrección al texto o al código.

## T9
Tarea T9: elegir (δ, η) por geometría usando SOLO validación (2015–2018, 48 meses). No abras ni uses resultados 2019–2025. No modifiques código existente ni sobrescribas resultados; escribe en results_seleccion/. Presenta el plan y espera aprobación.

Paso 1 (diagnóstico, G1 y G2, tablas de results_validacion_metricas_v2/):
 a) Por (geometría, δ, η): meses con la cota δ activa (holgura ≤ 1e-6).
 b) Para cada η y geometría, compara las celdas con δ ∈ {0.50,0.60,0.70,0.75,0.80}. Si la cota nunca está activa deberían ser la misma estrategia: reporta la máxima diferencia relativa de riqueza final y max|Δx|. Quiero saber cuánto ruido numérico hay entre celdas equivalentes.
 c) Riqueza final vs η para cada δ y geometría, con la pérdida relativa respecto a η=0.

Paso 2: implementa en select_parameters.m esta regla fijada a priori, una selección independiente por geometría:
 1. Elegibles: solo η>0.
 2. Fracción de meses con solución óptima ≥ φ_min = 0.95.
 3. Maximizar la riqueza final de validación.
 4. Empate si la diferencia relativa < TOL; propón TOL a partir del ruido medido en 1b (no menor que ese ruido). Desempate: menor η, luego mayor δ.

Paso 3 (solo reportar, no cambia la elección): top 10 por geometría; qué se elegiría si se incluyera η=0; qué pasa con TOL×10 y TOL/10; mejor celda por Sharpe, CVaR y MDD; si la elegida está en el borde de la malla.

Salidas: seleccion_G1.csv, seleccion_G2.csv, sensibilidad_seleccion.csv y un reporte corto. Posteriormente:

Con las configuraciones aprobadas (δ1*,η1*) y (δ2*,η2*): 
1. Corre G2 sobre los 132 meses SOLO para esas configuraciones (primero una prueba de tiempo). Verifica que los primeros 48 meses reproducen exactamente la trayectoria de validación ya guardada.
2. Evalúa 2019–2025 recortando la trayectoria completa, con las métricas nuevas, para: nominal (η=0, mismo δ de cada configuración), G1 y G2 con (δ1*,η1*), y G1 y G2 con (δ2*,η2*). Esto da el contraste emparejado y el de configuraciones seleccionadas.
3. No barras ninguna malla en prueba. Salida en results_prueba_v2/.

## T10. 
Cuando T1–T8 estén resueltas, genera RESUMEN_PARA_METODOLOGIA.md con: (1) un bloque por cada [PENDIENTE]/REVISAR de metodologia_1.tex, con el dato exacto que lo resuelve; (2) las diferencias entre texto y código encontradas y su estado final; (3) rutas y contenido de las tablas nuevas; (4) los parámetros y configuraciones fijados; (5) lo que no se hizo y por qué. No interpretes resultados ni edites el .tex.


---
Después de cada tarea: pídele que liste qué marcadores `[PENDIENTE]`/`REVISAR` de `metodologia_1.tex` quedaron resueltos y con qué dato; ese resumen me lo puedes traer aquí para actualizar el texto.
