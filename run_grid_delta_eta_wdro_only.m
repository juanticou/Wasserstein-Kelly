function grid = run_grid_delta_eta_wdro_only(data, base_params, delta_grid, eta_grid, alpha)
% RUN_GRID_DELTA_ETA_WDRO_ONLY  Version mas liviana de run_grid_delta_eta.m
% que NO llama a run_backtest_nominal_kelly por separado. En vez de eso,
% usa la corrida con eta=0 dentro de la propia malla WDRO como el
% "baseline" equivalente al nominal (verificado en
% test_wdro_nominal_equivalence.m y en la corrida completa de
% main_wdro_kelly.m). Esto evita resolver dos veces esencialmente el
% mismo problema por cada delta.
%
% IMPORTANTE: si eta_grid NO incluye 0, no hay baseline con el cual
% calcular CAGR_diff / MDD_diff para esa fila; esos campos quedan en NaN
% y se emite una advertencia. Para conservar la comparacion, incluye 0 en
% eta_grid aunque el resto de valores sean mayores a 1.
%
% NOTA: CAGR_diff y MDD_diff se calculan solo como referencia informativa
% frente al baseline (eta=0); esta funcion NO selecciona una combinacion
% "ganadora" -- eso se deja para que el usuario lo decida a partir de la
% tabla maestra (build_grid_summary_table.m) y los heatmaps individuales.
%
% ENTRADAS
%   data        : struct de load_monthly_data.m
%   base_params : struct con N, tau, xbar, gamma, solver (delta y eta se
%                 sobrescriben en cada combinacion de la malla)
%   delta_grid  : vector de valores de delta a explorar (puede incluir
%                 valores > 1; una cota de supervivencia delta > 1 exige
%                 crecimiento garantizado incluso en el peor escenario de
%                 entrenamiento, asi que se espera que la region factible
%                 se angoste rapido ahi -- justo lo que se quiere mapear)
%   eta_grid    : vector de valores de eta a explorar (incluir 0 para
%                 tener baseline; el resto puede ser > 1)
%   alpha       : (opcional) nivel de confianza para VaR/CVaR (default 0.95,
%                 ver compute_metrics.m)
%
% SALIDA (struct `grid`) -- mismos campos de resultados que
% run_grid_delta_eta.m para la parte WDRO (feas_wdro, CAGR_wdro,
% MDD_wdro, Turnover_wdro, Neff_wdro, Wealth_wdro, results_wdro), MAS:
%   Variance_wdro, CVaR_wdro : (nd x ne) varianza y CVaR de los retornos
%                      mensuales realizados de cada combinacion
%   baseline_col     : indice de columna en eta_grid usado como baseline
%                      (eta=0), o [] si eta_grid no incluye 0
%   CAGR_baseline, MDD_baseline : (nd x 1) metricas de esa columna, una
%                      por fila de delta (equivalen al "nominal" de esa fila)
%   CAGR_diff, MDD_diff : igual que en run_grid_delta_eta.m, pero
%                      calculados contra CAGR_baseline/MDD_baseline en vez
%                      de una corrida nominal separada. Si no hay
%                      baseline, quedan en NaN.

    if nargin < 5 || isempty(alpha)
        alpha = 0.95;
    end

    nd = numel(delta_grid);
    ne = numel(eta_grid);

    feas_wdro     = nan(nd, ne);
    CAGR_wdro     = nan(nd, ne);
    MDD_wdro      = nan(nd, ne);
    Turnover_wdro = nan(nd, ne);
    Neff_wdro     = nan(nd, ne);
    Wealth_wdro   = nan(nd, ne);
    Variance_wdro = nan(nd, ne);
    CVaR_wdro     = nan(nd, ne);
    results_wdro  = cell(nd, ne);

    baseline_col = find(eta_grid == 0, 1);
    if isempty(baseline_col)
        warning('run_grid_delta_eta_wdro_only:noBaseline', ...
            ['eta_grid no incluye 0: no habra baseline equivalente al nominal ', ...
             'para calcular CAGR_diff/MDD_diff. Se recomienda incluir 0 en ', ...
             'eta_grid aunque el resto de valores sean > 1.']);
    end

    for i = 1:nd
        delta_i = delta_grid(i);
        fprintf('\n--- delta = %.3f ---\n', delta_i);

        for j = 1:ne
            eta_j = eta_grid(j);
            fprintf('  delta = %.3f, eta = %.3f | WDRO ... ', delta_i, eta_j);

            p_wdro = base_params;
            p_wdro.delta = delta_i;
            p_wdro.eta   = eta_j;

            try
                r_w = run_backtest_wdro_kelly(data, p_wdro);
                m_w = compute_metrics(r_w, alpha);

                feas_wdro(i, j)     = mean(strcmp(r_w.status, 'Solved'));
                CAGR_wdro(i, j)     = m_w.CAGR;
                MDD_wdro(i, j)      = m_w.max_drawdown;
                Turnover_wdro(i, j) = m_w.turnover_total;
                Neff_wdro(i, j)     = m_w.Neff_mean;
                Wealth_wdro(i, j)   = m_w.wealth_final;
                Variance_wdro(i, j) = m_w.variance_monthly;
                CVaR_wdro(i, j)     = m_w.CVaR_loss;
                results_wdro{i, j}  = r_w;

                fprintf('factibilidad = %.0f%% | CAGR = %.2f%% | MDD = %.2f%%\n', ...
                    100*feas_wdro(i, j), 100*CAGR_wdro(i, j), 100*MDD_wdro(i, j));
            catch ME
                warning('run_grid_delta_eta_wdro_only:wdroFailed', ...
                    'delta=%.3f, eta=%.3f: fallo con error: %s', delta_i, eta_j, ME.message);
                fprintf('FALLO (%s)\n', ME.message);
            end
        end
    end

    if ~isempty(baseline_col)
        CAGR_baseline = CAGR_wdro(:, baseline_col);
        MDD_baseline  = MDD_wdro(:, baseline_col);
        CAGR_diff = CAGR_wdro - CAGR_baseline;     % broadcast (nd x ne) - (nd x 1)
        MDD_diff  = MDD_wdro - MDD_baseline;
    else
        CAGR_baseline = nan(nd, 1);
        MDD_baseline  = nan(nd, 1);
        CAGR_diff = nan(nd, ne);
        MDD_diff  = nan(nd, ne);
    end

    grid.delta_grid    = delta_grid;
    grid.eta_grid      = eta_grid;
    grid.alpha         = alpha;
    grid.baseline_col  = baseline_col;
    grid.feas_wdro     = feas_wdro;
    grid.CAGR_wdro     = CAGR_wdro;
    grid.MDD_wdro      = MDD_wdro;
    grid.Turnover_wdro = Turnover_wdro;
    grid.Neff_wdro     = Neff_wdro;
    grid.Wealth_wdro   = Wealth_wdro;
    grid.Variance_wdro = Variance_wdro;
    grid.CVaR_wdro     = CVaR_wdro;
    grid.CAGR_baseline = CAGR_baseline;
    grid.MDD_baseline  = MDD_baseline;
    grid.CAGR_diff     = CAGR_diff;
    grid.MDD_diff      = MDD_diff;
    grid.results_wdro  = results_wdro;
    grid.base_params   = base_params;
end
