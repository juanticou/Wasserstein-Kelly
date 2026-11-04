# Reporte de la sesión del 3–4 de noviembre de 2026

Documento interno de trabajo (no se inserta en el manuscrito). Resume qué se hizo, qué se cambió en `metodologia_6.tex`, qué decisiones y desviaciones hubo, y el plan para el análisis de resultados. Las cifras citadas salen de los CSV indicados; ante cualquier diferencia, mandan los CSV.

Punto de partida: revisión del documento guía del director («Propuesta de Práctica Investigativa… Versión Detallada», jul-2026) frente al trabajo existente (rama `resultados-r3-r7`, commit `df7d4f6`). El documento guía es auxiliar: **no se cita ni se menciona en el manuscrito**.

## 1. Commits de la sesión

| Commit | Contenido |
|---|---|
| `c6df0e5` | Benchmarks (bajo riesgo, igual ponderación, SPY pasivo) y Kelly nominal sin costos; confirmación de MOSEK nativo en `RESULTADOS.md`. |
| `ba723ab` | R2, R3 y R6: tablas (e) y (f), dos figuras nuevas, índice actualizado. |
| `0781a0b` | `main_6.tex` y `metodologia_6.tex`: cambios previos del autor + estrategias de referencia ([C9b], [R-ref]). |
| `c8de506` | `test_seccion_21_4.m`: instancia sintética, primal–dual, monotonía en el radio. |
| `c6384a2` | `metodologia_6.tex`: verificaciones (d)–(f) [R-21.4]; se retiran las menciones al documento guía. |
| `5f239cd` | `metodologia_6.tex`: marcas `%%% [RESULTADO]` en pasajes que reportan resultados. |
| `f81305c` | `main_tiempos_solucion.m`: tiempos de solución por mes. |
| (este commit) | `main_probabilidades_adversariales.m` y este reporte. |

## 2. Trabajo realizado

1. **CVX + MOSEK nativo (confirmado).** El aviso de «successive approximation» de CVX es genérico: lo imprime `lib/cvx_expert_check.m` al construir `log()`, sin importar el solucionador. En CVX 2.2 build 1148, `lib/@cvxprob/solve.m` desactiva la aproximación sucesiva con MOSEK ≥ 9; el log muestra «Calling Mosek 9.1.9», una sola llamada, con conos exponenciales. El texto de `metodologia_6.tex` («MOSEK admite de forma nativa…») es correcto. Nota: el solucionador por defecto de CVX en este equipo es SDPT3; el código del proyecto fija MOSEK explícitamente.
2. **Estrategias de referencia** (`run_backtest_benchmark.m`, `main_benchmarks.m`; `results_v2/results_benchmarks/`, 25/25 comprobaciones). Bajo riesgo; igual ponderación con costos (rebalanceo mensual, c_k por bisección sobre la ecuación de balance); SPY pasivo (compra única en dic-2014 con costo); Kelly nominal sin costos con δ ∈ {0.80, 0.90} y turnover canónico Σ|x − h|. Mismo protocolo que las seis estrategias (inicio en efectivo, 132 meses, tramos por recorte).
3. **Integración en R2, R3 y R6** (sin alterar lo existente): tablas `tabla_e_prueba_referencias` y `tabla_f_validacion_referencias`; figuras `riqueza_referencias_prueba` y `turnover_con_sin_costos_prueba`; `RESULTADOS.md` con dos afirmaciones descriptivas y una limitación nueva (no hay contrastes frente a las referencias). Comprobaciones: R2 360/360, R3 77/77, total del índice 1149.
4. **Pruebas de verificación** (`test_seccion_21_4.m`; `results_v2/results_pruebas_21_4/`, 153/153): (A) instancia sintética 3×6 frente a búsqueda exhaustiva y con costos; (B) LP adversarial primal (MOSEK y SDPT3) frente al dual, a la fórmula cerrada y al valor de `solve_wdro_kelly`, y recuperación de p; (C) valor robusto no creciente en ρ (portafolio fijo y óptimo re-resuelto).
5. **Tiempos de solución** (`main_tiempos_solucion.m`; `results_v2/results_tiempos/`). Re-resolución de los 792 problemas mensuales de las seis estrategias con el h_k guardado; ρ_k y x_k reproducen lo guardado en los 792. Tiempos en `tiempos_resumen.csv`; entorno en `entorno_tiempos.csv` (sin usuario ni ID del equipo).
6. **Probabilidades adversariales** (`main_probabilidades_adversariales.m`; `results_v2/results_probabilidades_adversariales/`, 5820/5820). Distribución adversarial p en las 132 fechas, c1 y c2, G1 y G2, con portafolio común (nominal del mismo δ; aísla la geometría) y propio. Indicadores en `resumen_por_fecha.csv`; detalle por escenario en las tres fechas fijas en `detalle_fechas_fijas.csv`. SDPT3 reproduce la p de MOSEK en esas fechas (diferencias ≤ 2.1e-7, `verificaciones.csv`).

## 3. Lo que se agregó hoy a `metodologia_6.tex` (solo procedimiento)

Buscar por marca:

| Marca | Sección | Contenido |
|---|---|---|
| `[R-ref]` (≈ l. 31) | Diseño general | Anuncio de las cuatro referencias descriptivas. |
| `[C9b]` (≈ l. 62) | Universo y fuentes | SPY: retorno de mercado y referencia pasiva de comprar y mantener (antes: «no se incluyó como estrategia de comparación»). |
| `[R-ref]` (≈ l. 380) | Protocolo | Párrafo «Estrategias de referencia» (`sec:referencias`): construcción de cada referencia, turnover canónico, que se implementaron después de evaluar las seis estrategias en prueba, sin contrastes, y qué métricas no aplican. |
| `[R-21.4]` (≈ l. 470) | Implementación y verificación | Verificaciones (d) instancia sintética, (e) primal–dual y p, (f) monotonía en el radio, con tolerancias y solucionadores; sin resultados. |

Se retiraron del texto y de esos comentarios todas las menciones al documento guía. `main_6.tex` no se editó en la sesión.

**Pasajes marcados `%%% [RESULTADO]`** (reportan resultados dentro de Metodología; decidir si se mueven a Resultados o se reformulan como procedimiento): ajuste de dividendos y desdoblamientos; descarga y panel (4045/4046 días, 192 meses); «no hubo fechas duplicadas…»; auditoría de discrepancias; «0 de 2496»; conteo de IQR < ε; «el nominal ocupaba los primeros puestos» (selección); «primeros 48 meses coinciden» (fase de prueba); empates |D_k| < 1e-6 (inferencia); redacción de (a)–(c) en verificación.

## 4. Decisiones y desviaciones a tener presentes

- **Referencias implementadas después de ver la prueba** de las seis estrategias (siguiendo el documento guía). Se declaró en el texto; no intervienen en la selección y no tienen contrastes.
- Convenciones de las referencias: SPY paga costo solo en la compra inicial; igual ponderación invierte todo (x₀ = 0) tras costos; bajo riesgo tiene Sharpe, Sortino y Calmar no definidos (se muestran «—»).
- `compute_metrics.m` devuelve ruido en el Sharpe cuando el exceso sobre r^f es idénticamente cero; no se modificó (no afecta a las seis estrategias); el caso se trata en `main_benchmarks.m`.
- Figuras 1–8 de R3: al regenerarse cambiaban byte a byte (metadatos); se restauraron las del commit.
- Instancia sintética: la primera versión tenía óptimo de esquina (prueba no informativa) y se rediseñó para óptimo interior antes de la corrida completa.
- No hay Gurobi ni `linprog` en el equipo: el LP se verificó con MOSEK y SDPT3. SDPT3 devolvió `Inaccurate/Solved` en 2 instancias degeneradas (jun-2022, η = 0.30) con diferencia ~2.8e-8 respecto a MOSEK; registrado en `pruebas_21_4.csv`.
- Los tiempos son de este equipo (MATLAB R2026a, CVX 2.2 b1148, MOSEK 9.1.9, 8 núcleos), una medición por mes.

## 5. Plan para el análisis de resultados (pendiente; no se ha redactado nada en el manuscrito)

**Decisiones previas (del autor y del director):**
1. Si se reportan en prueba los η = 0.05, 0.15, 0.30 previstos en el documento guía (requiere correr esas configuraciones; choca con la regla «no hay mallas nuevas»).
2. Qué hacer con los pasajes `[RESULTADO]` de Metodología.
3. Si se calculan contrastes D_k exploratorios frente a las referencias (las cifras descriptivas ya se vieron, lo que debe declararse).
4. Si los tiempos y las probabilidades adversariales entran como tabla/figura (R2/R3) y en el índice (R6); hoy son solo CSV.

**Estructura propuesta para Resultados** (cada cifra desde un script, como en R2–R6; prueba descriptiva salvo intervalos de R4):
1. Estabilidad numérica y verificación: meses sin optimización, cota δ activa, pruebas (a)–(f), tiempos de solución.
2. Validación y selección: mapas δ × η, sensibilidad de la regla, trayectorias planas con η ≥ 0.30.
3. Prueba, desempeño y operación: tablas (a)–(c) y referencias (e); figuras de riqueza, caída, riesgo/N_eff, turnover/costo.
4. Contraste principal G2 vs. G1 emparejado: tabla R4a e IC; resultado nulo dicho con claridad.
5. Costos frente a robustez: nominal con y sin costos y WK (turnover, costo, riqueza).
6. Cómo repondera cada geometría: probabilidades adversariales (masa movida, masa en VIX alto y SPY < 0), en el caso de portafolio común.
7. Desglose por régimen (R4b, R4c), descriptivo.

**Discusión:** robustez efectiva concentrada en η muy pequeño; la geometría informada no mejora de forma consistente (resultado negativo válido); papel de los costos; limitaciones (universo fijo, una trayectoria, uso previo de la prueba, referencias posteriores a la prueba, pesos de G2 fijos).

**Extensiones (solo si sobra tiempo):** Kelly fraccionario, mínima varianza, otros τ, estrés, Δlog VIX, regímenes, segundo universo.

## 6. Reproducción

Desde la raíz del proyecto en MATLAB, antes de cada script:

```matlab
setenv('WK_PANEL', fullfile(pwd,'data','processed_2026-01-01','monthly_panel_hibrido.csv'));
setenv('WK_RESULTS_ROOT', fullfile(pwd,'results_v2'));
```

Orden: `main_benchmarks` → `results_finales/r2_tablas`, `r3_figuras`, `r6_resultados` → `test_seccion_21_4` → `main_tiempos_solucion` → `main_probabilidades_adversariales`. Los scripts nuevos abortan si su carpeta de salida ya tiene archivos.
