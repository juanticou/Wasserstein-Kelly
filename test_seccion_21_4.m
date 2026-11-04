%% test_seccion_21_4.m
% Pruebas obligatorias de la seccion 21.4 de la propuesta que no tenian
% evidencia en el repositorio vigente:
%   A. instancia sintetica de 3 activos y 6 escenarios (Kelly nominal sin
%      y con costos; el optimo sin costos se contrasta con una busqueda
%      exhaustiva en una malla del simplex);
%   B. coincidencia entre el problema adversarial PRIMAL (ec. 51, LP en el
%      plan de transporte Gamma) y su DUAL (ec. 52), y entre el valor del
%      modelo completo (ec. 53, solve_wdro_kelly.m) y el primal evaluado en
%      su portafolio optimo; recuperacion de la distribucion adversarial p;
%   C. monotonia en el radio: con portafolio fijo el valor robusto es no
%      creciente en rho (C1); el optimo re-resuelto tambien (C2).
% Ya verificado en otros scripts y no repetido aqui: equivalencia con rho=0
% (test_wdro_nominal_equivalence.m, verify_eta0_backtest.m), balance,
% limites y cota delta en el backtest (verify_backtest_constraints.m).
%
% Diferencia con la propuesta (sec. 21.2): no hay Gurobi ni linprog en este
% equipo; el LP primal se resuelve con CVX y DOS solucionadores
% independientes (MOSEK y SDPT3).
%
% No elige ni ajusta ningun parametro. Requiere WK_PANEL y WK_RESULTS_ROOT.
% Con WK_SOLO_A=1 corre solo la parte A (prueba rapida) y no escribe nada.
% Salidas (carpeta nueva; aborta si ya tiene archivos):
%   <WK_RESULTS_ROOT>/results_pruebas_21_4/pruebas_21_4.csv
%   <WK_RESULTS_ROOT>/results_pruebas_21_4/instancia_sintetica.csv
%   <WK_RESULTS_ROOT>/results_pruebas_21_4/monotonia_optimo.csv

clear; clc;
t_total = tic;
SOLO_A = strcmp(getenv('WK_SOLO_A'), '1');

PROJECT_DIR = fileparts(mfilename('fullpath'));
addpath(fullfile(PROJECT_DIR, 'wdro-market'));
cfg = config_rutas();
OUT_DIR = fullfile(cfg.results_root, 'results_pruebas_21_4');
if ~SOLO_A
    if exist(OUT_DIR, 'dir')
        L = dir(OUT_DIR);
        if any(~ismember({L.name}, {'.', '..'}))
            error('test_seccion_21_4:wouldOverwrite', '%s ya tiene archivos; no se sobrescribe.', OUT_DIR);
        end
    else
        mkdir(OUT_DIR);
    end
end

SOLVER = 'mosek';
ETA_GRID = [0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.10, 0.15, 0.30, 0.50, 1.00];
chk = {};

%% A. Instancia sintetica (NO son datos reales)
% Disenada para que el optimo de Kelly sea INTERIOR (no una esquina del
% simplex, que la malla contendria exactamente): el activo 1 tiene la mayor
% media pero una caida fuerte (escenario 4); el 2 es de baja volatilidad y
% sube en ese escenario; el 3 es intermedio.
R_syn = [ 0.15,  0.03, -0.02
         -0.08,  0.02,  0.05
          0.20, -0.01,  0.06
         -0.30,  0.04, -0.04
          0.05,  0.02,  0.01
          0.10, -0.01,  0.03];
rf_syn = 0.002;
[Ns, ds] = size(R_syn);
h_syn = [1; zeros(ds, 1)];

% A1. Kelly nominal sin costos frente a busqueda exhaustiva (paso 0.01)
tA = tic;
[xA, ~, ~, x0A, fA1, stA] = solve_nominal_kelly(h_syn, R_syn, rf_syn, 0, 1, 1, 0.5, SOLVER);
step = 0.01; n = round(1 / step);
[i1, i2, i3] = ndgrid(0:n, 0:n, 0:n);
keep = (i1 + i2 + i3) <= n;
X = [i1(keep), i2(keep), i3(keep)] * step;           % (M x 3), x0 = 1 - sum
x0g = 1 - sum(X, 2);
G = (1 + rf_syn) * x0g' + (1 + R_syn) * X';           % (6 x M)
obj = mean(log(G), 1);
obj(any(G < 0.5, 1)) = -Inf;
[best, ib] = max(obj);
fprintf('A1: CVX %.10f | malla %.10f (%d puntos) | x CVX = [%s] | x malla = [%s]\n', fA1, best, ...
    numel(obj), num2str([x0A; xA]', '%.3f '), num2str([x0g(ib), X(ib, :)], '%.2f '));
chk = add(chk, "A1", "sintetica", "status CVX = Solved", double(strcmp(stA, 'Solved')), 1, strcmp(stA, 'Solved'));
chk = add(chk, "A1", "sintetica", "malla_max - optimo CVX (<= 1e-9)", best - fA1, 1e-9, best - fA1 <= 1e-9);
chk = add(chk, "A1", "sintetica", "optimo CVX - malla_max (<= 1e-3)", fA1 - best, 1e-3, fA1 - best <= 1e-3);
chk = add(chk, "A1", "sintetica", "puntos factibles de la malla", numel(obj), NaN, true);

% A2. Con costos tau = 0.001 y xbar = 0.5
tau = 0.001; xbar = 0.5; delta = 0.5;
[xB, bB, sB, x0B, fA2, stB] = solve_nominal_kelly(h_syn, R_syn, rf_syn, tau, xbar, 1, delta, SOLVER);
TO = sum(bB + sB);
GB = x0B * (1 + rf_syn) + (1 + R_syn) * xB;
chk = add(chk, "A2", "sintetica", "status CVX = Solved", double(strcmp(stB, 'Solved')), 1, strcmp(stB, 'Solved'));
chk = add(chk, "A2", "sintetica", "|x0 + sum x - (1 - tau TO)|", abs(x0B + sum(xB) - (1 - tau * TO)), 1e-8, abs(x0B + sum(xB) - (1 - tau * TO)) <= 1e-8);
chk = add(chk, "A2", "sintetica", "max min(b_j, s_j)", max(min(bB, sB)), 1e-7, max(min(bB, sB)) <= 1e-7);
chk = add(chk, "A2", "sintetica", "max(x - xbar)", max(xB - xbar), 1e-8, max(xB - xbar) <= 1e-8);
chk = add(chk, "A2", "sintetica", "min x (incluye x0)", min([xB; x0B]), -1e-8, min([xB; x0B]) >= -1e-8);
chk = add(chk, "A2", "sintetica", "min(G_s - delta)", min(GB) - delta, -1e-8, min(GB) - delta >= -1e-8);
chk = add(chk, "A2", "sintetica", "objetivo con costos - sin costos (<= 1e-9)", fA2 - fA1, 1e-9, fA2 - fA1 <= 1e-9);
fprintf('A2: objetivo %.10f, TO = %.4f, x = [%s] | parte A en %.1f s\n', fA2, TO, num2str([x0B; xB]', '%.4f '), toc(tA));

if SOLO_A
    disp(vertcat(chk{:}));
    return
end

%% Instancias para B y C
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
data = load_monthly_data(cfg.panel, TICKERS);
N = 60; d = numel(TICKERS);
P = struct('tau', 0.001, 'xbar', 0.25, 'gamma', 1, 'delta', 0.90, 'eps', 1e-6);
W = struct('wR', 0.70, 'wm', 0.15, 'wv', 0.15, 'wf', 0);
TEST_DATES = [datetime(2014,12,31), datetime(2018,12,31), datetime(2022,6,30)];

inst = struct('name', {}, 'R', {}, 'rf', {}, 'C', {}, 'h', {}, 'p', {});
inst(end+1) = struct('name', "sintetica G1", 'R', R_syn, 'rf', rf_syn, ...
    'C', build_transport_cost(R_syn, 1e-6), 'h', h_syn, ...
    'p', struct('tau', tau, 'xbar', xbar, 'gamma', 1, 'delta', delta));
for t = 1:numel(TEST_DATES)
    k = find(data.dates == TEST_DATES(t), 1);
    assert(~isempty(k) && k >= N, 'Fecha %s fuera del panel.', datestr(TEST_DATES(t)));
    w = k - N + 1 : k;
    Rk = data.R(w, :);
    C1 = build_transport_cost(Rk, P.eps);
    C2 = build_transport_cost_market(Rk, data.mkt_return(w), data.vix(w), W, P.eps);
    tag = string(datestr(TEST_DATES(t), 'yyyy-mm'));
    inst(end+1) = struct('name', tag + " G1", 'R', Rk, 'rf', data.rf_return(k), 'C', C1, ...
        'h', [1; zeros(d, 1)], 'p', P); %#ok<SAGROW>
    inst(end+1) = struct('name', tag + " G2", 'R', Rk, 'rf', data.rf_return(k), 'C', C2, ...
        'h', [1; zeros(d, 1)], 'p', P); %#ok<SAGROW>
end

%% B. Primal frente a dual
for m = 1:numel(inst)
    I = inst(m); p = I.p; Nm = size(I.R, 1);
    offdiag_pos = all(I.C(~eye(Nm)) > 0);
    chk = add(chk, "B", I.name, "costos fuera de la diagonal > 0", double(offdiag_pos), 1, offdiag_pos);
    for eta = [0.01, 0.30]
        rho = compute_rho(I.C, eta);
        [x, ~, ~, x0, ~, lam, fval, st] = solve_wdro_kelly(I.h, I.R, I.rf, p.tau, p.xbar, p.gamma, ...
            p.delta, I.C, rho, SOLVER);
        g = log(x0 * (1 + I.rf) + (1 + I.R) * x);
        [vP, Gam] = primal_lp(g, I.C, rho, 'mosek');
        [vP2, ~, st2] = primal_lp(g, I.C, rho, 'sdpt3', false);   % contraverificacion: se registra su estado
        [vD, lamD] = dual_lp(g, I.C, rho, 'mosek');
        vF = mean(min(g' + lamD * I.C, [], 2)) - rho * lamD;   % alpha_r = min_s(g_s + lambda c_rs)
        pa = sum(Gam, 1)';
        tag = sprintf('eta=%.2f', eta);
        chk = add(chk, "B", I.name, tag + ": status WK = Solved", double(strcmp(st, 'Solved')), 1, strcmp(st, 'Solved'));
        chk = add(chk, "B", I.name, tag + ": |primal - dual|", abs(vP - vD), 1e-7, abs(vP - vD) <= 1e-7);
        chk = add(chk, "B", I.name, tag + ": |primal MOSEK - primal SDPT3| (estado SDPT3: " + st2 + ")", abs(vP - vP2), 1e-6, abs(vP - vP2) <= 1e-6);
        chk = add(chk, "B", I.name, tag + ": |dual - formula cerrada en lambda*|", abs(vD - vF), 1e-7, abs(vD - vF) <= 1e-7);
        chk = add(chk, "B", I.name, tag + ": |fval WK - primal en x*|", abs(fval - vP), 1e-6, abs(fval - vP) <= 1e-6);
        chk = add(chk, "B", I.name, tag + ": |sum p - 1|", abs(sum(pa) - 1), 1e-8, abs(sum(pa) - 1) <= 1e-8);
        chk = add(chk, "B", I.name, tag + ": min p", min(pa), -1e-8, min(pa) >= -1e-8);
        chk = add(chk, "B", I.name, tag + ": costo de transporte - rho", sum(I.C .* Gam, 'all') - rho, 1e-8, sum(I.C .* Gam, 'all') - rho <= 1e-8);
        fprintf('B %-14s %s: fval=%.8f primal=%.8f dual=%.8f sdpt3=%.8f lambda=%.3e/%.3e\n', ...
            I.name, tag, fval, vP, vD, vP2, lam, lamD);
    end
end

%% C1. Monotonia con portafolio fijo (x* del nominal de cada instancia)
for m = 1:numel(inst)
    I = inst(m); p = I.p;
    [x, ~, ~, x0] = solve_nominal_kelly(I.h, I.R, I.rf, p.tau, p.xbar, p.gamma, p.delta, SOLVER);
    g = log(x0 * (1 + I.rf) + (1 + I.R) * x);
    V = arrayfun(@(e) primal_lp(g, I.C, compute_rho(I.C, e), 'mosek'), ETA_GRID);
    chk = add(chk, "C1", I.name, "max paso V(eta_{i+1}) - V(eta_i)", max(diff(V)), 1e-9, max(diff(V)) <= 1e-9);
    chk = add(chk, "C1", I.name, "|V(0) - promedio empirico de log G|", abs(V(1) - mean(g)), 1e-8, abs(V(1) - mean(g)) <= 1e-8);
    chk = add(chk, "C1", I.name, "V(0) - V(1.00) (descriptivo)", V(1) - V(end), NaN, true);
end

%% C2. Monotonia del optimo re-resuelto
rowsC2 = {};
for m = find(ismember([inst.name], ["sintetica G1", "2018-12 G1"]))
    I = inst(m); p = I.p;
    fv = zeros(size(ETA_GRID)); risk = fv; lamv = fv;
    for e = 1:numel(ETA_GRID)
        rho = compute_rho(I.C, ETA_GRID(e));
        [x, ~, ~, ~, ~, lamv(e), fv(e)] = solve_wdro_kelly(I.h, I.R, I.rf, p.tau, p.xbar, p.gamma, ...
            p.delta, I.C, rho, SOLVER);
        risk(e) = sum(x);
    end
    chk = add(chk, "C2", I.name, "max paso fval(eta_{i+1}) - fval(eta_i)", max(diff(fv)), 1e-7, max(diff(fv)) <= 1e-7);
    rowsC2{end + 1} = table(repmat(I.name, numel(ETA_GRID), 1), ETA_GRID', fv', risk', lamv', ...
        'VariableNames', {'instancia', 'eta', 'valor_optimo_WK', 'proporcion_riesgo', 'lambda'}); %#ok<SAGROW>
end

%% Salidas
T = vertcat(chk{:});
writetable(T, fullfile(OUT_DIR, 'pruebas_21_4.csv'));
writetable(vertcat(rowsC2{:}), fullfile(OUT_DIR, 'monotonia_optimo.csv'));
S = array2table([R_syn, rf_syn * ones(Ns, 1)], 'VariableNames', {'r1', 'r2', 'r3', 'rf'});
S = addvars(S, (1:Ns)', 'Before', 1, 'NewVariableNames', 'escenario');
writetable(S, fullfile(OUT_DIR, 'instancia_sintetica.csv'));
disp(T(~T.ok, :));
fprintf('Pruebas 21.4: %d de %d correctas en %.1f s.\n', sum(T.ok), height(T), toc(t_total));


function c = add(c, prueba, instancia, comprobacion, valor, tol, ok)
    valor = full(double(valor)); ok = full(logical(ok));   % CVX puede devolver dispersas
    c{end + 1} = table(string(prueba), string(instancia), string(comprobacion), valor, tol, ok, ...
        'VariableNames', {'prueba', 'instancia', 'comprobacion', 'valor', 'tolerancia', 'ok'});
end


function [v, Gam, st] = primal_lp(g, C, rho, solver, exigir_solved)
% Ec. 51: min sum_{r,s} Gamma_rs g_s, filas = 1/N, sum C.*Gamma <= rho, Gamma >= 0
% Con exigir_solved = false (contraverificacion con SDPT3) no aborta si el
% estado no es 'Solved': lo devuelve en st para registrarlo.
    if nargin < 5, exigir_solved = true; end
    N = numel(g);
    cvx_begin quiet
        cvx_solver(solver)
        variable Gam(N, N) nonnegative
        minimize( sum(Gam * g(:)) )
        subject to
            sum(Gam, 2) == 1 / N;
            sum(sum(C .* Gam)) <= rho;
    cvx_end
    st = string(cvx_status);
    assert(~exigir_solved || strcmp(cvx_status, 'Solved'), 'primal_lp (%s): %s', solver, cvx_status);
    v = cvx_optval;
end


function [v, lam] = dual_lp(g, C, rho, solver)
% Ec. 52: max (1/N) sum alpha - rho*lambda, alpha_r <= g_s + lambda C_rs, lambda >= 0
    N = numel(g);
    cvx_begin quiet
        cvx_solver(solver)
        variables alpha_v(N) lam
        maximize( sum(alpha_v) / N - rho * lam )
        subject to
            alpha_v * ones(1, N) - lam * C <= ones(N, 1) * g(:)';
            lam >= 0;
    cvx_end
    assert(strcmp(cvx_status, 'Solved'), 'dual_lp (%s): %s', solver, cvx_status);
    v = cvx_optval;
end
