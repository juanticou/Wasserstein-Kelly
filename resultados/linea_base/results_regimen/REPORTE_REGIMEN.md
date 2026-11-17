# T7: desglose por régimen (descriptivo)

Usa las mismas series y contrastes de prueba que T6: 84 meses, ene-2019 a dic-2025, recortados de las trayectorias completas. No se eligió ni se ajustó ningún parámetro. Script: `main_regime_breakdown.m`.

## Clasificación (solo información disponible en la fecha de decisión k)
Umbrales fijados a priori, como en la metodología; ninguno se eligió mirando la prueba:
- **VIX alto** si VIX_k > mediana del VIX en la ventana D_k (los 60 meses que terminan en k, la misma ventana de la decisión); **VIX bajo** si VIX_k ≤ esa mediana.
- **SPY_k negativo** si el retorno de SPY en el mes k es < 0; **no negativo** si es ≥ 0.

Cada mes realizado k+1 hereda la clase del mes k. Detalle por mes en `clasificacion_meses.csv`.

**Tamaño de los grupos (de 84 meses):**

| | SPY_k < 0 | SPY_k ≥ 0 | Total |
|---|---|---|---|
| VIX alto | 23 | 25 | 48 |
| VIX bajo | 5 | 31 | 36 |
| **Total** | 28 | 56 | 84 |

48 de los 84 meses tienen el VIX por encima de la mediana de su ventana de 5 años; las ventanas incluyen años de VIX bajo, 2014–2019. La celda «VIX bajo y SPY_k < 0» tiene solo 5 meses.

## Media de D_k y proporción de meses con D_k > 0 por régimen (`desglose_regimen.csv`)

| Contraste | Todos (84) | VIX alto (48) | VIX bajo (36) | SPY_k<0 (28) | SPY_k≥0 (56) |
|---|---|---|---|---|---|
| (i) G1 − Nom, (0.90, 0.01) | +0.00079 / 52 % | +0.00104 / 46 % | +0.00047 / 61 % | +0.00120 / 46 % | +0.00059 / 55 % |
| (ii) G2 − G1, (0.90, 0.01) | −0.00038 / 50 % | −0.00058 / 52 % | −0.00012 / 47 % | −0.00152 / 46 % | +0.00019 / 52 % |
| (iii) G2 − Nom, (0.90, 0.01) | +0.00041 / 52 % | +0.00046 / 56 % | +0.00035 / 47 % | −0.00033 / 46 % | +0.00078 / 55 % |
| (i) G1 − Nom, (0.80, 0.01) | +0.00020 / 60 % | −0.00027 / 50 % | +0.00082 / 72 % | −0.00073 / 46 % | +0.00066 / 66 % |
| (ii) G2 − G1, (0.80, 0.01) | +0.00059 / 52 % | +0.00125 / 67 % | −0.00029 / 33 % | +0.00128 / 64 % | +0.00025 / 46 % |
| (iii) G2 − Nom, (0.80, 0.01) | +0.00079 / 67 % | +0.00098 / 67 % | +0.00053 / 67 % | +0.00055 / 61 % | +0.00091 / 70 % |
| (ii) seleccionado: G2(0.80) − G1(0.90) | −0.00038 / 43 % | −0.00095 / 40 % | +0.00036 / 47 % | −0.00105 / 43 % | −0.00005 / 43 % |

Cada celda es «media mensual de D_k / % de meses con D_k > 0». Los contrastes (i) y (iii) seleccionados coinciden con los emparejados, porque el nominal usa el mismo δ.

**Cruce 2×2 del contraste central, (ii) G2 − G1** (media de D_k):

| | VIX alto, SPY<0 (23) | VIX alto, SPY≥0 (25) | VIX bajo, SPY<0 (5) | VIX bajo, SPY≥0 (31) |
|---|---|---|---|---|
| Emparejado (0.90, 0.01) | −0.00158 | +0.00034 | −0.00128 | +0.00007 |
| Emparejado (0.80, 0.01) | +0.00165 | +0.00089 | −0.00041 | −0.00027 |
| Seleccionado | −0.00041 | −0.00144 | −0.00401 | +0.00107 |

## Lectura descriptiva (sin concluir)
1. **El contraste central G2 − G1 no tiene un patrón de régimen estable.**
   - Con (0.80, 0.01), G2 rinde más que G1 en meses de VIX alto o SPY_k negativo (+0.00125 y +0.00128; 64–67 % de meses con D>0) y menos con VIX bajo.
   - Con (0.90, 0.01) pasa lo contrario en los meses con SPY_k negativo (−0.00152).
   - La configuración cambia el signo, igual que en el total (T6).
2. **G1 − nominal con δ=0.90** es positivo en todos los regímenes. Sin embargo, la proporción de meses con D>0 es < 50 % en VIX alto y en SPY_k<0: la media positiva se apoya en pocos meses con diferencias grandes.
3. **G2 − nominal con δ=0.80** es positivo en los cuatro grupos marginales, con 61–70 % de meses con D>0.
4. Los empates numéricos (|D_k| < 1e-6) son 0–19 meses según el contraste. La columna `prop_D_pos_sin_empates` da la proporción sin contarlos.

**Advertencias:**
- Es un análisis descriptivo: **no hay inferencia por régimen** y los grupos son pequeños (5–56 meses).
- Con 7 contrastes × 9 grupos, aparecen patrones por azar.
- La clasificación usa información de k, pero eso no prueba capacidad de anticipación, como dice el texto.

## Para la metodología (C31, l. 331–333)
- Se confirma que el desglose se calculó como lo describe el texto. VIX al cierre de k frente a la mediana del VIX en la ventana D_k: la ventana de 60 meses que termina en k, **incluyendo el mes k**. Retorno de SPY en k negativo / no negativo. Todo con información disponible en k.
- Detalle para el texto: el caso de empate VIX_k = mediana se asignó a «bajo». También se añadió el cruce 2×2. El `[PENDIENTE]` se puede retirar.

## Archivos
- Código nuevo: `main_regime_breakdown.m`.
- Resultados: `results_regimen/clasificacion_meses.csv`, `results_regimen/desglose_regimen.csv` (incluye el 2×2 de todos los contrastes).
- No se modificó código existente ni se sobrescribieron resultados.
