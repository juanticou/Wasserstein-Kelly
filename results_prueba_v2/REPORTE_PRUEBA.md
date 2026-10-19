# Evaluación del periodo de prueba (2019–2025) con las configuraciones de T9

Configuraciones aprobadas (`results_seleccion/REPORTE_SELECCION.md`): G1 → (δ1*, η1*) = (0.90, 0.01); G2 → (δ2*, η2*) = (0.80, 0.01). No se barrió ninguna malla en prueba ni se volvieron a elegir parámetros.

Script: `main_test_evaluation_v2.m`. Los tramos se obtienen recortando la trayectoria completa (que empieza en dic-2014 con todo en efectivo), sin reiniciar posiciones, y re-basando la riqueza a 1 al inicio de cada tramo. Prueba: 84 meses realizados, de ene-2019 a dic-2025.

## 1. Corrida de G2 en los 132 meses
- Prueba de tiempo: 6 meses en 4.5 s (≈0.75 s/mes). Corrida real: 18.9 s para (0.90, 0.01) y 16.7 s para (0.80, 0.01).
- **Verificación:** los primeros 48 meses de las dos corridas reproducen **exactamente** la trayectoria de validación guardada (Δx = ΔG = ΔW = 0, mismas fechas; `verificacion_G2_reproduce_validacion.csv`).
- G1 sale de la malla guardada (`results_eta_delta_grid_wdro`) y el nominal de `results_verificaciones/nominal_backtests.mat` (con el mismo δ). Los valores de G1 (0.90, 0.01) y del nominal con δ=0.90 coinciden con la evaluación anterior (`results_prueba_fuera_muestra/`: 4.0241 y 3.7651).
- Meses sin optimización en prueba: **0** en las 6 estrategias.

## 2. Métricas de prueba (`metricas_por_tramo.csv`, también con validación)

| Estrategia | W_T | CAGR | MDD | CVaR 95 % | Sharpe | Costo monetario | Cota δ activa (meses de 84) |
|---|---|---|---|---|---|---|---|
| G1 (0.90, 0.01) ★G1 | 4.0241 | 22.0 % | 25.5 % | 0.0977 | 1.007 | 0.0159 | 60 |
| G2 (0.90, 0.01) | 3.8975 | 21.5 % | 26.4 % | 0.0980 | 0.986 | 0.0167 | 66 |
| G2 (0.80, 0.01) ★G2 | 3.8964 | 21.4 % | 26.4 % | 0.1032 | 0.956 | 0.0181 | 0 |
| Nominal (0.90) | 3.7651 | 20.9 % | 26.8 % | 0.1004 | 0.952 | 0.0180 | 65 |
| G1 (0.80, 0.01) | 3.7078 | 20.6 % | 27.0 % | 0.1005 | 0.921 | 0.0192 | 0 |
| Nominal (0.80) | 3.6469 | 20.3 % | 26.4 % | 0.1055 | 0.896 | 0.0216 | 0 |

★ = configuración seleccionada para esa geometría. Gráficas: `riqueza_prueba.png` y `riqueza_trayectoria_completa.png`.

## 3. Contrastes con D_k = log G^A − log G^B, en los 84 meses (`contrastes_prueba.csv`)
Son solo valores puntuales: **sin intervalos**, porque el bootstrap (T6) sigue pendiente. No permiten afirmar que una estrategia sea superior.

| Contraste | A | B | media D_k | mediana D_k | % D_k>0 | W_A/W_B − 1 |
|---|---|---|---|---|---|---|
| Emparejado | G2 (0.90, 0.01) | G1 (0.90, 0.01) | −0.00038 | ≈0 | 50.0 % | −3.1 % |
| Emparejado | G2 (0.80, 0.01) | G1 (0.80, 0.01) | +0.00059 | ≈0 | 52.4 % | +5.1 % |
| Seleccionado | G2 (0.80, 0.01) | G1 (0.90, 0.01) | −0.00038 | −0.00061 | 42.9 % | −3.2 % |
| vs nominal | G1 (0.90, 0.01) | Nominal (0.90) | +0.00079 | ≈0 | 52.4 % | +6.9 % |
| vs nominal | G2 (0.90, 0.01) | Nominal (0.90) | +0.00041 | ≈0 | 52.4 % | +3.5 % |
| vs nominal | G1 (0.80, 0.01) | Nominal (0.80) | +0.00020 | ≈0 | 59.5 % | +1.7 % |
| vs nominal | G2 (0.80, 0.01) | Nominal (0.80) | +0.00079 | ≈0 | 66.7 % | +6.8 % |

## 4. Observaciones para interpretar (sin concluir)
1. **El contraste emparejado cambia de signo según la configuración**: G2 − G1 es negativo con (0.90, 0.01) y positivo con (0.80, 0.01).
2. **Muchos meses casi idénticos**: entre 6 y 19 de los 84 meses tienen |D_k| < 1e-6 (por eso la mediana es ≈0), así que el «% D_k>0» incluye empates numéricos.
   - G2 vs G1 en (0.90, 0.01): 34 meses positivos y 37 negativos con |D_k| > 1e-4.
   - G2 vs G1 en (0.80, 0.01): 32 y 31.
   - Las diferencias de riqueza de 3–7 % se acumulan a lo largo de 84 meses con diferencias mensuales del orden de 1e-3 a 2e-2 (máx. |D_k| ≈ 0.02).
3. **Cambio de régimen de la cota δ**: con δ=0.90 la cota está activa en 60–66 de los 84 meses de prueba, frente a 4–8 de 48 en validación. En validación, δ=0.90 y δ=0.80 eran casi la misma estrategia; en prueba no lo son. Por eso el contraste «seleccionado» mezcla geometría y δ y no aísla el efecto de la geometría, como dice el texto.
4. Ruido numérico de referencia (T9, 1b): entre estrategias teóricamente idénticas, la riqueza de validación difería hasta 4.6e-4 en 48 meses. Las diferencias de prueba son unas 100 veces mayores, pero sin inferencia (T6) no se puede afirmar nada más.

## 5. Archivos
- `results_prueba_v2/verificacion_G2_reproduce_validacion.csv`
- `results_prueba_v2/g2_trayectorias_completas.mat`
- `results_prueba_v2/metricas_por_tramo.csv`
- `results_prueba_v2/contrastes_prueba.csv`
- `results_prueba_v2/riqueza_prueba.png`
- `results_prueba_v2/riqueza_trayectoria_completa.png`
- Script nuevo: `main_test_evaluation_v2.m`. No se modificó código existente ni se sobrescribieron resultados.

**Siguiente paso natural:** T6 (bootstrap por bloques) sobre estas mismas series de D_k, sin volver a elegir parámetros.
