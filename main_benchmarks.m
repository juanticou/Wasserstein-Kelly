%% MAIN_BENCHMARKS  Benchmarks del Cuadro 7 de la propuesta (NUCLEO) y
% Kelly nominal sin costos (tau = 0) como diagnostico.
%
% Estrategias (mismo protocolo que las seis vigentes de results_prueba_v2:
% primera decision dic-2014, W_0 = 1, h_0 en efectivo, 132 meses, tramos
% por recorte con extract_period_results.m):
%   - Bajo riesgo, Igual ponderacion (con costos), SPY pasivo
%     (run_backtest_benchmark.m)
%   - Nominal sin costos con delta en {0.80, 0.90} (los delta de las
%     configuraciones elegidas), con run_backtest_nominal_kelly.m sin
%     cambios y tau = 0. Turnover canonico: TO_k = sum_j |x_jk - h_jk|
%     (con tau = 0, b y s no son unicos; propuesta sec. 7.5 y 13.2).
% No se elige ni ajusta ningun parametro.
%
% Requiere WK_PANEL y WK_RESULTS_ROOT (ver results_finales/MANIFIESTO.md).
% Salidas (carpeta nueva; aborta si ya tiene archivos):
%   <WK_RESULTS_ROOT>/results_benchmarks/benchmarks.mat
%   <WK_RESULTS_ROOT>/results_benchmarks/metricas_por_tramo_benchmarks.csv
%   <WK_RESULTS_ROOT>/results_benchmarks/verificaciones_benchmarks.csv

clear; clc;

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
cfg = config_rutas();
RES = cfg.results_root;
OUT_DIR = fullfile(RES, 'results_benchmarks');
if exist(OUT_DIR, 'dir')
    L = dir(OUT_DIR);
    if any(~ismember({L.name}, {'.', '..'}))
        error('main_benchmarks:wouldOverwrite', '%s ya tiene archivos; no se sobrescribe.', OUT_DIR);
    end
else
    mkdir(OUT_DIR);
end

ALPHA = 0.95;
TAU   = 0.001;
DELTAS_TAU0 = [0.80, 0.90];
VALIDATION_START = datetime(2015,1,1);  VALIDATION_END = datetime(2018,12,31);
TEST_START       = datetime(2019,1,1);  TEST_END       = datetime(2025,12,31);

data = load_monthly_data(cfg.panel, TICKERS);
S = load(fullfile(RES, 'results_verificaciones', 'nominal_backtests.mat'), ...
    'nominal_results', 'DELTAS_TO_RUN');
nominal_all = S.nominal_results; nominal_deltas = S.DELTAS_TO_RUN; clear S
nom_ref = nominal_all{find(abs(nominal_deltas - 0.90) < 1e-12, 1)};
base_p = nom_ref.params;
N = base_p.N;

chk = {};
addchk = @(c, nombre, valor, tol, ok) [c, {table(string(nombre), valor, tol, ok, ...
    'VariableNames', {'comprobacion', 'valor', 'tolerancia', 'ok'})}];

%% 0. Prueba pequena: ruta del nominal y tiempo
% (a) tau = 0.001 por esta ruta reproduce los primeros 4 meses guardados
d4 = truncar(data, N + 4);
r4 = run_backtest_nominal_kelly(d4, base_p);
dG = max(abs(r4.growth_real - nom_ref.growth_real(1:4)));
dx = max(abs([r4.x, r4.x0] - [nom_ref.x(1:4, :), nom_ref.x0(1:4)]), [], 'all');
chk = addchk(chk, 'nominal tau=0.001 (0.90) reproduce 4 meses guardados: max|dG|', dG, 1e-8, dG <= 1e-8);
chk = addchk(chk, 'nominal tau=0.001 (0.90) reproduce 4 meses guardados: max|dx|', dx, 1e-8, dx <= 1e-8);
fprintf('Reproduccion nominal tau=0.001: dG = %.2e, dx = %.2e\n', dG, dx);
assert(dG <= 1e-8 && dx <= 1e-8, 'La ruta del nominal no reproduce lo guardado; se detiene.');

% (b) tiempo de un mes con tau = 0
p0 = base_p; p0.tau = 0; p0.delta = 0.90;
tic; run_backtest_nominal_kelly(truncar(data, N + 1), p0); t1 = toc;
T_dec = size(data.R, 1) - N;
fprintf('Un mes con tau = 0: %.2f s -> estimado %.1f min para %d backtests de %d meses\n', ...
    t1, t1 * T_dec * numel(DELTAS_TAU0) / 60, numel(DELTAS_TAU0), T_dec);

%% 1. Benchmarks
res = struct('name', {}, 'geo', {}, 'delta', {}, 'eta', {}, 'r', {});
pb = struct('N', N, 'tau', TAU);
res(end+1) = struct('name', "Bajo riesgo",       'geo', "benchmark", 'delta', NaN, 'eta', NaN, 'r', run_backtest_benchmark(data, 'bajo_riesgo', pb));
res(end+1) = struct('name', "Igual ponderación", 'geo', "benchmark", 'delta', NaN, 'eta', NaN, 'r', run_backtest_benchmark(data, 'igual_ponderacion', pb));
res(end+1) = struct('name', "SPY pasivo",        'geo', "benchmark", 'delta', NaN, 'eta', NaN, 'r', run_backtest_benchmark(data, 'spy', pb));

%% 2. Nominal sin costos
for delta = DELTAS_TAU0
    p = base_p; p.tau = 0; p.delta = delta;
    tic; r = run_backtest_nominal_kelly(data, p); t = toc;
    fprintf('Nominal sin costos (%.2f): %d meses en %.1f s\n', delta, numel(r.dates), t);
    r.turnover_cvx = r.turnover;
    r.turnover = sum(abs(r.x - r.h(1:end-1, 2:end)), 2);   % canonico
    r.cost = zeros(size(r.turnover));

    % Verificaciones del modelo con tau = 0
    bal = max(abs(r.x0 + sum(r.x, 2) - 1));
    neg = min([r.x(:); r.x0(:)]);
    sup = max(r.x(:)) - p.xbar;
    gmin = inf;
    for i = 1:numel(r.dates)
        k = find(data.dates == r.dates(i), 1);
        Rk = data.R(k - N + 1 : k, :);
        gmin = min(gmin, min(r.x0(i) * (1 + r.rf(i)) + (1 + Rk) * r.x(i, :)') - delta);
    end
    dTO = max(r.turnover - r.turnover_cvx);
    nopt = sum(~strcmp(r.status, 'Solved'));
    tag = sprintf('nominal tau=0 (%.2f): ', delta);
    chk = addchk(chk, [tag 'max|x0+sum x-1|'], bal, 1e-7, bal <= 1e-7);
    chk = addchk(chk, [tag 'min x'], neg, -1e-7, neg >= -1e-7);
    chk = addchk(chk, [tag 'max x - xbar'], sup, 1e-7, sup <= 1e-7);
    chk = addchk(chk, [tag 'min (G_ks - delta) en la ventana'], gmin, -1e-7, gmin >= -1e-7);
    chk = addchk(chk, [tag 'max(TO canonico - TO cvx)'], dTO, 1e-7, dTO <= 1e-7);
    chk = addchk(chk, [tag 'meses sin optimizacion'], nopt, 0, nopt == 0);
    res(end+1) = struct('name', string(sprintf('Nominal sin costos (%.2f)', delta)), ...
        'geo', "nominal_tau0", 'delta', delta, 'eta', 0, 'r', r); %#ok<SAGROW>
end

%% 3. Verificaciones de los benchmarks
ew = res(2).r;
bal = max(abs(ew.x0 + sum(ew.x, 2) - (1 - TAU * ew.turnover)));
dsp = max(max(ew.x, [], 2) - min(ew.x, [], 2));
chk = addchk(chk, 'igual ponderacion: max|x0+sum x-(1-tau TO)|', bal, 1e-12, bal <= 1e-12);
chk = addchk(chk, 'igual ponderacion: max(max x_j - min x_j)', dsp, 1e-12, dsp <= 1e-12);
for m = 1:numel(res)
    same = isequal(res(m).r.dates, nom_ref.dates);
    chk = addchk(chk, res(m).name + ": mismas 132 fechas de decision que el nominal guardado", double(same), 1, same);
end

%% 4. Metricas por tramo
periods = {'validacion', VALIDATION_START, VALIDATION_END; 'prueba', TEST_START, TEST_END};
rows = {};
for m = 1:numel(res)
    for q = 1:size(periods, 1)
        sr = extract_period_results(res(m).r, periods{q, 2}, periods{q, 3});
        mt = compute_metrics(sr, ALPHA);
        if res(m).name == "SPY pasivo"
            mt.max_weight_mean = NaN; mt.Neff_mean = NaN;   % no aplica (1 activo, fuera del universo)
        end
        if res(m).name == "Bajo riesgo"
            % Exceso sobre r^f identicamente cero (G = 1 + r^f_k): Sharpe no
            % definido. compute_metrics devuelve ruido de punto flotante
            % (std ~1e-19 > 0), asi que se fija NaN aqui.
            ex = sr.growth_real - 1 - sr.rf;
            chk = addchk(chk, "Bajo riesgo (" + periods{q, 1} + "): max|exceso sobre rf|", max(abs(ex)), 1e-15, max(abs(ex)) <= 1e-15);
            mt.sharpe = NaN;
        end
        rows{end + 1} = table(res(m).name, res(m).geo, res(m).delta, res(m).eta, ...
            string(periods{q, 1}), min(sr.dates), max(sr.dates), mt.n_months, ...
            mt.wealth_final, mt.log_growth_mean, mt.CAGR, mt.max_drawdown, mt.worst_month, ...
            mt.variance_monthly, mt.VaR_loss, mt.CVaR_loss, mt.sharpe, mt.sortino, mt.calmar, ...
            mt.turnover_total, mt.n_rebalances, mt.cost_frac_total, mt.cost_monetary_total, ...
            mt.max_weight_mean, mt.Neff_mean, mt.risky_share_mean, mt.n_violations_delta, ...
            mt.min_growth_real, mt.n_solver_failed, ...
            'VariableNames', {'estrategia', 'geometria', 'delta', 'eta', 'tramo', 'primer_mes', ...
            'ultimo_mes', 'n_meses', 'riqueza_final', 'log_crecimiento_medio', 'CAGR', ...
            'max_drawdown', 'peor_mes', 'varianza_mensual', 'VaR_perdida', 'CVaR_perdida', ...
            'sharpe', 'sortino', 'calmar', 'turnover_total', 'n_transacciones', ...
            'costo_fraccional', 'costo_monetario', 'peso_max_promedio', 'Neff_promedio', ...
            'proporcion_riesgo_media', 'violaciones_delta', 'min_factor_crecimiento', ...
            'meses_sin_optimizacion'}); %#ok<SAGROW>

        % Riqueza de los benchmarks pasivos = producto de sus retornos
        if q == 2 && any(res(m).name == ["SPY pasivo", "Bajo riesgo"])
            rd = dateshift(res(m).r.dates, 'end', 'month', 1);
            kk = find(rd >= TEST_START & rd <= TEST_END);
            [~, loc] = ismember(rd(kk), data.dates);
            if res(m).name == "SPY pasivo"
                ref = prod(1 + data.mkt_return(loc));
            else
                ref = prod(1 + res(m).r.rf(kk));
            end
            e = abs(mt.wealth_final / ref - 1);
            chk = addchk(chk, res(m).name + ": riqueza de prueba = producto de retornos (error relativo)", e, 1e-10, e <= 1e-10);
        end
    end
end
M = vertcat(rows{:});
C = vertcat(chk{:});
save(fullfile(OUT_DIR, 'benchmarks.mat'), 'res', 'TAU', 'DELTAS_TAU0');
writetable(M, fullfile(OUT_DIR, 'metricas_por_tramo_benchmarks.csv'));
writetable(C, fullfile(OUT_DIR, 'verificaciones_benchmarks.csv'));
disp(C);
disp(M(M.tramo == "prueba", {'estrategia', 'riqueza_final', 'CAGR', 'max_drawdown', 'sharpe', ...
    'turnover_total', 'costo_monetario', 'proporcion_riesgo_media'}));
fprintf('Comprobaciones: %d de %d correctas.\n', sum(C.ok), height(C));


function d = truncar(data, T)
    d = data;
    d.dates = data.dates(1:T); d.R = data.R(1:T, :);
    d.rf_return = data.rf_return(1:T); d.mkt_return = data.mkt_return(1:T);
    d.vix = data.vix(1:T);
end
