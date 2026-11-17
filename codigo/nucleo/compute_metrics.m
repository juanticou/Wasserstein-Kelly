function metrics = compute_metrics(results, alpha, rf)
% COMPUTE_METRICS  Metricas nucleo del backtest (Seccion 19 de la propuesta;
% seccion "Metricas y evaluacion estadistica" de metodologia_2.tex):
% crecimiento, perdidas (incluyendo varianza y CVaR), costos, concentracion
% y supervivencia.
%
% ENTRADA
%   results : struct devuelto por run_backtest_nominal_kelly.m /
%             run_backtest_wdro_kelly.m (o recortado con
%             extract_period_results.m)
%   alpha   : (opcional) nivel de confianza para VaR/CVaR, en (0,1).
%             Default: 0.95 (es decir, CVaR del peor 5% de los meses,
%             consistente con la Seccion 4.2 de la propuesta).
%   rf      : (opcional) (T_dec x 1) tasa r^f_k del mes de decision de cada
%             fila de results (la que gana el activo de bajo riesgo en el
%             mes realizado k+1). Si se omite se usa results.rf; si
%             tampoco existe, el Sharpe queda NaN (ver attach_rf.m para
%             anadirla a resultados guardados antes de este cambio).
%
% SALIDA
%   metrics : struct con los campos descritos abajo, y un
%             metrics.table (table de MATLAB) para impresion rapida.

    if nargin < 2 || isempty(alpha)
        alpha = 0.95;
    end
    if nargin < 3 || isempty(rf)
        if isfield(results, 'rf')
            rf = results.rf;
        else
            rf = [];
        end
    end

    wealth      = results.wealth;
    growth_real = results.growth_real;
    x           = results.x;          % (T_dec x d)
    turnover    = results.turnover;
    cost        = results.cost;
    delta       = results.params.delta;
    tau         = results.params.tau;

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
    var5        = prctile(simple_ret, 5);         % percentil 5 (descriptivo, interpolado)
    ret_variance = var(simple_ret);                % varianza de los retornos mensuales
                                                     % (la cantidad que penaliza Markowitz,
                                                     % ecuacion 5, aqui sobre el retorno
                                                     % REALIZADO del portafolio completo)

    % VaR y CVaR empiricos sobre la PERDIDA L_t = 1 - G^real_t. CVaR con la
    % formulacion empirica de Rockafellar-Uryasev (2000):
    %   CVaR_alpha = min_zeta { zeta + sum_t max(L_t - zeta, 0) / ((1-alpha) T) }
    % La funcion es convexa y lineal por tramos en zeta, con quiebres en
    % los L_t, asi que el minimo se alcanza en un punto de la muestra: se
    % evalua exactamente en todos ellos (maneja empates y colas de tamano
    % no entero). El VaR es el minimizador zeta*, es decir, el cuantil
    % empirico L_(ceil(alpha*T)) sin interpolar.
    losses   = -simple_ret;
    L_sorted = sort(losses);
    VaR_loss = L_sorted(max(1, ceil(alpha * T_dec - 1e-9)));
    ru_obj   = @(z) z + sum(max(losses - z, 0)) / ((1 - alpha) * T_dec);
    CVaR_loss = min(arrayfun(ru_obj, L_sorted));

    % --- Riesgo ajustado (Sharpe/Sortino/Calmar), anualizados con sqrt(12) ---
    % Sharpe: excesos mensuales e_t = R_t - r^f del mes de decision.
    % Sortino: tasa objetivo cero (no r^f), DD_0 = sqrt((1/T) sum_t
    % min(R_t,0)^2) sobre los T meses. Si el denominador es nulo la razon
    % no esta definida y se reporta NaN.
    if ~isempty(rf)
        excess = simple_ret - rf(:);
        ex_std = std(excess);
        if ex_std > 0
            sharpe = (mean(excess) / ex_std) * sqrt(12);
        else
            sharpe = NaN;
        end
    else
        warning('compute_metrics:noRf', ...
            'results no trae rf: el Sharpe con excesos sobre r^f queda NaN (usar attach_rf.m).');
        sharpe = NaN;
    end

    downside_dev = sqrt(mean(min(simple_ret, 0).^2));
    if downside_dev > 0
        sortino = (mean(simple_ret) / downside_dev) * sqrt(12);
    else
        sortino = NaN;   % ningun mes negativo: no definido
    end

    if MDD > 0
        calmar = CAGR / MDD;
    else
        calmar = NaN;   % sin drawdown no hay forma de normalizar (division por cero)
    end

    % --- Costos ---
    % cost_total/cost_mean: suma de results.cost = tau*W_k*TO_k con la
    % riqueza de la trayectoria COMPLETA (se conservan por trazabilidad;
    % en un tramo recortado NO estan en unidades de su W_0).
    % Las dos medidas de la metodologia:
    %   costo fraccional = sum_k tau*TO_k
    %   costo monetario  = sum_k W_k*tau*TO_k / W_0, con W_k la riqueza al
    %                      momento de la decision dentro del tramo evaluado
    %                      (results.wealth, re-basada en tramos recortados).
    turnover_total = sum(turnover);
    cost_total     = sum(cost);
    cost_mean      = mean(cost);
    cost_frac_total     = tau * turnover_total;
    cost_monetary_total = sum(wealth(1:T_dec) .* tau .* turnover) / wealth(1);
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
    % Sin exposicion riesgosa (sum_j x_jk <= RISK_EPS) pi_jk no esta
    % definido: N_eff = 0 y el mes no entra en los promedios de
    % concentracion. Se reporta aparte la proporcion invertida en riesgo.
    RISK_EPS  = 1e-8;
    risky_sum = sum(x, 2);                        % (T_dec x 1)
    pi_w = zeros(size(x));
    valid = risky_sum > RISK_EPS;
    pi_w(valid, :) = x(valid, :) ./ risky_sum(valid);
    Neff = zeros(T_dec, 1);
    Neff(valid) = 1 ./ sum(pi_w(valid, :).^2, 2);  % ecuacion 68
    % Neff(~valid) queda en 0, tal como indica la Seccion 19.
    max_weight_series = max(pi_w, [], 2);
    risky_share_mean  = mean(risky_sum);
    n_months_no_risk  = sum(~valid);

    % --- Supervivencia y computo ---
    n_violations = numel(results.violations);
    min_growth   = min(growth_real);
    n_failed     = sum(~strcmp(results.status, 'Solved'));   % meses sin optimizacion
    if isfield(results, 'status_class')
        status_class = results.status_class;
    else
        status_class = classify_solver_status(results.status);
    end
    n_inaccurate   = sum(strcmp(status_class, 'inaccurate'));
    n_infeasible   = sum(strcmp(status_class, 'infeasible_certificado'));
    n_numeric_fail = sum(strcmp(status_class, 'fallo_numerico'));

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
    metrics.cost_frac_total  = cost_frac_total;
    metrics.cost_monetary_total = cost_monetary_total;
    metrics.n_rebalances     = n_rebalances;
    metrics.turnover_mean_active = turnover_mean_active;
    metrics.max_weight_mean  = mean(max_weight_series(valid));
    metrics.max_weight_max   = max(max_weight_series);
    metrics.Neff_mean        = mean(Neff(valid));
    metrics.risky_share_mean = risky_share_mean;
    metrics.n_months_no_risk = n_months_no_risk;
    metrics.n_violations_delta = n_violations;
    metrics.delta_used       = delta;
    metrics.min_growth_real  = min_growth;
    metrics.n_solver_failed  = n_failed;
    metrics.n_inaccurate     = n_inaccurate;
    metrics.n_infeasible_cert = n_infeasible;
    metrics.n_numeric_fail   = n_numeric_fail;
    metrics.n_months         = T_dec;

    names = {'Riqueza final'; 'Crecimiento log. medio (mensual)'; 'CAGR (anual)'; ...
        'Maximo drawdown'; 'Peor retorno mensual'; 'Percentil 5 mensual'; ...
        'Varianza retornos mensuales'; sprintf('VaR %.0f%% (perdida)', 100*alpha); ...
        sprintf('CVaR %.0f%% (perdida)', 100*alpha); ...
        'Sharpe (anualizado, exceso sobre r^f)'; 'Sortino (anualizado, objetivo 0)'; 'Calmar'; ...
        'Turnover acumulado'; 'Costo acumulado (tau*W_k*TO_k, trayectoria completa)'; ...
        'Costo medio por rebalanceo'; 'Costo fraccional acumulado'; ...
        'Costo monetario acumulado (/W_0 del tramo)'; ...
        'Numero de meses con transaccion'; 'Turnover medio (meses con transaccion)'; ...
        'Peso maximo promedio'; 'Peso maximo (pico)'; 'N efectivo promedio'; ...
        'Proporcion media en riesgo'; 'Meses sin exposicion riesgosa'; ...
        'Violaciones de delta fuera de muestra'; 'Minimo factor de crecimiento'; ...
        'Meses sin optimizacion'; 'Meses inaccurate'; 'Meses infeasible certificado'; ...
        'Meses con fallo numerico'; 'Numero de meses'};
    values = [wealth_final; g_mean; CAGR; MDD; worst_month; var5; ...
        ret_variance; VaR_loss; CVaR_loss; ...
        sharpe; sortino; calmar; ...
        turnover_total; cost_total; cost_mean; cost_frac_total; cost_monetary_total; ...
        n_rebalances; turnover_mean_active; metrics.max_weight_mean; ...
        max(max_weight_series); mean(Neff(valid)); risky_share_mean; n_months_no_risk; ...
        n_violations; min_growth; ...
        n_failed; n_inaccurate; n_infeasible; n_numeric_fail; T_dec];

    metrics.table = table(names, values, 'VariableNames', {'Metrica', 'Valor'});
end
