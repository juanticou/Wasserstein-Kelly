%% main_grid_delta_eta.m
% Malla COMPLETA de delta y eta -- valores por debajo Y por encima de 1
% para ambos parametros -- para mapear regiones de (in)factibilidad y
% comparar riqueza, retornos y demas metricas contra el caso eta=0.
%
% CAMBIO IMPORTANTE respecto a versiones anteriores de este script:
% ya NO se corre el Kelly nominal por separado. eta=0 dentro de la propia
% malla WDRO es matematicamente equivalente al nominal (verificado en
% test_wdro_nominal_equivalence.m y en la corrida completa de
% main_wdro_kelly.m), asi que se usa esa columna como baseline en vez de
% duplicar el computo con run_backtest_nominal_kelly.
%
% Requiere: CVX + MOSEK, Statistics and Machine Learning Toolbox
% (boxplot, prctile dentro de compute_metrics.m), y todos los .m del
% proyecto incluyendo run_grid_delta_eta_wdro_only.m.

clear; clc; close all;

%% 1. Configuracion
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');

if ~isfile(CSV_PATH)
    error('main_grid_delta_eta:csvNotFound', 'No se encontro el archivo:\n  %s', CSV_PATH);
end

base_params.N       = 60;
base_params.tau     = 0.001;
base_params.xbar    = 0.25;
base_params.gamma   = 1;
base_params.solver  = 'mosek';
base_params.eps_esc = 1e-6;
% delta y eta se sobrescriben dentro de run_grid_delta_eta_wdro_only.m

% Malla completa: nucleo del Cuadro 8 (delta<=0.90, eta<=0.30) + rango
% explorado antes (eta hasta 1.00) + valores por ENCIMA de 1 en ambos.
% eta=0 se conserva como baseline equivalente al nominal (ver nota arriba).
DELTA_GRID = [0.50, 0.60, 0.70, 0.75, 0.80, 0.90, 1.00];
ETA_GRID   = [0, 0.05, 0.15, 0.30, 0.50, 1.00, 1.50, 2.00, 3.00];

OUT_DIR = 'results_eta_delta_grid_wdro';   % misma carpeta de la malla anterior
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

n_total = numel(DELTA_GRID) * numel(ETA_GRID);
fprintf('Malla completa: %d valores de delta x %d valores de eta = %d backtests WDRO (sin nominal por separado).\n', ...
    numel(DELTA_GRID), numel(ETA_GRID), n_total);

%% 2. Cargar datos
data = load_monthly_data(CSV_PATH, TICKERS);

%% 3. Prueba de tiempo en una sola fecha, para estimar el total
h0_test = [1; zeros(numel(TICKERS), 1)];
R_test  = data.R(1:base_params.N, :);
rf_test = data.rf_return(base_params.N);
C_test  = build_transport_cost(R_test, base_params.eps_esc);
rho_test = compute_rho(C_test, ETA_GRID(end));

tic;
delta_test = median(DELTA_GRID);   % valor representativo solo para estimar el tiempo
solve_wdro_kelly(h0_test, R_test, rf_test, base_params.tau, base_params.xbar, ...
    base_params.gamma, delta_test, C_test, rho_test, base_params.solver);
t_one = toc;

n_dates_total = numel(data.dates) - base_params.N - 1;
fprintf(['Tiempo de una sola fecha WDRO: %.2f s. Estimado por cada (delta,eta) (%d fechas): ~%.1f min. ', ...
    'Malla completa (%d combinaciones): ~%.1f min (~%.1f h).\n'], ...
    t_one, n_dates_total, t_one * n_dates_total / 60, ...
    n_total, n_total * t_one * n_dates_total / 60, n_total * t_one * n_dates_total / 3600);

%% 4. Correr la malla completa (solo WDRO, eta=0 como baseline)
grid = run_grid_delta_eta_wdro_only(data, base_params, DELTA_GRID, ETA_GRID);

%% 5. Guardar resultados crudos
save(fullfile(OUT_DIR, 'grid_delta_eta.mat'), 'grid', '-v7.3');

%% 6. Mapa de factibilidad
plot_heatmap(grid.feas_wdro, ETA_GRID, DELTA_GRID, ...
    'Factibilidad WDRO (fraccion de fechas resueltas)', 'Fraccion Solved', '%.2f', ...
    OUT_DIR, 'heatmap_factibilidad.png');

%% 7. Mapas de desempeno vs. baseline (eta=0 de cada fila)
if ~isempty(grid.baseline_col)
    plot_heatmap(100 * grid.CAGR_diff, ETA_GRID, DELTA_GRID, ...
        'CAGR(WDRO) - CAGR(\eta=0), mismo \delta  [pp]', 'Diferencia de CAGR (pp)', '%.2f', ...
        OUT_DIR, 'heatmap_cagr_diff.png');

    plot_heatmap(100 * grid.MDD_diff, ETA_GRID, DELTA_GRID, ...
        'MaxDrawdown(WDRO) - MaxDrawdown(\eta=0), mismo \delta  [pp]', ...
        'Diferencia de MDD (pp, negativo = mejor)', '%.2f', ...
        OUT_DIR, 'heatmap_mdd_diff.png');

    plot_heatmap(double(grid.beats_nominal), ETA_GRID, DELTA_GRID, ...
        'WDRO domina al baseline \eta=0 (mas CAGR y menos MDD)', '1 = si, 0 = no', '%.0f', ...
        OUT_DIR, 'heatmap_dominancia.png');
else
    warning('main_grid_delta_eta:noBaseline', ...
        'eta_grid no incluyo 0; se omiten los mapas de comparacion.');
end

%% 8. Mapa adicional: riqueza final (util para ver el efecto combinado
% delta-eta sobre la riqueza total, no solo el CAGR anualizado)
plot_heatmap(grid.Wealth_wdro, ETA_GRID, DELTA_GRID, ...
    'Riqueza final W_T / W_0 (WDRO)', 'Riqueza final', '%.2f', ...
    OUT_DIR, 'heatmap_riqueza_final.png');

%% 9. Reportar combinaciones donde el WDRO domina al baseline
fprintf('\n=== Combinaciones (delta, eta) donde WDRO domina al baseline eta=0 ===\n');
[iBeat, jBeat] = find(grid.beats_nominal);
if isempty(iBeat)
    fprintf('  Ninguna combinacion en la malla domina estrictamente al baseline.\n');
    fprintf('  (Resultado valido y reportable -- Secciones 13.4 y 22 de la propuesta.)\n');
else
    for k = 1:numel(iBeat)
        i = iBeat(k); j = jBeat(k);
        fprintf(['  delta=%.2f, eta=%.2f -> CAGR: %.2f%% vs %.2f%% (eta=0) | ', ...
            'MDD: %.2f%% vs %.2f%% (eta=0) | Riqueza final: %.2f vs %.2f (eta=0)\n'], ...
            DELTA_GRID(i), ETA_GRID(j), ...
            100*grid.CAGR_wdro(i,j), 100*grid.CAGR_baseline(i), ...
            100*grid.MDD_wdro(i,j), 100*grid.MDD_baseline(i), ...
            grid.Wealth_wdro(i,j), grid.Wealth_wdro(i, grid.baseline_col));
    end
end

%% 10. Graficas para un caso representativo: baseline (eta=0) vs. la mejor
% combinacion encontrada (o, si ninguna domina, delta=0.75/eta=0.15 -- el
% caso nucleo del Cuadro 8).
if ~isempty(iBeat)
    [~, best] = max(grid.CAGR_diff(sub2ind(size(grid.CAGR_diff), iBeat, jBeat)));
    i_sel = iBeat(best); j_sel = jBeat(best);
else
    i_sel = find(DELTA_GRID == 0.75, 1);
    j_sel = find(ETA_GRID == 0.15, 1);
    if isempty(i_sel), i_sel = 1; end
    if isempty(j_sel), j_sel = 1; end
end

r_baseline_sel = grid.results_wdro{i_sel, grid.baseline_col};
r_wdro_sel     = grid.results_wdro{i_sel, j_sel};
label_baseline = sprintf('\\eta=0 (\\delta=%.2f)', DELTA_GRID(i_sel));
label_wdro     = sprintf('WDRO (\\delta=%.2f, \\eta=%.2f)', DELTA_GRID(i_sel), ETA_GRID(j_sel));

% Riqueza total (no solo CAGR)
figure('Position', [100, 100, 950, 550]);
plot([r_baseline_sel.dates(1); r_baseline_sel.dates], r_baseline_sel.wealth, ...
    'LineWidth', 1.6, 'DisplayName', label_baseline);
hold on;
plot([r_wdro_sel.dates(1); r_wdro_sel.dates], r_wdro_sel.wealth, ...
    'LineWidth', 1.6, 'DisplayName', label_wdro);
hold off;
title('Riqueza acumulada: baseline (\eta=0) vs. combinacion seleccionada');
xlabel('Fecha'); ylabel('W_t / W_0');
legend('Location', 'best'); grid on;
saveas(gcf, fullfile(OUT_DIR, 'riqueza_baseline_vs_seleccionado.png'));

% Retornos: serie de tiempo, boxplot y barras individuales
plot_returns_timeseries({r_baseline_sel, r_wdro_sel}, {label_baseline, label_wdro}, [], OUT_DIR);
plot_returns_boxplot({r_baseline_sel, r_wdro_sel}, {label_baseline, label_wdro}, [], OUT_DIR);
plot_returns_bar(r_baseline_sel, label_baseline, OUT_DIR);
plot_returns_bar(r_wdro_sel, label_wdro, OUT_DIR);

fprintf('\nResultados guardados en la carpeta "%s".\n', OUT_DIR);