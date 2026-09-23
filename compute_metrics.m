function metrics = compute_metrics(results, alpha)
% COMPUTE_METRICS  Metricas nucleo del backtest (Seccion 19 de la propuesta):
% crecimiento, perdidas (incluyendo varianza y CVaR), costos, concentracion
% y supervivencia.
%
% ENTRADA
%   results : struct devuelto por run_backtest_nominal_kelly.m /
%             run_backtest_wdro_kelly.m
%   alpha   : (opcional) nivel de confianza para VaR/CVaR, en (0,1).
%             Default: 0.95 (es decir, CVaR del peor 5% de los meses,
%             consistente con la Seccion 4.2 de la propuesta).
%
% SALIDA
%   metrics : struct con los campos descritos abajo, y un
%             metrics.table (table de MATLAB) para impresion rapida.

    if nargin < 2 || isempty(alpha)
        alpha = 0.95;
    end

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
    ret_variance = var(simple_ret);                % varianza de los retornos mensuales
                                                     % (la cantidad que penaliza Markowitz,
                                                     % ecuacion 5, aqui sobre el retorno
                                                     % REALIZADO del portafolio completo)

    % VaR y CVaR empiricos sobre la PERDIDA L = -R^p (ecuaciones 8-10).
    % Con la convencion de perdida (L > 0 = mes malo), el VaR_alpha es el
    % cuantil alpha de la perdida, y el CVaR_alpha es el promedio de las
    % perdidas que superan ese cuantil (el peor (1-alpha) de los meses).
    losses = -simple_ret;
    VaR_loss = prctile(losses, 100 * alpha);
    tail = losses(losses >= VaR_loss);
    if isempty(tail)
        CVaR_loss = VaR_loss;
    else
        CVaR_loss = mean(tail);
    end

    % --- Riesgo ajustado (Seccion 19, fila EXTENSION: Sharpe/Sortino/Calmar) ---
    % Anualizados asumiendo 12 periodos por ano (datos mensuales). No se
    % resta una tasa libre de riesgo aparte porque ya esta incorporada
    % dentro del propio retorno del portafolio (el activo de bajo riesgo
    % es una posicion mas de x).
    ret_std = std(simple_ret);
    if ret_std > 0
        sharpe = (mean(simple_ret) / ret_std) * sqrt(12);
    else
        sharpe = NaN;
    end

    downside = simple_ret(simple_ret < 0);
    if isempty(downside)
        sortino = Inf;   % ningun mes negativo en la muestra
    else
        downside_std = sqrt(mean(downside.^2));
        if downside_std > 0
            sortino = (mean(simple_ret) / downside_std) * sqrt(12);
        else
            sortino = NaN;
        end
    end

    if MDD > 0
        calmar = CAGR / MDD;
    else
        calmar = NaN;   % sin drawdown no hay forma de normalizar (division por cero)
    end

    % --- Costos ---
    turnover_total = sum(turnover);
    cost_total     = sum(cost);
    cost_mean      = mean(cost);
    TRADE_EPS      = 1e-8;   % umbral numerico: turnover por debajo de esto
                              % se considera "no hubo transaccion" ese mes
                              % (evita contar ruido de punto flotante como
                              % un rebalanceo real)
    n_rebalances   = sum(turnover > TRADE_EPS);   % # de meses con transaccion
    turnover_mean_active = NaN;
    if n_rebalances > 0
        turnover_mean_active = mean(turnover(turnover > TRADE_EPS));
    end

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
    metrics.variance_monthly = ret_variance;
    metrics.alpha_used       = alpha;
    metrics.VaR_loss         = VaR_loss;
    metrics.CVaR_loss        = CVaR_loss;
    metrics.sharpe           = sharpe;
    metrics.sortino          = sortino;
    metrics.calmar           = calmar;
    metrics.turnover_total   = turnover_total;
    metrics.cost_total       = cost_total;
    metrics.cost_mean        = cost_mean;
    metrics.n_rebalances     = n_rebalances;
    metrics.turnover_mean_active = turnover_mean_active;
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
        'Varianza retornos mensuales'; sprintf('VaR %.0f%% (perdida)', 100*alpha); ...
        sprintf('CVaR %.0f%% (perdida)', 100*alpha); ...
        'Sharpe (anualizado)'; 'Sortino (anualizado)'; 'Calmar'; ...
        'Turnover acumulado'; 'Costo acumulado'; 'Costo medio por rebalanceo'; ...
        'Numero de meses con transaccion'; 'Turnover medio (meses con transaccion)'; ...
        'Peso maximo promedio'; 'Peso maximo (pico)'; 'N efectivo promedio'; ...
        'Violaciones de delta fuera de muestra'; 'Minimo factor de crecimiento'; ...
        'Fallos del solucionador'; 'Numero de meses'};
    values = [wealth_final; g_mean; CAGR; MDD; worst_month; var5; ...
        ret_variance; VaR_loss; CVaR_loss; ...
        sharpe; sortino; calmar; ...
        turnover_total; cost_total; cost_mean; ...
        n_rebalances; turnover_mean_active; mean(max_weight_series); ...
        max(max_weight_series); mean(Neff(valid)); n_violations; min_growth; ...
        n_failed; T_dec];

    metrics.table = table(names, values, 'VariableNames', {'Metrica', 'Valor'});
end
