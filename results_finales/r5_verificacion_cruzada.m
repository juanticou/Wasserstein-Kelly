function r5_verificacion_cruzada()
% R5_VERIFICACION_CRUZADA  R5: verificacion cruzada de las cifras de R2-R4
% contra los resultados de results_v2/. No escribe nada fuera de
% results_finales/. Solo el bloque F optimiza (48 meses de G1, sin guardar).
%
%   A  riqueza final: tablas R2 y trayectorias vs metricas_por_tramo.csv;
%      verificaciones de R2, R3 y R4 sin fallos
%   B  suma de D_k = log(W_A / W_B) en cada contraste
%   C  primeros 48 meses de G2 (132 meses) = malla de validacion guardada
%   D  conteos de meses (48, 84, 132 y grupos de regimen)
%   E  la seleccion (T9) solo usa validacion: revision estatica del codigo,
%      tablas de validacion recalculadas desde los recortes 2015-2018,
%      TOL y seleccion repetidas, malla G2 sin meses posteriores a 2018
%   F  G1 (0.90, 0.01) corrido de nuevo con el panel truncado a dic-2018
%      reproduce sus primeros 48 meses (no mira el futuro)
%
% Salidas: results_finales/verificacion_cruzada.csv y VERIFICACION_R5.md

    root = fileparts(fileparts(mfilename('fullpath')));
    here = fileparts(mfilename('fullpath'));
    addpath(root, fullfile(root, 'wdro-market'), here);
    RES = fullfile(root, 'results_v2');
    PANEL = fullfile(root, 'data', 'processed_2026-01-01', 'monthly_panel_hibrido.csv');

    TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
    PERIODS = {'validacion', datetime(2015,1,1), datetime(2018,12,31), 48; ...
               'prueba',     datetime(2019,1,1), datetime(2025,12,31), 84};
    ORDER = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.80, 0.01)", "G1 (0.90, 0.01)", ...
             "G2 (0.80, 0.01)", "G2 (0.90, 0.01)"];
    CHOSEN = struct('G1', [0.90, 0.01], 'G2', [0.80, 0.01]);   % seleccion de T9
    PHI_MIN = 0.95;                                            % main_seleccion_parametros.m
    DELTA_EQUIV = [0.50, 0.60, 0.70, 0.75, 0.80];              % diagnostico_seleccion.m

    M = readtable(fullfile(RES, 'results_prueba_v2', 'metricas_por_tramo.csv'), 'TextType', 'string');
    data = load_monthly_data(PANEL, TICKERS);
    traj = cargar_trayectorias(RES, data);
    W = @(s, tramo) M.riqueza_final(M.estrategia == s & M.tramo == tramo);
    chk = {};

    %% A. Riqueza final
    for q = 1:size(PERIODS, 1)
        for s = ORDER
            r = extract_period_results(traj(char(s)), PERIODS{q, 2}, PERIODS{q, 3});
            chk{end + 1} = row("A", "riqueza_trayectoria_vs_metricas_" + PERIODS{q, 1}, s, W(s, PERIODS{q, 1}), r.wealth(end)); %#ok<AGROW>
        end
    end
    R2T = {'tabla_a_prueba_desempeno', 'prueba'; 'tabla_d_validacion', 'validacion'};
    for t = 1:size(R2T, 1)
        C = readcell(fullfile(here, 'tablas', [R2T{t, 1} '.csv']));
        i = find(strcmp(C(:, 2), 'riqueza_final'));
        assert(numel(i) == 1, 'Sin fila riqueza_final en %s.', R2T{t, 1});
        for j = 3:size(C, 2)
            s = strtrim(erase(string(C{1, j}), "†"));
            chk{end + 1} = row("A", "riqueza_" + R2T{t, 1} + "_vs_metricas", s, W(s, R2T{t, 2}), C{i, j}); %#ok<AGROW>
        end
    end
    VER = {'R2', fullfile(here, 'tablas', 'r2_verificacion.csv')
           'R3', fullfile(here, 'figuras', 'r3_verificacion.csv')
           'R4', fullfile(here, 'inferencia', 'r4_verificacion.csv')
           'T9', fullfile(RES, 'results_prueba_v2', 'verificacion_G2_reproduce_validacion.csv')};
    for v = 1:size(VER, 1)
        T = readtable(VER{v, 2});
        chk{end + 1} = row("A", "verificacion_previa_sin_fallos", VER{v, 1}, height(T), sum(T.ok == 1)); %#ok<AGROW>
    end

    %% B. Suma de D_k = log(W_A / W_B)
    K = readtable(fullfile(RES, 'results_prueba_v2', 'contrastes_prueba.csv'), 'TextType', 'string');
    for c = 1:height(K)
        tag = K.contraste(c) + ": " + K.A(c) + " - " + K.B(c);
        lw = log(W(K.A(c), "prueba") / W(K.B(c), "prueba"));
        chk{end + 1} = row("B", "suma_D_vs_log_WA_WB", tag, lw, K.suma_D(c)); %#ok<AGROW>
        chk{end + 1} = row("B", "riqueza_A_sobre_B_menos_1_vs_exp_suma_D", tag, exp(K.suma_D(c)) - 1, K.riqueza_A_sobre_B_menos_1(c)); %#ok<AGROW>
    end
    RB = readtable(fullfile(here, 'inferencia', 'tabla_r4b_regimen.csv'), 'TextType', 'string');
    RB = RB(RB.regimen == "todos", :);
    for c = 1:height(RB)
        lw = log(W(RB.A(c), "prueba") / W(RB.B(c), "prueba"));
        chk{end + 1} = row("B", "R4_suma_D_vs_log_WA_WB", "contraste " + RB.n_contraste(c), lw, RB.suma_D(c)); %#ok<AGROW>
    end

    %% C. Primeros 48 meses de G2 = malla de validacion guardada
    S = load(fullfile(RES, 'wdro-market', 'results_validacion_grid_market', 'grid_delta_eta_market_validacion.mat'), 'grid');
    g2val = S.grid;
    for dl = [0.90, 0.80]
        s = sprintf("G2 (%.2f, 0.01)", dl);
        r = traj(char(s));
        rv = g2val.results_wdro{abs(g2val.delta_grid - dl) < 1e-12, abs(g2val.eta_grid - 0.01) < 1e-12};
        n = numel(rv.dates);
        chk{end + 1} = row("C", "G2_n_meses_validacion", s, 48, n); %#ok<AGROW>
        chk{end + 1} = row("C", "G2_mismas_fechas", s, 1, double(isequal(r.dates(1:n), rv.dates))); %#ok<AGROW>
        chk{end + 1} = row("C", "G2_max_abs_dx", s, 0, max(abs([r.x(1:n, :), r.x0(1:n)] - [rv.x, rv.x0]), [], 'all'), 0); %#ok<AGROW>
        chk{end + 1} = row("C", "G2_max_abs_dG", s, 0, max(abs(r.growth_real(1:n) - rv.growth_real)), 0); %#ok<AGROW>
        chk{end + 1} = row("C", "G2_riqueza_mes_48", s, rv.wealth(end), r.wealth(n + 1), 0); %#ok<AGROW>
    end

    %% D. Conteos de meses
    for s = ORDER
        realized = dateshift(traj(char(s)).dates, 'end', 'month', 1);
        nv = sum(realized >= PERIODS{1, 2} & realized <= PERIODS{1, 3});
        np = sum(realized >= PERIODS{2, 2} & realized <= PERIODS{2, 3});
        chk{end + 1} = row("D", "decisiones_totales", s, 132, numel(realized)); %#ok<AGROW>
        chk{end + 1} = row("D", "meses_validacion", s, 48, nv); %#ok<AGROW>
        chk{end + 1} = row("D", "meses_prueba", s, 84, np); %#ok<AGROW>
        chk{end + 1} = row("D", "validacion_mas_prueba_igual_total", s, numel(realized), nv + np); %#ok<AGROW>
    end
    for q = 1:size(PERIODS, 1)
        chk{end + 1} = row("D", "n_meses_metricas_por_tramo", PERIODS{q, 1}, PERIODS{q, 4}, ...
            unique(M.n_meses(M.tramo == PERIODS{q, 1}))); %#ok<AGROW>
    end
    TBt = readtable(fullfile(RES, 'results_bootstrap', 'tabla_bootstrap_contrastes.csv'));
    chk{end + 1} = row("D", "n_meses_bootstrap", "todas las filas", 84, unique(TBt.n_meses)); %#ok<AGROW>
    CL = readtable(fullfile(RES, 'results_regimen', 'clasificacion_meses.csv'));
    vix = CL.VIX_alto == 1; spy = CL.SPY_negativo == 1;
    chk{end + 1} = row("D", "meses_clasificados", "regimen", 84, height(CL)); %#ok<AGROW>
    chk{end + 1} = row("D", "VIX_alto_mas_bajo", "48 + 36", 84, nnz(vix) + nnz(~vix)); %#ok<AGROW>
    chk{end + 1} = row("D", "SPY_neg_mas_noneg", "28 + 56", 84, nnz(spy) + nnz(~spy)); %#ok<AGROW>
    chk{end + 1} = row("D", "cruce_suma", "23 + 25 + 5 + 31", 84, ...
        nnz(vix & spy) + nnz(vix & ~spy) + nnz(~vix & spy) + nnz(~vix & ~spy)); %#ok<AGROW>

    %% E. La seleccion solo usa validacion
    % E1. Revision estatica: lecturas de archivos del codigo de seleccion
    IO = '(load\s*\(|readtable|readmatrix|readcell|readlines|fopen|importdata|textscan|csvread|xlsread|webread|fileread)';
    src = fileread(fullfile(root, 'select_parameters.m'));
    chk{end + 1} = row("E", "select_parameters_sin_lecturas", "select_parameters.m", 0, numel(regexp(src, IO))); %#ok<AGROW>
    src = fileread(fullfile(root, 'main_seleccion_parametros.m'));
    code = strjoin(regexprep(splitlines(string(src)), '(^|\s)%.*$', ''), newline);   % sin comentarios
    reads = regexp(code, ['[^\n]*' IO '[^\n]*'], 'match');
    allowed = ["ruido_celdas_equivalentes.csv", "tabla_maestra_validacion_"];
    bad = reads(~contains(reads, allowed));
    chk{end + 1} = row("E", "main_seleccion_solo_lee_validacion", "main_seleccion_parametros.m: " + numel(reads) + " lecturas", 0, numel(bad)); %#ok<AGROW>
    chk{end + 1} = row("E", "main_seleccion_sin_rutas_de_prueba", "main_seleccion_parametros.m", 0, ...
        numel(regexp(code, 'results_prueba|results_bootstrap|results_regimen|2019|2025|\.mat', 'match'))); %#ok<AGROW>

    % E2. Tablas de validacion recalculadas desde los recortes 2015-2018
    S = load(fullfile(RES, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'), 'grid');
    grids = struct('G1', S.grid, 'G2', g2val);
    VT = struct();
    for g = ["G1", "G2"]
        T = readtable(fullfile(RES, 'results_validacion_metricas_v2', "tabla_maestra_validacion_" + g + ".csv"));
        Tr = build_grid_summary_table(grids.(g), PERIODS{1, 2}, PERIODS{1, 3});
        for col = ["riqueza_final", "fraccion_factible", "n_meses"]
            chk{end + 1} = row("E", "tabla_validacion_recalculada_" + col, g, 0, max(abs(T.(col) - Tr.(col)))); %#ok<AGROW>
        end
        chk{end + 1} = row("E", "tabla_validacion_48_meses", g, 48 * height(T), sum(T.n_meses)); %#ok<AGROW>
        % Tabla de los mapas de R3 = tabla de la seleccion
        T3 = readtable(fullfile(RES, ifelse(g == "G1", 'results_validacion_grid', fullfile('wdro-market', 'results_validacion_grid_market')), ...
            'tabla_maestra_metricas_validacion.csv'));
        chk{end + 1} = row("E", "tabla_R3_igual_tabla_seleccion_riqueza", g, 0, ...
            max(abs(sortrows(T3(:, {'delta', 'eta', 'riqueza_final'})).riqueza_final - sortrows(T(:, {'delta', 'eta', 'riqueza_final'})).riqueza_final))); %#ok<AGROW>
        VT.(g) = T;
        last = max(cellfun(@(r) max(dateshift(r.dates, 'end', 'month', 1)), grids.(g).results_wdro(:)));
        if g == "G2"
            chk{end + 1} = row("E", "malla_G2_ultimo_mes_realizado_yyyymm", g, 201812, year(last) * 100 + month(last)); %#ok<AGROW>
        end
    end

    % E3. TOL y seleccion repetidas
    B = readtable(fullfile(RES, 'results_seleccion', 'ruido_celdas_equivalentes.csv'), 'TextType', 'string');
    for i = 1:height(B)
        T = VT.(B.geometria(i));
        w = T.riqueza_final(abs(T.eta - B.eta(i)) < 1e-12 & ismember(round(T.delta, 2), DELTA_EQUIV));
        tag = B.geometria(i) + sprintf(" eta=%.2f", B.eta(i));
        chk{end + 1} = row("E", "ruido_riqueza_min_desde_validacion", tag, B.riqueza_min(i), min(w)); %#ok<AGROW>
        chk{end + 1} = row("E", "ruido_riqueza_max_desde_validacion", tag, B.riqueza_max(i), max(w)); %#ok<AGROW>
    end
    TOL = round_up_125(max(B.max_dif_rel_riqueza(B.usada_para_ruido == 1)));
    SS = readtable(fullfile(RES, 'results_seleccion', 'sensibilidad_seleccion.csv'), 'TextType', 'string');
    chk{end + 1} = row("E", "TOL_recalculada", "ruido -> {1,2,5}x10^k", unique(SS.TOL(SS.caso == "regla (eta>0, TOL)")), TOL); %#ok<AGROW>
    for g = ["G1", "G2"]
        sel = select_parameters(VT.(g), PHI_MIN, TOL);
        saved = readtable(fullfile(RES, 'results_seleccion', "seleccion_" + g + ".csv"));
        saved = saved(saved.elegida == 1, :);
        chk{end + 1} = row("E", "seleccion_delta", g, CHOSEN.(g)(1), sel.chosen.delta); %#ok<AGROW>
        chk{end + 1} = row("E", "seleccion_eta", g, CHOSEN.(g)(2), sel.chosen.eta); %#ok<AGROW>
        chk{end + 1} = row("E", "seleccion_igual_guardada", g, saved.riqueza_final, sel.chosen.riqueza_final); %#ok<AGROW>
    end

    %% F. G1 (0.90, 0.01) con el panel truncado a dic-2018
    rg = S.grid.results_wdro{abs(S.grid.delta_grid - 0.90) < 1e-12, abs(S.grid.eta_grid - 0.01) < 1e-12};
    p = rg.params;
    assert(abs(p.delta - 0.90) < 1e-12 && abs(p.eta - 0.01) < 1e-12, 'Parametros inesperados en la celda G1.');
    tic;
    rt = run_backtest_wdro_kelly(truncate_data(data, PERIODS{1, 3}), p);
    t_run = toc;
    n = numel(rt.dates);
    chk{end + 1} = row("F", "G1_truncado_n_meses", "G1 (0.90, 0.01)", 48, n); %#ok<AGROW>
    chk{end + 1} = row("F", "G1_truncado_mismas_fechas", "G1 (0.90, 0.01)", 1, double(isequal(rt.dates, rg.dates(1:n)))); %#ok<AGROW>
    chk{end + 1} = row("F", "G1_truncado_max_abs_dx", "G1 (0.90, 0.01)", 0, max(abs([rt.x, rt.x0] - [rg.x(1:n, :), rg.x0(1:n)]), [], 'all'), 0); %#ok<AGROW>
    chk{end + 1} = row("F", "G1_truncado_max_abs_dG", "G1 (0.90, 0.01)", 0, max(abs(rt.growth_real - rg.growth_real(1:n))), 0); %#ok<AGROW>
    chk{end + 1} = row("F", "G1_truncado_riqueza_validacion", "G1 (0.90, 0.01)", W("G1 (0.90, 0.01)", "validacion"), ...
        prod(rt.growth_real)); %#ok<AGROW>

    %% Salidas
    V = vertcat(chk{:});
    writetable(V, fullfile(here, 'verificacion_cruzada.csv'));
    BLK = ["A", "riqueza final"; "B", "suma de D_k = log(W_A/W_B)"; "C", "G2: primeros 48 meses = validación"; ...
           "D", "conteos de meses"; "E", "la selección solo usa validación"; "F", "G1 truncado a dic-2018 (sin mirar el futuro)"];
    md = ["# Verificación cruzada R5 (generada por `results_finales/r5_verificacion_cruzada.m`)", "", ...
          "Detalle en `verificacion_cruzada.csv`. Tolerancia relativa 1e-12 salvo donde se exige igualdad exacta (C y F: 0).", "", ...
          "| Bloque | Qué verifica | Comprobaciones | Fallidas |", "|---|---|---:|---:|"];
    for b = 1:size(BLK, 1)
        m = V.bloque == BLK(b, 1);
        md(end + 1) = sprintf("| %s | %s | %d | %d |", BLK(b, 1), BLK(b, 2), nnz(m), nnz(m & ~V.ok)); %#ok<AGROW>
    end
    md = [md, "", sprintf("Total: %d comprobaciones, %d fallidas. Bloque F: %d optimizaciones en %.1f s (no se guardan).", ...
          height(V), sum(~V.ok), n, t_run)];
    writelines(md, fullfile(here, 'VERIFICACION_R5.md'), 'Encoding', 'UTF-8');
    fprintf('R5: %d comprobaciones, %d fallidas (F: %.1f s).\n', height(V), sum(~V.ok), t_run);
    if any(~V.ok)
        disp(V(~V.ok, :));
        error('r5_verificacion_cruzada:fallos', 'Hay comprobaciones fallidas.');
    end
end


function v = round_up_125(x)
% Igual que main_seleccion_parametros.m: menor {1, 2, 5} x 10^k >= x
    k = floor(log10(x));
    for m = [1, 2, 5, 10]
        v = m * 10^k;
        if v >= x
            return
        end
    end
end


function v = ifelse(c, a, b)
    if c, v = a; else, v = b; end
end


function T = row(bloque, chequeo, objeto, esperado, obtenido, tol)
    if nargin < 6, tol = 1e-12; end
    ok = isequal(esperado, obtenido) || abs(esperado - obtenido) <= tol * max(1, abs(esperado));
    T = table(string(bloque), string(chequeo), string(objeto), esperado, obtenido, abs(esperado - obtenido), ok, ...
        'VariableNames', {'bloque', 'chequeo', 'objeto', 'esperado', 'obtenido', 'dif_abs', 'ok'});
end
