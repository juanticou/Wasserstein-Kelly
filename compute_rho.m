function rho_k = compute_rho(C, eta)
% COMPUTE_RHO  Radio efectivo de la bola de Wasserstein en la fecha k,
% ecuacion 63 de la propuesta:
%
%   rho_k = eta * mediana{ C(r,s) : r < s, C(r,s) > 0 }
%
% Esta normalizacion ancla el radio a la escala tipica de distancias entre
% escenarios DENTRO de la ventana actual, para que el mismo eta represente
% un nivel de robustez comparable en ventanas con distinta volatilidad.
%
% ENTRADAS
%   C   : (N x N) matriz de costos de transporte (salida de
%         build_transport_cost.m para la ventana Dk).
%   eta : escalar >= 0, intensidad relativa de robustez. Malla nucleo del
%         Cuadro 8: eta = 0 (nominal), 0.05, 0.15, 0.30.
%
% SALIDA
%   rho_k : escalar >= 0, radio de Wasserstein para usar en solve_wdro_kelly.

    if eta < 0
        error('compute_rho:negativeEta', 'eta debe ser >= 0.');
    end

    N = size(C, 1);
    mask = triu(true(N), 1);          % solo r < s, sin repetir pares
    upper_vals = C(mask);
    positive_vals = upper_vals(upper_vals > 0);

    if isempty(positive_vals)
        warning('compute_rho:allZero', ...
            ['Todos los costos fuera de la diagonal son cero en esta ventana; ', ...
             'no se puede normalizar rho_k con la mediana. Se retorna rho_k = 0.']);
        rho_k = 0;
        return
    end

    rho_k = eta * median(positive_vals);
end
