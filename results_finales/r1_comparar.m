function r1_comparar(etapa)
% R1_COMPARAR  R1, paso 4: compara results_v2/ (cierre del 31-dic-2025,
% panel hibrido) con los resultados de la linea base (cierre del 30-dic).
%   etapa = 'mallas' : trayectorias de G1, G2 y el nominal, y la seleccion de T9
%   etapa = 'prueba' : riqueza final y metricas de prueba, bootstrap y regimen
% Exigencias: hasta nov-2025 (todas las decisiones y los factores realizados
% salvo el ultimo) |dif| <= 1e-6, y la seleccion de T9 identica.
% Salidas en results_finales/r1_comparacion_<etapa>.csv

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    old = root;
    new = fullfile(root, 'results_v2');
    TOL = 1e-6;
    out = fullfile(root, 'results_finales', sprintf('r1_comparacion_%s.csv', etapa));

    switch etapa
        case 'mallas'
            rows = {};
            f = fullfile('results_eta_delta_grid_wdro', 'grid_delta_eta.mat');
            rows = [rows, comparar_malla(fullfile(old, f), fullfile(new, f), "G1 malla completa", TOL)];
            f = fullfile('wdro-market', 'results_validacion_grid_market', 'grid_delta_eta_market_validacion.mat');
            rows = [rows, comparar_malla(fullfile(old, f), fullfile(new, f), "G2 malla validacion", TOL)];
            f = fullfile('results_verificaciones', 'nominal_backtests.mat');
            A = load(fullfile(old, f)); B = load(fullfile(new, f));
            for m = 1:numel(A.nominal_results)
                rows{end + 1} = comparar_tray(A.nominal_results{m}, B.nominal_results{m}, ...
                    "nominal", A.DELTAS_TO_RUN(m), 0, TOL); %#ok<AGROW>
            end
            T = vertcat(rows{:});
            writetable(T, out);
            fprintf('Trayectorias: %d | todas ok hasta nov-2025: %d | max dif decisiones: %.2e | max dif factores hasta nov-2025: %.2e\n', ...
                height(T), all(T.ok), max(T.max_dx_decisiones), max(T.max_dG_hasta_nov2025));
            fprintf('Ultimo factor (dic-2025): cambio min %.4e, max %.4e\n', min(T.dG_dic2025), max(T.dG_dic2025));

            % Seleccion de T9 y tablas de validacion
            for g = ["G1", "G2"]
                a = readtable(fullfile(old, 'results_seleccion', sprintf('seleccion_%s.csv', g)));
                b = readtable(fullfile(new, 'results_seleccion', sprintf('seleccion_%s.csv', g)));
                fprintf('seleccion_%s.csv identica: %d\n', g, isequaln(a, b));
                disp(b);
            end
            a = readtable(fullfile(old, 'results_seleccion', 'sensibilidad_seleccion.csv'));
            b = readtable(fullfile(new, 'results_seleccion', 'sensibilidad_seleccion.csv'));
            fprintf('sensibilidad_seleccion.csv identica: %d\n', isequaln(a, b));
            d = dir(fullfile(old, 'results_validacion_metricas_v2', '*.csv'));
            for q = 1:numel(d)
                a = readtable(fullfile(d(q).folder, d(q).name));
                b = readtable(fullfile(new, 'results_validacion_metricas_v2', d(q).name));
                fprintf('results_validacion_metricas_v2/%s identica: %d\n', d(q).name, isequaln(a, b));
            end

        case 'prueba'
            a = readtable(fullfile(old, 'results_prueba_v2', 'metricas_por_tramo.csv'), 'TextType', 'string');
            b = readtable(fullfile(new, 'results_prueba_v2', 'metricas_por_tramo.csv'), 'TextType', 'string');
            assert(isequal(a.estrategia, b.estrategia) && isequal(a.tramo, b.tramo));
            T = table(a.estrategia, a.tramo, a.n_meses, a.riqueza_final, b.riqueza_final, ...
                b.riqueza_final ./ a.riqueza_final - 1, a.CAGR, b.CAGR, ...
                'VariableNames', {'estrategia', 'tramo', 'n_meses', 'riqueza_final_dic30', ...
                'riqueza_final_dic31', 'cambio_relativo', 'CAGR_dic30', 'CAGR_dic31'});
            writetable(T, out);
            disp(T);
            num = varfun(@isnumeric, a, 'OutputFormat', 'uniform');
            dv = abs(a{a.tramo == "validacion", num} - b{b.tramo == "validacion", num});
            fprintf('Validacion en metricas_por_tramo: max |dif| = %.2e\n', max(dv, [], 'all', 'omitnan'));
            for f = [fullfile("results_prueba_v2", "contrastes_prueba.csv"); ...
                    fullfile("results_bootstrap", "tabla_bootstrap_contrastes.csv"); ...
                    fullfile("results_regimen", "desglose_regimen.csv")]'
                ta = readtable(fullfile(old, f)); tb = readtable(fullfile(new, f));
                n = varfun(@isnumeric, ta, 'OutputFormat', 'uniform');
                fprintf('%s: max |dif| numerica = %.3e (filas %d vs %d)\n', f, ...
                    max(abs(ta{:, n} - tb{:, n}), [], 'all', 'omitnan'), height(ta), height(tb));
            end
    end
end

function rows = comparar_malla(pa, pb, fuente, TOL)
    A = load(pa, 'grid'); B = load(pb, 'grid');
    A = A.grid; B = B.grid;
    rows = {};
    for i = 1:numel(A.delta_grid)
        for j = 1:numel(A.eta_grid)
            rows{end + 1} = comparar_tray(A.results_wdro{i, j}, B.results_wdro{i, j}, ...
                fuente, A.delta_grid(i), A.eta_grid(j), TOL); %#ok<AGROW>
        end
    end
end

function row = comparar_tray(a, b, fuente, delta, eta, TOL)
% Decisiones: todas (ninguna usa dic-2025). Factores: todos menos el ultimo
% si la trayectoria llega a dic-2025 (realizado en dic-2025 = decision nov-2025).
    n = numel(a.dates);
    llega_dic = dateshift(a.dates(end), 'end', 'month', 1) == datetime(2025, 12, 31);
    m = n - llega_dic;
    dx = max(abs([a.x, a.x0] - [b.x, b.x0]), [], 'all');
    dG = max(abs(a.growth_real(1:m) - b.growth_real(1:m)));
    if llega_dic
        dG_last = b.growth_real(end) - a.growth_real(end);
    else
        dG_last = NaN;
    end
    ok = isequal(a.dates, b.dates) && dx <= TOL && dG <= TOL;
    row = table(fuente, delta, eta, n, dx, dG, dG_last, b.wealth(end) / a.wealth(end) - 1, ok, ...
        'VariableNames', {'fuente', 'delta', 'eta', 'n_decisiones', 'max_dx_decisiones', ...
        'max_dG_hasta_nov2025', 'dG_dic2025', 'cambio_riqueza_final', 'ok'});
end
