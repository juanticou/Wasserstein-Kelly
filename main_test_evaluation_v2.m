%% main_test_evaluation_v2.m
% Evaluacion UNICA del periodo de prueba (2019-2025) con las
% configuraciones aprobadas en T9 (results_seleccion/REPORTE_SELECCION.md):
%   (delta1*, eta1*) = (0.90, 0.01)  -> elegida para G1
%   (delta2*, eta2*) = (0.80, 0.01)  -> elegida para G2
% No se barre ninguna malla en prueba ni se reeligen parametros.
%
% 1. Corre G2 sobre el panel completo (132 decisiones) SOLO para esas dos
%    configuraciones y verifica que los primeros 48 meses reproducen
%    exactamente la trayectoria de validacion ya guardada
%    (wdro-market/results_validacion_grid_market).
% 2. Toma G1 de la malla guardada (results_eta_delta_grid_wdro) y el
%    nominal de results_verificaciones/nominal_backtests.mat (mismo delta
%    de cada configuracion).
% 3. Recorta 2019-2025 de cada trayectoria completa (extract_period_results,
%    sin reiniciar posiciones) y calcula las metricas nuevas
%    (compute_metrics.m). Tambien reporta validacion como referencia.
% 4. Contrastes con D_k = log G^A - log G^B (solo estadisticos puntuales;
%    el bootstrap es T6):
%    - emparejado: G2 vs G1 con la misma (delta, eta), para cada configuracion
%    - seleccionado: G2(delta2*, eta2*) vs G1(delta1*, eta1*)
%    - cada estrategia WK vs el nominal con su mismo delta
%
% Salidas: results_prueba_v2/

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
cfg = config_rutas();   % rutas de datos y resultados (WK_PANEL, WK_RESULTS_ROOT)
RES = cfg.results_root;
addpath(fullfile(PROJECT_DIR, 'wdro-market'));
CSV_PATH = cfg.panel;
OUT_DIR  = fullfile(RES, 'results_prueba_v2');
preparar_salida(cfg, OUT_DIR);

CONFIGS = [0.90, 0.01; 0.80, 0.01];   % fila 1: elegida G1; fila 2: elegida G2
WEIGHTS = struct('wR', 0.70, 'wm', 0.15, 'wv', 0.15, 'wf', 0);
ALPHA   = 0.95;
VALIDATION_START = datetime(2015,1,1);  VALIDATION_END = datetime(2018,12,31);
TEST_START       = datetime(2019,1,1);  TEST_END       = datetime(2025,12,31);
TOL_REPRO = 0;   % reproduccion exacta exigida (mismo codigo, mismos datos)

data = load_monthly_data(CSV_PATH, TICKERS);

S = load(fullfile(RES, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'), 'grid');
g1 = S.grid;
S = load(fullfile(RES, 'wdro-market', 'results_validacion_grid_market', ...
    'grid_delta_eta_market_validacion.mat'), 'grid');
g2val = S.grid;
S = load(fullfile(RES, 'results_verificaciones', 'nominal_backtests.mat'), ...
    'nominal_results', 'DELTAS_TO_RUN');
nominal_all = S.nominal_results;
nominal_deltas = S.DELTAS_TO_RUN;
clear S

%% 1. G2 completo para las dos configuraciones + verificacion de validacion
res = struct('name', {}, 'geo', {}, 'delta', {}, 'eta', {}, 'r', {});
repro_rows = {};
for c = 1:size(CONFIGS, 1)
    delta = CONFIGS(c, 1); eta = CONFIGS(c, 2);
    p = g2val.base_params;
    p.delta = delta; p.eta = eta; p.weights = WEIGHTS;
    tic;
    r2 = run_backtest_wdro_kelly_market(data, p);
    t_run = toc;

    i = find(abs(g2val.delta_grid - delta) < 1e-12, 1);
    j = find(abs(g2val.eta_grid - eta) < 1e-12, 1);
    rv = g2val.results_wdro{i, j};
    n = numel(rv.dates);
    same_dates = isequal(r2.dates(1:n), rv.dates);
    dx = max(abs([r2.x(1:n, :), r2.x0(1:n)] - [rv.x, rv.x0]), [], 'all');
    dG = max(abs(r2.growth_real(1:n) - rv.growth_real));
    dW = abs(r2.wealth(n + 1) - rv.wealth(end));
    ok = same_dates && max([dx, dG, dW]) <= TOL_REPRO;
    fprintf('G2 (%.2f, %.2f): %d meses en %.1f s | primeros %d vs validacion: dx=%.2e dG=%.2e dW=%.2e -> %d\n', ...
        delta, eta, numel(r2.dates), t_run, n, dx, dG, dW, ok);
    if ~ok
        error('main_test_evaluation_v2:reproFailed', ...
            'G2 (%.2f, %.2f) no reproduce la validacion guardada; se detiene antes de evaluar la prueba.', delta, eta);
    end
    repro_rows{end + 1} = table(delta, eta, numel(r2.dates), n, same_dates, dx, dG, dW, ok, t_run, ...
        'VariableNames', {'delta', 'eta', 'n_meses_total', 'n_meses_validacion', 'mismas_fechas', ...
        'max_dx', 'max_dG', 'dW', 'ok', 'segundos'}); %#ok<SAGROW>
    res(end + 1) = struct('name', sprintf('G2 (%.2f, %.2f)', delta, eta), 'geo', "G2", ...
        'delta', delta, 'eta', eta, 'r', r2); %#ok<SAGROW>
end
writetable(vertcat(repro_rows{:}), fullfile(OUT_DIR, 'verificacion_G2_reproduce_validacion.csv'));
save(fullfile(OUT_DIR, 'g2_trayectorias_completas.mat'), 'res', 'CONFIGS', 'WEIGHTS');

%% 2. G1 (malla guardada) y nominal con el mismo delta
for c = 1:size(CONFIGS, 1)
    delta = CONFIGS(c, 1); eta = CONFIGS(c, 2);
    i = find(abs(g1.delta_grid - delta) < 1e-12, 1);
    j = find(abs(g1.eta_grid - eta) < 1e-12, 1);
    r1 = attach_rf(g1.results_wdro{i, j}, data);
    res(end + 1) = struct('name', sprintf('G1 (%.2f, %.2f)', delta, eta), 'geo', "G1", ...
        'delta', delta, 'eta', eta, 'r', r1); %#ok<SAGROW>
end
for delta = unique(CONFIGS(:, 1))'
    k = find(abs(nominal_deltas - delta) < 1e-12, 1);
    res(end + 1) = struct('name', sprintf('Nominal (%.2f)', delta), 'geo', "nominal", ...
        'delta', delta, 'eta', 0, 'r', nominal_all{k}); %#ok<SAGROW>
end
% Todas las trayectorias deben compartir las mismas fechas de decision.
for m = 2:numel(res)
    assert(isequal(res(m).r.dates, res(1).r.dates), 'Fechas de decision distintas entre estrategias.');
end

%% 3. Metricas por tramo
periods = {'validacion', VALIDATION_START, VALIDATION_END; 'prueba', TEST_START, TEST_END};
rows = {};
sub = cell(numel(res), size(periods, 1));
for m = 1:numel(res)
    for q = 1:size(periods, 1)
        sr = extract_period_results(res(m).r, periods{q, 2}, periods{q, 3});
        sub{m, q} = sr;
        mt = compute_metrics(sr, ALPHA);
        rows{end + 1} = table(string(res(m).name), res(m).geo, res(m).delta, res(m).eta, ...
            string(periods{q, 1}), min(sr.dates), max(sr.dates), mt.n_months, ...
            mt.wealth_final, mt.log_growth_mean, mt.CAGR, mt.max_drawdown, mt.worst_month, ...
            mt.variance_monthly, mt.VaR_loss, mt.CVaR_loss, mt.sharpe, mt.sortino, mt.calmar, ...
            mt.turnover_total, mt.n_rebalances, mt.cost_frac_total, mt.cost_monetary_total, ...
            mt.max_weight_mean, mt.Neff_mean, mt.risky_share_mean, mt.n_violations_delta, ...
            mt.min_growth_real, mt.n_solver_failed, ...
            'VariableNames', {'estrategia', 'geometria', 'delta', 'eta', 'tramo', 'primer_mes', ...
            'ultimo_mes', 'n_meses', 'riqueza_final', 'log_crecimiento_medio', 'CAGR', ...
            'max_drawdown', 'peor_mes', 'varianza_mensual', 'VaR_perdida', 'CVaR_perdida', ...
            'sharpe', 'sortino', 'calmar', 'turnover_total', 'n_transacciones', ...
            'costo_fraccional', 'costo_monetario', 'peso_max_promedio', 'Neff_promedio', ...
            'proporcion_riesgo_media', 'violaciones_delta', 'min_factor_crecimiento', ...
            'meses_sin_optimizacion'}); %#ok<SAGROW>
    end
end
M = vertcat(rows{:});
writetable(M, fullfile(OUT_DIR, 'metricas_por_tramo.csv'));
disp(M(M.tramo == "prueba", {'estrategia', 'n_meses', 'riqueza_final', 'CAGR', 'max_drawdown', ...
    'CVaR_perdida', 'sharpe', 'costo_monetario', 'meses_sin_optimizacion'}));

%% 4. Contrastes D_k = log G^A - log G^B en prueba (puntuales)
name_idx = @(s) find(strcmp({res.name}, s), 1);
contrasts = { ...
    'emparejado (0.90, 0.01)',  'G2 (0.90, 0.01)', 'G1 (0.90, 0.01)'; ...
    'emparejado (0.80, 0.01)',  'G2 (0.80, 0.01)', 'G1 (0.80, 0.01)'; ...
    'seleccionado',             'G2 (0.80, 0.01)', 'G1 (0.90, 0.01)'; ...
    'vs nominal',               'G1 (0.90, 0.01)', 'Nominal (0.90)'; ...
    'vs nominal',               'G2 (0.90, 0.01)', 'Nominal (0.90)'; ...
    'vs nominal',               'G1 (0.80, 0.01)', 'Nominal (0.80)'; ...
    'vs nominal',               'G2 (0.80, 0.01)', 'Nominal (0.80)'};
q_test = 2;
crow = {};
for c = 1:size(contrasts, 1)
    a = sub{name_idx(contrasts{c, 2}), q_test};
    b = sub{name_idx(contrasts{c, 3}), q_test};
    assert(isequal(a.dates, b.dates));
    D = log(a.growth_real) - log(b.growth_real);
    crow{end + 1} = table(string(contrasts{c, 1}), string(contrasts{c, 2}), string(contrasts{c, 3}), ...
        numel(D), mean(D), median(D), mean(D > 0), sum(D), ...
        a.wealth(end) / b.wealth(end) - 1, max(abs(D)), ...
        'VariableNames', {'contraste', 'A', 'B', 'n_meses', 'media_D', 'mediana_D', ...
        'prop_D_positivo', 'suma_D', 'riqueza_A_sobre_B_menos_1', 'max_abs_D'}); %#ok<SAGROW>
end
CT = vertcat(crow{:});
writetable(CT, fullfile(OUT_DIR, 'contrastes_prueba.csv'));
disp(CT);

%% 5. Graficas de riqueza en prueba y trayectoria completa
fig = figure('Position', [100, 100, 1000, 560], 'Visible', 'off');
hold on;
colors = lines(numel(res));
for m = 1:numel(res)
    sr = sub{m, q_test};
    style = '-';
    if res(m).geo == "nominal", style = '--'; end
    plot([dateshift(sr.dates(1), 'end', 'month', -1); sr.dates], sr.wealth, style, ...
        'Color', colors(m, :), 'LineWidth', 1.4, 'DisplayName', res(m).name);
end
hold off;
xlabel('Fecha'); ylabel('W_t / W_{inicio prueba}');
title('Riqueza en el periodo de prueba (2019-2025), re-basada a 1, sin reiniciar posiciones');
legend('Location', 'northwest'); set(gca, 'XGrid', 'on', 'YGrid', 'on');
saveas(fig, fullfile(OUT_DIR, 'riqueza_prueba.png'));
close(fig);

fig = figure('Position', [100, 100, 1000, 560], 'Visible', 'off');
hold on;
for m = 1:numel(res)
    r = res(m).r;
    style = '-';
    if res(m).geo == "nominal", style = '--'; end
    plot([r.dates(1); dateshift(r.dates, 'end', 'month', 1)], r.wealth, style, ...
        'Color', colors(m, :), 'LineWidth', 1.4, 'DisplayName', res(m).name);
end
xline(datetime(2018,12,31), 'k:', 'inicio prueba', 'HandleVisibility', 'off');
hold off;
xlabel('Fecha'); ylabel('W_t / W_0');
title('Riqueza de la trayectoria completa (dic-2014 = 1)');
legend('Location', 'northwest'); set(gca, 'XGrid', 'on', 'YGrid', 'on');
saveas(fig, fullfile(OUT_DIR, 'riqueza_trayectoria_completa.png'));
close(fig);

fprintf('Salidas en %s\n', OUT_DIR);
