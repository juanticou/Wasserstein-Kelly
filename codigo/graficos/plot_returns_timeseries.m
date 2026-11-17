function plot_returns_timeseries(results_list, labels, titleStr, outDir)
% PLOT_RETURNS_TIMESERIES  Serie de tiempo de los retornos mensuales
% REALIZADOS del portafolio (no la riqueza acumulada), para una o varias
% estrategias superpuestas.
%
% El retorno mensual realizado de la estrategia es
%   ret_k = G^real_{k+1} - 1
% que es exactamente results.growth_real - 1 (ver run_backtest_*.m).
%
% ENTRADAS
%   results_list : cell array de structs `results` (salida de
%                  run_backtest_nominal_kelly.m / run_backtest_wdro_kelly.m)
%   labels       : cell array de nombres para la leyenda, mismo orden
%   titleStr     : (opcional) titulo de la figura
%   outDir       : (opcional) carpeta de salida. Default: 'results_out'.

    if nargin < 3 || isempty(titleStr)
        titleStr = 'Retornos mensuales realizados del portafolio';
    end
    if nargin < 4 || isempty(outDir)
        outDir = 'results_out';
    end

    figure('Position', [100, 100, 950, 500]);
    hold on;
    colors = lines(numel(results_list));
    for i = 1:numel(results_list)
        r = results_list{i};
        ret = r.growth_real - 1;
        plot(r.dates, ret, 'LineWidth', 1.1, 'Color', colors(i, :), ...
            'DisplayName', labels{i});
    end
    yline(0, 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    hold off;

    ytickformat('percentage');
    xlabel('Fecha'); ylabel('Retorno mensual realizado');
    title(titleStr);
    legend('Location', 'best');
    grid on;

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(gcf, fullfile(outDir, 'retornos_mensuales_timeseries.png'));
end
