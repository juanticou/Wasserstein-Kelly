function [xk, bk, sk, x0k, alpha, lambda, fval, status] = solve_wdro_kelly_hypercube( ...
    hk, R, R_synth, rf, tau, xbar, gamma, delta, C, rho, solver_name, apply_delta_to_synthetic)
% SOLVE_WDRO_KELLY_HYPERCUBE  Generalizacion de solve_wdro_kelly.m donde
% el ADVERSARIO puede mover probabilidad hacia escenarios SINTETICOS
% (muestreados uniformemente en el hipercubo de la ventana,
% sample_hypercube_scenarios.m), ademas de los N escenarios historicos.
%
%   max_{xk,bk,sk,alpha,lambda}  (1/N) * sum_r alpha_r  -  rho * lambda
%   s.a.
%       alpha_r <= log(Gs(xk)) + lambda * C(r,s)   para r=1..N, s=1..(N+M)
%       xjk = hjk + bjk - sjk
%       x0k = h0k - sum(bjk) + sum(sjk) - tau*sum(bjk+sjk)
%       0 <= xjk <= xbar,  sum(xjk) <= gamma
%       Gs(xk) >= delta  para los escenarios indicados (ver mas abajo)
%       xk,bk,sk >= 0,  lambda >= 0,  alpha libre
%
% El origen de la masa de probabilidad SIGUE SIENDO los N escenarios
% historicos (1/N cada uno, igual que en el modelo nucleo) -- lo que
% cambia es que el DESTINO ya no esta restringido a esos mismos N puntos:
% ahora el adversario puede mover masa hacia cualquiera de los N+M puntos
% (historicos + sinteticos). Con rho=0 y M=0 (sin sinteticos) esto se
% reduce exactamente a solve_wdro_kelly.m.
%
% ENTRADAS
%   hk, rf, tau, xbar, gamma, delta : identicos a solve_wdro_kelly.m.
%   R        : (N x d) retornos historicos de la ventana (origenes).
%   R_synth  : (M x d) escenarios sinteticos del hipercubo (destinos
%              adicionales). Puede ser una matriz vacia (M=0) para
%              recuperar el comportamiento de solve_wdro_kelly.m.
%   C        : (N x (N+M)) matriz de costos de transporte, salida de
%              build_transport_cost_hypercube.m.
%   rho      : escalar >= 0, radio de la bola.
%   solver_name : (opcional) solucionador de CVX. Default 'mosek'.
%   apply_delta_to_synthetic : (opcional) logico, default true. Si true,
%              la cota de supervivencia Gs(xk) >= delta se exige tambien
%              en los M escenarios sinteticos (no solo en los N
%              historicos) -- una eleccion deliberada: si se va a
%              proteger contra esos escenarios nunca vistos, tiene
%              sentido que tambien respeten la cota minima de
%              crecimiento. Si se pone false, delta solo se exige sobre
%              los N escenarios historicos, igual que en el modelo
%              nucleo (ecuacion 36).
%
% SALIDAS
%   xk, bk, sk, x0k : igual que en solve_wdro_kelly.m.
%   alpha  : (N x 1) variable dual por escenario de ORIGEN (sigue siendo N,
%            no N+M -- el origen de la masa no cambio).
%   lambda, fval, status : igual que en solve_wdro_kelly.m.

    if nargin < 12 || isempty(apply_delta_to_synthetic)
        apply_delta_to_synthetic = true;
    end
    if nargin < 11 || isempty(solver_name)
        solver_name = 'mosek';
    end

    [N, d] = size(R);
    M = size(R_synth, 1);
    if M > 0 && size(R_synth, 2) ~= d
        error('solve_wdro_kelly_hypercube:dimMismatch', ...
            'R_synth debe tener el mismo numero de columnas (d=%d) que R.', d);
    end

    if ~isequal(size(C), [N, N + M])
        error('solve_wdro_kelly_hypercube:sizeMismatch', ...
            'C debe ser N x (N+M) = %dx%d, pero size(C)=[%d,%d].', ...
            N, N + M, size(C, 1), size(C, 2));
    end
    if rho < 0
        error('solve_wdro_kelly_hypercube:negativeRho', 'rho debe ser >= 0.');
    end

    if isscalar(xbar)
        xbar = xbar * ones(d, 1);
    end
    xbar = xbar(:);

    hk = hk(:);
    h0k = hk(1);
    hjk = hk(2:end);
    if numel(hjk) ~= d
        error('solve_wdro_kelly_hypercube:dimMismatch2', ...
            'hk debe tener d+1 componentes, consistente con R.');
    end

    R_ext = [R; R_synth];          % (N+M) x d, destinos (historicos + sinteticos)
    Rext_plus1 = 1 + R_ext;
    NM = N + M;

    cvx_begin quiet
        cvx_solver(solver_name)
        variables xjk(d) bjk(d) sjk(d) x0k lambda
        variable alpha_k(N)
        expression Gext(NM)
        expression logGext(NM)

        Gext = x0k * (1 + rf) + Rext_plus1 * xjk;   % (N+M) x 1, un valor por DESTINO
        logGext = log(Gext);

        maximize( (1 / N) * sum(alpha_k) - rho * lambda )
        subject to
            % alpha_r <= log(G_s) + lambda*C(r,s), para r=1..N (origenes),
            % s=1..N+M (destinos). Vectorizado como matriz N x (N+M):
            alpha_k * ones(1, NM) - lambda * C <= ones(N, 1) * logGext';

            xjk == hjk + bjk - sjk;
            x0k == h0k - sum(bjk) + sum(sjk) - tau * sum(bjk + sjk);

            xjk >= 0;
            xjk <= xbar;
            sum(xjk) <= gamma;

            if apply_delta_to_synthetic
                Gext >= delta;                  % N+M restricciones
            else
                Gext(1:N) >= delta;             % solo las N historicas
            end

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
        warning('solve_wdro_kelly_hypercube:notSolved', ...
            'CVX status = %s en esta fecha (revisar factibilidad de delta o escala de rho/C).', ...
            status);
    end
end
