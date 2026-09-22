function plot_wealth_by_delta(grid, delta_value, outDir)
% PLOT_WEALTH_BY_DELTA  Grafica la riqueza acumulada de TODOS los valores
% de eta disponibles en la malla, para un delta fijo -- util para ver de
% un vistazo el efecto del radio de robustez sobre la trayectoria de
% riqueza completa, no solo sobre el CAGR o la riqueza final.
%
% ENTRADAS
%   grid        : struct de run_grid_delta_eta_wdro_only.m (o cargado
%                 desde el .mat que guarda main_grid_delta_eta.m)
%   delta_value : escalar, el valor de delta a graficar (debe existir en
%                 grid.delta_grid; si no hay coincidencia exacta se usa
%                 el mas cercano y se avisa)
%   outDir      : (opcional) carpeta de salida. Default: 'results_out'.

    if nargin < 3 || isempty(outDir)
        outDir = 'results_out';
    end

    i_sel = find(grid.delta_grid == delta_value, 1);
    if isempty(i_sel)
        [~, i_sel] = min(abs(grid.delta_grid - delta_value));
        warning('plot_wealth_by_delta:deltaNotFound', ...
            'delta=%.4f no esta exactamente en la malla; se usa el mas cercano: delta=%.4f.', ...
            delta_value, grid.delta_grid(i_sel));
    end
    delta_actual = grid.delta_grid(i_sel);

    ne = numel(grid.eta_grid);
    colors = lines(ne);

    figure('Position', [100, 100, 1000, 600]);
    hold on;
    n_plotted = 0;
    for j = 1:ne
        r = grid.results_wdro{i_sel, j};
        if isempty(r)
            continue
        end
        label = sprintf('\\eta=%.3g', grid.eta_grid(j));
        if ~isempty(grid.baseline_col) && j == grid.baseline_col
            % Baseline (eta=0) resaltado en negro y mas grueso, ya que
            % equivale al modelo nominal y sirve de referencia visual.
            plot([r.dates(1); r.dates], r.wealth, 'LineWidth', 2.2, ...
                'Color', 'k', 'DisplayName', [label, ' (baseline)']);
        else
            plot([r.dates(1); r.dates], r.wealth, 'LineWidth', 1.2, ...
                'Color', colors(j, :), 'DisplayName', label);
        end
        n_plotted = n_plotted + 1;
    end
    hold off;

    if n_plotted == 0
        close(gcf);
        error('plot_wealth_by_delta:noResults', ...
            'No hay resultados guardados para delta=%.4f en esta malla.', delta_actual);
    end

    title(sprintf('Riqueza acumulada para \\delta=%.2f, todos los valores de \\eta', delta_actual));
    xlabel('Fecha'); ylabel('W_t / W_0');
    legend('Location', 'best', 'NumColumns', 2);
    grid on;

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    fname = sprintf('riqueza_delta_%s_todas_etas.png', ...
        strrep(sprintf('%.2f', delta_actual), '.', 'p'));
    saveas(gcf, fullfile(outDir, fname));
end
