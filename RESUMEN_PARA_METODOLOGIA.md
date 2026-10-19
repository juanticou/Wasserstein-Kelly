# Resumen para la metodología (T10)

Fecha: 2026-10-19. Texto de referencia: **`metodologia_2.tex`** (líneas citadas en ese archivo). `CLAUDE.md` y `TAREAS_PENDIENTES.md` nombran `metodologia_1.tex`, que no existe en la carpeta.

Este documento no interpreta resultados y no se editó ningún `.tex`. Los detalles de cada tarea están en los reportes enlazados en §3.

---

## 1. Un bloque por cada `[PENDIENTE]` / `REVISAR`

### l. 7 — instrucción general «[PENDIENTE: ...]»
Es una nota de uso, no un pendiente. No requiere dato.

### l. 52 (REVISAR C6) y l. 54 — clasificación GICS y criterio de selección
- **Estado:** no se resuelve con datos ni con código; es una decisión del autor (T1).
- **Dato:** ninguno.

### l. 64 (C7) — cuatro `[PENDIENTE]` de datos (T1, `data/audit/audit_report.md` §8)
- **Fecha de descarga:** 2026-08-12 (Yahoo Finance, `data/raw/download_log.csv`). DGS3MO no está en el log; su archivo está en el mismo commit.
- **Periodo efectivo por ticker:**
  - 12 series de Yahoo: 2009-12-01 a 2025-12-30 (el `end` de yfinance es exclusivo).
  - DGS3MO: 2009-12-01 a 2025-12-31.
  - Panel mensual: ene-2010 a dic-2025, 192 meses, 0 NaN.
  - El texto cita `audit_report.csv`; el dato está en `data/audit/audit_report.md` §1.
- **Criterio ante faltantes:** no se imputó nada; se tomó el último dato disponible de cada mes. El `ffill` entre meses se usó en 0 meses. El único día hábil ausente (31-dic-2025) no se rellenó.
- **Regla ante discrepancias (PROPUESTA, la decides tú):** prevalece Yahoo Finance; se registra como discrepancia un error de precio > 0.5 % o una diferencia de retorno > 0.25 pp. Resultado: 14 activo-mes fuera de tolerancia, 4 sin explicar, máx. |dif. de retorno| = 3.79e-2.
- **Diferencia de texto:** el contraste se hizo contra **Tiingo** (acciones y SPY) y **CBOE** (VIX), no contra Stooq (ver §2).

### l. 79 (REVISAR C8) y l. 81 — sin datos posteriores al cierre
- **Confirmado (T1):** 0 datos posteriores al fin de mes; 0 de 2 496 celdas distintas al recomputar el panel.
- La descripción `resample('ME').last()` + `ffill` coincide con `01_import_data.py`.
- SPY y VIX tienen 1 mes (dic-2025) cuyo último dato es el 30-dic-2025.

### l. 143 (REVISAR C12/C13a) — «sin distancias positivas ⇒ ρ_k = 0»
- **Coincide** con `compute_rho.m:29-34`.
- No se activa nunca: el mínimo de c_rs fuera de la diagonal es 0.142 (G1) y 0.193 (G2) en las 132 ventanas.

### l. 145 — PENDIENTE (opcional): resumen de las distancias c_rs
- **Hecho:** `results_verificaciones/resumen_distancias_c.csv`.
- Mediana entre ventanas de [p25, mediana, p75]:
  - 132 ventanas: G1 [0.646, 0.830, 1.074]; G2 [0.628, 0.821, 1.092].
  - Validación (48): G1 [0.657, 0.823, 1.034]; G2 [0.629, 0.811, 1.083].
- La comparación del objetivo en el peor caso con un η común **no se hizo**.

### l. 171 (REVISAR C14) y l. 173 — ventanas con IQR < ε_esc
- **Conteo = 0** en las 12 series (10 retornos, SPY y VIX) y las 132 ventanas.
- IQR mínimo: 0.0256 (SPY).
- La regla de exclusión no está implementada; con conteo 0 no se habría activado.

### l. 187 (REVISAR C15) — razón de los pesos 70/15/15
- **Estado:** decisión del autor.
- **Dato:** ninguno.

### l. 189 — PENDIENTE (opcional): pesos alternativos
**No se hizo.**

### l. 203 (REVISAR C17) y l. 205 — condición inicial del tramo de prueba (T8)
**Confirmado: el tramo 2019–2025 se obtiene recortando la trayectoria completa y hereda el portafolio de 2018; no reinicia desde 100 % efectivo.** Líneas de código:
- `run_backtest_nominal_kelly.m:55,60-61`, `run_backtest_wdro_kelly.m:48,51-52`, `wdro-market/run_backtest_wdro_kelly_market.m:56,59-60`: `decision_idx = N:(T-1)` (primera decisión el 31-dic-2014), `h_current = [1; zeros(d,1)]` y `W_current = 1`. Es la única inicialización de cada trayectoria.
- Mismos archivos, líneas 158 / 147 / 158: `h_current = h_next`. El portafolio se hereda mes a mes, sin reinicios.
- `main_test_evaluation.m:59-60`: toma la trayectoria completa guardada (`grid.results_wdro{i,j}`).
- `main_test_evaluation.m:91,93`: `extract_period_results(r_full, TEST_START, TEST_END)`.
- `extract_period_results.m:49-51`: selecciona por fecha de realización. `:58-65` copia x, x0, turnover, etc. tal como están. `:70` re-basa la riqueza con `[1; cumprod(growth_real)]`. No hay ninguna reinicialización de h.
- Las corridas nuevas hacen lo mismo: `main_test_evaluation_v2.m` y `wdro-market/main_comparacion_modelos.m:81-91,148`.

Portafolio heredado en la decisión del 31-dic-2018 (primer mes de prueba): h_0 = 0.0000 y Σ_j h_j = 1.0000 en las 6 estrategias evaluadas. Entrar desde efectivo habría costado τ·Σx ≈ 0.00096–0.00100 de la riqueza en esa fecha. No se corrió un backtest alternativo que empiece en efectivo en 2019.

**Comparación con el texto (l. 205):** el texto actual («El tramo de prueba no reinició posiciones … parte del portafolio heredado h_k acumulado al cierre de 2018, y la riqueza se re-basó a uno») **coincide con el código**. El `[PENDIENTE]` se puede retirar.

**Correcciones propuestas (no aplicadas):**
- *Texto:* ninguna obligatoria. Opcional, para mayor precisión: «En la primera fecha de decisión de la prueba (31-dic-2018) el portafolio heredado estaba íntegramente en activos riesgosos en todas las estrategias evaluadas».
- *Código:* corregir el comentario de `extract_period_results.m:13-17`. La primera mitad es correcta: los meses 2015–2018 son idénticos a detener el backtest en 2018. La segunda («matemáticamente equivalente a correr cada tramo por separado») es falsa para el tramo de prueba con portafolio heredado y costos, como señaló el director en C24. Lo mismo vale para la justificación de la cabecera de `main_validation_grid.m:5-8`. Solo son comentarios; el cálculo es correcto.

### l. 219 (REVISAR C18) y l. 221 — precisión del solver y estado por mes
- **Precisión:** CVX 2.2 (build 1148) con MOSEK 9.1.9; `cvx_precision` por defecto = [1.49e-8, 1.49e-8, 1.22e-4]; `cvx_slvtol` alcanzado = 1.49e-8 en todos los meses registrados.
- **Estado por mes:**
  - Antes de T3 solo se guardaba `cvx_status`.
  - Desde T3 se guardan, en los tres `run_backtest_*.m`: `cvx_status`, el estado nativo de MOSEK (problema / solución), la clase {óptimo, inaccurate, infeasible certificado, fallo numérico}, `cvx_slvtol`, `cvx_slvitr` y `cvx_precision`.
  - Las corridas antiguas (malla G1 y malla de validación G2) solo tienen `cvx_status`.
- **Conteo:** 0 meses sin optimización en 149 corridas / 14 124 meses. 0 inaccurate, 0 infeasible certificado, 0 fallos numéricos. Las corridas nuevas dan MOSEK PRIMAL_AND_DUAL_FEASIBLE / OPTIMAL en todos sus meses (`results_estado_solver/tabla_meses_sin_optimizacion.csv`).

### l. 254 (REVISAR C19) — fracciones factibles < 1
- **No hay ninguna:** la fracción de meses con solución óptima es 1 en las 66 celdas de G1 (malla completa) y en las 66 de G2 (validación). No hubo fallos numéricos que reportar.
- **Cota δ activa** (holgura ≤ 1e-6):
  - Validación: solo con δ = 0.90. G1 con η ∈ {0, 0.01, 0.02, 0.03, 0.04}: 8, 6, 4, 4, 1 meses de 48. G2 con η ∈ {0, 0.01, 0.02}: 8, 4, 3 meses (`results_seleccion/diagnostico_cota_delta.csv`).
  - Prueba (configuraciones evaluadas): con δ = 0.90, 60 (G1), 66 (G2) y 65 (nominal) de 84 meses; con δ = 0.80, 0.

### l. 261 — PENDIENTE interno C20: malla de validación de G2
**Hecha:** `wdro-market/results_validacion_grid_market/`, 66 celdas × 48 meses, todas óptimas. Tablas con las métricas nuevas en `results_validacion_metricas_v2/`.

### l. 265 (REVISAR C21/C23) y l. 267 — φ_min y desempate
- **Regla aplicada en T9** (fijada por ti antes de ejecutar; `select_parameters.m`):
  1. Solo η > 0.
  2. φ_min = **0.95**.
  3. Maximizar la riqueza final de validación.
  4. Empate si la brecha relativa es < TOL; desempate por menor η y luego mayor δ.
- **TOL = 5e-4.** Es el ruido máximo medido entre celdas equivalentes (4.62e-4), redondeado hacia arriba a {1, 2, 5}×10^k.
- **Elegidas:** G1 → (δ, η) = **(0.90, 0.01)**; G2 → **(0.80, 0.01)**. La de G2 sale de un empate de 5 celdas, δ ∈ {0.50, …, 0.80} con η = 0.01.
- **Celdas elegibles:** 60 de 66 por geometría.
- **Diferencias con el texto:** ver §2, filas 7–9.

### l. 290 (REVISAR C25) — CVaR empírico
**Alineado** (T2):
- CVaR: formulación empírica de Rockafellar–Uryasev, evaluada de forma exacta.
- VaR: el minimizador ζ* = L_(⌈αT⌉), sin interpolar.

### l. 296 (REVISAR C27) — Sharpe, Sortino y denominador nulo
**Alineado** (T2):
- Sharpe: √12·ē/s_e con e_t = R_t − r^f del mes de decisión (`results.rf`).
- Sortino: √12·R̄/DD₀, con DD₀ calculado sobre los T meses.
- Calmar: CAGR/MDD.
- Si el denominador es nulo, la razón es NaN («no definida»).

### l. 302 (C28) — costo fraccional y monetario
**Alineado** (T2):
- `costo_fraccional` = τ·ΣTO.
- `costo_monetario` = Σ W_k τ TO_k / W_0, con el W_0 del tramo.
- La columna antigua `costo_total` se conserva con su significado anterior (ver §2).

### l. 308 (REVISAR C29) — N_eff = 0 sin exposición
- **Confirmado** en `compute_metrics.m` (umbral 1e-8) y en `plot_neff_series.m` (umbral > 0).
- Se añadieron la proporción invertida en riesgo y los meses sin exposición.
- El promedio de N_eff se calcula sobre los meses con exposición.

### l. 323 (REVISAR C30/C34) y l. 324, 327 — bootstrap por bloques (T6)
- **Implementado** (`bootstrap_block_diff.m`):
  - Bloques solapados, pares alineados.
  - ℓ = 6, B = 10 000, percentiles 2.5–97.5.
  - Semilla 20261019.
  - Sensibilidad con ℓ = 3 y ℓ = 12 hecha.
- **Prueba simulada:** D_k = μ + AR(1) con φ = 0.3, T = 84, 500 simulaciones. Cobertura empírica del intervalo del 95 %: 0.90 (ℓ = 3), 0.90 (ℓ = 6) y 0.86 (ℓ = 12); sesgo de la media 1.3e-7 (`results_bootstrap/test_simulado.csv`).
- **Resultados:** `results_bootstrap/tabla_bootstrap_contrastes.csv` (7 contrastes distintos × 3 valores de ℓ). Ver §3.
- La l. 324 es un comentario con el texto anterior; queda resuelta junto con la l. 327.

### l. 331 (REVISAR C31) y l. 333 — desglose por régimen (T7)
- **Confirmado:** se calculó como dice el texto.
  - VIX al cierre de k frente a la mediana del VIX de la ventana D_k (60 meses que terminan en k, **incluido k**).
  - Retorno de SPY en k: negativo / no negativo.
  - Solo información disponible en k.
- **Detalles para el texto:** empate VIX_k = mediana → «bajo»; también se calculó el cruce 2×2.
- **Grupos en prueba:** VIX alto 48 y bajo 36; SPY_k < 0 28 y ≥ 0 56; en el 2×2: 23 / 25 / 5 / 31 (`results_regimen/`).
- **l. 336 (comentada, opcional):** queda cubierta por lo mismo.

### l. 341 (REVISAR C32) y l. 343 — tolerancias (T5)
- **Valor objetivo:** **1e-6** (absoluta). La factibilidad se comprueba con **1e-7** (residuo máximo de las restricciones).
- **Ponderaciones:** **1e-5**, solo si la solución es única. Criterio de unicidad: A = [(1+r_f)𝟙, 1+R] con rango de columna completo.
- **Resultados:**
  - 3 instancias (dic-2014, dic-2018, jun-2022): |Δobj| = 0; residuo ≤ 4.3e-8; rango 11/11, cond(A) entre 140 y 157; |Δx| = 0.
  - Backtest completo, nominal vs η = 0, 6 δ × 132 meses: |ΔG| = |Δx| = |ΔW_T| = 0.

### l. 346 (comentada) — dos `[PENDIENTE]`
- **Verificaciones (a), (b) y (c):** las tres se corrieron y quedaron registradas en `results_verificaciones/`; no hay que retirar ninguna.
  - (b) en 132 celdas: balance ≤ 1.94e-10; cotas por activo y cota δ en la ventana con violación 0.
  - (c) η = 0: G1 = G2 mes a mes, diferencia 0.
- **Repositorio con código y datos:** pendiente del autor.

### `main_2.tex` C33 — versión de CVX/MOSEK
CVX 2.2, build 1148 (28-ene-2020); MOSEK 9.1.9 (build 2019-11-21); MATLAB R2026a (26.1). La fecha de consulta la pone el autor.

---

## 2. Diferencias entre texto y código, y estado final

| # | Tema | Texto | Código / ejecución | Estado |
|---|---|---|---|---|
| 1 | Fuente del contraste de datos (l. 64) | Stooq | Tiingo (acciones, SPY) y CBOE (VIX); Stooq está bloqueado | **Abierta**: cambiar el texto |
| 2 | Archivo citado (l. 64) | `audit_report.csv` | el dato está en `data/audit/audit_report.md` | **Abierta**: texto |
| 3 | CVaR / VaR (l. 290) | R–U; cuantil α | antes: media de las pérdidas ≥ prctile | **Cerrada** (código alineado, T2) |
| 4 | Sharpe / Sortino / denominador nulo (l. 296) | excesos sobre r^f; objetivo 0, 1/T; no definida | antes: sin r^f; RMS solo de los meses negativos; Sortino = Inf | **Cerrada** (T2) |
| 5 | Costos (l. 302) | fraccional y monetario /W_0 del tramo | antes: solo Σ τ W_k TO_k con la W de la trayectoria completa | **Cerrada** (T2; columnas nuevas) |
| 6 | Estado del solver (l. 221) | estado exacto por mes | antes: solo `cvx_status` | **Cerrada** para las corridas nuevas (T3); las antiguas conservan solo `cvx_status` |
| 7 | Regla de selección, paso de elegibilidad (l. 267) | no excluye η = 0 | T9 excluye η = 0 (regla del usuario) | **Abierta**: actualizar el texto |
| 8 | Tolerancia de empate (l. 267) | 1e-6 | T9 usa TOL = 5e-4 (ruido medido) | **Abierta**: texto |
| 9 | Número de combinaciones (l. 267) | 66 por geometría | elegibles: 60 (η > 0) | **Abierta**: texto |
| 10 | «Fracción de fechas factibles» (l. 313; heatmaps y columna `fraccion_factible`) | — | mide la fracción de meses con 'Solved' | **Abierta**: renombrar a «fracción de meses con solución óptima» |
| 11 | «Evaluadas una sola vez» (l. 271–273) | una sola evaluación de prueba | G1 (0.90, 0.01) ya se había evaluado en `results_prueba_fuera_muestra/`; `main_comparacion_modelos.m` evaluó la prueba con (0.90, 0.05) en G1 y G2, que no sale de la regla; en T2–T5 se calcularon métricas de prueba del nominal (0.90) y la exposición de G1 (0.90) con η ≥ 0.15 después de 2022 | **Abierta**: decidir cómo declararlo |
| 12 | Comentario «recortar = correr por separado» | el texto ya lo corrigió (C24) | `extract_period_results.m:13-17`, `main_validation_grid.m:5-8` | **Abierta**: solo comentarios de código (T8) |
| 13 | Regla de exclusión con IQR ≈ 0 (l. 173) | prevista | no implementada; conteo 0 | **Cerrada**: no hace falta; decirlo en el texto |
| 14 | Dependencia de `wdro-return/` | carpeta descartada | `main_validation_grid_market.m` usaba su `truncate_data.m` | **Cerrada** (copia en `wdro-market/`) |
| 15 | Conteo de «meses con transacción» | — | TO incluye compras y ventas simultáneas pequeñas del punto interior (máx. 5e-4 en un mes; ≤ 0.09 % del turnover) | **Abierta (menor)**: no se cambió la definición |

---

## 3. Tablas nuevas: rutas y contenido

| Ruta | Contenido |
|---|---|
| `results_validacion_metricas_v2/tabla_maestra_validacion_G1.csv`, `..._G2.csv` | 66 filas (δ, η), validación 2015–2018, con todas las métricas anteriores más sharpe, sortino, calmar, costo_fraccional, costo_monetario, proporción en riesgo, meses sin exposición y meses por clase de estado |
| `results_validacion_metricas_v2/comparacion_G2_vs_G1_validacion.csv` | G1 frente a G2, celda a celda |
| `results_validacion_metricas_v2/verificacion_eta0_G1_vs_G2.csv` | por δ: max\|Δx\|, max\|ΔG\| y \|ΔW\| con η = 0 (todos 0) |
| `results_validacion_metricas_v2/heatmap_*.png` | CVaR R–U, Sharpe, costo monetario y proporción en riesgo, para G1 y G2 |
| `results_estado_solver/tabla_meses_sin_optimizacion.csv` | 149 corridas: fuente, geometría, δ, η, meses, óptimos, sin optimización por clase, primera fecha |
| `results_estado_solver/diagnostico_eta_alto.csv`, `.png` | G1, δ = 0.90, η ∈ {0, 0.10, 0.15, 0.30}, por mes: exposición, ρ_k, λ_k, r_f, ρ_k/ρ̄_k y G real (132 meses) |
| `results_verificaciones/equivalencia_eta0_instancias.csv` | 3 fechas: objetivos, residuos, rango y cond(A), \|Δx\|, λ |
| `results_verificaciones/equivalencia_eta0_backtest.csv` | 6 δ: max\|ΔG\|, max\|Δx\| y \|ΔW_T\| (nominal vs η = 0) |
| `results_verificaciones/verificacion_restricciones.csv` | 132 celdas: residuos de balance, turnover, cotas y δ; meses con la cota activa; exceso de turnover |
| `results_verificaciones/metricas_anteriores_vs_nuevas_eta0.csv` | δ = 0.90, η = 0: métricas anteriores frente a nuevas en los tramos completo, validación y prueba |
| `results_verificaciones/resumen_distancias_c.csv` | por ventana: p25, mediana, p75 y mínimo de c_rs para G1 y G2 |
| `results_seleccion/diagnostico_cota_delta.csv` | validación: meses con la cota activa y holgura mínima por (geometría, δ, η) |
| `results_seleccion/ruido_celdas_equivalentes.csv` | validación: ruido de riqueza y de x entre δ ≤ 0.80, por (geometría, η) |
| `results_seleccion/riqueza_vs_eta.csv`, `riqueza_vs_eta_G*.png` | validación: riqueza y pérdida relativa frente a η = 0 |
| `results_seleccion/seleccion_G1.csv`, `seleccion_G2.csv` | celda elegida y conjunto empatado, con la brecha relativa |
| `results_seleccion/sensibilidad_seleccion.csv`, `top10_G*.csv` | top 10; elección con η = 0; con TOL×10 y TOL/10; mejor por Sharpe, CVaR y MDD; borde de la malla |
| `results_prueba_v2/verificacion_G2_reproduce_validacion.csv` | G2 en los 132 meses frente a la validación guardada: Δ = 0 |
| `results_prueba_v2/metricas_por_tramo.csv` | 6 estrategias × {validación, prueba}, con las métricas nuevas |
| `results_prueba_v2/contrastes_prueba.csv` | 7 contrastes: media, mediana y % de D_k > 0, suma, cociente de riquezas |
| `results_prueba_v2/g2_trayectorias_completas.mat`, `riqueza_*.png` | trayectorias de G2 y gráficas de riqueza |
| `results_bootstrap/test_simulado.csv` | cobertura y ancho del intervalo por ℓ, con datos simulados |
| `results_bootstrap/tabla_bootstrap_contrastes.csv` | 9 filas de contraste × ℓ ∈ {3, 6, 12}: media, IC 95 %, error estándar, mediana, % de D > 0, empates, ¿excluye 0? |
| `results_regimen/clasificacion_meses.csv` | 84 meses de prueba: VIX_k, mediana de la ventana, clase VIX, retorno de SPY_k, clase SPY |
| `results_regimen/desglose_regimen.csv` | 7 contrastes × 9 grupos: n, media, mediana, % de D > 0, empates, suma |

Reportes por tarea: `REPORTE_T2_T5.md`, `results_seleccion/REPORTE_SELECCION.md`, `results_prueba_v2/REPORTE_PRUEBA.md`, `results_bootstrap/REPORTE_BOOTSTRAP.md`, `results_regimen/REPORTE_REGIMEN.md`.

---

## 4. Parámetros y configuraciones fijados

| Parámetro | Valor |
|---|---|
| Datos | ene-2010 a dic-2025, mensuales; N = 60; primera decisión 31-dic-2014; h_0 = (1, 0, …, 0), W_0 = 1 |
| Modelo | τ = 0.001, x̄ = 0.25, γ = 1, ε_esc = 1e-6; CVX 2.2 + MOSEK 9.1.9, precisión por defecto |
| Geometría 2 | pesos (0.70, 0.15, 0.15, 0), VIX en nivel |
| Tramos | validación: ene-2015 a dic-2018 (48 meses realizados); prueba: ene-2019 a dic-2025 (84 meses realizados) |
| Mallas | δ ∈ {0.50, 0.60, 0.70, 0.75, 0.80, 0.90}; η ∈ {0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.10, 0.15, 0.30, 0.50, 1.00} |
| Métricas | α = 0.95; VaR = L_(⌈αT⌉); CVaR de R–U; anualización con √12; umbrales de transacción y de exposición 1e-8 |
| Regla de selección (T9) | η > 0; φ_min = 0.95; máxima riqueza de validación; TOL = 5e-4; desempate por menor η y luego mayor δ |
| Configuraciones elegidas | G1: (0.90, 0.01); G2: (0.80, 0.01) |
| Estrategias de prueba | nominal (0.90) y (0.80); G1 y G2 con (0.90, 0.01) y con (0.80, 0.01) |
| Tolerancias de verificación | objetivo 1e-6; factibilidad 1e-7; ponderaciones 1e-5 (si la solución es única); crecimiento en el backtest 1e-6; trayectorias G1 = G2 1e-8 |
| Cota δ activa | holgura ≤ 1e-6 |
| Bootstrap | ℓ = 6 (sensibilidad con 3 y 12); B = 10 000; IC percentil 2.5–97.5; semilla 20261019 |
| Régimen | VIX_k > mediana de la ventana D_k (incluido k) → alto; SPY_k < 0 → negativo |
| Empates numéricos de D_k | \|D_k\| < 1e-6 (solo se reportan) |

---

## 5. Lo que no se hizo y por qué
- **No se editó ningún `.tex`**, por instrucción.
- **Pendientes opcionales:** pesos alternativos de G2 (l. 189) y comparación del objetivo en el peor caso con un η común (l. 145). No se pidieron como tareas.
- **Decisiones del autor:**  razón de los pesos 70/15/15 (l. 187); repositorio (l. 346); regla final ante discrepancias de datos (l. 64, queda como propuesta); fecha de consulta de CVX/MOSEK.
- **Comentarios de código** sobre la «equivalencia» del recorte (`extract_period_results.m:13-17`, `main_validation_grid.m:5-8`): solo se propone corregirlos (T8).
- **Definición del conteo de transacciones** (compras y ventas simultáneas del punto interior): no se cambió.
- **Tablas antiguas** (`results_validacion_grid/`, `wdro-market/results_validacion_grid_market/`, `results_prueba_fuera_muestra/`, `wdro-market/results_comparacion_modelos/`): conservan las métricas anteriores; no se sobrescribieron.
- **Backtest de prueba desde efectivo en 2019:** no se corrió, porque no forma parte del protocolo y sería otra mirada al periodo de prueba.
- **Cambios de código sin commit:** quedan pendientes de tu revisión.
