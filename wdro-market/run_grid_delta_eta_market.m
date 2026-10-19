function grid = run_grid_delta_eta_market(data, base_params, delta_grid, eta_grid, alpha)
% RUN_GRID_DELTA_ETA_MARKET  Malla delta x eta para la GEOMETRIA 2
% (retornos + retorno de mercado + VIX, build_transport_cost_market.m).
% Es la misma rutina que run_grid_delta_eta_wdro_only.m (Geometria 1),
% pero cada combinacion se resuelve con run_backtest_wdro_kelly_market.m.
%
% Devuelve EXACTAMENTE el mismo struct `grid` que
% run_grid_delta_eta_wdro_only.m, para poder reusar sin cambios
% compute_period_grid_matrices.m, build_grid_summary_table.m,
% plot_wealth_by_delta.m y matrix_to_wide_table.m.
%
% Como en la Geometria 1, eta=0 hace de baseline (equivalente al
% nominal): con radio cero el costo de transporte no participa, asi que
% esa columna debe coincidir con la de la Geometria 1.
%
% ENTRADAS
%   data        : struct de load_monthly_data.m (con mkt_return y vix)
%   base_params : struct con N, tau, xbar, gamma, solver, eps_esc y
%                 weights (wR, wm, wv, wf de la Geometria 2). delta y eta
%                 se sobrescriben en cada combinacion de la malla.
%   delta_grid  : vector de valores de delta a explorar
%   eta_grid    : vector de valores de eta a explorar (incluir 0 para
%                 tener baseline)
%   alpha       : (opcional) nivel de confianza para VaR/CVaR (default 0.95)
%
% SALIDA (struct `grid`) -- ver run_grid_delta_eta_wdro_only.m.

    if nargin < 5 || isempty(alpha)
        alpha = 0.95;
    end
    if ~isfield(base_params, 'weights') || isempty(base_params.weights)
        error('run_grid_delta_eta_market:noWeights', ...
            'base_params.weights (wR, wm, wv, wf) es obligatorio para la Geometria 2.');
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
        warning('run_grid_delta_eta_market:noBaseline', ...
            ['eta_grid no incluye 0: no habra baseline equivalente al nominal ', ...
             'para calcular CAGR_diff/MDD_diff.']);
    end

    for i = 1:nd
        delta_i = delta_grid(i);
        fprintf('\n--- delta = %.3f ---\n', delta_i);

        for j = 1:ne
            eta_j = eta_grid(j);
            fprintf('  delta = %.3f, eta = %.3f | WDRO Geometria 2 ... ', delta_i, eta_j);

            p_wdro = base_params;
            p_wdro.delta = delta_i;
            p_wdro.eta   = eta_j;

            try
                r_w = run_backtest_wdro_kelly_market(data, p_wdro);
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
                warning('run_grid_delta_eta_market:wdroFailed', ...
                    'delta=%.3f, eta=%.3f: fallo con error: %s', delta_i, eta_j, ME.message);
                fprintf('FALLO (%s)\n', ME.message);
            end
        end
    end

    if ~isempty(baseline_col)
        CAGR_baseline = CAGR_wdro(:, baseline_col);
        MDD_baseline  = MDD_wdro(:, baseline_col);
        CAGR_diff = CAGR_wdro - CAGR_baseline;
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
