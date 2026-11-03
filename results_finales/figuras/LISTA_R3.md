# Figuras R3 (generadas por `results_finales/r3_figuras.m`)

Cada figura está en PDF (vectorial) y PNG. Fuente: `results_v2/`. † = configuración elegida en validación (T9).

| Archivo | Fuente | Qué muestra |
|---|---|---|
| `riqueza_prueba.pdf/.png` | trayectorias (cargar_trayectorias.m) recortadas a 2019-2025 | Riqueza re-basada a 1 al inicio de la prueba de las seis estrategias evaluadas. |
| `drawdown_prueba.pdf/.png` | trayectorias recortadas a 2019-2025 | Caída porcentual desde el máximo previo de la riqueza (eje invertido), seis estrategias. |
| `riesgo_neff_prueba.pdf/.png` | trayectorias recortadas a 2019-2025 | Proporción invertida en activos riesgosos y número efectivo de activos riesgosos por mes (N_eff = 0 sin exposición). |
| `turnover_costo_prueba.pdf/.png` | trayectorias recortadas a 2019-2025 | Turnover acumulado y costo monetario acumulado (suma de W_k tau TO_k / W_0) de las seis estrategias. |
| `mapa_riqueza.pdf/.png` | tabla_maestra_metricas_validacion.csv (G1 y G2) | Validación 2015-2018, malla delta x eta: Riqueza final; recuadro = configuración elegida (T9). |
| `mapa_cvar.pdf/.png` | tabla_maestra_metricas_validacion.csv (G1 y G2) | Validación 2015-2018, malla delta x eta: CVaR 95 %; recuadro = configuración elegida (T9). |
| `mapa_sharpe.pdf/.png` | tabla_maestra_metricas_validacion.csv (G1 y G2) | Validación 2015-2018, malla delta x eta: Sharpe; recuadro = configuración elegida (T9). |
| `mapa_costo.pdf/.png` | tabla_maestra_metricas_validacion.csv (G1 y G2) | Validación 2015-2018, malla delta x eta: Costo monetario; recuadro = configuración elegida (T9). |
| `mapa_riesgo.pdf/.png` | tabla_maestra_metricas_validacion.csv (G1 y G2) | Validación 2015-2018, malla delta x eta: Proporción en riesgo; recuadro = configuración elegida (T9). |
| `mapa_cota_activa.pdf/.png` | tabla_maestra_metricas_validacion.csv (G1 y G2) y diagnostico_cota_delta.csv | Validación 2015-2018, malla delta x eta: Meses con la cota delta activa; recuadro = configuración elegida (T9). |
| `mapa_optima.pdf/.png` | tabla_maestra_metricas_validacion.csv (G1 y G2) | Validación 2015-2018, malla delta x eta: Fracción de meses con solución óptima; recuadro = configuración elegida (T9). |
| `riqueza_vs_eta_validacion.pdf/.png` | results_seleccion/riqueza_vs_eta.csv | Riqueza final de validación frente a eta (espaciado categórico), una línea por delta, para cada geometría. |
| `exposicion_eta_alto.pdf/.png` | results_estado_solver/diagnostico_eta_alto.csv | Proporción en riesgo de G1 con delta = 0.90 y eta en {0, 0.10, 0.15, 0.30}, 132 decisiones (diagnóstico de trayectorias planas). |
| `dk_contraste_principal.pdf/.png` | trayectorias recortadas a 2019-2025; contrastes_prueba.csv | Diferencia mensual de crecimiento logarítmico D_k (en puntos porcentuales) de los contrastes 1 y 2 (G2 frente a G1 con los mismos parámetros). |

## Verificación

61 comprobaciones, 0 fallidas (detalle en `r3_verificacion.csv`).
