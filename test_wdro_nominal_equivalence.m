%% test_wdro_nominal_equivalence.m
% Verificacion de la seccion "Implementacion y verificacion" de
% metodologia_2.tex: con rho_k = 0 y C(r,s) > 0 para todo r~=s, el modelo
% Wasserstein-Kelly debe reproducir el modelo Kelly nominal, y las dos
% geometrias deben coincidir (con radio cero C no participa).
%
% Como pueden existir optimos multiples, se compara con TOLERANCIAS
% EXPLICITAS:
%   TOL_OBJ  : |objetivo_nominal - objetivo_WDRO|            (valor optimo)
%   TOL_FEAS : residuo maximo de las restricciones de cada solucion
%              (balance x0+sum(x) = 1 - tau*TO, 0<=x<=xbar, sum(x)<=gamma,
%               G_ks >= delta, x0,b,s >= 0)
%   TOL_X    : max |x_nom - x_WDRO| y |x0_nom - x0_WDRO|, SOLO si la
%              solucion es unica.
% Unicidad: el objetivo es estrictamente concavo en el vector de
% crecimientos G = A*[x0; x], con A = [(1+rf)*1, 1+R] (N x (d+1)); por
% tanto G* es unico y, si A tiene rango de columna completo, tambien lo
% es (x0, x). Con tau>0 comprar y vender el mismo activo a la vez no es
% optimo, asi que (b, s) quedan determinados por x - h. Se reporta el
% rango y el numero de condicion de A.
%
% Se prueban varias fechas de decision (no solo la primera ventana), con
% el portafolio inicial h0 = (1, 0, ..., 0) y delta = 0.75.

clear; clc;

%% 1. Configuracion (misma que main_nominal_kelly.m)
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
cfg = config_rutas();   % rutas de datos y resultados (WK_PANEL, WK_RESULTS_ROOT)
RES = cfg.results_root;
addpath(fullfile(PROJECT_DIR, 'wdro-market'));   % build_transport_cost_market.m
CSV_PATH = cfg.panel;
OUT_DIR  = fullfile(RES, 'results_verificaciones');
preparar_salida(cfg, OUT_DIR);

params.N     = 60;
params.tau   = 0.001;
params.xbar  = 0.25;
params.gamma = 1;
params.delta = 0.75;
params.eps_esc = 1e-6;
solver_name  = 'mosek';
WEIGHTS = struct('wR', 0.70, 'wm', 0.15, 'wv', 0.15, 'wf', 0);

TOL_OBJ  = 1e-6;
TOL_FEAS = 1e-7;
TOL_X    = 1e-5;

% Fechas de decision a probar: primera ventana, cierre de validacion y una
% fecha con tasas altas (posterior a 2022).
TEST_DATES = [datetime(2014,12,31), datetime(2018,12,31), datetime(2022,6,30)];

%% 2. Datos
data = load_monthly_data(CSV_PATH, TICKERS);
d = numel(TICKERS);
h0_test = [1; zeros(d, 1)];

rows = {};
for t = 1:numel(TEST_DATES)
    k = find(data.dates == dateshift(TEST_DATES(t), 'end', 'month'), 1);
    if isempty(k) || k < params.N
        warning('test_wdro_nominal_equivalence:dateNotFound', ...
            'La fecha %s no esta en el panel; se omite.', datestr(TEST_DATES(t)));
        continue
    end
    R_test  = data.R(k - params.N + 1 : k, :);
    rf_test = data.rf_return(k);

    %% 3. Nominal
    [x_n, b_n, s_n, x0_n, f_n, st_n, info_n] = solve_nominal_kelly( ...
        h0_test, R_test, rf_test, params.tau, params.xbar, params.gamma, ...
        params.delta, solver_name);

    %% 4. WDRO con rho = 0, Geometria 1 y Geometria 2
    C1 = build_transport_cost(R_test, params.eps_esc);
    C2 = build_transport_cost_market(R_test, data.mkt_return(k - params.N + 1 : k), ...
        data.vix(k - params.N + 1 : k), WEIGHTS, params.eps_esc);
    n_zero = [sum(C1(~eye(params.N)) == 0), sum(C2(~eye(params.N)) == 0)];
    if any(n_zero > 0)
        warning('test_wdro_nominal_equivalence:zeroCost', ...
            'Hay pares r~=s con costo cero (G1: %d, G2: %d).', n_zero(1), n_zero(2));
    end

    [x_1, b_1, s_1, x0_1, ~, lam_1, f_1, st_1, info_1] = solve_wdro_kelly( ...
        h0_test, R_test, rf_test, params.tau, params.xbar, params.gamma, ...
        params.delta, C1, 0, solver_name);
    [x_2, b_2, s_2, x0_2, ~, lam_2, f_2, st_2, info_2] = solve_wdro_kelly( ...
        h0_test, R_test, rf_test, params.tau, params.xbar, params.gamma, ...
        params.delta, C2, 0, solver_name);

    %% 5. Factibilidad, unicidad y comparacion
    feas_n = feas_residual(x_n, b_n, s_n, x0_n, h0_test, R_test, rf_test, params);
    feas_1 = feas_residual(x_1, b_1, s_1, x0_1, h0_test, R_test, rf_test, params);
    feas_2 = feas_residual(x_2, b_2, s_2, x0_2, h0_test, R_test, rf_test, params);

    A = [(1 + rf_test) * ones(params.N, 1), 1 + R_test];
    rankA = rank(A);
    condA = cond(A);
    unique_sol = (rankA == d + 1);

    d_obj = [abs(f_n - f_1), abs(f_n - f_2), abs(f_1 - f_2)];
    d_x   = [max(abs([x_n; x0_n] - [x_1; x0_1])), max(abs([x_n; x0_n] - [x_2; x0_2])), ...
             max(abs([x_1; x0_1] - [x_2; x0_2]))];

    ok_obj  = all(d_obj <= TOL_OBJ);
    ok_feas = all([feas_n, feas_1, feas_2] <= TOL_FEAS);
    if unique_sol
        ok_x = all(d_x <= TOL_X);
    else
        ok_x = true;   % no se exige igualdad de ponderaciones sin unicidad
    end

    fprintf('\n--- Fecha de decision %s ---\n', datestr(data.dates(k)));
    fprintf('status: nominal=%s (MOSEK %s/%s) | G1=%s | G2=%s\n', st_n, ...
        info_n.mosek_problem_status, info_n.mosek_solution_status, st_1, st_2);
    fprintf('objetivo: nominal=%.10f  G1=%.10f  G2=%.10f\n', f_n, f_1, f_2);
    fprintf('|obj| nom-G1=%.2e  nom-G2=%.2e  G1-G2=%.2e  (TOL_OBJ=%.0e) -> %s\n', ...
        d_obj, TOL_OBJ, pass_str(ok_obj));
    fprintf('residuo factibilidad: nom=%.2e  G1=%.2e  G2=%.2e  (TOL_FEAS=%.0e) -> %s\n', ...
        feas_n, feas_1, feas_2, TOL_FEAS, pass_str(ok_feas));
    fprintf('rank(A)=%d de %d, cond(A)=%.2f -> solucion unica: %d\n', rankA, d + 1, condA, unique_sol);
    fprintf('max|x| nom-G1=%.2e  nom-G2=%.2e  G1-G2=%.2e  (TOL_X=%.0e) -> %s\n', ...
        d_x, TOL_X, pass_str(ok_x));
    fprintf('lambda: G1=%.3e  G2=%.3e\n', lam_1, lam_2);

    rows{end + 1} = table(data.dates(k), string(st_n), string(st_1), string(st_2), ...
        string(info_n.mosek_solution_status), f_n, f_1, f_2, ...
        d_obj(1), d_obj(2), d_obj(3), feas_n, feas_1, feas_2, rankA, condA, unique_sol, ...
        d_x(1), d_x(2), d_x(3), lam_1, lam_2, ok_obj, ok_feas, ok_x, ...
        'VariableNames', {'fecha_decision', 'status_nominal', 'status_G1', 'status_G2', ...
        'mosek_solsta_nominal', 'obj_nominal', 'obj_G1', 'obj_G2', ...
        'dobj_nom_G1', 'dobj_nom_G2', 'dobj_G1_G2', 'resid_feas_nom', 'resid_feas_G1', ...
        'resid_feas_G2', 'rango_A', 'cond_A', 'solucion_unica', ...
        'dx_nom_G1', 'dx_nom_G2', 'dx_G1_G2', 'lambda_G1', 'lambda_G2', ...
        'ok_objetivo', 'ok_factibilidad', 'ok_ponderaciones'}); %#ok<SAGROW>
end

T = vertcat(rows{:});
writetable(T, fullfile(OUT_DIR, 'equivalencia_eta0_instancias.csv'));
fprintf('\nTolerancias: TOL_OBJ=%.0e, TOL_FEAS=%.0e, TOL_X=%.0e\n', TOL_OBJ, TOL_FEAS, TOL_X);
if all(T.ok_objetivo & T.ok_factibilidad & T.ok_ponderaciones)
    fprintf('OK: con rho=0 WDRO (G1 y G2) reproduce el nominal en todas las fechas probadas.\n');
else
    fprintf(['ATENCION: alguna comparacion supera la tolerancia. Revisar costos cero ' ...
        'fuera de la diagonal, precision del solver o la formulacion dual.\n']);
end
fprintf('Tabla guardada en %s\n', fullfile(OUT_DIR, 'equivalencia_eta0_instancias.csv'));


function r = feas_residual(x, b, s, x0, h, R, rf, p)
% Mayor violacion de las restricciones del modelo (37)/(53) en la solucion.
    TO = sum(b + s);
    G  = x0 * (1 + rf) + (1 + R) * x;
    v = [abs(x0 + sum(x) - (1 - p.tau * TO)); ...         % balance total
         abs(x - (h(2:end) + b - s)); ...                 % balance por activo
         max(-x, 0); max(x - p.xbar, 0); ...              % cotas por activo
         max(sum(x) - p.gamma, 0); ...                    % exposicion
         max(p.delta - G, 0); ...                         % supervivencia en la ventana
         max(-x0, 0); max(-b, 0); max(-s, 0)];
    r = max(v);
end


function s = pass_str(ok)
    if ok
        s = 'OK';
    else
        s = 'FALLA';
    end
end
