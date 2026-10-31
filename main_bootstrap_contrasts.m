%% main_bootstrap_contrasts.m
% T6: bootstrap movil por bloques (bootstrap_block_diff.m) de la media de
% D_k = log G^A - log G^B en el periodo de PRUEBA (2019-2025, 84 meses),
% usando SOLO resultados ya existentes (sin reelegir parametros):
%   - G2: results_prueba_v2/g2_trayectorias_completas.mat
%   - G1: results_eta_delta_grid_wdro/grid_delta_eta.mat
%   - nominal: results_verificaciones/nominal_backtests.mat
% Las series se recortan con extract_period_results.m (sin reiniciar
% posiciones), igual que en main_test_evaluation_v2.m.
%
% Contrastes (i) G1 vs nominal, (ii) G2 vs G1, (iii) G2 vs nominal:
%   - emparejados en (0.90, 0.01) y en (0.80, 0.01)
%   - con las configuraciones seleccionadas (G1: 0.90/0.01, G2: 0.80/0.01);
%     el nominal se toma con el mismo delta de la estrategia WK
% ell = 6 (regla a priori) y sensibilidad con ell = 3 y 12; B = 10000;
% semilla fija.
%
% Salidas: results_bootstrap/tabla_bootstrap_contrastes.csv

PROJECT_DIR = fileparts(mfilename('fullpath'));
cfg = config_rutas();   % rutas de datos y resultados (WK_PANEL, WK_RESULTS_ROOT)
RES = cfg.results_root;
OUT_DIR = fullfile(RES, 'results_bootstrap');
preparar_salida(cfg, OUT_DIR);
TEST_START = datetime(2019,1,1);
TEST_END   = datetime(2025,12,31);
ELLS = [6, 3, 12];
B    = 10000;
SEED = 20261019;

%% Series de prueba
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

keys_s = series.keys;
ref_dates = series(keys_s{1}).dates;
for q = 1:numel(keys_s)
    s = series(keys_s{q});
    assert(isequal(s.dates, ref_dates) && numel(s.dates) == 84, 'Series de prueba no alineadas.');
end

%% Contrastes
C = { ...
    'emparejado (0.90, 0.01)', '(i) G1 vs nominal',  'G1 (0.90, 0.01)', 'Nominal (0.90)'; ...
    'emparejado (0.90, 0.01)', '(ii) G2 vs G1',      'G2 (0.90, 0.01)', 'G1 (0.90, 0.01)'; ...
    'emparejado (0.90, 0.01)', '(iii) G2 vs nominal','G2 (0.90, 0.01)', 'Nominal (0.90)'; ...
    'emparejado (0.80, 0.01)', '(i) G1 vs nominal',  'G1 (0.80, 0.01)', 'Nominal (0.80)'; ...
    'emparejado (0.80, 0.01)', '(ii) G2 vs G1',      'G2 (0.80, 0.01)', 'G1 (0.80, 0.01)'; ...
    'emparejado (0.80, 0.01)', '(iii) G2 vs nominal','G2 (0.80, 0.01)', 'Nominal (0.80)'; ...
    'seleccionado',            '(i) G1 vs nominal',  'G1 (0.90, 0.01)', 'Nominal (0.90)'; ...
    'seleccionado',            '(ii) G2 vs G1',      'G2 (0.80, 0.01)', 'G1 (0.90, 0.01)'; ...
    'seleccionado',            '(iii) G2 vs nominal','G2 (0.80, 0.01)', 'Nominal (0.80)'};

rows = {};
for c = 1:size(C, 1)
    a = series(C{c, 3}); b = series(C{c, 4});
    for ell = ELLS
        o = bootstrap_block_diff(a.growth_real, b.growth_real, ell, B, SEED);
        rows{end + 1} = table(string(C{c, 1}), string(C{c, 2}), string(C{c, 3}), string(C{c, 4}), ...
            ell, o.n, o.mean_D, o.ci_lo, o.ci_hi, o.boot_se, o.median_D, o.prop_D_pos, o.n_ties, ...
            12 * o.mean_D, o.ci_lo > 0 || o.ci_hi < 0, B, SEED, ...
            'VariableNames', {'tipo', 'contraste', 'A', 'B', 'ell', 'n_meses', 'media_D', ...
            'IC95_inf', 'IC95_sup', 'ee_bootstrap', 'mediana_D', 'prop_D_pos', ...
            'meses_empate_1e6', 'media_D_anualizada', 'IC_excluye_cero', 'B_replicas', 'semilla'}); %#ok<SAGROW>
    end
end
TB = vertcat(rows{:});
writetable(TB, fullfile(OUT_DIR, 'tabla_bootstrap_contrastes.csv'));

disp(TB(:, {'tipo', 'contraste', 'ell', 'media_D', 'IC95_inf', 'IC95_sup', 'mediana_D', ...
    'prop_D_pos', 'IC_excluye_cero'}));
fprintf('B=%d, semilla=%d. Salida en %s\n', B, SEED, OUT_DIR);
