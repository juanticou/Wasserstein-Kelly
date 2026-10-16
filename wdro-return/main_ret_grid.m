%% main_ret_grid.m
% Malla (mu, eps) de la restriccion de retorno esperado robusto
% (Fonseca y Junca, arXiv:2111.04663) sobre el Wasserstein-Kelly de
% Geometria 1, con (delta, eta) FIJOS en la configuracion ya elegida
% (delta = 0.90, eta = 0.01). mu es un valor FIJO por ejecucion.
%
% VALIDACION: este script corre SOLO sobre el periodo de
% validacion -- los datos se recortan con truncate_data.m antes de correr
% ningun backtest, asi que el codigo nunca ve 2019 en adelante. Elige
% (mu, eps) a partir de esta salida; el periodo de prueba se evalua DESPUES,
% una sola vez, con la combinacion elegida. Ojo: el periodo de prueba ya se
% uso una vez para el modelo base (delta=0.90, eta=0.01); por eso mu y eps
% deben escogerse mirando unicamente esta salida de validacion.
%
% Compara cada (mu, eps) contra el BASELINE sin restriccion de retorno
% (mismo delta y eta, mu = -Inf). Corre antes main_ret_feasibility_map.m
% y ajusta MU_GRID / EPS_GRID segun el mapa.
%
% Requiere: CVX + MOSEK. UBICACION: Wasserstein-Kelly/wdro-return/.

clear; clc; close all;

%% 1. Configuracion y path
PROJECT_DIR = fileparts(mfilename('fullpath'));
ROOT_DIR    = fileparts(PROJECT_DIR);
addpath(PROJECT_DIR);
addpath(ROOT_DIR);

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
CSV_PATH = fullfile(ROOT_DIR, 'data', 'processed', 'monthly_panel.csv');
if ~isfile(CSV_PATH)
    error('main_ret_grid:csvNotFound', 'No se encontro %s.', CSV_PATH);
end

base_params.N       = 60;
base_params.tau     = 0.001;
base_params.xbar    = 0.25;
base_params.gamma   = 1;
base_params.delta   = 0.90;
base_params.eta     = 0.01;
base_params.solver  = 'mosek';
base_params.eps_esc = 1e-6;

% Valores iniciales: AJUSTAR segun main_ret_feasibility_map.m
MU_GRID  = [ 0.010, 0.020, 0.05, 0.07, 0.1];     % retorno esperado minimo mensual (fijo)
EPS_GRID = [0, 0.005, 0.006, 0.008 ];            % radio de la restriccion de retorno

ALPHA = 0.95;
OUT_DIR = fullfile(PROJECT_DIR, 'results_ret_grid_validacion');
if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end

%% 2. Datos recortados a validacion
data = load_monthly_data(CSV_PATH, TICKERS);
VALIDATION_START = max(datetime(2015,1,1), min(data.dates));
VALIDATION_END   = datetime(2018,12,31);
data_val = truncate_data(data, VALIDATION_END);
fprintf('Datos recortados a %s. Combinaciones: %d (mu) x %d (eps) + baseline.\n', ...
    datestr(VALIDATION_END), numel(MU_GRID), numel(EPS_GRID));

%% 3. Baseline: mismo modelo sin restriccion de retorno
fprintf('\n--- Baseline (delta=%.2f, eta=%.2f, sin restriccion de retorno) ---\n', base_params.delta, base_params.eta);
p0 = base_params; p0.mu = -Inf; p0.eps_ret = 0;
r0_full = run_backtest_wdro_kelly_ret(data_val, p0);
r0 = extract_period_results(r0_full, VALIDATION_START, VALIDATION_END);
m0 = compute_metrics(r0, ALPHA);
fprintf('riqueza final = %.4f | CAGR = %.2f%% | MDD = %.2f%%\n', m0.wealth_final, 100*m0.CAGR, 100*m0.max_drawdown);

%% 4. Malla (mu, eps)
nm = numel(MU_GRID); ne = numel(EPS_GRID);
res = cell(nm, ne);  met = cell(nm, ne);
Wealth = nan(nm, ne); CAGR = nan(nm, ne); MDD = nan(nm, ne); CVaR = nan(nm, ne);
Turn = nan(nm, ne); NTr = nan(nm, ne); Feas = nan(nm, ne); Slack = nan(nm, ne); Sharpe = nan(nm, ne);

for i = 1:nm
    for j = 1:ne
        fprintf('mu = %.4f, eps = %.4f ... ', MU_GRID(i), EPS_GRID(j));
        p = base_params; p.mu = MU_GRID(i); p.eps_ret = EPS_GRID(j);
        try
            r_full = run_backtest_wdro_kelly_ret(data_val, p);
            r = extract_period_results(r_full, VALIDATION_START, VALIDATION_END);
            m = compute_metrics(r, ALPHA);
            res{i,j} = r; met{i,j} = m;
            Wealth(i,j) = m.wealth_final; CAGR(i,j) = m.CAGR; MDD(i,j) = m.max_drawdown;
            CVaR(i,j) = m.CVaR_loss; Turn(i,j) = m.turnover_total; NTr(i,j) = m.n_rebalances;
            Feas(i,j) = mean(strcmp(r.status, 'Solved')); Sharpe(i,j) = m.sharpe;
            Slack(i,j) = mean(r.growth_real - 1) - MU_GRID(i);   % retorno medio realizado - mu
            fprintf('factibilidad = %.0f%% | CAGR = %.2f%% | MDD = %.2f%%\n', 100*Feas(i,j), 100*CAGR(i,j), 100*MDD(i,j));
        catch ME
            warning('main_ret_grid:runFailed', 'mu=%.4f, eps=%.4f: %s', MU_GRID(i), EPS_GRID(j), ME.message);
            fprintf('FALLO\n');
        end
    end
end

%% 5. Tabla maestra (una fila por ejecucion; baseline primero)
rows = {};
rows{end+1} = metrics_row(NaN, NaN, true, 1, mean(r0.growth_real - 1), m0);
for i = 1:nm
    for j = 1:ne
        if isempty(met{i,j}), continue; end
        rows{end+1} = metrics_row(MU_GRID(i), EPS_GRID(j), false, Feas(i,j), mean(res{i,j}.growth_real - 1), met{i,j}); %#ok<SAGROW>
    end
end
T = vertcat(rows{:});
T.CAGR_diff_vs_baseline = T.CAGR - m0.CAGR;
T.MDD_diff_vs_baseline  = T.max_drawdown - m0.max_drawdown;
writetable(T, fullfile(OUT_DIR, 'tabla_maestra_ret_validacion.csv'));
save(fullfile(OUT_DIR, 'grid_ret_validacion.mat'), 'res', 'met', 'r0', 'm0', ...
    'MU_GRID', 'EPS_GRID', 'base_params', 'VALIDATION_START', 'VALIDATION_END', 'ALPHA');

fprintf('\n=== Tabla maestra (validacion), ordenada por CAGR ===\n');
Ts = sortrows(T, 'CAGR', 'descend');
disp(Ts(1:min(12, height(Ts)), {'mu','eps','fraccion_factible','riqueza_final','CAGR','max_drawdown','ret_medio_mensual','cumple_mu','n_transacciones'}));

%% 6. Heatmaps (filas = mu, columnas = eps)
H = @(M, ttl, cbl, fmt, fn) plot_heatmap(M, EPS_GRID, MU_GRID, [ttl ' (validacion)'], cbl, fmt, OUT_DIR, fn, '\epsilon', '\mu (mensual)');
H(Feas, 'Fraccion de fechas resueltas', 'Fraccion Solved', '%.2f', 'heatmap_factibilidad.png');
H(Wealth, 'Riqueza final W_T/W_0', 'Riqueza final', '%.2f', 'heatmap_riqueza_final.png');
H(100*(CAGR - m0.CAGR), 'CAGR - CAGR baseline [pp]', 'pp', '%.2f', 'heatmap_cagr_diff.png');
H(100*(MDD - m0.max_drawdown), 'MDD - MDD baseline [pp, negativo = mejor]', 'pp', '%.2f', 'heatmap_mdd_diff.png');
H(100*CVaR, sprintf('CVaR %.0f%% de perdida mensual [pp]', 100*ALPHA), 'pp', '%.2f', 'heatmap_cvar.png');
H(Sharpe, 'Sharpe anualizado', 'Sharpe', '%.2f', 'heatmap_sharpe.png');
H(Turn, 'Turnover acumulado', 'Turnover', '%.2f', 'heatmap_turnover.png');
H(NTr, 'Meses con transaccion', '# transacciones', '%.0f', 'heatmap_n_transacciones.png');
H(100*Slack, 'Retorno medio realizado - mu [pp/mes] (>0: cumple mu)', 'pp/mes', '%.2f', 'heatmap_slack_mu.png');

%% 7. Riqueza acumulada: una figura por mu (curvas = eps) + baseline en negro
for i = 1:nm
    figure('Position', [100, 100, 950, 520]); hold on;
    plot([r0.dates(1); r0.dates], r0.wealth, 'k', 'LineWidth', 2.2, 'DisplayName', 'baseline (sin restriccion)');
    cols = lines(ne);
    for j = 1:ne
        if isempty(res{i,j}), continue; end
        r = res{i,j};
        plot([r.dates(1); r.dates], r.wealth, 'LineWidth', 1.3, 'Color', cols(j,:), ...
            'DisplayName', sprintf('\\epsilon=%.3g', EPS_GRID(j)));
    end
    hold off; grid on; legend('Location', 'best');
    title(sprintf('Riqueza acumulada, \\mu=%.3f mensual (validacion)', MU_GRID(i)));
    xlabel('Fecha'); ylabel('W_t / W_0');
    saveas(gcf, fullfile(OUT_DIR, sprintf('riqueza_mu_%s.png', strrep(sprintf('%.4f', MU_GRID(i)), '.', 'p'))));
end

fprintf(['\nElige (mu, eps) a partir de ESTA salida de validacion. El periodo de prueba se evalua ', ...
    'despues, una sola vez, con la combinacion elegida.\nResultados en "%s".\n'], OUT_DIR);


%% --- Funcion local ---
function row = metrics_row(mu, eps_ret, is_base, feas, ret_medio, m)
    cumple = isnan(mu) || (ret_medio >= mu);
    row = table(mu, eps_ret, is_base, feas, m.wealth_final, m.CAGR, m.log_growth_mean, ...
        m.variance_monthly, m.max_drawdown, m.worst_month, m.VaR_loss, m.CVaR_loss, ...
        m.sharpe, m.sortino, m.calmar, m.turnover_total, m.n_rebalances, m.cost_total, ...
        m.Neff_mean, ret_medio, cumple, m.n_months, ...
        'VariableNames', {'mu','eps','es_baseline','fraccion_factible','riqueza_final','CAGR','log_crecimiento_medio', ...
        'varianza_mensual','max_drawdown','peor_mes','VaR_perdida','CVaR_perdida', ...
        'sharpe','sortino','calmar','turnover_total','n_transacciones','costo_total', ...
        'Neff_promedio','ret_medio_mensual','cumple_mu','n_meses'});
end
