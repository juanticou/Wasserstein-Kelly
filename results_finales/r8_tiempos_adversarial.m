function r8_tiempos_adversarial(OUT)
% R8_TIEMPOS_ADVERSARIAL  Tablas de tiempos de solucion y de indicadores de
% la distribucion adversarial, y una figura del exceso de masa adversarial
% en meses con SPY < 0. Solo lee CSV de results_v2/ (main_tiempos_solucion.m
% y main_probabilidades_adversariales.m); no optimiza, no usa CVX y no
% elige parametros. Ninguna cifra se escribe a mano.
%
%   A  tiempos: seis estrategias x {validacion, prueba}
%   B  adversarial: {c1, c2} x {comun, propio} x {G1, G2} x {validacion, prueba}
%   C  figura: exceso de masa en SPY < 0, caso comun, 132 fechas
%
% Uso: r8_tiempos_adversarial()      -> results_finales/complementarias/
%      r8_tiempos_adversarial(out)   -> otra carpeta (prueba)
% Aborta si la carpeta de salida ya tiene archivos.
%
% Salidas: tabla_g_tiempos.csv/.tex, tabla_h_adversarial.csv/.tex,
% exceso_spy_negativo.pdf/.png, r8_verificacion.csv y TABLAS_R8.md

    here = fileparts(mfilename('fullpath'));
    root = fileparts(here);
    RES = fullfile(root, 'results_v2');
    if nargin < 1, OUT = fullfile(here, 'complementarias'); end
    if isfolder(OUT)
        d = dir(OUT);
        assert(all(ismember({d.name}, {'.', '..'})), 'r8: la carpeta de salida %s ya tiene archivos.', OUT);
    else
        mkdir(OUT);
    end

    STRAT = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.80, 0.01)", "G1 (0.90, 0.01)", "G2 (0.80, 0.01)", "G2 (0.90, 0.01)"];
    TRAMOS = ["validacion", "prueba"];
    NT = struct('validacion', 48, 'prueba', 84);
    CONF = ["c1 (0.90, 0.01)", "c2 (0.80, 0.01)"];
    CASOS = ["comun", "propio"];
    GEOS = ["G1", "G2"];
    N_ESC = 60;                         % ventana movil
    TH = 1e-8;                          % exceso > TH cuenta como positivo (tolerancia |sum p - 1| del LP)
    TEST_FIRST_DECISION = datetime(2018, 12, 31);   % decision dic-2018 -> retorno ene-2019
    chk = {};

    F.TM = 'results_v2/results_tiempos/tiempos_por_mes.csv';
    F.TR = 'results_v2/results_tiempos/tiempos_resumen.csv';
    F.EN = 'results_v2/results_tiempos/entorno_tiempos.csv';
    F.PA = 'results_v2/results_probabilidades_adversariales/resumen_por_fecha.csv';
    F.PV = 'results_v2/results_probabilidades_adversariales/verificaciones.csv';

    %% A. Tiempos
    TM = readtable(fullfile(root, F.TM), 'TextType', 'string');
    TR = readtable(fullfile(root, F.TR), 'TextType', 'string');
    EN = readtable(fullfile(root, F.EN), 'TextType', 'string');
    chk{end + 1} = check_row("tiempos: 792 meses", 0, 792, height(TM));
    chk{end + 1} = check_row("tiempos: ok_x en todos los meses", 0, 1, double(all(TM.ok_x == 1)));
    chk{end + 1} = check_row("tiempos: ok_rho en todos los meses", 0, 1, double(all(TM.ok_rho == 1)));
    chk{end + 1} = check_row("tiempos: todos los estados Solved", 0, 1, double(all(TM.estado == "Solved")));

    A = table();
    for s = 1:numel(STRAT)
        for t = 1:numel(TRAMOS)
            x = TM(TM.estrategia == STRAT(s) & TM.tramo == TRAMOS(t), :);
            r = table(STRAT(s), TRAMOS(t), height(x), median(x.segundos_solucion), mean(x.segundos_solucion), ...
                max(x.segundos_solucion), mean(x.segundos_C_rho), sum(x.estado ~= "Solved"), ...
                'VariableNames', {'estrategia', 'tramo', 'n_meses', 'mediana_s', 'media_s', 'max_s', ...
                'media_C_rho_s', 'n_no_solved'});
            A = [A; r]; %#ok<AGROW>
            id = sprintf('%s %s', STRAT(s), TRAMOS(t));
            chk{end + 1} = check_row("tiempos: n meses " + id, s, NT.(TRAMOS(t)), height(x)); %#ok<AGROW>
            g = TR(TR.estrategia == STRAT(s) & TR.tramo == TRAMOS(t), :);
            chk{end + 1} = check_row("tiempos: fila unica en tiempos_resumen " + id, s, 1, height(g)); %#ok<AGROW>
            chk{end + 1} = check_row("tiempos: n vs resumen " + id, s, g.GroupCount, r.n_meses); %#ok<AGROW>
            chk{end + 1} = check_row("tiempos: media vs resumen " + id, s, g.mean_segundos_solucion, r.media_s); %#ok<AGROW>
            chk{end + 1} = check_row("tiempos: mediana vs resumen " + id, s, g.median_segundos_solucion, r.mediana_s); %#ok<AGROW>
            chk{end + 1} = check_row("tiempos: max vs resumen " + id, s, g.max_segundos_solucion, r.max_s); %#ok<AGROW>
            chk{end + 1} = check_row("tiempos: C_rho vs resumen " + id, s, g.media_segundos_C_rho, r.media_C_rho_s); %#ok<AGROW>
            chk{end + 1} = check_row("tiempos: no Solved vs resumen " + id, s, g.n_estado_no_solved, r.n_no_solved); %#ok<AGROW>
        end
    end
    writetable(A, fullfile(OUT, 'tabla_g_tiempos.csv'));

    env = sprintf('MATLAB %s, %s, %s, %d núcleos', extractBetween(EN.matlab(1), "(", ")"), EN.cvx(1), EN.mosek(1), EN.nucleos(1));
    tex = tex_head(['Tiempo de solución por mes (segundos) de cada problema mensual, re-resuelto con el portafolio heredado guardado ', ...
        '(modelado en CVX y solución con MOSEK). $C_k$ y $\rho_k$: construcción de la matriz de costos y del radio (milisegundos, prueba). ', ...
        'Una medición por mes; ', env, '.'], 'tab:tiempos', '|l|r|r|r|r|r|r|r|');
    tex(end + 1) = " & \multicolumn{3}{c|}{\textbf{Prueba (84)}} & \multicolumn{2}{c|}{\textbf{Validación (48)}} & & \\ \cline{2-6}";
    tex(end + 1) = "\textbf{Estrategia} & \textbf{Mediana} & \textbf{Media} & \textbf{Máx.} & \textbf{Mediana} & \textbf{Máx.} & \textbf{$C_k$, $\rho_k$ (ms)} & \textbf{No óptimos} \\ \hline";
    md = ["# Tablas R8 (generadas por `results_finales/r8_tiempos_adversarial.m`)", "", ...
          "Solo lee CSV; no optimiza ni elige parámetros. Fuentes: `" + F.TM + "`, `" + F.TR + "`, `" + F.EN + "`, `" + F.PA + "`, `" + F.PV + "`.", "", ...
          "## G. Tiempos de solución por mes (segundos)", "", "CSV: `tabla_g_tiempos.csv`; .tex: `tabla_g_tiempos.tex`. Entorno: " + env + ".", "", ...
          "| Estrategia | Tramo | n | Mediana | Media | Máx. | C_k y ρ_k (ms) | No óptimos |", "|---|---|---:|---:|---:|---:|---:|---:|"];
    for s = 1:numel(STRAT)
        p = A(A.estrategia == STRAT(s) & A.tramo == "prueba", :);
        v = A(A.estrategia == STRAT(s) & A.tramo == "validacion", :);
        vals = {p.mediana_s, 3; p.media_s, 3; p.max_s, 3; v.mediana_s, 3; v.max_s, 3; 1000 * p.media_C_rho_s, 2};
        cells = strings(1, size(vals, 1));
        for q = 1:size(vals, 1)
            cells(q) = num(vals{q, 1}, vals{q, 2});
            chk{end + 1} = shown_check("tiempos: impreso " + STRAT(s) + " col " + q, s, vals{q, 1}, vals{q, 2}); %#ok<AGROW>
        end
        tex(end + 1) = sprintf('%s & %s & %d \\\\ \\hline', STRAT(s), strjoin(cells, ' & '), p.n_no_solved + v.n_no_solved); %#ok<AGROW>
        for t = 1:numel(TRAMOS)
            r = A(A.estrategia == STRAT(s) & A.tramo == TRAMOS(t), :);
            md(end + 1) = sprintf("| %s | %s | %d | %s | %s | %s | %s | %d |", STRAT(s), TRAMOS(t), r.n_meses, ...
                num(r.mediana_s, 3), num(r.media_s, 3), num(r.max_s, 3), num(1000 * r.media_C_rho_s, 2), r.n_no_solved); %#ok<AGROW>
        end
    end
    write_tex(fullfile(OUT, 'tabla_g_tiempos.tex'), [tex, tex_tail()]);
    md = [md, ""];

    %% B. Indicadores adversariales
    PV = readtable(fullfile(root, F.PV), 'TextType', 'string');
    chk{end + 1} = check_row("adversarial: verificaciones.csv sin fallos", 0, 1, double(all(PV.ok == 1)));
    chk{end + 1} = check_row("adversarial: 5820 verificaciones", 0, 5820, height(PV));
    PA = readtable(fullfile(root, F.PA), 'TextType', 'string');
    if ~isdatetime(PA.fecha_decision)
        PA.fecha_decision = datetime(PA.fecha_decision, 'InputFormat', 'dd-MMM-yyyy', 'Locale', 'en_US');
    end
    PA.tramo = repmat("validacion", height(PA), 1);
    PA.tramo(PA.fecha_decision >= TEST_FIRST_DECISION) = "prueba";
    chk{end + 1} = check_row("adversarial: masa movida en [0, 1]", 0, 1, double(all(PA.masa_movida >= 0 & PA.masa_movida <= 1)));
    chk{end + 1} = check_row("adversarial: 1 <= N efectivo <= N", 0, 1, ...
        double(all(PA.n_efectivo_escenarios >= 1 - 1e-9 & PA.n_efectivo_escenarios <= N_ESC + 1e-9)));
    chk{end + 1} = check_row("adversarial: costo usado / rho = 1", 0, 1, max(abs(PA.costo_usado_sobre_rho - 1)) + 1, 1e-6);

    B = table();
    for c = 1:numel(CONF)
        for k = 1:numel(CASOS)
            for g = 1:numel(GEOS)
                sel = PA.configuracion == CONF(c) & PA.caso == CASOS(k) & PA.geometria == GEOS(g);
                id = sprintf('%s %s %s', CONF(c), CASOS(k), GEOS(g));
                chk{end + 1} = check_row("adversarial: 132 fechas " + id, c, 132, nnz(sel)); %#ok<AGROW>
                chk{end + 1} = check_row("adversarial: fechas unicas " + id, c, nnz(sel), numel(unique(PA.fecha_decision(sel)))); %#ok<AGROW>
                for t = 1:numel(TRAMOS)
                    x = PA(sel & PA.tramo == TRAMOS(t), :);
                    chk{end + 1} = check_row("adversarial: n " + id + " " + TRAMOS(t), c, NT.(TRAMOS(t)), height(x)); %#ok<AGROW>
                    r = table(CONF(c), CASOS(k), GEOS(g), TRAMOS(t), height(x), mean(x.rho), mean(x.masa_movida), ...
                        mean(x.n_efectivo_escenarios), mean(x.exceso_masa_vix_alto), mean(x.exceso_masa_vix_alto > TH), ...
                        mean(x.exceso_masa_spy_negativo), mean(x.exceso_masa_spy_negativo > TH), mean(x.masa_peor_escenario), ...
                        'VariableNames', {'configuracion', 'caso', 'geometria', 'tramo', 'n_fechas', 'media_rho', ...
                        'media_masa_movida', 'media_n_efectivo', 'media_exceso_vix_alto', 'frac_fechas_exceso_vix_alto_pos', ...
                        'media_exceso_spy_negativo', 'frac_fechas_exceso_spy_negativo_pos', 'media_masa_peor_escenario'});
                    B = [B; r]; %#ok<AGROW>
                end
            end
        end
    end
    writetable(B, fullfile(OUT, 'tabla_h_adversarial.csv'));

    % Filas: {etiqueta tex, etiqueta md, columna, escala, decimales}
    ROWS = {'$\rho_k$ medio',                                        'ρ_k medio',                          'media_rho',                           1,   4
            'Masa movida (\%)',                                       'Masa movida (%)',                    'media_masa_movida',                   100, 2
            'Número efectivo de escenarios (de 60)',                  'N efectivo de escenarios (de 60)',   'media_n_efectivo',                    1,   1
            'Masa del peor escenario (\%; $1/N=1.67$)',               'Masa del peor escenario (%)',        'media_masa_peor_escenario',           100, 2
            'Exceso de masa, VIX alto (pp)',                          'Exceso de masa, VIX alto (pp)',      'media_exceso_vix_alto',               100, 2
            'Fechas con exceso $>0$, VIX alto (\%)',                  'Fechas con exceso > 0, VIX alto (%)', 'frac_fechas_exceso_vix_alto_pos',    100, 1
            'Exceso de masa, $r^{\mathrm{SPY}}<0$ (pp)',              'Exceso de masa, SPY < 0 (pp)',       'media_exceso_spy_negativo',           100, 2
            'Fechas con exceso $>0$, $r^{\mathrm{SPY}}<0$ (\%)',      'Fechas con exceso > 0, SPY < 0 (%)', 'frac_fechas_exceso_spy_negativo_pos', 100, 1};
    tex = tex_head(['Prueba 2019--2025: distribución adversarial $p$ de la bola de Wasserstein frente a un mismo portafolio ', ...
        '(el Kelly nominal con el mismo $\delta$), de modo que solo cambia la geometría. Medias sobre las 84 fechas de decisión. ', ...
        'Masa movida: $\frac12\sum_s|p_s-1/N|$. Exceso de masa: masa adversarial en los meses de la ventana con VIX sobre su mediana ', ...
        '(o con retorno de SPY negativo) menos la fracción de esos meses. Fechas con exceso $>0$: con umbral $10^{-8}$. Descriptivo.'], ...
        'tab:adversarial', '|l|r|r|r|r|');
    tex(end + 1) = " & \multicolumn{2}{c|}{\textbf{$c_1=(0.90,\,0.01)$}} & \multicolumn{2}{c|}{\textbf{$c_2=(0.80,\,0.01)$}} \\ \cline{2-5}";
    tex(end + 1) = "\textbf{Indicador} & \textbf{G1} & \textbf{G2} & \textbf{G1} & \textbf{G2} \\ \hline";
    for q = 1:size(ROWS, 1)
        cells = strings(1, 4); j = 0;
        for c = 1:numel(CONF)
            for g = 1:numel(GEOS)
                j = j + 1;
                r = B(B.configuracion == CONF(c) & B.caso == "comun" & B.geometria == GEOS(g) & B.tramo == "prueba", :);
                v = ROWS{q, 4} * r.(ROWS{q, 3});
                cells(j) = num(v, ROWS{q, 5});
                chk{end + 1} = shown_check("adversarial: impreso " + ROWS{q, 3} + " " + CONF(c) + " " + GEOS(g), c, v, ROWS{q, 5}); %#ok<AGROW>
            end
        end
        tex(end + 1) = sprintf('%s & %s \\\\ \\hline', ROWS{q, 1}, tex_minus(strjoin(cells, ' & '))); %#ok<AGROW>
    end
    write_tex(fullfile(OUT, 'tabla_h_adversarial.tex'), [tex, tex_tail()]);

    md = [md, "## H. Distribución adversarial (medias por fecha de decisión)", "", ...
          "CSV: `tabla_h_adversarial.csv`; .tex: `tabla_h_adversarial.tex` (solo caso común, prueba). " + ...
          "Común = mismo portafolio (nominal del mismo δ) para G1 y G2; propio = portafolio de cada estrategia. " + ...
          "Fechas con exceso > 0: umbral " + string(sprintf('%g', TH)) + ".", ""];
    for k = 1:numel(CASOS)
        for t = 1:numel(TRAMOS)
            md = [md, "### Caso " + CASOS(k) + ", " + TRAMOS(t) + " (n = " + NT.(TRAMOS(t)) + ")", "", ...
                  "| Indicador | c1 G1 | c1 G2 | c2 G1 | c2 G2 |", "|---|---:|---:|---:|---:|"]; %#ok<AGROW>
            for q = 1:size(ROWS, 1)
                cells = strings(1, 4); j = 0;
                for c = 1:numel(CONF)
                    for g = 1:numel(GEOS)
                        j = j + 1;
                        r = B(B.configuracion == CONF(c) & B.caso == CASOS(k) & B.geometria == GEOS(g) & B.tramo == TRAMOS(t), :);
                        cells(j) = num(ROWS{q, 4} * r.(ROWS{q, 3}), ROWS{q, 5});
                    end
                end
                md(end + 1) = "| " + ROWS{q, 2} + " | " + strjoin(cells, ' | ') + " |"; %#ok<AGROW>
            end
            md = [md, ""]; %#ok<AGROW>
        end
    end

    %% C. Figura
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [100, 100, 860, 560]);
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    STY = struct('G1', {{'-', [0 0 0], 'o'}}, 'G2', {{'--', [0.55 0.55 0.55], 's'}});
    for c = 1:numel(CONF)
        ax = nexttile(tl); hold(ax, 'on');
        for g = 1:numel(GEOS)
            x = PA(PA.configuracion == CONF(c) & PA.caso == "comun" & PA.geometria == GEOS(g), :);
            x = sortrows(x, 'fecha_decision');
            st = STY.(GEOS(g));
            plot(ax, x.fecha_decision, 100 * x.exceso_masa_spy_negativo, st{1}, 'Color', st{2}, 'LineWidth', 1.3, ...
                'Marker', st{3}, 'MarkerIndices', 1:12:height(x), 'MarkerSize', 5, 'MarkerFaceColor', 'w', ...
                'DisplayName', GEOS(g));
        end
        yline(ax, 0, 'k-', 'HandleVisibility', 'off');
        ymax = 100 * max(PA.exceso_masa_spy_negativo(PA.caso == "comun"));
        ylim(ax, [-0.1, 1.1 * ymax]);
        xline(ax, TEST_FIRST_DECISION, 'k:', 'inicio de la prueba', 'LineWidth', 1, 'HandleVisibility', 'off', ...
            'LabelVerticalAlignment', 'top', 'FontSize', 9);
        ylabel(ax, 'Exceso de masa (pp)');
        title(ax, strrep(CONF(c), " (", " = ("), 'FontWeight', 'normal');
        grid(ax, 'on'); box(ax, 'on');
        if c == 1, legend(ax, 'Location', 'northeast'); end
    end
    xlabel(tl, 'Fecha de decisión');
    title(tl, 'Masa adversarial extra en meses con SPY < 0 (mismo portafolio)');
    exportgraphics(fig, fullfile(OUT, 'exceso_spy_negativo.pdf'), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(OUT, 'exceso_spy_negativo.png'), 'Resolution', 200);
    close(fig);
    md = [md, "## Figura", "", "`exceso_spy_negativo.pdf/.png`: exceso de masa adversarial (pp) en los meses de la ventana con " + ...
          "retorno de SPY negativo, caso común, 132 fechas de decisión; G1 continua, G2 discontinua; línea punteada = primera decisión de prueba.", ""];

    %% Verificacion
    V = vertcat(chk{:});
    writetable(V, fullfile(OUT, 'r8_verificacion.csv'));
    md = [md, "## Verificación", "", sprintf("%d comprobaciones, %d fallidas (detalle en `r8_verificacion.csv`).", ...
          height(V), sum(~V.ok))];
    writelines(md, fullfile(OUT, 'TABLAS_R8.md'), 'Encoding', 'UTF-8');
    fprintf('R8: %d comprobaciones, %d fallidas. Salidas en %s\n', height(V), sum(~V.ok), OUT);
    if any(~V.ok)
        disp(V(~V.ok, :));
        error('r8_tiempos_adversarial:verificacion', 'Hay comprobaciones fallidas.');
    end
end


function s = num(v, d)
% Numero con d decimales; evita "-0.000"
    s = string(sprintf('%.*f', d, v));
    if str2double(s) == 0, s = string(sprintf('%.*f', d, 0)); end
end


function T = shown_check(chequeo, id, v, d)
% El texto impreso, releido, coincide con el valor redondeado
    T = check_row(chequeo, id, round(v, d) + 0, str2double(num(v, d)));
end


function t = tex_head(caption, label, cols)
    t = ["% Generado por results_finales/r8_tiempos_adversarial.m; no editar a mano.", ...
         "\begin{table}[h]", "\centering", "\footnotesize", "\setlength{\tabcolsep}{4pt}", ...
         "\caption{" + string(caption) + "}\label{" + string(label) + "}", ...
         "\begin{tabular}{" + string(cols) + "}", "\hline"];
end


function t = tex_tail()
    t = ["\end{tabular}", "\end{table}"];
end


function write_tex(path, lines)
    writelines(lines, path, 'Encoding', 'UTF-8');
end


function T = check_row(chequeo, id, esperado, obtenido, tol)
    if nargin < 5, tol = 1e-12; end
    ok = isequal(esperado, obtenido) || abs(esperado - obtenido) <= tol * max(1, abs(esperado));
    T = table(string(chequeo), id, esperado, obtenido, abs(esperado - obtenido), ok, ...
        'VariableNames', {'chequeo', 'id', 'esperado', 'obtenido', 'dif_abs', 'ok'});
end


function s = tex_minus(s)
% Signo menos matematico en las cifras negativas de una fila .tex
    s = regexprep(s, '(?<![\w)$])-(?=\d)', '$-$');
end
