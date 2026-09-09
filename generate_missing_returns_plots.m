%% generate_missing_returns_plots.m
% Regenera las graficas de retornos (boxplot, barras, timeseries) SIN
% volver a correr los backtests de main_grid_delta_eta.m -- util si el
% boxplot fallo por no tener el Statistics and Machine Learning Toolbox
% instalado (lo cual detiene el script en esa linea y salta lo que sigue).
%
% Actualizado para la comparacion EXPLICITA (delta=0.75, eta en
% {0, 0.01, 0.05, 0.15}) que usa la version actual de main_grid_delta_eta.m
% -- ya no hay logica de "mejor combinacion" ni grid.beats_nominal.
%
% Requiere que ya hayas corrido main_grid_delta_eta.m al menos hasta el
% paso 5 (el guardado de resultados/grid_delta_eta.mat ocurre antes de
% las graficas, asi que sobrevive aunque alguna fallara).

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

DELTA_REF = 0.75;
ETA_COMPARE = [0, 0.01, 0.05, 0.15];

i_ref = find(DELTA_GRID == DELTA_REF, 1);
if isempty(i_ref)
    warning('generate_missing_returns_plots:deltaRefNotFound', ...
        'delta=%.2f no esta en la malla guardada; se usa el primer valor disponible.', DELTA_REF);
    i_ref = 1;
end

results_compare = {};
labels_compare  = {};
for e = 1:numel(ETA_COMPARE)
    j_e = find(ETA_GRID == ETA_COMPARE(e), 1);
    if isempty(j_e)
        warning('generate_missing_returns_plots:etaCompareNotFound', ...
            'eta=%.3f no esta en la malla guardada; se omite.', ETA_COMPARE(e));
        continue
    end
    r_e = grid.results_wdro{i_ref, j_e};
    if isempty(r_e)
        continue
    end
    results_compare{end+1} = r_e; %#ok<SAGROW>
    labels_compare{end+1}  = sprintf('\\eta=%.2f', ETA_GRID(j_e)); %#ok<SAGROW>
end

fprintf('Comparando delta=%.2f, eta = %s\n', DELTA_GRID(i_ref), mat2str(ETA_COMPARE));

plot_returns_timeseries(results_compare, labels_compare, ...
    sprintf('Retornos mensuales, \\delta=%.2f', DELTA_GRID(i_ref)), OUT_DIR);
plot_returns_boxplot(results_compare, labels_compare, ...
    sprintf('Distribucion de retornos, \\delta=%.2f', DELTA_GRID(i_ref)), OUT_DIR);
for k = 1:numel(results_compare)
    plot_returns_bar(results_compare{k}, labels_compare{k}, OUT_DIR);
end

fprintf('Graficas regeneradas en la carpeta "%s".\n', OUT_DIR);
