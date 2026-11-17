# Tablas R8 (generadas por `results_finales/r8_tiempos_adversarial.m`)

Solo lee CSV; no optimiza ni elige parámetros. Fuentes: `results_v2/results_tiempos/tiempos_por_mes.csv`, `results_v2/results_tiempos/tiempos_resumen.csv`, `results_v2/results_tiempos/entorno_tiempos.csv`, `results_v2/results_probabilidades_adversariales/resumen_por_fecha.csv`, `results_v2/results_probabilidades_adversariales/verificaciones.csv`.

## G. Tiempos de solución por mes (segundos)

CSV: `tabla_g_tiempos.csv`; .tex: `tabla_g_tiempos.tex`. Entorno: MATLAB R2026a, CVX Version 2.2, Build 1148, MOSEK 9.1.9, 8 núcleos.

| Estrategia | Tramo | n | Mediana | Media | Máx. | C_k y ρ_k (ms) | No óptimos |
|---|---|---:|---:|---:|---:|---:|---:|
| Nominal (0.80) | validacion | 48 | 0.091 | 0.100 | 0.231 | 0.00 | 0 |
| Nominal (0.80) | prueba | 84 | 0.090 | 0.091 | 0.099 | 0.00 | 0 |
| Nominal (0.90) | validacion | 48 | 0.090 | 0.091 | 0.096 | 0.00 | 0 |
| Nominal (0.90) | prueba | 84 | 0.090 | 0.091 | 0.103 | 0.00 | 0 |
| G1 (0.80, 0.01) | validacion | 48 | 0.123 | 0.124 | 0.150 | 1.23 | 0 |
| G1 (0.80, 0.01) | prueba | 84 | 0.124 | 0.124 | 0.135 | 0.45 | 0 |
| G1 (0.90, 0.01) | validacion | 48 | 0.123 | 0.124 | 0.133 | 0.44 | 0 |
| G1 (0.90, 0.01) | prueba | 84 | 0.122 | 0.124 | 0.144 | 0.45 | 0 |
| G2 (0.80, 0.01) | validacion | 48 | 0.124 | 0.124 | 0.136 | 1.41 | 0 |
| G2 (0.80, 0.01) | prueba | 84 | 0.124 | 0.125 | 0.142 | 0.58 | 0 |
| G2 (0.90, 0.01) | validacion | 48 | 0.123 | 0.124 | 0.132 | 0.57 | 0 |
| G2 (0.90, 0.01) | prueba | 84 | 0.123 | 0.128 | 0.323 | 0.57 | 0 |

## H. Distribución adversarial (medias por fecha de decisión)

CSV: `tabla_h_adversarial.csv`; .tex: `tabla_h_adversarial.tex` (solo caso común, prueba). Común = mismo portafolio (nominal del mismo δ) para G1 y G2; propio = portafolio de cada estrategia. Fechas con exceso > 0: umbral 1e-08.

### Caso comun, validacion (n = 48)

| Indicador | c1 G1 | c1 G2 | c2 G1 | c2 G2 |
|---|---:|---:|---:|---:|
| ρ_k medio | 0.0083 | 0.0082 | 0.0083 | 0.0082 |
| Masa movida (%) | 1.48 | 1.37 | 1.47 | 1.37 |
| N efectivo de escenarios (de 60) | 58.6 | 58.7 | 58.6 | 58.7 |
| Masa del peor escenario (%) | 1.90 | 1.67 | 1.92 | 1.67 |
| Exceso de masa, VIX alto (pp) | 0.70 | 0.27 | 0.69 | 0.27 |
| Fechas con exceso > 0, VIX alto (%) | 54.2 | 27.1 | 54.2 | 27.1 |
| Exceso de masa, SPY < 0 (pp) | 1.30 | 0.02 | 1.29 | 0.02 |
| Fechas con exceso > 0, SPY < 0 (%) | 89.6 | 2.1 | 89.6 | 2.1 |

### Caso comun, prueba (n = 84)

| Indicador | c1 G1 | c1 G2 | c2 G1 | c2 G2 |
|---|---:|---:|---:|---:|
| ρ_k medio | 0.0083 | 0.0083 | 0.0083 | 0.0083 |
| Masa movida (%) | 1.10 | 1.32 | 0.97 | 1.33 |
| N efectivo de escenarios (de 60) | 59.1 | 58.8 | 59.3 | 58.8 |
| Masa del peor escenario (%) | 1.81 | 1.72 | 1.93 | 1.83 |
| Exceso de masa, VIX alto (pp) | 0.13 | -0.02 | 0.13 | 0.09 |
| Fechas con exceso > 0, VIX alto (%) | 33.3 | 6.0 | 29.8 | 11.9 |
| Exceso de masa, SPY < 0 (pp) | 0.65 | 0.39 | 0.89 | 0.42 |
| Fechas con exceso > 0, SPY < 0 (%) | 73.8 | 40.5 | 94.0 | 50.0 |

### Caso propio, validacion (n = 48)

| Indicador | c1 G1 | c1 G2 | c2 G1 | c2 G2 |
|---|---:|---:|---:|---:|
| ρ_k medio | 0.0083 | 0.0082 | 0.0083 | 0.0082 |
| Masa movida (%) | 1.48 | 1.43 | 1.49 | 1.41 |
| N efectivo de escenarios (de 60) | 58.6 | 58.7 | 58.6 | 58.7 |
| Masa del peor escenario (%) | 1.87 | 1.67 | 1.87 | 1.67 |
| Exceso de masa, VIX alto (pp) | 0.85 | 0.30 | 0.85 | 0.33 |
| Fechas con exceso > 0, VIX alto (%) | 64.6 | 27.1 | 62.5 | 29.2 |
| Exceso de masa, SPY < 0 (pp) | 1.45 | 0.17 | 1.46 | 0.17 |
| Fechas con exceso > 0, SPY < 0 (%) | 97.9 | 18.8 | 97.9 | 18.8 |

### Caso propio, prueba (n = 84)

| Indicador | c1 G1 | c1 G2 | c2 G1 | c2 G2 |
|---|---:|---:|---:|---:|
| ρ_k medio | 0.0083 | 0.0083 | 0.0083 | 0.0083 |
| Masa movida (%) | 1.05 | 1.26 | 0.98 | 1.24 |
| N efectivo de escenarios (de 60) | 59.2 | 58.9 | 59.3 | 58.9 |
| Masa del peor escenario (%) | 1.82 | 1.75 | 1.89 | 1.79 |
| Exceso de masa, VIX alto (pp) | 0.30 | -0.02 | 0.17 | 0.13 |
| Fechas con exceso > 0, VIX alto (%) | 41.7 | 6.0 | 32.1 | 14.3 |
| Exceso de masa, SPY < 0 (pp) | 0.72 | 0.42 | 0.83 | 0.46 |
| Fechas con exceso > 0, SPY < 0 (%) | 78.6 | 41.7 | 89.3 | 53.6 |

## Figura

`exceso_spy_negativo.pdf/.png`: exceso de masa adversarial (pp) en los meses de la ventana con retorno de SPY negativo, caso común, 132 fechas de decisión; G1 continua, G2 discontinua; línea punteada = primera decisión de prueba.

## Verificación

205 comprobaciones, 0 fallidas (detalle en `r8_verificacion.csv`).
