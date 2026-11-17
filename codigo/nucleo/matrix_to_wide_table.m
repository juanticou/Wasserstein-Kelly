function T = matrix_to_wide_table(M, delta_grid, eta_grid)
% MATRIX_TO_WIDE_TABLE  Convierte una matriz (nd x ne) indexada por
% delta (filas) y eta (columnas) en una tabla ancha de MATLAB, con una
% columna 'delta' y una columna por cada valor de eta -- el formato
% "tabla" (no heatmap) para exportar varianza, CVaR, etc. a CSV.
%
% ENTRADAS
%   M          : (nd x ne) matriz de una metrica (p.ej. grid.Variance_wdro)
%   delta_grid : (nd x 1) o (1 x nd) valores de delta, filas de M
%   eta_grid   : (ne x 1) o (1 x ne) valores de eta, columnas de M
%
% SALIDA
%   T : table con columnas {'delta', 'eta_<v1>', 'eta_<v2>', ...}

    eta_names = arrayfun(@(v) matlab.lang.makeValidName(sprintf('eta_%g', v)), ...
        eta_grid, 'UniformOutput', false);

    T = array2table(M, 'VariableNames', eta_names);
    T = addvars(T, delta_grid(:), 'Before', 1, 'NewVariableNames', 'delta');
end
