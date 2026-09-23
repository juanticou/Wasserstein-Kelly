%% generate_extra_metrics_test.m
% Vistas adicionales para la evaluacion fuera de muestra ya corrida
% (delta=0.90, eta=0.01 vs. baseline eta=0). NO recalcula nada: carga
% results_prueba_fuera_muestra/test_evaluation.mat (guardado por
% main_test_evaluation.m) y solo genera graficas y metricas nuevas sobre
% esos mismos resultados.
%
% Agrega:
%   - Sharpe, Sortino, Calmar a la tabla comparativa (ya en
%     compute_metrics.m; aqui solo se reconstruye la tabla con ellos)
%   - Drawdown en el tiempo (no solo el maximo)
%   - N efectivo en el tiempo (no solo el promedio)
%   - Evolucion de la composicion del portafolio (elegido y baseline,
%     por separado)
%   - Turnover mes a mes (elegido vs. baseline)
%
% Requiere: haber corrido main_test_evaluation.m, y compute_metrics.m,
% plot_drawdown_series.m, plot_neff_series.m, plot_weights_evolution.m,
% plot_turnover_series.m en el path.

clear; clc; close all;

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};

OUT_DIR = 'results_prueba_fuera_muestra';
mat_path = fullfile(OUT_DIR, 'test_evaluation.mat');

if ~isfile(mat_path)
    error('generate_extra_metrics_test:notFound', ...
        'No se encontro %s. Corre main_test_evaluation.m primero.', mat_path);
end

load(mat_path, 'chosen_val', 'chosen_test', 'base_val', 'base_test', ...
    'CHOSEN_DELTA', 'CHOSEN_ETA');

label_chosen = sprintf('\\delta=%.2f, \\eta=%.2f (elegido)', CHOSEN_DELTA, CHOSEN_ETA);
label_base   = sprintf('\\delta=%.2f, \\eta=0.00 (baseline)', CHOSEN_DELTA);

ALPHA = 0.95;   % mismo alpha usado en toda la corrida

%% 1. Tabla comparativa ampliada, ahora con Sharpe/Sortino/Calmar
m_chosen_val  = compute_metrics(chosen_val,  ALPHA);
m_chosen_test = compute_metrics(chosen_test, ALPHA);
m_base_val    = compute_metrics(base_val,    ALPHA);
m_base_test   = compute_metrics(base_test,   ALPHA);

row1 = metrics_to_row_extended(CHOSEN_DELTA, CHOSEN_ETA, "elegido",  "validacion", m_chosen_val);
row2 = metrics_to_row_extended(CHOSEN_DELTA, CHOSEN_ETA, "elegido",  "prueba",     m_chosen_test);
row3 = metrics_to_row_extended(CHOSEN_DELTA, 0,          "baseline", "validacion", m_base_val);
row4 = metrics_to_row_extended(CHOSEN_DELTA, 0,          "baseline", "prueba",     m_base_test);

comparison_table = [row1; row2; row3; row4];
writetable(comparison_table, fullfile(OUT_DIR, 'tabla_validacion_vs_prueba_extendida.csv'));

fprintf('=== Tabla extendida (incluye Sharpe, Sortino, Calmar) ===\n');
disp(comparison_table(:, {'modelo', 'periodo', 'CAGR', 'max_drawdown', 'sharpe', 'sortino', 'calmar'}));

%% 2. Drawdown en el tiempo, solo periodo de prueba
plot_drawdown_series({chosen_test, base_test}, {label_chosen, label_base}, ...
    'Drawdown en el tiempo, periodo de prueba', OUT_DIR);

%% 3. N efectivo en el tiempo, solo periodo de prueba
plot_neff_series({chosen_test, base_test}, {label_chosen, label_base}, ...
    'N_{eff} en el tiempo, periodo de prueba', OUT_DIR);

%% 4. Evolucion de la composicion del portafolio, elegido y baseline por separado
plot_weights_evolution(chosen_test, TICKERS, ...
    sprintf('Composicion del portafolio -- %s, periodo de prueba', label_chosen), OUT_DIR);

% Se guarda con otro nombre de archivo para no sobreescribir la anterior:
% plot_weights_evolution.m siempre usa el mismo nombre, asi que se corre
% en una subcarpeta separada para el baseline.
BASE_SUBDIR = fullfile(OUT_DIR, 'baseline');
plot_weights_evolution(base_test, TICKERS, ...
    sprintf('Composicion del portafolio -- %s, periodo de prueba', label_base), BASE_SUBDIR);

%% 5. Turnover mes a mes, elegido vs. baseline
plot_turnover_series({chosen_test, base_test}, {label_chosen, label_base}, ...
    'Turnover mensual, periodo de prueba', OUT_DIR);

fprintf('\nGraficas y tabla extendida guardadas en "%s" (composicion del baseline en su subcarpeta "baseline").\n', OUT_DIR);


%% --- Funcion local ---
function row = metrics_to_row_extended(delta_val, eta_val, modelo, periodo, m)
    row = table(delta_val, eta_val, string(modelo), string(periodo), ...
        m.wealth_final, m.CAGR, m.variance_monthly, m.max_drawdown, ...
        m.CVaR_loss, m.sharpe, m.sortino, m.calmar, ...
        m.turnover_total, m.n_rebalances, m.Neff_mean, m.n_months, ...
        'VariableNames', {'delta', 'eta', 'modelo', 'periodo', ...
            'riqueza_final', 'CAGR', 'varianza_mensual', 'max_drawdown', ...
            'CVaR_perdida', 'sharpe', 'sortino', 'calmar', ...
            'turnover_total', 'n_transacciones', 'Neff_promedio', 'n_meses'});
end
