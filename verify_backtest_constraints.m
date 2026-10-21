%% verify_backtest_constraints.m
% Verificacion (b) de "Implementacion y verificacion" sobre los
% resultados YA GUARDADOS (no resuelve nada): para cada celda (delta, eta)
% y cada mes se recalculan, con los datos de la ventana D_k,
%   balance   : |x0 + sum(x) - (1 - tau*TO)|
%   turnover  : |TO - sum|x - h_j||  (sin compra y venta simultanea)
%   cotas     : max(-x, x - xbar, 0), max(sum(x) - gamma, 0)
%   delta     : max(delta - min_s G_ks, 0), G_ks = x0(1+rf_k) + (1+R_s) x
% y se reporta el maximo por celda, junto con TOL_FEAS.
%
% Fuentes: Geometria 1, malla completa (results_eta_delta_grid_wdro) y
% Geometria 2, malla de validacion (wdro-market/results_validacion_grid_market).
% Salida: results_verificaciones/verificacion_restricciones.csv

TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
PROJECT_DIR = fileparts(mfilename('fullpath'));
cfg = config_rutas();   % rutas de datos y resultados (WK_PANEL, WK_RESULTS_ROOT)
RES = cfg.results_root;
CSV_PATH = cfg.panel;
OUT_DIR  = fullfile(RES, 'results_verificaciones');
preparar_salida(cfg, OUT_DIR);
TOL_FEAS = 1e-7;

data = load_monthly_data(CSV_PATH, TICKERS);

sources = { ...
    'G1', fullfile(RES, 'results_eta_delta_grid_wdro', 'grid_delta_eta.mat'); ...
    'G2', fullfile(RES, 'wdro-market', 'results_validacion_grid_market', ...
                   'grid_delta_eta_market_validacion.mat')};

rows = {};
for s = 1:size(sources, 1)
    S = load(sources{s, 2}, 'grid');
    g = S.grid;
    for i = 1:numel(g.delta_grid)
        for j = 1:numel(g.eta_grid)
            r = g.results_wdro{i, j};
            if isempty(r)
                continue
            end
            p = r.params;
            [~, kk] = ismember(r.dates, data.dates);
            T_dec = numel(r.dates);
            v_bal = zeros(T_dec, 1); v_to = v_bal; v_bnd = v_bal; v_del = v_bal;
            slack_del = v_bal;
            for t = 1:T_dec
                k  = kk(t);
                x  = r.x(t, :)';
                x0 = r.x0(t);
                h  = r.h(t, :)';
                TO = r.turnover(t);
                Rw = data.R(k - p.N + 1 : k, :);
                G  = x0 * (1 + data.rf_return(k)) + (1 + Rw) * x;
                v_bal(t) = abs(x0 + sum(x) - (1 - p.tau * TO));
                v_to(t)  = abs(TO - sum(abs(x - h(2:end))));
                v_bnd(t) = max([max(-x, 0); max(x - p.xbar, 0); max(sum(x) - p.gamma, 0); max(-x0, 0)]);
                v_del(t) = max(p.delta - min(G), 0);
                slack_del(t) = min(G) - p.delta;
            end
            n_active = sum(slack_del <= 1e-6);   % meses con la cota delta activa
            % Exceso de turnover por compra y venta simultanea del mismo activo
            % (holgura de punto interior): suma sobre el horizonte.
            excess_to = sum(v_to);
            % El residuo de turnover no es una restriccion del modelo: se reporta
            % aparte y no entra en ok.
            ok = max([v_bal; v_bnd; v_del]) <= TOL_FEAS;
            rows{end + 1} = table(string(sources{s, 1}), g.delta_grid(i), g.eta_grid(j), T_dec, ...
                max(v_bal), max(v_to), max(v_bnd), max(v_del), n_active, min(slack_del), excess_to, sum(r.turnover), ok, ...
                'VariableNames', {'geometria', 'delta', 'eta', 'n_meses', 'max_resid_balance', ...
                'max_resid_turnover', 'max_viol_cotas', 'max_viol_delta_ventana', ...
                'meses_cota_delta_activa', 'min_holgura_delta', 'exceso_turnover_total', 'turnover_total', 'ok'}); %#ok<SAGROW>
        end
    end
end

T = vertcat(rows{:});
writetable(T, fullfile(OUT_DIR, 'verificacion_restricciones.csv'));
fprintf('Celdas verificadas: %d | todas dentro de TOL_FEAS=%.0e: %d\n', height(T), TOL_FEAS, all(T.ok));
for gname = ["G1", "G2"]
    m = T.geometria == gname;
    fprintf(['%s: max balance=%.2e | max turnover=%.2e | max cotas=%.2e | max delta=%.2e | ', ...
        'celdas con cota delta activa algun mes: %d\n'], gname, max(T.max_resid_balance(m)), ...
        max(T.max_resid_turnover(m)), max(T.max_viol_cotas(m)), max(T.max_viol_delta_ventana(m)), ...
        sum(T.meses_cota_delta_activa(m) > 0));
    [ex_max, i_ex] = max(T.exceso_turnover_total .* m);
    fprintf('%s: exceso de turnover acumulado maximo por celda = %.2e (turnover total de esa celda %.2f)\n', ...
        gname, ex_max, T.turnover_total(i_ex));
end
