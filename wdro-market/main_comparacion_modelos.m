%% main_comparacion_modelos.m
% Comparacion final, con (delta, eta) = (0.90, 0.05) fijos, de:
%   1. Kelly nominal (sin robustez, run_backtest_nominal_kelly.m)
%   2. Wasserstein-Kelly, Geometria 1 (solo retornos, run_backtest_wdro_kelly.m)
%   3. Wasserstein-Kelly, Geometria 2 (retornos + mercado + VIX,
%      run_backtest_wdro_kelly_market.m, pesos del Cuadro 8)
%   4. S&P 500: comprar y mantener SPY (mkt_return del panel, retorno total
%      con dividendos porque sale del Adj Close)
%
% Los tres modelos se corren sobre el panel completo (mismas fechas de
% decision k = N..T-1, mismo arranque en el activo libre de riesgo) y se
% evaluan en tres periodos con extract_period_results.m:
%   completo   : todo el backtest (enero 2015 - diciembre 2025)
%   validacion : enero 2015 - diciembre 2018
%   prueba     : enero 2019 - diciembre 2025  (el que realmente importa)
%
% UBICACION: Wasserstein-Kelly/wdro-market/ (mismo patron que
% main_geometria_mercado.m).
%
% Requiere: CVX + MOSEK, Statistics and Machine Learning Toolbox
% (prctile/boxplot), y los .m compartidos de la raiz.

clear; clc; close all;

%% 1. Configuracion y path
PROJECT_DIR = fileparts(mfilename('fullpath'));   % .../Wasserstein-Kelly/wdro-market
ROOT_DIR    = fileparts(PROJECT_DIR);              % .../Wasserstein-Kelly
addpath(PROJECT_DIR);
addpath(ROOT_DIR);

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
CSV_PATH = fullfile(ROOT_DIR, 'data', 'processed', 'monthly_panel.csv');
if ~isfile(CSV_PATH)
    error('main_comparacion_modelos:csvNotFound', 'No se encontro el archivo:\n  %s', CSV_PATH);
end

base_params.N       = 60;
base_params.tau     = 0.001;
base_params.xbar    = 0.25;
base_params.gamma   = 1;
base_params.solver  = 'mosek';
base_params.eps_esc = 1e-6;
base_params.delta   = 0.90;
base_params.eta     = 0.05;

% Pesos de la Geometria 2 (Cuadro 8, configuracion nucleo).
WEIGHTS = struct('wR', 0.70, 'wm', 0.15, 'wv', 0.15, 'wf', 0);

ALPHA = 0.95;

VALIDATION_START = datetime(2015,1,1);
VALIDATION_END   = datetime(2018,12,31);
TEST_START       = datetime(2019,1,1);
TEST_END         = datetime(2025,12,31);

OUT_DIR = fullfile(PROJECT_DIR, 'results_comparacion_modelos');
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

% Malla delta-eta de la Geometria 1 (panel completo), para el chequeo de consistencia.
G1_GRID_PATH = fullfile(ROOT_DIR, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat');

fprintf('Comparacion de modelos: delta=%.2f, eta=%.2f\n', base_params.delta, base_params.eta);
fprintf('Pesos Geometria 2: wR=%.2f, wm=%.2f, wv=%.2f, wf=%.2f\n', ...
    WEIGHTS.wR, WEIGHTS.wm, WEIGHTS.wv, WEIGHTS.wf);

%% 2. Datos (panel completo)
data = load_monthly_data(CSV_PATH, TICKERS);

%% 3. Correr las cuatro estrategias
MODEL_NAMES  = ["nominal", "G1_retornos", "G2_mercado_vix", "SP500"];
MODEL_LABELS = {'Kelly nominal', ...
    sprintf('WK Geometria 1 (\\eta=%.2f)', base_params.eta), ...
    sprintf('WK Geometria 2 (\\eta=%.2f)', base_params.eta), ...
    'S&P 500 (SPY)'};
n_models = numel(MODEL_NAMES);
results  = cell(n_models, 1);

fprintf('\n--- Kelly nominal (delta=%.2f) ... ', base_params.delta);
results{1} = run_backtest_nominal_kelly(data, base_params);
fprintf('riqueza final = %.4f\n', results{1}.wealth(end));

fprintf('--- Geometria 1 (retornos) ... ');
results{2} = run_backtest_wdro_kelly(data, base_params);
fprintf('riqueza final = %.4f\n', results{2}.wealth(end));

fprintf('--- Geometria 2 (mercado+VIX) ... ');
p2 = base_params;
p2.weights = WEIGHTS;
results{3} = run_backtest_wdro_kelly_market(data, p2);
fprintf('riqueza final = %.4f\n', results{3}.wealth(end));

results{4} = build_benchmark_results(data, base_params.N);
fprintf('--- S&P 500 (SPY, comprar y mantener): riqueza final = %.4f\n', results{4}.wealth(end));

save(fullfile(OUT_DIR, 'comparacion_modelos.mat'), 'results', 'MODEL_NAMES', 'MODEL_LABELS', ...
    'base_params', 'WEIGHTS', 'VALIDATION_START', 'VALIDATION_END', 'TEST_START', 'TEST_END');

%% 4. Chequeos de consistencia
fprintf('\n=== Chequeos de consistencia ===\n');
for m = 1:3
    fprintf('Fraccion de fechas resueltas, %s: %.1f%%\n', MODEL_NAMES(m), ...
        100 * mean(strcmp(results{m}.status, 'Solved')));
end
if isfile(G1_GRID_PATH)
    S_grid = load(G1_GRID_PATH, 'grid');
    g = S_grid.grid;
    i_d = find(g.delta_grid == base_params.delta, 1);
    j_e = find(g.eta_grid == base_params.eta, 1);
    j_0 = g.baseline_col;
    if ~isempty(i_d) && ~isempty(j_e) && ~isempty(g.results_wdro{i_d, j_e})
        d1 = abs(results{2}.wealth(end) - g.results_wdro{i_d, j_e}.wealth(end));
        fprintf('G1 vs malla guardada (delta=%.2f, eta=%.2f): |dif. riqueza final| = %.3e\n', ...
            base_params.delta, base_params.eta, d1);
        if d1 > 1e-4
            warning('main_comparacion_modelos:g1Mismatch', ...
                'La Geometria 1 no reproduce la celda guardada en %s (dif. = %.3e).', G1_GRID_PATH, d1);
        end
    end
    if ~isempty(i_d) && ~isempty(j_0) && ~isempty(g.results_wdro{i_d, j_0})
        d0 = abs(results{1}.wealth(end) - g.results_wdro{i_d, j_0}.wealth(end));
        fprintf('Nominal vs WDRO eta=0 guardado (delta=%.2f): |dif. riqueza final| = %.3e\n', ...
            base_params.delta, d0);
        if d0 > 1e-4
            warning('main_comparacion_modelos:nominalMismatch', ...
                'El nominal no coincide con la celda eta=0 de la malla guardada (dif. = %.3e).', d0);
        end
    end
else
    fprintf('No se encontro %s; se omite el chequeo contra la malla guardada.\n', G1_GRID_PATH);
end

%% 5. Metricas por modelo y periodo
PERIOD_NAMES  = ["completo", "validacion", "prueba"];
PERIOD_BOUNDS = {[NaT, NaT], [VALIDATION_START, VALIDATION_END], [TEST_START, TEST_END]};

sub     = cell(n_models, numel(PERIOD_NAMES));
metrics = cell(n_models, numel(PERIOD_NAMES));
for m = 1:n_models
    full_start = min(dateshift(results{m}.dates, 'end', 'month', 1));
    full_end   = max(dateshift(results{m}.dates, 'end', 'month', 1));
    for p = 1:numel(PERIOD_NAMES)
        b = PERIOD_BOUNDS{p};
        if isnat(b(1))
            b = [full_start, full_end];
        end
        sub{m, p}     = extract_period_results(results{m}, b(1), b(2));
        metrics{m, p} = compute_metrics(sub{m, p}, ALPHA);
    end
end

i_sp = find(MODEL_NAMES == "SP500");
rows = {};
for p = 1:numel(PERIOD_NAMES)
    r_sp = sub{i_sp, p}.growth_real - 1;
    m_sp = metrics{i_sp, p};
    for m = 1:n_models
        rows{end+1} = metrics_row(MODEL_NAMES(m), PERIOD_NAMES(p), metrics{m, p}, ...
            sub{m, p}.growth_real - 1, r_sp, m_sp); %#ok<SAGROW>
    end
end
comparison_table = vertcat(rows{:});
writetable(comparison_table, fullfile(OUT_DIR, 'tabla_comparacion_modelos.csv'));

fprintf('\n=== Periodo de PRUEBA (%s a %s) ===\n', ...
    datestr(TEST_START, 'mmm-yyyy'), datestr(TEST_END, 'mmm-yyyy'));
disp(comparison_table(comparison_table.periodo == "prueba", ...
    {'modelo', 'riqueza_final', 'CAGR', 'max_drawdown', 'CVaR_perdida', 'sharpe', ...
     'sortino', 'calmar', 'turnover_total', 'CAGR_menos_SP500', 'beta_SP500', 'correlacion_SP500'}));

fprintf('\n=== Periodo de VALIDACION (%s a %s) ===\n', ...
    datestr(VALIDATION_START, 'mmm-yyyy'), datestr(VALIDATION_END, 'mmm-yyyy'));
disp(comparison_table(comparison_table.periodo == "validacion", ...
    {'modelo', 'riqueza_final', 'CAGR', 'max_drawdown', 'CVaR_perdida', 'sharpe', 'CAGR_menos_SP500'}));

%% 6. Graficas
colors = lines(n_models);
colors(i_sp, :) = [0 0 0];   % S&P 500 en negro
styles = {'-', '-', '-', '--'};

% 6.1 Riqueza acumulada completa, con la frontera validacion/prueba
figure('Position', [100, 100, 1000, 600]);
hold on;
for m = 1:n_models
    r = results{m};
    plot([r.dates(1); dateshift(r.dates, 'end', 'month', 1)], r.wealth, styles{m}, ...
        'LineWidth', 1.6, 'Color', colors(m, :), 'DisplayName', MODEL_LABELS{m});
end
xline(TEST_START, ':k', 'Inicio de prueba', 'LabelVerticalAlignment', 'bottom', ...
    'HandleVisibility', 'off');
hold off;
title(sprintf('Riqueza acumulada, \\delta=%.2f, \\eta=%.2f -- backtest completo', ...
    base_params.delta, base_params.eta));
xlabel('Fecha'); ylabel('W_t / W_0');
legend('Location', 'northwest');
set(gca, 'XGrid', 'on', 'YGrid', 'on');
saveas(gcf, fullfile(OUT_DIR, 'riqueza_completa_modelos.png'));

% 6.2 Riqueza solo en la prueba (re-basada a 1)
i_test = find(PERIOD_NAMES == "prueba");
figure('Position', [100, 100, 1000, 600]);
hold on;
for m = 1:n_models
    s = sub{m, i_test};
    plot([dateshift(s.dates(1), 'end', 'month', -1); s.dates], s.wealth, styles{m}, ...
        'LineWidth', 1.8, 'Color', colors(m, :), 'DisplayName', MODEL_LABELS{m});
end
hold off;
title(sprintf('Riqueza acumulada, SOLO periodo de prueba (%s a %s)', ...
    datestr(TEST_START, 'mmm-yyyy'), datestr(TEST_END, 'mmm-yyyy')));
xlabel('Fecha'); ylabel('W_t / W_0 (re-basada a 1 al inicio de la prueba)');
legend('Location', 'northwest');
set(gca, 'XGrid', 'on', 'YGrid', 'on');
saveas(gcf, fullfile(OUT_DIR, 'riqueza_prueba_modelos.png'));

% 6.3 Drawdown y retornos mensuales en la prueba
test_list = sub(:, i_test)';
try
    plot_drawdown_series(test_list, MODEL_LABELS, 'Drawdown, periodo de prueba', OUT_DIR);
catch ME
    warning('main_comparacion_modelos:drawdownFailed', '%s', ME.message);
end
try
    plot_returns_timeseries(test_list, MODEL_LABELS, 'Retornos mensuales, periodo de prueba', OUT_DIR);
catch ME
    warning('main_comparacion_modelos:returnsTimeseriesFailed', '%s', ME.message);
end
try
    plot_returns_boxplot(test_list, MODEL_LABELS, 'Distribucion de retornos, periodo de prueba', OUT_DIR);
catch ME
    warning('main_comparacion_modelos:returnsBoxplotFailed', ...
        'Revisa si tienes el Statistics Toolbox: %s', ME.message);
end

% 6.4 Barras de CAGR, MDD y Sharpe en la prueba
m_test = metrics(:, i_test);
bar_vals = {100 * cellfun(@(s) s.CAGR, m_test), 100 * cellfun(@(s) s.max_drawdown, m_test), ...
    cellfun(@(s) s.sharpe, m_test)};
bar_titles = {'CAGR (%)', 'Maximo drawdown (%)', 'Sharpe anualizado'};
figure('Position', [100, 100, 1200, 450]);
for q = 1:3
    subplot(1, 3, q);
    bh = bar(categorical(cellstr(MODEL_NAMES), cellstr(MODEL_NAMES)), bar_vals{q}, 'FaceColor', 'flat');
    bh.CData = colors;
    title(bar_titles{q});
    text(1:n_models, bar_vals{q}, compose('%.2f', bar_vals{q}), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    set(gca, 'YGrid', 'on', 'TickLabelInterpreter', 'none');
end
sgtitle(sprintf('Periodo de prueba (%s a %s), \\delta=%.2f, \\eta=%.2f', ...
    datestr(TEST_START, 'mmm-yyyy'), datestr(TEST_END, 'mmm-yyyy'), base_params.delta, base_params.eta));
saveas(gcf, fullfile(OUT_DIR, 'barras_metricas_prueba.png'));

fprintf('\nResultados guardados en la carpeta "%s".\n', OUT_DIR);


%% --- Funciones locales ---
function res = build_benchmark_results(data, N)
% Struct tipo `results` para comprar y mantener SPY sobre las MISMAS fechas
% de decision que los backtests (k = N..T-1): en la fecha k se "invierte"
% y se realiza el retorno de mercado del mes k+1.
    T = numel(data.dates);
    k = (N:(T - 1))';
    T_dec = numel(k);
    res.dates       = data.dates(k);
    res.growth_real = 1 + data.mkt_return(k + 1);
    res.wealth      = [1; cumprod(res.growth_real)];
    res.x           = ones(T_dec, 1);   % 100% en SPY
    res.x0          = zeros(T_dec, 1);
    res.turnover    = zeros(T_dec, 1);
    res.cost        = zeros(T_dec, 1);
    res.status      = repmat({'Solved'}, T_dec, 1);
    res.params      = struct('delta', NaN);
    res.violations  = [];
end


function row = metrics_row(modelo, periodo, m, r, r_sp, m_sp)
% Una fila de la tabla comparativa, con metricas relativas al S&P 500.
    C = cov(r, r_sp);
    beta = C(1, 2) / C(2, 2);
    rho  = corr(r, r_sp);
    te   = std(r - r_sp) * sqrt(12);   % tracking error anualizado
    row = table(modelo, periodo, m.wealth_final, m.CAGR, m.log_growth_mean, ...
        m.variance_monthly, m.max_drawdown, m.worst_month, m.VaR_loss, m.CVaR_loss, ...
        m.sharpe, m.sortino, m.calmar, m.turnover_total, m.cost_total, m.n_rebalances, ...
        m.Neff_mean, m.n_violations_delta, m.n_months, ...
        m.CAGR - m_sp.CAGR, m.max_drawdown - m_sp.max_drawdown, beta, rho, te, ...
        'VariableNames', {'modelo', 'periodo', 'riqueza_final', 'CAGR', 'log_crecimiento_medio', ...
            'varianza_mensual', 'max_drawdown', 'peor_mes', 'VaR_perdida', 'CVaR_perdida', ...
            'sharpe', 'sortino', 'calmar', 'turnover_total', 'costo_total', 'n_transacciones', ...
            'Neff_promedio', 'violaciones_delta', 'n_meses', ...
            'CAGR_menos_SP500', 'MDD_menos_SP500', 'beta_SP500', 'correlacion_SP500', ...
            'tracking_error_anual'});
end
