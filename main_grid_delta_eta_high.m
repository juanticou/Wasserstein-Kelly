%% main_grid_delta_eta_high.m
% Malla de valores ALTOS de delta y eta (por encima de 1), sin correr el
% Kelly nominal por separado -- eta=0 dentro de la propia malla WDRO hace
% ese papel (equivalencia verificada en test_wdro_nominal_equivalence.m).
%
% delta > 1 exige un factor de crecimiento garantizado incluso en el peor
% escenario de la ventana de entrenamiento -- se espera que la region
% factible se angoste rapido; ese es justamente el limite que se quiere
% mapear. eta > 1 hace que el radio de Wasserstein supere la mediana de
% distancias entre escenarios de la ventana, una robustez bastante
% agresiva (Seccion 13.4: puede volverse excesivamente conservador).
%
% Requiere: CVX + MOSEK, el Statistics and Machine Learning Toolbox
% (boxplot, prctile dentro de compute_metrics.m), y todos los .m del
% proyecto incluyendo run_grid_delta_eta_wdro_only.m.

clear; clc; close all;

%% 1. Configuracion
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');

if ~isfile(CSV_PATH)
    error('main_grid_delta_eta_high:csvNotFound', 'No se encontro el archivo:\n  %s', CSV_PATH);
end

base_params.N       = 60;
base_params.tau     = 0.001;
base_params.xbar    = 0.25;
base_params.gamma   = 1;
base_params.solver  = 'mosek';
base_params.eps_esc = 1e-6;

% Malla de valores altos. Se conserva eta=0 como baseline (no como
% "ejecucion nominal": se resuelve con el mismo solve_wdro_kelly, solo
% que con radio cero -- por eso no hace falta correr
% run_backtest_nominal_kelly por separado).
DELTA_GRID = [1.00, 1.05, 1.10, 1.20, 1.30];
ETA_GRID   = [0, 1.00, 1.50, 2.00, 3.00];

OUT_DIR = 'results_eta_delta_grid_wdro_high';   % carpeta propia, distinta
                                                  % de la malla original
                                                  % (0.5-0.9 / 0-1)
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

fprintf('Malla: %d valores de delta x %d valores de eta = %d backtests WDRO (sin nominal por separado).\n', ...
    numel(DELTA_GRID), numel(ETA_GRID), numel(DELTA_GRID)*numel(ETA_GRID));

%% 2. Cargar datos
data = load_monthly_data(CSV_PATH, TICKERS);

%% 3. Correr la malla (solo WDRO, eta=0 como baseline)
grid = run_grid_delta_eta_wdro_only(data, base_params, DELTA_GRID, ETA_GRID);

%% 4. Guardar resultados crudos
save(fullfile(OUT_DIR, 'grid_delta_eta_high.mat'), 'grid', '-v7.3');

%% 5. Mapa de factibilidad
plot_heatmap(grid.feas_wdro, ETA_GRID, DELTA_GRID, ...
    'Factibilidad WDRO, valores altos (fraccion de fechas resueltas)', ...
    'Fraccion Solved', '%.2f', OUT_DIR, 'heatmap_factibilidad_high.png');

%% 6. Mapas de desempeno vs. baseline (eta=0 de cada fila)
if ~isempty(grid.baseline_col)
    plot_heatmap(100 * grid.CAGR_diff, ETA_GRID, DELTA_GRID, ...
        'CAGR(WDRO) - CAGR(\eta=0), mismo \delta  [pp]', ...
        'Diferencia de CAGR (pp)', '%.2f', OUT_DIR, 'heatmap_cagr_diff_high.png');

    plot_heatmap(100 * grid.MDD_diff, ETA_GRID, DELTA_GRID, ...
        'MaxDrawdown(WDRO) - MaxDrawdown(\eta=0), mismo \delta  [pp]', ...
        'Diferencia de MDD (pp, negativo = mejor)', '%.2f', OUT_DIR, 'heatmap_mdd_diff_high.png');

    % Indicador de dominancia informativo (no usado para seleccionar nada
    % automaticamente): CAGR_diff/MDD_diff ya vienen en grid, calculados
    % contra el baseline eta=0 dentro de run_grid_delta_eta_wdro_only.m.
    beats_local = (grid.CAGR_diff > 0) & (grid.MDD_diff < 0);
    plot_heatmap(double(beats_local), ETA_GRID, DELTA_GRID, ...
        'WDRO domina al baseline \eta=0 (mas CAGR y menos MDD)', ...
        '1 = si, 0 = no', '%.0f', OUT_DIR, 'heatmap_dominancia_high.png');
else
    warning('main_grid_delta_eta_high:noBaseline', ...
        'eta_grid no incluyo 0; se omiten los mapas de comparacion.');
    beats_local = false(size(grid.CAGR_diff));
end

%% 7. Reportar combinaciones donde el WDRO domina al baseline
fprintf('\n=== Combinaciones (delta, eta) donde WDRO domina al baseline eta=0 ===\n');
[iBeat, jBeat] = find(beats_local);
if isempty(iBeat)
    fprintf('  Ninguna combinacion en esta malla domina estrictamente al baseline.\n');
else
    for k = 1:numel(iBeat)
        i = iBeat(k); j = jBeat(k);
        fprintf(['  delta=%.2f, eta=%.2f -> CAGR: %.2f%% vs %.2f%% (eta=0) | ', ...
            'MDD: %.2f%% vs %.2f%% (eta=0)\n'], ...
            DELTA_GRID(i), ETA_GRID(j), ...
            100*grid.CAGR_wdro(i,j), 100*grid.CAGR_baseline(i), ...
            100*grid.MDD_wdro(i,j), 100*grid.MDD_baseline(i));
    end
end

%% 8. Graficas de retornos para un caso representativo
if ~isempty(iBeat)
    [~, best] = max(grid.CAGR_diff(sub2ind(size(grid.CAGR_diff), iBeat, jBeat)));
    i_sel = iBeat(best); j_sel = jBeat(best);
else
    i_sel = 1;
    j_sel = min(2, numel(ETA_GRID));   % primer eta > 0 disponible
end

r_baseline_sel = grid.results_wdro{i_sel, grid.baseline_col};
r_wdro_sel     = grid.results_wdro{i_sel, j_sel};
label_baseline = sprintf('\\eta=0 (\\delta=%.2f)', DELTA_GRID(i_sel));
label_wdro     = sprintf('WDRO (\\delta=%.2f, \\eta=%.2f)', DELTA_GRID(i_sel), ETA_GRID(j_sel));

plot_returns_timeseries({r_baseline_sel, r_wdro_sel}, {label_baseline, label_wdro}, [], OUT_DIR);
plot_returns_boxplot({r_baseline_sel, r_wdro_sel}, {label_baseline, label_wdro}, [], OUT_DIR);
plot_returns_bar(r_baseline_sel, label_baseline, OUT_DIR);
plot_returns_bar(r_wdro_sel, label_wdro, OUT_DIR);

fprintf('\nResultados guardados en la carpeta "%s".\n', OUT_DIR);
