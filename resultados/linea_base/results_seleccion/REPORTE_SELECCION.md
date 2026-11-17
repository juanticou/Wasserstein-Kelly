# T9: elección de (δ, η) por geometría (solo validación 2015–2018)

Se usaron solo meses de validación: 48 meses realizados, con decisiones de dic-2014 a nov-2018. Las métricas salen de `results_validacion_metricas_v2/`; las trayectorias de G1 se recortaron a validación al cargarlas y el panel se truncó a dic-2018 (`diagnostico_seleccion.m` lo comprueba con `assert`). No se abrió ningún resultado de 2019–2025 y no se modificó código existente.

Scripts: `diagnostico_seleccion.m` (Paso 1), `select_parameters.m` (la regla) y `main_seleccion_parametros.m` (Pasos 2 y 3). `select_parameters.m` es una función, así que la regla se aplica desde un script aparte.

## Paso 1: diagnóstico
**1a. Cota δ activa** (holgura ≤ 1e-6; `diagnostico_cota_delta.csv`). Solo está activa con **δ=0.90**:

| | η=0 | 0.01 | 0.02 | 0.03 | 0.04 | ≥0.05 |
|---|---|---|---|---|---|---|
| G1 (meses activos de 48) | 8 | 6 | 4 | 4 | 1 | 0 |
| G2 (meses activos de 48) | 8 | 4 | 3 | 0 | 0 | 0 |

Con δ ≤ 0.80 la cota no se activa en ninguna celda: para cada η, las celdas con δ ∈ {0.50, 0.60, 0.70, 0.75, 0.80} son la misma estrategia en teoría.

**1b. Ruido numérico entre esas celdas equivalentes** (`ruido_celdas_equivalentes.csv`):
- Diferencia relativa máxima de riqueza final: **4.62e-4** (G2, η=0.15); en G1 llega a 4.32e-4 (η=0.10). Con η=0 vale 1.22e-4 en las dos geometrías.
- max|Δ[x, x0]| mes a mes: hasta **5.0e-3** (G1, η=0.10).
- Por qué: el objetivo es casi plano cerca de las cotas x̄. Con la precisión de CVX (1.5e-8 en el objetivo), problemas equivalentes devuelven ponderaciones distintas en el tercer decimal, y esas diferencias se acumulan en la riqueza.

**1c. Riqueza frente a η** (`riqueza_vs_eta.csv`, `riqueza_vs_eta_G1.png`, `riqueza_vs_eta_G2.png`): la riqueza baja de forma monótona al subir η.
- Con δ=0.90, frente a η=0 (W=2.3666): η=0.01 pierde −1.5 % en G1 y −1.1 % en G2, y η≥0.30 pierde ≈ −56 % en las dos (W≈1.032, prácticamente todo en bajo riesgo).

## Paso 2: regla y TOL
- Regla, fijada a priori por el usuario: η>0; fracción de meses óptimos ≥ φ_min = 0.95; máxima riqueza de validación; empate si la brecha relativa es < TOL; desempate por menor η y luego mayor δ.
- **TOL = 5e-4**: es el ruido máximo medido en 1b (4.62e-4) redondeado hacia arriba al siguiente valor {1, 2, 5}×10^k, según la fórmula aprobada antes de correr la selección. Elegibles: 60 de 66 celdas (todas tienen fracción de meses óptimos = 1). La regla pasó primero una prueba con una tabla sintética.

| Geometría | Elegida | W validación | Cómo se eligió |
|---|---|---|---|
| **G1** | **δ=0.90, η=0.01** | 2.33070 | Máxima riqueza, sin empate (la 2.ª está 0.2 % abajo). Coincide con la configuración ya usada en la prueba. |
| **G2** | **δ=0.80, η=0.01** | 2.34166 | Empate de 5 celdas: δ ∈ {0.50, 0.60, 0.70, 0.75, 0.80} con η=0.01, que son justo las celdas equivalentes de 1b (brechas ≤ 2.4e-4). Gana δ=0.80 por ser el mayor δ. La máxima riqueza la tiene δ=0.70 (2.34192). |

**Lectura de la elección de G2:** δ=0.80 representa a la familia «η=0.01 con la cota δ inactiva». En validación, cualquier δ ≤ 0.80 da la misma estrategia salvo ruido numérico. G2 con δ=0.90 (W=2.34047, cota activa 4 meses) queda fuera del empate por una brecha de 6.2e-4.

## Paso 3: sensibilidad (solo se reporta; no cambia la elección)
(`sensibilidad_seleccion.csv`, `top10_G1.csv`, `top10_G2.csv`)
- **Top 10**: en las dos geometrías, los puestos 1–6 son η=0.01 con los seis δ, y los puestos 7–10 son η=0.02.
- **Incluyendo η=0**: las dos geometrías elegirían **δ=0.90, η=0** (el nominal). Las seis celdas con η=0 empatan dentro de TOL y gana el mayor δ.
- **TOL×10 (5e-3)**: G1 no cambia (0.90, 0.01). G2 pasa a **(0.90, 0.01)**: el empate incluye a δ=0.90 y gana el mayor δ.
- **TOL/10 (5e-5)**: G1 no cambia. G2 pasa a **(0.75, 0.01)**.
- **Mejor Sharpe (η>0)**: G1 (0.90, 0.01), igual que la elegida; G2 (0.70, 0.01), equivalente a la elegida.
- **Mejor CVaR y mejor MDD (η>0)**: siempre η=0.30, celdas casi todo en bajo riesgo (MDD = 0, CVaR ≈ 0), con riqueza 56 % menor (puestos 43–45).
- **Borde de la malla elegible**: las dos elecciones tienen **η=0.01, el menor η>0 de la malla**. G1 además está en el borde de δ (0.90). Es decir, la regla empuja hacia el modelo más cercano al nominal: la malla no permite saber si un η entre 0 y 0.01 daría más riqueza.

## Advertencias
1. **Elección de G2 poco robusta en δ**: cambia con TOL (0.75 / 0.80 / 0.90). Entre 0.75 y 0.80 da igual (es la misma estrategia), pero frente a 0.90 sí cambia, porque con δ=0.90 la cota está activa.
2. **Riesgo de sobreajuste**: 48 meses y 60 celdas elegibles, y las brechas entre las mejores celdas son del orden del ruido numérico.
3. **Contaminación previa (transparencia)**: en la sesión de T2–T5 ya calculé cantidades del periodo de prueba (métricas del nominal δ=0.90 en prueba; exposición de G1 δ=0.90 con η≥0.15 después de 2022). La regla la fijó el usuario y TOL sale de una fórmula que solo usa validación, pero conviene saberlo.

## Pendiente (requiere tu aprobación de las configuraciones)
Con (δ1*, η1*) = (0.90, 0.01) y (δ2*, η2*) = (0.80, 0.01):
1. Correr G2 en los 132 meses solo para esas configuraciones, empezando por una prueba de tiempo, y verificar que los primeros 48 reproducen la validación guardada.
2. Evaluar 2019–2025 recortando la trayectoria completa, con las métricas nuevas, para: el nominal con cada δ; G1 y G2 con (0.90, 0.01); y G1 y G2 con (0.80, 0.01). G1 con (0.80, 0.01) ya existe en la malla guardada.
3. Salidas en `results_prueba_v2/`.
