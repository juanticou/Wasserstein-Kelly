%% generate_missing_returns_plots.m
% Regenera el boxplot (y las graficas de barras que se saltaron por el
% mismo error, ya que MATLAB detiene el script en la linea que falla)
% SIN volver a correr los backtests de main_grid_delta_eta.m.
%
% Actualizado para la malla WDRO-only (eta=0 como baseline, sin
% grid.results_nominal por separado).
%
% Requiere que ya hayas corrido main_grid_delta_eta.m al menos hasta el
% paso 5 (el guardado de resultados/grid_delta_eta.mat ocurre antes de
% las graficas, asi que sobrevive aunque alguna fallara).
%
% Corre esto DESPUES de instalar el Statistics and Machine Learning
% Toolbox (necesario para boxplot() y para prctile(), que usa
% compute_metrics.m).

clear; clc; close all;

OUT_DIR = 'results_eta_delta_grid_wdro';
mat_path = fullfile(OUT_DIR, 'grid_delta_eta.mat');

if ~isfile(mat_path)
    error('generate_missing_returns_plots:notFound', ...
        ['No se encontro %s. Verifica que main_grid_delta_eta.m se haya ', ...
         'corrido al menos hasta el paso 5 (guardado del grid).'], mat_path);
end

load(mat_path, 'grid');

DELTA_GRID = grid.delta_grid;
ETA_GRID   = grid.eta_grid;

if isempty(grid.baseline_col)
    error('generate_missing_returns_plots:noBaseline', ...
        'Esta malla no incluyo eta=0, asi que no hay baseline para comparar.');
end

% --- Misma logica de seleccion que main_grid_delta_eta.m paso 10 ---
[iBeat, jBeat] = find(grid.beats_nominal);
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

fprintf('Caso seleccionado: delta=%.2f, eta=%.2f\n', DELTA_GRID(i_sel), ETA_GRID(j_sel));

% --- Regenerar lo que falto ---
plot_returns_boxplot({r_baseline_sel, r_wdro_sel}, {label_baseline, label_wdro}, [], OUT_DIR);
plot_returns_bar(r_baseline_sel, label_baseline, OUT_DIR);
plot_returns_bar(r_wdro_sel, label_wdro, OUT_DIR);

fprintf('Graficas regeneradas en la carpeta "%s".\n', OUT_DIR);
