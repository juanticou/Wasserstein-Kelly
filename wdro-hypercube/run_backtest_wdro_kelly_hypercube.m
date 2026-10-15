function results = run_backtest_wdro_kelly_hypercube(data, params)
% RUN_BACKTEST_WDRO_KELLY_HYPERCUBE  Backtest de origen movil para la
% variante del modelo Wasserstein-Kelly donde el adversario puede mover
% probabilidad hacia escenarios SINTETICOS muestreados uniformemente en
% el hipercubo de la ventana (sample_hypercube_scenarios.m), ademas de
% los N escenarios historicos -- en vez de estar confinado a los puntos
% ya observados (ver solve_wdro_kelly_hypercube.m).
%
% En cada fecha k, usando UNICAMENTE la ventana Dk vigente:
%   1. se muestrean M escenarios sinteticos del hipercubo
%      (sample_hypercube_scenarios.m);
%   2. se construye la matriz de costos RECTANGULAR N x (N+M)
%      (build_transport_cost_hypercube.m);
%   3. se calcula el radio rho_k = eta * mediana(C_k) (compute_rho.m,
%      generalizado para matrices rectangulares -- mismo resultado que
%      antes para el caso cuadrado).
%
% ENTRADAS
%   data   : struct de load_monthly_data.m (dates, R, rf_return, ...).
%   params : struct con los mismos campos que run_backtest_wdro_kelly.m
%            (N, tau, xbar, gamma, delta, solver, eta, eps_esc) MAS:
%       M_synth  - numero de escenarios sinteticos por fecha (default 100).
%                  OJO: el costo computacional escala como N*(N+M_synth),
%                  no N^2 -- valores grandes de M_synth pueden ser lentos.
%       rng_seed - (opcional) semilla para el muestreo del hipercubo, para
%                  reproducibilidad entre corridas (default: sin fijar,
%                  cada corrida genera sinteticos distintos).
%       apply_delta_to_synthetic - (opcional, default true) ver
%                  solve_wdro_kelly_hypercube.m.
%
% SALIDA (struct `results`) — mismos campos que run_backtest_wdro_kelly.m
% (dates, wealth, x, x0, h, turnover, cost, growth_real, rho, lambda,
% violations, status, params).

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
    params = set_default(params, 'M_synth', 100);
    params = set_default(params, 'rng_seed', []);
    params = set_default(params, 'apply_delta_to_synthetic', true);

    N = params.N;
    [T, d] = size(data.R);

    if T <= N
        error('run_backtest_wdro_kelly_hypercube:notEnoughData', ...
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

        % Escenarios sinteticos del hipercubo de ESTA ventana (nunca de
        % informacion fuera de Dk) y matriz de costos rectangular.
        seed_k = params.rng_seed;
        if ~isempty(seed_k)
            seed_k = seed_k + k;   % semilla distinta mas reproducible por fecha
        end
        Rk_synth = sample_hypercube_scenarios(Rk, params.M_synth, seed_k);
        Ck = build_transport_cost_hypercube(Rk, Rk_synth, params.eps_esc);
        rho_k = compute_rho(Ck, params.eta);

        % Resolver el modelo Wasserstein-Kelly con soporte ampliado al hipercubo.
        [xk, bk, sk, x0k, ~, lambda_k, ~, status] = solve_wdro_kelly_hypercube( ...
            h_current, Rk, Rk_synth, rf_k, params.tau, params.xbar, params.gamma, ...
            params.delta, Ck, rho_k, params.solver, params.apply_delta_to_synthetic);

        status_hist{i} = status;
        if ~strcmp(status, 'Solved')
            warning('run_backtest_wdro_kelly_hypercube:notSolved', ...
                ['Fecha %d (indice %d): cvx_status = %s. Se mantiene el portafolio ', ...
                 'heredado sin rebalancear este mes (fallback de factibilidad).'], ...
                i, k, status);
            xk = h_current(2:end);
            x0k = h_current(1);
            bk = zeros(d, 1);
            sk = zeros(d, 1);
            lambda_k = NaN;   % no hay solucion dual valida esta fecha
        end

        TOk = sum(bk + sk);
        Ck_cost = params.tau * W_current * TOk;

        r_next = data.R(k + 1, :)';
        Gk_real = x0k * (1 + rf_k) + sum(xk .* (1 + r_next));
        W_next = W_current * Gk_real;

        if Gk_real <= 0
            warning('run_backtest_wdro_kelly_hypercube:nonPositiveGrowth', ...
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
