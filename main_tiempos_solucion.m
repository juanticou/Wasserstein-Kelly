%% MAIN_TIEMPOS_SOLUCION  Tiempo de solucion por mes de las seis
% estrategias evaluadas (Nominal y G1/G2 con c1 = (0.90, 0.01) y
% c2 = (0.80, 0.01)). Los backtests guardados no registraron tiempos, asi
% que cada problema mensual se re-resuelve tal como lo resolvio el backtest:
% mismo portafolio heredado h_k (guardado), misma ventana, misma C_k y rho_k
% (build_transport_cost*.m + compute_rho.m con los params guardados) y
% mismos parametros. Se cronometra la llamada completa a solve_*.m
% (modelado en CVX + MOSEK) y, aparte, la construccion de C_k y rho_k.
% Se comprueba que es el mismo problema: rho_k = r.rho y x_k = r.x.
% No elige ni ajusta ningun parametro; no escribe en ningun documento.
%
% Requiere WK_PANEL y WK_RESULTS_ROOT. Con WK_TIEMPOS_MUESTRA=n mide solo
% los primeros n meses de cada estrategia (prueba pequena) y no escribe.
% Con WK_TIEMPOS_PASO=p mide una de cada p decisiones (default 1 = todas).
% Salidas (carpeta nueva; aborta si ya tiene archivos):
%   <WK_RESULTS_ROOT>/results_tiempos/tiempos_por_mes.csv
%   <WK_RESULTS_ROOT>/results_tiempos/tiempos_resumen.csv
%   <WK_RESULTS_ROOT>/results_tiempos/entorno_tiempos.csv

clear; clc;
PROJECT_DIR = fileparts(mfilename('fullpath'));
addpath(fullfile(PROJECT_DIR, 'wdro-market'), fullfile(PROJECT_DIR, 'results_finales'));
cfg = config_rutas();
RES = cfg.results_root;
MUESTRA = str2double(getenv('WK_TIEMPOS_MUESTRA'));
PASO = str2double(getenv('WK_TIEMPOS_PASO')); if isnan(PASO), PASO = 1; end
OUT_DIR = fullfile(RES, 'results_tiempos');
if isnan(MUESTRA)
    if exist(OUT_DIR, 'dir')
        L = dir(OUT_DIR);
        if any(~ismember({L.name}, {'.', '..'}))
            error('main_tiempos_solucion:wouldOverwrite', '%s ya tiene archivos; no se sobrescribe.', OUT_DIR);
        end
    else
        mkdir(OUT_DIR);
    end
end

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
ORDER = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.80, 0.01)", "G1 (0.90, 0.01)", ...
         "G2 (0.80, 0.01)", "G2 (0.90, 0.01)"];
TOL_X = 1e-6; TOL_RHO = 1e-12;
PERIODS = {'validacion', datetime(2015,1,1), datetime(2018,12,31); ...
           'prueba',     datetime(2019,1,1), datetime(2025,12,31)};

data = load_monthly_data(cfg.panel, TICKERS);
traj = cargar_trayectorias(RES, data);

% Calentamiento (no se cuenta): primera inicializacion de CVX/MOSEK
r = traj(char(ORDER(3))); p = r.params; k = find(data.dates == r.dates(1), 1);
Rk = data.R(k - p.N + 1 : k, :); C = build_transport_cost(Rk, p.eps_esc);
solve_wdro_kelly(r.h(1, :)', Rk, data.rf_return(k), p.tau, p.xbar, p.gamma, p.delta, C, compute_rho(C, p.eta), p.solver);

rows = {};
t_all = tic;
for s = ORDER
    r = traj(char(s)); p = r.params;
    geo = extractBefore(s + " ", " ");
    idx = 1:PASO:numel(r.dates);
    if ~isnan(MUESTRA), idx = idx(1:MUESTRA); end
    for i = idx
        k = find(data.dates == r.dates(i), 1);
        w = k - p.N + 1 : k;
        Rk = data.R(w, :); rf = data.rf_return(k); h = r.h(i, :)';
        t_c = 0; drho = NaN;
        if geo == "Nominal"
            tic;
            [x, ~, ~, x0, ~, st] = solve_nominal_kelly(h, Rk, rf, p.tau, p.xbar, p.gamma, p.delta, p.solver);
            t_s = toc;
        else
            tic;
            if geo == "G1"
                C = build_transport_cost(Rk, p.eps_esc);
            else
                C = build_transport_cost_market(Rk, data.mkt_return(w), data.vix(w), p.weights, p.eps_esc);
            end
            rho = compute_rho(C, p.eta);
            t_c = toc;
            drho = abs(rho - r.rho(i));
            tic;
            [x, ~, ~, x0, ~, ~, ~, st] = solve_wdro_kelly(h, Rk, rf, p.tau, p.xbar, p.gamma, p.delta, C, rho, p.solver);
            t_s = toc;
        end
        dx = max(abs([x; x0] - [r.x(i, :)'; r.x0(i)]));
        rows{end + 1} = table(s, geo, r.dates(i), t_s, t_c, string(st), dx, drho, ...
            'VariableNames', {'estrategia', 'modelo', 'fecha_decision', 'segundos_solucion', ...
            'segundos_C_rho', 'estado', 'max_dx_vs_guardado', 'drho_vs_guardado'}); %#ok<SAGROW>
    end
    fprintf('%-16s %3d meses: media %.3f s\n', s, numel(idx), mean(cellfun(@(t) t.segundos_solucion, rows(end-numel(idx)+1:end))));
end
T = vertcat(rows{:});
T.ok_x   = ~(T.estado == "Solved") | T.max_dx_vs_guardado <= TOL_X;
T.ok_rho = isnan(T.drho_vs_guardado) | T.drho_vs_guardado <= TOL_RHO;
fprintf('Tiempo total medido: %.1f s; comprobaciones: x %d/%d, rho %d/%d\n', toc(t_all), ...
    sum(T.ok_x), height(T), sum(T.ok_rho), height(T));

if ~isnan(MUESTRA)
    n_total = 132 / PASO;
    est = groupsummary(T, 'modelo', 'mean', 'segundos_solucion');
    fprintf('Estimado para %d meses por estrategia: %.1f min\n', round(n_total), ...
        2 * n_total * sum(est.mean_segundos_solucion) / 60);
    disp(T); return
end

%% Resumen por estrategia y tramo (tramo = mes realizado k+1)
realiz = dateshift(T.fecha_decision, 'end', 'month', 1);
T.tramo = strings(height(T), 1);
for q = 1:size(PERIODS, 1)
    T.tramo(realiz >= PERIODS{q, 2} & realiz <= PERIODS{q, 3}) = PERIODS{q, 1};
end
T.tramo(T.tramo == "") = "otro";
S = groupsummary(T, {'estrategia', 'tramo'}, {'mean', 'median', 'max'}, 'segundos_solucion');
S2 = groupsummary(T, {'estrategia', 'tramo'}, 'mean', 'segundos_C_rho');
S.media_segundos_C_rho = S2.mean_segundos_C_rho;
T.no_solved = double(T.estado ~= "Solved");
S3 = groupsummary(T, {'estrategia', 'tramo'}, 'sum', 'no_solved');
S.n_estado_no_solved = S3.sum_no_solved;
T.no_solved = [];
% Solo versiones (cvx_version tambien imprime usuario e ID del equipo: no se guardan)
cv = regexp(evalc('cvx_version'), 'Version [\d.]+, Build \d+', 'match', 'once');
mv = regexp(evalc('cvx_solver'), 'Mosek\s+(?:\S*selected\S*\s+)?(\d+\.\d+\.\d+)', 'tokens', 'once');
E = table(string(version), "CVX " + string(cv), "MOSEK " + string(mv{1}), feature('numcores'), ...
    maxNumCompThreads, string(datetime('now')), PASO, 'VariableNames', {'matlab', 'cvx', 'mosek', ...
    'nucleos', 'hilos_matlab', 'fecha_corrida', 'paso_muestreo'});
writetable(T, fullfile(OUT_DIR, 'tiempos_por_mes.csv'));
writetable(S, fullfile(OUT_DIR, 'tiempos_resumen.csv'));
writetable(E, fullfile(OUT_DIR, 'entorno_tiempos.csv'));
disp(S);
assert(all(T.ok_x) && all(T.ok_rho), 'Hay meses que no reproducen lo guardado (ver tiempos_por_mes.csv).');
