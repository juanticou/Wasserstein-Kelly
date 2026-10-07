%% main_geometria_mercado.m
% Ejecuta y compara la Geometria 1 (solo retornos, build_transport_cost.m)
% contra la Geometria 2 (retornos + retorno de mercado + VIX,
% build_transport_cost_market.m) -- la pregunta central del proyecto
% (Seccion 14.2 de la propuesta).
%
% Se corre en delta=0.90 (el que mostro mejor desempeno en la malla
% delta-eta ya explorada) sobre la malla nucleo de eta del Cuadro 8:
% {0, 0.05, 0.15, 0.30}. eta=0 sirve como verificacion cruzada adicional:
% con radio cero ambas geometrias deben coincidir (el costo de transporte
% no importa si no se transporta nada), asi que si difieren ahi hay un
% error a corregir antes de confiar en el resto.
%
% UBICACION EN DISCO: este archivo vive en Wasserstein-Kelly/wdro-market/,
% una subcarpeta DISTINTA de donde estan los demas scripts del proyecto
% (main_nominal_kelly.m, main_grid_delta_eta.m, etc., que se quedan en
% Wasserstein-Kelly/ raiz). Estructura esperada:
%
%   Wasserstein-Kelly/
%   |-- data/processed/monthly_panel.csv
%   |-- solve_wdro_kelly.m, compute_metrics.m, load_monthly_data.m,
%   |   build_transport_cost.m, standardize_median_iqr.m, compute_rho.m,
%   |   plot_returns_*.m, plot_heatmap.m, ... (todo lo compartido)
%   |-- main_nominal_kelly.m, main_grid_delta_eta.m, ... (Geometria 1)
%   `-- wdro-market/
%       |-- build_transport_cost_market.m
%       |-- run_backtest_wdro_kelly_market.m
%       `-- main_geometria_mercado.m   (este archivo)
%
% Por eso ROOT_DIR (mas abajo) sube UN NIVEL desde la carpeta de este
% script para encontrar data/ y las funciones compartidas, y se agregan
% ambas carpetas al path -- asi el script funciona sin importar cual sea
% el "Current Folder" de MATLAB al momento de correrlo.
%
% Requiere: CVX + MOSEK, y todos los .m compartidos del proyecto en
% Wasserstein-Kelly/ raiz.

clear; clc; close all;

%% 1. Configuracion y path
PROJECT_DIR = fileparts(mfilename('fullpath'));   % .../Wasserstein-Kelly/wdro-market
ROOT_DIR    = fileparts(PROJECT_DIR);              % .../Wasserstein-Kelly
addpath(PROJECT_DIR);   % este propio folder (build_transport_cost_market.m, etc.)
addpath(ROOT_DIR);      % lo compartido (solve_wdro_kelly.m, compute_metrics.m, ...)

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
CSV_PATH = fullfile(ROOT_DIR, 'data', 'processed', 'monthly_panel.csv');

if ~isfile(CSV_PATH)
    error('main_geometria_mercado:csvNotFound', ...
        ['No se encontro el archivo:\n  %s\n', ...
         'Verifica que data/processed/monthly_panel.csv este en la carpeta ', ...
         'Wasserstein-Kelly (raiz), no dentro de wdro-market.'], CSV_PATH);
end

base_params.N       = 60;
base_params.tau     = 0.001;
base_params.xbar    = 0.25;
base_params.gamma   = 1;
base_params.solver  = 'mosek';
base_params.eps_esc = 1e-6;
base_params.delta   = 0.90;   % el delta con mejor desempeno en la malla previa

ALPHA = 0.95;

% Pesos de la Geometria 2 (Cuadro 8, configuracion nucleo): retornos,
% mercado, VIX, tasa. La tasa queda en 0 (no se usa DGS3MO en la
% geometria del nucleo, solo como r^f_k -- ver Seccion 15.7-15.8).
WEIGHTS = struct('wR', 0.70, 'wm', 0.15, 'wv', 0.15, 'wf', 0);

ETA_GRID = [0, 0.05, 0.15, 0.30];   % malla nucleo del Cuadro 8

% Los resultados quedan DENTRO de wdro-market/, sin importar cual sea el
% Current Folder de MATLAB al correr el script.
OUT_DIR = fullfile(PROJECT_DIR, 'results_geometria_mercado');
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

fprintf('Comparacion Geometria 1 (retornos) vs. Geometria 2 (mercado+VIX), delta=%.2f, %d valores de eta.\n', ...
    base_params.delta, numel(ETA_GRID));
fprintf('Pesos Geometria 2: wR=%.2f, wm=%.2f, wv=%.2f, wf=%.2f\n', ...
    WEIGHTS.wR, WEIGHTS.wm, WEIGHTS.wv, WEIGHTS.wf);

%% 2. Cargar datos (incluye mkt_return y vix, necesarios para Geometria 2)
data = load_monthly_data(CSV_PATH, TICKERS);

%% 3. Prueba de tiempo en una sola fecha para cada geometria
h0_test = [1; zeros(numel(TICKERS), 1)];
R_test  = data.R(1:base_params.N, :);
mkt_test = data.mkt_return(1:base_params.N);
vix_test = data.vix(1:base_params.N);
rf_test = data.rf_return(base_params.N);

C1_test = build_transport_cost(R_test, base_params.eps_esc);
rho1_test = compute_rho(C1_test, ETA_GRID(end));
tic;
solve_wdro_kelly(h0_test, R_test, rf_test, base_params.tau, base_params.xbar, ...
    base_params.gamma, base_params.delta, C1_test, rho1_test, base_params.solver);
t_geo1 = toc;

C2_test = build_transport_cost_market(R_test, mkt_test, vix_test, WEIGHTS, base_params.eps_esc);
rho2_test = compute_rho(C2_test, ETA_GRID(end));
tic;
solve_wdro_kelly(h0_test, R_test, rf_test, base_params.tau, base_params.xbar, ...
    base_params.gamma, base_params.delta, C2_test, rho2_test, base_params.solver);
t_geo2 = toc;

n_dates_total = numel(data.dates) - base_params.N - 1;
n_runs = 2 * numel(ETA_GRID);   % 2 geometrias x los eta de la malla
t_total_est = (t_geo1 + t_geo2) * numel(ETA_GRID) * n_dates_total / 2;
fprintf(['Tiempo de una fecha -- Geometria 1: %.2f s, Geometria 2: %.2f s. ', ...
    'Estimado total (%d corridas x %d fechas): ~%.1f min.\n'], ...
    t_geo1, t_geo2, n_runs, n_dates_total, t_total_est / 60);

%% 4. Correr ambas geometrias para cada eta
results_geo1 = cell(numel(ETA_GRID), 1);   % solo retornos
results_geo2 = cell(numel(ETA_GRID), 1);   % mercado + VIX
metrics_geo1 = cell(numel(ETA_GRID), 1);
metrics_geo2 = cell(numel(ETA_GRID), 1);

for e = 1:numel(ETA_GRID)
    eta_e = ETA_GRID(e);
    p = base_params;
    p.eta = eta_e;

    fprintf('\n--- eta = %.2f ---\n', eta_e);

    fprintf('  Geometria 1 (retornos) ... ');
    r1 = run_backtest_wdro_kelly(data, p);
    m1 = compute_metrics(r1, ALPHA);
    results_geo1{e} = r1;
    metrics_geo1{e} = m1;
    fprintf('riqueza final = %.4f | CAGR = %.2f%% | MDD = %.2f%%\n', ...
        m1.wealth_final, 100*m1.CAGR, 100*m1.max_drawdown);

    fprintf('  Geometria 2 (mercado+VIX) ... ');
    p2 = p;
    p2.weights = WEIGHTS;
    r2 = run_backtest_wdro_kelly_market(data, p2);
    m2 = compute_metrics(r2, ALPHA);
    results_geo2{e} = r2;
    metrics_geo2{e} = m2;
    fprintf('riqueza final = %.4f | CAGR = %.2f%% | MDD = %.2f%%\n', ...
        m2.wealth_final, 100*m2.CAGR, 100*m2.max_drawdown);
end

% Verificacion cruzada: en eta=0 ambas geometrias deben coincidir (el
% radio es cero, no se transporta nada, asi que el costo de transporte
% no participa en la solucion).
if ETA_GRID(1) == 0
    diff_eta0 = abs(metrics_geo1{1}.wealth_final - metrics_geo2{1}.wealth_final);
    fprintf(['\nVerificacion eta=0: |riqueza_final Geometria 1 - Geometria 2| = %.3e ', ...
        '(deberia ser ~0).\n'], diff_eta0);
    if diff_eta0 > 1e-4
        warning('main_geometria_mercado:eta0Mismatch', ...
            ['Las geometrias no coinciden en eta=0 (diferencia = %.3e). ', ...
             'Revisar build_transport_cost_market.m antes de confiar en la comparacion.'], ...
            diff_eta0);
    end
end

%% 5. Guardar resultados crudos
save(fullfile(OUT_DIR, 'geometria_mercado_vs_retornos.mat'), ...
    'results_geo1', 'results_geo2', 'metrics_geo1', 'metrics_geo2', ...
    'ETA_GRID', 'base_params', 'WEIGHTS');

%% 6. Tabla comparativa (una fila por eta x geometria)
rows = {};
for e = 1:numel(ETA_GRID)
    for g = 1:2
        if g == 1
            m = metrics_geo1{e}; geo_label = "retornos";
        else
            m = metrics_geo2{e}; geo_label = "mercado_vix";
        end
        row = table(ETA_GRID(e), geo_label, m.wealth_final, m.CAGR, ...
            m.variance_monthly, m.max_drawdown, m.CVaR_loss, ...
            m.turnover_total, m.n_rebalances, m.Neff_mean, ...
            'VariableNames', {'eta', 'geometria', 'riqueza_final', 'CAGR', ...
                'varianza_mensual', 'max_drawdown', 'CVaR_perdida', ...
                'turnover_total', 'n_transacciones', 'Neff_promedio'});
        rows{end+1} = row; %#ok<SAGROW>
    end
end
comparison_table = vertcat(rows{:});
writetable(comparison_table, fullfile(OUT_DIR, 'comparacion_geometrias.csv'));
disp(comparison_table);

%% 7. Grafica de riqueza: ambas geometrias, todos los eta
figure('Position', [100, 100, 1000, 600]);
hold on;
colors = lines(numel(ETA_GRID));
for e = 1:numel(ETA_GRID)
    r1 = results_geo1{e};
    r2 = results_geo2{e};
    plot([r1.dates(1); r1.dates], r1.wealth, '-', 'LineWidth', 1.3, ...
        'Color', colors(e, :), 'DisplayName', sprintf('\\eta=%.2f, retornos', ETA_GRID(e)));
    plot([r2.dates(1); r2.dates], r2.wealth, '--', 'LineWidth', 1.3, ...
        'Color', colors(e, :), 'DisplayName', sprintf('\\eta=%.2f, mercado+VIX', ETA_GRID(e)));
end
hold off;
title(sprintf('Riqueza acumulada: Geometria 1 (linea solida) vs. Geometria 2 (punteada), \\delta=%.2f', ...
    base_params.delta));
xlabel('Fecha'); ylabel('W_t / W_0');
legend('Location', 'best', 'NumColumns', 2);
grid on;
saveas(gcf, fullfile(OUT_DIR, 'riqueza_geometria1_vs_geometria2.png'));

%% 8. Graficas de retornos para eta=0.15 (el segundo valor nucleo, radio moderado)
ETA_FOCUS = 0.15;
e_focus = find(ETA_GRID == ETA_FOCUS, 1);
if ~isempty(e_focus)
    label1 = sprintf('Retornos (\\eta=%.2f)', ETA_FOCUS);
    label2 = sprintf('Mercado+VIX (\\eta=%.2f)', ETA_FOCUS);
    plot_returns_timeseries({results_geo1{e_focus}, results_geo2{e_focus}}, ...
        {label1, label2}, sprintf('Retornos mensuales, \\delta=%.2f, \\eta=%.2f', ...
        base_params.delta, ETA_FOCUS), OUT_DIR);
    plot_returns_boxplot({results_geo1{e_focus}, results_geo2{e_focus}}, ...
        {label1, label2}, sprintf('Distribucion de retornos, \\delta=%.2f, \\eta=%.2f', ...
        base_params.delta, ETA_FOCUS), OUT_DIR);
end

fprintf('\nResultados guardados en la carpeta "%s".\n', OUT_DIR);
