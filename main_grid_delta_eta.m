%% main_grid_delta_eta.m
% Malla de delta (<=1) y eta -- REFINADA por debajo de 0.05 -- para mapear
% factibilidad y comparar riqueza, retornos, varianza, CVaR y demas
% metricas de la Seccion 19 entre ejecuciones. Esta version YA NO busca
% una combinacion que "domine" al baseline en todas las metricas: genera
% una tabla maestra con todas las metricas de cada ejecucion para que la
% comparacion se haga a mano, cruzando las columnas que interesen.
%
% delta se mantiene <= 1 (ver justificacion en corridas anteriores: con
% delta > 1 la region factible se angosta o desaparece en casi toda la
% malla). eta=0 sigue sirviendo de baseline equivalente al nominal (no se
% corre run_backtest_nominal_kelly por separado).
%
% Requiere: CVX + MOSEK, Statistics and Machine Learning Toolbox
% (boxplot, prctile dentro de compute_metrics.m), y todos los .m del
% proyecto incluyendo run_grid_delta_eta_wdro_only.m,
% build_grid_summary_table.m y matrix_to_wide_table.m.

clear; clc; close all;

%% 1. Configuracion
TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
CSV_PATH = fullfile(PROJECT_DIR, 'data', 'processed', 'monthly_panel.csv');

if ~isfile(CSV_PATH)
    error('main_grid_delta_eta:csvNotFound', 'No se encontro el archivo:\n  %s', CSV_PATH);
end

base_params.N       = 60;
base_params.tau     = 0.001;
base_params.xbar    = 0.25;
base_params.gamma   = 1;
base_params.solver  = 'mosek';
base_params.eps_esc = 1e-6;
% delta y eta se sobrescriben dentro de run_grid_delta_eta_wdro_only.m

ALPHA = 0.95;   % nivel de confianza para VaR/CVaR (Seccion 4.2 de la propuesta)

% Malla: nucleo del Cuadro 8 (delta<=0.90) + resolucion FINA de eta por
% debajo de 0.05 (antes se saltaba directo de 0 a 0.05) + eta hasta 1.00.
% Se quitan los valores muy altos (1.5, 2.0, 3.0): ya se vio en la corrida
% anterior que ahi el modelo se vuelve excesivamente conservador sin
% aportar nada nuevo, y asi se compensa el costo computacional de la
% malla mas fina cerca de cero.
DELTA_GRID = [0.50, 0.60, 0.70, 0.75, 0.80, 0.90];
ETA_GRID   = [0, 0.01, 0.02, 0.03, 0.04, 0.05, 0.10, 0.15, 0.30, 0.50, 1.00];

OUT_DIR = 'results_eta_delta_grid_wdro';   % misma carpeta de la malla anterior
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

n_total = numel(DELTA_GRID) * numel(ETA_GRID);
fprintf('Malla: %d valores de delta x %d valores de eta = %d backtests WDRO (sin nominal por separado).\n', ...
    numel(DELTA_GRID), numel(ETA_GRID), n_total);

%% 2. Cargar datos
data = load_monthly_data(CSV_PATH, TICKERS);

%% 3. Prueba de tiempo en una sola fecha, para estimar el total
h0_test = [1; zeros(numel(TICKERS), 1)];
R_test  = data.R(1:base_params.N, :);
rf_test = data.rf_return(base_params.N);
C_test  = build_transport_cost(R_test, base_params.eps_esc);
rho_test = compute_rho(C_test, ETA_GRID(end));

tic;
delta_test = median(DELTA_GRID);   % valor representativo solo para estimar el tiempo
solve_wdro_kelly(h0_test, R_test, rf_test, base_params.tau, base_params.xbar, ...
    base_params.gamma, delta_test, C_test, rho_test, base_params.solver);
t_one = toc;

n_dates_total = numel(data.dates) - base_params.N - 1;
fprintf(['Tiempo de una sola fecha WDRO: %.2f s. Estimado por cada (delta,eta) (%d fechas): ~%.1f min. ', ...
    'Malla completa (%d combinaciones): ~%.1f min (~%.1f h).\n'], ...
    t_one, n_dates_total, t_one * n_dates_total / 60, ...
    n_total, n_total * t_one * n_dates_total / 60, n_total * t_one * n_dates_total / 3600);

%% 4. Correr la malla completa (solo WDRO, eta=0 como baseline)
grid = run_grid_delta_eta_wdro_only(data, base_params, DELTA_GRID, ETA_GRID, ALPHA);

%% 5. Guardar resultados crudos
save(fullfile(OUT_DIR, 'grid_delta_eta.mat'), 'grid', '-v7.3');

%% 6. Heatmaps individuales (una metrica a la vez sobre toda la malla)
plot_heatmap(grid.feas_wdro, ETA_GRID, DELTA_GRID, ...
    'Factibilidad WDRO (fraccion de fechas resueltas)', 'Fraccion Solved', '%.2f', ...
    OUT_DIR, 'heatmap_factibilidad.png');

plot_heatmap(grid.Wealth_wdro, ETA_GRID, DELTA_GRID, ...
    'Riqueza final W_T / W_0 (WDRO)', 'Riqueza final', '%.2f', ...
    OUT_DIR, 'heatmap_riqueza_final.png');

plot_heatmap(100 * grid.Variance_wdro, ETA_GRID, DELTA_GRID, ...
    'Varianza de retornos mensuales (WDRO)  [x100]', 'Varianza x100', '%.3f', ...
    OUT_DIR, 'heatmap_varianza.png');

plot_heatmap(100 * grid.CVaR_wdro, ETA_GRID, DELTA_GRID, ...
    sprintf('CVaR %.0f%% de perdida mensual (WDRO)  [pp]', 100*ALPHA), ...
    'CVaR (pp)', '%.2f', OUT_DIR, 'heatmap_cvar.png');

if ~isempty(grid.baseline_col)
    plot_heatmap(100 * grid.CAGR_diff, ETA_GRID, DELTA_GRID, ...
        'CAGR(WDRO) - CAGR(\eta=0), mismo \delta  [pp]', 'Diferencia de CAGR (pp)', '%.2f', ...
        OUT_DIR, 'heatmap_cagr_diff.png');

    plot_heatmap(100 * grid.MDD_diff, ETA_GRID, DELTA_GRID, ...
        'MaxDrawdown(WDRO) - MaxDrawdown(\eta=0), mismo \delta  [pp]', ...
        'Diferencia de MDD (pp, negativo = mejor)', '%.2f', ...
        OUT_DIR, 'heatmap_mdd_diff.png');
else
    warning('main_grid_delta_eta:noBaseline', ...
        'eta_grid no incluyo 0; se omiten los mapas de comparacion contra baseline.');
end

%% 7. Tablas (no solo heatmaps): varianza, CVaR y la tabla maestra
% Tablas anchas (delta en filas, eta en columnas) para varianza y CVaR --
% el formato "tabla" pedido explicitamente, ademas de su heatmap.
variance_table = matrix_to_wide_table(grid.Variance_wdro, DELTA_GRID, ETA_GRID);
writetable(variance_table, fullfile(OUT_DIR, 'tabla_varianza.csv'));

cvar_table = matrix_to_wide_table(grid.CVaR_wdro, DELTA_GRID, ETA_GRID);
writetable(cvar_table, fullfile(OUT_DIR, 'tabla_cvar.csv'));

% Tabla maestra: una fila por ejecucion (delta, eta), TODAS las metricas
% como columnas -- riqueza final, CAGR, crecimiento log, varianza, MDD,
% peor mes, VaR, CVaR, turnover, costos, concentracion, supervivencia.
% No hay seleccion de "ganador" aqui: se deja para el analisis manual.
summary_table = build_grid_summary_table(grid);
writetable(summary_table, fullfile(OUT_DIR, 'tabla_maestra_metricas.csv'));

fprintf('\n=== Primeras filas de la tabla maestra (delta, eta, riqueza, CAGR, varianza, CVaR) ===\n');
disp(summary_table(1:min(10, height(summary_table)), ...
    {'delta', 'eta', 'riqueza_final', 'CAGR', 'varianza_mensual', 'CVaR_perdida', 'max_drawdown'}));

%% 8. Graficas de retornos: comparacion EXPLICITA (no automatica)
% delta = 0.75 (nucleo del Cuadro 8) como referencia fija, comparando el
% baseline (eta=0) contra el refinamiento cerca de cero: eta = 0.01,
% 0.05, 0.15. El objetivo es ver el efecto de radios pequenos, no elegir
% un ganador.
DELTA_REF = 0.75;
ETA_COMPARE = [0, 0.01, 0.05, 0.15];

i_ref = find(DELTA_GRID == DELTA_REF, 1);
if isempty(i_ref)
    warning('main_grid_delta_eta:deltaRefNotFound', ...
        'delta=%.2f no esta en DELTA_GRID; se usa el primer valor disponible.', DELTA_REF);
    i_ref = 1;
end

results_compare = {};
labels_compare  = {};
for e = 1:numel(ETA_COMPARE)
    j_e = find(ETA_GRID == ETA_COMPARE(e), 1);
    if isempty(j_e)
        warning('main_grid_delta_eta:etaCompareNotFound', ...
            'eta=%.3f no esta en ETA_GRID; se omite de la comparacion de retornos.', ETA_COMPARE(e));
        continue
    end
    r_e = grid.results_wdro{i_ref, j_e};
    if isempty(r_e)
        continue
    end
    results_compare{end+1} = r_e; %#ok<SAGROW>
    labels_compare{end+1}  = sprintf('\\eta=%.2f', ETA_GRID(j_e)); %#ok<SAGROW>
end

% Riqueza acumulada de todas las etas comparadas, mismo delta
figure('Position', [100, 100, 950, 550]);
hold on;
colors = lines(numel(results_compare));
for k = 1:numel(results_compare)
    r_k = results_compare{k};
    plot([r_k.dates(1); r_k.dates], r_k.wealth, 'LineWidth', 1.4, ...
        'DisplayName', labels_compare{k}, 'Color', colors(k, :));
end
hold off;
title(sprintf('Riqueza acumulada, \\delta=%.2f -- comparacion de \\eta cerca de cero', DELTA_REF));
xlabel('Fecha'); ylabel('W_t / W_0');
legend('Location', 'best'); grid on;
saveas(gcf, fullfile(OUT_DIR, 'riqueza_comparacion_eta_bajo.png'));

% Retornos: serie de tiempo, boxplot y barras individuales
plot_returns_timeseries(results_compare, labels_compare, ...
    sprintf('Retornos mensuales, \\delta=%.2f', DELTA_REF), OUT_DIR);
plot_returns_boxplot(results_compare, labels_compare, ...
    sprintf('Distribucion de retornos, \\delta=%.2f', DELTA_REF), OUT_DIR);
for k = 1:numel(results_compare)
    plot_returns_bar(results_compare{k}, labels_compare{k}, OUT_DIR);
end

fprintf('\nResultados guardados en la carpeta "%s".\n', OUT_DIR);
