# Tareas pendientes — fase de resultados

Cómo usarlo: abre Claude Code en la carpeta del proyecto, activa el modo plan (Shift+Tab) y pega SOLO una tarea a la vez. Cada una termina con un criterio de "terminado". Texto de referencia: `metodologia_6.tex` y `main_6.tex` (las versiones `_1` y `_2` están obsoletas; no hay `_7`). Después de cada tarea, pídele un reporte corto con rutas de archivos y cifras clave; me lo traes y actualizo el texto.

---

## 0. Qué ya está hecho (no repetir)

| Tarea | Resultado | Dónde |
|---|---|---|
| T1 Auditoría de datos | hecha | `data/audit/audit_report.md` |
| T2 Métricas alineadas con el texto | hecha | `compute_metrics.m`, `results_validacion_metricas_v2/` |
| T3 Estado del solucionador | hecha | `results_estado_solver/` |
| T4 Malla de validación de G2 | hecha | `wdro-market/results_validacion_grid_market/` |
| T5 Verificaciones con tolerancia | hechas | `results_verificaciones/` |
| T6 Bootstrap móvil por bloques | hecho | `results_bootstrap/` |
| T7 Desglose por régimen | hecho | `results_regimen/` |
| T8 Condición inicial de la prueba | confirmada (sin cambios de código) | `RESUMEN_PARA_METODOLOGIA.md` |
| T9 Selección de (δ, η) y prueba v2 | hecha | `results_seleccion/`, `results_prueba_v2/` |
| T10 Resumen para la metodología | hecho | `RESUMEN_PARA_METODOLOGIA.md` |

Configuraciones fijadas: G1 → (δ, η) = (0.90, 0.01); G2 → (0.80, 0.01). Pesos de G2 fijos en (0.70, 0.15, 0.15). Prueba: 84 meses realizados (ene-2019 a dic-2025).

## 1. Decisiones tuyas antes de empezar

- **D1. Cierre de diciembre de 2025: DECIDIDO, se corrige.** Hoy el último cierre usado es el del 30-dic (la descarga trató `end` como exclusivo). Se parametrizan los scripts (R0) y se regenera todo de punta a punta con el cierre del 31-dic (R1). Mi lectura, que R0 verifica: las decisiones llegan hasta nov-2025, así que dic-2025 solo entra en el último retorno *realizado*; por eso la validación y la selección de T9 no deberían cambiar.
- **D2. Conteo de «meses con transacción».** El turnover incluye compras y ventas simultáneas pequeñas del punto interior (máx. 5e-4 en un mes; ≤ 0.09 % del turnover). Opciones: dejar TO como está, o contar con Σ|x−h| > 1e-8. Solo afecta ese conteo.

## 2. Reglas de esta fase (añádelas a `CLAUDE.md`)

- No se elige ni se ajusta ningún parámetro con resultados de prueba. No hay mallas nuevas ni se refina η por debajo de 0.01.
- Ninguna cifra de tablas o figuras se escribe a mano: cada una sale de un script que lee los CSV/.mat existentes.
- Todo va en `results_finales/` (nueva); no se sobrescribe ningún resultado anterior ni `data/raw/`.
- Los resultados de prueba son descriptivos. Sin intervalo del bootstrap no se afirma superioridad.
- Tablas en `.tex` insertables con `\input`, con `\hline` (el documento no carga `booktabs`); figuras en PDF y PNG.

---

## R0. Congelar el estado y parametrizar los scripts (sin descargar ni correr mallas)
1. Commit de todo lo pendiente en una rama nueva y etiqueta `base-dic30` (línea base con el cierre del 30-dic).
2. Inventario, con archivo y línea, de lo que depende de la fecha final: `END_DATE` de `01_import_data.py` (yfinance trata `end` como exclusivo), fechas escritas a mano (`2025-12-30`, `TEST_END`, `T`, número de meses, `decision_idx`) en Python, MATLAB y `data/audit/`, y rutas fijas a `data/raw/`, `monthly_panel.csv` y carpetas `results_*`. Verificar (no asumir) si el MATLAB necesita cambios de lógica o solo de rutas.
3. Cambios mínimos y compatibles hacia atrás: fecha final, carpeta de datos crudos, ruta del panel y carpeta raíz de resultados pasan a ser parámetros con valores por defecto IGUALES a los actuales. Incluye los scripts nuevos de T2–T9. Explicar cada cambio antes de hacerlo; nada de `data/raw/` ni de resultados existentes se sobrescribe.
4. Comprobación de que no cambió nada: con los parámetros por defecto, una corrida corta (G1, δ=0.90, η=0.01, primeros 12 meses) reproduce exactamente la trayectoria guardada.
5. `results_finales/MANIFIESTO.md`: orden de ejecución de los scripts, versiones (MATLAB R2026a, CVX 2.2 build 1148, MOSEK 9.1.9, Python y paquetes), SHA-256 de `data/raw/` y de `monthly_panel.csv`, semillas y la ruta de cada resultado. Commit y etiqueta `scripts-parametrizados`.
6. Estimar (sin ejecutar) el tiempo de repetir todo de punta a punta con los datos nuevos.
Terminado cuando: existan las dos etiquetas, el manifiesto, la lista del inventario, la confirmación del paso 4 y la estimación de tiempo.

## R1. Regenerar todo con el cierre del 31-dic-2025 (después de aprobar el tiempo de R0)
1. Descarga con `end=2026-01-01` en una carpeta NUEVA (`data/raw_<fecha>/`) y reconstruye el panel en una ruta nueva.
2. Compara los retornos mensuales de ene-2010 a nov-2025 con la descarga anterior. Si alguno difiere más de 1e-8, detente y repórtalo (puede ser reescalado de Adj Close).
3. Vuelve a correr, con la raíz de resultados nueva (`results_v2/`): mallas de G1 y G2, G2 en 132 meses para las configuraciones elegidas, prueba, bootstrap y régimen. Antes de lanzar cada corrida larga, una prueba corta y su tiempo estimado.
4. Compara con los resultados anteriores: hasta nov-2025 los factores realizados deben coincidir (tolerancia 1e-6) y la selección de T9 no debe cambiar. Si algo de eso falla, detente y repórtalo.
5. No reemplaces nada sin mi aprobación.
Terminado cuando: haya una tabla antes/después de la riqueza final de las estrategias de prueba, la confirmación de que solo cambió el último mes, y la lista de frases de la metodología a actualizar (sección de Datos y limitaciones).

## R2. Tablas de desempeño
Genera `results_finales/tablas/*.tex` desde `results_prueba_v2/metricas_por_tramo.csv` y las tablas maestras de validación:
- (a) Prueba, estrategias evaluadas: riqueza final, crecimiento logarítmico medio, CAGR, MDD, peor mes, VaR y CVaR al 95 %, Sharpe, Sortino, Calmar.
- (b) Prueba: turnover acumulado, meses con transacción, costo fraccional y monetario, peso máximo, N_eff y proporción en riesgo.
- (c) Prueba: incumplimientos de δ, mínimo factor de crecimiento, meses con la cota δ activa, meses sin optimización.
- (d) Validación: las dos configuraciones elegidas y el nominal, con las mismas métricas.
Terminado cuando: las tablas compilen en `main_6.tex` sin tocar los números a mano y cada columna coincida con el CSV.

## R3. Figuras
Genera en `results_finales/figuras/`, con colores fijos por estrategia y etiquetas en español:
- Riqueza de la prueba (re-basada a 1) y drawdown de todas las estrategias evaluadas.
- Proporción en riesgo y N_eff en el tiempo (G1, G2 y nominal).
- Turnover y costo acumulados.
- Mapas de calor de validación para G1 y G2: riqueza, CVaR, Sharpe, costo monetario, proporción en riesgo, meses con la cota δ activa y fracción de meses con solución óptima (renombra «Factibilidad WDRO» a «fracción de meses con solución óptima»).
- Riqueza de validación frente a η, por δ y geometría.
- Exposición riesgosa frente al tiempo con η ∈ {0, 0.10, 0.15, 0.30} (diagnóstico de las trayectorias planas).
- Serie de D_k del contraste central.

Terminado cuando: cada figura tenga el script que la genera y se lea en blanco y negro. Haz los titulos lo mas conciso que se pueda.

## R4. Inferencia y régimen en LaTeX
Con `results_bootstrap/tabla_bootstrap_contrastes.csv` y `results_regimen/desglose_regimen.csv`:
- Tabla de los siete contrastes × ℓ ∈ {3, 6, 12}: media, IC 95 %, mediana, % de D_k > 0 y empates numéricos, y un gráfico de intervalos.
- Tablas del desglose por régimen: siete contrastes × cinco grupos, y el cruce 2×2 del contraste central.
Terminado cuando: coincidan con los CSV y con el tamaño de grupos (48/36, 28/56; 23/25/5/31).

## R5. Verificación cruzada de cifras
Script que comprueba: la riqueza final de cada tabla coincide con `metricas_por_tramo.csv`; para cada contraste Σ D_k = log(W_A/W_B); los primeros 48 meses de G2 coinciden con la validación guardada; los conteos de meses suman 48 y 84; `select_parameters.m` no lee nada de 2019–2025.
Terminado cuando: el script corra sin fallos y deje `results_finales/verificacion_cruzada.csv`.

## R6. Índice de resultados
Escribe `results_finales/RESULTADOS.md`: lista de tablas y figuras con su archivo, su script y qué muestra cada una en una frase neutra; y una lista de lo que los resultados SÍ y NO permiten afirmar (sin interpretar). Esto me sirve para escribir la sección de Resultados sin inventar nada.
Terminado cuando: cada cifra citada en el índice tenga su archivo fuente.

## R7. Mantenimiento de código (baja prioridad)
- Corrige los comentarios de `extract_period_results.m:13-17` y `main_validation_grid.m:5-8` (recortar NO equivale a correr por separado con portafolio heredado y costos).
- Añade la columna «fracción de meses con solución óptima» y conserva `fraccion_factible` por trazabilidad.
- Aplica D2 si decidiste cambiar el conteo.
- Actualiza `CLAUDE.md`: referencias a `metodologia_6.tex`, la regla de selección de T9, y reemplaza «la prueba se usó una sola vez» por lo que dice la limitación del texto.
Terminado cuando: no queden comentarios que contradigan la metodología.

---

## 3. Decidido que NO se hace
Sensibilidad o calibración de los pesos ω; backtest de prueba desde efectivo en 2019; comparación del objetivo en el peor caso con un η común; refinar η entre 0 y 0.01; mallas nuevas de cualquier tipo.

## 4. Pendientes que solo puede resolver el autor
- Dirección del repositorio con código y datos.
- Fecha de consulta de CVX y MOSEK en las referencias.
- Revisión manual de las 4 discrepancias de precios sin explicar (AAPL sep y oct de 2015; VIX ago y sep de 2014); Stooq está bloqueado en el entorno de Claude Code, pero tu código de Jupyter sí puede contrastarlas.
- Quitar o reemplazar el `[PENDIENTE (opcional)]` de los pesos alternativos (C15).

R2 a R6 leen los resultados de `results_v2/` una vez aprobada R1.

## Orden sugerido
R0 → R1 → R2, R3 y R4 → R5 → R6 → R7.
