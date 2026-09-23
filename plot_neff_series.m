function plot_neff_series(results_list, labels, titleStr, outDir)
% PLOT_NEFF_SERIES  Serie de tiempo del numero efectivo de activos
% riesgosos, Neff_k = 1 / sum(pi_jk^2) (ecuacion 68), donde pi_jk son las
% ponderaciones riesgosas normalizadas. Muestra COMO evoluciona la
% concentracion mes a mes, no solo el promedio (Neff_mean de
% compute_metrics.m).
%
% ENTRADAS
%   results_list : cell array de structs `results`
%   labels       : cell array de nombres, mismo orden
%   titleStr     : (opcional) titulo de la figura
%   outDir       : (opcional) carpeta de salida. Default: 'results_out'.

    if nargin < 3 || isempty(titleStr)
        titleStr = 'Numero efectivo de activos riesgosos (N_{eff}) en el tiempo';
    end
    if nargin < 4 || isempty(outDir)
        outDir = 'results_out';
    end

    figure('Position', [100, 100, 1000, 500]);
    hold on;
    colors = lines(numel(results_list));
    for i = 1:numel(results_list)
        r = results_list{i};
        risky_sum = sum(r.x, 2);
        pi_w = zeros(size(r.x));
        valid = risky_sum > 0;
        pi_w(valid, :) = r.x(valid, :) ./ risky_sum(valid);
        Neff = zeros(size(r.x, 1), 1);
        Neff(valid) = 1 ./ sum(pi_w(valid, :).^2, 2);

        plot(r.dates, Neff, 'LineWidth', 1.3, 'Color', colors(i, :), ...
            'DisplayName', labels{i});
    end
    hold off;

    xlabel('Fecha'); ylabel('N_{eff}');
    title(titleStr);
    legend('Location', 'best');
    grid on;

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(gcf, fullfile(outDir, 'neff_series.png'));
end
