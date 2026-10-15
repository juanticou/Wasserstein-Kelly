%% test_hypercube_equivalence.m
% Dos verificaciones rapidas ANTES de confiar en el backtest completo del
% modelo hipercubo:
%
%   (a) M_synth=0 (sin sinteticos) debe dar EXACTAMENTE lo mismo que
%       solve_wdro_kelly.m con la Geometria 1 -- la matriz rectangular se
%       reduce a la cuadrada original cuando no hay destinos nuevos.
%   (b) eta=0 (rho=0) debe dar el modelo NOMINAL, sin importar M_synth --
%       con costo cero en la auto-pareja (r,s=r) y objetivo indiferente
%       a lambda cuando rho=0, el optimo coincide con el nominal (misma
%       propiedad ya verificada en test_wdro_nominal_equivalence.m, que
%       aqui se extiende al caso con destinos sinteticos).
%
% Usa una ventana sintetica pequena (no corre sobre datos reales) para
% que sea rapido. Requiere CVX + MOSEK.

clear; clc;

rng(42);   % reproducibilidad de la ventana sintetica y del hipercubo

N = 6; d = 3;
R = 0.02 * randn(N, d);          % ventana de prueba pequena
rf = 0.003;
tau = 0.001; xbar = 0.5; gamma = 1; delta = 0.5;
hk = [1; zeros(d, 1)];

fprintf('=== (a) M_synth = 0 debe igualar a solve_wdro_kelly.m ===\n');
C_square = build_transport_cost(R, 1e-6);
rho_test = compute_rho(C_square, 0.20);

[xk_sq, ~, ~, x0k_sq, ~, ~, fval_sq, status_sq] = solve_wdro_kelly( ...
    hk, R, rf, tau, xbar, gamma, delta, C_square, rho_test, 'mosek');

R_synth_empty = zeros(0, d);
C_rect = build_transport_cost_hypercube(R, R_synth_empty, 1e-6);
rho_rect = compute_rho(C_rect, 0.20);

[xk_hc, ~, ~, x0k_hc, ~, ~, fval_hc, status_hc] = solve_wdro_kelly_hypercube( ...
    hk, R, R_synth_empty, rf, tau, xbar, gamma, delta, C_rect, rho_rect, 'mosek');

diff_C = max(abs(C_square(:) - C_rect(:)));
diff_x = max(abs(xk_sq - xk_hc));
diff_x0 = abs(x0k_sq - x0k_hc);
diff_fval = abs(fval_sq - fval_hc);

fprintf('  status: %s (cuadrado) vs %s (hipercubo, M=0)\n', status_sq, status_hc);
fprintf('  |C_square - C_rect|_max = %.3e (deberia ser ~0)\n', diff_C);
fprintf('  |xk diff|_max = %.3e | |x0k diff| = %.3e | |fval diff| = %.3e\n', ...
    diff_x, diff_x0, diff_fval);
if diff_x < 1e-5 && diff_x0 < 1e-5 && diff_fval < 1e-4
    fprintf('  OK: M_synth=0 reproduce el modelo de Geometria 1.\n\n');
else
    fprintf('  ATENCION: diferencias mayores a la tolerancia -- revisar antes de seguir.\n\n');
end

fprintf('=== (b) eta=0 debe igualar al modelo nominal, con M_synth > 0 ===\n');
[xk_nom, ~, ~, x0k_nom, fval_nom, status_nom] = solve_nominal_kelly( ...
    hk, R, rf, tau, xbar, gamma, delta);

M_synth = 50;
R_synth = sample_hypercube_scenarios(R, M_synth, 123);
C_hc0 = build_transport_cost_hypercube(R, R_synth, 1e-6);
rho_zero = compute_rho(C_hc0, 0);   % eta=0 -> rho=0

[xk_hc0, ~, ~, x0k_hc0, ~, ~, fval_hc0, status_hc0] = solve_wdro_kelly_hypercube( ...
    hk, R, R_synth, rf, tau, xbar, gamma, delta, C_hc0, rho_zero, 'mosek', true);

diff_x_nom = max(abs(xk_nom - xk_hc0));
diff_x0_nom = abs(x0k_nom - x0k_hc0);

fprintf('  status: %s (nominal) vs %s (hipercubo, eta=0, M=%d)\n', status_nom, status_hc0, M_synth);
fprintf('  |xk diff|_max = %.3e | |x0k diff| = %.3e\n', diff_x_nom, diff_x0_nom);
if diff_x_nom < 1e-5 && diff_x0_nom < 1e-5
    fprintf('  OK: eta=0 reproduce el modelo nominal incluso con escenarios sinteticos.\n');
else
    fprintf('  ATENCION: diferencias mayores a la tolerancia -- revisar antes de seguir.\n');
end
