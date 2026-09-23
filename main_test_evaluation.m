%% main_test_evaluation.m
% Evaluacion fuera de muestra HONESTA (Seccion 17.3 de la propuesta) de
% UNA UNICA combinacion (delta, eta) ya elegida a partir del periodo de
% validacion -- no se vuelve a barrer ninguna malla sobre el periodo de
% prueba, y no se resuelve ningun backtest nuevo: todo se reconstruye
% desde grid_delta_eta.mat con extract_period_results.m.
%
% Combinacion elegida (edita aqui si cambias de idea):
%   delta = 0.90, eta = 0.01
%
% Compara esa combinacion contra el baseline eta=0 (equivalente al
% nominal) en el MISMO delta, y contra su propio desempeno en el periodo
% de validacion -- para responder la pregunta real: "lo que parecia bueno
% en validacion, se sostuvo en datos que nunca se usaron para elegir
% nada?"
%
% Requiere: haber corrido main_grid_delta_eta.m (o tener su .mat), y
% extract_period_results.m, compute_metrics.m, plot_returns_*.m en el path.

clear; clc; close all;

%% 1. Configuracion
CHOSEN_DELTA = 0.90;
CHOSEN_ETA   = 0.01;

GRID_DIR = 'results_eta_delta_grid_wdro';
mat_path = fullfile(GRID_DIR, 'grid_delta_eta.mat');

if ~isfile(mat_path)
    error('main_test_evaluation:notFound', ...
        ['No se encontro %s. Corre main_grid_delta_eta.m primero (o al ', ...
         'menos hasta el paso 5, el guardado del grid).'], mat_path);
end

load(mat_path, 'grid');
DELTA_GRID = grid.delta_grid;
ETA_GRID   = grid.eta_grid;
ALPHA      = grid.alpha;

OUT_DIR = 'results_prueba_fuera_muestra';
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

%% 2. Localizar la combinacion elegida y el baseline en la malla guardada
i_sel = find(DELTA_GRID == CHOSEN_DELTA, 1);
j_sel = find(ETA_GRID == CHOSEN_ETA, 1);
j_base = grid.baseline_col;

if isempty(i_sel) || isempty(j_sel)
    error('main_test_evaluation:comboNotFound', ...
        'delta=%.4f, eta=%.4f no esta en la malla guardada. Valores disponibles: delta=%s, eta=%s.', ...
        CHOSEN_DELTA, CHOSEN_ETA, mat2str(DELTA_GRID), mat2str(ETA_GRID));
end
if isempty(j_base)
    error('main_test_evaluation:noBaseline', 'La malla guardada no tiene columna eta=0 (baseline).');
end

r_chosen_full = grid.results_wdro{i_sel, j_sel};
r_base_full   = grid.results_wdro{i_sel, j_base};
if isempty(r_chosen_full) || isempty(r_base_full)
    error('main_test_evaluation:emptyResults', ...
        'La combinacion elegida o el baseline no tienen resultados guardados en esta malla.');
end

fprintf('Combinacion elegida: delta=%.2f, eta=%.2f\n', CHOSEN_DELTA, CHOSEN_ETA);
fprintf('Baseline de comparacion: delta=%.2f, eta=%.2f (equivalente al nominal)\n', ...
    CHOSEN_DELTA, ETA_GRID(j_base));

%% 3. Rango de fechas y particion validacion / prueba (misma logica que main_validation_grid.m)
realized_dates_full = dateshift(r_chosen_full.dates, 'end', 'month', 1);
DATA_START = min(realized_dates_full);
DATA_END   = max(realized_dates_full);

VALIDATION_START = max(datetime(2015,1,1), DATA_START);
VALIDATION_END   = min(datetime(2018,12,31), DATA_END);
TEST_START = max(datetime(2019,1,1), VALIDATION_END + caldays(1));
TEST_END   = min(datetime(2025,12,31), DATA_END);

fprintf('\nRango de datos: %s a %s.\n', datestr(DATA_START), datestr(DATA_END));
fprintf('Validacion: %s a %s.\n', datestr(VALIDATION_START), datestr(VALIDATION_END));
fprintf('Prueba (fuera de muestra): %s a %s.\n', datestr(TEST_START), datestr(TEST_END));

if TEST_START > TEST_END
    error('main_test_evaluation:noTestPeriod', ...
        'No queda periodo de prueba util con los datos disponibles (revisa el rango de tu descarga).');
end

%% 4. Extraer los 4 sub-periodos necesarios (sin resolver nada nuevo)
chosen_val  = extract_period_results(r_chosen_full, VALIDATION_START, VALIDATION_END);
chosen_test = extract_period_results(r_chosen_full, TEST_START, TEST_END);
base_val    = extract_period_results(r_base_full,   VALIDATION_START, VALIDATION_END);
base_test   = extract_period_results(r_base_full,   TEST_START, TEST_END);

m_chosen_val  = compute_metrics(chosen_val,  ALPHA);
m_chosen_test = compute_metrics(chosen_test, ALPHA);
m_base_val    = compute_metrics(base_val,    ALPHA);
m_base_test   = compute_metrics(base_test,   ALPHA);

%% 5. Tabla comparativa: 4 filas (elegido/baseline x validacion/prueba)
row1 = metrics_to_row(CHOSEN_DELTA, CHOSEN_ETA, "elegido",  "validacion", false, m_chosen_val);
row2 = metrics_to_row(CHOSEN_DELTA, CHOSEN_ETA, "elegido",  "prueba",     false, m_chosen_test);
row3 = metrics_to_row(CHOSEN_DELTA, ETA_GRID(j_base), "baseline", "validacion", true, m_base_val);
row4 = metrics_to_row(CHOSEN_DELTA, ETA_GRID(j_base), "baseline", "prueba",     true, m_base_test);

comparison_table = [row1; row2; row3; row4];
writetable(comparison_table, fullfile(OUT_DIR, 'tabla_validacion_vs_prueba.csv'));

fprintf('\n=== Tabla comparativa: elegido vs. baseline, validacion vs. prueba ===\n');
disp(comparison_table(:, {'modelo', 'periodo', 'riqueza_final', 'CAGR', 'max_drawdown', ...
    'varianza_mensual', 'CVaR_perdida', 'turnover_total', 'n_transacciones'}));

%% 6. Resumen de "sostenibilidad": que tanto cambio el desempeno de
% validacion a prueba, para la combinacion elegida y para el baseline.
fprintf('\n=== Cambio validacion -> prueba (positivo = mejoro, negativo = empeoro) ===\n');
fprintf('Elegido  (delta=%.2f, eta=%.2f): CAGR %.2f%% -> %.2f%% (%+.2f pp) | MDD %.2f%% -> %.2f%% (%+.2f pp)\n', ...
    CHOSEN_DELTA, CHOSEN_ETA, 100*m_chosen_val.CAGR, 100*m_chosen_test.CAGR, ...
    100*(m_chosen_test.CAGR - m_chosen_val.CAGR), ...
    100*m_chosen_val.max_drawdown, 100*m_chosen_test.max_drawdown, ...
    100*(m_chosen_test.max_drawdown - m_chosen_val.max_drawdown));
fprintf('Baseline (delta=%.2f, eta=%.2f): CAGR %.2f%% -> %.2f%% (%+.2f pp) | MDD %.2f%% -> %.2f%% (%+.2f pp)\n', ...
    CHOSEN_DELTA, ETA_GRID(j_base), 100*m_base_val.CAGR, 100*m_base_test.CAGR, ...
    100*(m_base_test.CAGR - m_base_val.CAGR), ...
    100*m_base_val.max_drawdown, 100*m_base_test.max_drawdown, ...
    100*(m_base_test.max_drawdown - m_base_val.max_drawdown));

fprintf('\n=== Elegido vs. baseline, SOLO en el periodo de prueba (el numero que realmente importa) ===\n');
fprintf('CAGR: %.2f%% (elegido) vs %.2f%% (baseline)  [%+.2f pp]\n', ...
    100*m_chosen_test.CAGR, 100*m_base_test.CAGR, 100*(m_chosen_test.CAGR - m_base_test.CAGR));
fprintf('MDD:  %.2f%% (elegido) vs %.2f%% (baseline)  [%+.2f pp, negativo = elegido mejor]\n', ...
    100*m_chosen_test.max_drawdown, 100*m_base_test.max_drawdown, ...
    100*(m_chosen_test.max_drawdown - m_base_test.max_drawdown));
fprintf('CVaR: %.2f%% (elegido) vs %.2f%% (baseline)  [%+.2f pp, negativo = elegido mejor]\n', ...
    100*m_chosen_test.CVaR_loss, 100*m_base_test.CVaR_loss, ...
    100*(m_chosen_test.CVaR_loss - m_base_test.CVaR_loss));

%% 7. Guardar todo
save(fullfile(OUT_DIR, 'test_evaluation.mat'), ...
    'chosen_val', 'chosen_test', 'base_val', 'base_test', ...
    'm_chosen_val', 'm_chosen_test', 'm_base_val', 'm_base_test', ...
    'CHOSEN_DELTA', 'CHOSEN_ETA', 'VALIDATION_START', 'VALIDATION_END', 'TEST_START', 'TEST_END');

%% 8. Grafica de riqueza CONTINUA (validacion + prueba), con la frontera marcada
label_chosen = sprintf('\\delta=%.2f, \\eta=%.2f (elegido)', CHOSEN_DELTA, CHOSEN_ETA);
label_base   = sprintf('\\delta=%.2f, \\eta=%.2f (baseline)', CHOSEN_DELTA, ETA_GRID(j_base));

figure('Position', [100, 100, 1000, 600]);
hold on;
plot([r_chosen_full.dates(1); r_chosen_full.dates], r_chosen_full.wealth, ...
    'LineWidth', 1.6, 'DisplayName', label_chosen);
plot([r_base_full.dates(1); r_base_full.dates], r_base_full.wealth, ...
    'LineWidth', 1.6, 'DisplayName', label_base);
yl = ylim;
xline(TEST_START, '--k', 'Inicio de prueba', 'LabelVerticalAlignment', 'bottom', ...
    'HandleVisibility', 'off');
hold off;
title('Riqueza acumulada completa -- linea punteada marca el inicio del periodo de prueba');
xlabel('Fecha'); ylabel('W_t / W_0');
legend('Location', 'best'); grid on;
saveas(gcf, fullfile(OUT_DIR, 'riqueza_completa_con_frontera.png'));

%% 9. Grafica de riqueza SOLO del periodo de prueba (re-basada a 1)
figure('Position', [100, 100, 1000, 600]);
hold on;
plot([chosen_test.dates(1); chosen_test.dates], chosen_test.wealth, ...
    'LineWidth', 1.8, 'DisplayName', label_chosen);
plot([base_test.dates(1); base_test.dates], base_test.wealth, ...
    'LineWidth', 1.8, 'DisplayName', label_base);
hold off;
title(sprintf('Riqueza acumulada, SOLO periodo de prueba (%s a %s)', ...
    datestr(TEST_START, 'mmm-yyyy'), datestr(TEST_END, 'mmm-yyyy')));
xlabel('Fecha'); ylabel('W_t / W_0 (re-basada a 1 al inicio de la prueba)');
legend('Location', 'best'); grid on;
saveas(gcf, fullfile(OUT_DIR, 'riqueza_solo_prueba.png'));

%% 10. Graficas de retornos, SOLO periodo de prueba
try
    plot_returns_timeseries({chosen_test, base_test}, {label_chosen, label_base}, ...
        'Retornos mensuales, periodo de prueba', OUT_DIR);
catch ME
    warning('main_test_evaluation:returnsTimeseriesFailed', '%s', ME.message);
end
try
    plot_returns_boxplot({chosen_test, base_test}, {label_chosen, label_base}, ...
        'Distribucion de retornos, periodo de prueba', OUT_DIR);
catch ME
    warning('main_test_evaluation:returnsBoxplotFailed', ...
        'Revisa si tienes el Statistics Toolbox: %s', ME.message);
end
try
    plot_returns_bar(chosen_test, [label_chosen, ' (prueba)'], OUT_DIR);
    plot_returns_bar(base_test, [label_base, ' (prueba)'], OUT_DIR);
catch ME
    warning('main_test_evaluation:returnsBarFailed', '%s', ME.message);
end

fprintf('\nResultados guardados en la carpeta "%s".\n', OUT_DIR);


%% --- Funcion local ---
function row = metrics_to_row(delta_val, eta_val, modelo, periodo, is_baseline, m)
    row = table(delta_val, eta_val, string(modelo), string(periodo), is_baseline, ...
        m.wealth_final, m.log_growth_mean, m.CAGR, m.variance_monthly, ...
        m.max_drawdown, m.worst_month, m.VaR_loss, m.CVaR_loss, ...
        m.turnover_total, m.n_rebalances, m.cost_total, ...
        m.max_weight_mean, m.Neff_mean, m.n_violations_delta, m.n_months, ...
        'VariableNames', {'delta', 'eta', 'modelo', 'periodo', 'es_baseline', ...
            'riqueza_final', 'log_crecimiento_medio', 'CAGR', 'varianza_mensual', ...
            'max_drawdown', 'peor_mes', 'VaR_perdida', 'CVaR_perdida', ...
            'turnover_total', 'n_transacciones', 'costo_total', ...
            'peso_max_promedio', 'Neff_promedio', 'violaciones_delta', 'n_meses'});
end
