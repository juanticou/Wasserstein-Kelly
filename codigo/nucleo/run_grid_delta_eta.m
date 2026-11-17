function grid = run_grid_delta_eta(data, base_params, delta_grid, eta_grid)
% RUN_GRID_DELTA_ETA  Corre el backtest WDRO para cada combinacion
% (delta, eta) y el backtest nominal para cada delta (el nominal no
% depende de eta: es el caso base de comparacion en esa fila de la malla).
%
% Para cada combinacion registra:
%   - fraccion de fechas resueltas ('Solved') -> mapa de factibilidad
%   - metricas de desempeno (CAGR, drawdown, turnover, Neff, etc.)
%   - la diferencia de desempeno frente al nominal CON EL MISMO delta,
%     que es la comparacion correcta (Seccion 21.4, punto 8: solo tiene
%     sentido comparar WDRO vs. nominal manteniendo fijo todo lo demas).
%
% ENTRADAS
%   data        : struct de load_monthly_data.m
%   base_params : struct con N, tau, xbar, gamma, solver (delta y eta se
%                 sobrescriben en cada combinacion de la malla)
%   delta_grid  : vector de valores de delta a explorar
%   eta_grid    : vector de valores de eta a explorar
%
% SALIDA (struct `grid`)
%   delta_grid, eta_grid   : las mallas usadas
%   feas_nominal           : (nd x 1) fraccion de fechas 'Solved' del nominal
%   feas_wdro              : (nd x ne) fraccion de fechas 'Solved' del WDRO
%   CAGR_nominal, MDD_nominal, Turnover_nominal, Neff_nominal : (nd x 1)
%   CAGR_wdro, MDD_wdro, Turnover_wdro, Neff_wdro, Wealth_wdro : (nd x ne)
%   CAGR_diff  : (nd x ne) = CAGR_wdro - CAGR_nominal(fila correspondiente)
%   MDD_diff   : (nd x ne) = MDD_wdro - MDD_nominal (negativo = WDRO mejor)
%   beats_nominal : (nd x ne) logico, CAGR_diff > 0 AND MDD_diff < 0
%                   (WDRO crece mas Y cae menos: dominancia estricta)
%   results_nominal, results_wdro : celdas con los structs completos de
%                   cada corrida, por si se necesita inspeccionar el detalle

    nd = numel(delta_grid);
    ne = numel(eta_grid);

    feas_nominal     = nan(nd, 1);
    CAGR_nominal     = nan(nd, 1);
    MDD_nominal      = nan(nd, 1);
    Turnover_nominal = nan(nd, 1);
    Neff_nominal     = nan(nd, 1);
    results_nominal  = cell(nd, 1);

    feas_wdro     = nan(nd, ne);
    CAGR_wdro     = nan(nd, ne);
    MDD_wdro      = nan(nd, ne);
    Turnover_wdro = nan(nd, ne);
    Neff_wdro     = nan(nd, ne);
    Wealth_wdro   = nan(nd, ne);
    results_wdro  = cell(nd, ne);

    for i = 1:nd
        delta_i = delta_grid(i);
        fprintf('\n--- delta = %.3f | Kelly nominal (baseline de esta fila) ---\n', delta_i);

        p_nom = base_params;
        p_nom.delta = delta_i;

        try
            r_nom = run_backtest_nominal_kelly(data, p_nom);
            m_nom = compute_metrics(r_nom);
            feas_nominal(i)     = mean(strcmp(r_nom.status, 'Solved'));
            CAGR_nominal(i)     = m_nom.CAGR;
            MDD_nominal(i)      = m_nom.max_drawdown;
            Turnover_nominal(i) = m_nom.turnover_total;
            Neff_nominal(i)     = m_nom.Neff_mean;
            results_nominal{i}  = r_nom;
            fprintf('  factibilidad = %.0f%% | CAGR = %.2f%% | MDD = %.2f%%\n', ...
                100*feas_nominal(i), 100*CAGR_nominal(i), 100*MDD_nominal(i));
        catch ME
            warning('run_grid_delta_eta:nominalFailed', ...
                'delta=%.3f: el backtest nominal fallo con error: %s', delta_i, ME.message);
        end

        for j = 1:ne
            eta_j = eta_grid(j);
            fprintf('  delta = %.3f, eta = %.3f | WDRO ... ', delta_i, eta_j);

            p_wdro = base_params;
            p_wdro.delta = delta_i;
            p_wdro.eta   = eta_j;

            try
                r_w = run_backtest_wdro_kelly(data, p_wdro);
                m_w = compute_metrics(r_w);

                feas_wdro(i, j)     = mean(strcmp(r_w.status, 'Solved'));
                CAGR_wdro(i, j)     = m_w.CAGR;
                MDD_wdro(i, j)      = m_w.max_drawdown;
                Turnover_wdro(i, j) = m_w.turnover_total;
                Neff_wdro(i, j)     = m_w.Neff_mean;
                Wealth_wdro(i, j)   = m_w.wealth_final;
                results_wdro{i, j}  = r_w;

                fprintf('factibilidad = %.0f%% | CAGR = %.2f%% | MDD = %.2f%%\n', ...
                    100*feas_wdro(i, j), 100*CAGR_wdro(i, j), 100*MDD_wdro(i, j));
            catch ME
                warning('run_grid_delta_eta:wdroFailed', ...
                    'delta=%.3f, eta=%.3f: el backtest WDRO fallo con error: %s', ...
                    delta_i, eta_j, ME.message);
                fprintf('FALLO (%s)\n', ME.message);
            end
        end
    end

    CAGR_diff = CAGR_wdro - CAGR_nominal;          % broadcast (nd x ne) - (nd x 1)
    MDD_diff  = MDD_wdro - MDD_nominal;
    beats_nominal = (CAGR_diff > 0) & (MDD_diff < 0);

    grid.delta_grid      = delta_grid;
    grid.eta_grid        = eta_grid;
    grid.feas_nominal    = feas_nominal;
    grid.feas_wdro       = feas_wdro;
    grid.CAGR_nominal    = CAGR_nominal;
    grid.MDD_nominal     = MDD_nominal;
    grid.Turnover_nominal = Turnover_nominal;
    grid.Neff_nominal    = Neff_nominal;
    grid.CAGR_wdro       = CAGR_wdro;
    grid.MDD_wdro        = MDD_wdro;
    grid.Turnover_wdro   = Turnover_wdro;
    grid.Neff_wdro       = Neff_wdro;
    grid.Wealth_wdro     = Wealth_wdro;
    grid.CAGR_diff       = CAGR_diff;
    grid.MDD_diff        = MDD_diff;
    grid.beats_nominal   = beats_nominal;
    grid.results_nominal = results_nominal;
    grid.results_wdro    = results_wdro;
    grid.base_params     = base_params;
end
