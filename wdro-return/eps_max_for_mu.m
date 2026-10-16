function eps_max = eps_max_for_mu(mu, hk, R, rf, tau, xbar, gamma, delta, solver_name, tol)
% EPS_MAX_FOR_MU  Mayor radio eps tal que la restriccion de retorno esperado
% robusto con retorno minimo mu sigue siendo factible en la ventana R
% (criterio de factibilidad de Fonseca y Junca, arXiv:2111.04663):
%
%   eps_max(mu) = max { eps >= 0 : v(eps) >= mu },   v de max_robust_return.m
%
% Se calcula por biseccion, usando que v es no creciente en eps. Devuelve
% NaN si ni siquiera eps = 0 es factible (es decir, mu > mu_max de la
% ventana) e Inf si el problema sigue factible para todo eps razonable
% (v(eps) >= mu aun con eps muy grande, p. ej. mu <= v(infinito) = 1*rf
% alcanzado con todo en el activo de bajo riesgo).
%
% ENTRADAS: mu y los argumentos de max_robust_return.m; tol (opcional,
%           default 1e-5) es la tolerancia de la biseccion en eps.

    if nargin < 9 || isempty(solver_name), solver_name = 'mosek'; end
    if nargin < 10 || isempty(tol), tol = 1e-5; end

    v0 = max_robust_return(hk, R, rf, tau, xbar, gamma, delta, 0, solver_name);
    if isnan(v0) || v0 < mu
        eps_max = NaN;
        return
    end

    lo = 0;
    hi = 0.01;
    n_double = 0;
    while n_double < 12
        v_hi = max_robust_return(hk, R, rf, tau, xbar, gamma, delta, hi, solver_name);
        if isnan(v_hi) || v_hi < mu
            break
        end
        lo = hi;
        hi = 2 * hi;
        n_double = n_double + 1;
    end
    if n_double >= 12
        eps_max = Inf;   % factible incluso con eps ~ 40 -> practicamente sin tope
        return
    end

    while (hi - lo) > tol
        mid = 0.5 * (lo + hi);
        v_mid = max_robust_return(hk, R, rf, tau, xbar, gamma, delta, mid, solver_name);
        if ~isnan(v_mid) && v_mid >= mu
            lo = mid;
        else
            hi = mid;
        end
    end
    eps_max = lo;
end
