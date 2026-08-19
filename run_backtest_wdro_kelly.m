function results = run_backtest_wdro_kelly(data, params)
% RUN_BACKTEST_WDRO_KELLY  Backtest de origen movil para el modelo
% Wasserstein-Kelly (formulacion 53), analogo a
% run_backtest_nominal_kelly.m pero recalculando en cada fecha k:
%   1. la matriz de costos de transporte C_k (build_transport_cost.m,
%      Geometria 1: solo retornos, ecuacion 42), usando UNICAMENTE la
%      ventana Dk vigente en esa fecha;
%   2. el radio efectivo rho_k = eta * mediana(C_k) (compute_rho.m,
%      ecuacion 63).
%
% ENTRADAS
%   data   : struct de load_monthly_data.m (dates, R, rf_return, ...).
%   params : struct con los mismos campos que run_backtest_nominal_kelly.m
%            (N, tau, xbar, gamma, delta, solver) MAS:
%       eta      - intensidad relativa de robustez (Cuadro 8: 0, 0.05,
%                  0.15, 0.30). eta=0 debe reproducir el modelo nominal.
%       eps_esc  - (opcional) piso para la estandarizacion en
%                  build_transport_cost.m (default 1e-6).
%
% SALIDA (struct `results`) — mismos campos que run_backtest_nominal_kelly.m
% (dates, wealth, x, x0, h, turnover, cost, growth_real, violations,
% status, params) MAS:
%   rho    : (T_dec x 1) radio de Wasserstein efectivamente usado cada mes
%   lambda : (T_dec x 1) variable dual del presupuesto de transporte
%            (valor marginal del radio; ~0 sugiere que la restriccion de
%            robustez no esta activa en esa fecha)

    if nargin < 2
        params = struct();
    end
    params = set_default(params, 'N', 60);
    params = set_default(params, 'tau', 0.001);
    params = set_default(params, 'xbar', 0.25);
    params = set_default(params, 'gamma', 1);
    params = set_default(params, 'delta', 0.75);
    params = set_default(params, 'solver', 'mosek');
    params = set_default(params, 'eta', 0.15);
    params = set_default(params, 'eps_esc', 1e-6);

    N = params.N;
    [T, d] = size(data.R);

    if T <= N
        error('run_backtest_wdro_kelly:notEnoughData', ...
            'Se requieren mas de N=%d observaciones; el panel solo tiene %d.', N, T);
    end

    decision_idx = N:(T - 1);
    T_dec = numel(decision_idx);

    h_current = [1; zeros(d, 1)];   % Seccion 17.1: todo en el activo libre de riesgo
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
    rho_hist     = zeros(T_dec, 1);
    lambda_hist  = zeros(T_dec, 1);
    status_hist  = cell(T_dec, 1);

    for i = 1:T_dec
        k = decision_idx(i);

        % 1-2. Ventana Dk.
        Rk = data.R(k - N + 1 : k, :);
        rf_k = data.rf_return(k);

        % Geometria y radio de la fecha k, usando SOLO informacion de Rk.
        Ck = build_transport_cost(Rk, params.eps_esc);
        rho_k = compute_rho(Ck, params.eta);

        % Resolver el modelo Wasserstein-Kelly con costos.
        [xk, bk, sk, x0k, ~, lambda_k, ~, status] = solve_wdro_kelly( ...
            h_current, Rk, rf_k, params.tau, params.xbar, params.gamma, ...
            params.delta, Ck, rho_k, params.solver);

        status_hist{i} = status;
        if ~strcmp(status, 'Solved')
            warning('run_backtest_wdro_kelly:notSolved', ...
                'Fecha %d (indice %d): cvx_status = %s.', i, k, status);
        end

        TOk = sum(bk + sk);
        Ck_cost = params.tau * W_current * TOk;

        r_next = data.R(k + 1, :)';
        Gk_real = x0k * (1 + rf_k) + sum(xk .* (1 + r_next));
        W_next = W_current * Gk_real;

        if Gk_real <= 0
            warning('run_backtest_wdro_kelly:nonPositiveGrowth', ...
                'Factor de crecimiento realizado no positivo en la fecha %d (indice %d). Deteniendo backtest.', ...
                i, k);
            dates_out(i)   = data.dates(k);
            x_hist(i, :)   = xk';
            x0_hist(i)     = x0k;
            turnover(i)    = TOk;
            cost(i)        = Ck_cost;
            growth_real(i) = Gk_real;
            rho_hist(i)    = rho_k;
            lambda_hist(i) = lambda_k;
            wealth(i + 1)  = W_next;

            results = pack_results(dates_out(1:i), wealth(1:i+1), x_hist(1:i,:), ...
                x0_hist(1:i), h_hist(1:i+1,:), turnover(1:i), cost(1:i), ...
                growth_real(1:i), rho_hist(1:i), lambda_hist(1:i), status_hist(1:i), params);
            return
        end

        h0_next = x0k * (1 + rf_k) / Gk_real;
        hj_next = xk .* (1 + r_next) / Gk_real;
        h_next  = [h0_next; hj_next];

        dates_out(i)      = data.dates(k);
        x_hist(i, :)      = xk';
        x0_hist(i)        = x0k;
        turnover(i)       = TOk;
        cost(i)           = Ck_cost;
        growth_real(i)    = Gk_real;
        rho_hist(i)       = rho_k;
        lambda_hist(i)    = lambda_k;
        wealth(i + 1)     = W_next;
        h_hist(i + 1, :)  = h_next';

        h_current = h_next;
        W_current = W_next;
    end

    results = pack_results(dates_out, wealth, x_hist, x0_hist, h_hist, ...
        turnover, cost, growth_real, rho_hist, lambda_hist, status_hist, params);
end


function s = set_default(s, field, value)
    if ~isfield(s, field) || isempty(s.(field))
        s.(field) = value;
    end
end


function results = pack_results(dates, wealth, x, x0, h, turnover, cost, ...
    growth_real, rho, lambda, status, params)

    results.dates       = dates;
    results.wealth      = wealth;
    results.x           = x;
    results.x0          = x0;
    results.h           = h;
    results.turnover    = turnover;
    results.cost        = cost;
    results.growth_real = growth_real;
    results.rho         = rho;
    results.lambda      = lambda;
    results.violations  = find(growth_real < params.delta);
    results.status      = status;
    results.params      = params;
end
