# Verificación cruzada R5 (generada por `results_finales/r5_verificacion_cruzada.m`)

Detalle en `verificacion_cruzada.csv`. Tolerancia relativa 1e-12 salvo donde se exige igualdad exacta (C y F: 0).

| Bloque | Qué verifica | Comprobaciones | Fallidas |
|---|---|---:|---:|
| A | riqueza final | 26 | 0 |
| B | suma de D_k = log(W_A/W_B) | 21 | 0 |
| C | G2: primeros 48 meses = validación | 10 | 0 |
| D | conteos de meses | 31 | 0 |
| E | la selección solo usa validación | 65 | 0 |
| F | G1 truncado a dic-2018 (sin mirar el futuro) | 5 | 0 |

Total: 158 comprobaciones, 0 fallidas. Bloque F: 48 optimizaciones en 20.4 s (no se guardan).
