%% main_validation_grid.m
% Analisis de la malla delta-eta restringido al periodo de VALIDACION
% (Seccion 15.2 y 17.3 de la propuesta: enero 2015 - diciembre 2018).
% NO vuelve a correr ningun backtest: reusa los resultados ya guardados
% en results_eta_delta_grid_wdro/grid_delta_eta.mat y los recorta por
% fecha con extract_period_results.m. Esto es valido porque cada decision
% del backtest de origen movil solo mira hacia atras (ver el comentario
% en extract_period_results.m para el argumento completo).
%
% Genera exactamente el mismo tipo de salida que main_grid_delta_eta.m
% (heatmaps, tablas anchas de varianza/CVaR/turnover, tabla maestra,
% riqueza por delta, graficas de retornos) pero calculado SOLO sobre
% 2015-2018 -- para elegir (delta, eta) sin haber mirado 2019-2025.
%
% IMPORTANTE: este script es para EXPLORAR y ELEGIR parametros. Una vez
% elijas (delta, eta) a partir de esta salida, el paso siguiente es
% evaluar ESA UNICA combinacion sobre el periodo de prueba (2019-2025) --
% no volver a barrer toda la malla sobre el periodo de prueba, porque eso
% seria exactamente el "espionaje" que la Seccion 17.3 pide evitar.
%
% Requiere: haber corrido main_grid_delta_eta.m (o tener su .mat), y
% extract_period_results.m, compute_period_grid_matrices.m,
% matrix_to_wide_table.m, plot_heatmap.m, plot_wealth_by_delta.m,
% plot_returns_*.m en el path.

clear; clc; close all;

GRID_DIR = 'results_eta_delta_grid_wdro';
mat_path = fullfile(GRID_DIR, 'grid_delta_eta.mat');

if ~isfile(mat_path)
    error('main_validation_grid:notFound', ...
        ['No se encontro %s. Corre main_grid_delta_eta.m primero (o al ', ...
         'menos hasta el paso 5, el guardado del grid).'], mat_path);
end

load(mat_path, 'grid');
DELTA_GRID = grid.delta_grid;
ETA_GRID   = grid.eta_grid;

OUT_DIR = 'results_validacion_grid';
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

%% 1. Determinar el rango de fechas disponible y definir el periodo de validacion
% Se usa cualquier celda con resultados para conocer el rango real de
% datos (por si la descarga no llega exactamente hasta diciembre 2025).
any_result = [];
for i = 1:numel(DELTA_GRID)
    for j = 1:numel(ETA_GRID)
        if ~isempty(grid.results_wdro{i, j})
            any_result = grid.results_wdro{i, j};
            break
        end
    end
    if ~isempty(any_result)
        break
    end
end
if isempty(any_result)
    error('main_validation_grid:noResults', 'La malla guardada no tiene ninguna celda con resultados.');
end
realized_dates_full = dateshift(any_result.dates, 'end', 'month', 1);
DATA_START = min(realized_dates_full);
DATA_END   = max(realized_dates_full);

VALIDATION_START = max(datetime(2015,1,1), DATA_START);
VALIDATION_END   = min(datetime(2018,12,31), DATA_END);

fprintf('Rango de datos disponible: %s a %s.\n', datestr(DATA_START), datestr(DATA_END));
fprintf('Periodo de VALIDACION usado: %s a %s.\n', datestr(VALIDATION_START), datestr(VALIDATION_END));
if VALIDATION_END >= DATA_END
    warning('main_validation_grid:noTestPeriodLeft', ...
        ['El periodo de validacion llega hasta el final de los datos disponibles; ', ...
         'no queda periodo de prueba independiente. Verifica el rango de tu descarga.']);
end

%% 2. Matrices delta x eta restringidas a validacion (sin rerun)
pm_val = compute_period_grid_matrices(grid, VALIDATION_START, VALIDATION_END);
save(fullfile(OUT_DIR, 'pm_validacion.mat'), 'pm_val', 'VALIDATION_START', 'VALIDATION_END');

%% 3. Heatmaps (mismo set que main_grid_delta_eta.m, pero solo validacion)
period_tag = sprintf('(validacion %d-%d)', year(VALIDATION_START), year(VALIDATION_END));

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

%% 4. Tablas anchas (delta en filas, eta en columnas): varianza, CVaR, turnover, # transacciones
writetable(matrix_to_wide_table(pm_val.Variance, DELTA_GRID, ETA_GRID), ...
    fullfile(OUT_DIR, 'tabla_varianza_validacion.csv'));
writetable(matrix_to_wide_table(pm_val.CVaR, DELTA_GRID, ETA_GRID), ...
    fullfile(OUT_DIR, 'tabla_cvar_validacion.csv'));
writetable(matrix_to_wide_table(pm_val.Turnover, DELTA_GRID, ETA_GRID), ...
    fullfile(OUT_DIR, 'tabla_turnover_validacion.csv'));
writetable(matrix_to_wide_table(pm_val.NRebalances, DELTA_GRID, ETA_GRID), ...
    fullfile(OUT_DIR, 'tabla_n_transacciones_validacion.csv'));

%% 5. Tabla maestra (una fila por ejecucion), SOLO periodo de validacion
summary_table_val = build_grid_summary_table(grid, VALIDATION_START, VALIDATION_END);
writetable(summary_table_val, fullfile(OUT_DIR, 'tabla_maestra_metricas_validacion.csv'));

fprintf('\n=== Tabla maestra de VALIDACION, ordenada por CAGR descendente ===\n');
summary_sorted = sortrows(summary_table_val, 'CAGR', 'descend');
disp(summary_sorted(1:min(10, height(summary_sorted)), ...
    {'delta', 'eta', 'riqueza_final', 'CAGR', 'max_drawdown', 'varianza_mensual', ...
     'CVaR_perdida', 'turnover_total', 'n_transacciones'}));

%% 6. Riqueza acumulada para delta=0.90, todos los eta -- SOLO validacion
DELTA_WEALTH_PLOT = 0.90;
i_wp = find(DELTA_GRID == DELTA_WEALTH_PLOT, 1);
if ~isempty(i_wp)
    try
        plot_wealth_by_delta(grid, DELTA_WEALTH_PLOT, OUT_DIR, ...
            pm_val.sub_results(i_wp, :), period_tag);
    catch ME
        warning('main_validation_grid:wealthByDeltaFailed', ...
            'Fallo la grafica de riqueza por delta (delta=%.2f): %s', DELTA_WEALTH_PLOT, ME.message);
    end
else
    warning('main_validation_grid:deltaWealthPlotNotFound', ...
        'delta=%.2f no esta en la malla; se omite la grafica de riqueza por delta.', DELTA_WEALTH_PLOT);
end

%% 7. Graficas de retornos Y riqueza: comparacion explicita, SOLO validacion
% Mismo criterio que main_grid_delta_eta.m: delta=0.75 (nucleo del
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
    warning('main_validation_grid:noReturnsComparison', ...
        ['No hay resultados para delta=%.2f con los eta pedidos (%s) dentro del ', ...
         'periodo de validacion; se omiten las graficas de retornos/riqueza de esta seccion.'], ...
        DELTA_GRID(i_ref), mat2str(ETA_COMPARE));
else
    % Riqueza acumulada de todas las etas comparadas, mismo delta (la
    % pieza que faltaba antes de las graficas de retornos).
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
        legend('Location', 'best'); grid on;
        saveas(gcf, fullfile(OUT_DIR, 'riqueza_comparacion_eta_bajo_validacion.png'));
    catch ME
        warning('main_validation_grid:wealthComparisonFailed', ...
            'Fallo la grafica de riqueza de comparacion de eta: %s', ME.message);
    end

    try
        plot_returns_timeseries(results_compare, labels_compare, ...
            sprintf('Retornos mensuales, \\delta=%.2f %s', DELTA_GRID(i_ref), period_tag), OUT_DIR);
    catch ME
        warning('main_validation_grid:returnsTimeseriesFailed', 'Fallo el timeseries de retornos: %s', ME.message);
    end
    try
        plot_returns_boxplot(results_compare, labels_compare, ...
            sprintf('Distribucion de retornos, \\delta=%.2f %s', DELTA_GRID(i_ref), period_tag), OUT_DIR);
    catch ME
        warning('main_validation_grid:returnsBoxplotFailed', ...
            'Fallo el boxplot de retornos (revisa si tienes el Statistics Toolbox): %s', ME.message);
    end
    for k = 1:numel(results_compare)
        try
            plot_returns_bar(results_compare{k}, [labels_compare{k}, ' ', period_tag], OUT_DIR);
        catch ME
            warning('main_validation_grid:returnsBarFailed', ...
                'Fallo la barra de retornos para %s: %s', labels_compare{k}, ME.message);
        end
    end
end

fprintf('\n=== IMPORTANTE ===\n');
fprintf(['Estas salidas usan SOLO el periodo de validacion (%s a %s). ', ...
    'Elige (delta, eta) a partir de esta tabla/heatmaps. El periodo de ', ...
    'prueba (2019 en adelante) debe evaluarse UNA SOLA VEZ, con esa unica ', ...
    'combinacion ya elegida -- no vuelvas a barrer toda la malla sobre el ', ...
    'periodo de prueba.\n'], datestr(VALIDATION_START), datestr(VALIDATION_END));
fprintf('Resultados guardados en la carpeta "%s".\n', OUT_DIR);
