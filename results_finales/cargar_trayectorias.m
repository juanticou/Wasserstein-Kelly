function traj = cargar_trayectorias(RES, data)
% CARGAR_TRAYECTORIAS  Trayectorias completas (132 decisiones) de las seis
% estrategias de prueba, igual que main_test_evaluation_v2.m. Compartida
% por r2_tablas.m y r3_figuras.m; solo lee resultados de RES.
%
%   traj : containers.Map, clave = nombre de la estrategia
%          ("Nominal (0.80)", "G1 (0.90, 0.01)", ...), valor = struct results
    traj = containers.Map('KeyType', 'char', 'ValueType', 'any');
    S = load(fullfile(RES, 'results_prueba_v2', 'g2_trayectorias_completas.mat'), 'res');
    for m = 1:numel(S.res)
        traj(char(S.res(m).name)) = S.res(m).r;
    end
    S = load(fullfile(RES, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'), 'grid');
    for delta = [0.80, 0.90]
        i = find(abs(S.grid.delta_grid - delta) < 1e-12, 1);
        j = find(abs(S.grid.eta_grid - 0.01) < 1e-12, 1);
        traj(sprintf('G1 (%.2f, 0.01)', delta)) = attach_rf(S.grid.results_wdro{i, j}, data);
    end
    S = load(fullfile(RES, 'results_verificaciones', 'nominal_backtests.mat'), 'nominal_results', 'DELTAS_TO_RUN');
    for delta = [0.80, 0.90]
        k = find(abs(S.DELTAS_TO_RUN - delta) < 1e-12, 1);
        traj(sprintf('Nominal (%.2f)', delta)) = S.nominal_results{k};
    end
end
