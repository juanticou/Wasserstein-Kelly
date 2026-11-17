function plot_drawdown_series(results_list, labels, titleStr, outDir)
% PLOT_DRAWDOWN_SERIES  Serie de tiempo del drawdown (1 - W_t/max(W_1..t)),
% no solo el maximo -- muestra CUANDO ocurrieron las caidas y cuanto
% duraron, informacion que el max_drawdown (un solo numero) no captura.
%
% ENTRADAS
%   results_list : cell array de structs `results`
%   labels       : cell array de nombres, mismo orden
%   titleStr     : (opcional) titulo de la figura
%   outDir       : (opcional) carpeta de salida. Default: 'results_out'.

    if nargin < 3 || isempty(titleStr)
        titleStr = 'Drawdown en el tiempo';
    end
    if nargin < 4 || isempty(outDir)
        outDir = 'results_out';
    end

    figure('Position', [100, 100, 1000, 500]);
    hold on;
    colors = lines(numel(results_list));
    for i = 1:numel(results_list)
        r = results_list{i};
        running_max = cummax(r.wealth);
        dd = 1 - r.wealth ./ running_max;
        plot([r.dates(1); r.dates], 100 * dd, 'LineWidth', 1.3, ...
            'Color', colors(i, :), 'DisplayName', labels{i});
    end
    hold off;

    set(gca, 'YDir', 'reverse');   % drawdowns hacia abajo, visualmente intuitivo
    xlabel('Fecha'); ylabel('Drawdown (%)');
    title(titleStr);
    legend('Location', 'best');
    grid on;

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(gcf, fullfile(outDir, 'drawdown_series.png'));
end
