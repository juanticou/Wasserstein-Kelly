%% analyze_solver_status.m
% T3: estado del solucionador y "meses sin optimizacion", usando SOLO
% resultados ya guardados (no resuelve nada).
%
% 1. Tabla (fuente, geometria, delta, eta, meses sin optimizacion por
%    clasificacion de classify_solver_status.m, primera fecha) para todas
%    las corridas guardadas de la metodologia:
%      - G1 malla completa 2014-12..2025-11 (results_eta_delta_grid_wdro)
%      - G2 malla de validacion (wdro-market/results_validacion_grid_market)
%      - G1/G2 trayectorias completas de main_geometria_mercado.m
%      - modelos de main_comparacion_modelos.m
%      - nominal por delta de verify_eta0_backtest.m (con estado MOSEK nativo)
%    Las corridas guardadas antes de este cambio solo tienen cvx_status; la
%    clasificacion se deriva de el.
% 2. Diagnostico de las trayectorias casi planas con eta >= 0.15 (G1,
%    delta = 0.90): por mes, exposicion riesgosa, rho_k, lambda_k, r^f_k y
%    el presupuesto minimo para concentrar toda la masa en un escenario,
%    rho_bar_k = min_s (1/N) sum_r C_k(r,s). Si rho_k >= rho_bar_k el
%    adversario podria llevar toda la probabilidad a un solo escenario
%    (en la malla guardada esto NO ocurre en ningun mes: rho_k << rho_bar_k).
%    lambda_k ~ 0 aparece cuando el portafolio esta en bajo riesgo: G_ks
%    es igual en todos los escenarios, el transporte no cambia el valor y
%    el multiplicador queda indeterminado.
%
% Salidas: results_estado_solver/

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
cfg = config_rutas();   % rutas de datos y resultados (WK_PANEL, WK_RESULTS_ROOT)
RES = cfg.results_root;
CSV_PATH = cfg.panel;
OUT_DIR  = fullfile(RES, 'results_estado_solver');
preparar_salida(cfg, OUT_DIR);
data = load_monthly_data(CSV_PATH, TICKERS);

%% 1. Tabla de meses sin optimizacion
rows = {};

S = load(fullfile(RES, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'), 'grid');
rows = add_grid_rows(rows, S.grid, "malla_completa", "G1");
grid_g1 = S.grid;

S = load(fullfile(RES, 'wdro-market', 'results_validacion_grid_market', ...
    'grid_delta_eta_market_validacion.mat'), 'grid');
rows = add_grid_rows(rows, S.grid, "malla_validacion", "G2");

% Corridas heredadas: solo existen en la raiz historica; se omiten si faltan.
geo_path = fullfile(RES, 'wdro-market', 'results_geometria_mercado', 'geometria_mercado_vs_retornos.mat');
if isfile(geo_path)
    S = load(geo_path);
    for e = 1:numel(S.ETA_GRID)
        rows{end + 1} = status_row("main_geometria_mercado", "G1", S.results_geo1{e}); %#ok<SAGROW>
        rows{end + 1} = status_row("main_geometria_mercado", "G2", S.results_geo2{e}); %#ok<SAGROW>
    end
end

cmp_path = fullfile(RES, 'wdro-market', 'results_comparacion_modelos', 'comparacion_modelos.mat');
if isfile(cmp_path)
    S = load(cmp_path);
    for m = 1:numel(S.results)
        if strcmp(S.MODEL_NAMES(m), "SP500")
            continue   % comprar y mantener, no resuelve ningun problema
        end
        rows{end + 1} = status_row("main_comparacion_modelos", string(S.MODEL_NAMES(m)), S.results{m}); %#ok<SAGROW>
    end
end

nom_path = fullfile(RES, 'results_verificaciones', 'nominal_backtests.mat');
if isfile(nom_path)
    S = load(nom_path, 'nominal_results');
    for m = 1:numel(S.nominal_results)
        rows{end + 1} = status_row("verify_eta0_backtest", "nominal", S.nominal_results{m}); %#ok<SAGROW>
    end
    % Estados nativos de MOSEK registrados en esas corridas.
    infos = [S.nominal_results{:}];
    infos = vertcat(infos.solver_info);
    solsta = cellfun(@(z) z.mosek_solution_status, infos, 'UniformOutput', false);
    prosta = cellfun(@(z) z.mosek_problem_status, infos, 'UniformOutput', false);
    [u, ~, ic] = unique(strcat(prosta, " / ", solsta));
    fprintf('Estados nativos MOSEK en los backtests nominales nuevos:\n');
    for q = 1:numel(u)
        fprintf('  %s : %d meses\n', u{q}, sum(ic == q));
    end
    fprintf('cvx_precision = %s, cvx_slvtol (max) = %g\n', mat2str(infos{1}.cvx_precision, 4), ...
        max(cellfun(@(z) z.cvx_slvtol, infos)));
end

T = vertcat(rows{:});
writetable(T, fullfile(OUT_DIR, 'tabla_meses_sin_optimizacion.csv'));
fprintf('\nCorridas revisadas: %d | meses revisados: %d | meses sin optimizacion: %d\n', ...
    height(T), sum(T.n_meses), sum(T.meses_sin_optimizacion));

%% 2. Diagnostico eta >= 0.15 (G1, delta = 0.90)
DELTA_DIAG = 0.90;
ETA_DIAG = [0, 0.10, 0.15, 0.30];
i_d = find(abs(grid_g1.delta_grid - DELTA_DIAG) < 1e-12, 1);
N = grid_g1.base_params.N;

r_ref = grid_g1.results_wdro{i_d, 1};
[~, kk] = ismember(r_ref.dates, data.dates);
T_dec = numel(kk);
rho_bar = zeros(T_dec, 1);
c_med   = zeros(T_dec, 1);
for t = 1:T_dec
    k = kk(t);
    C = build_transport_cost(data.R(k - N + 1 : k, :), grid_g1.base_params.eps_esc);
    rho_bar(t) = min(mean(C, 1));
    c_med(t)   = median(C(triu(true(N), 1)));
end

D = table(r_ref.dates, data.rf_return(kk), c_med, rho_bar, ...
    'VariableNames', {'fecha_decision', 'rf_mensual', 'mediana_C', 'rho_bar_concentrar'});
for e = ETA_DIAG
    j = find(abs(grid_g1.eta_grid - e) < 1e-12, 1);
    r = grid_g1.results_wdro{i_d, j};
    tag = strrep(sprintf('eta_%.2f', e), '.', '_');
    D.(['exposicion_riesgo_', tag]) = sum(r.x, 2);
    D.(['rho_', tag])    = r.rho;
    D.(['lambda_', tag]) = r.lambda;
    D.(['rho_sobre_rhobar_', tag]) = r.rho ./ rho_bar;
    D.(['G_real_', tag]) = r.growth_real;
end
writetable(D, fullfile(OUT_DIR, 'diagnostico_eta_alto.csv'));

pre  = D.fecha_decision <  datetime(2022,1,1);
post = D.fecha_decision >= datetime(2022,1,1);
fprintf('\nDiagnostico G1, delta=%.2f (pre-2022: %d meses, desde 2022: %d meses)\n', ...
    DELTA_DIAG, sum(pre), sum(post));
fprintf('  r^f mensual medio: pre=%.4f  post=%.4f | rho_bar mediana: pre=%.3f post=%.3f\n', ...
    mean(D.rf_mensual(pre)), mean(D.rf_mensual(post)), median(D.rho_bar_concentrar(pre)), ...
    median(D.rho_bar_concentrar(post)));
for e = ETA_DIAG
    tag = strrep(sprintf('eta_%.2f', e), '.', '_');
    expo = D.(['exposicion_riesgo_', tag]);
    lam  = D.(['lambda_', tag]);
    ratio = D.(['rho_sobre_rhobar_', tag]);
    G = D.(['G_real_', tag]);
    fprintf(['  eta=%.2f: exposicion pre=%.3f post=%.3f | lambda mediana pre=%.2e post=%.2e | ', ...
        'meses rho>=rho_bar pre=%d post=%d | sd(G-1) post=%.4f\n'], e, mean(expo(pre)), mean(expo(post)), ...
        median(lam(pre)), median(lam(post)), sum(ratio(pre) >= 1), sum(ratio(post) >= 1), std(G(post) - 1));
end

% Grafico: exposicion riesgosa y rho/rho_bar en el tiempo
fig = figure('Position', [100, 100, 1000, 650], 'Visible', 'off');
subplot(3, 1, 1); hold on;
for e = ETA_DIAG
    tag = strrep(sprintf('eta_%.2f', e), '.', '_');
    plot(D.fecha_decision, D.(['exposicion_riesgo_', tag]), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('\\eta=%.2f', e));
end
hold off; ylabel('\Sigma_j x_{jk}'); legend('Location', 'best');
title(sprintf('G1, \\delta=%.2f: exposicion riesgosa por mes de decision', DELTA_DIAG));
set(gca, 'XGrid', 'on', 'YGrid', 'on');
subplot(3, 1, 2); hold on;
for e = ETA_DIAG(2:end)
    tag = strrep(sprintf('eta_%.2f', e), '.', '_');
    plot(D.fecha_decision, D.(['rho_sobre_rhobar_', tag]), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('\\eta=%.2f', e));
end
yline(1, 'k--', 'HandleVisibility', 'off'); hold off;
ylabel('\rho_k / \rho^{conc}_k'); legend('Location', 'best');
title('Radio frente al presupuesto para concentrar toda la masa en un escenario');
set(gca, 'XGrid', 'on', 'YGrid', 'on');
subplot(3, 1, 3);
plot(D.fecha_decision, 100 * D.rf_mensual, 'k', 'LineWidth', 1.2);
ylabel('r^f_k mensual (%)'); title('Tasa del activo de bajo riesgo');
set(gca, 'XGrid', 'on', 'YGrid', 'on');
saveas(fig, fullfile(OUT_DIR, 'diagnostico_eta_alto.png'));
fprintf('Salidas en %s\n', OUT_DIR);


function rows = add_grid_rows(rows, g, fuente, geometria)
    for i = 1:numel(g.delta_grid)
        for j = 1:numel(g.eta_grid)
            if ~isempty(g.results_wdro{i, j})
                rows{end + 1} = status_row(fuente, geometria, g.results_wdro{i, j}); %#ok<AGROW>
            end
        end
    end
end


function row = status_row(fuente, geometria, r)
    if isfield(r, 'status_class')
        cls = r.status_class;
    else
        cls = classify_solver_status(r.status);
    end
    if isfield(r.params, 'eta')
        eta = r.params.eta;
    else
        eta = NaN;   % nominal
    end
    no_opt = ~strcmp(cls, 'optimo');
    if any(no_opt)
        first_date = r.dates(find(no_opt, 1));
    else
        first_date = NaT;
    end
    row = table(fuente, geometria, r.params.delta, eta, numel(r.dates), ...
        min(r.dates), max(r.dates), sum(strcmp(cls, 'optimo')), sum(no_opt), ...
        sum(strcmp(cls, 'inaccurate')), sum(strcmp(cls, 'infeasible_certificado')), ...
        sum(strcmp(cls, 'fallo_numerico')), first_date, ...
        'VariableNames', {'fuente', 'geometria', 'delta', 'eta', 'n_meses', ...
        'primera_decision', 'ultima_decision', 'meses_optimos', 'meses_sin_optimizacion', ...
        'inaccurate', 'infeasible_certificado', 'fallo_numerico', 'primer_mes_sin_optimizacion'});
end
