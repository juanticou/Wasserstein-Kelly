%% regenerate_grid_tables.m
% Regenera las tablas de salida de main_grid_delta_eta.m -- ahora
% incluyendo turnover y numero de transacciones -- y produce la grafica
% de evolucion de riqueza para delta=0.9 (todos sus valores de eta), SIN
% volver a correr los 66 backtests: todo se reconstruye a partir de
% results_wdro, que ya quedo guardado dentro de grid_delta_eta.mat.
%
% Requiere: haber corrido main_grid_delta_eta.m al menos hasta el paso 5
% (guardado del grid), y tener build_grid_summary_table.m,
% matrix_to_wide_table.m, plot_wealth_by_delta.m y plot_heatmap.m en el path.

clear; clc; close all;

OUT_DIR = 'results_eta_delta_grid_wdro';
mat_path = fullfile(OUT_DIR, 'grid_delta_eta.mat');

if ~isfile(mat_path)
    error('regenerate_grid_tables:notFound', ...
        ['No se encontro %s. Verifica que main_grid_delta_eta.m se haya ', ...
         'corrido al menos hasta el paso 5 (guardado del grid).'], mat_path);
end

load(mat_path, 'grid');
DELTA_GRID = grid.delta_grid;
ETA_GRID   = grid.eta_grid;

%% 1. Tabla maestra actualizada (ahora con n_transacciones y turnover_medio_activo)
summary_table = build_grid_summary_table(grid);
writetable(summary_table, fullfile(OUT_DIR, 'tabla_maestra_metricas.csv'));

fprintf('=== Primeras filas de la tabla maestra (delta, eta, turnover, n_transacciones) ===\n');
disp(summary_table(1:min(10, height(summary_table)), ...
    {'delta', 'eta', 'turnover_total', 'n_transacciones', 'riqueza_final', 'CAGR'}));

%% 2. Tabla ancha de turnover (delta en filas, eta en columnas)
turnover_table = matrix_to_wide_table(grid.Turnover_wdro, DELTA_GRID, ETA_GRID);
writetable(turnover_table, fullfile(OUT_DIR, 'tabla_turnover.csv'));

%% 3. Tabla ancha de numero de transacciones (cuantos meses SI rebalancearon)
nd = numel(DELTA_GRID);
ne = numel(ETA_GRID);
NRebalances = nan(nd, ne);
for i = 1:nd
    for j = 1:ne
        r = grid.results_wdro{i, j};
        if isempty(r)
            continue
        end
        NRebalances(i, j) = sum(r.turnover > 1e-8);
    end
end
nrebal_table = matrix_to_wide_table(NRebalances, DELTA_GRID, ETA_GRID);
writetable(nrebal_table, fullfile(OUT_DIR, 'tabla_n_transacciones.csv'));

%% 4. Heatmap de turnover (no estaba en la corrida original)
plot_heatmap(grid.Turnover_wdro, ETA_GRID, DELTA_GRID, ...
    'Turnover acumulado (WDRO)', 'Turnover total', '%.2f', ...
    OUT_DIR, 'heatmap_turnover.png');

plot_heatmap(NRebalances, ETA_GRID, DELTA_GRID, ...
    'Numero de meses con transaccion (WDRO)', '# transacciones', '%.0f', ...
    OUT_DIR, 'heatmap_n_transacciones.png');


fprintf('\nTablas y graficas regeneradas en la carpeta "%s".\n', OUT_DIR);
