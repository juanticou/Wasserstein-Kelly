%% main_ret_feasibility_map.m
% Mapa de factibilidad (mu, eps) de la restriccion de retorno esperado
% robusto (Fonseca y Junca, arXiv:2111.04663), calculado SOLO sobre las
% ventanas del periodo de VALIDACION -- para elegir una malla razonable de
% mu y eps antes de correr ningun backtest, de forma analoga al mapa de
% factibilidad (delta, eta). No se resuelve ningun backtest ni se usan
% retornos realizados: solo se evalua, ventana por ventana, el criterio
% v(eps) >= mu del articulo (max_robust_return.m).
%
% Para que el mapa no dependa del camino de cada backtest, se calcula con
% tau = 0 (sin costos de transaccion) y partiendo de todo en el activo de
% bajo riesgo. Los costos reales reducen el retorno alcanzable en un orden
% de tau (0.1%), asi que el mapa es una aproximacion ligeramente optimista
% de la frontera -- el backtest reporta la factibilidad real fecha por fecha.
%
% UBICACION: Wasserstein-Kelly/wdro-return/ (mismo patron que wdro-market y
% wdro-hypercube); lo compartido (load_monthly_data.m, compute_*.m,
% plot_heatmap.m, ...) se queda en Wasserstein-Kelly/ raiz.
%
% Requiere: CVX + MOSEK.

clear; clc; close all;

%% 1. Configuracion y path
PROJECT_DIR = fileparts(mfilename('fullpath'));   % .../Wasserstein-Kelly/wdro-return
ROOT_DIR    = fileparts(PROJECT_DIR);              % .../Wasserstein-Kelly
addpath(PROJECT_DIR);
addpath(ROOT_DIR);

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
CSV_PATH = fullfile(ROOT_DIR, 'data', 'processed', 'monthly_panel.csv');
if ~isfile(CSV_PATH)
    error('main_ret_feasibility_map:csvNotFound', ...
        'No se encontro %s. data/ debe estar en Wasserstein-Kelly (raiz).', CSV_PATH);
end

N     = 60;
xbar  = 0.25;
gamma = 1;
delta = 0.90;        % mismo delta que el modelo elegido
solver = 'mosek';

EPS_MAP = [0, 0.0025, 0.005, 0.01, 0.015, 0.02, 0.03];          % radios a evaluar
MU_MAP  = [0.002, 0.004, 0.006, 0.008, 0.010, 0.012, 0.015];    % retornos minimos mensuales

OUT_DIR = fullfile(PROJECT_DIR, 'results_ret_mapa_factibilidad');
if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end

%% 2. Datos: SOLO hasta el fin de la validacion
data = load_monthly_data(CSV_PATH, TICKERS);
VALIDATION_START = max(datetime(2015,1,1), min(data.dates));
VALIDATION_END   = datetime(2018,12,31);
data_val = truncate_data(data, VALIDATION_END);

T = size(data_val.R, 1);
dec_idx = N:(T - 1);
realized = dateshift(data_val.dates(dec_idx), 'end', 'month', 1);
dec_idx = dec_idx(realized >= VALIDATION_START);     % decisiones cuyo retorno cae en validacion
nDec = numel(dec_idx);
fprintf('Ventanas de validacion a evaluar: %d (decisiones %s a %s).\n', nDec, ...
    datestr(data_val.dates(dec_idx(1)), 'mmm-yyyy'), datestr(data_val.dates(dec_idx(end)), 'mmm-yyyy'));

%% 3. v(eps) para cada ventana y cada eps
d = size(data_val.R, 2);
h_cash = [1; zeros(d, 1)];
V = nan(nDec, numel(EPS_MAP));
tic;
for a = 1:nDec
    k = dec_idx(a);
    Rk = data_val.R(k - N + 1 : k, :);
    rf_k = data_val.rf_return(k);
    for j = 1:numel(EPS_MAP)
        V(a, j) = max_robust_return(h_cash, Rk, rf_k, 0, xbar, gamma, delta, EPS_MAP(j), solver);
    end
end
fprintf('Listo en %.1f s.\n', toc);

%% 4. Fraccion de ventanas factibles para cada (mu, eps): criterio v(eps) >= mu
F = nan(numel(MU_MAP), numel(EPS_MAP));
for i = 1:numel(MU_MAP)
    for j = 1:numel(EPS_MAP)
        F(i, j) = mean(V(:, j) >= MU_MAP(i), 'omitnan');
    end
end

plot_heatmap(F, EPS_MAP, MU_MAP, ...
    'Fraccion de ventanas factibles (validacion): v(\epsilon) >= \mu', ...
    'Fraccion de ventanas', '%.2f', OUT_DIR, 'heatmap_factibilidad_mu_eps.png', ...
    '\epsilon', '\mu (mensual)');

eps_names = arrayfun(@(v) matlab.lang.makeValidName(sprintf('eps_%g', v)), EPS_MAP, 'UniformOutput', false);
Ftab = addvars(array2table(F, 'VariableNames', eps_names), MU_MAP(:), 'Before', 1, 'NewVariableNames', 'mu');
writetable(Ftab, fullfile(OUT_DIR, 'mapa_factibilidad_mu_eps.csv'));

%% 5. mu_max por ventana (v(0)): para elegir mu con criterio
mu_max_series = V(:, 1);
figure('Position', [100, 100, 950, 450]);
plot(data_val.dates(dec_idx), 100 * mu_max_series, 'LineWidth', 1.4); hold on;
yline(100 * median(mu_max_series, 'omitnan'), 'k--', 'mediana');
plot(data_val.dates(dec_idx), 100 * data_val.rf_return(dec_idx), 'LineWidth', 1.0);
hold off; grid on;
legend({'\mu_{max} de la ventana', 'mediana de \mu_{max}', 'r^f_k'}, 'Location', 'best');
xlabel('Fecha de decision'); ylabel('Retorno mensual (%)');
title('Retorno esperado maximo alcanzable por ventana (validacion), \epsilon = 0');
saveas(gcf, fullfile(OUT_DIR, 'mu_max_por_ventana.png'));

fprintf('\n=== mu_max (retorno mensual maximo alcanzable, eps=0) en validacion ===\n');
fprintf('  min = %.3f%% | mediana = %.3f%% | max = %.3f%%\n', ...
    100*min(mu_max_series), 100*median(mu_max_series), 100*max(mu_max_series));
fprintf('Un mu fijo por ENCIMA del minimo de mu_max sera infactible en algunas fechas (fallback: no rebalancear).\n');
fprintf('Resultados en "%s".\n', OUT_DIR);
