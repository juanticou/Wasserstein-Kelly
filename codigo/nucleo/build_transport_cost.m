function [C, Rstd] = build_transport_cost(R, eps_esc)
% BUILD_TRANSPORT_COST  Geometria 1 de la propuesta (Seccion 9.2, ecuacion
% 42): distancia de transporte entre escenarios historicos basada
% UNICAMENTE en los retornos estandarizados de las acciones.
%
%   c^R_{k,rs} = (1/d) * || rtilde_r - rtilde_s ||_1
%
% donde rtilde son los retornos estandarizados con mediana y rango
% intercuartilico DENTRO de la ventana (ecuacion 41):
%
%   rtilde_{j,s} = (r_{j,s} - mediana_s{r_{j,.}}) / max(IQR_s{r_{j,.}}, eps_esc)
%
% ENTRADAS
%   R        : (N x d) retornos simples de la ventana Dk (un escenario por
%              fila, un activo por columna). Los valores originales NO se
%              modifican; la estandarizacion es solo para la geometria.
%   eps_esc  : (opcional) constante pequena para evitar division por cero
%              cuando el IQR de un activo es practicamente nulo.
%              Default: 1e-6.
%
% SALIDAS
%   C        : (N x N) matriz de costos de transporte, C(r,s) = c^R_{k,rs}.
%              Simetrica, con diagonal exactamente cero (ecuacion: c_ss=0).
%   Rstd     : (N x d) retornos estandarizados (por si se quieren
%              inspeccionar o reusar para la geometria 2/3).
%
% NOTA: todas las medianas y IQR se recalculan usando UNICAMENTE la
% ventana R que se recibe; nunca datos posteriores a la fecha de decision
% (consistente con la Seccion 9.4 de la propuesta).

    if nargin < 2 || isempty(eps_esc)
        eps_esc = 1e-6;
    end

    [N, d] = size(R);

    % --- Estandarizacion por mediana / IQR, columna por columna (ecuacion 41) ---
    med = median(R, 1);                    % (1 x d)
    q1  = prctile(R, 25, 1);                % (1 x d)
    q3  = prctile(R, 75, 1);                % (1 x d)
    iqr_vals = q3 - q1;                     % (1 x d)
    denom = max(iqr_vals, eps_esc);         % evita division por cero

    Rstd = (R - med) ./ denom;              % (N x d), broadcasting por fila

    if any(iqr_vals <= eps_esc)
        cols = find(iqr_vals <= eps_esc);
        warning('build_transport_cost:lowIQR', ...
            ['El IQR de las columnas [%s] es practicamente nulo en esta ventana; ' ...
             'se uso eps_esc=%.1e como denominador. Revisar si esos activos ' ...
             'aportan informacion suficiente para la geometria.'], ...
            num2str(cols), eps_esc);
    end

    % --- Distancia L1 promedio entre escenarios estandarizados (ecuacion 42) ---
    % C(r,s) = (1/d) * sum_j |Rstd(r,j) - Rstd(s,j)|
    if exist('pdist', 'file') == 2
        % Ruta vectorizada (Statistics and Machine Learning Toolbox)
        C = squareform(pdist(Rstd, 'cityblock')) / d;
    else
        % Ruta sin dependencias del toolbox de estadistica
        C = zeros(N, N);
        for r = 1:N
            diffs = abs(Rstd(r, :) - Rstd);     % (N x d), broadcasting
            C(r, :) = sum(diffs, 2) / d;
        end
    end

    % La diagonal debe ser exactamente cero; se fuerza por robustez numerica.
    C(1:N+1:end) = 0;
end
