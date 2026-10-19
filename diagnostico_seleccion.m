%% diagnostico_seleccion.m
% T9, Paso 1: diagnostico de la malla (delta, eta) de VALIDACION
% (2015-2018) para G1 y G2, antes de aplicar la regla de seleccion
% (select_parameters.m). Usa SOLO meses de validacion:
%   - G2: wdro-market/results_validacion_grid_market (datos truncados a dic-2018)
%   - G1: results_eta_delta_grid_wdro/grid_delta_eta.mat; cada celda se
%     recorta de inmediato a validacion con extract_period_results.m, y no
%     se calcula nada con meses posteriores.
%
%   1a. Por (geometria, delta, eta): meses con la cota delta activa en la
%       ventana (min_s G_ks - delta <= 1e-6) y holgura minima.
%   1b. Por (geometria, eta), entre delta en {0.50,...,0.80}: si la cota
%       nunca esta activa, las celdas deberian ser la misma estrategia;
%       se mide el ruido numerico (diferencia relativa maxima de riqueza
%       final y max|d[x, x0]| entre pares, mes a mes).
%   1c. Riqueza final vs eta para cada delta, y perdida relativa frente a
%       eta=0.
%
% Salidas: results_seleccion/diagnostico_cota_delta.csv,
% ruido_celdas_equivalentes.csv, riqueza_vs_eta.csv, riqueza_vs_eta_G*.png

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
addpath(fullfile(PROJECT_DIR, 'wdro-market'));   % truncate_data.m
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');
OUT_DIR  = fullfile(PROJECT_DIR, 'results_seleccion');
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

VALIDATION_START = datetime(2015,1,1);
VALIDATION_END   = datetime(2018,12,31);
LAST_DECISION    = datetime(2018,11,30);
ACTIVE_TOL       = 1e-6;
DELTA_EQUIV      = [0.50, 0.60, 0.70, 0.75, 0.80];

% Panel truncado a dic-2018: las ventanas D_k se reconstruyen sin ver 2019+.
data = truncate_data(load_monthly_data(CSV_PATH, TICKERS), VALIDATION_END);

sources = { ...
    'G1', fullfile(PROJECT_DIR, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'); ...
    'G2', fullfile(PROJECT_DIR, 'wdro-market', 'results_validacion_grid_market', ...
                   'grid_delta_eta_market_validacion.mat')};

rows_a = {}; rows_b = {}; rows_c = {};
for s = 1:size(sources, 1)
    geo = string(sources{s, 1});
    S = load(sources{s, 2}, 'grid');
    g = S.grid;
    DELTA_GRID = g.delta_grid;
    ETA_GRID   = g.eta_grid;
    nd = numel(DELTA_GRID); ne = numel(ETA_GRID);

    % Recorte inmediato a validacion; se descarta la trayectoria completa.
    sub = cell(nd, ne);
    for c = 1:numel(g.results_wdro)
        sub{c} = extract_period_results(g.results_wdro{c}, VALIDATION_START, VALIDATION_END);
    end
    clear S g

    %% 1a. Cota delta activa
    n_active = zeros(nd, ne);
    W = zeros(nd, ne);
    for i = 1:nd
        for j = 1:ne
            r = sub{i, j};
            dec_dates = dateshift(r.dates, 'end', 'month', -1);   % fecha de decision k
            assert(max(dec_dates) <= LAST_DECISION, 'Se colo una fecha posterior a validacion.');
            assert(numel(dec_dates) == 48, 'Se esperaban 48 meses de validacion.');
            [tf, kk] = ismember(dec_dates, data.dates);
            assert(all(tf));
            p = r.params;
            slack = zeros(numel(kk), 1);
            for t = 1:numel(kk)
                k  = kk(t);
                Rw = data.R(k - p.N + 1 : k, :);
                G  = r.x0(t) * (1 + data.rf_return(k)) + (1 + Rw) * r.x(t, :)';
                slack(t) = min(G) - p.delta;
            end
            n_active(i, j) = sum(slack <= ACTIVE_TOL);
            W(i, j) = r.wealth(end);
            rows_a{end + 1} = table(geo, DELTA_GRID(i), ETA_GRID(j), numel(kk), ...
                n_active(i, j), min(slack), ...
                'VariableNames', {'geometria', 'delta', 'eta', 'n_meses', ...
                'meses_cota_activa', 'holgura_minima'}); %#ok<SAGROW>
        end
    end

    %% 1b. Ruido entre celdas equivalentes (mismo eta, delta en DELTA_EQUIV)
    [~, ii] = ismember(DELTA_EQUIV, DELTA_GRID);
    for j = 1:ne
        any_active = any(n_active(ii, j) > 0);
        Wj = W(ii, j);
        rel_W = (max(Wj) - min(Wj)) / max(Wj);
        dx_max = 0;
        for a = 1:numel(ii)
            for b = a + 1:numel(ii)
                ra = sub{ii(a), j}; rb = sub{ii(b), j};
                dx_max = max(dx_max, max(abs([ra.x, ra.x0] - [rb.x, rb.x0]), [], 'all'));
            end
        end
        rows_b{end + 1} = table(geo, ETA_GRID(j), any_active, ~any_active, rel_W, dx_max, ...
            min(Wj), max(Wj), ...
            'VariableNames', {'geometria', 'eta', 'cota_activa_en_alguna', 'usada_para_ruido', ...
            'max_dif_rel_riqueza', 'max_abs_dx', 'riqueza_min', 'riqueza_max'}); %#ok<SAGROW>
    end

    %% 1c. Riqueza vs eta
    j0 = find(ETA_GRID == 0, 1);
    for i = 1:nd
        for j = 1:ne
            rows_c{end + 1} = table(geo, DELTA_GRID(i), ETA_GRID(j), W(i, j), ...
                (W(i, j) - W(i, j0)) / W(i, j0), ...
                'VariableNames', {'geometria', 'delta', 'eta', 'riqueza_final', ...
                'perdida_rel_vs_eta0'}); %#ok<SAGROW>
        end
    end

    fig = figure('Position', [100, 100, 900, 520], 'Visible', 'off');
    hold on;
    colors = lines(nd);
    x_pos = 1:ne;   % eje categorico: la malla de eta no es equiespaciada
    for i = 1:nd
        plot(x_pos, W(i, :), '-o', 'Color', colors(i, :), 'LineWidth', 1.3, ...
            'DisplayName', sprintf('\\delta=%.2f', DELTA_GRID(i)));
    end
    hold off;
    set(gca, 'XTick', x_pos, 'XTickLabel', compose('%.2f', ETA_GRID), 'XGrid', 'on', 'YGrid', 'on');
    xlabel('\eta'); ylabel('Riqueza final W_T/W_0 (validacion)');
    title(sprintf('%s: riqueza final de validacion 2015-2018 vs \\eta', geo));
    legend('Location', 'southwest');
    saveas(fig, fullfile(OUT_DIR, sprintf('riqueza_vs_eta_%s.png', geo)));
    close(fig);
    clear sub
end

TA = vertcat(rows_a{:}); TB = vertcat(rows_b{:}); TC = vertcat(rows_c{:});
writetable(TA, fullfile(OUT_DIR, 'diagnostico_cota_delta.csv'));
writetable(TB, fullfile(OUT_DIR, 'ruido_celdas_equivalentes.csv'));
writetable(TC, fullfile(OUT_DIR, 'riqueza_vs_eta.csv'));

% Comprobacion cruzada con las tablas maestras v2 (solo validacion)
for geo = ["G1", "G2"]
    Tv = readtable(fullfile(PROJECT_DIR, 'results_validacion_metricas_v2', ...
        sprintf('tabla_maestra_validacion_%s.csv', geo)));
    Tc = sortrows(TC(TC.geometria == geo, :), {'delta', 'eta'});
    fprintf('%s: max|riqueza 1c - tabla v2| = %.2e\n', geo, max(abs(Tc.riqueza_final - Tv.riqueza_final)));
end

fprintf('\n1a. Celdas con la cota delta activa algun mes:\n');
disp(TA(TA.meses_cota_activa > 0, :));
fprintf('1b. Ruido entre celdas equivalentes (delta en %s):\n', mat2str(DELTA_EQUIV));
disp(TB);
fprintf('Salidas en %s\n', OUT_DIR);
