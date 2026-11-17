# T6: bootstrap móvil por bloques (Künsch, 1989)

Datos: solo resultados de prueba ya existentes (84 meses, ene-2019 a dic-2025), recortados de las trayectorias completas sin reiniciar posiciones; no se reeligió ningún parámetro.
- G2: `results_prueba_v2/g2_trayectorias_completas.mat`
- G1: la malla guardada
- Nominal: `results_verificaciones/nominal_backtests.mat`, con el mismo δ que la estrategia WK

## Procedimiento (`bootstrap_block_diff.m`)
D_k = log G^A_k − log G^B_k. En cada réplica se toman ⌈84/ℓ⌉ bloques solapados de ℓ meses consecutivos, con inicio uniforme en {1, …, 84−ℓ+1}; se concatenan y se truncan a 84 meses. A y B se remuestrean con **los mismos índices de mes**, de modo que el par se mueve junto.

El intervalo del 95 % es el percentil 2.5–97.5 de las B = 10 000 medias. La semilla es fija (20261019) y se usa un `RandStream` propio, que no altera el generador global. ℓ = 6 es la regla a priori; ℓ = 3 y ℓ = 12 son la sensibilidad.

## Prueba con datos simulados (`test_bootstrap_block_diff.m` → `test_simulado.csv`)
- **Casos deterministas, todos OK:**
  - Con D constante, el intervalo colapsa en ese valor.
  - Con GB muy volátil y GA = GB·e^c, el intervalo colapsa en c. Esto confirma que el par se remuestrea alineado: si A y B se remuestrearan por separado, el intervalo sería ancho.
  - La misma semilla da las mismas réplicas.
- **Media conocida** μ = 0.002, D_k = μ + e_k con e_k AR(1) (φ = 0.3, σ = 0.01), T = 84; 500 simulaciones con B = 2000 cada una:
  - La media estimada es insesgada (sesgo 1.3e-7).
  - **Cobertura empírica del intervalo del 95 %: 0.90 con ℓ = 3, 0.90 con ℓ = 6 y 0.86 con ℓ = 12.**
  - El bootstrap por bloques con percentiles **subestima la varianza en muestras cortas**: el ancho medio es ≈0.0054, frente a ≈0.0061 teórico. Con T = 84, el intervalo «del 95 %» funciona más bien como uno del 86–90 %. Es una propiedad conocida del método y no un error; no cambié el método fijado en el texto.

## Resultados (`tabla_bootstrap_contrastes.csv`; ℓ = 6, entre corchetes el rango con ℓ = 3 y 12)

| Tipo | Contraste | A − B | media D_k (mensual) | IC 95 % (ℓ=6) | ¿Excluye 0? (ℓ = 3/6/12) | mediana | % D>0 |
|---|---|---|---|---|---|---|---|
| Emparejado (0.90, 0.01) | (i) G1 vs nominal | G1 − Nom(0.90) | +0.00079 | [+0.00013, +0.00169] | sí / sí / sí | ≈0 | 52.4 % |
| | (ii) G2 vs G1 | G2 − G1 | −0.00038 | [−0.00118, +0.00038] | no / no / no | ≈0 | 50.0 % |
| | (iii) G2 vs nominal | G2 − Nom(0.90) | +0.00041 | [−0.00021, +0.00110] | no / no / no | ≈0 | 52.4 % |
| Emparejado (0.80, 0.01) | (i) G1 vs nominal | G1 − Nom(0.80) | +0.00020 | [−0.00081, +0.00111] | no / no / no | ≈0 | 59.5 % |
| | (ii) G2 vs G1 | G2 − G1 | +0.00059 | [−0.00035, +0.00170] | no / no / no | ≈0 | 52.4 % |
| | (iii) G2 vs nominal | G2 − Nom(0.80) | +0.00079 | [−0.00035, +0.00209] | no / no / no | ≈0 | 66.7 % |
| Seleccionado | (i) G1* vs nominal | = emparejado (0.90) (i) | +0.00079 | [+0.00013, +0.00169] | sí / sí / sí | ≈0 | 52.4 % |
| | (ii) G2* vs G1* | G2(0.80) − G1(0.90) | −0.00038 | [−0.00205, +0.00127] | no / no / no | −0.00061 | 42.9 % |
| | (iii) G2* vs nominal | = emparejado (0.80) (iii) | +0.00079 | [−0.00035, +0.00209] | no / no / no | ≈0 | 66.7 % |

En los contrastes seleccionados, el nominal se toma con el mismo δ que la estrategia WK. Por eso los contrastes (i) y (iii) seleccionados coinciden con los emparejados; solo (ii) es distinto.

**Lectura descriptiva (sin concluir):**
- Solo el contraste **G1 (0.90, 0.01) − nominal (0.90)** tiene un intervalo que excluye el cero, y lo hace con las tres longitudes de bloque. Su límite inferior está cerca de 0: +1.3e-4 con ℓ = 6 y +6.7e-5 con ℓ = 12.
- Los otros 6 contrastes distintos contienen el cero con ℓ = 3, 6 y 12. Según la metodología, eso es «ausencia de evidencia suficiente de una diferencia media», no equivalencia.
- **El contraste central, G2 vs G1, contiene el cero** tanto emparejado (en las dos configuraciones, con signos opuestos) como seleccionado.
- La sensibilidad a ℓ es pequeña: ningún contraste cambia de conclusión entre ℓ = 3, 6 y 12.

**Advertencias para el texto:**
1. **Cobertura real < 95 %** con T = 84 (≈0.90 con ℓ = 6, según la simulación). El intervalo que excluye el cero lo hace con un margen pequeño.
2. **Comparaciones múltiples:** son 7 contrastes distintos × 3 longitudes de bloque, sin ajuste. Si los 7 contrastes no tuvieran diferencia real, sería esperable que alguno excluyera el cero por azar.
3. La configuración G1 (0.90, 0.01) ya se había evaluado en prueba antes de T9 (la regla de T9 la volvió a elegir). El resultado de (i) no es la primera mirada a ese tramo.
4. Las medianas ≈0 reflejan muchos meses casi idénticos (|D_k| < 1e-6 en 6–19 de los 84 meses; columna `meses_empate_1e6`). La «proporción de meses con D_k > 0» incluye esos empates numéricos del lado negativo.

## Para la metodología (C30/C34, l. 323–327)
- Procedimiento implementado tal como lo describe el texto (ℓ = 6, B = 10 000, percentiles 2.5–97.5, pares alineados). La sensibilidad con ℓ = 3 y ℓ = 12 está hecha. El `[PENDIENTE]` se puede retirar.
- Dato sugerido para el texto: semilla 20261019; cobertura simulada ≈0.90 con T = 84 (AR(1), φ = 0.3).

## Archivos
- Código nuevo: `bootstrap_block_diff.m`, `test_bootstrap_block_diff.m`, `main_bootstrap_contrasts.m`.
- Resultados: `results_bootstrap/test_simulado.csv`, `results_bootstrap/tabla_bootstrap_contrastes.csv`.
- No se modificó código existente ni se sobrescribieron resultados.
