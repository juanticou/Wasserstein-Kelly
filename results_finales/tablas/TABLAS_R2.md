# Tablas R2 (generadas por `results_finales/r2_tablas.m`)

Fuente: `results_v2/results_prueba_v2/metricas_por_tramo.csv`; la fila de cota delta activa sale de `r2_cota_delta.csv`. † = configuracion elegida en validacion (T9). Porcentajes con 2 decimales; las cifras exactas estan en los CSV.

## (a) Prueba 2019-2025: desempeno

CSV: `tabla_a_prueba_desempeno.csv`

| Metrica | Nominal (0.80) | Nominal (0.90) | G1 (0.80, 0.01) | G1 (0.90, 0.01) † | G2 (0.80, 0.01) † | G2 (0.90, 0.01) |
|---|---:|---:|---:|---:|---:|---:|
| Riqueza final (base 1) | 3.625 | 3.741 | 3.686 | 3.999 | 3.873 | 3.873 |
| Crecimiento logaritmico medio mensual | 1.53 % | 1.57 % | 1.55 % | 1.65 % | 1.61 % | 1.61 % |
| CAGR | 20.20 % | 20.74 % | 20.48 % | 21.90 % | 21.34 % | 21.34 % |
| Maxima caida (MDD) | 26.39 % | 26.79 % | 27.04 % | 25.54 % | 26.38 % | 26.42 % |
| Peor mes | -12.13 % | -11.41 % | -11.11 % | -11.14 % | -11.95 % | -11.35 % |
| VaR 95 % (perdida mensual) | 8.48 % | 8.35 % | 8.48 % | 8.35 % | 8.48 % | 8.26 % |
| CVaR 95 % (perdida mensual) | 10.55 % | 10.04 % | 10.05 % | 9.77 % | 10.32 % | 9.80 % |
| Sharpe | 0.891 | 0.947 | 0.917 | 1.002 | 0.952 | 0.981 |
| Sortino | 1.779 | 1.924 | 1.841 | 2.049 | 1.904 | 2.005 |
| Calmar | 0.765 | 0.774 | 0.758 | 0.857 | 0.809 | 0.808 |

## (b) Prueba 2019-2025: operacion y concentracion

CSV: `tabla_b_prueba_operacion.csv`

| Metrica | Nominal (0.80) | Nominal (0.90) | G1 (0.80, 0.01) | G1 (0.90, 0.01) † | G2 (0.80, 0.01) † | G2 (0.90, 0.01) |
|---|---:|---:|---:|---:|---:|---:|
| Turnover acumulado | 8.73 | 7.60 | 7.92 | 6.59 | 7.05 | 6.77 |
| Meses con transaccion | 84 | 84 | 84 | 84 | 84 | 84 |
| Costo fraccional acumulado | 0.87 % | 0.76 % | 0.79 % | 0.66 % | 0.70 % | 0.68 % |
| Costo monetario acumulado (riqueza inicial = 1) | 0.0216 | 0.0180 | 0.0192 | 0.0159 | 0.0181 | 0.0167 |
| Peso maximo medio | 25.00 % | 24.99 % | 25.00 % | 24.96 % | 25.00 % | 24.99 % |
| N_eff medio | 4.25 | 4.63 | 4.39 | 4.69 | 4.43 | 4.71 |
| Proporcion en riesgo media | 99.99 % | 99.99 % | 99.99 % | 99.99 % | 99.99 % | 99.94 % |

## (c) Prueba 2019-2025: restricciones y solucionador

CSV: `tabla_c_prueba_restricciones.csv`

| Metrica | Nominal (0.80) | Nominal (0.90) | G1 (0.80, 0.01) | G1 (0.90, 0.01) † | G2 (0.80, 0.01) † | G2 (0.90, 0.01) |
|---|---:|---:|---:|---:|---:|---:|
| Meses con factor realizado < delta | 0 | 2 | 0 | 2 | 0 | 2 |
| Minimo factor de crecimiento realizado | 0.8787 | 0.8859 | 0.8889 | 0.8886 | 0.8805 | 0.8865 |
| Meses con la cota delta activa en la ventana | 0 | 65 | 0 | 60 | 0 | 66 |
| Meses sin optimizacion | 0 | 0 | 0 | 0 | 0 | 0 |
| Meses evaluados | 84 | 84 | 84 | 84 | 84 | 84 |

## (d) Validacion 2015-2018: configuraciones elegidas y nominal

CSV: `tabla_d_validacion.csv`

| Metrica | Nominal (0.80) | Nominal (0.90) | G1 (0.90, 0.01) † | G2 (0.80, 0.01) † |
|---|---:|---:|---:|---:|
| Riqueza final (base 1) | 2.367 | 2.367 | 2.331 | 2.342 |
| Crecimiento logaritmico medio mensual | 1.79 % | 1.79 % | 1.76 % | 1.77 % |
| CAGR | 24.03 % | 24.03 % | 23.56 % | 23.70 % |
| Maxima caida (MDD) | 19.59 % | 19.59 % | 19.59 % | 19.74 % |
| Peor mes | -10.86 % | -10.86 % | -10.86 % | -10.86 % |
| VaR 95 % (perdida mensual) | 6.53 % | 6.53 % | 5.98 % | 6.25 % |
| CVaR 95 % (perdida mensual) | 9.01 % | 9.01 % | 8.92 % | 9.12 % |
| Sharpe | 1.311 | 1.311 | 1.306 | 1.313 |
| Sortino | 2.608 | 2.608 | 2.612 | 2.584 |
| Calmar | 1.227 | 1.227 | 1.203 | 1.201 |
| Turnover acumulado | 4.73 | 4.70 | 4.13 | 4.04 |
| Meses con transaccion | 48 | 48 | 48 | 48 |
| Costo fraccional acumulado | 0.47 % | 0.47 % | 0.41 % | 0.40 % |
| Costo monetario acumulado (riqueza inicial = 1) | 0.0068 | 0.0067 | 0.0060 | 0.0057 |
| Peso maximo medio | 25.00 % | 25.00 % | 25.00 % | 25.00 % |
| N_eff medio | 4.22 | 4.23 | 4.34 | 4.33 |
| Proporcion en riesgo media | 99.99 % | 99.99 % | 99.99 % | 99.99 % |

## Verificacion

210 comprobaciones, 0 fallidas (detalle en `r2_verificacion.csv`).
