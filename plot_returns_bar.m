function plot_returns_bar(results, label, outDir)
% PLOT_RETURNS_BAR  Grafica de barras de los retornos mensuales
% realizados de UNA estrategia, con color segun el signo (verde
% positivo, rojo negativo) — util para inspeccionar meses individuales
% de perdidas grandes que el drawdown resume pero no muestra uno a uno.
%
% ENTRADAS
%   results : struct `results` de run_backtest_nominal_kelly.m o
%             run_backtest_wdro_kelly.m
%   label   : (opcional) nombre de la estrategia para el titulo
%   outDir  : (opcional) carpeta de salida. Default: 'results_out'.

    if nargin < 2 || isempty(label)
        label = 'Estrategia';
    end
    if nargin < 3 || isempty(outDir)
        outDir = 'results_out';
    end

    ret = results.growth_real - 1;
    dates = results.dates;

    figure('Position', [100, 100, 950, 450]);
    colors = repmat([0.85 0.2 0.2], numel(ret), 1);   % rojo por defecto
    colors(ret >= 0, :) = repmat([0.2 0.6 0.3], sum(ret >= 0), 1);  % verde

    b = bar(dates, ret, 'FaceColor', 'flat');
    b.CData = colors;

    ytickformat('percentage');
    xlabel('Fecha'); ylabel('Retorno mensual realizado');
    title(sprintf('Retornos mensuales realizados - %s', label));
    grid on;

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    fname = sprintf('retornos_mensuales_bar_%s.png', matlab.lang.makeValidName(label));
    saveas(gcf, fullfile(outDir, fname));
end
