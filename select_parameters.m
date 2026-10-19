function sel = select_parameters(T, phi_min, TOL, include_eta0)
% SELECT_PARAMETERS  Regla de seleccion de (delta, eta) fijada a priori
% (T9), aplicada a la tabla maestra de VALIDACION de UNA geometria
% (build_grid_summary_table.m / rebuild_validation_tables.m):
%
%   1. Elegibles: solo eta > 0 (salvo include_eta0 = true, solo para el
%      analisis de sensibilidad).
%   2. Fraccion de meses con solucion optima (fraccion_factible) >= phi_min.
%   3. Maximizar la riqueza final de validacion.
%   4. Empate si (W_max - W) / W_max < TOL; desempate: menor eta y luego
%      mayor delta.
%
% ENTRADAS
%   T            : table con columnas delta, eta, riqueza_final, fraccion_factible
%   phi_min      : umbral de la fraccion de meses optimos (p. ej. 0.95)
%   TOL          : tolerancia relativa de empate en riqueza final
%   include_eta0 : (opcional) default false
%
% SALIDA (struct)
%   chosen     : fila de T elegida
%   tied       : filas empatadas con el maximo (ordenadas por el desempate)
%   eligible   : filas elegibles, ordenadas por riqueza descendente
%   W_max      : riqueza maxima entre las elegibles
%   reason     : texto con la razon de la eleccion

    if nargin < 4 || isempty(include_eta0)
        include_eta0 = false;
    end

    mask = T.fraccion_factible >= phi_min;
    if ~include_eta0
        mask = mask & T.eta > 0;
    end
    E = T(mask, :);
    if isempty(E)
        error('select_parameters:noEligible', 'Ninguna celda cumple los criterios de elegibilidad.');
    end
    E = sortrows(E, 'riqueza_final', 'descend');

    W_max = E.riqueza_final(1);
    rel_gap = (W_max - E.riqueza_final) / W_max;
    tied = E(rel_gap < TOL, :);
    tied.brecha_rel_vs_max = rel_gap(rel_gap < TOL);

    % Desempate: menor eta, luego mayor delta.
    [~, order] = sortrows([tied.eta, -tied.delta]);
    tied = tied(order, :);
    sel.chosen = tied(1, :);
    sel.tied = tied;
    sel.eligible = E;
    sel.W_max = W_max;

    if height(tied) == 1
        sel.reason = "maxima riqueza, sin empate";
    elseif sel.chosen.riqueza_final == W_max
        sel.reason = sprintf("maxima riqueza; %d celdas empatadas (TOL=%g) y gana por menor eta / mayor delta", ...
            height(tied), TOL);
    else
        sel.reason = sprintf("empate de %d celdas (TOL=%g); desempate por menor eta y luego mayor delta", ...
            height(tied), TOL);
    end
end
