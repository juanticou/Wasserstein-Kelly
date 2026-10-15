function [C, R_ext, info] = build_transport_cost_hypercube(R, R_synth, eps_esc)
% BUILD_TRANSPORT_COST_HYPERCUBE  Matriz de costos de transporte
% RECTANGULAR (N x (N+M)): el origen de la masa sigue siendo los N
% escenarios historicos (la distribucion empirica, 1/N cada uno, igual
% que en el modelo nucleo); el DESTINO se amplia a los N historicos MAS
% los M escenarios sinteticos del hipercubo (sample_hypercube_scenarios.m).
%
% Esta es la generalizacion directa de build_transport_cost.m (Geometria
% 1, ecuacion 42) que relaja la restriccion supp(Q) subconjunto de los
% escenarios historicos (Seccion 10.3): ahora el adversario puede mover
% probabilidad hacia puntos nunca observados, siempre que esten dentro
% del hipercubo.
%
% La estandarizacion (mediana, IQR) se calcula UNICAMENTE con la ventana
% historica R -- nunca con los escenarios sinteticos, que a su vez se
% estandarizan con esas MISMAS estadisticas (consistente con la Seccion
% 9.4: todas las estadisticas vienen solo de Dk, y los sinteticos son
% derivados de Dk, no de informacion externa).
%
% ENTRADAS
%   R        : (N x d) retornos historicos de la ventana Dk.
%   R_synth  : (M x d) escenarios sinteticos (de sample_hypercube_scenarios.m).
%   eps_esc  : (opcional) piso para la estandarizacion (default 1e-6).
%
% SALIDAS
%   C     : (N x (N+M)) matriz de costos de transporte. Las primeras N
%           columnas corresponden a destinos historicos (C(:,1:N) es
%           simetrica con diagonal cero, igual que en Geometria 1); las
%           siguientes M columnas son los destinos sinteticos.
%   R_ext : (N+M x d) retornos extendidos (historicos + sinteticos), en
%           el mismo orden que las columnas de C -- util para evaluar
%           Gks(xk) en TODOS los destinos (ver solve_wdro_kelly_hypercube.m).
%   info  : struct con R_std (historicos estandarizados) y
%           R_synth_std (sinteticos estandarizados, con las MISMAS
%           estadisticas), por si se quieren inspeccionar.

    if nargin < 3 || isempty(eps_esc)
        eps_esc = 1e-6;
    end

    [N, d] = size(R);
    M = size(R_synth, 1);
    if size(R_synth, 2) ~= d
        error('build_transport_cost_hypercube:dimMismatch', ...
            'R_synth debe tener el mismo numero de activos (d=%d) que R.', d);
    end

    med = median(R, 1);
    q = prctile(R, [25 75], 1);
    iqr_ = q(2, :) - q(1, :);
    denom = max(iqr_, eps_esc);

    R_std = (R - med) ./ denom;
    R_synth_std = (R_synth - med) ./ denom;   % MISMAS estadisticas que R

    R_ext_std = [R_std; R_synth_std];   % (N+M) x d, estandarizados

    % Costo: (1/d) * ||r_tilde_r - r_tilde_s||_1, r=1..N (origenes
    % historicos), s=1..N+M (destinos historicos+sinteticos).
    C = zeros(N, N + M);
    for r = 1:N
        C(r, :) = sum(abs(R_std(r, :) - R_ext_std), 2)' / d;
    end
    C(:, 1:N) = C(:, 1:N) - diag(diag(C(:, 1:N)));   % fuerza diagonal exactamente 0
                                                       % (deberia serlo ya, es robustez numerica)

    R_ext = [R; R_synth];
    info.R_std = R_std;
    info.R_synth_std = R_synth_std;
end
