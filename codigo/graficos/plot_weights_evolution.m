function plot_weights_evolution(results, tickers, titleStr, outDir)
% PLOT_WEIGHTS_EVOLUTION  Grafica de area apilada de la composicion del
% portafolio (activo de bajo riesgo + cada accion) mes a mes -- muestra
% COMO cambia la asignacion a lo largo del tiempo, algo que ni el peso
% maximo promedio ni el N efectivo (ambos resumenes de un solo numero)
% dejan ver.
%
% ENTRADAS
%   results   : struct `results` (una sola estrategia -- una grafica
%               apilada con dos estrategias a la vez seria ilegible)
%   tickers   : cell array con los nombres de las d acciones, en el mismo
%               orden de las columnas de results.x
%   titleStr  : (opcional) titulo de la figura
%   outDir    : (opcional) carpeta de salida. Default: 'results_out'.

    if nargin < 3 || isempty(titleStr)
        titleStr = 'Evolucion de la composicion del portafolio';
    end
    if nargin < 4 || isempty(outDir)
        outDir = 'results_out';
    end

    W = [results.x0, results.x];   % (T x (d+1)), columna 1 = bajo riesgo
    labels = [{'Bajo riesgo'}, tickers(:)'];

    figure('Position', [100, 100, 1050, 550]);
    area(results.dates, W);
    colormap(lines(numel(labels)));

    xlabel('Fecha'); ylabel('Fraccion de la riqueza (pre-costos)');
    title(titleStr);
    legend(labels, 'Location', 'eastoutside');
    ylim([0, max(1, max(sum(W, 2)))]);
    grid on;

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(gcf, fullfile(outDir, 'evolucion_composicion_portafolio.png'));
end
