function pm = compute_period_grid_matrices(grid, period_start, period_end, alpha)
% COMPUTE_PERIOD_GRID_MATRICES  Version restringida a un periodo de
% fechas de las matrices delta x eta que ya trae `grid` (Wealth_wdro,
% CAGR_wdro, MDD_wdro, Variance_wdro, CVaR_wdro, Turnover_wdro, feas_wdro,
% CAGR_diff, MDD_diff) -- para construir los heatmaps de SOLO el periodo
% de validacion o SOLO el periodo de prueba, sin volver a resolver ningun
% backtest (usa extract_period_results.m sobre los resultados ya guardados
% en grid.results_wdro).
%
% ENTRADAS
%   grid         : struct de run_grid_delta_eta_wdro_only.m (con
%                  results_wdro guardado, no solo las matrices resumen)
%   period_start : datetime, inicio del periodo (inclusive)
%   period_end   : datetime, fin del periodo (inclusive)
%   alpha        : (opcional) nivel de confianza para VaR/CVaR. Default:
%                  grid.alpha (el mismo usado en la corrida completa).
%
% SALIDA (struct `pm`)
%   delta_grid, eta_grid, baseline_col : igual que en `grid`
%   period_start, period_end : los limites usados
%   feas, CAGR, MDD, Wealth, Variance, CVaR, Turnover, NRebalances : (nd x ne)
%   CAGR_baseline, MDD_baseline : (nd x 1), metricas de la columna eta=0
%                  DENTRO del periodo (no del rango completo)
%   CAGR_diff, MDD_diff : (nd x ne), diferencia contra ese baseline
%                  DENTRO del periodo
%   sub_results  : (nd x ne) cell array con los `results` ya recortados
%                  al periodo, por si se necesitan para graficar retornos
%                  o riqueza de una celda especifica sin repetir el corte

    if nargin < 4 || isempty(alpha)
        alpha = grid.alpha;
    end

    nd = numel(grid.delta_grid);
    ne = numel(grid.eta_grid);

    feas        = nan(nd, ne);
    CAGR        = nan(nd, ne);
    MDD         = nan(nd, ne);
    Wealth      = nan(nd, ne);
    Variance    = nan(nd, ne);
    CVaR        = nan(nd, ne);
    Turnover    = nan(nd, ne);
    NRebalances = nan(nd, ne);
    sub_results = cell(nd, ne);

    for i = 1:nd
        for j = 1:ne
            r = grid.results_wdro{i, j};
            if isempty(r)
                continue
            end
            try
                r_sub = extract_period_results(r, period_start, period_end);
            catch ME
                warning('compute_period_grid_matrices:extractFailed', ...
                    'delta=%.3f, eta=%.3f: %s', grid.delta_grid(i), grid.eta_grid(j), ME.message);
                continue
            end
            m = compute_metrics(r_sub, alpha);

            feas(i, j)        = mean(strcmp(r_sub.status, 'Solved'));
            CAGR(i, j)        = m.CAGR;
            MDD(i, j)         = m.max_drawdown;
            Wealth(i, j)      = m.wealth_final;
            Variance(i, j)    = m.variance_monthly;
            CVaR(i, j)        = m.CVaR_loss;
            Turnover(i, j)    = m.turnover_total;
            NRebalances(i, j) = m.n_rebalances;
            sub_results{i, j} = r_sub;
        end
    end

    if ~isempty(grid.baseline_col)
        CAGR_baseline = CAGR(:, grid.baseline_col);
        MDD_baseline  = MDD(:, grid.baseline_col);
    else
        CAGR_baseline = nan(nd, 1);
        MDD_baseline  = nan(nd, 1);
    end
    CAGR_diff = CAGR - CAGR_baseline;
    MDD_diff  = MDD - MDD_baseline;

    pm.delta_grid    = grid.delta_grid;
    pm.eta_grid      = grid.eta_grid;
    pm.baseline_col  = grid.baseline_col;
    pm.period_start  = period_start;
    pm.period_end    = period_end;
    pm.alpha         = alpha;
    pm.feas          = feas;
    pm.CAGR          = CAGR;
    pm.MDD           = MDD;
    pm.Wealth        = Wealth;
    pm.Variance      = Variance;
    pm.CVaR          = CVaR;
    pm.Turnover      = Turnover;
    pm.NRebalances   = NRebalances;
    pm.CAGR_baseline = CAGR_baseline;
    pm.MDD_baseline  = MDD_baseline;
    pm.CAGR_diff     = CAGR_diff;
    pm.MDD_diff      = MDD_diff;
    pm.sub_results   = sub_results;
end
