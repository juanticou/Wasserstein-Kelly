function [xk, bk, sk, x0k, alpha, lambda, fval, status] = solve_wdro_kelly( ...
    hk, R, rf, tau, xbar, gamma, delta, C, rho, solver_name)
% SOLVE_WDRO_KELLY  Modelo Wasserstein-Kelly con costos de transaccion,
% reformulacion convexa dual exacta (ecuacion 53 de la propuesta).
%
%   max_{xk,bk,sk,alpha,lambda}  (1/N) * sum_r alpha_r  -  rho * lambda
%   s.a.
%       alpha_r <= log(Gks(xk)) + lambda * C(r,s)   para todo r,s = 1..N
%       xjk = hjk + bjk - sjk
%       x0k = h0k - sum(bjk) + sum(sjk) - tau*sum(bjk+sjk)
%       0 <= xjk <= xbar,  sum(xjk) <= gamma
%       Gks(xk) >= delta  para todo escenario s
%       xk,bk,sk >= 0,  lambda >= 0,  alpha libre
%
% Es la version robusta distribucionalmente de solve_nominal_kelly.m: el
% adversario puede redistribuir hasta `rho` unidades de costo de transporte
% (matriz C) entre los N escenarios de la ventana. Con rho=0 (y C(r,s)>0
% para todo r~=s) el problema se reduce exactamente al modelo nominal
% (Seccion 13.1 de la propuesta) — ver test_wdro_nominal_equivalence.m.
%
% ENTRADAS
%   hk, R, rf, tau, xbar, gamma, delta : identicos a solve_nominal_kelly.m.
%           R son retornos simples (NO 1+r), (N x d).
%   C     : (N x N) matriz de costos de transporte entre escenarios,
%           tipicamente la salida de build_transport_cost.m. Debe tener
%           diagonal cero y ser no negativa.
%   rho   : escalar >= 0, radio de la bola de Wasserstein (presupuesto de
%           transporte del adversario). rho=0 recupera el modelo nominal.
%   solver_name : (opcional) solucionador de CVX. Default 'mosek' (nativo
%           para el cono exponencial). 'sedumi'/'sdpt3' tambien funcionan
%           via aproximacion sucesiva, pero seran mas lentos aqui porque
%           hay N^2 restricciones logaritmicas en vez de N.
%
% SALIDAS
%   xk, bk, sk, x0k : igual que en solve_nominal_kelly.m.
%   alpha  : (N x 1) variable dual asociada al origen r (ecuacion 52).
%   lambda : escalar >= 0, variable dual del presupuesto de transporte.
%   fval   : valor optimo del objetivo minimax (peor caso distribucional).
%   status : cvx_status.

    if nargin < 10 || isempty(solver_name)
        solver_name = 'mosek';
    end

    [N, d] = size(R);

    if ~isequal(size(C), [N, N])
        error('solve_wdro_kelly:sizeMismatch', ...
            'C debe ser N x N con N = numero de filas de R (N=%d), pero size(C)=[%d,%d].', ...
            N, size(C, 1), size(C, 2));
    end
    if any(diag(C) ~= 0)
        warning('solve_wdro_kelly:nonzeroDiagonal', ...
            'La diagonal de C no es exactamente cero; se esperaba c_ss=0.');
    end
    if rho < 0
        error('solve_wdro_kelly:negativeRho', 'rho debe ser >= 0.');
    end

    if isscalar(xbar)
        xbar = xbar * ones(d, 1);
    end
    xbar = xbar(:);

    hk = hk(:);
    h0k = hk(1);
    hjk = hk(2:end);

    if numel(hjk) ~= d
        error('solve_wdro_kelly:dimMismatch', ...
            'hk debe tener d+1 componentes, consistente con R.');
    end

    Rplus1 = 1 + R;   % (N x d), para escribir Gks de forma afin en xjk

    cvx_begin quiet
        cvx_solver(solver_name)
        variables xjk(d) bjk(d) sjk(d) x0k lambda
        variable alpha_k(N)
        expression Gks(N)
        expression logGks(N)

        Gks = x0k * (1 + rf) + Rplus1 * xjk;   % (N x 1), factor de crecimiento por escenario destino s
        logGks = log(Gks);                      % (N x 1), concava

        maximize( (1 / N) * sum(alpha_k) - rho * lambda )
        subject to
            % Restriccion dual (ecuacion 52-53): para todo (r,s),
            %   alpha_r <= logGks(s) + lambda * C(r,s)
            % Vectorizado como una matriz N x N:
            %   alpha_k * ones(1,N) - lambda * C <= ones(N,1) * logGks'
            alpha_k * ones(1, N) - lambda * C <= ones(N, 1) * logGks';

            xjk == hjk + bjk - sjk;
            x0k == h0k - sum(bjk) + sum(sjk) - tau * sum(bjk + sjk);

            xjk >= 0;
            xjk <= xbar;
            sum(xjk) <= gamma;

            Gks >= delta;

            x0k >= 0;
            bjk >= 0;
            sjk >= 0;
            lambda >= 0;
    cvx_end

    xk = xjk;
    bk = bjk;
    sk = sjk;
    alpha = alpha_k;
    fval = cvx_optval;
    status = cvx_status;

    if ~strcmp(status, 'Solved')
        warning('solve_wdro_kelly:notSolved', ...
            'CVX status = %s en esta fecha (revisar factibilidad de delta o escala de rho/C).', ...
            status);
    end
end
