function plot_heatmap(M, xlabels, ylabels, titleStr, cbarLabel, fmt, outDir, fileName)
% PLOT_HEATMAP  Mapa de calor anotado usando solo imagesc (sin depender
% del Statistics/ML Toolbox), para las mallas delta x eta.
%
% ENTRADAS
%   M         : (nrows x ncols) matriz a graficar (filas = delta, columnas = eta)
%   xlabels   : cell array o vector con las etiquetas de columnas (eta)
%   ylabels   : cell array o vector con las etiquetas de filas (delta)
%   titleStr  : titulo de la figura
%   cbarLabel : etiqueta de la barra de color
%   fmt       : (opcional) formato sprintf para las anotaciones, p.ej. '%.2f'
%   outDir    : (opcional) carpeta donde guardar la figura. Default: 'results_out'.
%   fileName  : (opcional) nombre del archivo .png. Si se omite, se deriva
%               de titleStr.

    if nargin < 6 || isempty(fmt)
        fmt = '%.2f';
    end
    if nargin < 7 || isempty(outDir)
        outDir = 'results_out';
    end
    if nargin < 8 || isempty(fileName)
        fileName = [matlab.lang.makeValidName(titleStr), '.png'];
    end
    if isnumeric(xlabels)
        xlabels = arrayfun(@(v) sprintf('%.3g', v), xlabels, 'UniformOutput', false);
    end
    if isnumeric(ylabels)
        ylabels = arrayfun(@(v) sprintf('%.3g', v), ylabels, 'UniformOutput', false);
    end

    figure('Position', [100, 100, 700, 500]);
    imagesc(M);
    colormap(gca, parula);
    cb = colorbar;
    cb.Label.String = cbarLabel;

    set(gca, 'XTick', 1:numel(xlabels), 'XTickLabel', xlabels, ...
             'YTick', 1:numel(ylabels), 'YTickLabel', ylabels);
    xlabel('\eta'); ylabel('\delta');
    title(titleStr);

    [nrows, ncols] = size(M);
    for r = 1:nrows
        for c = 1:ncols
            if isnan(M(r, c))
                txt = 'NA';
            else
                txt = sprintf(fmt, M(r, c));
            end
            text(c, r, txt, 'HorizontalAlignment', 'center', ...
                'Color', 'k', 'FontSize', 9);
        end
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(gcf, fullfile(outDir, fileName));
end
