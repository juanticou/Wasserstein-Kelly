function plot_turnover_series(results_list, labels, titleStr, outDir)
% PLOT_TURNOVER_SERIES  Barras del turnover (TOk, ecuacion 27) mes a mes,
% para una o varias estrategias -- responde "cuando" se concentran las
% transacciones, complementando el turnover_total y n_transacciones de
% compute_metrics.m (que solo dan totales/conteos, no la distribucion en
% el tiempo).
%
% Con mas de una estrategia, se dibuja un subplot por estrategia (barras
% superpuestas serian dificiles de leer).
%
% ENTRADAS
%   results_list : cell array de structs `results`
%   labels       : cell array de nombres, mismo orden
%   titleStr     : (opcional) titulo general de la figura
%   outDir       : (opcional) carpeta de salida. Default: 'results_out'.

    if nargin < 3 || isempty(titleStr)
        titleStr = 'Turnover mensual';
    end
    if nargin < 4 || isempty(outDir)
        outDir = 'results_out';
    end

    n = numel(results_list);
    figure('Position', [100, 100, 1000, 250 * n + 100]);
    for i = 1:n
        r = results_list{i};
        subplot(n, 1, i);
        bar(r.dates, r.turnover, 'FaceColor', [0.3 0.4 0.7]);
        ylabel('Turnover');
        title(labels{i});
        grid on;
    end
    sgtitle(titleStr);

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(gcf, fullfile(outDir, 'turnover_series.png'));
end
