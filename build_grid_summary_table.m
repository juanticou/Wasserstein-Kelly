function T = build_grid_summary_table(grid, period_start, period_end)
% BUILD_GRID_SUMMARY_TABLE  Tabla maestra en formato largo: una fila por
% cada combinacion (delta, eta) de la malla, con todas las metricas de
% la Seccion 19 de la propuesta como columnas (crecimiento, perdidas
% -incluyendo varianza y CVaR-, costos, concentracion, supervivencia).
%
% A diferencia de los heatmaps (que muestran UNA metrica a la vez sobre
% la malla completa), esta tabla deja las 19+ metricas de cada ejecucion
% juntas para poder cruzarlas libremente (ordenar, filtrar, graficar
% cualquier par de columnas) sin que el codigo preseleccione un "ganador".
%
% ENTRADA
%   grid         : struct de run_grid_delta_eta_wdro_only.m
%   period_start : (opcional) datetime, inicio del periodo a evaluar. Si
%                  se omite, la tabla usa el backtest COMPLETO (como antes).
%   period_end   : (opcional) datetime, fin del periodo. Requerido si se
%                  da period_start.
%
% Cuando se pasan period_start/period_end, cada fila se recalcula SOLO
% sobre esos meses (via extract_period_results.m) -- asi es como se
% construye la tabla maestra de validacion (2015-2018) o de prueba
% (2019-2025) por separado, sin volver a resolver ningun backtest. En ese
% caso, la fraccion_factible y las columnas *_diff_vs_baseline TAMBIEN se
% recalculan dentro del periodo (no se reusan las del rango completo).
%
% SALIDA
%   T : table de MATLAB, una fila por combinacion (delta, eta) resuelta
%       (las combinaciones que fallaron por completo -- results_wdro
%       vacio, o sin meses dentro del periodo pedido -- se omiten, no se
%       rellenan con NaN silenciosamente).

    use_period = nargin >= 3 && ~isempty(period_start) && ~isempty(period_end);

    nd = numel(grid.delta_grid);
    ne = numel(grid.eta_grid);
    alpha = grid.alpha;

    % --- Primera pasada: calcular metricas de TODAS las celdas, para
    % poder construir feas/CAGR_diff/MDD_diff correctamente cuando se
    % filtra por periodo (necesitan conocerse todas antes de calcular la
    % diferencia contra la columna baseline de cada fila). ---
    M = cell(nd, ne);
    feas = nan(nd, ne);
    CAGR_mat = nan(nd, ne);
    MDD_mat  = nan(nd, ne);

    for i = 1:nd
        for j = 1:ne
            r = grid.results_wdro{i, j};
            if isempty(r)
                continue
            end
            if use_period
                try
                    r = extract_period_results(r, period_start, period_end);
                catch ME
                    warning('build_grid_summary_table:periodExtractFailed', ...
                        'delta=%.3f, eta=%.3f: %s', grid.delta_grid(i), grid.eta_grid(j), ME.message);
                    continue
                end
            end
            m = compute_metrics(r, alpha);
            M{i, j} = m;
            feas(i, j) = mean(strcmp(r.status, 'Solved'));
            CAGR_mat(i, j) = m.CAGR;
            MDD_mat(i, j)  = m.max_drawdown;
        end
    end

    if use_period
        % Baseline y diferencias recalculadas DENTRO del periodo.
        if ~isempty(grid.baseline_col)
            CAGR_baseline = CAGR_mat(:, grid.baseline_col);
            MDD_baseline  = MDD_mat(:, grid.baseline_col);
        else
            CAGR_baseline = nan(nd, 1);
            MDD_baseline  = nan(nd, 1);
        end
    else
        % Rango completo: se reusan las que ya trae `grid` (identicas a
        % las que se acaban de recalcular en CAGR_mat/MDD_mat, pero se
        % mantiene la referencia original por si `grid` fue editado a mano).
        feas = grid.feas_wdro;
        CAGR_baseline = grid.CAGR_baseline;
        MDD_baseline  = grid.MDD_baseline;
    end
    CAGR_diff = CAGR_mat - CAGR_baseline;
    MDD_diff  = MDD_mat - MDD_baseline;

    % --- Segunda pasada: construir las filas de la tabla. ---
    rows = {};
    for i = 1:nd
        for j = 1:ne
            m = M{i, j};
            if isempty(m)
                continue
            end

            is_baseline = ~isempty(grid.baseline_col) && (j == grid.baseline_col);

            row = table( ...
                grid.delta_grid(i), grid.eta_grid(j), is_baseline, ...
                m.wealth_final, m.log_growth_mean, m.CAGR, ...
                m.variance_monthly, m.max_drawdown, m.worst_month, ...
                m.var5_monthly, m.VaR_loss, m.CVaR_loss, ...
                m.turnover_total, m.n_rebalances, m.turnover_mean_active, ...
                m.cost_total, m.cost_mean, ...
                m.max_weight_mean, m.max_weight_max, m.Neff_mean, ...
                m.n_violations_delta, m.min_growth_real, ...
                feas(i, j), m.n_solver_failed, m.n_months, ...
                CAGR_diff(i, j), MDD_diff(i, j), ...
                'VariableNames', { ...
                    'delta', 'eta', 'es_baseline', ...
                    'riqueza_final', 'log_crecimiento_medio', 'CAGR', ...
                    'varianza_mensual', 'max_drawdown', 'peor_mes', ...
                    'percentil5_mensual', 'VaR_perdida', 'CVaR_perdida', ...
                    'turnover_total', 'n_transacciones', 'turnover_medio_activo', ...
                    'costo_total', 'costo_medio', ...
                    'peso_max_promedio', 'peso_max_pico', 'Neff_promedio', ...
                    'violaciones_delta', 'min_factor_crecimiento', ...
                    'fraccion_factible', 'fallos_solver', 'n_meses', ...
                    'CAGR_diff_vs_baseline', 'MDD_diff_vs_baseline'} ...
            );
            rows{end + 1} = row; %#ok<AGROW>
        end
    end

    if isempty(rows)
        error('build_grid_summary_table:empty', ...
            'Ninguna combinacion de la malla tiene resultados guardados en este periodo.');
    end

    T = vertcat(rows{:});
    T = sortrows(T, {'delta', 'eta'});
end
