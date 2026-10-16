%% test_ret_equivalence.m
% Verificaciones rapidas ANTES de confiar en el backtest con la restriccion
% de retorno esperado robusto (Fonseca y Junca, arXiv:2111.04663). Usa una
% ventana sintetica pequena (no toca los datos reales). Requiere CVX + MOSEK.
%
%   (a) mu = -Inf debe reproducir EXACTAMENTE solve_wdro_kelly.m.
%   (b) Consistencia con la frontera de factibilidad: con mu apenas por
%       debajo de v(eps) el problema debe resolverse; apenas por encima,
%       debe ser infactible (para eps = 0 y para eps > 0).
%   (c) eps_max_for_mu debe quedar sobre la frontera: factible en eps_max
%       e infactible un poco mas alla.
%   (d) La solucion cumple la restriccion: E[G]-1-eps*||x||_2 >= mu.

clear; clc;
rng(7);

N = 8; d = 3;
R = 0.01 + 0.03 * randn(N, d);      % medias positivas para que mu_max > rf
rf = 0.002; tau = 0.001; xbar = 0.5; gamma = 1; delta = 0.5;
hk = [1; zeros(d, 1)];
C = build_transport_cost(R, 1e-6);
rho = compute_rho(C, 0.15);
tol_status = 'Solved';

fprintf('=== (a) mu = -Inf reproduce solve_wdro_kelly.m ===\n');
[x_base, ~, ~, x0_base, ~, ~, f_base] = solve_wdro_kelly(hk, R, rf, tau, xbar, gamma, delta, C, rho, 'mosek');
[x_ret, ~, ~, x0_ret, ~, ~, f_ret]   = solve_wdro_kelly_ret(hk, R, rf, tau, xbar, gamma, delta, C, rho, 'mosek', -Inf, 0.05);
fprintf('  |dx|_max = %.2e | |dx0| = %.2e | |dfval| = %.2e\n', ...
    max(abs(x_base - x_ret)), abs(x0_base - x0_ret), abs(f_base - f_ret));
if max(abs(x_base - x_ret)) < 1e-6 && abs(f_base - f_ret) < 1e-6
    fprintf('  OK\n\n'); else, fprintf('  ATENCION: difiere\n\n'); end

fprintf('=== (b) Frontera de factibilidad: v(eps) vs. el solver completo ===\n');
for eps_ret = [0, 0.01]
    v = max_robust_return(hk, R, rf, tau, xbar, gamma, delta, eps_ret, 'mosek');
    fprintf('  eps = %.3f: v(eps) = %.5f\n', eps_ret, v);
    [~, ~, ~, ~, ~, ~, ~, st_ok]  = solve_wdro_kelly_ret(hk, R, rf, tau, xbar, gamma, delta, C, rho, 'mosek', v - 1e-4, eps_ret);
    [~, ~, ~, ~, ~, ~, ~, st_bad] = solve_wdro_kelly_ret(hk, R, rf, tau, xbar, gamma, delta, C, rho, 'mosek', v + 1e-4, eps_ret);
    fprintf('    mu = v - 1e-4 -> %s (esperado: Solved) | mu = v + 1e-4 -> %s (esperado: Infeasible)\n', st_ok, st_bad);
end
fprintf('\n');

fprintf('=== (c) eps_max_for_mu queda sobre la frontera ===\n');
mu_max = max_robust_return(hk, R, rf, tau, xbar, gamma, delta, 0, 'mosek');
mu_test = rf + 0.5 * (mu_max - rf);
e_star = eps_max_for_mu(mu_test, hk, R, rf, tau, xbar, gamma, delta, 'mosek');
v_in  = max_robust_return(hk, R, rf, tau, xbar, gamma, delta, max(e_star - 1e-3, 0), 'mosek');
v_out = max_robust_return(hk, R, rf, tau, xbar, gamma, delta, e_star + 1e-3, 'mosek');
fprintf('  mu_max = %.5f, mu = %.5f, eps_max(mu) = %.5f\n', mu_max, mu_test, e_star);
fprintf('  v(eps_max - 1e-3) = %.5f (>= mu) | v(eps_max + 1e-3) = %.5f (< mu)\n', v_in, v_out);
if v_in >= mu_test - 1e-6 && v_out < mu_test
    fprintf('  OK\n\n'); else, fprintf('  ATENCION: la biseccion no queda sobre la frontera\n\n'); end

fprintf('=== (d) La solucion cumple la restriccion de retorno robusto ===\n');
eps_ret = 0.01; mu = rf + 0.4 * (max_robust_return(hk, R, rf, tau, xbar, gamma, delta, eps_ret, 'mosek') - rf);
[x_s, ~, ~, x0_s, ~, ~, ~, st] = solve_wdro_kelly_ret(hk, R, rf, tau, xbar, gamma, delta, C, rho, 'mosek', mu, eps_ret);
lhs = x0_s * (1 + rf) + (1 + mean(R, 1)) * x_s - 1 - eps_ret * norm(x_s, 2);
fprintf('  status = %s | E[G]-1-eps*||x|| = %.6f >= mu = %.6f ? %d\n', st, lhs, mu, lhs >= mu - 1e-6);
