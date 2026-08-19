%% main_wdro_kelly.m
% Corre la malla nucleo de robustez del Cuadro 8: eta = 0, 0.05, 0.15, 0.30
% (Geometria 1: solo retornos) y compara contra el benchmark Kelly nominal.
%
% eta = 0 debe coincidir (dentro de tolerancia numerica) con
% main_nominal_kelly.m -- es una segunda verificacion de la equivalencia
% ademas de test_wdro_nominal_equivalence.m, pero corrida sobre el
% backtest completo en vez de una sola fecha.
%
% Requiere: CVX + MOSEK, y los archivos solve_nominal_kelly.m,
% solve_wdro_kelly.m, build_transport_cost.m, compute_rho.m,
% run_backtest_nominal_kelly.m, run_backtest_wdro_kelly.m,
% compute_metrics.m, load_monthly_data.m en el mismo path.

clear; clc; close all;

%% 1. Configuracion (Cuadro 8, configuracion nucleo)
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');

if ~isfile(CSV_PATH)
    error('main_wdro_kelly:csvNotFound', ...
        'No se encontro el archivo:\n  %s', CSV_PATH);
end

base_params.N      = 60;
base_params.tau    = 0.001;
base_params.xbar   = 0.25;
base_params.gamma  = 1;
base_params.delta  = 0.75;
base_params.solver = 'mosek';
base_params.eps_esc = 1e-6;

ETA_GRID = [0, 0.05, 0.15, 0.30];   % Cuadro 8: nominal + tres intensidades

%% 2. Cargar datos
data = load_monthly_data(CSV_PATH, TICKERS);
fprintf('Panel cargado: %d meses (%s a %s)\n', numel(data.dates), ...
    datestr(data.dates(1), 'mmm-yyyy'), datestr(data.dates(end), 'mmm-yyyy'));

%% 3. Prueba de tiempo en una sola fecha
% El problema WDRO tiene N^2 restricciones logaritmicas en vez de N
% (equation 53), asi que es mas pesado que el nominal por cada llamada.
h0_test = [1; zeros(numel(TICKERS), 1)];
R_test  = data.R(1:base_params.N, :);
rf_test = data.rf_return(base_params.N);
C_test  = build_transport_cost(R_test, base_params.eps_esc);
rho_test = compute_rho(C_test, ETA_GRID(end));

tic;
solve_wdro_kelly(h0_test, R_test, rf_test, base_params.tau, base_params.xbar, ...
    base_params.gamma, base_params.delta, C_test, rho_test, base_params.solver);
t_one = toc;

n_dates_total = numel(data.dates) - base_params.N - 1;
fprintf(['Tiempo de una sola fecha WDRO con solver "%s": %.2f s. ', ...
    'Estimado por cada eta (%d fechas): ~%.1f min. Malla completa (%d etas): ~%.1f min.\n'], ...
    base_params.solver, t_one, n_dates_total, t_one * n_dates_total / 60, ...
    numel(ETA_GRID), numel(ETA_GRID) * t_one * n_dates_total / 60);

%% 4. Correr la malla de eta
all_results = struct();
all_metrics = struct();

for e = 1:numel(ETA_GRID)
    eta = ETA_GRID(e);
    field = sprintf('eta_%s', strrep(num2str(eta), '.', 'p'));

    fprintf('\n=== Corriendo WDRO con eta = %.2f ===\n', eta);
    params = base_params;
    params.eta = eta;

    results_e = run_backtest_wdro_kelly(data, params);
    metrics_e = compute_metrics(results_e);

    all_results.(field) = results_e;
    all_metrics.(field) = metrics_e;

    fprintf('  Riqueza final = %.4f | CAGR = %.2f%% | MDD = %.2f%% | Neff medio = %.2f | Turnover total = %.2f\n', ...
        metrics_e.wealth_final, 100*metrics_e.CAGR, 100*metrics_e.max_drawdown, ...
        metrics_e.Neff_mean, metrics_e.turnover_total);
end

%% 5. Benchmark nominal para comparar (equivalente a eta = 0)
fprintf('\n=== Corriendo Kelly nominal (benchmark) ===\n');
results_nom = run_backtest_nominal_kelly(data, base_params);
metrics_nom = compute_metrics(results_nom);
fprintf('  Riqueza final = %.4f | CAGR = %.2f%% | MDD = %.2f%%\n', ...
    metrics_nom.wealth_final, 100*metrics_nom.CAGR, 100*metrics_nom.max_drawdown);

% Verificacion rapida: eta=0 deberia coincidir con el nominal.
diff_eta0 = abs(all_metrics.eta_0.wealth_final - metrics_nom.wealth_final);
fprintf(['\nVerificacion eta=0 vs. nominal: |riqueza_final diff| = %.3e ', ...
    '(deberia ser ~0; si no, revisar equivalencia antes de confiar en la malla).\n'], diff_eta0);

%% 6. Tabla comparativa
eta_labels = arrayfun(@(e) sprintf('eta=%.2f', e), ETA_GRID, 'UniformOutput', false);
fields = fieldnames(all_metrics);

wealth_final = cellfun(@(f) all_metrics.(f).wealth_final, fields);
cagr         = cellfun(@(f) all_metrics.(f).CAGR, fields);
mdd          = cellfun(@(f) all_metrics.(f).max_drawdown, fields);
turnover_tot = cellfun(@(f) all_metrics.(f).turnover_total, fields);
neff_mean    = cellfun(@(f) all_metrics.(f).Neff_mean, fields);
n_viol       = cellfun(@(f) all_metrics.(f).n_violations_delta, fields);

comparison = table(eta_labels', wealth_final, cagr, mdd, turnover_tot, neff_mean, n_viol, ...
    'VariableNames', {'Modelo', 'RiquezaFinal', 'CAGR', 'MaxDrawdown', ...
    'TurnoverTotal', 'NeffMedio', 'ViolacionesDelta'});
comparison = [comparison; ...
    {'Nominal', metrics_nom.wealth_final, metrics_nom.CAGR, metrics_nom.max_drawdown, ...
     metrics_nom.turnover_total, metrics_nom.Neff_mean, metrics_nom.n_violations_delta}];

disp(comparison);

%% 7. Guardar resultados
if ~exist('results_out_wdro', 'dir')
    mkdir('results_out_wdro');
end
save(fullfile('results_out_wdro', 'wdro_kelly_grid.mat'), ...
    'all_results', 'all_metrics', 'results_nom', 'metrics_nom', 'ETA_GRID', 'base_params');
writetable(comparison, fullfile('results_out_wdro', 'wdro_vs_nominal_comparison.csv'));

%% 8. Grafica: riqueza acumulada, todas las etas + nominal
figure('Position', [100, 100, 950, 550]);
hold on;
plot([results_nom.dates(1); results_nom.dates], results_nom.wealth, ...
    'LineWidth', 2, 'DisplayName', 'Nominal', 'Color', 'k');
colors = lines(numel(ETA_GRID));
for e = 1:numel(ETA_GRID)
    field = fields{e};
    r = all_results.(field);
    plot([r.dates(1); r.dates], r.wealth, 'LineWidth', 1.3, ...
        'DisplayName', eta_labels{e}, 'Color', colors(e, :));
end
hold off;
title('Riqueza acumulada: Kelly nominal vs. Wasserstein-Kelly (geometria de retornos)');
xlabel('Fecha'); ylabel('W_t / W_0');
legend('Location', 'best');
grid on;
saveas(gcf, fullfile('results_out_wdro', 'wdro_vs_nominal_wealth.png'));

fprintf('\nResultados guardados en la carpeta "results_out_wdro".\n');
