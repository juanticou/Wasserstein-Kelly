%% test_bootstrap_block_diff.m
% Prueba de bootstrap_block_diff.m con datos SIMULADOS de media conocida,
% antes de usarlo con los resultados reales:
%   1. Casos deterministas: D constante => IC degenerado en ese valor;
%      misma semilla => mismo resultado; alineacion del par (A y B
%      desplazados en un mes NO deben dar el mismo D).
%   2. Cobertura: D_k = mu + e_k con e_k AR(1) (phi = 0.3), T = 84 (como
%      la prueba), mu conocida. Se simulan N_SIM muestras y se cuenta en
%      cuantas el IC del 95 % contiene mu, para ell = 3, 6 y 12.
%      Se usa B = 2000 por replica para que la prueba sea rapida.
%
% Salida: results_bootstrap/test_simulado.csv

PROJECT_DIR = fileparts(mfilename('fullpath'));
cfg = config_rutas();   % rutas de datos y resultados (WK_PANEL, WK_RESULTS_ROOT)
RES = cfg.results_root;
OUT_DIR = fullfile(RES, 'results_bootstrap');
preparar_salida(cfg, OUT_DIR);

%% 1. Casos deterministas
T = 84;
GB = exp(0.01 * ones(T, 1));
GA = GB * exp(0.002);
o = bootstrap_block_diff(GA, GB, 6, 1000);
assert(abs(o.mean_D - 0.002) < 1e-12 && abs(o.ci_lo - 0.002) < 1e-12 && abs(o.ci_hi - 0.002) < 1e-12, ...
    'D constante: el IC deberia colapsar en 0.002.');
% Alineacion del par: GB muy volatil y GA = GB * exp(0.002). Si A y B se
% remuestrean con los mismos meses, D sigue siendo constante y el IC
% colapsa; si se remuestrearan por separado, el IC seria ancho.
rng(1, 'twister');
GB2 = exp(0.01 + 0.08 * randn(T, 1));
o = bootstrap_block_diff(GB2 * exp(0.002), GB2, 6, 1000);
assert(o.ci_hi - o.ci_lo < 1e-12, 'El par (A,B) no se remuestreo alineado.');
% Reproducibilidad: misma semilla => mismas replicas.
GA3 = GB2 .* exp(0.002 + 0.01 * randn(T, 1));
assert(isequal(bootstrap_block_diff(GA3, GB2, 6, 500, 7).boot_means, ...
               bootstrap_block_diff(GA3, GB2, 6, 500, 7).boot_means), ...
    'La misma semilla debe dar el mismo resultado.');
fprintf('Casos deterministas: OK\n');

%% 2. Cobertura con media conocida
MU = 0.002; SIGMA = 0.01; PHI = 0.3;
N_SIM = 500; B_SIM = 2000;
rng(20261019, 'twister');
ells = [3, 6, 12];
cover = zeros(N_SIM, numel(ells)); width = cover; mean_hat = zeros(N_SIM, 1);
for s = 1:N_SIM
    e = zeros(T, 1);
    e(1) = SIGMA / sqrt(1 - PHI^2) * randn;
    for t = 2:T
        e(t) = PHI * e(t - 1) + SIGMA * randn;
    end
    D = MU + e;
    GBs = exp(0.01 + 0.04 * randn(T, 1));   % crecimiento base arbitrario
    GAs = GBs .* exp(D);
    mean_hat(s) = mean(D);
    for q = 1:numel(ells)
        o = bootstrap_block_diff(GAs, GBs, ells(q), B_SIM, 1000 + s);
        cover(s, q) = (o.ci_lo <= MU) && (MU <= o.ci_hi);
        width(s, q) = o.ci_hi - o.ci_lo;
    end
end
R = table(ells', mean(cover)', mean(width)', repmat(mean(mean_hat), 3, 1), repmat(MU, 3, 1), ...
    repmat(N_SIM, 3, 1), repmat(B_SIM, 3, 1), repmat(PHI, 3, 1), ...
    'VariableNames', {'ell', 'cobertura_IC95', 'ancho_medio_IC', 'media_estimada_promedio', ...
    'mu_verdadera', 'n_simulaciones', 'B_por_simulacion', 'phi_AR1'});
writetable(R, fullfile(OUT_DIR, 'test_simulado.csv'));
disp(R);
fprintf('Sesgo de la media muestral: %.2e (mu = %.4f)\n', mean(mean_hat) - MU, MU);
