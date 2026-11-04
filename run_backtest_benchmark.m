function results = run_backtest_benchmark(data, tipo, params)
% RUN_BACKTEST_BENCHMARK  Backtest de origen movil de los benchmarks del
% Cuadro 7 de la propuesta (NUCLEO), con el mismo protocolo que
% run_backtest_nominal_kelly.m: primera decision en k = N, W_0 = 1,
% h_0 = (1, 0, ..., 0) y una decision por mes hasta k = T-1. Ninguno
% optimiza ni usa la ventana; solo r^f_k (conocida en k) y retornos
% realizados en k+1.
%
% TIPOS
%   'bajo_riesgo'       : x_0 = 1 todos los meses; G = 1 + r^f_k; sin costos.
%   'igual_ponderacion' : rebalanceo mensual a x_j = c/d, x_0 = 0, con la
%                         convencion de costos del modelo (bal_0):
%                         x_0 + sum_j x_j = 1 - tau * TO,  TO = sum_j |x_j - h_j|.
%                         c es la unica raiz de f(c) = c - 1 + tau*sum_j|c/d - h_j|
%                         (f es estrictamente creciente), hallada por biseccion.
%   'spy'               : comprar y mantener SPY. El primer mes compra desde
%                         efectivo: x_SPY = 1/(1+tau) (costo tau*x_SPY); despues
%                         no opera (TO = 0) y G = x_SPY*(1 + m_{k+1}), con
%                         data.mkt_return. x es una sola columna (SPY), por lo
%                         que N_eff y peso maximo no son comparables con las
%                         estrategias sobre las 10 acciones.
%
% ENTRADAS
%   data   : struct de load_monthly_data.m (dates, R, rf_return, mkt_return)
%   tipo   : uno de los tres anteriores
%   params : struct con N (default 60) y tau (default 0.001)
%
% SALIDA: struct con los mismos campos que run_backtest_nominal_kelly.m
% (dates, wealth, x, x0, h, turnover, cost, growth_real, violations,
% status, status_class, rf, params). params.delta = NaN: los benchmarks no
% tienen cota de supervivencia, asi que no se cuentan violaciones de delta.

    if nargin < 3, params = struct(); end
    if ~isfield(params, 'N'),   params.N   = 60;    end
    if ~isfield(params, 'tau'), params.tau = 0.001; end
    params.delta = NaN;
    params.tipo  = tipo;
    N = params.N; tau = params.tau;

    [T, d] = size(data.R);
    switch tipo
        case {'bajo_riesgo', 'igual_ponderacion'}
            Ret = data.R; m = d;
        case 'spy'
            Ret = data.mkt_return(:); m = 1;
        otherwise
            error('run_backtest_benchmark:tipo', 'Tipo desconocido: %s', tipo);
    end

    decision_idx = N:(T - 1);
    T_dec = numel(decision_idx);

    h = [1; zeros(m, 1)];
    W = 1;
    dates = data.dates(decision_idx);
    wealth = zeros(T_dec + 1, 1); wealth(1) = W;
    x_hist = zeros(T_dec, m); x0_hist = zeros(T_dec, 1);
    h_hist = zeros(T_dec + 1, m + 1); h_hist(1, :) = h';
    turnover = zeros(T_dec, 1); cost = zeros(T_dec, 1);
    growth = zeros(T_dec, 1); rf_hist = zeros(T_dec, 1);

    for i = 1:T_dec
        k = decision_idx(i);
        rf_k = data.rf_return(k);
        hj = h(2:end);

        switch tipo
            case 'bajo_riesgo'
                % Vender todo lo riesgoso (nunca hay, h_j = 0 siempre).
                TO = sum(hj); xj = zeros(m, 1); x0 = h(1) + sum(hj) - tau * TO;
            case 'igual_ponderacion'
                f = @(c) c - 1 + tau * sum(abs(c / d - hj));
                lo = 0; hi = 1;            % f(0) <= 0 <= f(1)
                for it = 1:200
                    mid = (lo + hi) / 2;
                    if f(mid) > 0, hi = mid; else, lo = mid; end
                end
                c = (lo + hi) / 2;
                xj = (c / d) * ones(m, 1); x0 = 0;
                TO = sum(abs(xj - hj));
            case 'spy'
                if i == 1
                    xj = 1 / (1 + tau); x0 = 0; TO = xj;
                else
                    xj = hj; x0 = h(1); TO = 0;
                end
        end

        Ck = tau * W * TO;
        r_next = Ret(k + 1, :)';
        G = x0 * (1 + rf_k) + sum(xj .* (1 + r_next));
        W_next = W * G;

        x_hist(i, :) = xj'; x0_hist(i) = x0;
        turnover(i) = TO; cost(i) = Ck; growth(i) = G; rf_hist(i) = rf_k;
        wealth(i + 1) = W_next;

        h = [x0 * (1 + rf_k); xj .* (1 + r_next)] / G;
        h_hist(i + 1, :) = h';
        W = W_next;
    end

    results.dates        = dates;
    results.wealth       = wealth;
    results.x            = x_hist;
    results.x0           = x0_hist;
    results.h            = h_hist;
    results.turnover     = turnover;
    results.cost         = cost;
    results.growth_real  = growth;
    results.violations   = [];
    results.status       = repmat({'Solved'}, T_dec, 1);
    results.status_class = repmat({'optimo'}, T_dec, 1);
    results.rf           = rf_hist;
    results.params       = params;
end
