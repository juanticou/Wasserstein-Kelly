%% main_validation_grid_market.m
% Malla delta-eta de la GEOMETRIA 2 (retornos + retorno de mercado + VIX,
% build_transport_cost_market.m) evaluada SOLO en el periodo de
% VALIDACION (Seccion 15.2 y 17.3 de la propuesta: enero 2015 - diciembre
% 2018), con los pesos de la Geometria 2 fijos en la configuracion nucleo
% del Cuadro 8 (wR=0.70, wm=0.15, wv=0.15, wf=0).
%
% Es el equivalente de main_validation_grid.m (Geometria 1), con una
% diferencia: para la Geometria 2 no existe una corrida de la malla sobre
% el panel completo que se pueda recortar, asi que aqui los datos se
% recortan FISICAMENTE a diciembre 2018 (truncate_data.m) antes de correr
% ningun backtest -- el codigo nunca ve 2019 en adelante. Como cada
% decision del backtest de origen movil solo mira hacia atras, el
% resultado es identico al de correr sobre el panel completo y mirar solo
% hasta 2018.
%
% Se usa la MISMA malla (delta, eta) que main_grid_delta_eta.m, para que
% los heatmaps sean comparables celda a celda con los de
% results_validacion_grid/ (Geometria 1). Si existe
% results_validacion_grid/pm_validacion.mat, ademas se generan heatmaps
% de diferencia Geometria 2 - Geometria 1 y se verifica que la columna
% eta=0 coincida en ambas geometrias (con radio cero el costo de
% transporte no participa en la solucion).
%
% IMPORTANTE: este script es para EXPLORAR y ELEGIR (delta, eta). El
% periodo de prueba (2019-2025) se evalua DESPUES, una sola vez, con la
% combinacion elegida -- no se barre la malla sobre el periodo de prueba.
%
% UBICACION: Wasserstein-Kelly/wdro-market/ (mismo patron que
% main_geometria_mercado.m). Usa las funciones compartidas de la raiz y
% truncate_data.m de wdro-return/.
%
% Requiere: CVX + MOSEK, Statistics and Machine Learning Toolbox
% (boxplot, prctile dentro de compute_metrics.m).

clear; clc; close all;

%% 1. Configuracion y path
PROJECT_DIR = fileparts(mfilename('fullpath'));   % .../Wasserstein-Kelly/wdro-market
ROOT_DIR    = fileparts(PROJECT_DIR);              % .../Wasserstein-Kelly
addpath(PROJECT_DIR);
addpath(ROOT_DIR);
% Solo para truncate_data.m. Con '-end', las funciones de la raiz (p. ej.
% plot_heatmap.m) siguen teniendo prioridad sobre las de wdro-return/.
addpath(fullfile(ROOT_DIR, 'wdro-return'), '-end');

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
CSV_PATH = fullfile(ROOT_DIR, 'data', 'processed', 'monthly_panel.csv');

if ~isfile(CSV_PATH)
    error('main_validation_grid_market:csvNotFound', ...
        'No se encontro el archivo:\n  %s', CSV_PATH);
end

base_params.N       = 60;
base_params.tau     = 0.001;
base_params.xbar    = 0.25;
base_params.gamma   = 1;
base_params.solver  = 'mosek';
base_params.eps_esc = 1e-6;
% delta y eta se sobrescriben dentro de run_grid_delta_eta_market.m

% Pesos de la Geometria 2 (Cuadro 8, configuracion nucleo), fijos en toda la malla.
WEIGHTS = struct('wR', 0.70, 'wm', 0.15, 'wv', 0.15, 'wf', 0);
base_params.weights = WEIGHTS;

ALPHA = 0.95;

% Misma malla que main_grid_delta_eta.m (Geometria 1).
DELTA_GRID = [0.50, 0.60, 0.70, 0.75, 0.80, 0.90];
ETA_GRID   = [0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.10, 0.15, 0.30, 0.50, 1.00];

OUT_DIR = fullfile(PROJECT_DIR, 'results_validacion_grid_market');
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

% Resultados de validacion de la Geometria 1 (main_validation_grid.m), para comparar.
G1_PM_PATH = fullfile(ROOT_DIR, 'results_validacion_grid', 'pm_validacion.mat');

n_total = numel(DELTA_GRID) * numel(ETA_GRID);
fprintf('Malla Geometria 2: %d valores de delta x %d valores de eta = %d backtests.\n', ...
    numel(DELTA_GRID), numel(ETA_GRID), n_total);
fprintf('Pesos Geometria 2: wR=%.2f, wm=%.2f, wv=%.2f, wf=%.2f\n', ...
    WEIGHTS.wR, WEIGHTS.wm, WEIGHTS.wv, WEIGHTS.wf);

%% 2. Datos recortados al periodo de validacion
data = load_monthly_data(CSV_PATH, TICKERS);
VALIDATION_START = max(datetime(2015,1,1), min(data.dates));
VALIDATION_END   = datetime(2018,12,31);
data_val = truncate_data(data, VALIDATION_END);

fprintf('Datos recortados a %s (%d meses). Periodo de VALIDACION: %s a %s.\n', ...
    datestr(VALIDATION_END), numel(data_val.dates), datestr(VALIDATION_START), datestr(VALIDATION_END));

%% 3. Prueba de tiempo en una sola fecha, para estimar el total
h0_test  = [1; zeros(numel(TICKERS), 1)];
R_test   = data_val.R(1:base_params.N, :);
mkt_test = data_val.mkt_return(1:base_params.N);
vix_test = data_val.vix(1:base_params.N);
rf_test  = data_val.rf_return(base_params.N);
C_test   = build_transport_cost_market(R_test, mkt_test, vix_test, WEIGHTS, base_params.eps_esc);
rho_test = compute_rho(C_test, ETA_GRID(end));

tic;
solve_wdro_kelly(h0_test, R_test, rf_test, base_params.tau, base_params.xbar, ...
    base_params.gamma, median(DELTA_GRID), C_test, rho_test, base_params.solver);
t_one = toc;

n_dates_total = numel(data_val.dates) - base_params.N;
fprintf(['Tiempo de una sola fecha (Geometria 2): %.2f s. Estimado por cada (delta,eta) ', ...
    '(%d fechas): ~%.1f min. Malla completa: ~%.1f min.\n'], ...
    t_one, n_dates_total, t_one * n_dates_total / 60, n_total * t_one * n_dates_total / 60);

%% 4. Correr la malla (solo WDRO Geometria 2, eta=0 como baseline)
grid = run_grid_delta_eta_market(data_val, base_params, DELTA_GRID, ETA_GRID, ALPHA);
save(fullfile(OUT_DIR, 'grid_delta_eta_market_validacion.mat'), 'grid', 'WEIGHTS', ...
    'VALIDATION_START', 'VALIDATION_END');

%% 5. Matrices delta x eta restringidas a validacion
pm_val = compute_period_grid_matrices(grid, VALIDATION_START, VALIDATION_END);
save(fullfile(OUT_DIR, 'pm_validacion_market.mat'), 'pm_val', 'WEIGHTS', ...
    'VALIDATION_START', 'VALIDATION_END');

%% 6. Heatmaps (mismo set que main_validation_grid.m)
period_tag = sprintf('(G2 mercado+VIX, validacion %d-%d)', year(VALIDATION_START), year(VALIDATION_END));

plot_heatmap(pm_val.feas, ETA_GRID, DELTA_GRID, ...
    ['Factibilidad WDRO ', period_tag], 'Fraccion Solved', '%.2f', ...
    OUT_DIR, 'heatmap_factibilidad_validacion.png');

plot_heatmap(pm_val.Wealth, ETA_GRID, DELTA_GRID, ...
    ['Riqueza final W_T/W_0 ', period_tag], 'Riqueza final', '%.2f', ...
    OUT_DIR, 'heatmap_riqueza_final_validacion.png');

plot_heatmap(100 * pm_val.Variance, ETA_GRID, DELTA_GRID, ...
    ['Varianza de retornos mensuales ', period_tag, '  [x100]'], 'Varianza x100', '%.3f', ...
    OUT_DIR, 'heatmap_varianza_validacion.png');

plot_heatmap(100 * pm_val.CVaR, ETA_GRID, DELTA_GRID, ...
    sprintf('CVaR %.0f%% de perdida mensual %s  [pp]', 100*pm_val.alpha, period_tag), ...
    'CVaR (pp)', '%.2f', OUT_DIR, 'heatmap_cvar_validacion.png');

plot_heatmap(pm_val.Turnover, ETA_GRID, DELTA_GRID, ...
    ['Turnover acumulado ', period_tag], 'Turnover total', '%.2f', ...
    OUT_DIR, 'heatmap_turnover_validacion.png');

plot_heatmap(pm_val.NRebalances, ETA_GRID, DELTA_GRID, ...
    ['Numero de meses con transaccion ', period_tag], '# transacciones', '%.0f', ...
    OUT_DIR, 'heatmap_n_transacciones_validacion.png');

if ~isempty(grid.baseline_col)
    plot_heatmap(100 * pm_val.CAGR_diff, ETA_GRID, DELTA_GRID, ...
        ['CAGR(WDRO) - CAGR(\eta=0) ', period_tag, '  [pp]'], ...
        'Diferencia de CAGR (pp)', '%.2f', OUT_DIR, 'heatmap_cagr_diff_validacion.png');

    plot_heatmap(100 * pm_val.MDD_diff, ETA_GRID, DELTA_GRID, ...
        ['MaxDrawdown(WDRO) - MaxDrawdown(\eta=0) ', period_tag, '  [pp]'], ...
        'Diferencia de MDD (pp, negativo = mejor)', '%.2f', OUT_DIR, 'heatmap_mdd_diff_validacion.png');
end

%% 7. Tablas anchas (delta en filas, eta en columnas)
writetable(matrix_to_wide_table(pm_val.Variance, DELTA_GRID, ETA_GRID), ...
    fullfile(OUT_DIR, 'tabla_varianza_validacion.csv'));
writetable(matrix_to_wide_table(pm_val.CVaR, DELTA_GRID, ETA_GRID), ...
    fullfile(OUT_DIR, 'tabla_cvar_validacion.csv'));
writetable(matrix_to_wide_table(pm_val.Turnover, DELTA_GRID, ETA_GRID), ...
    fullfile(OUT_DIR, 'tabla_turnover_validacion.csv'));
writetable(matrix_to_wide_table(pm_val.NRebalances, DELTA_GRID, ETA_GRID), ...
    fullfile(OUT_DIR, 'tabla_n_transacciones_validacion.csv'));

%% 8. Tabla maestra (una fila por ejecucion), SOLO periodo de validacion
summary_table_val = build_grid_summary_table(grid, VALIDATION_START, VALIDATION_END);
writetable(summary_table_val, fullfile(OUT_DIR, 'tabla_maestra_metricas_validacion.csv'));

fprintf('\n=== Tabla maestra de VALIDACION (Geometria 2), ordenada por CAGR descendente ===\n');
summary_sorted = sortrows(summary_table_val, 'CAGR', 'descend');
disp(summary_sorted(1:min(10, height(summary_sorted)), ...
    {'delta', 'eta', 'riqueza_final', 'CAGR', 'max_drawdown', 'varianza_mensual', ...
     'CVaR_perdida', 'turnover_total', 'n_transacciones'}));

%% 9. Comparacion con la Geometria 1 en validacion (sin correr nada mas)
if isfile(G1_PM_PATH)
    S_g1  = load(G1_PM_PATH, 'pm_val');
    pm_g1 = S_g1.pm_val;
    same_grid = isequal(pm_g1.delta_grid, DELTA_GRID) && isequal(pm_g1.eta_grid, ETA_GRID);
    if ~same_grid
        warning('main_validation_grid_market:gridMismatch', ...
            ['La malla de %s no coincide con la de este script; se omite la ', ...
             'comparacion Geometria 2 - Geometria 1.'], G1_PM_PATH);
    else
        tag_cmp = sprintf('(validacion %d-%d)', year(VALIDATION_START), year(VALIDATION_END));
        plot_heatmap(100 * (pm_val.CAGR - pm_g1.CAGR), ETA_GRID, DELTA_GRID, ...
            ['CAGR(G2) - CAGR(G1) ', tag_cmp, '  [pp]'], 'pp (positivo = G2 mejor)', '%.2f', ...
            OUT_DIR, 'heatmap_cagr_G2_menos_G1_validacion.png');
        plot_heatmap(100 * (pm_val.MDD - pm_g1.MDD), ETA_GRID, DELTA_GRID, ...
            ['MaxDrawdown(G2) - MaxDrawdown(G1) ', tag_cmp, '  [pp]'], 'pp (negativo = G2 mejor)', '%.2f', ...
            OUT_DIR, 'heatmap_mdd_G2_menos_G1_validacion.png');
        plot_heatmap(pm_val.Wealth - pm_g1.Wealth, ETA_GRID, DELTA_GRID, ...
            ['Riqueza final G2 - G1 ', tag_cmp], 'Diferencia W_T/W_0', '%.3f', ...
            OUT_DIR, 'heatmap_riqueza_G2_menos_G1_validacion.png');

        [D, E] = ndgrid(DELTA_GRID, ETA_GRID);
        cmp_table = table(D(:), E(:), pm_g1.Wealth(:), pm_val.Wealth(:), ...
            pm_g1.CAGR(:), pm_val.CAGR(:), pm_val.CAGR(:) - pm_g1.CAGR(:), ...
            pm_g1.MDD(:), pm_val.MDD(:), pm_val.MDD(:) - pm_g1.MDD(:), ...
            pm_g1.CVaR(:), pm_val.CVaR(:), pm_g1.feas(:), pm_val.feas(:), ...
            'VariableNames', {'delta', 'eta', 'riqueza_G1', 'riqueza_G2', ...
                'CAGR_G1', 'CAGR_G2', 'CAGR_G2_menos_G1', ...
                'MDD_G1', 'MDD_G2', 'MDD_G2_menos_G1', ...
                'CVaR_G1', 'CVaR_G2', 'factibilidad_G1', 'factibilidad_G2'});
        writetable(cmp_table, fullfile(OUT_DIR, 'comparacion_G2_vs_G1_validacion.csv'));

        % Verificacion cruzada: en eta=0 ambas geometrias deben coincidir.
        if ~isempty(grid.baseline_col) && ~isempty(pm_g1.baseline_col)
            diff_eta0 = max(abs(pm_val.Wealth(:, grid.baseline_col) - pm_g1.Wealth(:, pm_g1.baseline_col)));
            fprintf(['\nVerificacion eta=0: max |riqueza_final G2 - G1| sobre los delta = %.3e ', ...
                '(deberia ser ~0).\n'], diff_eta0);
            if diff_eta0 > 1e-4
                warning('main_validation_grid_market:eta0Mismatch', ...
                    ['Las geometrias no coinciden en eta=0 (diferencia = %.3e). Revisar ', ...
                     'build_transport_cost_market.m o el recorte de datos antes de confiar ', ...
                     'en la comparacion.'], diff_eta0);
            end
        end
    end
else
    warning('main_validation_grid_market:noG1Validation', ...
        ['No se encontro %s (salida de main_validation_grid.m); se omite la ', ...
         'comparacion Geometria 2 - Geometria 1.'], G1_PM_PATH);
end

%% 10. Riqueza acumulada para delta=0.90, todos los eta -- SOLO validacion
DELTA_WEALTH_PLOT = 0.90;
i_wp = find(DELTA_GRID == DELTA_WEALTH_PLOT, 1);
if ~isempty(i_wp)
    try
        plot_wealth_by_delta(grid, DELTA_WEALTH_PLOT, OUT_DIR, ...
            pm_val.sub_results(i_wp, :), period_tag);
    catch ME
        warning('main_validation_grid_market:wealthByDeltaFailed', ...
            'Fallo la grafica de riqueza por delta (delta=%.2f): %s', DELTA_WEALTH_PLOT, ME.message);
    end
else
    warning('main_validation_grid_market:deltaWealthPlotNotFound', ...
        'delta=%.2f no esta en la malla; se omite la grafica de riqueza por delta.', DELTA_WEALTH_PLOT);
end

%% 11. Graficas de retornos y riqueza: comparacion de eta cerca de cero, SOLO validacion
% Mismo criterio que main_validation_grid.m: delta=0.75 (nucleo del
% Cuadro 8) como referencia, comparando eta = 0, 0.01, 0.05, 0.15.
DELTA_REF = 0.75;
ETA_COMPARE = [0, 0.01, 0.05, 0.15];

i_ref = find(DELTA_GRID == DELTA_REF, 1);
if isempty(i_ref)
    i_ref = 1;
end

results_compare = {};
labels_compare  = {};
for e = 1:numel(ETA_COMPARE)
    j_e = find(ETA_GRID == ETA_COMPARE(e), 1);
    if isempty(j_e)
        continue
    end
    r_e = pm_val.sub_results{i_ref, j_e};
    if isempty(r_e)
        continue
    end
    results_compare{end+1} = r_e; %#ok<SAGROW>
    labels_compare{end+1}  = sprintf('\\eta=%.2f', ETA_GRID(j_e)); %#ok<SAGROW>
end

if isempty(results_compare)
    warning('main_validation_grid_market:noReturnsComparison', ...
        ['No hay resultados para delta=%.2f con los eta pedidos (%s) dentro del ', ...
         'periodo de validacion; se omiten las graficas de retornos/riqueza de esta seccion.'], ...
        DELTA_GRID(i_ref), mat2str(ETA_COMPARE));
else
    try
        figure('Position', [100, 100, 950, 550]);
        hold on;
        colors = lines(numel(results_compare));
        for k = 1:numel(results_compare)
            r_k = results_compare{k};
            plot([r_k.dates(1); r_k.dates], r_k.wealth, 'LineWidth', 1.4, ...
                'DisplayName', labels_compare{k}, 'Color', colors(k, :));
        end
        hold off;
        title(sprintf('Riqueza acumulada, \\delta=%.2f -- comparacion de \\eta cerca de cero %s', ...
            DELTA_GRID(i_ref), period_tag));
        xlabel('Fecha'); ylabel('W_t / W_0');
        legend('Location', 'best');
        set(gca, 'XGrid', 'on', 'YGrid', 'on');   % no "grid on": `grid` es la variable de la malla
        saveas(gcf, fullfile(OUT_DIR, 'riqueza_comparacion_eta_bajo_validacion.png'));
    catch ME
        warning('main_validation_grid_market:wealthComparisonFailed', ...
            'Fallo la grafica de riqueza de comparacion de eta: %s', ME.message);
    end

    try
        plot_returns_timeseries(results_compare, labels_compare, ...
            sprintf('Retornos mensuales, \\delta=%.2f %s', DELTA_GRID(i_ref), period_tag), OUT_DIR);
    catch ME
        warning('main_validation_grid_market:returnsTimeseriesFailed', 'Fallo el timeseries de retornos: %s', ME.message);
    end
    try
        plot_returns_boxplot(results_compare, labels_compare, ...
            sprintf('Distribucion de retornos, \\delta=%.2f %s', DELTA_GRID(i_ref), period_tag), OUT_DIR);
    catch ME
        warning('main_validation_grid_market:returnsBoxplotFailed', ...
            'Fallo el boxplot de retornos (revisa si tienes el Statistics Toolbox): %s', ME.message);
    end
    for k = 1:numel(results_compare)
        try
            plot_returns_bar(results_compare{k}, [labels_compare{k}, ' ', period_tag], OUT_DIR);
        catch ME
            warning('main_validation_grid_market:returnsBarFailed', ...
                'Fallo la barra de retornos para %s: %s', labels_compare{k}, ME.message);
        end
    end
end

fprintf('\n=== IMPORTANTE ===\n');
fprintf(['Estas salidas usan SOLO el periodo de validacion (%s a %s). ', ...
    'Elige (delta, eta) de la Geometria 2 a partir de esta tabla/heatmaps. El periodo de ', ...
    'prueba (2019 en adelante) debe evaluarse UNA SOLA VEZ, con esa unica ', ...
    'combinacion ya elegida -- no vuelvas a barrer toda la malla sobre el ', ...
    'periodo de prueba.\n'], datestr(VALIDATION_START), datestr(VALIDATION_END));
fprintf('Resultados guardados en la carpeta "%s".\n', OUT_DIR);
