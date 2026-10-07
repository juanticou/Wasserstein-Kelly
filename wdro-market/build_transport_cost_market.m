function [C, info] = build_transport_cost_market(R, mkt, vix, weights, eps_esc, rate)
% BUILD_TRANSPORT_COST_MARKET  Geometria 2 de la propuesta (Seccion 9.5,
% ecuacion 43): distancia de transporte entre escenarios historicos
% informada por el estado del mercado, no solo por los retornos de las
% acciones.
%
%   c^M_{k,rs} = wR*(1/d)||rtilde_r - rtilde_s||_1 + wm|mtilde_r - mtilde_s|
%                + wv|vtilde_r - vtilde_s| + wf|ftilde_r - ftilde_s|
%
% con wR + wm + wv + wf = 1 (Cuadro 2). La version nucleo de la propuesta
% usa unicamente el nivel del VIX (no su cambio ni categorias de regimen,
% eso queda para la Geometria 3 / extensiones) y wf=0 (la tasa de corto
% plazo se deja fuera del nucleo, Seccion 15.7).
%
% ENTRADAS
%   R        : (N x d) retornos simples de las acciones en la ventana Dk.
%   mkt      : (N x 1) retorno mensual de SPY en la misma ventana (m_m,
%              ecuacion 56; data.mkt_return(k-N+1:k) de load_monthly_data.m).
%   vix      : (N x 1) nivel del VIX de fin de mes en la misma ventana
%              (V_m, ecuacion 57; data.vix(k-N+1:k)).
%   weights  : (opcional) struct con campos wR, wm, wv, wf que deben sumar 1.
%              Default: Cuadro 8 -- wR=0.70, wm=0.15, wv=0.15, wf=0.
%   eps_esc  : (opcional) piso para la estandarizacion (default 1e-6).
%   rate     : (opcional, N x 1) tasa de corto plazo de la ventana, solo
%              necesaria si weights.wf > 0 (Geometria 2 extendida con tasa,
%              Seccion 18.2 EXTENSION). Vacio por defecto.
%
% SALIDAS
%   C    : (N x N) matriz de costos de transporte c^M_{k,rs}. Simetrica,
%          diagonal exactamente cero.
%   info : struct con los componentes por separado (C_returns, C_market,
%          C_vix, C_rate si aplica) por si se quieren inspeccionar los
%          pesos relativos de cada bloque en la geometria resultante.
%
% NOTA: todas las estadisticas de estandarizacion se calculan UNICAMENTE
% con la ventana recibida (Seccion 9.4) -- nunca con datos posteriores a
% la fecha de decision.

    if nargin < 6
        rate = [];
    end
    if nargin < 5 || isempty(eps_esc)
        eps_esc = 1e-6;
    end
    if nargin < 4 || isempty(weights)
        weights = struct('wR', 0.70, 'wm', 0.15, 'wv', 0.15, 'wf', 0);
    end

    w_sum = weights.wR + weights.wm + weights.wv + weights.wf;
    if abs(w_sum - 1) > 1e-8
        error('build_transport_cost_market:weightsNotNormalized', ...
            'Los pesos (wR+wm+wv+wf) deben sumar 1; suman %.6f.', w_sum);
    end
    if weights.wf > 0 && isempty(rate)
        error('build_transport_cost_market:missingRate', ...
            'weights.wf > 0 pero no se proporciono la serie "rate" de la ventana.');
    end

    N = size(R, 1);
    mkt = mkt(:);
    vix = vix(:);
    if numel(mkt) ~= N || numel(vix) ~= N
        error('build_transport_cost_market:sizeMismatch', ...
            'mkt y vix deben tener N=%d observaciones, igual que R.', N);
    end

    % --- Bloque de retornos: reusa exactamente la Geometria 1 (ecuacion 42) ---
    C_returns = build_transport_cost(R, eps_esc);

    % --- Bloques escalares (mercado, VIX, tasa): estandarizacion + |diff| ---
    m_std = standardize_median_iqr(mkt, eps_esc);
    v_std = standardize_median_iqr(vix, eps_esc);

    C_market = pairwise_abs_diff(m_std);
    C_vix    = pairwise_abs_diff(v_std);

    C = weights.wR * C_returns + weights.wm * C_market + weights.wv * C_vix;

    info.C_returns = C_returns;
    info.C_market  = C_market;
    info.C_vix     = C_vix;
    info.weights   = weights;

    if weights.wf > 0
        f_std = standardize_median_iqr(rate(:), eps_esc);
        C_rate = pairwise_abs_diff(f_std);
        C = C + weights.wf * C_rate;
        info.C_rate = C_rate;
    end

    % La diagonal debe ser exactamente cero; se fuerza por robustez numerica.
    C(1:N+1:end) = 0;
end


function D = pairwise_abs_diff(v)
% Matriz (N x N) de diferencias absolutas por pares de un vector columna
% escalar v: D(r,s) = |v(r) - v(s)|. Equivalente a pdist(v,'cityblock')
% pero sin depender del Statistics Toolbox.
    D = abs(v - v.');
end
