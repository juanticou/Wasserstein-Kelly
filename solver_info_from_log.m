function info = solver_info_from_log(log_txt, cvx_stat, slvtol, slvitr, prec)
% SOLVER_INFO_FROM_LOG  Empaqueta el estado del solucionador de una fecha:
% el cvx_status, la tolerancia alcanzada y la precision pedida a CVX, y el
% estado NATIVO de MOSEK leido del log que imprime cvx_end (capturado con
% evalc en solve_nominal_kelly.m / solve_wdro_kelly.m). CVX no expone el
% estado de MOSEK como variable, por eso se lee del texto; si no aparece
% (otro solucionador, log vacio) queda 'no disponible'.
%
% SALIDA (struct)
%   cvx_status            : p. ej. 'Solved', 'Inaccurate/Solved', 'Failed'
%   status_class          : classify_solver_status(cvx_status)
%   mosek_problem_status  : p. ej. 'PRIMAL_AND_DUAL_FEASIBLE'
%   mosek_solution_status : p. ej. 'OPTIMAL'
%   cvx_slvtol, cvx_slvitr, cvx_precision : ver documentacion de CVX

    info.cvx_status   = cvx_stat;
    info.status_class = classify_solver_status(cvx_stat);
    info.mosek_problem_status  = read_field(log_txt, 'Problem status');
    info.mosek_solution_status = read_field(log_txt, 'Solution status');
    info.cvx_slvtol    = slvtol;
    info.cvx_slvitr    = slvitr;
    info.cvx_precision = prec;
end


function val = read_field(txt, key)
% Toma la ULTIMA ocurrencia de "key : VALOR" (MOSEK puede imprimir varios
% resumenes, p. ej. interior-point y basic; el ultimo es el reportado).
    tok = regexp(txt, [key, '\s*:\s*([A-Z_]+)'], 'tokens');
    if isempty(tok)
        val = 'no disponible';
    else
        val = tok{end}{1};
    end
end
