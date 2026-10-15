%% main_wdro_hypercube.m
% Ejecuta y compara el modelo WDRO-hipercubo (adversario con soporte
% ampliado a escenarios sinteticos del hipercubo de la ventana,
% solve_wdro_kelly_hypercube.m) contra el Wasserstein-Kelly nucleo
% (Geometria 1, solo escenarios historicos, solve_wdro_kelly.m).
%
% ADVERTENCIAS METODOLOGICAS antes de interpretar los resultados:
%   1. El muestreo del hipercubo es independiente por activo (ver
%      sample_hypercube_scenarios.m) -- no preserva correlacion entre
%      activos. Los escenarios sinteticos pueden ser economicamente
%      implausibles (ej. todos los activos simultaneamente en su maximo
%      historico). Esto tiende a hacer el modelo MAS conservador de lo
%      que un escenario conjunto realista justificaria.
%   2. El costo computacional escala como N*(N+M_synth), no N^2 -- mucho
%      mas pesado que la Geometria 1 para M_synth grande. La prueba de
%      tiempo (paso 3) es especialmente importante aqui.
%   3. eta=0 debe coincidir con el nominal sin importar M_synth (ver
%      test_hypercube_equivalence.m) -- correr ese test ANTES de este
%      script si no se ha hecho.
%
% UBICACION: este archivo vive en Wasserstein-Kelly/wdro-hypercube/, una
% subcarpeta distinta de donde estan los demas scripts del proyecto
% (mismo patron que wdro-market/). Estructura esperada:
%
%   Wasserstein-Kelly/
%   |-- data/processed/monthly_panel.csv
%   |-- solve_wdro_kelly.m, solve_nominal_kelly.m, compute_metrics.m,
%   |   load_monthly_data.m, build_transport_cost.m, compute_rho.m,
%   |   run_backtest_wdro_kelly.m, plot_returns_*.m, ...  (compartido)
%   |-- main_nominal_kelly.m, main_grid_delta_eta.m, ...  (Geometria 1)
%   |-- wdro-market/   (Geometria 2, carpeta aparte)
%   `-- wdro-hypercube/
%       |-- sample_hypercube_scenarios.m
%       |-- build_transport_cost_hypercube.m
%       |-- solve_wdro_kelly_hypercube.m
%       |-- run_backtest_wdro_kelly_hypercube.m
%       |-- test_hypercube_equivalence.m
%       `-- main_wdro_hypercube.m   (este archivo)
%
% Requiere: CVX + MOSEK, y todos los .m compartidos en Wasserstein-Kelly/ raiz.

clear; clc; close all;

%% 1. Configuracion y path
PROJECT_DIR = fileparts(mfilename('fullpath'));   % .../Wasserstein-Kelly/wdro-hypercube
ROOT_DIR    = fileparts(PROJECT_DIR);              % .../Wasserstein-Kelly
addpath(PROJECT_DIR);
addpath(ROOT_DIR);

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
CSV_PATH = fullfile(ROOT_DIR, 'data', 'processed', 'monthly_panel.csv');

if ~isfile(CSV_PATH)
    error('main_wdro_hypercube:csvNotFound', ...
        ['No se encontro el archivo:\n  %s\n', ...
         'Verifica que data/processed/monthly_panel.csv este en Wasserstein-Kelly ', ...
         '(raiz), no dentro de wdro-hypercube.'], CSV_PATH);
end

base_params.N       = 60;
base_params.tau     = 0.001;
base_params.xbar    = 0.25;
base_params.gamma   = 1;
base_params.solver  = 'mosek';
base_params.eps_esc = 1e-6;
base_params.delta   = 0.90;   % mismo delta usado en main_geometria_mercado.m

ALPHA = 0.95;

M_SYNTH  = 100;    % numero de escenarios sinteticos por fecha (ver advertencia de costo)
RNG_SEED = 2026;   % reproducibilidad del muestreo del hipercubo entre corridas

ETA_GRID = [0, 0.05, 0.15, 0.30];   % malla nucleo del Cuadro 8

OUT_DIR = fullfile(PROJECT_DIR, 'results_wdro_hypercube');
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

fprintf('Comparacion WDRO-hipercubo (M_synth=%d) vs. Wasserstein-Kelly (Geometria 1), delta=%.2f, %d valores de eta.\n', ...
    M_SYNTH, base_params.delta, numel(ETA_GRID));

%% 2. Cargar datos
data = load_monthly_data(CSV_PATH, TICKERS);

%% 3. Prueba de tiempo en una sola fecha para cada modelo
h0_test = [1; zeros(numel(TICKERS), 1)];
R_test  = data.R(1:base_params.N, :);
rf_test = data.rf_return(base_params.N);

C1_test = build_transport_cost(R_test, base_params.eps_esc);
rho1_test = compute_rho(C1_test, ETA_GRID(end));
tic;
solve_wdro_kelly(h0_test, R_test, rf_test, base_params.tau, base_params.xbar, ...
    base_params.gamma, base_params.delta, C1_test, rho1_test, base_params.solver);
t_geo1 = toc;

Rsynth_test = sample_hypercube_scenarios(R_test, M_SYNTH, RNG_SEED);
C2_test = build_transport_cost_hypercube(R_test, Rsynth_test, base_params.eps_esc);
rho2_test = compute_rho(C2_test, ETA_GRID(end));
tic;
solve_wdro_kelly_hypercube(h0_test, R_test, Rsynth_test, rf_test, base_params.tau, ...
    base_params.xbar, base_params.gamma, base_params.delta, C2_test, rho2_test, base_params.solver);
t_hc = toc;

n_dates_total = numel(data.dates) - base_params.N - 1;
n_runs = 2 * numel(ETA_GRID);
t_total_est = (t_geo1 + t_hc) * numel(ETA_GRID) * n_dates_total / 2;
fprintf(['Tiempo de una fecha -- Geometria 1: %.2f s, Hipercubo (M=%d): %.2f s (%.1fx mas lento). ', ...
    'Estimado total (%d corridas x %d fechas): ~%.1f min.\n'], ...
    t_geo1, M_SYNTH, t_hc, t_hc / max(t_geo1, eps), n_runs, n_dates_total, t_total_est / 60);

%% 4. Correr ambos modelos para cada eta
results_geo1 = cell(numel(ETA_GRID), 1);   % Wasserstein-Kelly, Geometria 1
results_hc   = cell(numel(ETA_GRID), 1);   % WDRO-hipercubo
metrics_geo1 = cell(numel(ETA_GRID), 1);
metrics_hc   = cell(numel(ETA_GRID), 1);

for e = 1:numel(ETA_GRID)
    eta_e = ETA_GRID(e);
    p1 = base_params;
    p1.eta = eta_e;

    fprintf('\n--- eta = %.2f ---\n', eta_e);

    fprintf('  Geometria 1 (Wasserstein-Kelly nucleo) ... ');
    r1 = run_backtest_wdro_kelly(data, p1);
    m1 = compute_metrics(r1, ALPHA);
    results_geo1{e} = r1;
    metrics_geo1{e} = m1;
    fprintf('riqueza final = %.4f | CAGR = %.2f%% | MDD = %.2f%%\n', ...
        m1.wealth_final, 100*m1.CAGR, 100*m1.max_drawdown);

    fprintf('  WDRO-hipercubo (M_synth=%d) ... ', M_SYNTH);
    p2 = base_params;
    p2.eta = eta_e;
    p2.M_synth = M_SYNTH;
    p2.rng_seed = RNG_SEED;
    r2 = run_backtest_wdro_kelly_hypercube(data, p2);
    m2 = compute_metrics(r2, ALPHA);
    results_hc{e} = r2;
    metrics_hc{e} = m2;
    fprintf('riqueza final = %.4f | CAGR = %.2f%% | MDD = %.2f%%\n', ...
        m2.wealth_final, 100*m2.CAGR, 100*m2.max_drawdown);
end

% Verificacion cruzada en eta=0 (deberian coincidir, ver test_hypercube_equivalence.m).
diff_eta0 = abs(metrics_geo1{1}.wealth_final - metrics_hc{1}.wealth_final);
fprintf(['\nVerificacion eta=0: |riqueza_final Geometria1 - Hipercubo| = %.3e ', ...
    '(deberia ser ~0; si no, correr test_hypercube_equivalence.m antes de confiar en el resto).\n'], diff_eta0);

%% 5. Guardar resultados crudos
save(fullfile(OUT_DIR, 'hipercubo_vs_geometria1.mat'), ...
    'results_geo1', 'results_hc', 'metrics_geo1', 'metrics_hc', ...
    'ETA_GRID', 'base_params', 'M_SYNTH', 'RNG_SEED');

%% 6. Tabla comparativa
rows = {};
for e = 1:numel(ETA_GRID)
    for g = 1:2
        if g == 1
            m = metrics_geo1{e}; modelo = "wasserstein_kelly";
        else
            m = metrics_hc{e}; modelo = "wdro_hipercubo";
        end
        row = table(ETA_GRID(e), modelo, m.wealth_final, m.CAGR, ...
            m.variance_monthly, m.max_drawdown, m.CVaR_loss, m.sharpe, ...
            m.turnover_total, m.n_rebalances, m.Neff_mean, ...
            'VariableNames', {'eta', 'modelo', 'riqueza_final', 'CAGR', ...
                'varianza_mensual', 'max_drawdown', 'CVaR_perdida', 'sharpe', ...
                'turnover_total', 'n_transacciones', 'Neff_promedio'});
        rows{end+1} = row; %#ok<SAGROW>
    end
end
comparison_table = vertcat(rows{:});
writetable(comparison_table, fullfile(OUT_DIR, 'comparacion_hipercubo_vs_geometria1.csv'));
disp(comparison_table);

%% 7. Grafica de riqueza: ambos modelos, todos los eta
figure('Position', [100, 100, 1000, 600]);
hold on;
colors = lines(numel(ETA_GRID));
for e = 1:numel(ETA_GRID)
    r1 = results_geo1{e};
    r2 = results_hc{e};
    plot([r1.dates(1); r1.dates], r1.wealth, '-', 'LineWidth', 1.3, ...
        'Color', colors(e, :), 'DisplayName', sprintf('\\eta=%.2f, Geometria 1', ETA_GRID(e)));
    plot([r2.dates(1); r2.dates], r2.wealth, '--', 'LineWidth', 1.3, ...
        'Color', colors(e, :), 'DisplayName', sprintf('\\eta=%.2f, Hipercubo', ETA_GRID(e)));
end
hold off;
title(sprintf('Riqueza acumulada: Geometria 1 (linea solida) vs. WDRO-hipercubo (punteada), \\delta=%.2f', ...
    base_params.delta));
xlabel('Fecha'); ylabel('W_t / W_0');
legend('Location', 'best', 'NumColumns', 2);
grid on;
saveas(gcf, fullfile(OUT_DIR, 'riqueza_geometria1_vs_hipercubo.png'));

%% 8. Graficas de retornos para eta=0.15 (radio moderado)
ETA_FOCUS = 0.15;
e_focus = find(ETA_GRID == ETA_FOCUS, 1);
if ~isempty(e_focus)
    label1 = sprintf('Geometria 1 (\\eta=%.2f)', ETA_FOCUS);
    label2 = sprintf('Hipercubo (\\eta=%.2f)', ETA_FOCUS);
    plot_returns_timeseries({results_geo1{e_focus}, results_hc{e_focus}}, ...
        {label1, label2}, sprintf('Retornos mensuales, \\delta=%.2f, \\eta=%.2f', ...
        base_params.delta, ETA_FOCUS), OUT_DIR);
    plot_returns_boxplot({results_geo1{e_focus}, results_hc{e_focus}}, ...
        {label1, label2}, sprintf('Distribucion de retornos, \\delta=%.2f, \\eta=%.2f', ...
        base_params.delta, ETA_FOCUS), OUT_DIR);
end

fprintf('\nResultados guardados en la carpeta "%s".\n', OUT_DIR);
