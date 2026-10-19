function cls = classify_solver_status(status)
% CLASSIFY_SOLVER_STATUS  Clasifica el estado devuelto por CVX/MOSEK en
% cada fecha en {optimo, inaccurate, infeasible_certificado, fallo_numerico}
% (seccion "Backtest de origen movil" de metodologia_2.tex).
%
%   'Solved'            -> 'optimo'
%   'Inaccurate/Solved' -> 'inaccurate'
%   'Infeasible'        -> 'infeasible_certificado'
%   cualquier otro      -> 'fallo_numerico' ('Inaccurate/Infeasible',
%                          'Failed', 'Unbounded', 'Overdetermined', vacio...)
%
% Con delta <= 0.90 el problema es siempre factible (ir todo a bajo riesgo
% da G_ks >= 0.999(1+r^f) > delta), asi que un 'Infeasible' tampoco seria
% infactibilidad teorica: se separa solo porque el solucionador lo
% certifico. Solo 'optimo' rebalancea; las demas clases son "mes sin
% optimizacion" (se mantiene el portafolio heredado) en todas las
% estrategias.
%
% ENTRADA
%   status : char o cell array de cvx_status (uno por mes)
% SALIDA
%   cls    : cell array del mismo tamano (o char si status es char)

    was_char = ischar(status);
    if was_char
        status = {status};
    end

    cls = repmat({'fallo_numerico'}, size(status));
    for i = 1:numel(status)
        s = status{i};
        if ~ischar(s) && ~isstring(s)
            continue
        end
        switch char(s)
            case 'Solved'
                cls{i} = 'optimo';
            case 'Inaccurate/Solved'
                cls{i} = 'inaccurate';
            case 'Infeasible'
                cls{i} = 'infeasible_certificado';
        end
    end

    if was_char
        cls = cls{1};
    end
end
