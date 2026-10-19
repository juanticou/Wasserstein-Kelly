%% rebuild_validation_tables.m
% Tablas maestras de VALIDACION (2015-2018) de la Geometria 1 y la
% Geometria 2 recalculadas con las metricas alineadas a la metodologia
% (compute_metrics.m: CVaR de Rockafellar-Uryasev, Sharpe con excesos
% sobre r^f, Sortino con objetivo cero, costo fraccional y monetario,
% proporcion en riesgo). NO resuelve ningun backtest: reusa
%   results_eta_delta_grid_wdro/grid_delta_eta.mat            (G1)
%   wdro-market/results_validacion_grid_market/
%       grid_delta_eta_market_validacion.mat                  (G2)
% y escribe en una carpeta NUEVA (results_validacion_metricas_v2/), sin
% tocar las tablas anteriores. Solo usa meses de validacion.
%
% Ademas verifica que con eta=0 ambas geometrias producen la misma
% trayectoria mes a mes (x, x0 y G^real) dentro de TOL_PATH.

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');
OUT_DIR  = fullfile(PROJECT_DIR, 'results_validacion_metricas_v2');
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end
TOL_PATH = 1e-8;
VALIDATION_START = datetime(2015,1,1);
VALIDATION_END   = datetime(2018,12,31);

data = load_monthly_data(CSV_PATH, TICKERS);

S = load(fullfile(PROJECT_DIR, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'), 'grid');
g1 = add_rf_to_grid(S.grid, data);
S = load(fullfile(PROJECT_DIR, 'wdro-market', 'results_validacion_grid_market', ...
    'grid_delta_eta_market_validacion.mat'), 'grid');
g2 = add_rf_to_grid(S.grid, data);

if ~isequal(g1.delta_grid, g2.delta_grid) || ~isequal(g1.eta_grid, g2.eta_grid)
    error('rebuild_validation_tables:gridMismatch', 'Las mallas de G1 y G2 no coinciden.');
end
DELTA_GRID = g1.delta_grid;
ETA_GRID   = g1.eta_grid;

%% 1. Tablas maestras de validacion
T1 = build_grid_summary_table(g1, VALIDATION_START, VALIDATION_END);
T2 = build_grid_summary_table(g2, VALIDATION_START, VALIDATION_END);
writetable(T1, fullfile(OUT_DIR, 'tabla_maestra_validacion_G1.csv'));
writetable(T2, fullfile(OUT_DIR, 'tabla_maestra_validacion_G2.csv'));
fprintf('Tabla maestra G1: %d filas | G2: %d filas\n', height(T1), height(T2));

%% 2. Comparacion G2 - G1 celda a celda
cmp = table(T1.delta, T1.eta, T1.riqueza_final, T2.riqueza_final, ...
    T1.CAGR, T2.CAGR, T2.CAGR - T1.CAGR, T1.max_drawdown, T2.max_drawdown, ...
    T1.CVaR_perdida, T2.CVaR_perdida, T1.sharpe, T2.sharpe, ...
    T1.costo_monetario, T2.costo_monetario, T1.proporcion_riesgo_media, T2.proporcion_riesgo_media, ...
    T1.fraccion_factible, T2.fraccion_factible, ...
    'VariableNames', {'delta', 'eta', 'riqueza_G1', 'riqueza_G2', 'CAGR_G1', 'CAGR_G2', ...
    'CAGR_G2_menos_G1', 'MDD_G1', 'MDD_G2', 'CVaR_G1', 'CVaR_G2', 'sharpe_G1', 'sharpe_G2', ...
    'costo_monetario_G1', 'costo_monetario_G2', 'prop_riesgo_G1', 'prop_riesgo_G2', ...
    'fraccion_optima_G1', 'fraccion_optima_G2'});
writetable(cmp, fullfile(OUT_DIR, 'comparacion_G2_vs_G1_validacion.csv'));

%% 3. Verificacion eta=0: trayectorias identicas en validacion
j0 = g1.baseline_col;
rows = {};
for i = 1:numel(DELTA_GRID)
    a = extract_period_results(g1.results_wdro{i, j0}, VALIDATION_START, VALIDATION_END);
    b = extract_period_results(g2.results_wdro{i, j0}, VALIDATION_START, VALIDATION_END);
    same_dates = isequal(a.dates, b.dates);
    dx = max(abs([a.x, a.x0] - [b.x, b.x0]), [], 'all');
    dG = max(abs(a.growth_real - b.growth_real));
    dW = abs(a.wealth(end) - b.wealth(end));
    rows{end + 1} = table(DELTA_GRID(i), numel(a.dates), same_dates, dx, dG, dW, ...
        same_dates && max([dx, dG, dW]) <= TOL_PATH, ...
        'VariableNames', {'delta', 'n_meses', 'mismas_fechas', 'max_dx', 'max_dG', 'dW_final', 'ok'}); %#ok<SAGROW>
end
E = vertcat(rows{:});
writetable(E, fullfile(OUT_DIR, 'verificacion_eta0_G1_vs_G2.csv'));
fprintf('eta=0, G1 vs G2 en validacion: max dx=%.2e, max dG=%.2e, max dW=%.2e (TOL=%.0e) -> %d\n', ...
    max(E.max_dx), max(E.max_dG), max(E.dW_final), TOL_PATH, all(E.ok));

%% 4. Heatmaps de las metricas que cambiaron (mismo formato que main_validation_grid.m)
for g = 1:2
    if g == 1
        T = T1; tag = 'G1';
    else
        T = T2; tag = 'G2';
    end
    M_cvar   = reshape_metric(T, 'CVaR_perdida', DELTA_GRID, ETA_GRID);
    M_sharpe = reshape_metric(T, 'sharpe', DELTA_GRID, ETA_GRID);
    M_cost   = reshape_metric(T, 'costo_monetario', DELTA_GRID, ETA_GRID);
    M_risk   = reshape_metric(T, 'proporcion_riesgo_media', DELTA_GRID, ETA_GRID);
    period_tag = sprintf('(%s, validacion 2015-2018)', tag);
    plot_heatmap(100 * M_cvar, ETA_GRID, DELTA_GRID, ['CVaR 95% R-U de perdida mensual ', period_tag, ' [pp]'], ...
        'CVaR (pp)', '%.2f', OUT_DIR, sprintf('heatmap_cvar_RU_%s.png', tag));
    plot_heatmap(M_sharpe, ETA_GRID, DELTA_GRID, ['Sharpe (exceso sobre r^f) ', period_tag], ...
        'Sharpe anualizado', '%.2f', OUT_DIR, sprintf('heatmap_sharpe_%s.png', tag));
    plot_heatmap(100 * M_cost, ETA_GRID, DELTA_GRID, ['Costo monetario acumulado / W_0 ', period_tag, ' [%]'], ...
        'Costo (%)', '%.3f', OUT_DIR, sprintf('heatmap_costo_monetario_%s.png', tag));
    plot_heatmap(M_risk, ETA_GRID, DELTA_GRID, ['Proporcion media invertida en riesgo ', period_tag], ...
        '\Sigma_j x_{jk}', '%.2f', OUT_DIR, sprintf('heatmap_proporcion_riesgo_%s.png', tag));
end
close all;
fprintf('Salidas en %s\n', OUT_DIR);


function g = add_rf_to_grid(g, data)
    for c = 1:numel(g.results_wdro)
        if ~isempty(g.results_wdro{c}) && ~isfield(g.results_wdro{c}, 'rf')
            g.results_wdro{c} = attach_rf(g.results_wdro{c}, data);
        end
    end
end


function M = reshape_metric(T, col, delta_grid, eta_grid)
    M = nan(numel(delta_grid), numel(eta_grid));
    for r = 1:height(T)
        i = find(abs(delta_grid - T.delta(r)) < 1e-12, 1);
        j = find(abs(eta_grid - T.eta(r)) < 1e-12, 1);
        M(i, j) = T.(col)(r);
    end
end
