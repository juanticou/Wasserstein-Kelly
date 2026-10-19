# Reporte de las tareas T2–T5

Fecha: 2026-10-19. Referencia del texto: `metodologia_2.tex` (el `CLAUDE.md` y `TAREAS_PENDIENTES.md` dicen `metodologia_1.tex`, pero en la carpeta solo existe `metodologia_2.tex`). **No se editó ningún `.tex`**, no se tocó `data/raw/` y no se sobrescribió ningún resultado anterior: todo lo nuevo está en carpetas nuevas.

Ningún parámetro se eligió ni se ajustó con el periodo de prueba. Los únicos cálculos que tocan 2019–2025 son verificaciones de código (equivalencia con η=0 y residuos de restricciones) y la reproducción de métricas que ya existían para δ=0.90 y η=0.

---

## 0. Resumen

| Tarea | Estado | Resultado principal |
|---|---|---|
| T2 Métricas | ✅ | `compute_metrics.m` coincide con el texto (CVaR de R–U, Sharpe con excesos sobre r_f, Sortino con objetivo 0, costo fraccional y monetario, N_eff=0 y proporción en riesgo). Con η=0, las 20 métricas cuya definición no cambió son **idénticas** a las anteriores en el backtest completo, en validación y en prueba. |
| T3 Solver | ✅ | Desde ahora se guarda por mes el estado de CVX, el estado **nativo** de MOSEK y la clase {óptimo, inaccurate, infeasible certificado, fallo numérico}. En los resultados ya guardados (149 corridas, 14 124 meses) hay **0 meses sin optimización**. Las trayectorias planas de η≥0.15 después de 2022 **no son fallos**: el óptimo es quedarse en el activo de bajo riesgo. |
| T4 Malla G2 | ✅ (ya existía) | La malla de validación de G2 ya estaba corrida (`wdro-market/results_validacion_grid_market/`, 66 celdas × 48 meses, todas óptimas). Se rehicieron las tablas maestras de G1 y G2 con las métricas nuevas y se verificó que con η=0 las dos geometrías dan **la misma trayectoria mes a mes** (diferencia 0). No se volvió a correr la malla. |
| T5 Verificaciones | ✅ | Tolerancias explícitas: objetivo 1e-6, factibilidad 1e-7, ponderaciones 1e-5 (solo con solución única). Las tres verificaciones (a), (b) y (c) del texto pasan; detalle en §4. |

**Hallazgos que debes decidir tú** (no los resolví yo):
1. **Regla de selección (C21/C23).** Con la regla del texto (maximizar la riqueza de validación), la mejor celda en **ambas** geometrías es **η=0** (δ=0.80, W=2.36678); las 6 celdas con η=0 ocupan los puestos 1–6. La configuración usada en la prueba, δ=0.90 y η=0.01, es la **7.ª** en G1 (la mejor con η>0). En G2, la mejor con η>0 es δ=0.70, η=0.01 (7.ª); δ=0.90, η=0.01 es la 12.ª. Es decir, la elección de δ=0.90, η=0.01 equivale a aplicar la regla **excluyendo η=0**, y eso no está escrito en el texto.
2. **`wdro-market/main_comparacion_modelos.m`** compara los modelos en la prueba con **δ=0.90, η=0.05** para G1 y G2. Ninguna de las dos sale de la regla de validación (en validación son la 30.ª en G1 y la 34.ª en G2). Si esos resultados se usan en el texto, hay que decir de dónde sale η=0.05.
3. **Stooq → Tiingo/CBOE** (de T1): el texto dice que el contraste se hizo con Stooq; en realidad se hizo con Tiingo (acciones y SPY) y CBOE (VIX).

---

## 1. T2 — Métricas

### 1.1 Diferencias encontradas (antes de editar) y estado final

| Métrica | Texto (`metodologia_2.tex` §Métricas) | Código anterior | Estado |
|---|---|---|---|
| VaR 95 % | cuantil de nivel α de L_t = 1−G_t | `prctile(L,95)` (interpolado) | **Cambiado**: VaR = L_(⌈αT⌉), el ζ* de R–U (lo decidiste tú) |
| CVaR 95 % | R–U empírico: min_ζ{ζ + Σ(L−ζ)₊/((1−α)T)} | media de las pérdidas ≥ VaR | **Cambiado**: R–U exacto (se evalúa en todos los puntos de la muestra; la función es lineal por tramos) |
| Sharpe | √12·ē/s_e, con e_t = R_t − r^f_{t−1} | √12·R̄/s_R, sin restar r_f | **Cambiado**. r^f es la del mes de decisión k, la misma que gana el activo de bajo riesgo en k+1 |
| Sortino | objetivo 0, DD₀ = ((1/T)Σmin(R_t,0)²)^½ | RMS **solo de los meses negativos** (divide entre su número, no entre T); `Inf` si no hay meses negativos | **Cambiado**: divide entre T y da NaN si DD₀=0 |
| Denominador nulo | «no definida» | Sharpe NaN, Sortino Inf, Calmar NaN | **Cambiado**: NaN en los tres |
| Calmar | CAGR/MDD | igual | sin cambio |
| Costo fraccional | Σ τ·TO_k | no existía | **Nuevo**: `cost_frac_total` / `costo_fraccional` |
| Costo monetario | Σ W_k τ TO_k / W_0 | `cost_total` = Σ τ W_k TO_k con la W de la **trayectoria completa** (W_0 = dic-2014). En los tramos recortados (validación/prueba) **no** queda en unidades del W_0 del tramo | **Nuevo**: `cost_monetary_total` / `costo_monetario`, con la riqueza re-basada del tramo. `cost_total` se conserva con su significado anterior, por trazabilidad |
| N_eff sin exposición | N_eff = 0, concentración «no aplicable» | ya era 0 (umbral `>0` exacto); el promedio usa solo los meses con exposición | Umbral subido a 1e-8 (igual que TRADE_EPS); el peso máximo promedio ahora también usa solo esos meses |
| Proporción en riesgo | Σ_j x_jk, reportada aparte | no existía | **Nueva**: `risky_share_mean` / `proporcion_riesgo_media` y `n_months_no_risk` / `meses_sin_exposicion` |

`plot_neff_series.m` ya usaba N_eff=0 sin exposición (umbral `>0`); no se modificó.

### 1.2 Prueba con η=0 (nominal), δ=0.90
Archivo: `results_verificaciones/metricas_anteriores_vs_nuevas_eta0.csv`. La versión anterior se tomó de `git show HEAD:compute_metrics.m`.

- **Idénticas (diferencia 0) en los tres tramos**: riqueza final, crecimiento log, CAGR, MDD, peor mes, percentil 5, varianza, Calmar, turnover, `cost_total`, costo medio, n.º de transacciones, turnover medio, peso máximo (promedio y pico), N_eff, violaciones de δ, mínimo factor de crecimiento, fallos y n.º de meses.
- **Cambian, como se esperaba:**

| Tramo | VaR ant. → nuevo | CVaR ant. → nuevo | Sharpe ant. → nuevo | Sortino ant. → nuevo |
|---|---|---|---|---|
| Completo (132 m) | 0.07985 → 0.08148 | 0.09694 → 0.09788 | 1.187 → 1.075 | 1.235 → 2.139 |
| Validación (48 m) | 0.06688 → 0.06526 | 0.09504 → 0.09008 | 1.360 → 1.311 | 1.458 → 2.608 |
| Prueba (84 m) | 0.08479 → 0.08354 | 0.10124 → 0.10040 | 1.095 → 0.952 | 1.135 → 1.932 |

- Costo en la prueba: `cost_total` antiguo = 0.04265 (en unidades de la riqueza de dic-2014) frente a `costo_monetario` = 0.01802 (en unidades del W_0 del tramo). El costo fraccional es 0.00760.
- En las 66 celdas de validación de G1 y G2, las métricas sin cambio de definición son idénticas, salvo N_eff y peso máximo en las celdas con **η=1** (δ=0.5, 0.7, 0.75, 0.8). Ahí la exposición riesgosa media es ~0 (posiciones de 1e-8 a 1e-6) y el umbral nuevo excluye esos meses. **Observación**: con η≥0.30 la exposición es solo ruido numérico, así que el N_eff de esas celdas no tiene interpretación; conviene reportarlo como «no aplicable».

---

## 2. T3 — Estado del solucionador y meses sin optimización

### 2.1 Qué se guardaba y qué se guarda ahora
- **Antes**: solo `cvx_status` por mes (`results.status`). Un mes contaba como resuelto solo con `'Solved'`; `'Inaccurate/Solved'` ya se trataba como mes sin optimización (se mantenía el portafolio heredado).
- **Ahora**, en los tres `run_backtest_*.m` y para todas las estrategias:
  - `results.status_class` ∈ {`optimo`, `inaccurate`, `infeasible_certificado`, `fallo_numerico`} (`classify_solver_status.m`): Solved→óptimo; Inaccurate/Solved→inaccurate; Infeasible→infeasible certificado; el resto (Inaccurate/Infeasible, Failed, Unbounded, …)→fallo numérico.
  - `results.solver_info{k}`: `cvx_status`, estado **nativo** de MOSEK (`Problem status` y `Solution status`, leídos del log de `cvx_end` capturado con `evalc`, porque CVX no los expone como variable), `cvx_slvtol`, `cvx_slvitr` y `cvx_precision`.
  - `results.rf`: la r^f_k de cada fecha (la necesita el Sharpe).
  - La regla de contingencia **no cambió**: si el estado no es óptimo, se mantiene el portafolio heredado y el mes se cuenta como «mes sin optimización».
- **Precisión del solucionador**: CVX 2.2 (build 1148) con MOSEK 9.1.9 y `cvx_precision` por defecto = [1.49e-8, 1.49e-8, 1.22e-4] (tolerancias objetivo/aceptable/mínima de CVX). La tolerancia alcanzada (`cvx_slvtol`) fue 1.49e-8 en todos los meses registrados. Entorno: MATLAB R2026a.

### 2.2 Tabla de meses sin optimización
Archivo: `results_estado_solver/tabla_meses_sin_optimizacion.csv` (columnas: fuente, geometría, δ, η, n_meses, rango de fechas, óptimos, sin optimización, inaccurate, infeasible certificado, fallo numérico, primer mes sin optimización).

| Fuente | Corridas | Meses | Sin optimización |
|---|---|---|---|
| G1, malla completa (dic-2014…nov-2025), 66 (δ,η) | 66 | 8 712 | **0** |
| G2, malla de validación (dic-2014…nov-2018), 66 (δ,η) | 66 | 3 168 | **0** |
| `main_geometria_mercado.m` (G1 y G2, δ=0.90, η∈{0, 0.05, 0.15, 0.30}) | 8 | 1 056 | **0** |
| `main_comparacion_modelos.m` (nominal, G1, G2) | 3 | 396 | **0** |
| Nominal por δ (nuevo, `verify_eta0_backtest.m`) | 6 | 792 | **0**; MOSEK: PRIMAL_AND_DUAL_FEASIBLE / OPTIMAL en los 792 |
| **Total** | **149** | **14 124** | **0** (0 inaccurate, 0 infeasible certificado, 0 fallo numérico) |

Los resultados guardados antes de este cambio solo tienen `cvx_status`; su clase se deriva de él. El estado nativo de MOSEK existe solo para las corridas nuevas.

### 2.3 Trayectorias casi planas con η≥0.15 después de 2022
Archivos: `results_estado_solver/diagnostico_eta_alto.csv` y `.png` (G1, δ=0.90).

**No son meses sin optimización** (todos son óptimos): el óptimo del modelo robusto es mantener casi todo en el activo de bajo riesgo, y la riqueza crece a la tasa r_f.

Exposición riesgosa media Σ_j x_jk por año de decisión:

| Año | r_f mensual | η=0.10 | η=0.15 | η=0.30 |
|---|---|---|---|---|
| 2014–2021 | 0.0000–0.0017 | 1.00 | 0.93–1.00 | 0.00 (0.15 en 2021) |
| 2022 | 0.0018 | 0.99 | **0.65** | 0.00 |
| 2023 | 0.0043 | 0.93 | **0.00** | 0.00 |
| 2024 | 0.0042 | 1.00 | **0.01** | 0.00 |
| 2025 | 0.0035 | 1.00 | 0.74 | 0.00 |

- Con η=0.15 el portafolio pasa a bajo riesgo desde sep-2022: 29 de los 47 meses desde 2022 tienen exposición < 0.05. La desviación estándar de G−1 desde 2022 es 0.026 con η=0.15 y 0.0012 con η=0.30, frente a 0.052 con η=0.
- Con η≥0.30 el portafolio está en bajo riesgo casi todo el periodo, incluso antes de 2022.
- Mecanismo: el valor robusto de quedarse en bajo riesgo es log(x_0(1+r_f)), que no depende de ρ (G_ks es igual en todos los escenarios y el adversario no puede empeorarlo). El de un portafolio riesgoso disminuye al crecer ρ. El efectivo gana cuando su valor supera al mejor riesgoso robusto. Desde 2022 coinciden dos cosas: r_f sube de ~0.07 % a ~0.34 % mensual (correlación entre r_f y la exposición con η=0.15: −0.84), y las ventanas incluyen 2020 y 2022. Con los datos no se puede separar el efecto de cada una. En 2018–2019 r_f era 0.17 % y η=0.15 seguía invertido, así que **r_f no lo explica sola**.
- λ_k ≈ 0 en esos meses (mediana 9e-4 con η=0.15 y 6e-6 con η=0.30, frente a ~0.1–0.17 con η≤0.10) es **consecuencia** de estar en bajo riesgo: con G constante el multiplicador queda indeterminado. Comprobé además la hipótesis de que el adversario concentrara toda la masa en un escenario: **es falsa**, porque ρ_k (~0.12 con η=0.15) es mucho menor que min_s (1/N)Σ_r C(r,s) (~0.63) en todos los meses.

### 2.4 Para reescribir el párrafo de factibilidad (C18/C19)
Datos: 0 de 14 124 meses sin solución óptima; 0 infeasible certificado; 0 inaccurate; 0 fallos numéricos; precisión de CVX por defecto con tolerancia alcanzada de 1.49e-8; desde ahora se guarda el estado exacto de cada mes (CVX + MOSEK). La cota δ estuvo **activa** (holgura ≤ 1e-6) solo con δ=0.90: G1 con η ∈ {0, 0.01, 0.02, 0.03, 0.04, 0.05} tuvo 73, 66, 54, 41, 31 y 21 meses activos de 132; G2 (validación) en 3 celdas (ver `results_verificaciones/verificacion_restricciones.csv`, columna `meses_cota_delta_activa`).

---

## 3. T4 — Malla de validación de la Geometría 2

- **Ya existía**: `wdro-market/main_validation_grid_market.m` corre la malla completa 6×11 con los datos truncados físicamente a dic-2018, pesos (0.70, 0.15, 0.15) y VIX en nivel. Sus salidas, en `wdro-market/results_validacion_grid_market/`, incluyen la tabla maestra, los mismos heatmaps y gráficos que G1 y la comparación G2−G1. **No la volví a correr**: no hacía falta, porque las métricas nuevas se recalculan sobre los `.mat` guardados, y no se sobrescriben resultados.
- **Problema corregido**: el script usaba `truncate_data.m` de `wdro-return/` (carpeta descartada). Lo copié sin cambios a `wdro-market/truncate_data.m` y quité el `addpath` a `wdro-return`. `wdro-return/` no se tocó.
- **Tablas comparables con las métricas nuevas** (`rebuild_validation_tables.m` → `results_validacion_metricas_v2/`):
  - `tabla_maestra_validacion_G1.csv` y `tabla_maestra_validacion_G2.csv`: 66 filas cada una, con las mismas columnas que antes más sharpe, sortino, calmar, costo_fraccional, costo_monetario, proporción en riesgo, meses sin exposición y meses por clase de estado.
  - `comparacion_G2_vs_G1_validacion.csv`, celda a celda.
  - Heatmaps de CVaR (R–U), Sharpe, costo monetario y proporción en riesgo para G1 y G2.
- **η=0 ⇒ G1 = G2**: `verificacion_eta0_G1_vs_G2.csv`. Para los 6 δ, en los 48 meses de validación: max|Δx| = 0, max|ΔG| = 0, |ΔW_T| = 0 (tolerancia 1e-8). La fracción de meses óptimos es 1 en las 66 celdas de las dos geometrías.

---

## 4. T5 — Verificaciones numéricas con tolerancia explícita

### 4.1 Tolerancias usadas (propuestas por mí; puedes cambiarlas)
| Qué | Tolerancia |
|---|---|
| Valor objetivo (nominal vs WDRO con ρ=0) | **1e-6** (absoluta) |
| Factibilidad: residuo máximo de las restricciones | **1e-7** |
| Ponderaciones (x, x_0), **solo con solución única** | **1e-5** |
| Trayectoria del backtest: factor de crecimiento mensual | 1e-6 |
| Trayectorias G1 vs G2 con η=0 | 1e-8 |

**Criterio de unicidad** (para decidir cuándo se comparan las ponderaciones): el objetivo es estrictamente cóncavo en G = A[x_0; x], con A = [(1+r_f)𝟙, 1+R]. Por eso G* es único, y (x_0, x) también lo es si A tiene rango de columna completo. Con τ>0, comprar y vender a la vez no es óptimo, así que (b, s) quedan determinados por x−h. El script reporta el rango y el número de condición de A.

### 4.2 Resultados
**(a) η=0 / ρ=0 ⇒ nominal**
- *Instancias* (`test_wdro_nominal_equivalence.m` → `results_verificaciones/equivalencia_eta0_instancias.csv`): 3 fechas de decisión (dic-2014, dic-2018, jun-2022), h_0 = efectivo, δ=0.75. En las tres: estado Solved (MOSEK OPTIMAL); |Δobjetivo| = 0 entre nominal, G1 y G2; residuo de factibilidad ≤ 4.3e-8; rango(A) = 11/11 con cond(A) ∈ [140, 157], o sea, solución única; max|Δx| = 0.
- *Backtest completo* (`verify_eta0_backtest.m` → `equivalencia_eta0_backtest.csv`): nominal frente a η=0 de G1 para los 6 δ, 132 meses: max|ΔG| = 0, max|Δx| = 0, |ΔW_T| = 0. Tarda ~12 s por δ.
- Las diferencias son exactamente 0 en doble precisión, no solo menores que la tolerancia. Mi hipótesis, que no verifiqué en el log, es que el presolve de MOSEK reduce ambos problemas a la misma forma. Con ρ=0 el λ que devuelve el solver (≈0.15–0.21) no tiene interpretación, porque cualquier λ suficientemente grande es óptimo.

**(b) Restricciones en todos los meses guardados** (`verify_backtest_constraints.m` → `verificacion_restricciones.csv`; 132 celdas: G1 completa y G2 en validación):
| Comprobación | Máximo G1 | Máximo G2 |
|---|---|---|
| Balance x_0+Σx_j − (1−τ·TO) | 1.85e-10 | 1.94e-10 |
| Cotas 0≤x_j≤x̄, Σx_j≤γ, x_0≥0 | 0 | 0 |
| Cota δ en la ventana, max(δ − min_s G_ks, 0) | 0 | 0 |

Todas las celdas cumplen la tolerancia de 1e-7.

**Observación (no es una violación del modelo):** TO_k − Σ_j|x_jk − h_jk| llega a 5.0e-4 en un mes. Es decir, el punto interior deja compras y ventas simultáneas pequeñas del mismo activo. Acumulado, es como máximo el 0.09 % del turnover total de una celda (0.0126 de 13.46), así que el efecto en costos es despreciable. Sí hace que `n_transacciones` cuente como «mes con transacción» meses en los que el portafolio no cambia, por ejemplo con η≥0.30 en efectivo. Si quieres un conteo limpio, propongo contar con Σ|x−h| en lugar de TO; no lo cambié.

**(c) η=0 ⇒ ambas geometrías coinciden**: ver §3 (diferencia 0 mes a mes) y §4.2(a) (instancias: |Δobjetivo| = 0 y |Δx| = 0 entre G1 y G2).

---

## 5. Respuesta a cada `[PENDIENTE]` / `REVISAR` de `metodologia_2.tex`

Cada marcador va con el dato que lo resuelve, o con su estado. «(T1)» indica que el dato sale de `data/audit/audit_report.md` §8, la auditoría anterior.

**C6 (l. 52–54) — GICS y criterio de selección.** No se resuelve con datos ni con código: es tu decisión, junto con la fuente de la clasificación sectorial. (T1)

**C7 (l. 64) — datos de descarga.** (T1)
- Fecha de descarga: **2026-08-12** según `data/raw/download_log.csv` (Yahoo Finance). La de DGS3MO no está registrada en el log; es la del mismo commit.
- Periodo efectivo: las 12 series de Yahoo van del 2009-12-01 al 2025-12-30 (el `end` de yfinance es exclusivo); DGS3MO, del 2009-12-01 al 2025-12-31; panel mensual, de ene-2010 a dic-2025 (192 meses, 0 NaN). El texto cita `audit_report.csv`, pero el dato está en `audit_report.md`.
- Criterio ante faltantes: no se imputó nada; se tomó el último dato disponible del mes. El `ffill` entre meses se usó en **0** meses.
- Regla ante discrepancias (**propuesta**): prevalece Yahoo y la discrepancia se registra. Hay 14 activo-mes fuera de tolerancia (4 sin explicar). El contraste fue contra **Tiingo/CBOE, no Stooq**: hay que corregir el texto y la nota al pie.

**C8 (l. 79–81) — sin datos posteriores al cierre.** Confirmado (T1): 0 datos posteriores al fin de mes y 0 de 2 496 celdas distintas al recomputar. La descripción de `resample('ME').last()` + `ffill` coincide con `01_import_data.py`.

**C12/C13a (l. 143–145) — REVISAR «sin distancias positivas ⇒ ρ_k=0».** Coincide con `compute_rho.m:29-34`: si no hay costos positivos en el triángulo superior, devuelve ρ_k=0 con una advertencia. Nunca se activa: el mínimo c_rs fuera de la diagonal es 0.142 en G1 y 0.193 en G2.

**C12 (l. 145) — PENDIENTE opcional, resumen de las distancias c_rs.** Hecho (`results_verificaciones/resumen_distancias_c.csv`, por ventana). Mediana entre ventanas de [p25, mediana, p75]:
- Todas las ventanas (132): G1 [0.646, 0.830, 1.074]; G2 [0.628, 0.821, 1.092].
- Validación (48): G1 [0.657, 0.823, 1.034]; G2 [0.629, 0.811, 1.083].

La comparación del objetivo en el peor caso con un η común **no se hizo**.

**C14 (l. 171–173) — ventanas con IQR < ε_esc.** **Conteo = 0** en las 12 series (10 retornos, SPY y VIX) y las 132 ventanas; el IQR mínimo es 0.0256 (SPY) (T1). La regla de exclusión no está implementada y nunca habría hecho falta; puede decirse así.

**C15 (l. 187–189) — razón de los pesos 70/15/15.** Es tu decisión. La comprobación opcional con pesos alternativos **no se hizo**.

**C17 (l. 203–205) — condición inicial y recorte.** **Confirmado: el tramo de prueba se obtiene recortando la trayectoria completa, sin reiniciar desde efectivo.**
- `main_test_evaluation.m:59-60` toma la trayectoria completa guardada de la malla (`grid.results_wdro{i,j}`).
- `main_test_evaluation.m:90-93` la recorta con `extract_period_results`, que re-basa la riqueza a 1 con `[1; cumprod(growth_real)]` y no toca h.
- La condición inicial h_0 = (1, 0, …, 0) se aplica una sola vez, en la primera decisión (dic-2014), en los tres `run_backtest_*.m` (`h_current = [1; zeros(d,1)]`).
- `wdro-market/main_comparacion_modelos.m:81-91,148` hace lo mismo para G2.

El texto actual de C17 es correcto. **Nota**: el comentario interno de `extract_period_results.m` (y de `main_validation_grid.m`) dice que recortar «es matemáticamente equivalente a correr cada tramo por separado». Eso es falso con portafolio heredado y costos, como señaló el director en C24. Solo es un comentario; no lo cambié.

**C18 (l. 219–221) — estado y precisión del solver.** Precisión: CVX 2.2 con MOSEK 9.1.9 y `cvx_precision` por defecto [1.49e-8, 1.49e-8, 1.22e-4]. **Hasta ahora solo se guardaba `cvx_status`**; desde este cambio se guardan por mes el estado de CVX, el estado nativo de MOSEK, la clase y la tolerancia alcanzada. En los resultados existentes hay 0 meses no óptimos (§2.2).

**C19 (l. 254) — REVISAR fracciones factibles < 1.** No hay ninguna: la fracción de meses óptimos es **1** en todas las celdas de G1 (malla completa) y de G2 (validación). No hubo fallos numéricos que reportar. **Diferencia de texto**: los heatmaps se titulan «Factibilidad WDRO» y la columna se llama `fraccion_factible`, pero miden la fracción de meses con `Solved`. Igual que en C19, conviene llamarla «fracción de meses con solución óptima», también en la viñeta «Supervivencia y cómputo» (l. ~314), que todavía dice «fracción de fechas factibles».

**C20 interno (l. 261) — malla de validación de G2.** Hecha (ya existía; §3), así que el párrafo es cierto para las dos geometrías.

**C21/C23 (l. 265–267) — φ_min y desempate.** φ_min lo tienes que fijar tú. Dato útil: como todas las celdas tienen fracción 1, cualquier φ_min ≤ 1 no excluye ninguna. **Pero ver el hallazgo 1 del §0**: con la regla tal como está escrita, gana η=0 en las dos geometrías; δ=0.90, η=0.01 sale solo si se excluye η=0. Los desempates (diferencia relativa < 1e-6) no aplican: la diferencia entre la 1.ª celda (δ=0.80) y la 2.ª (δ=0.75) es 5.0e-5 relativa.

**C25 (l. 290) — CVaR empírico.** Alineado: R–U exacto y VaR = L_(⌈αT⌉) (§1.1).

**C27 (l. 296) — Sharpe, Sortino y denominador nulo.** Alineado: las fórmulas del texto son ahora las del código (§1.1). r^f_{t−1} del texto = `results.rf`, la tasa del mes de decisión.

**C28 (l. 302) — costo fraccional y monetario.** Alineado: `costo_fraccional` = τΣTO y `costo_monetario` = ΣW_kτTO_k/W_0 con el W_0 del tramo. El «Costo acumulado» de las tablas anteriores era el monetario de la trayectoria completa (W_0 = dic-2014), así que en los tramos no está en unidades del W_0 del tramo.

**C29 (l. 308) — N_eff = 0 sin exposición.** Confirmado en `compute_metrics.m` y `plot_neff_series.m`. Se añadió la proporción invertida en riesgo. El promedio de N_eff es sobre los meses con exposición. Ver la observación sobre η≥0.30 en §1.2.

**C30/C34 (l. 323–327) — bootstrap por bloques.** **No se hizo** (es T6).

**C31 (l. 331–333) — desglose por régimen.** **No se hizo** (es T7); el texto todavía no se puede confirmar.

**C32 (l. 341–343) — tolerancias.** Objetivo y factibilidad: **1e-6** (objetivo, absoluta) y **1e-7** (residuos de las restricciones). Ponderaciones: **1e-5**, solo con solución única (rango completo de A). Resultados en §4.2.

**l. 346 (comentado) — confirmar que cada verificación se corrió.** (a), (b) y (c) se corrieron y quedaron registradas en `results_verificaciones/`; ninguna hay que retirarla. El repositorio con código y datos sigue pendiente (lo decides tú).

**main_2.tex C33 — versión de CVX/MOSEK.** CVX 2.2, build 1148 (28-ene-2020); MOSEK 9.1.9 (build 2019-11-21); MATLAB R2026a (26.1). La fecha de consulta la pones tú.

---

## 6. Archivos

**Modificados** (los cambios se explicaron y aprobaron en el plan):
- `compute_metrics.m`: métricas de T2; nuevo argumento opcional `rf`.
- `solve_nominal_kelly.m` y `solve_wdro_kelly.m`: salida opcional `info` y log de MOSEK capturado con `evalc` (se quitó `quiet`, pero no se imprime nada). La formulación no cambió.
- `run_backtest_nominal_kelly.m`, `run_backtest_wdro_kelly.m` y `wdro-market/run_backtest_wdro_kelly_market.m`: guardan `status_class`, `solver_info` y `rf`. La regla de contingencia no cambió.
- `extract_period_results.m`: recorta `rf`, `status_class` y `solver_info` si existen.
- `build_grid_summary_table.m`: columnas nuevas al final; las anteriores no cambian.
- `wdro-market/main_validation_grid_market.m`: ya no depende de `wdro-return/`.
- `test_wdro_nominal_equivalence.m`: reescrito (§4).

**Nuevos:** `classify_solver_status.m`, `solver_info_from_log.m`, `attach_rf.m`, `analyze_solver_status.m`, `verify_eta0_backtest.m`, `verify_backtest_constraints.m`, `rebuild_validation_tables.m`, `wdro-market/truncate_data.m`.

**Carpetas de resultados nuevas:**
- `results_estado_solver/`: `tabla_meses_sin_optimizacion.csv`, `diagnostico_eta_alto.csv` y `.png`.
- `results_validacion_metricas_v2/`: tablas maestras de G1 y G2, comparación, verificación η=0 y heatmaps.
- `results_verificaciones/`: `equivalencia_eta0_instancias.csv`, `equivalencia_eta0_backtest.csv`, `nominal_backtests.mat`, `verificacion_restricciones.csv`, `metricas_anteriores_vs_nuevas_eta0.csv`, `resumen_distancias_c.csv`.

Comprobado después de los cambios: η=0 reproduce el nominal (instancias y backtest completo), y un backtest corto de G1 y G2 con η=0.15 y el código nuevo reproduce exactamente las trayectorias guardadas (|Δx| = |ΔG| = 0).

## 7. Lo que no se hizo y por qué
- T6 (bootstrap) y T7 (régimen): fuera del alcance pedido (T2–T5).
- No se reevaluó el periodo de prueba con las métricas nuevas para la configuración elegida, ni se eligió la configuración de G2: depende de que fijes la regla de selección (hallazgo 1).
- No se volvió a correr ninguna malla: no hacía falta, y se respeta la regla de no sobrescribir.
- Las tablas antiguas (`results_validacion_grid/`, `wdro-market/results_validacion_grid_market/`, `results_prueba_fuera_muestra/`) quedan con las métricas anteriores; las nuevas están en `results_validacion_metricas_v2/`.
- No se cambió la definición del conteo de transacciones (ver la observación del §4.2(b)), ni los comentarios de `extract_period_results.m` / `main_validation_grid.m` sobre la «equivalencia» del recorte.
- La comparación opcional del objetivo en el peor caso con un η común y la de pesos alternativos de G2 no se hicieron.
