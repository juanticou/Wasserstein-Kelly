function metrics = compute_metrics(results)
% COMPUTE_METRICS  Metricas nucleo del backtest (Seccion 19 de la propuesta):
% crecimiento, perdidas, costos, concentracion y supervivencia.
%
% ENTRADA
%   results : struct devuelto por run_backtest_nominal_kelly.m
%
% SALIDA
%   metrics : struct con los campos descritos abajo, y un
%             metrics.table (table de MATLAB) para impresion rapida.

    wealth      = results.wealth;
    growth_real = results.growth_real;
    x           = results.x;          % (T_dec x d)
    turnover    = results.turnover;
    cost        = results.cost;
    delta       = results.params.delta;

    T_dec = numel(growth_real);

    % --- Crecimiento ---
    wealth_final = wealth(end);
    log_growth   = log(growth_real);           % log(W_{k+1}/W_k), un valor por mes
    g_mean       = mean(log_growth);            % ecuacion 65
    CAGR         = (wealth_final / wealth(1)) ^ (12 / T_dec) - 1;  % ecuacion 66

    % --- Perdidas ---
    running_max = cummax(wealth);
    drawdown    = 1 - wealth ./ running_max;
    MDD         = max(drawdown);                 % ecuacion 67
    simple_ret  = growth_real - 1;                % retorno mensual del portafolio
    worst_month = min(simple_ret);
    var5        = prctile(simple_ret, 5);         % percentil 5 (proxy de VaR empirico)

    % --- Costos ---
    turnover_total = sum(turnover);
    cost_total     = sum(cost);
    cost_mean      = mean(cost);

    % --- Concentracion ---
    risky_sum = sum(x, 2);                        % (T_dec x 1)
    pi_w = zeros(size(x));
    valid = risky_sum > 0;
    pi_w(valid, :) = x(valid, :) ./ risky_sum(valid);
    Neff = zeros(T_dec, 1);
    Neff(valid) = 1 ./ sum(pi_w(valid, :).^2, 2);  % ecuacion 68
    % Neff(~valid) queda en 0, tal como indica la Seccion 19.
    max_weight_series = max(pi_w, [], 2);

    % --- Supervivencia ---
    n_violations = numel(results.violations);
    min_growth   = min(growth_real);
    n_failed     = sum(~strcmp(results.status, 'Solved'));

    % --- Empaquetado ---
    metrics.wealth_final     = wealth_final;
    metrics.log_growth_mean  = g_mean;
    metrics.CAGR             = CAGR;
    metrics.max_drawdown     = MDD;
    metrics.worst_month      = worst_month;
    metrics.var5_monthly     = var5;
    metrics.turnover_total   = turnover_total;
    metrics.cost_total       = cost_total;
    metrics.cost_mean        = cost_mean;
    metrics.max_weight_mean  = mean(max_weight_series);
    metrics.max_weight_max   = max(max_weight_series);
    metrics.Neff_mean        = mean(Neff(valid));
    metrics.n_violations_delta = n_violations;
    metrics.delta_used       = delta;
    metrics.min_growth_real  = min_growth;
    metrics.n_solver_failed  = n_failed;
    metrics.n_months         = T_dec;

    names = {'Riqueza final'; 'Crecimiento log. medio (mensual)'; 'CAGR (anual)'; ...
        'Maximo drawdown'; 'Peor retorno mensual'; 'Percentil 5 mensual'; ...
        'Turnover acumulado'; 'Costo acumulado'; 'Costo medio por rebalanceo'; ...
        'Peso maximo promedio'; 'Peso maximo (pico)'; 'N efectivo promedio'; ...
        'Violaciones de delta fuera de muestra'; 'Minimo factor de crecimiento'; ...
        'Fallos del solucionador'; 'Numero de meses'};
    values = [wealth_final; g_mean; CAGR; MDD; worst_month; var5; ...
        turnover_total; cost_total; cost_mean; mean(max_weight_series); ...
        max(max_weight_series); mean(Neff(valid)); n_violations; min_growth; ...
        n_failed; T_dec];

    metrics.table = table(names, values, 'VariableNames', {'Metrica', 'Valor'});
end
