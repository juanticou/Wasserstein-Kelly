%% main_seleccion_parametros.m
% T9, Pasos 2 y 3: aplica select_parameters.m a G1 y G2 por separado,
% usando SOLO las tablas maestras de VALIDACION
% (results_validacion_metricas_v2/) y el ruido medido por
% diagnostico_seleccion.m. No abre ningun .mat ni ningun resultado de
% 2019-2025.
%
% TOL (fijada antes de ver la seleccion): ruido = max de la diferencia
% relativa de riqueza entre celdas equivalentes (1b), sobre ambas
% geometrias y todos los eta; TOL = ruido redondeado hacia arriba al
% siguiente valor {1, 2, 5} x 10^k.
%
% Salidas en results_seleccion/: seleccion_G1.csv, seleccion_G2.csv,
% sensibilidad_seleccion.csv, top10_G1.csv, top10_G2.csv

PROJECT_DIR = fileparts(mfilename('fullpath'));
V_DIR   = fullfile(PROJECT_DIR, 'results_validacion_metricas_v2');
OUT_DIR = fullfile(PROJECT_DIR, 'results_seleccion');

PHI_MIN = 0.95;
DELTA_GRID = [0.50, 0.60, 0.70, 0.75, 0.80, 0.90];
ETA_ELIG   = [0.01, 0.02, 0.03, 0.04, 0.05, 0.10, 0.15, 0.30, 0.50, 1.00];

%% 0. Prueba de la regla con una tabla sintetica
Ts = table([0.5; 0.9; 0.9; 0.7; 0.5], [0; 0.05; 0.01; 0.01; 0.01], ...
    [9; 2.0000; 1.9995; 1.9995; 1.0], [1; 1; 1; 1; 1], ...
    'VariableNames', {'delta', 'eta', 'riqueza_final', 'fraccion_factible'});
s = select_parameters(Ts, PHI_MIN, 5e-4);
assert(s.chosen.delta == 0.9 && s.chosen.eta == 0.01, 'Fallo la prueba sintetica (desempate).');
s = select_parameters(Ts, PHI_MIN, 1e-5);
assert(s.chosen.delta == 0.9 && s.chosen.eta == 0.05, 'Fallo la prueba sintetica (sin empate).');
s = select_parameters(Ts, PHI_MIN, 5e-4, true);
assert(s.chosen.eta == 0, 'Fallo la prueba sintetica (incluyendo eta=0).');
fprintf('Prueba sintetica de la regla: OK\n');

%% 1. TOL a partir del ruido medido (1b)
B = readtable(fullfile(OUT_DIR, 'ruido_celdas_equivalentes.csv'));
B = B(B.usada_para_ruido == 1, :);
if isempty(B)
    error('main_seleccion_parametros:noNoise', 'No hay celdas equivalentes para medir el ruido.');
end
noise = max(B.max_dif_rel_riqueza);
TOL = round_up_125(noise);
fprintf('Ruido maximo entre celdas equivalentes = %.4g -> TOL = %g\n', noise, TOL);

%% 2. Seleccion por geometria
sens = {};
chosen_all = struct();
for geo = ["G1", "G2"]
    T = readtable(fullfile(V_DIR, sprintf('tabla_maestra_validacion_%s.csv', geo)));
    assert(all(T.n_meses == 48), 'La tabla no es de validacion (48 meses).');

    sel = select_parameters(T, PHI_MIN, TOL);
    c = sel.chosen;
    chosen_all.(geo) = c;
    out = sel.tied;
    out.elegida = false(height(out), 1); out.elegida(1) = true;
    out = movevars(out, {'elegida', 'brecha_rel_vs_max'}, 'Before', 1);
    writetable(out, fullfile(OUT_DIR, sprintf('seleccion_%s.csv', geo)));
    fprintf('\n%s: elegida delta=%.2f, eta=%.2f, W=%.6f (%s)\n', geo, c.delta, c.eta, ...
        c.riqueza_final, sel.reason);
    fprintf('    celdas elegibles: %d de %d; empatadas: %d\n', height(sel.eligible), height(T), height(sel.tied));

    % --- Paso 3: sensibilidad (solo se reporta; no cambia la eleccion) ---
    top = sel.eligible(1:min(10, height(sel.eligible)), ...
        {'delta', 'eta', 'riqueza_final', 'CAGR', 'max_drawdown', 'CVaR_perdida', 'sharpe', ...
         'turnover_total', 'costo_monetario', 'proporcion_riesgo_media', 'fraccion_factible'});
    top = addvars(top, (1:height(top))', 'Before', 1, 'NewVariableNames', 'rank');
    top.brecha_rel_vs_max = (sel.W_max - top.riqueza_final) / sel.W_max;
    writetable(top, fullfile(OUT_DIR, sprintf('top10_%s.csv', geo)));

    s0  = select_parameters(T, PHI_MIN, TOL, true);
    s10 = select_parameters(T, PHI_MIN, TOL * 10);
    s01 = select_parameters(T, PHI_MIN, TOL / 10);
    E = sel.eligible;
    [~, ish] = max(E.sharpe);
    [~, icv] = min(E.CVaR_perdida);
    [~, imd] = min(E.max_drawdown);
    rank_chosen = find(E.delta == c.delta & E.eta == c.eta, 1);

    sens = add_row(sens, geo, "regla (eta>0, TOL)", sel.chosen, TOL, rank_chosen, sel.W_max);
    i_rule = numel(sens);
    sens = add_row(sens, geo, "incluyendo eta=0", s0.chosen, TOL, NaN, s0.W_max);
    sens = add_row(sens, geo, "TOL x 10", s10.chosen, TOL * 10, NaN, s10.W_max);
    sens = add_row(sens, geo, "TOL / 10", s01.chosen, TOL / 10, NaN, s01.W_max);
    sens = add_row(sens, geo, "mejor Sharpe (eta>0)", E(ish, :), NaN, ish, sel.W_max);
    sens = add_row(sens, geo, "mejor CVaR (eta>0)", E(icv, :), NaN, icv, sel.W_max);
    sens = add_row(sens, geo, "mejor MDD (eta>0)", E(imd, :), NaN, imd, sel.W_max);

    border_d = c.delta == min(DELTA_GRID) || c.delta == max(DELTA_GRID);
    border_e = c.eta == min(ETA_ELIG) || c.eta == max(ETA_ELIG);
    fprintf('    borde de la malla elegible: delta %d, eta %d\n', border_d, border_e);
    fprintf('    incluyendo eta=0: delta=%.2f, eta=%.2f | TOLx10: delta=%.2f, eta=%.2f | TOL/10: delta=%.2f, eta=%.2f\n', ...
        s0.chosen.delta, s0.chosen.eta, s10.chosen.delta, s10.chosen.eta, s01.chosen.delta, s01.chosen.eta);
    fprintf('    mejor Sharpe: (%.2f, %.2f) | mejor CVaR: (%.2f, %.2f) | mejor MDD: (%.2f, %.2f)\n', ...
        E.delta(ish), E.eta(ish), E.delta(icv), E.eta(icv), E.delta(imd), E.eta(imd));
    sens{i_rule}.borde_delta = border_d;
    sens{i_rule}.borde_eta   = border_e;
end

S = vertcat(sens{:});
writetable(S, fullfile(OUT_DIR, 'sensibilidad_seleccion.csv'));
fprintf('\nTOL=%g, phi_min=%.2f. Salidas en %s\n', TOL, PHI_MIN, OUT_DIR);


function v = round_up_125(x)
% Menor valor de la serie {1, 2, 5} x 10^k que es >= x.
    k = floor(log10(x));
    for m = [1, 2, 5, 10]
        v = m * 10^k;
        if v >= x
            return
        end
    end
end


function sens = add_row(sens, geo, caso, r, tol, rank_val, W_max)
    sens{end + 1} = table(geo, string(caso), r.delta, r.eta, r.riqueza_final, ...
        (W_max - r.riqueza_final) / W_max, r.sharpe, r.CVaR_perdida, r.max_drawdown, tol, rank_val, ...
        false, false, ...
        'VariableNames', {'geometria', 'caso', 'delta', 'eta', 'riqueza_final', ...
        'brecha_rel_vs_max', 'sharpe', 'CVaR_perdida', 'max_drawdown', 'TOL', ...
        'rank_en_riqueza', 'borde_delta', 'borde_eta'});
end
