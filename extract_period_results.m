function sub = extract_period_results(results, period_start, period_end)
% EXTRACT_PERIOD_RESULTS  Extrae de un `results` completo (salida de
% run_backtest_nominal_kelly.m / run_backtest_wdro_kelly.m /
% run_backtest_wdro_kelly_market.m) solo los meses cuyo retorno REALIZADO
% cae dentro de [period_start, period_end], y reconstruye una riqueza
% re-basada a 1 al inicio de ese tramo -- para poder evaluar el periodo
% de validacion (2015-2018) y el periodo de prueba (2019-2025) por
% separado, tal como exige la Seccion 17.3 de la propuesta.
%
% IMPORTANTE sobre por que esto es valido sin volver a correr el backtest:
% cada decision xk del backtest de origen movil usa UNICAMENTE la ventana
% Dk (informacion hasta la fecha k), nunca datos posteriores. Por tanto,
% los meses correspondientes a 2015-2018 dentro de un backtest que corrio
% hasta 2025 son IDENTICOS a los que se habrian obtenido deteniendo el
% backtest en 2018 -- particionar por fecha DESPUES de correr es
% matematicamente equivalente a correr cada tramo por separado, pero sin
% repetir el computo.
%
% NOTA sobre las fechas: results.dates(i) es la fecha de DECISION (fin de
% la ventana Dk, ecuacion en run_backtest_*.m), no la fecha en la que se
% realiza growth_real(i) -- ese retorno se realiza el mes SIGUIENTE. Por
% eso aqui se calcula la fecha de realizacion como el mes calendario
% siguiente a cada fecha de decision, y esa es la fecha que se compara
% contra [period_start, period_end].
%
% ENTRADAS
%   results      : struct `results` completo
%   period_start : datetime, inicio del periodo (inclusive)
%   period_end   : datetime, fin del periodo (inclusive)
%
% SALIDA
%   sub : struct con los mismos campos relevantes de `results`
%         (dates, growth_real, turnover, cost, x, x0, status, params,
%         wealth, violations, y rho/lambda si existian), pero:
%         - dates ahora es la fecha de REALIZACION (no de decision)
%         - wealth arranca en 1 al primer mes del periodo (no es la
%           riqueza acumulada del backtest completo)
%         - compatible tal cual con compute_metrics.m y con
%           plot_returns_*.m / plot_wealth_by_delta.m

    if nargin < 3
        error('extract_period_results:missingArgs', ...
            'Se requieren period_start y period_end (datetime).');
    end

    % Fecha en la que se realiza growth_real(i): el mes siguiente al de
    % decision (dates(i) esta al final de la ventana Dk que se uso para
    % decidir; el retorno aplicado se observa un mes despues).
    realized_dates = dateshift(results.dates, 'end', 'month', 1);

    idx = find(realized_dates >= period_start & realized_dates <= period_end);
    if isempty(idx)
        error('extract_period_results:empty', ...
            'Ningun mes de results cae dentro de [%s, %s].', ...
            datestr(period_start), datestr(period_end));
    end

    sub.dates       = realized_dates(idx);
    sub.growth_real = results.growth_real(idx);
    sub.turnover    = results.turnover(idx);
    sub.cost        = results.cost(idx);
    sub.x           = results.x(idx, :);
    sub.x0          = results.x0(idx);
    sub.status      = results.status(idx);
    sub.params      = results.params;

    % Riqueza re-basada: 1 al comienzo del tramo, luego el producto de
    % los factores de crecimiento REALIZADOS dentro del tramo (ecuacion 13,
    % aplicada solo a este subconjunto de meses).
    sub.wealth = [1; cumprod(sub.growth_real)];
    sub.violations = find(sub.growth_real < sub.params.delta);

    if isfield(results, 'rho')
        sub.rho = results.rho(idx);
    end
    if isfield(results, 'lambda')
        sub.lambda = results.lambda(idx);
    end
end
