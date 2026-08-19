%% test_wdro_nominal_equivalence.m
% Verificacion obligatoria de la Seccion 21.4 (paso 8): con rho_k = 0 y
% C(r,s) > 0 para todo r~=s, el modelo Wasserstein-Kelly debe reproducir
% EXACTAMENTE el modelo Kelly nominal (Seccion 13.1 de la propuesta).
%
% Corre esto ANTES de conectar solve_wdro_kelly.m al backtest completo.
% Usa una sola fecha (la primera ventana disponible) para que la
% comparacion sea rapida.

clear; clc;

%% 1. Configuracion (misma que main_nominal_kelly.m)
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');

params.N     = 60;
params.tau   = 0.001;
params.xbar  = 0.25;
params.gamma = 1;
params.delta = 0.75;
solver_name  = 'mosek';   % cambia a 'sedumi' si aun no tienes mosek

%% 2. Cargar datos y tomar la primera ventana disponible
data = load_monthly_data(CSV_PATH, TICKERS);

h0_test = [1; zeros(numel(TICKERS), 1)];
R_test  = data.R(1:params.N, :);
rf_test = data.rf_return(params.N);

%% 3. Resolver el modelo nominal
fprintf('Resolviendo Kelly nominal...\n');
[xk_nom, bk_nom, sk_nom, x0k_nom, fval_nom, status_nom] = solve_nominal_kelly( ...
    h0_test, R_test, rf_test, params.tau, params.xbar, params.gamma, ...
    params.delta, solver_name);
fprintf('  status = %s, objetivo = %.8f\n', status_nom, fval_nom);

%% 4. Construir la matriz de costos y resolver WDRO con rho = 0
fprintf('Construyendo matriz de costos de transporte (geometria de retornos)...\n');
[C, ~] = build_transport_cost(R_test);

n_zero_offdiag = sum(C(~eye(params.N)) == 0);
if n_zero_offdiag > 0
    warning(['Hay %d pares (r,s), r~=s, con costo cero. La equivalencia ' ...
        'exacta con rho=0 requiere C(r,s)>0 para todo r~=s (Seccion 13.1). ' ...
        'Puede deberse a meses historicos con retornos identicos o casi ' ...
        'identicos en la ventana.'], n_zero_offdiag);
end

fprintf('Resolviendo Wasserstein-Kelly con rho = 0...\n');
[xk_wdro, bk_wdro, sk_wdro, x0k_wdro, alpha, lambda, fval_wdro, status_wdro] = ...
    solve_wdro_kelly(h0_test, R_test, rf_test, params.tau, params.xbar, ...
    params.gamma, params.delta, C, 0, solver_name);
fprintf('  status = %s, objetivo = %.8f\n', status_wdro, fval_wdro);

%% 5. Comparar
tol = 1e-4;   % tolerancia razonable entre dos resoluciones numericas independientes

diff_x   = max(abs(xk_nom - xk_wdro));
diff_x0  = abs(x0k_nom - x0k_wdro);
diff_obj = abs(fval_nom - fval_wdro);

fprintf('\n--- Comparacion nominal vs. WDRO(rho=0) ---\n');
fprintf('Max |xk_nom - xk_wdro|   = %.3e\n', diff_x);
fprintf('|x0k_nom - x0k_wdro|     = %.3e\n', diff_x0);
fprintf('|objetivo_nom - objetivo_wdro| = %.3e\n', diff_obj);
fprintf('lambda optimo (deberia ser ~0) = %.3e\n', lambda);

if diff_x < tol && diff_x0 < tol && diff_obj < tol
    fprintf('\nOK: el modelo WDRO con rho=0 reproduce el modelo nominal dentro de la tolerancia (%.0e).\n', tol);
else
    fprintf(['\nATENCION: las soluciones difieren mas alla de la tolerancia. ' ...
        'Revisar: (a) posibles costos cero fuera de la diagonal, (b) precision ' ...
        'del solver, (c) errores en la formulacion dual antes de continuar.\n']);
end
