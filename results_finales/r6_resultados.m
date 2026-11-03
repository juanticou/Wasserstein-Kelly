function r6_resultados()
% R6_RESULTADOS  R6: indice de resultados (results_finales/RESULTADOS.md).
% Lista tablas y figuras con su archivo, su script y una frase neutra, y
% las afirmaciones que los resultados SI y NO permiten, con cada cifra
% leida de su CSV y citada con su fuente. No interpreta ni optimiza.
% Se detiene si R2-R5 tienen comprobaciones fallidas.

    root = fileparts(fileparts(mfilename('fullpath')));
    here = fileparts(mfilename('fullpath'));
    addpath(root);
    RES = fullfile(root, 'results_v2');
    ELLS = [3, 6, 12];
    ALPHA = 0.95;
    PHI_MIN = 0.95;                                   % main_seleccion_parametros.m

    %% Las verificaciones previas no tienen fallos
    VER = {'tablas/r2_verificacion.csv', 'figuras/r3_verificacion.csv', ...
           'inferencia/r4_verificacion.csv', 'verificacion_cruzada.csv'};
    nchk = 0;
    for v = 1:numel(VER)
        T = readtable(fullfile(here, VER{v}));
        assert(all(T.ok == 1), 'r6_resultados: %s tiene comprobaciones fallidas.', VER{v});
        nchk = nchk + height(T);
    end

    %% Fuentes
    F.M   = 'results_v2/results_prueba_v2/metricas_por_tramo.csv';
    F.A   = 'results_finales/inferencia/tabla_r4a_bootstrap.csv';
    F.RB  = 'results_finales/inferencia/tabla_r4b_regimen.csv';
    F.RC  = 'results_finales/inferencia/tabla_r4c_cruce.csv';
    F.V1  = 'results_v2/results_validacion_metricas_v2/tabla_maestra_validacion_G1.csv';
    F.V2  = 'results_v2/results_validacion_metricas_v2/tabla_maestra_validacion_G2.csv';
    F.CD  = 'results_finales/tablas/r2_cota_delta.csv';
    F.SS  = 'results_v2/results_seleccion/sensibilidad_seleccion.csv';
    F.SEL = 'results_v2/results_seleccion/seleccion_G1.csv y seleccion_G2.csv';
    F.R5  = 'results_finales/verificacion_cruzada.csv';
    rd = @(f) readtable(fullfile(root, f), 'TextType', 'string');
    M = rd(F.M); A = rd(F.A); RB = rd(F.RB); CD = rd(F.CD); SS = rd(F.SS); R5 = rd(F.R5);
    V.G1 = rd(F.V1); V.G2 = rd(F.V2);
    src = @(f, col) " (`" + f + "`, `" + col + "`)";

    ORDER = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.80, 0.01)", "G1 (0.90, 0.01)", ...
             "G2 (0.80, 0.01)", "G2 (0.90, 0.01)"];
    LAB = ["G2(c1) − G1(c1)", "G2(c2) − G1(c2)", "G2(c2) − G1(c1)", "G1(c1) − Nom(0.90)", ...
           "G2(c1) − Nom(0.90)", "G1(c2) − Nom(0.80)", "G2(c2) − Nom(0.80)"];
    m = @(s, tramo, col) M.(col)(M.estrategia == s & M.tramo == tramo);
    pct = @(x, d) string(sprintf('%.*f %%', d, 100 * x));

    %% 1. Indice
    md = ["# Índice de resultados (generado por `results_finales/r6_resultados.m`)", "", ...
          "No editar a mano: se regenera con `r6_resultados`. Todas las cifras salen de los archivos citados entre paréntesis " + ...
          "(archivo y columna). Fuente común: `results_v2/` (aprobado en R1). c1 = (δ, η) = (0.90, 0.01), elegida para G1; " + ...
          "c2 = (0.80, 0.01), elegida para G2 (T9). Prueba: 84 meses realizados (ene-2019 a dic-2025); validación: 48 (ene-2015 a dic-2018).", "", ...
          sprintf("Antes de escribir este índice se comprobó que R2–R5 no tienen fallos (%d comprobaciones en total).", nchk), "", ...
          "## 1. Tablas y figuras", "", "| Archivo | Script | Qué muestra |", "|---|---|---|"];
    IDX = ["tablas/tabla_a_prueba_desempeno.csv", "r2_tablas.m", "Prueba: riqueza final, crecimiento logarítmico medio, CAGR, MDD, peor mes, VaR y CVaR al 95 %, Sharpe, Sortino y Calmar de las seis estrategias."
           "tablas/tabla_b_prueba_operacion.csv", "r2_tablas.m", "Prueba: turnover, meses con transacción, costo fraccional y monetario, peso máximo, N_eff y proporción en riesgo."
           "tablas/tabla_c_prueba_restricciones.csv", "r2_tablas.m", "Prueba: incumplimientos de δ, mínimo factor de crecimiento, meses con la cota δ activa y meses sin optimización."
           "tablas/tabla_d_validacion.csv", "r2_tablas.m", "Validación: las dos configuraciones elegidas y el nominal de cada δ, con las métricas de (a) y (b)."
           "tablas/TABLAS_R2.md", "r2_tablas.m", "Las tablas (a)–(d) en Markdown (sin .tex todavía)."];
    for i = 1:size(IDX, 1)
        md(end + 1) = "| `results_finales/" + IDX(i, 1) + "` | `" + IDX(i, 2) + "` | " + IDX(i, 3) + " |"; %#ok<AGROW>
    end
    L3 = readlines(fullfile(here, 'figuras', 'LISTA_R3.md'), 'EmptyLineRule', 'skip');
    L3 = L3(startsWith(L3, "| `"));
    for i = 1:numel(L3)
        p = strtrim(split(extractBetween(L3(i), 2, strlength(L3(i)) - 1), "|"));
        md(end + 1) = "| `results_finales/figuras/" + erase(p(1), "`") + "` | `r3_figuras.m` | " + p(3) + " |"; %#ok<AGROW>
    end
    IDX = ["inferencia/tabla_r4a_bootstrap.csv/.tex", "Prueba: media, mediana, % D_k > 0, empates e IC 95 % por bootstrap con ℓ ∈ {3, 6, 12} de los siete contrastes."
           "inferencia/tabla_r4b_regimen.csv/.tex", "Prueba: media de D_k y % D_k > 0 por régimen (todos, VIX alto/bajo, SPY_k < 0 / ≥ 0), siete contrastes."
           "inferencia/tabla_r4c_cruce.csv/.tex", "Prueba: cruce 2×2 de VIX y SPY_k para los contrastes principales 1 y 2."
           "inferencia/ic_contrastes.pdf/.png", "Prueba: medias e IC 95 % de los siete contrastes, un marcador por ℓ."];
    for i = 1:size(IDX, 1)
        md(end + 1) = "| `results_finales/" + IDX(i, 1) + "` | `r4_inferencia.m` | " + IDX(i, 2) + " |"; %#ok<AGROW>
    end
    md(end + 1) = "| `results_finales/verificacion_cruzada.csv` | `r5_verificacion_cruzada.m` | Verificación cruzada de cifras, conteos y de que la selección solo usa validación (" + height(R5) + " comprobaciones). |";

    %% 2. Lo que SI permiten afirmar
    md = [md, "", "## 2. Lo que los resultados SÍ permiten afirmar (descriptivo)", ""];
    k = 0;

    w = strings(1, numel(ORDER));
    for i = 1:numel(ORDER), w(i) = ORDER(i) + ": " + sprintf('%.3f', m(ORDER(i), "prueba", 'riqueza_final')); end
    k = k + 1; md(end + 1) = k + ". Riqueza final de prueba (base 1), una trayectoria por estrategia: " + strjoin(w, "; ") + src(F.M, "riqueza_final") + ".";

    w = strings(1, 4); S4 = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.90, 0.01)", "G2 (0.80, 0.01)"];
    for i = 1:4, w(i) = S4(i) + ": " + sprintf('%.3f', m(S4(i), "validacion", 'riqueza_final')); end
    k = k + 1; md(end + 1) = k + ". Riqueza final de validación: " + strjoin(w, "; ") + src(F.M, "riqueza_final") + ".";

    ic = @(c, ell) A(A.n_contraste == c & A.ell == ell, :);
    for c = 1:2
        a = ic(c, 6);
        contains0 = arrayfun(@(e) ic(c, e).IC95_inf <= 0 && ic(c, e).IC95_sup >= 0, ELLS);
        k = k + 1; md(end + 1) = k + ". Contraste principal " + c + " (" + LAB(c) + "): media de D_k = " + pct(a.media_D, 3) + ...
            " mensual, IC 95 % (ℓ = 6) = [" + pct(a.IC95_inf, 3) + ", " + pct(a.IC95_sup, 3) + "]; el IC " + ...
            ifelse(all(contains0), "contiene el 0 con ℓ = 3, 6 y 12", "contiene el 0 con ℓ = " + strjoin(string(ELLS(contains0)), ", ")) + ...
            "; " + pct(a.prop_D_pos, 1) + " de meses con D_k > 0 y " + a.empates_1e6 + " empates (|D_k| < 1e-6)" + src(F.A, "media_D, IC95_inf, IC95_sup, prop_D_pos, empates_1e6") + ".";
    end
    excl = strings(0);
    for c = 3:7
        e = ELLS(arrayfun(@(l) ic(c, l).IC_excluye_cero == 1, ELLS));
        if ~isempty(e)
            a = ic(c, 6);
            excl(end + 1) = sprintf("%d (%s; con ℓ = %s; media %s, IC ℓ = 6 [%s, %s])", c, LAB(c), strjoin(string(e), ", "), ...
                pct(a.media_D, 3), pct(a.IC95_inf, 3), pct(a.IC95_sup, 3)); %#ok<AGROW>
        end
    end
    k = k + 1; k_excl = k;
    md(end + 1) = k + ". Contrastes exploratorios (3 a 7) cuyo IC 95 % excluye el 0: " + ...
        ifelse(isempty(excl), "ninguno", strjoin(excl, "; ")) + src(F.A, "IC_excluye_cero") + ".";

    nso = sum(M.meses_sin_optimizacion);
    fmin = min([V.G1.fraccion_factible; V.G2.fraccion_factible]);
    k = k + 1; md(end + 1) = k + ". Meses sin optimización: " + nso + " en las seis estrategias y los dos tramos" + src(F.M, "meses_sin_optimizacion") + ...
        "; la fracción mínima de meses con solución óptima en las mallas de validación de G1 y G2 es " + sprintf('%.2f', fmin) + src("tabla_maestra_validacion_G*.csv", "fraccion_factible") + ".";

    w = strings(1, numel(ORDER));
    for i = 1:numel(ORDER)
        w(i) = ORDER(i) + ": " + m(ORDER(i), "prueba", 'violaciones_delta') + " (mín. G = " + sprintf('%.4f', m(ORDER(i), "prueba", 'min_factor_crecimiento')) + ")";
    end
    k = k + 1; md(end + 1) = k + ". Meses de prueba con factor realizado menor que δ (fuera de muestra): " + strjoin(w, "; ") + src(F.M, "violaciones_delta, min_factor_crecimiento") + ".";

    w = strings(1, numel(ORDER));
    for i = 1:numel(ORDER)
        w(i) = ORDER(i) + ": " + CD.meses_cota_activa(CD.estrategia == ORDER(i) & CD.tramo == "prueba");
    end
    act = strings(0);
    for g = ["G1", "G2"]
        dd = rd('results_v2/results_seleccion/diagnostico_cota_delta.csv');
        dd = dd(dd.geometria == g & dd.meses_cota_activa > 0, :);
        act(end + 1) = g + ": δ ∈ {" + strjoin(compose('%.2f', unique(dd.delta)), ", ") + "}"; %#ok<AGROW>
    end
    k = k + 1; md(end + 1) = k + ". Meses de prueba con la cota δ activa en la ventana: " + strjoin(w, "; ") + src(F.CD, "meses_cota_activa") + ...
        ". En validación, la cota solo está activa en alguna celda con " + strjoin(act, "; ") + " (`results_v2/results_seleccion/diagnostico_cota_delta.csv`).";

    w = strings(1, 0);
    for dl = [0.80, 0.90]
        nom = sprintf("Nominal (%.2f)", dl);
        for g = ["G1", "G2"]
            s = sprintf("%s (%.2f, 0.01)", g, dl);
            w(end + 1) = sprintf("%s %.2f vs. %s %.2f", s, m(s, "prueba", 'turnover_total'), nom, m(nom, "prueba", 'turnover_total')); %#ok<AGROW>
        end
    end
    k = k + 1; md(end + 1) = k + ". Turnover acumulado de prueba, Wasserstein–Kelly frente al nominal del mismo δ: " + strjoin(w, "; ") + src(F.M, "turnover_total") + ...
        ". Costo monetario acumulado (riqueza inicial = 1): " + strjoin(arrayfun(@(s) s + " " + sprintf('%.4f', m(s, "prueba", 'costo_monetario')), ORDER), "; ") + src(F.M, "costo_monetario") + ".";

    w = strings(1, 0);
    for g = ["G1", "G2"]
        T = V.(g); etas = unique(T.eta); spread = zeros(size(etas));
        for j = 1:numel(etas)
            x = T.riqueza_final(T.eta == etas(j));
            spread(j) = (max(x) - min(x)) / min(x);
        end
        hi = T.riqueza_final(T.eta >= 0.30);
        w(end + 1) = sprintf("%s: diferencia relativa máxima entre δ con η fijo = %s; con η ≥ 0.30 la riqueza está entre %.4f y %.4f", ...
            g, pct(max(spread), 3), min(hi), max(hi)); %#ok<AGROW>
    end
    k = k + 1; md(end + 1) = k + ". Validación, malla δ × η: " + strjoin(w, "; ") + src("tabla_maestra_validacion_G*.csv", "riqueza_final") + ".";

    e5 = R5(R5.bloque == "E", :); f5 = R5(R5.bloque == "F", :);
    k = k + 1; md(end + 1) = k + ". La selección de T9 se reproduce con las tablas de validación, sin leer resultados de 2019–2025, y G1 (0.90, 0.01) " + ...
        "corrido con el panel truncado a dic-2018 reproduce exactamente sus 48 meses: " + nnz(e5.ok) + " de " + height(e5) + " y " + ...
        nnz(f5.ok) + " de " + height(f5) + " comprobaciones correctas" + src(F.R5, "bloque E y F") + ".";

    %% 3. Lo que NO permiten afirmar
    md = [md, "", "## 3. Lo que los resultados NO permiten afirmar", ""];
    k = 0;
    p1 = all(arrayfun(@(c) all(arrayfun(@(e) ic(c, e).IC95_inf <= 0 && ic(c, e).IC95_sup >= 0, ELLS)), 1:2));
    if p1
        k = k + 1; md(end + 1) = k + ". Que una geometría supere a la otra con los mismos parámetros: los IC 95 % de los contrastes principales 1 y 2 contienen el 0 con ℓ = 3, 6 y 12" + src(F.A, "IC95_inf, IC95_sup") + ".";
    else
        k = k + 1; md(end + 1) = k + ". [REVISAR] Algún IC de los contrastes principales excluye el 0; esta afirmación debe redactarse a mano a partir de " + F.A + ".";
    end
    k = k + 1; md(end + 1) = k + ". Superioridad estadística global de alguna estrategia: se calculan siete intervalos sin ajuste por comparaciones múltiples y los contrastes 3 a 7 son exploratorios" + ...
        ifelse(isempty(excl), "", "; los IC que excluyen el 0 (punto " + k_excl + " de la sección 2) pueden deberse a multiplicidad") + " (metodologia_6.tex, sec. «Inferencia sobre las diferencias»).";
    k = k + 1; md(end + 1) = k + ". Un orden entre estrategias a partir de la riqueza final: es una sola trayectoria por estrategia, no una estimación con incertidumbre (metodologia_6.tex).";
    k = k + 1; md(end + 1) = k + ". Un efecto de la geometría a partir del contraste 3 (" + LAB(3) + "): cambian a la vez la geometría y δ (metodologia_6.tex, sec. «Contrastes de la fase de prueba»).";
    k = k + 1; md(end + 1) = k + ". Estimaciones precisas de riesgo extremo con VaR y CVaR: con 84 meses de prueba la cola al 95 % equivale a (1 − 0.95)·84 = " + ...
        sprintf('%.1f', (1 - ALPHA) * 84) + " meses (VaR = L_(⌈0.95·84⌉) = L_(" + ceil(ALPHA * 84) + "); metodologia_6.tex, sec. «Métricas de desempeño»).";
    RC = rd(F.RC);
    k = k + 1; md(end + 1) = k + ". Diferencias entre regímenes: el desglose es descriptivo, sin intervalos por grupo, y el grupo más pequeño tiene n = " + ...
        min([RB.n_meses; RC.n_meses]) + src(F.RC, "n_meses") + ".";
    s2 = SS(SS.geometria == "G2", :);
    alt = s2(ismember(s2.caso, ["TOL x 10", "TOL / 10"]), :);
    g2n = strjoin(arrayfun(@(i) alt.caso(i) + " → (" + sprintf('%.2f, %.2f', alt.delta(i), alt.eta(i)) + ")", 1:height(alt)), "; ");
    TOLr = unique(SS.TOL(SS.caso == "regla (eta>0, TOL)")); sel = select_parameters(V.G2, PHI_MIN, TOLr);
    k = k + 1; md(end + 1) = k + ". Que el δ elegido para G2 sea mejor que otros δ en validación: " + height(sel.tied) + ...
        " celdas quedan dentro de la tolerancia de empate (TOL = " + sprintf('%g', TOLr) + ...
        ") y la elección cambia con la tolerancia: " + g2n + src(F.SS, "caso, delta, eta") + ".";
    k = k + 1; md(end + 1) = k + ". Generalización fuera de la muestra estudiada: diez acciones de EE. UU., un solo periodo de prueba, y la configuración de la geometría 1 ya se había evaluado en prueba antes de T9 (metodologia_6.tex, limitaciones).";

    %% 4. Pendientes
    md = [md, "", "## 4. Pendientes que no salen de estos resultados", "", ...
          "- Las tablas de R2 aún no tienen versión .tex; las de R4 sí, pero no se han compilado en este equipo (no hay LaTeX instalado).", ...
          "- Al correr r5_verificacion_cruzada.m, CVX avisó que los modelos con log se resuelven con su método de aproximación sucesiva; falta confirmar si MOSEK trata el cono exponencial de forma nativa, porque la metodología dice «CVX + MOSEK»."];

    writelines(md, fullfile(here, 'RESULTADOS.md'), 'Encoding', 'UTF-8');
    fprintf('R6: RESULTADOS.md escrito (%d líneas).\n', numel(md));
end


function v = ifelse(c, a, b)
    if c, v = a; else, v = b; end
end
