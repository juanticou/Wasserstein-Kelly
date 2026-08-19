function [xk, bk, sk, x0k, fval, status] = solve_nominal_kelly(hk, R, rf, tau, xbar, gamma, delta, solver_name)
% SOLVE_NOMINAL_KELLY  Modelo de Kelly nominal con costos de transaccion
% proporcionales, formulacion (37) de la propuesta.
%
%   max_{xk,bk,sk}  (1/N) * sum_s log( x0k*(1+rf) + sum_j xjk_j*(1+R(s,j)) )
%   s.a.
%       xjk = hjk + bjk - sjk                          (balance por activo)
%       x0k = h0k - sum(bjk) + sum(sjk) - tau*sum(bjk+sjk)  (balance de caja)
%       0 <= xjk <= xbar_j
%       sum(xjk) <= gamma
%       Gks(xk) >= delta   para todo escenario s        (supervivencia)
%       x0k, bjk, sjk >= 0
%
% ENTRADAS
%   hk    : (d+1 x 1) portafolio heredado ANTES del rebalanceo.
%           hk(1) = h0k (fraccion en el activo libre de riesgo),
%           hk(2:end) = hjk (fracciones en las d acciones). sum(hk) = 1.
%   R     : (N x d) retornos simples historicos de la ventana Dk. Cada
%           fila s es un escenario, cada columna j un activo riesgoso.
%           OJO: son retornos simples r_jk s, NO (1+r).
%   rf    : escalar, r^f_k, retorno del activo libre de riesgo conocido en k.
%   tau   : escalar >= 0, costo proporcional de transaccion.
%   xbar  : escalar o (d x 1), limite maximo por activo riesgoso (x_j).
%   gamma : escalar en (0,1], limite de exposicion riesgosa total.
%   delta : escalar > 0, cota de supervivencia (factor de crecimiento minimo
%           admitido dentro de los escenarios de entrenamiento).
%   solver_name : (opcional) cadena con el solucionador de CVX a usar.
%           Default: 'mosek'. MOSEK soporta el cono exponencial de forma
%           nativa (una sola resolucion exacta, rapida). Si no estuviera
%           disponible, 'sedumi'/'sdpt3' tambien funcionan pero via
%           aproximacion sucesiva (mas lento, algo menos preciso).
%
% SALIDAS
%   xk     : (d x 1) posiciones en activos riesgosos despues del rebalanceo.
%   bk     : (d x 1) compras (fraccion de Wk).
%   sk     : (d x 1) ventas (fraccion de Wk).
%   x0k    : escalar, posicion en el activo libre de riesgo despues del
%            rebalanceo y del pago de costos.
%   fval   : valor optimo del objetivo (crecimiento logaritmico promedio).
%   status : cvx_status ('Solved', 'Infeasible', 'Failed', etc.)
%
% Requiere CVX con un solucionador compatible con el cono exponencial
% (MOSEK recomendado; alternativamente SCS o ECOS con soporte exp-cone).

    if nargin < 8 || isempty(solver_name)
        solver_name = 'mosek';
    end

    [N, d] = size(R);

    if isscalar(xbar)
        xbar = xbar * ones(d, 1);
    end
    xbar = xbar(:);

    hk = hk(:);
    h0k = hk(1);
    hjk = hk(2:end);

    if numel(hjk) ~= d
        error('solve_nominal_kelly:dimMismatch', ...
            'hk debe tener d+1 componentes (h0k y d posiciones), consistente con R.');
    end

    % Matriz de "factores brutos" (1 + retorno) para construir Gks de forma
    % afin en xjk: Gks = x0k*(1+rf) + Rplus1 * xjk
    Rplus1 = 1 + R;   % (N x d)

    cvx_begin quiet
        cvx_solver(solver_name)
        variables xjk(d) bjk(d) sjk(d) x0k
        expression Gks(N)

        Gks = x0k * (1 + rf) + Rplus1 * xjk;

        maximize( (1 / N) * sum(log(Gks)) )
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

    xk = xjk;
    bk = bjk;
    sk = sjk;
    fval = cvx_optval;
    status = cvx_status;

    if ~strcmp(status, 'Solved')
        warning('solve_nominal_kelly:notSolved', ...
            'CVX status = %s en esta fecha de rebalanceo (revisar factibilidad de delta).', ...
            status);
    end
end