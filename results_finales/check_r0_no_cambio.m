%% check_r0_no_cambio.m
% R0, paso 4: con las rutas por defecto (config_rutas.m), una corrida corta
% de los primeros 12 meses de decision debe reproducir EXACTAMENTE las
% trayectorias guardadas:
%   - G1 (0.90, 0.01) vs results_eta_delta_grid_wdro/grid_delta_eta.mat
%   - G1 (0.90, 0)    vs la misma malla y vs el nominal guardado
%                       (results_verificaciones/nominal_backtests.mat)
%   - G2 (0.80, 0.01) vs wdro-market/results_validacion_grid_market
% Tambien mide el tiempo por mes resuelto, para la estimacion de R1.
% No escribe nada fuera de results_finales/.

HERE = fileparts(mfilename('fullpath'));
ROOT = fileparts(HERE);
addpath(ROOT);
addpath(fullfile(ROOT, 'wdro-market'));

cfg = config_rutas();
assert(cfg.is_default, 'Este chequeo es para las rutas por defecto.');
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
N_MESES = 12;

data = load_monthly_data(cfg.panel, TICKERS);
S = load(fullfile(cfg.results_root, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'), 'grid');
g1 = S.grid;
S = load(fullfile(cfg.results_root, 'wdro-market', 'results_validacion_grid_market', ...
    'grid_delta_eta_market_validacion.mat'), 'grid');
g2 = S.grid;
S = load(fullfile(cfg.results_root, 'results_verificaciones', 'nominal_backtests.mat'), ...
    'nominal_results', 'DELTAS_TO_RUN');
nominal = S.nominal_results{abs(S.DELTAS_TO_RUN - 0.90) < 1e-12};
clear S

N = g1.base_params.N;
data12 = truncate_data(data, data.dates(N + N_MESES));
cell_of = @(g, d, e) g.results_wdro{abs(g.delta_grid - d) < 1e-12, abs(g.eta_grid - e) < 1e-12};

casos = { ...
    'G1 (0.90, 0.01) vs malla G1',   'G1', 0.90, 0.01, cell_of(g1, 0.90, 0.01); ...
    'G1 (0.90, 0) vs malla G1',      'G1', 0.90, 0,    cell_of(g1, 0.90, 0); ...
    'G1 (0.90, 0) vs nominal',       'G1', 0.90, 0,    nominal; ...
    'G2 (0.80, 0.01) vs validacion', 'G2', 0.80, 0.01, cell_of(g2, 0.80, 0.01)};

rows = {};
for c = 1:size(casos, 1)
    geo = casos{c, 2}; delta = casos{c, 3}; eta = casos{c, 4}; ref = casos{c, 5};
    if geo == "G1"
        p = g1.base_params;
    else
        p = g2.base_params;
        p.weights = struct('wR', 0.70, 'wm', 0.15, 'wv', 0.15, 'wf', 0);
    end
    p.delta = delta; p.eta = eta;
    tic;
    if geo == "G1"
        r = run_backtest_wdro_kelly(data12, p);
    else
        r = run_backtest_wdro_kelly_market(data12, p);
    end
    t = toc;
    n = numel(r.dates);
    same_dates = isequal(r.dates, ref.dates(1:n));
    dx = max(abs([r.x, r.x0] - [ref.x(1:n, :), ref.x0(1:n)]), [], 'all');
    dG = max(abs(r.growth_real - ref.growth_real(1:n)));
    dW = max(abs(r.wealth - ref.wealth(1:n + 1)));
    rows{end + 1} = table(string(casos{c, 1}), n, same_dates, dx, dG, dW, ...
        same_dates && max([dx, dG, dW]) == 0, t, t / n, ...
        'VariableNames', {'caso', 'n_meses', 'mismas_fechas', 'max_dx', 'max_dG', 'max_dW', ...
        'identico', 'segundos', 'segundos_por_mes'}); %#ok<SAGROW>
end
T = vertcat(rows{:});
disp(T);
writetable(T, fullfile(HERE, 'check_r0_no_cambio.csv'));
