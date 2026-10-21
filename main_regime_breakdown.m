%% main_regime_breakdown.m
% T7: desglose DESCRIPTIVO por regimen de las diferencias D_k del periodo
% de PRUEBA (2019-2025, 84 meses), con las mismas series y contrastes que
% main_bootstrap_contrasts.m (T6). No se elige ni se ajusta nada.
%
% Cada mes realizado k+1 se clasifica SOLO con informacion disponible en
% la fecha de decision k (umbrales fijados a priori, sin mirar la prueba):
%   - VIX: "alto" si VIX_k > mediana del VIX de la ventana D_k (los N=60
%     meses que terminan en k, los mismos de la decision); "bajo" si <=.
%   - SPY: "negativo" si el retorno de SPY en k es < 0; "no negativo" si >= 0.
% Se reportan, por regimen, el numero de meses, la media de D_k, la
% proporcion de meses con D_k > 0 y los empates numericos (|D_k| < 1e-6).
% Tambien el cruce 2x2 VIX x SPY.
%
% Salidas: results_regimen/

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
cfg = config_rutas();   % rutas de datos y resultados (WK_PANEL, WK_RESULTS_ROOT)
RES = cfg.results_root;
CSV_PATH = cfg.panel;
OUT_DIR  = fullfile(RES, 'results_regimen');
preparar_salida(cfg, OUT_DIR);
TEST_START = datetime(2019,1,1);
TEST_END   = datetime(2025,12,31);
N_WINDOW   = 60;
TIE_TOL    = 1e-6;

data = load_monthly_data(CSV_PATH, TICKERS);

%% Series de prueba (mismas fuentes que T6)
S = load(fullfile(RES, 'results_prueba_v2', 'g2_trayectorias_completas.mat'), 'res');
G = load(fullfile(RES, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'), 'grid');
N = load(fullfile(RES, 'results_verificaciones', 'nominal_backtests.mat'), ...
    'nominal_results', 'DELTAS_TO_RUN');
g1 = G.grid;
cell_g1 = @(delta, eta) g1.results_wdro{abs(g1.delta_grid - delta) < 1e-12, abs(g1.eta_grid - eta) < 1e-12};
cut = @(r) extract_period_results(r, TEST_START, TEST_END);

series = containers.Map();
series('G1 (0.90, 0.01)') = cut(cell_g1(0.90, 0.01));
series('G1 (0.80, 0.01)') = cut(cell_g1(0.80, 0.01));
for m = 1:numel(S.res)
    series(S.res(m).name) = cut(S.res(m).r);
end
for delta = [0.90, 0.80]
    k = find(abs(N.DELTAS_TO_RUN - delta) < 1e-12, 1);
    series(sprintf('Nominal (%.2f)', delta)) = cut(N.nominal_results{k});
end
clear S G N g1

%% Clasificacion de cada mes con informacion de la fecha de decision k
realized = series('G1 (0.90, 0.01)').dates;
decision = dateshift(realized, 'end', 'month', -1);
[tf, kk] = ismember(decision, data.dates);
assert(all(tf) && numel(kk) == 84);

vix_k   = data.vix(kk);
vix_med = arrayfun(@(k) median(data.vix(k - N_WINDOW + 1 : k)), kk);
spy_k   = data.mkt_return(kk);
vix_high = vix_k > vix_med;
spy_neg  = spy_k < 0;

R = table(decision, realized, vix_k, vix_med, vix_high, spy_k, spy_neg, ...
    'VariableNames', {'fecha_decision_k', 'mes_realizado_k1', 'VIX_k', 'mediana_VIX_ventana', ...
    'VIX_alto', 'retorno_SPY_k', 'SPY_negativo'});
writetable(R, fullfile(OUT_DIR, 'clasificacion_meses.csv'));
fprintf('Meses de prueba: %d | VIX alto: %d | SPY negativo en k: %d | ambos: %d\n', ...
    numel(kk), sum(vix_high), sum(spy_neg), sum(vix_high & spy_neg));

%% Contrastes (los mismos de T6)
C = { ...
    'emparejado (0.90, 0.01)', '(i) G1 vs nominal',  'G1 (0.90, 0.01)', 'Nominal (0.90)'; ...
    'emparejado (0.90, 0.01)', '(ii) G2 vs G1',      'G2 (0.90, 0.01)', 'G1 (0.90, 0.01)'; ...
    'emparejado (0.90, 0.01)', '(iii) G2 vs nominal','G2 (0.90, 0.01)', 'Nominal (0.90)'; ...
    'emparejado (0.80, 0.01)', '(i) G1 vs nominal',  'G1 (0.80, 0.01)', 'Nominal (0.80)'; ...
    'emparejado (0.80, 0.01)', '(ii) G2 vs G1',      'G2 (0.80, 0.01)', 'G1 (0.80, 0.01)'; ...
    'emparejado (0.80, 0.01)', '(iii) G2 vs nominal','G2 (0.80, 0.01)', 'Nominal (0.80)'; ...
    'seleccionado',            '(ii) G2 vs G1',      'G2 (0.80, 0.01)', 'G1 (0.90, 0.01)'};
% (i) y (iii) seleccionados coinciden con los emparejados (mismo delta del nominal).

regimes = { ...
    'todos',                  true(84, 1); ...
    'VIX alto',               vix_high; ...
    'VIX bajo',               ~vix_high; ...
    'SPY_k negativo',         spy_neg; ...
    'SPY_k no negativo',      ~spy_neg; ...
    'VIX alto y SPY_k neg.',  vix_high & spy_neg; ...
    'VIX alto y SPY_k >= 0',  vix_high & ~spy_neg; ...
    'VIX bajo y SPY_k neg.',  ~vix_high & spy_neg; ...
    'VIX bajo y SPY_k >= 0',  ~vix_high & ~spy_neg};

rows = {};
for c = 1:size(C, 1)
    a = series(C{c, 3}); b = series(C{c, 4});
    assert(isequal(a.dates, realized) && isequal(b.dates, realized));
    D = log(a.growth_real) - log(b.growth_real);
    for g = 1:size(regimes, 1)
        msk = regimes{g, 2};
        Dg = D(msk);
        if isempty(Dg)
            stats = [NaN, NaN, NaN, NaN];
        else
            stats = [mean(Dg), median(Dg), mean(Dg > 0), sum(abs(Dg) < TIE_TOL)];
        end
        rows{end + 1} = table(string(C{c, 1}), string(C{c, 2}), string(C{c, 3}), string(C{c, 4}), ...
            string(regimes{g, 1}), sum(msk), stats(1), stats(2), stats(3), stats(4), ...
            sum(Dg(abs(Dg) >= TIE_TOL) > 0) / max(1, sum(abs(Dg) >= TIE_TOL)), sum(Dg), ...
            'VariableNames', {'tipo', 'contraste', 'A', 'B', 'regimen', 'n_meses', 'media_D', ...
            'mediana_D', 'prop_D_pos', 'empates_1e6', 'prop_D_pos_sin_empates', 'suma_D'}); %#ok<SAGROW>
    end
end
TR = vertcat(rows{:});
writetable(TR, fullfile(OUT_DIR, 'desglose_regimen.csv'));

main_reg = ismember(TR.regimen, ["todos", "VIX alto", "VIX bajo", "SPY_k negativo", "SPY_k no negativo"]);
disp(TR(main_reg, {'tipo', 'contraste', 'regimen', 'n_meses', 'media_D', 'prop_D_pos', ...
    'empates_1e6', 'prop_D_pos_sin_empates', 'suma_D'}));
fprintf('Salidas en %s\n', OUT_DIR);
