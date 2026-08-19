%% main_nominal_kelly.m
% Ejecuta el benchmark Kelly nominal con costos de transaccion sobre el
% panel mensual, siguiendo las Secciones 6, 7 y 17 de la propuesta.
%
% Requiere:
%   - CVX instalado y en el path (con MOSEK, o cambiar cvx_solver en
%     solve_nominal_kelly.m por 'SCS'/'ECOS' si MOSEK no esta disponible).
%   - data/processed/monthly_panel.csv generado por el pipeline de Python
%     (01_import_data.py), con columnas: <tickers>, mkt_return, vix, rf_return.

clear; clc; close all;

%% 1. Configuracion (Cuadro 8 de la propuesta, configuracion nucleo)
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};

% Ancla la ruta del CSV a la carpeta donde vive este script, sin importar
% cual sea el "Current Folder" de MATLAB en el momento de ejecutarlo.
PROJECT_DIR = fileparts(mfilename('fullpath'));
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');

if ~isfile(CSV_PATH)
    error('main_nominal_kelly:csvNotFound', ...
        ['No se encontro el archivo:\n  %s\n' ...
         'Verifica que monthly_panel.csv este en data\\processed\\ dentro de ' ...
         'la misma carpeta que main_nominal_kelly.m.'], CSV_PATH);
end

params.N     = 60;      % meses en la ventana movil
params.tau   = 0.001;   % 10 puntos basicos por unidad negociada
params.xbar  = 0.25;    % limite maximo por accion
params.gamma = 1;       % sin reduccion adicional de exposicion
params.delta = 0.75;    % cota de supervivencia (verificar factibilidad)

%% 2. Cargar datos
data = load_monthly_data(CSV_PATH, TICKERS);
fprintf('Panel cargado: %d meses, %d activos riesgosos (%s a %s)\n', ...
    numel(data.dates), numel(TICKERS), ...
    datestr(data.dates(1), 'mmm-yyyy'), datestr(data.dates(end), 'mmm-yyyy'));

%% 3. Correr el backtest de Kelly nominal con costos
results = run_backtest_nominal_kelly(data, params);

%% 4. Metricas nucleo (Seccion 19)
metrics = compute_metrics(results);
disp(metrics.table);

if metrics.n_violations_delta > 0
    fprintf(['\nAdvertencia: %d violaciones fuera de muestra de delta=%.2f ', ...
        '(minimo factor de crecimiento realizado = %.4f).\n'], ...
        metrics.n_violations_delta, metrics.delta_used, metrics.min_growth_real);
end
if metrics.n_solver_failed > 0
    fprintf('Advertencia: %d fechas con cvx_status distinto de "Solved".\n', ...
        metrics.n_solver_failed);
end

%% 5. Guardar resultados
if ~exist('results_out', 'dir')
    mkdir('results_out');
end
save(fullfile('results_out', 'nominal_kelly_backtest.mat'), 'results', 'metrics', 'params');

resultsTable = table(results.dates, results.wealth(2:end), results.growth_real, ...
    results.turnover, results.cost, ...
    'VariableNames', {'Date', 'Wealth', 'GrowthReal', 'Turnover', 'Cost'});
writetable(resultsTable, fullfile('results_out', 'nominal_kelly_timeseries.csv'));

weightsTable = array2table([results.x0, results.x], ...
    'VariableNames', [{'RiskFree'}, TICKERS]);
weightsTable.Date = results.dates;
weightsTable = movevars(weightsTable, 'Date', 'Before', 1);
writetable(weightsTable, fullfile('results_out', 'nominal_kelly_weights.csv'));

%% 6. Grafica de riqueza acumulada
figure('Position', [100, 100, 900, 500]);
plot([results.dates(1); results.dates], results.wealth, 'LineWidth', 1.5);
title('Riqueza acumulada - Kelly nominal con costos (benchmark)');
xlabel('Fecha'); ylabel('W_t / W_0');
grid on;
saveas(gcf, fullfile('results_out', 'nominal_kelly_wealth.png'));

fprintf('\nResultados guardados en la carpeta "results_out".\n');%% main_nominal_kelly.m
% Ejecuta el benchmark Kelly nominal con costos de transaccion sobre el
% panel mensual, siguiendo las Secciones 6, 7 y 17 de la propuesta.
%
% Requiere:
%   - CVX instalado y en el path (con MOSEK, o cambiar cvx_solver en
%     solve_nominal_kelly.m por 'SCS'/'ECOS' si MOSEK no esta disponible).
%   - data/processed/monthly_panel.csv generado por el pipeline de Python
%     (01_import_data.py), con columnas: <tickers>, mkt_return, vix, rf_return.

clear; clc; close all;

%% 1. Configuracion (Cuadro 8 de la propuesta, configuracion nucleo)
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
CSV_PATH = fullfile('data', 'processed', 'monthly_panel.csv');

params.N     = 60;      % meses en la ventana movil
params.tau   = 0.001;   % 10 puntos basicos por unidad negociada
params.xbar  = 0.25;    % limite maximo por accion
params.gamma = 1;       % sin reduccion adicional de exposicion
params.delta = 0.75;    % cota de supervivencia (verificar factibilidad)

%% 2. Cargar datos
data = load_monthly_data(CSV_PATH, TICKERS);
fprintf('Panel cargado: %d meses, %d activos riesgosos (%s a %s)\n', ...
    numel(data.dates), numel(TICKERS), ...
    datestr(data.dates(1), 'mmm-yyyy'), datestr(data.dates(end), 'mmm-yyyy'));

%% 3. Correr el backtest de Kelly nominal con costos
results = run_backtest_nominal_kelly(data, params);

%% 4. Metricas nucleo (Seccion 19)
metrics = compute_metrics(results);
disp(metrics.table);

if metrics.n_violations_delta > 0
    fprintf(['\nAdvertencia: %d violaciones fuera de muestra de delta=%.2f ', ...
        '(minimo factor de crecimiento realizado = %.4f).\n'], ...
        metrics.n_violations_delta, metrics.delta_used, metrics.min_growth_real);
end
if metrics.n_solver_failed > 0
    fprintf('Advertencia: %d fechas con cvx_status distinto de "Solved".\n', ...
        metrics.n_solver_failed);
end

%% 5. Guardar resultados
if ~exist('results_out', 'dir')
    mkdir('results_out');
end
save(fullfile('results_out', 'nominal_kelly_backtest.mat'), 'results', 'metrics', 'params');

resultsTable = table(results.dates, results.wealth(2:end), results.growth_real, ...
    results.turnover, results.cost, ...
    'VariableNames', {'Date', 'Wealth', 'GrowthReal', 'Turnover', 'Cost'});
writetable(resultsTable, fullfile('results_out', 'nominal_kelly_timeseries.csv'));

weightsTable = array2table([results.x0, results.x], ...
    'VariableNames', [{'RiskFree'}, TICKERS]);
weightsTable.Date = results.dates;
weightsTable = movevars(weightsTable, 'Date', 'Before', 1);
writetable(weightsTable, fullfile('results_out', 'nominal_kelly_weights.csv'));

%% 6. Grafica de riqueza acumulada
figure('Position', [100, 100, 900, 500]);
plot([results.dates(1); results.dates], results.wealth, 'LineWidth', 1.5);
title('Riqueza acumulada - Kelly nominal con costos (benchmark)');
xlabel('Fecha'); ylabel('W_t / W_0');
grid on;
saveas(gcf, fullfile('results_out', 'nominal_kelly_wealth.png'));

fprintf('\nResultados guardados en la carpeta "results_out".\n');
