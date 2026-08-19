function results = run_backtest_nominal_kelly(data, params)
% RUN_BACKTEST_NOMINAL_KELLY  Backtest de origen movil (rolling horizon)
% para el modelo de Kelly nominal con costos de transaccion, siguiendo el
% procedimiento mensual de la Seccion 17 de la propuesta.
%
% ENTRADAS
%   data   : struct devuelto por load_monthly_data.m, con campos
%            dates, R (T x d), rf_return (T x 1), mkt_return, vix.
%   params : struct con:
%       N      - tamano de la ventana movil (default 60)
%       tau    - costo proporcional de transaccion (default 0.001)
%       xbar   - limite maximo por activo (escalar o d x 1, default 0.25)
%       gamma  - limite de exposicion riesgosa total (default 1)
%       delta  - cota de supervivencia (default 0.75)
%
% SALIDA (struct `results`)
%   dates        : fechas de las decisiones (fin de cada mes k, T_dec x 1)
%   wealth       : (T_dec+1 x 1) trayectoria de riqueza, wealth(1) = 1
%                  en la fecha de la primera decision (antes de aplicar el
%                  primer retorno realizado)
%   x            : (T_dec x d) posiciones despues del rebalanceo, xjk
%   x0           : (T_dec x 1) posicion en el activo libre de riesgo
%   h            : (T_dec+1 x d+1) portafolio heredado antes de cada
%                  rebalanceo (incluye el estado inicial y el final)
%   turnover     : (T_dec x 1) TOk = sum(bjk + sjk)
%   cost         : (T_dec x 1) costo monetario del rebalanceo, Ck = tau*Wk*TOk
%   growth_real  : (T_dec x 1) factor de crecimiento realizado G^real_{k+1}
%   violations   : indices (dentro de T_dec) donde growth_real < delta
%   status       : cell array con cvx_status de cada fecha
%   params       : parametros efectivamente usados

    if nargin < 2
        params = struct();
    end
    params = set_default(params, 'N', 60);
    params = set_default(params, 'tau', 0.001);
    params = set_default(params, 'xbar', 0.25);
    params = set_default(params, 'gamma', 1);
    params = set_default(params, 'delta', 0.75);

    N = params.N;
    [T, d] = size(data.R);

    if T <= N
        error('run_backtest_nominal_kelly:notEnoughData', ...
            'Se requieren mas de N=%d observaciones; el panel solo tiene %d.', N, T);
    end

    % Fechas de decision: desde k = N (primera ventana completa) hasta
    % k = T-1 (se necesita el retorno realizado en k+1 para evaluar).
    decision_idx = N:(T - 1);
    T_dec = numel(decision_idx);

    % Estado inicial: toda la riqueza en el activo libre de riesgo
    % (Seccion 17.1): h0 = (1, 0, ..., 0).
    h_current = [1; zeros(d, 1)];
    W_current = 1;

    dates_out    = NaT(T_dec, 1);
    wealth       = zeros(T_dec + 1, 1);
    wealth(1)    = W_current;
    x_hist       = zeros(T_dec, d);
    x0_hist      = zeros(T_dec, 1);
    h_hist       = zeros(T_dec + 1, d + 1);
    h_hist(1, :) = h_current';
    turnover     = zeros(T_dec, 1);
    cost         = zeros(T_dec, 1);
    growth_real  = zeros(T_dec, 1);
    status_hist  = cell(T_dec, 1);

    for i = 1:T_dec
        k = decision_idx(i);

        % 1-2. Ventana Dk: los N retornos mas recientes hasta el mes k.
        Rk = data.R(k - N + 1 : k, :);

        % 6. Tasa libre de riesgo conocida en k.
        rf_k = data.rf_return(k);

        % 7. Resolver el modelo nominal con costos.
        [xk, bk, sk, x0k, ~, status] = solve_nominal_kelly( ...
            h_current, Rk, rf_k, params.tau, params.xbar, params.gamma, params.delta);

        status_hist{i} = status;
        if ~strcmp(status, 'Solved')
            warning('run_backtest_nominal_kelly:notSolved', ...
                'Fecha %d (indice %d): cvx_status = %s. Se mantiene la ultima solucion factible si existe.', ...
                i, k, status);
        end

        TOk = sum(bk + sk);
        Ck  = params.tau * W_current * TOk;   % costo monetario del rebalanceo

        % 8-9. Mantener xk durante el periodo y observar el retorno realizado.
        r_next = data.R(k + 1, :)';            % retornos realizados r_{k+1}
        Gk_real = x0k * (1 + rf_k) + sum(xk .* (1 + r_next));

        % 10. Actualizar riqueza y construir h_{k+1} (ecuaciones 59-62).
        W_next = W_current * Gk_real;

        if Gk_real <= 0
            warning('run_backtest_nominal_kelly:nonPositiveGrowth', ...
                'Factor de crecimiento realizado no positivo en la fecha %d (indice %d). Deteniendo backtest.', ...
                i, k);
            % Se registra lo obtenido hasta el momento y se trunca.
            dates_out(i)   = data.dates(k);
            x_hist(i, :)   = xk';
            x0_hist(i)     = x0k;
            turnover(i)    = TOk;
            cost(i)        = Ck;
            growth_real(i) = Gk_real;
            wealth(i + 1)  = W_next;

            results = pack_results(dates_out(1:i), wealth(1:i+1), x_hist(1:i,:), ...
                x0_hist(1:i), h_hist(1:i+1,:), turnover(1:i), cost(1:i), ...
                growth_real(1:i), status_hist(1:i), params);
            return
        end

        h0_next = x0k * (1 + rf_k) / Gk_real;
        hj_next = xk .* (1 + r_next) / Gk_real;
        h_next  = [h0_next; hj_next];

        % --- Registrar resultados de esta fecha ---
        dates_out(i)     = data.dates(k);
        x_hist(i, :)      = xk';
        x0_hist(i)        = x0k;
        turnover(i)       = TOk;
        cost(i)           = Ck;
        growth_real(i)    = Gk_real;
        wealth(i + 1)     = W_next;
        h_hist(i + 1, :)  = h_next';

        % 11. Desplazar la ventana: pasar al siguiente periodo.
        h_current = h_next;
        W_current = W_next;
    end

    results = pack_results(dates_out, wealth, x_hist, x0_hist, h_hist, ...
        turnover, cost, growth_real, status_hist, params);
end


function s = set_default(s, field, value)
    if ~isfield(s, field) || isempty(s.(field))
        s.(field) = value;
    end
end


function results = pack_results(dates, wealth, x, x0, h, turnover, cost, ...
    growth_real, status, params)

    results.dates       = dates;
    results.wealth      = wealth;
    results.x           = x;
    results.x0          = x0;
    results.h           = h;
    results.turnover    = turnover;
    results.cost        = cost;
    results.growth_real = growth_real;
    results.violations  = find(growth_real < params.delta);
    results.status      = status;
    results.params      = params;
end
