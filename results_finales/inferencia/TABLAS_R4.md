# Tablas R4 (generadas por `results_finales/r4_inferencia.m`)

Fuentes: `results_v2/results_bootstrap/tabla_bootstrap_contrastes.csv`, `results_v2/results_regimen/desglose_regimen.csv` y `clasificacion_meses.csv`. Contrastes numerados como en la Tabla `tab:contrastes`; c1 = (0.90, 0.01), c2 = (0.80, 0.01). D_k = log G^A - log G^B, en % mensual. Contraste principal: 1 y 2 (los demás son exploratorios).

## A. Bootstrap por bloques (prueba 2019-2025)

CSV: `tabla_r4a_bootstrap.csv`; .tex: `tabla_r4a_bootstrap.tex`

| N.º | A | B | Media (%) | Mediana (%) | % D>0 | Empates | IC ℓ=3 (%) | IC ℓ=6 (%) | IC ℓ=12 (%) |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | G2 (0.90, 0.01) | G1 (0.90, 0.01) | -0.038 | 0.000 | 50.0 | 6 | [-0.118, 0.038] | [-0.118, 0.038] | [-0.126, 0.038] |
| 2 | G2 (0.80, 0.01) | G1 (0.80, 0.01) | 0.059 | 0.000 | 52.4 | 16 | [-0.039, 0.164] | [-0.035, 0.170] | [-0.029, 0.157] |
| 3 | G2 (0.80, 0.01) | G1 (0.90, 0.01) | -0.038 | -0.061 | 42.9 | 0 | [-0.202, 0.133] | [-0.205, 0.127] | [-0.210, 0.076] |
| 4 | G1 (0.90, 0.01) | Nominal (0.90) | 0.079 | 0.000 | 52.4 | 7 | [0.013, 0.163] | [0.014, 0.169] | [0.007, 0.174] |
| 5 | G2 (0.90, 0.01) | Nominal (0.90) | 0.041 | 0.000 | 52.4 | 8 | [-0.026, 0.120] | [-0.021, 0.110] | [-0.018, 0.094] |
| 6 | G1 (0.80, 0.01) | Nominal (0.80) | 0.020 | 0.000 | 59.5 | 19 | [-0.079, 0.111] | [-0.081, 0.111] | [-0.084, 0.117] |
| 7 | G2 (0.80, 0.01) | Nominal (0.80) | 0.079 | 0.000 | 66.7 | 18 | [-0.028, 0.200] | [-0.035, 0.209] | [-0.021, 0.203] |

## B. Desglose por régimen (media % y, entre paréntesis, % D>0)

CSV: `tabla_r4b_regimen.csv`; .tex: `tabla_r4b_regimen.tex`

| N.º | A | B | todos (n=84) | VIX alto (n=48) | VIX bajo (n=36) | SPY_k negativo (n=28) | SPY_k no negativo (n=56) |
|---|---|---|---:|---:|---:|---:|---:|
| 1 | G2 (0.90, 0.01) | G1 (0.90, 0.01) | -0.038 (50.0) | -0.058 (52.1) | -0.012 (47.2) | -0.152 (46.4) | 0.019 (51.8) |
| 2 | G2 (0.80, 0.01) | G1 (0.80, 0.01) | 0.059 (52.4) | 0.125 (66.7) | -0.029 (33.3) | 0.128 (64.3) | 0.025 (46.4) |
| 3 | G2 (0.80, 0.01) | G1 (0.90, 0.01) | -0.038 (42.9) | -0.095 (39.6) | 0.037 (47.2) | -0.105 (42.9) | -0.005 (42.9) |
| 4 | G1 (0.90, 0.01) | Nominal (0.90) | 0.079 (52.4) | 0.104 (45.8) | 0.047 (61.1) | 0.120 (46.4) | 0.059 (55.4) |
| 5 | G2 (0.90, 0.01) | Nominal (0.90) | 0.041 (52.4) | 0.046 (56.2) | 0.035 (47.2) | -0.033 (46.4) | 0.078 (55.4) |
| 6 | G1 (0.80, 0.01) | Nominal (0.80) | 0.020 (59.5) | -0.027 (50.0) | 0.082 (72.2) | -0.073 (46.4) | 0.066 (66.1) |
| 7 | G2 (0.80, 0.01) | Nominal (0.80) | 0.079 (66.7) | 0.098 (66.7) | 0.053 (66.7) | 0.055 (60.7) | 0.091 (69.6) |

## C. Cruce 2x2 de los contrastes principales (media %, (% D>0), [n])

CSV: `tabla_r4c_cruce.csv`; .tex: `tabla_r4c_cruce.tex`

| N.º | Contraste | | SPY_k < 0 | SPY_k ≥ 0 |
|---|---|---|---:|---:|
| 1 | G2 (0.90, 0.01) − G1 (0.90, 0.01) | VIX alto | -0.158 (52.2) [23] | 0.034 (52.0) [25] |
| 1 | G2 (0.90, 0.01) − G1 (0.90, 0.01) | VIX bajo | -0.128 (20.0) [5] | 0.007 (51.6) [31] |
| 2 | G2 (0.80, 0.01) − G1 (0.80, 0.01) | VIX alto | 0.165 (69.6) [23] | 0.089 (64.0) [25] |
| 2 | G2 (0.80, 0.01) − G1 (0.80, 0.01) | VIX bajo | -0.041 (40.0) [5] | -0.027 (32.3) [31] |

## Figura

`ic_contrastes.pdf/.png`: media de D_k (% mensual) e IC 95 % por bootstrap de los siete contrastes, un marcador por ℓ ∈ {3, 6, 12}; la línea discontinua separa el contraste principal (1 y 2) de los exploratorios.

## Verificación

529 comprobaciones, 0 fallidas (detalle en `r4_verificacion.csv`).
