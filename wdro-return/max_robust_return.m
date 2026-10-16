function [val, x, status] = max_robust_return(hk, R, rf, tau, xbar, gamma, delta, eps_ret, solver_name)
% MAX_ROBUST_RETURN  Maximo retorno esperado robusto alcanzable en una
% ventana, sobre el mismo conjunto factible del modelo (balance de caja con
% costos, limites xbar/gamma, cota de supervivencia delta):
%
%   v(eps) = max_{x,b,s}  x0(1+rf) + sum_j xj(1+mbar_j) - 1 - eps*||x_{1..d}||_2
%
% Es el insumo del criterio de factibilidad del articulo de Fonseca y
% Junca (arXiv:2111.04663): la restriccion de retorno esperado con
% parametros (mu, eps) es factible si y solo si v(eps) >= mu. Con eps = 0,
% v(0) = mu_max (el mejor retorno promedio muestral alcanzable). v es
% convexa y no creciente en eps (maximo de funciones afines decrecientes
% en eps), lo que justifica la biseccion de eps_max_for_mu.m.
%
% ENTRADAS: hk, R, rf, tau, xbar, gamma, delta como en solve_wdro_kelly.m;
%           eps_ret >= 0; solver_name opcional (default 'mosek').
% SALIDAS : val (valor optimo, NaN si el problema es infactible), x
%           (posiciones riesgosas optimas) y status de CVX.

    if nargin < 9 || isempty(solver_name)
        solver_name = 'mosek';
    end
    [N, d] = size(R);
    if isscalar(xbar), xbar = xbar * ones(d, 1); end
    xbar = xbar(:);
    hk = hk(:);
    h0k = hk(1);
    hjk = hk(2:end);
    mbar = mean(R, 1)';
    Rplus1 = 1 + R;

    cvx_begin quiet
        cvx_solver(solver_name)
        variables xjk(d) bjk(d) sjk(d) x0k
        expression Gks(N)
        Gks = x0k * (1 + rf) + Rplus1 * xjk;

        maximize( x0k * (1 + rf) + (1 + mbar)' * xjk - 1 - eps_ret * norm(xjk, 2) )
        subject to
            xjk == hjk + bjk - sjk;
            x0k == h0k - sum(bjk) + sum(sjk) - tau * sum(bjk + sjk);
            xjk >= 0;
            xjk <= xbar;
            sum(xjk) <= gamma;
            Gks >= delta;
            x0k >= 0;
            bjk >= 0;
            sjk >= 0;
    cvx_end

    status = cvx_status;
    x = xjk;
    if strcmp(status, 'Solved')
        val = cvx_optval;
    else
        val = NaN;
    end
end
