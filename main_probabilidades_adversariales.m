%% MAIN_PROBABILIDADES_ADVERSARIALES  Distribucion adversarial p de la
% bola de Wasserstein en cada fecha de decision, para las geometrias 1 y 2,
% con c1 = (0.90, 0.01) y c2 = (0.80, 0.01).
%
% Para un portafolio x y la ventana D_k, con g_s = log G_ks(x), se resuelve
% el LP primal (ec. 51): min sum_{r,s} Gamma_rs g_s, filas = 1/N,
% sum C.*Gamma <= rho_k, Gamma >= 0, y se toma p_s = sum_r Gamma_rs.
% Casos:
%   comun  : x = x_k guardado del nominal con el mismo delta; p de G1 y de
%            G2 frente al MISMO portafolio (solo cambia la geometria).
%   propio : p de G1(c) frente a su x_k guardado y de G2(c) frente al suyo.
% Se calcula en las 132 fechas (sin elegir fechas); el detalle por
% escenario solo se guarda en las tres fechas fijadas en las verificaciones
% (dic-2014, dic-2018, jun-2022). El LP puede tener optimos multiples: en
% esas tres fechas se resuelve tambien con SDPT3 como diagnostico.
% Solo datos: no elige parametros ni escribe en ningun documento.
%
% Requiere WK_PANEL y WK_RESULTS_ROOT. Con WK_PA_MUESTRA=n procesa solo las
% primeras n fechas y no escribe (prueba pequena).
% Salidas (carpeta nueva; aborta si ya tiene archivos):
%   <WK_RESULTS_ROOT>/results_probabilidades_adversariales/resumen_por_fecha.csv
%   .../detalle_fechas_fijas.csv
%   .../verificaciones.csv

clear; clc;
PROJECT_DIR = fileparts(mfilename('fullpath'));
addpath(fullfile(PROJECT_DIR, 'wdro-market'), fullfile(PROJECT_DIR, 'results_finales'));
cfg = config_rutas();
RES = cfg.results_root;
MUESTRA = str2double(getenv('WK_PA_MUESTRA'));
OUT_DIR = fullfile(RES, 'results_probabilidades_adversariales');
if isnan(MUESTRA)
    if exist(OUT_DIR, 'dir')
        L = dir(OUT_DIR);
        if any(~ismember({L.name}, {'.', '..'}))
            error('main_probabilidades_adversariales:wouldOverwrite', '%s ya tiene archivos; no se sobrescribe.', OUT_DIR);
        end
    else
        mkdir(OUT_DIR);
    end
end

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
CONFIGS = [0.90, 0.01; 0.80, 0.01];          % c1, c2
FIXED = [datetime(2014,12,31), datetime(2018,12,31), datetime(2022,6,30)];
data = load_monthly_data(cfg.panel, TICKERS);
traj = cargar_trayectorias(RES, data);

rows = {}; det = {}; chk = {};
t0 = tic;
for c = 1:size(CONFIGS, 1)
    dl = CONFIGS(c, 1); eta = CONFIGS(c, 2);
    cname = sprintf('c%d (%.2f, %.2f)', c, dl, eta);
    rn  = traj(sprintf('Nominal (%.2f)', dl));
    rg1 = traj(sprintf('G1 (%.2f, %.2f)', dl, eta));
    rg2 = traj(sprintf('G2 (%.2f, %.2f)', dl, eta));
    p1 = rg1.params; p2 = rg2.params;
    assert(isequal(rn.dates, rg1.dates, rg2.dates), 'Fechas de decision distintas.');
    nd = numel(rn.dates); if ~isnan(MUESTRA), nd = MUESTRA; end
    for i = 1:nd
        k = find(data.dates == rn.dates(i), 1);
        w = k - p1.N + 1 : k;
        Rk = data.R(w, :); rf = data.rf_return(k); N = numel(w);
        vix = data.vix(w); spy = data.mkt_return(w);
        C.G1 = build_transport_cost(Rk, p1.eps_esc);
        C.G2 = build_transport_cost_market(Rk, spy, vix, p2.weights, p2.eps_esc);
        rho.G1 = compute_rho(C.G1, eta); rho.G2 = compute_rho(C.G2, eta);
        xs.comun.G1 = [rn.x0(i); rn.x(i, :)'];  xs.comun.G2 = xs.comun.G1;
        xs.propio.G1 = [rg1.x0(i); rg1.x(i, :)']; xs.propio.G2 = [rg2.x0(i); rg2.x(i, :)'];
        hi = vix > median(vix); neg = spy < 0;
        tag = cname + " " + string(datestr(rn.dates(i), 'yyyy-mm'));
        chk = add(chk, tag, "rho G1 recalculado = guardado", abs(rho.G1 - rg1.rho(i)), 1e-12);
        chk = add(chk, tag, "rho G2 recalculado = guardado", abs(rho.G2 - rg2.rho(i)), 1e-12);
        pc = struct();
        for caso = ["comun", "propio"]
            for g = ["G1", "G2"]
                x = xs.(caso).(g);
                gs = log(x(1) * (1 + rf) + (1 + Rk) * x(2:end));
                [v, Gam, st] = primal_lp(gs, C.(g), rho.(g), 'mosek');
                p = sum(Gam, 1)';
                used = sum(C.(g) .* Gam, 'all');
                t = tag + " " + caso + " " + g;
                chk = add(chk, t, "estado MOSEK = Solved", double(st ~= "Solved"), 0);
                chk = add(chk, t, "|sum p - 1|", abs(sum(p) - 1), 1e-8);
                chk = add(chk, t, "-min p", -min(p), 1e-8);
                chk = add(chk, t, "costo usado - rho", used - rho.(g), 1e-8);
                chk = add(chk, t, "|valor primal - sum p g|", abs(v - p' * gs), 1e-10);
                [~, iw] = min(gs);
                rows{end + 1} = table(string(cname), rn.dates(i), caso, g, rho.(g), ...
                    0.5 * sum(abs(p - 1 / N)), 1 / sum(p.^2), used / max(rho.(g), eps), ...
                    sum(p(hi)) - mean(hi), sum(p(neg)) - mean(neg), p(iw), ...
                    'VariableNames', {'configuracion', 'fecha_decision', 'caso', 'geometria', 'rho', ...
                    'masa_movida', 'n_efectivo_escenarios', 'costo_usado_sobre_rho', ...
                    'exceso_masa_vix_alto', 'exceso_masa_spy_negativo', 'masa_peor_escenario'}); %#ok<SAGROW>
                if caso == "comun", pc.(g) = p; gc = gs; end
            end
        end
        if any(rn.dates(i) == FIXED)
            x = xs.comun.G1;
            gs = log(x(1) * (1 + rf) + (1 + Rk) * x(2:end));
            [~, G1s] = primal_lp(gs, C.G1, rho.G1, 'sdpt3');
            [~, G2s] = primal_lp(gs, C.G2, rho.G2, 'sdpt3');
            d1 = max(abs(sum(G1s, 1)' - pc.G1)); d2 = max(abs(sum(G2s, 1)' - pc.G2));
            chk = add(chk, tag + " comun G1", "diagnostico: max|p MOSEK - p SDPT3|", d1, NaN);
            chk = add(chk, tag + " comun G2", "diagnostico: max|p MOSEK - p SDPT3|", d2, NaN);
            det{end + 1} = table(repmat(string(cname), N, 1), repmat(rn.dates(i), N, 1), data.dates(w), ...
                gc, vix, spy, hi, pc.G1, pc.G2, ...
                'VariableNames', {'configuracion', 'fecha_decision', 'fecha_escenario', 'g_s', ...
                'vix_s', 'spy_s', 'vix_alto', 'p_G1', 'p_G2'}); %#ok<SAGROW>
        end
    end
    fprintf('%s: %d fechas listas (%.1f s acumulados)\n', cname, nd, toc(t0));
end
T = vertcat(rows{:}); V = vertcat(chk{:});
fprintf('Verificaciones: %d de %d correctas (diagnosticos sin tolerancia incluidos como correctos).\n', sum(V.ok), height(V));
if ~isnan(MUESTRA)
    fprintf('Estimado para 132 fechas: %.1f min\n', toc(t0) / MUESTRA * 132 / 60);
    disp(T(:, {'configuracion', 'caso', 'geometria', 'masa_movida', 'exceso_masa_vix_alto', 'exceso_masa_spy_negativo'}));
    disp(V(~V.ok, :)); return
end
writetable(T, fullfile(OUT_DIR, 'resumen_por_fecha.csv'));
writetable(vertcat(det{:}), fullfile(OUT_DIR, 'detalle_fechas_fijas.csv'));
writetable(V, fullfile(OUT_DIR, 'verificaciones.csv'));
disp(V(~V.ok, :));


function c = add(c, objeto, comprobacion, valor, tol)
% tol = NaN: diagnostico que solo se registra
    valor = full(double(valor));
    ok = isnan(tol) || valor <= tol;
    c{end + 1} = table(string(objeto), string(comprobacion), valor, tol, ok, ...
        'VariableNames', {'objeto', 'comprobacion', 'valor', 'tolerancia', 'ok'});
end


function [v, Gam, st] = primal_lp(g, C, rho, solver)
% Ec. 51 (igual que en test_seccion_21_4.m)
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
    v = cvx_optval;
    Gam = full(Gam);
end
