%% verify_eta0_backtest.m
% Verificacion (a) de "Implementacion y verificacion" en el BACKTEST
% COMPLETO: el Kelly nominal (run_backtest_nominal_kelly.m) debe
% reproducir la columna eta=0 de la malla WDRO de la Geometria 1 ya
% guardada (results_eta_delta_grid_wdro/grid_delta_eta.mat), mes a mes.
% No se elige ni se ajusta ningun parametro: solo se compara.
%
% Se compara, con tolerancias explicitas, el factor de crecimiento
% realizado, la riqueza final y las ponderaciones (estas solo tienen
% sentido porque la solucion de cada mes es unica, ver
% test_wdro_nominal_equivalence.m). Una vez que las trayectorias se
% separan, el portafolio heredado difiere, asi que se reporta tambien el
% primer mes con diferencia por encima de la tolerancia.
%
% Variable opcional antes de correr: DELTAS_TO_RUN (por defecto, toda la
% malla de delta). Salida: results_verificaciones/equivalencia_eta0_backtest.csv

if ~exist('DELTAS_TO_RUN', 'var') || isempty(DELTAS_TO_RUN)
    DELTAS_TO_RUN = [0.50, 0.60, 0.70, 0.75, 0.80, 0.90];
end

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');
OUT_DIR  = fullfile(PROJECT_DIR, 'results_verificaciones');
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

TOL_G = 1e-6;   % |G^real_nominal - G^real_WDRO(eta=0)| por mes
TOL_X = 1e-5;   % max |x_nominal - x_WDRO(eta=0)| por mes

S = load(fullfile(PROJECT_DIR, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'), 'grid');
grid_g1 = S.grid;
j0 = grid_g1.baseline_col;
data = load_monthly_data(CSV_PATH, TICKERS);

base_params = grid_g1.base_params;
rows = {};
nominal_results = {};
for delta = DELTAS_TO_RUN
    i = find(abs(grid_g1.delta_grid - delta) < 1e-12, 1);
    r_w = grid_g1.results_wdro{i, j0};

    p = base_params;
    p.delta = delta;
    tic;
    r_n = run_backtest_nominal_kelly(data, p);
    t_run = toc;
    nominal_results{end + 1} = r_n; %#ok<SAGROW>

    dG = abs(r_n.growth_real - r_w.growth_real);
    dX = max(abs([r_n.x, r_n.x0] - [r_w.x, r_w.x0]), [], 2);
    first_bad = find(dG > TOL_G | dX > TOL_X, 1);
    if isempty(first_bad)
        first_bad_date = NaT;
    else
        first_bad_date = r_n.dates(first_bad);
    end
    n_opt = sum(strcmp(r_n.status_class, 'optimo'));

    fprintf(['delta=%.2f: %.1f s | max|dG|=%.2e | max|dx|=%.2e | |dW_T|=%.2e | ', ...
        'optimos %d/%d\n'], delta, t_run, max(dG), max(dX), ...
        abs(r_n.wealth(end) - r_w.wealth(end)), n_opt, numel(r_n.dates));

    rows{end + 1} = table(delta, numel(r_n.dates), n_opt, max(dG), max(dX), ...
        abs(r_n.wealth(end) - r_w.wealth(end)), first_bad_date, t_run, ...
        max(dG) <= TOL_G && max(dX) <= TOL_X, ...
        'VariableNames', {'delta', 'n_meses', 'meses_optimos_nominal', 'max_dG', 'max_dx', ...
        'dW_final', 'primer_mes_fuera_tol', 'segundos', 'ok'}); %#ok<SAGROW>
end

T = vertcat(rows{:});
writetable(T, fullfile(OUT_DIR, 'equivalencia_eta0_backtest.csv'));
save(fullfile(OUT_DIR, 'nominal_backtests.mat'), 'nominal_results', 'DELTAS_TO_RUN', 'TOL_G', 'TOL_X');
fprintf('Tolerancias: TOL_G=%.0e, TOL_X=%.0e. Tabla en %s\n', TOL_G, TOL_X, ...
    fullfile(OUT_DIR, 'equivalencia_eta0_backtest.csv'));
