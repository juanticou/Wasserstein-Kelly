# Análisis de resultados y discusión — documento de trabajo

Documento interno (5-nov-2026) para redactar las secciones de **Resultados** y **Discusión** de `main_6.tex`. No se inserta en el manuscrito. Cada cifra lleva su archivo de origen; ante cualquier diferencia mandan los CSV. Notación: c1 = (δ, η) = (0.90, 0.01), elegida para G1; c2 = (0.80, 0.01), elegida para G2. Validación: 48 meses (ene-2015 a dic-2018); prueba: 84 meses (ene-2019 a dic-2025). D_k = log G^A − log G^B, en % mensual.

Tipos de cifra y su origen:
- **[CSV]**: copiada de un archivo generado por script (R2–R6, `main_*`). Se puede llevar al manuscrito.
- **[Derivada]**: cociente o diferencia simple de dos cifras [CSV] (p. ej., 3.999/3.741 − 1). Antes de llevarla al manuscrito debe salir de un script (`contrastes_prueba.csv` ya trae `riqueza_A_sobre_B_menos_1` para los contrastes).
- Los agregados de tiempos y de probabilidades adversariales salen de `results_finales/r8_tiempos_adversarial.m` (P4, resuelto): tablas `complementarias/tabla_g_tiempos` y `tabla_h_adversarial` (CSV y `.tex`) y figura `complementarias/exceso_spy_negativo`; 205 comprobaciones, 0 fallidas. Son [CSV].

---

## 0. ¿Se puede empezar a escribir?

**Sí.** No falta ninguna ejecución para redactar Resultados y Discusión: las seis estrategias, la malla de validación de ambas geometrías, el bootstrap, el desglose por régimen, las referencias, las pruebas de verificación, los tiempos y las probabilidades adversariales ya están en `results_v2/` con sus comprobaciones (R2 360/360, R3 77/77, R4 529/529, R5 158, pruebas 21.4 153/153, probabilidades adversariales 5820/5820).

Lo que queda pendiente **no bloquea la redacción**, pero conviene decidirlo antes de cerrar el texto:

| # | Pendiente | Tipo | Recomendación |
|---|---|---|---|
| P1 | Reportar en prueba η = 0.05, 0.15, 0.30 | Decisión (autor/director) | **No.** Choca con «no hay mallas nuevas» y con la prohibición de mirar la prueba para parámetros. El efecto de η grande ya está documentado en validación (η ≥ 0.30 ⇒ todo en bajo riesgo, §2.3). |
| P2 | Pasajes `%%% [RESULTADO]` de `metodologia_6.tex` | Decisión de redacción | Mover a Resultados los que son resultados de la estrategia (selección, «el nominal ocupaba los primeros puestos», «los primeros 48 meses coinciden», empates); dejar en Metodología, como descripción de los datos, los de la auditoría del panel. |
| P3 | Contrastes D_k frente a las referencias | Decisión | No calcularlos. Las referencias se implementaron después de ver la prueba; quedan como descriptivas, como ya dice el texto. |
| P4 | Tiempos y probabilidades adversariales como tabla/figura | **Resuelto** (5-nov-2026) | `r8_tiempos_adversarial.m` → `results_finales/complementarias/` (tablas G y H, figura `exceso_spy_negativo`). No se añadió a `r6_resultados.m` ni a `RESULTADOS.md` (decisión del autor). |
| P5 | Compilar los `.tex` de R2 y R4 | Entorno | No hay LaTeX en el equipo; compilar en Overleaf o instalar MiKTeX. |
| P6 | Pendientes del autor | Autor | Dirección del repositorio; `[PENDIENTE (opcional)]` de los pesos alternativos (C15); marcas `REVISAR` (GICS, C15, C17, C18). |
| P7 | Cobertura del bootstrap por debajo del 95 % | Redacción | Ya está medida (§2.5); debe declararse en Resultados o Limitaciones, porque matiza el único IC exploratorio que excluye el 0. |

---

## 1. Hallazgos principales en una página

1. **La geometría informada por el mercado (G2) no produce una diferencia detectable frente a la geometría de solo retornos (G1).** Con parámetros emparejados, los dos contrastes principales tienen media de D_k de signo opuesto (−0.038 % con c1; +0.059 % con c2) e IC 95 % que contienen el 0 con ℓ = 3, 6 y 12. Es un resultado nulo, no evidencia de igualdad.
2. **La robustez efectiva está concentrada en η muy pequeño.** En validación, cualquier η > 0 reduce la riqueza frente al nominal (η = 0.01 cuesta entre 1.1 % y 1.7 %); con η ≥ 0.30 ambas geometrías se van a bajo riesgo y la riqueza queda en 1.032, la del activo de bajo riesgo. La regla de selección, condicionada a η > 0, elige el η mínimo en ambas geometrías.
3. **En prueba, la relación con el nominal se invierte de forma descriptiva:** las cuatro estrategias Wasserstein–Kelly terminan con más riqueza que el nominal del mismo δ, operan menos (turnover 9–19 % menor) y pagan menos costo. Solo un contraste exploratorio (G1(c1) − Nom(0.90)) tiene IC que excluye el 0, y no sobrevive a la lectura conjunta de multiplicidad y cobertura subnominal del bootstrap.
4. **Los costos pesan más sobre el turnover que la robustez:** quitar τ casi duplica el turnover del nominal (8.73 → 15.30 con δ = 0.80), mientras que η = 0.01 lo reduce en torno a 1–1.7 unidades. La ventaja en riqueza de G1(c1) sobre el nominal es mucho mayor que el costo que ahorra.
5. **La implementación es numéricamente estable y verificada:** 0 meses sin optimización en todas las celdas, η = 0 reproduce exactamente al nominal, primal y dual coinciden, y cada problema mensual tarda ≈ 0.12 s.
6. **Las Kelly son carteras concentradas y casi totalmente invertidas** (N_eff ≈ 4.3–4.7 de 10; peso máximo en la cota x̄ = 0.25; ≈ 99.99 % en riesgo). La igual ponderación, sin optimizar, tiene riqueza de prueba comparable (3.734), menor caída (15.9 %) y mayor Sharpe (1.162), de forma descriptiva.

---

## 2. Resultados detallados

### 2.1 Estabilidad numérica y verificación (objetivos 2 y 5)

- **Meses sin optimización: 0** en las seis estrategias y los dos tramos [CSV: `results_v2/results_prueba_v2/metricas_por_tramo.csv`, `meses_sin_optimizacion`]; en toda la malla de validación de G1 y G2 la fracción de meses con solución óptima es 1.00 [CSV: `tabla_maestra_validacion_G*.csv`, `fraccion_factible`] y en la malla completa de 132 meses de G1 no hay `inaccurate`, certificados de infactibilidad ni fallos numéricos [CSV: `results_v2/results_estado_solver/tabla_meses_sin_optimizacion.csv`]. Coherente con el hecho teórico de que con δ ≤ 0.90 el problema siempre es factible: no hubo que registrar fallos de software.
- **Equivalencia con η = 0:** para los seis δ, en 132 meses, `max_dG = 0`, `max_dx = 0`, `dW_final = 0` [CSV: `results_v2/results_verificaciones/equivalencia_eta0_backtest.csv`]. En las tres instancias fijas (dic-2014, dic-2018, jun-2022) los objetivos de nominal, G1 y G2 coinciden exactamente y la solución es única [CSV: `equivalencia_eta0_instancias.csv`].
- **Restricciones:** 132 celdas (geometría × δ × η) correctas; residuo de balance ≤ 1.9e-10, sin violaciones de cotas ni de δ dentro de la ventana [CSV: `verificacion_restricciones.csv`].
- **Pruebas de la sec. 21.4:** 153/153 [CSV: `results_v2/results_pruebas_21_4/pruebas_21_4.csv`]: (A) el óptimo de CVX coincide con la búsqueda exhaustiva en una instancia sintética 3×6 (diferencia 1.1e-7, 176 851 puntos factibles); (B) primal y dual del LP adversarial coinciden (≤ 1.6e-9), MOSEK y SDPT3 coinciden (≤ 5.6e-9) y la p recuperada suma 1 y agota el presupuesto ρ; (C) el valor robusto es no creciente en ρ (p. ej., instancia sintética: 0.01432 con η = 0 → 0.01274 con η = 0.03) [CSV: `monotonia_optimo.csv`].
- **MOSEK nativo:** el aviso de aproximación sucesiva de CVX es genérico; el log muestra una sola llamada a MOSEK 9.1.9 con conos exponenciales (RESULTADOS.md §4).
- **Tiempos** [CSV: `results_finales/complementarias/tabla_g_tiempos.csv`, a partir de `results_v2/results_tiempos/`]: en prueba, mediana por mes de 0.122–0.124 s para G1 y G2 y 0.090 s para el nominal; máximo 0.323 s (G2 (0.90, 0.01)); 0 meses no óptimos. La matriz de costos y el radio se construyen en 0.45–0.58 ms (prueba). Los 792 problemas re-resueltos reproducen ρ_k y x_k guardados. El costo computacional de la robustez es ≈ +35 % por problema [Derivada], irrelevante a escala mensual.
- **Bootstrap:** cobertura empírica del IC 95 % con AR(1) de φ = 0.3 y T = 84: 0.90 (ℓ = 3), 0.90 (ℓ = 6), 0.864 (ℓ = 12); la media no tiene sesgo (0.0020001 vs. 0.002) [CSV: `results_v2/results_bootstrap/test_simulado.csv`]. **Los IC son algo más estrechos de lo nominal**, lo que hace más conservadora la lectura de cualquier IC que excluya el 0.

**Lectura:** la cadena de verificación permite atribuir las diferencias entre estrategias al modelo y no a fallos del solucionador. Esto cumple la parte de «validar el modelo» del objetivo 2 y la de «estabilidad numérica» del objetivo 5.

### 2.2 Validación y selección de parámetros

- **Selección (T9)** [CSV: `results_v2/results_seleccion/sensibilidad_seleccion.csv`]:
  - G1 → (0.90, 0.01), riqueza 2.331, puesto 1 de las celdas con η > 0. Queda **en el borde de la malla** en ambas dimensiones (`borde_delta = 1`, `borde_eta = 1`): el máximo δ permitido y el mínimo η > 0. La elección no cambia con TOL × 10 ni TOL / 10, y coincide con la de mejor Sharpe.
  - G2 → (0.80, 0.01), riqueza 2.342, puesto 3 en riqueza, elegida por la regla de empate (brecha relativa 1.1e-4 < TOL = 5e-4). **Es frágil frente a la tolerancia:** TOL × 10 → (0.90, 0.01); TOL / 10 → (0.75, 0.01); 5 celdas quedan dentro de la tolerancia. La mejor celda en Sharpe es (0.70, 0.01). En G2 el δ es casi indiferente.
  - Si η = 0 fuera elegible, ambas geometrías elegirían el nominal (0.90, 0) con 2.367: es la razón documentada de la exclusión de η = 0.
- **Costo de la robustez en validación** [CSV: `results_v2/results_seleccion/riqueza_vs_eta.csv`, `perdida_rel_vs_eta0`]: con η = 0.01 la riqueza cae −1.52 % (G1, δ = 0.90) y −1.06 % (G2, δ = 0.80); con η = 0.10, −28.4 % y −24.2 %; con η = 0.15, −33.7 % y −31.6 %. La caída es casi monótona en η (la excepción η = 0.04 → 0.05 en G1 es pequeña: 2.069 → 2.094). Con δ = 0.90 y η ∈ {0.02, 0.04, 0.05, 0.10, 0.15}, G2 pierde menos riqueza que G1 con el mismo η (p. ej., η = 0.10: 1.793 vs. 1.694); con η = 0.03 quedan prácticamente iguales (2.184 vs. 2.186).
- **Colapso a bajo riesgo:** con η ≥ 0.30 la riqueza de validación está entre 1.0318 y 1.0320 en las dos geometrías y todos los δ [RESULTADOS.md §2.10], igual a la del activo de bajo riesgo (1.032) [CSV: `tabla_f_validacion_referencias.csv`]. La exposición riesgosa de G1 (δ = 0.90) con η = 0.30 es ≈ 3e-7 en dic-2014 [CSV: `results_v2/results_estado_solver/diagnostico_eta_alto.csv`]; figura `exposicion_eta_alto`. Hay un umbral entre η = 0.15 y η = 0.30 a partir del cual el adversario hace inviable cualquier posición riesgosa.
- **Sensibilidad a δ:** diferencia relativa máxima de riqueza entre δ con η fijo = 0.458 % en G1 y 0.081 % en G2 [RESULTADOS.md §2.10]. En validación δ casi no importa: la cota δ solo está activa en alguna celda con δ = 0.90 [CSV: `diagnostico_cota_delta.csv`], y el nominal con δ = 0.80 y con δ = 0.90 tiene la misma riqueza (2.367).
- **Ruido numérico entre celdas equivalentes:** hasta 4.3e-4 de diferencia relativa en riqueza [CSV: `ruido_celdas_equivalentes.csv`], que justifica TOL = 5e-4.

**Lectura:** el paisaje de validación es casi plano en δ y fuertemente decreciente en η. La «mejor configuración robusta» es, en ambas geometrías, la menos robusta posible dentro de la malla. Esto responde el objetivo 5 (sensibilidad) y condiciona todo lo demás: lo que se evalúa en prueba es una perturbación pequeña del nominal.

### 2.3 Prueba: desempeño (objetivos 3 y 4)

Tabla (a) [CSV: `results_finales/tablas/tabla_a_prueba_desempeno.csv`]:

| | Nom (0.80) | Nom (0.90) | G1 (0.80) | G1 (0.90) † | G2 (0.80) † | G2 (0.90) |
|---|---:|---:|---:|---:|---:|---:|
| Riqueza final | 3.625 | 3.741 | 3.686 | 3.999 | 3.873 | 3.873 |
| CAGR | 20.20 % | 20.74 % | 20.48 % | 21.90 % | 21.34 % | 21.34 % |
| MDD | 26.39 % | 26.79 % | 27.04 % | 25.54 % | 26.38 % | 26.42 % |
| CVaR 95 % | 10.55 % | 10.04 % | 10.05 % | 9.77 % | 10.32 % | 9.80 % |
| Sharpe | 0.891 | 0.947 | 0.917 | 1.002 | 0.952 | 0.981 |

(η = 0.01 en todas las WK; † elegida en validación.)

- Las cuatro WK superan en riqueza final al nominal del mismo δ: +1.7 % (G1, 0.80), +6.9 % (G1, 0.90), +6.8 % (G2, 0.80), +3.5 % (G2, 0.90) [Derivada; los contrastes 4–7 están en `contrastes_prueba.csv`, `riqueza_A_sobre_B_menos_1`]. Es una sola trayectoria por estrategia: no es un orden con incertidumbre.
- **Inversión validación → prueba:** en validación el nominal gana a todas las WK; en prueba ocurre lo contrario. Con un único periodo no se puede saber si es un efecto sistemático (p. ej., la robustez ayuda en un periodo con más volatilidad, 2020 y 2022) o variabilidad de una trayectoria.
- **Riesgo:** las diferencias en MDD (25.5–27.0 %), peor mes (−11.1 a −12.1 %) y CVaR (9.8–10.6 %) son de 1–2 puntos. El CVaR al 95 % descansa en ≈ 4.2 meses de cola: no es una estimación precisa.
- **δ en prueba:** a diferencia de validación, δ = 0.90 se asocia a más riqueza en G1 (3.999 vs. 3.686) y en el nominal (3.741 vs. 3.625), y la cota está activa en 60–66 de 84 meses [CSV: `r2_cota_delta.csv`]. En G2 los dos δ terminan con la misma riqueza (3.873) por trayectorias distintas (CVaR 10.32 % vs. 9.80 %).

### 2.4 Prueba: operación, concentración y restricciones

Tablas (b) y (c) [CSV: `tabla_b_prueba_operacion.csv`, `tabla_c_prueba_restricciones.csv`]:

- **Turnover acumulado:** Nominal 8.73 / 7.60 frente a WK 7.92, 7.05 (δ = 0.80) y 6.59, 6.77 (δ = 0.90). Reducción frente al nominal del mismo δ: entre −9 % (G1, 0.80) y −19 % (G2, 0.80) [Derivada]. Costo monetario acumulado (W_0 = 1): 0.0216/0.0180 (nominal) frente a 0.0159–0.0192 (WK).
- **El ahorro de costos no explica la diferencia de riqueza:** G1(c1) ahorra 0.0180 − 0.0159 = 0.0021 de costo frente al Nom(0.90) [Derivada], frente a una diferencia de riqueza final de 0.258. Aunque el ahorro se capitaliza, es de otro orden: la diferencia viene de asignaciones distintas, no del costo pagado.
- **Concentración:** peso máximo medio ≈ 25 % (la cota x̄ = 0.25 activa casi siempre), N_eff medio 4.25–4.71 y proporción en riesgo ≈ 99.99 %. Las WK son algo menos concentradas que el nominal (N_eff 4.39–4.71 vs. 4.25–4.63), coherente con que el adversario castiga apuestas concentradas.
- **Supervivencia fuera de muestra:** con δ = 0.90, 2 meses de prueba con factor realizado < δ en nominal, G1 y G2 (mínimos 0.8859, 0.8886, 0.8865); con δ = 0.80, ninguno (mínimo 0.8787). La cota δ protege solo frente a los escenarios de la ventana (limitación ya declarada); la robustez con η = 0.01 no evitó esas violaciones.
- **Meses con transacción:** 84/84 en todas; el conteo incluye las compras y ventas simultáneas pequeñas del punto interior (D2 de TAREAS_PENDIENTES; no se aplicó otro umbral).

### 2.5 Contraste principal: G2 frente a G1 con parámetros emparejados (pregunta de investigación)

[CSV: `results_finales/inferencia/tabla_r4a_bootstrap.csv`; figuras `dk_contraste_principal`, `ic_contrastes`]

| N.º | Contraste | Media D_k | Mediana | % D_k > 0 | Empates | IC 95 % (ℓ = 6) |
|---|---|---:|---:|---:|---:|---:|
| 1 | G2(c1) − G1(c1) | −0.038 % | 0.000 | 50.0 | 6 | [−0.118, 0.038] |
| 2 | G2(c2) − G1(c2) | +0.059 % | 0.000 | 52.4 | 16 | [−0.035, 0.170] |

- Ningún IC excluye el 0 con ℓ = 3, 6 o 12. **Los signos se contradicen entre c1 y c2**: con δ = 0.90 G2 queda por debajo de G1 (riqueza 3.873 vs. 3.999, −3.2 %), con δ = 0.80 por encima (3.873 vs. 3.686, +5.1 %) [Derivada].
- Mediana 0 y muchos empates (|D_k| < 1e-6 en 6 y 16 meses): en buena parte de los meses ambas geometrías eligen esencialmente el mismo portafolio. Las diferencias se concentran en pocos meses (max |D_k| = 1.9 pp en el contraste 1, `contrastes_prueba.csv`).
- **Magnitud:** el ancho del IC (≈ 0.16–0.20 pp/mes) es de un orden comparable a 1–2 % de riqueza al año; el estudio no tiene potencia para detectar diferencias de ese tamaño con 84 meses, y la cobertura subnominal (§2.1) indica que los IC reales serían algo más anchos.
- **Respuesta a la pregunta de investigación:** con este universo, periodo, costos y la configuración η = 0.01, incorporar el retorno de SPY y el VIX en la geometría de transporte **no cambia de forma detectable** el crecimiento logarítmico frente a la geometría de solo retornos, y las diferencias descriptivas en pérdidas, concentración y costos son pequeñas y de signo no consistente entre δ (p. ej., turnover: G2 < G1 con δ = 0.80, G2 > G1 con δ = 0.90).

### 2.6 Contrastes exploratorios (3 a 7)

[CSV: `tabla_r4a_bootstrap.csv`]

- 3: G2(c2) − G1(c1), entre estrategias calibradas: −0.038 %, IC [−0.205, 0.127]. No identifica el efecto de la geometría (cambian δ y la geometría).
- 4: **G1(c1) − Nom(0.90): +0.079 %, IC ℓ = 6 [0.014, 0.169]; excluye el 0 con ℓ = 3, 6 y 12.** Es el único. Con siete IC sin ajuste, cobertura empírica ≈ 0.90 y un límite inferior cercano a 0, no se afirma superioridad; se reporta como indicio exploratorio. Además, c1 está en el borde de la malla y la configuración de G1 ya se había evaluado en prueba antes de T9 (limitación del texto).
- 5: G2(c1) − Nom(0.90): +0.041 %, IC [−0.021, 0.110].
- 6: G1(c2) − Nom(0.80): +0.020 %, IC [−0.081, 0.111].
- 7: G2(c2) − Nom(0.80): +0.079 %, IC [−0.035, 0.209]; 66.7 % de meses con D_k > 0 (el más alto de los siete).
- **Patrón:** los cuatro contrastes WK − nominal (4–7) tienen media positiva (0.020 a 0.079 %), aunque solo uno con IC que excluye el 0. Es descriptivamente coherente con que η pequeño no perjudicó en prueba, pero no es evidencia de mejora.

### 2.7 Desglose por régimen (descriptivo)

[CSV: `results_finales/inferencia/tabla_r4b_regimen.csv`, `tabla_r4c_cruce.csv`; grupos 48/36 (VIX alto/bajo) y 28/56 (SPY_k < 0 / ≥ 0); cruce 23/25/5/31]

- **Contraste 2 (c2):** G2 por encima de G1 en VIX alto (+0.125 %, 66.7 % D > 0) y SPY_k < 0 (+0.128 %, 64.3 %); por debajo en VIX bajo (−0.029 %, 33.3 %). Es el patrón que motivaría G2: ayudar en estados de estrés.
- **Contraste 1 (c1):** el patrón no se repite: G2 por debajo en VIX alto (−0.058 %) y sobre todo con SPY_k < 0 (−0.152 %).
- Cruce 2×2: la celda «VIX bajo y SPY < 0» tiene n = 5.
- **Lectura:** no hay un patrón por régimen estable entre los dos δ; sin IC por grupo, el desglose solo sirve para describir dónde se concentran las diferencias.

### 2.8 Cómo repondera el adversario cada geometría (mecanismo)

[CSV: `results_finales/complementarias/tabla_h_adversarial.csv` (r8), a partir de `results_v2/results_probabilidades_adversariales/resumen_por_fecha.csv`; figura `complementarias/exceso_spy_negativo`. Caso «común» = mismo portafolio (nominal del mismo δ) para G1 y G2, que aísla la geometría. Masa movida = ½ Σ|p − 1/N|; exceso de masa en VIX alto = Σ_{VIX alto} p − fracción de esos escenarios; «fechas con exceso > 0» usa el umbral 1e-8. El presupuesto ρ se agota en todas las fechas (costo/ρ = 1 con tolerancia 1e-6).]

| Caso común, prueba (84 fechas) | c1 G1 | c1 G2 | c2 G1 | c2 G2 |
|---|---:|---:|---:|---:|
| Masa movida (%) | 1.10 | 1.32 | 0.97 | 1.33 |
| N efectivo de escenarios (de 60) | 59.1 | 58.8 | 59.3 | 58.8 |
| Masa del peor escenario (%; 1/N = 1.67) | 1.81 | 1.72 | 1.93 | 1.83 |
| Exceso de masa, VIX alto (pp) | 0.13 | −0.02 | 0.13 | 0.09 |
| Fechas con exceso > 0, VIX alto (%) | 33.3 | 6.0 | 29.8 | 11.9 |
| Exceso de masa, SPY < 0 (pp) | 0.65 | 0.39 | 0.89 | 0.42 |
| Fechas con exceso > 0, SPY < 0 (%) | 73.8 | 40.5 | 94.0 | 50.0 |

- **La perturbación adversarial con η = 0.01 es pequeña:** mueve 1–1.5 % de la masa y el N efectivo de escenarios sigue ≈ 59 de 60, aunque el presupuesto ρ se agota siempre. Esto explica que las WK elegidas se parezcan tanto al nominal y que haya tantos empates.
- **Contraintuitivo e importante para la discusión:** la geometría que «conoce» el estado del mercado (G2) **traslada menos** masa hacia escenarios de VIX alto y de SPY negativo que G1. Una explicación coherente con la construcción de c (hipótesis, no comprobada): en G2 mover masa entre meses con estados de mercado distintos es más caro, de modo que el adversario redistribuye sobre todo entre meses de estado parecido; en G1 el costo solo mira retornos de las acciones y el adversario puede llevar masa a los meses malos, que suelen coincidir con SPY < 0. Es decir, G2 no hace al adversario más pesimista sobre los estados de estrés, sino que lo restringe a perturbaciones «dentro del régimen».
- El mismo patrón aparece con c2, con el portafolio propio y en validación. En validación, caso común, G1 traslada masa extra a SPY < 0 en el 89.6 % de las fechas y G2 en el 2.1 %; el exceso medio es de 1.30 pp frente a 0.02 pp (`TABLAS_R8.md`).
- La figura `exceso_spy_negativo` muestra que la diferencia no es uniforme: en validación G2 casi nunca traslada masa a SPY < 0; en prueba ambas geometrías se acercan en 2019–2020 y desde 2023 hay tramos en que coinciden o G2 supera a G1.

### 2.9 Costos frente a robustez

[CSV: `tabla_b`, `tabla_e`; figura `turnover_con_sin_costos_prueba`]

- Turnover del nominal: 15.30 (sin costos) → 8.73 (τ = 0.001), con δ = 0.80; 14.99 → 7.60 con δ = 0.90. **Los costos reducen el turnover a casi la mitad**; η = 0.01 lo reduce después en otras 0.8–1.7 unidades.
- Riqueza: nominal sin costos 3.743/3.755 frente a nominal con costos 3.625/3.741. G1(c1) con costos (3.999) y G2 (3.873) terminan por encima del nominal **sin** costos, de forma descriptiva: la diferencia de las WK no se explica por costos.
- Conclusión descriptiva: en este diseño el término de costos es el principal regulador de la rotación, y la robustez añade una regularización adicional menor.

### 2.10 Estrategias de referencia (descriptivas, posteriores a la prueba)

[CSV: `tabla_e_prueba_referencias.csv`, `tabla_f_validacion_referencias.csv`; figura `riqueza_referencias_prueba`]

| Prueba | Bajo riesgo | Igual pond. | SPY pasivo | G1(c1) | G2(c2) |
|---|---:|---:|---:|---:|---:|
| Riqueza | 1.206 | 3.734 | 3.034 | 3.999 | 3.873 |
| MDD | 0 % | 15.91 % | 23.93 % | 25.54 % | 26.38 % |
| Sharpe | — | 1.162 | 0.883 | 1.002 | 0.952 |
| Turnover | 0 | 3.56 | 0 | 6.59 | 7.05 |

- Todas las Kelly superan a SPY pasivo y al bajo riesgo en riqueza; la igual ponderación logra una riqueza similar al nominal (3.734) con caída mucho menor y mejor Sharpe y Calmar.
- En validación las Kelly (≈ 2.33–2.37) superan con claridad a la igual ponderación (1.682) y a SPY (1.316): la ventaja del enfoque Kelly sobre la diversificación ingenua depende del periodo.
- Sin contrastes ni IC frente a las referencias: no se afirma que ninguna estrategia las supere.

---

## 3. Discusión (ideas para redactar)

1. **Resultado principal nulo, y por qué es informativo.** Con parámetros emparejados la geometría no cambia el crecimiento de forma detectable. Es un resultado negativo válido para la pregunta de investigación: anclar el transporte al estado del mercado no aporta una mejora sistemática bajo este protocolo. No debe presentarse como «G2 es igual a G1»: el estudio no tiene potencia para diferencias de ≈ 1 % anual.
2. **El mecanismo de por qué la geometría importa poco.** La validación empuja a η = 0.01, donde el adversario solo mueve ≈ 1 % de la masa (§2.8): con una perturbación tan pequeña, la forma de la bola apenas cambia la decisión, lo que se refleja en las medianas de D_k iguales a 0 y en los empates. Con η grandes, donde la geometría sí cambiaría el resultado (en validación G2 pierde menos que G1 con η = 0.10–0.15), el costo en crecimiento es tan alto que la regla de selección los descarta. Hay, entonces, una tensión estructural: **la geometría solo tiene margen para importar en la región de η que el criterio de crecimiento penaliza.**
3. **G2 no hace al adversario más pesimista en los estados de estrés.** Al encarecer el transporte entre estados de mercado distintos, G2 limita al adversario a perturbaciones dentro del régimen; G1 deja moverse masa hacia los meses de SPY negativo. Esto matiza la motivación económica de la introducción: añadir VIX y SPY a c no equivale a «estresar más» los escenarios de crisis, sino a cambiar qué perturbaciones son baratas. Es una observación de mecanismo útil para trabajos futuros (p. ej., costos asimétricos o pesos ω distintos), y se presenta como hipótesis coherente con los datos, no como resultado probado.
4. **Robustez frente al nominal: costo en validación, indicio favorable en prueba.** En validación toda robustez cuesta crecimiento; en prueba las WK quedan por encima del nominal en riqueza, turnover y costo, con un solo IC exploratorio que excluye el 0. Lecturas compatibles: (i) variabilidad de una sola trayectoria; (ii) la regularización por robustez ayuda más en un periodo con más volatilidad (2020, 2022). Con los datos disponibles no se puede distinguir entre ellas, y la inversión de signo entre tramos es en sí misma una advertencia contra elegir parámetros con un solo periodo.
5. **El papel de los costos.** Los costos de transacción regularizan la rotación mucho más que la robustez (turnover casi a la mitad). Para la literatura que estudia WDRO-Kelly sin costos (Sun y Zou, 2025; Li, 2023), esto sugiere que parte de la estabilidad que se atribuye a la robustez puede obtenerse con un término de costos, y que la comparación justa es con costos.
6. **Supervivencia δ.** La cota es una garantía dentro de la ventana; fuera de muestra hubo 2 meses por debajo de 0.90 con δ = 0.90, también con robustez. La protección que ofrece η = 0.01 no se extiende a los escenarios no observados (soporte finito de la bola: el adversario no crea escenarios nuevos).
7. **Concentración y diversificación ingenua.** Las Kelly están en la cota x̄ y concentradas en ≈ 4–5 activos; la igual ponderación tuvo en prueba riqueza parecida con menos caída. Es coherente con la literatura conocida sobre la dificultad de vencer a 1/N fuera de muestra, pero el trabajo no lo contrasta formalmente; no citar sin la referencia adecuada (pendiente de bibliografía si se quiere mencionar).
8. **Limitaciones que afectan la lectura de los resultados** (todas ya están en `sec:limit`): universo fijo con sesgo de supervivencia; una trayectoria; uso previo de la prueba; regla fijada tras ver la validación y elección de G1 en el borde de la malla; elección de G2 frágil frente a TOL; pesos ω fijos y VIX solo en nivel; referencias posteriores a la prueba; cobertura del bootstrap ≈ 90 %; CVaR con ≈ 4 meses de cola; siete IC sin ajuste.
9. **Trabajo futuro** (sin resultados): otros pesos ω (sin usar la prueba), Δlog VIX, costos asimétricos en la geometría, Kelly fraccionario, otros τ, otros universos y periodos, y un esquema de validación con varias ventanas (p. ej., validación cruzada temporal) para reducir la dependencia de un solo tramo.

---

## 4. Cumplimiento de los objetivos (`main_6.tex`, sec. Objetivos)

| Objetivo | Evidencia | Estado |
|---|---|---|
| **General:** evaluar el efecto de incorporar SPY y VIX en la geometría, con el nominal como referencia, en crecimiento, pérdidas, concentración y costos | §2.3–2.6 y §2.9; contrastes 1–2 con IC; tablas (a)–(c) | **Cumplido.** Respuesta: sin efecto detectable en crecimiento; diferencias pequeñas y de signo no consistente en pérdidas, concentración y costos. |
| **1. Establecer** el desempeño de referencia del Kelly nominal con costos y restricciones | Nominal (0.80) y (0.90) en validación y prueba, tablas (a)–(d); además nominal sin costos (tabla e) | **Cumplido**, ampliado con el nominal sin costos y tres referencias externas. |
| **2. Formular y validar** WK con dos geometrías y la equivalencia con η = 0 | Formulación en Metodología; equivalencia exacta (dG = dx = dW = 0, 6 δ × 132 meses); pruebas 21.4 (153/153); primal–dual; MOSEK nativo | **Cumplido.** |
| **3. Evaluar** fuera de muestra 2019–2025 con parámetros controlados | Seis estrategias congeladas, sin re-selección; contraste emparejado que fija (δ, η) | **Cumplido**, con la salvedad declarada del uso previo de la prueba y de que la selección fue condicionada a η > 0. |
| **4. Comparar** en crecimiento, pérdidas, concentración y costos y cuantificar la incertidumbre de D_k | Tablas (a)–(c), bootstrap con ℓ = 3, 6, 12, régimen, cobertura simulada | **Cumplido.** La incertidumbre se cuantificó y resulta grande frente a los efectos. |
| **5. Analizar** la sensibilidad del desempeño y la estabilidad numérica frente a η y δ | Mapas δ × η (7 métricas), riqueza vs. η, colapso con η ≥ 0.30, sensibilidad de la regla a TOL, 0 meses sin optimización, tiempos | **Cumplido.** Hallazgo: fuerte sensibilidad a η, casi nula a δ en validación; estabilidad numérica total. |

**Qué aporta el trabajo según la delimitación de la contribución:** una comparación controlada bajo el mismo protocolo, cuya conclusión es que, con costos y la selección por crecimiento, la geometría informada por el mercado no aporta valor detectable; más un mecanismo (§2.8) que explica por qué.

---

## 5. Estructura propuesta para el manuscrito

**Resultados**
1. Estabilidad numérica y verificación — §2.1. Texto + tabla G (`complementarias/tabla_g_tiempos.tex`).
2. Validación y selección — §2.2. Figuras `mapa_riqueza`, `riqueza_vs_eta_validacion`, `exposicion_eta_alto`; tabla (d); sensibilidad de la regla (desde `sensibilidad_seleccion.csv`, hoy sin .tex).
3. Prueba: desempeño y operación — §2.3–2.4. Tablas (a), (b), (c); figuras `riqueza_prueba`, `drawdown_prueba`, `riesgo_neff_prueba`, `turnover_costo_prueba`.
4. Contraste principal — §2.5. Tabla R4a (filas 1–2), figuras `dk_contraste_principal`, `ic_contrastes`.
5. Contrastes exploratorios y régimen — §2.6–2.7. Tablas R4a (3–7), R4b, R4c.
6. Costos frente a robustez y referencias — §2.9–2.10. Tablas (e), (f); figuras `riqueza_referencias_prueba`, `turnover_con_sin_costos_prueba`.
7. Mecanismo adversarial — §2.8. Tabla H (`complementarias/tabla_h_adversarial.tex`) y figura `complementarias/exceso_spy_negativo`.

**Discusión** — §3, cerrando con la tabla de objetivos (§4) en prosa.

**Reglas de redacción a respetar:** prueba descriptiva salvo IC; no hablar de «superioridad»; el contraste 3 no se usa para la geometría; siempre «fracción de meses con solución óptima», no «factibilidad»; no mencionar el documento guía del director.

---

## 6. Lo que los resultados NO permiten afirmar (recordatorio)

Ver `RESULTADOS.md` §3. Resumen: que una geometría supere a la otra; superioridad global de alguna estrategia (el IC del contraste 4 es exploratorio); un orden a partir de la riqueza final; efecto de la geometría con el contraste 3; superioridad frente a las referencias; estimaciones precisas de VaR/CVaR; diferencias entre regímenes; que el δ de G2 sea mejor que otros; generalización fuera de esta muestra; y, añadido aquí, que G2 «estrese» más los estados de crisis (la §2.8 indica lo contrario, y la explicación del mecanismo es una hipótesis).
