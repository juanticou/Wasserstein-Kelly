function plot_returns_boxplot(results_list, labels, titleStr, outDir)
% PLOT_RETURNS_BOXPLOT  Distribucion (boxplot) de los retornos mensuales
% realizados de cada estrategia, para comparar dispersion y colas -no solo
% el promedio que resume la riqueza acumulada.
%
% Requiere el Statistics and Machine Learning Toolbox (funcion boxplot).
%
% ENTRADAS
%   results_list : cell array de structs `results`
%   labels       : cell array de nombres, mismo orden
%   titleStr     : (opcional) titulo de la figura
%   outDir       : (opcional) carpeta de salida. Default: 'results_out'.

    if nargin < 3 || isempty(titleStr)
        titleStr = 'Distribucion de retornos mensuales por estrategia';
    end
    if nargin < 4 || isempty(outDir)
        outDir = 'results_out';
    end

    % boxplot necesita un vector de datos y un vector de grupos del mismo
    % largo (las estrategias pueden tener distinto numero de meses si
    % alguna se detuvo por G_real <= 0).
    all_ret = [];
    all_grp = [];
    for i = 1:numel(results_list)
        ret = results_list{i}.growth_real - 1;
        all_ret = [all_ret; ret(:)]; %#ok<AGROW>
        all_grp = [all_grp; repmat(labels(i), numel(ret), 1)]; %#ok<AGROW>
    end

    figure('Position', [100, 100, 800, 500]);
    try
        boxplot(all_ret, all_grp);
    catch ME
        close(gcf);
        error('plot_returns_boxplot:noStatsToolbox', ...
            ['boxplot() requiere el Statistics and Machine Learning Toolbox. ', ...
             'Error original: %s'], ME.message);
    end
    ytickformat('percentage');
    ylabel('Retorno mensual realizado');
    title(titleStr);
    grid on;

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(gcf, fullfile(outDir, 'retornos_mensuales_boxplot.png'));
end
