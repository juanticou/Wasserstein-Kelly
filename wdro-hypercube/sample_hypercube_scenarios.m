function [R_synth, box_min, box_max] = sample_hypercube_scenarios(R, M, rng_seed)
% SAMPLE_HYPERCUBE_SCENARIOS  Genera M escenarios sinteticos de retornos
% muestreando UNIFORMEMENTE dentro del hipercubo cuyas esquinas son el
% minimo y el maximo historico de CADA activo, observados dentro de la
% ventana R. Estos puntos nunca fueron observados literalmente, pero
% quedan dentro del rango que la historia reciente ya mostro posible
% para cada activo por separado.
%
% ADVERTENCIA METODOLOGICA (importante para discutir en el documento):
% el muestreo es independiente por columna (activo), por lo que NO
% preserva la estructura de correlacion entre activos. Esto puede
% producir escenarios economicamente implausibles -- por ejemplo, los 10
% activos simultaneamente en su maximo historico, una combinacion que
% nunca ocurrio y que probablemente sobreestima el riesgo conjunto. Es
% una eleccion de diseno deliberada (mas simple, y mas "adversarial" en
% el sentido de que amplia el espacio de peores casos), no un intento de
% simular una distribucion conjunta realista.
%
% ENTRADAS
%   R        : (N x d) retornos historicos de la ventana Dk.
%   M        : numero de escenarios sinteticos a generar.
%   rng_seed : (opcional) semilla para reproducibilidad. Si se omite, se
%              usa el generador de aleatorios actual sin fijar semilla
%              (cada corrida da escenarios sinteticos distintos).
%
% SALIDAS
%   R_synth : (M x d) escenarios sinteticos, cada fila dentro del
%             hipercubo [box_min, box_max].
%   box_min, box_max : (1 x d) las esquinas del hipercubo usadas.

    if nargin >= 3 && ~isempty(rng_seed)
        rng(rng_seed);
    end

    [~, d] = size(R);
    box_min = min(R, [], 1);
    box_max = max(R, [], 1);

    if any(box_max <= box_min)
        warning('sample_hypercube_scenarios:degenerateBox', ...
            ['Al menos un activo tiene max <= min en esta ventana (posible ', ...
             'columna constante); el hipercubo sera degenerado en esa dimension.']);
    end

    U = rand(M, d);   % uniforme en [0,1]^d
    R_synth = box_min + U .* (box_max - box_min);
end
