# Índice de resultados (generado por `results_finales/r6_resultados.m`)

No editar a mano: se regenera con `r6_resultados`. Todas las cifras salen de los archivos citados entre paréntesis (archivo y columna). Fuente común: `results_v2/` (aprobado en R1). c1 = (δ, η) = (0.90, 0.01), elegida para G1; c2 = (0.80, 0.01), elegida para G2 (T9). Prueba: 84 meses realizados (ene-2019 a dic-2025); validación: 48 (ene-2015 a dic-2018).

Antes de escribir este índice se comprobó que R2–R5 no tienen fallos (958 comprobaciones en total).

## 1. Tablas y figuras

| Archivo | Script | Qué muestra |
|---|---|---|
| `results_finales/tablas/tabla_a_prueba_desempeno.csv/.tex` | `r2_tablas.m` | Prueba: riqueza final, crecimiento logarítmico medio, CAGR, MDD, peor mes, VaR y CVaR al 95 %, Sharpe, Sortino y Calmar de las seis estrategias. |
| `results_finales/tablas/tabla_b_prueba_operacion.csv/.tex` | `r2_tablas.m` | Prueba: turnover, meses con transacción, costo fraccional y monetario, peso máximo, N_eff y proporción en riesgo. |
| `results_finales/tablas/tabla_c_prueba_restricciones.csv/.tex` | `r2_tablas.m` | Prueba: incumplimientos de δ, mínimo factor de crecimiento, meses con la cota δ activa y meses sin optimización. |
| `results_finales/tablas/tabla_d_validacion.csv/.tex` | `r2_tablas.m` | Validación: las dos configuraciones elegidas y el nominal de cada δ, con las métricas de (a) y (b). |
| `results_finales/tablas/TABLAS_R2.md` | `r2_tablas.m` | Las tablas (a)–(d) en Markdown. |
| `results_finales/figuras/riqueza_prueba.pdf/.png` | `r3_figuras.m` | Riqueza re-basada a 1 al inicio de la prueba de las seis estrategias evaluadas. |
| `results_finales/figuras/drawdown_prueba.pdf/.png` | `r3_figuras.m` | Caída porcentual desde el máximo previo de la riqueza (eje invertido), seis estrategias. |
| `results_finales/figuras/riesgo_neff_prueba.pdf/.png` | `r3_figuras.m` | Proporción invertida en activos riesgosos y número efectivo de activos riesgosos por mes (N_eff = 0 sin exposición). |
| `results_finales/figuras/turnover_costo_prueba.pdf/.png` | `r3_figuras.m` | Turnover acumulado y costo monetario acumulado (suma de W_k tau TO_k / W_0) de las seis estrategias. |
| `results_finales/figuras/mapa_riqueza.pdf/.png` | `r3_figuras.m` | Validación 2015-2018, malla delta x eta: Riqueza final; recuadro = configuración elegida (T9). |
| `results_finales/figuras/mapa_cvar.pdf/.png` | `r3_figuras.m` | Validación 2015-2018, malla delta x eta: CVaR 95 %; recuadro = configuración elegida (T9). |
| `results_finales/figuras/mapa_sharpe.pdf/.png` | `r3_figuras.m` | Validación 2015-2018, malla delta x eta: Sharpe; recuadro = configuración elegida (T9). |
| `results_finales/figuras/mapa_costo.pdf/.png` | `r3_figuras.m` | Validación 2015-2018, malla delta x eta: Costo monetario; recuadro = configuración elegida (T9). |
| `results_finales/figuras/mapa_riesgo.pdf/.png` | `r3_figuras.m` | Validación 2015-2018, malla delta x eta: Proporción en riesgo; recuadro = configuración elegida (T9). |
| `results_finales/figuras/mapa_cota_activa.pdf/.png` | `r3_figuras.m` | Validación 2015-2018, malla delta x eta: Meses con la cota delta activa; recuadro = configuración elegida (T9). |
| `results_finales/figuras/mapa_optima.pdf/.png` | `r3_figuras.m` | Validación 2015-2018, malla delta x eta: Fracción de meses con solución óptima; recuadro = configuración elegida (T9). |
| `results_finales/figuras/riqueza_vs_eta_validacion.pdf/.png` | `r3_figuras.m` | Riqueza final de validación frente a eta (espaciado categórico), una línea por delta, para cada geometría. |
| `results_finales/figuras/exposicion_eta_alto.pdf/.png` | `r3_figuras.m` | Proporción en riesgo de G1 con delta = 0.90 y eta en {0, 0.10, 0.15, 0.30}, 132 decisiones (diagnóstico de trayectorias planas). |
| `results_finales/figuras/dk_contraste_principal.pdf/.png` | `r3_figuras.m` | Diferencia mensual de crecimiento logarítmico D_k (en puntos porcentuales) de los contrastes 1 y 2 (G2 frente a G1 con los mismos parámetros). |
| `results_finales/inferencia/tabla_r4a_bootstrap.csv/.tex` | `r4_inferencia.m` | Prueba: media, mediana, % D_k > 0, empates e IC 95 % por bootstrap con ℓ ∈ {3, 6, 12} de los siete contrastes. |
| `results_finales/inferencia/tabla_r4b_regimen.csv/.tex` | `r4_inferencia.m` | Prueba: media de D_k y % D_k > 0 por régimen (todos, VIX alto/bajo, SPY_k < 0 / ≥ 0), siete contrastes. |
| `results_finales/inferencia/tabla_r4c_cruce.csv/.tex` | `r4_inferencia.m` | Prueba: cruce 2×2 de VIX y SPY_k para los contrastes principales 1 y 2. |
| `results_finales/inferencia/ic_contrastes.pdf/.png` | `r4_inferencia.m` | Prueba: medias e IC 95 % de los siete contrastes, un marcador por ℓ. |
| `results_finales/verificacion_cruzada.csv` | `r5_verificacion_cruzada.m` | Verificación cruzada de cifras, conteos y de que la selección solo usa validación (158 comprobaciones). |

## 2. Lo que los resultados SÍ permiten afirmar (descriptivo)

1. Riqueza final de prueba (base 1), una trayectoria por estrategia: Nominal (0.80): 3.625; Nominal (0.90): 3.741; G1 (0.80, 0.01): 3.686; G1 (0.90, 0.01): 3.999; G2 (0.80, 0.01): 3.873; G2 (0.90, 0.01): 3.873 (`results_v2/results_prueba_v2/metricas_por_tramo.csv`, `riqueza_final`).
2. Riqueza final de validación: Nominal (0.80): 2.367; Nominal (0.90): 2.367; G1 (0.90, 0.01): 2.331; G2 (0.80, 0.01): 2.342 (`results_v2/results_prueba_v2/metricas_por_tramo.csv`, `riqueza_final`).
3. Contraste principal 1 (G2(c1) − G1(c1)): media de D_k = -0.038 % mensual, IC 95 % (ℓ = 6) = [-0.118 %, 0.038 %]; el IC contiene el 0 con ℓ = 3, 6 y 12; 50.0 % de meses con D_k > 0 y 6 empates (|D_k| < 1e-6) (`results_finales/inferencia/tabla_r4a_bootstrap.csv`, `media_D, IC95_inf, IC95_sup, prop_D_pos, empates_1e6`).
4. Contraste principal 2 (G2(c2) − G1(c2)): media de D_k = 0.059 % mensual, IC 95 % (ℓ = 6) = [-0.035 %, 0.170 %]; el IC contiene el 0 con ℓ = 3, 6 y 12; 52.4 % de meses con D_k > 0 y 16 empates (|D_k| < 1e-6) (`results_finales/inferencia/tabla_r4a_bootstrap.csv`, `media_D, IC95_inf, IC95_sup, prop_D_pos, empates_1e6`).
5. Contrastes exploratorios (3 a 7) cuyo IC 95 % excluye el 0: 4 (G1(c1) − Nom(0.90); con ℓ = 3, 6, 12; media 0.079 %, IC ℓ = 6 [0.014 %, 0.169 %]) (`results_finales/inferencia/tabla_r4a_bootstrap.csv`, `IC_excluye_cero`).
6. Meses sin optimización: 0 en las seis estrategias y los dos tramos (`results_v2/results_prueba_v2/metricas_por_tramo.csv`, `meses_sin_optimizacion`); la fracción mínima de meses con solución óptima en las mallas de validación de G1 y G2 es 1.00 (`tabla_maestra_validacion_G*.csv`, `fraccion_factible`).
7. Meses de prueba con factor realizado menor que δ (fuera de muestra): Nominal (0.80): 0 (mín. G = 0.8787); Nominal (0.90): 2 (mín. G = 0.8859); G1 (0.80, 0.01): 0 (mín. G = 0.8889); G1 (0.90, 0.01): 2 (mín. G = 0.8886); G2 (0.80, 0.01): 0 (mín. G = 0.8805); G2 (0.90, 0.01): 2 (mín. G = 0.8865) (`results_v2/results_prueba_v2/metricas_por_tramo.csv`, `violaciones_delta, min_factor_crecimiento`).
8. Meses de prueba con la cota δ activa en la ventana: Nominal (0.80): 0; Nominal (0.90): 65; G1 (0.80, 0.01): 0; G1 (0.90, 0.01): 60; G2 (0.80, 0.01): 0; G2 (0.90, 0.01): 66 (`results_finales/tablas/r2_cota_delta.csv`, `meses_cota_activa`). En validación, la cota solo está activa en alguna celda con G1: δ ∈ {0.90}; G2: δ ∈ {0.90} (`results_v2/results_seleccion/diagnostico_cota_delta.csv`).
9. Turnover acumulado de prueba, Wasserstein–Kelly frente al nominal del mismo δ: G1 (0.80, 0.01) 7.92 vs. Nominal (0.80) 8.73; G2 (0.80, 0.01) 7.05 vs. Nominal (0.80) 8.73; G1 (0.90, 0.01) 6.59 vs. Nominal (0.90) 7.60; G2 (0.90, 0.01) 6.77 vs. Nominal (0.90) 7.60 (`results_v2/results_prueba_v2/metricas_por_tramo.csv`, `turnover_total`). Costo monetario acumulado (riqueza inicial = 1): Nominal (0.80) 0.0216; Nominal (0.90) 0.0180; G1 (0.80, 0.01) 0.0192; G1 (0.90, 0.01) 0.0159; G2 (0.80, 0.01) 0.0181; G2 (0.90, 0.01) 0.0167 (`results_v2/results_prueba_v2/metricas_por_tramo.csv`, `costo_monetario`).
10. Validación, malla δ × η: G1: diferencia relativa máxima entre δ con η fijo = 0.458 %; con η ≥ 0.30 la riqueza está entre 1.0318 y 1.0320; G2: diferencia relativa máxima entre δ con η fijo = 0.081 %; con η ≥ 0.30 la riqueza está entre 1.0318 y 1.0320 (`tabla_maestra_validacion_G*.csv`, `riqueza_final`).
11. La selección de T9 se reproduce con las tablas de validación, sin leer resultados de 2019–2025, y G1 (0.90, 0.01) corrido con el panel truncado a dic-2018 reproduce exactamente sus 48 meses: 65 de 65 y 5 de 5 comprobaciones correctas (`results_finales/verificacion_cruzada.csv`, `bloque E y F`).

## 3. Lo que los resultados NO permiten afirmar

1. Que una geometría supere a la otra con los mismos parámetros: los IC 95 % de los contrastes principales 1 y 2 contienen el 0 con ℓ = 3, 6 y 12 (`results_finales/inferencia/tabla_r4a_bootstrap.csv`, `IC95_inf, IC95_sup`).
2. Superioridad estadística global de alguna estrategia: se calculan siete intervalos sin ajuste por comparaciones múltiples y los contrastes 3 a 7 son exploratorios; los IC que excluyen el 0 (punto 5 de la sección 2) pueden deberse a multiplicidad (metodologia_6.tex, sec. «Inferencia sobre las diferencias»).
3. Un orden entre estrategias a partir de la riqueza final: es una sola trayectoria por estrategia, no una estimación con incertidumbre (metodologia_6.tex).
4. Un efecto de la geometría a partir del contraste 3 (G2(c2) − G1(c1)): cambian a la vez la geometría y δ (metodologia_6.tex, sec. «Contrastes de la fase de prueba»).
5. Estimaciones precisas de riesgo extremo con VaR y CVaR: con 84 meses de prueba la cola al 95 % equivale a (1 − 0.95)·84 = 4.2 meses (VaR = L_(⌈0.95·84⌉) = L_(80); metodologia_6.tex, sec. «Métricas de desempeño»).
6. Diferencias entre regímenes: el desglose es descriptivo, sin intervalos por grupo, y el grupo más pequeño tiene n = 5 (`results_finales/inferencia/tabla_r4c_cruce.csv`, `n_meses`).
7. Que el δ elegido para G2 sea mejor que otros δ en validación: 5 celdas quedan dentro de la tolerancia de empate (TOL = 0.0005) y la elección cambia con la tolerancia: TOL x 10 → (0.90, 0.01); TOL / 10 → (0.75, 0.01) (`results_v2/results_seleccion/sensibilidad_seleccion.csv`, `caso, delta, eta`).
8. Generalización fuera de la muestra estudiada: diez acciones de EE. UU., un solo periodo de prueba, y la configuración de la geometría 1 ya se había evaluado en prueba antes de T9 (metodologia_6.tex, limitaciones).

## 4. Pendientes que no salen de estos resultados

- Los .tex de R2 y R4 no se han compilado en este equipo (no hay LaTeX instalado); insertarlos con \input requiere solo los paquetes que ya carga main_6.tex.
- Resuelto (4-nov-2026): el aviso de aproximación sucesiva que CVX mostró al correr r5_verificacion_cruzada.m es genérico (lo imprime lib/cvx_expert_check.m al construir log(), sin mirar el solucionador). En CVX 2.2 build 1148, lib/@cvxprob/solve.m desactiva la aproximación sucesiva con MOSEK >= 9, y el log de una instancia de prueba muestra «Calling Mosek 9.1.9», una sola llamada y conos exponenciales nativos; lo que dice metodologia_6.tex («CVX + MOSEK», cono exponencial nativo) es correcto.
