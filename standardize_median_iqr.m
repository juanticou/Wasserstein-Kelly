function z_std = standardize_median_iqr(z, eps_esc)
% STANDARDIZE_MEDIAN_IQR  Estandarizacion robusta mediana/IQR (ecuacion 40).
%
%   z_std = (z - mediana(z)) / max(IQR(z), eps_esc)
%
% ENTRADAS
%   z        : (N x 1) o (N x d) valores a estandarizar. Si es una matriz,
%              cada columna se estandariza de forma independiente (esto
%              cubre tanto una variable escalar como el bloque de retornos
%              de d acciones, ecuacion 41).
%   eps_esc  : escalar > 0, constante pequena para evitar division por cero
%              (default: 1e-6).
%
% SALIDA
%   z_std : misma forma que z, con cada columna estandarizada usando
%           UNICAMENTE los datos de esa columna (es decir, usando solo la
%           ventana Dk vigente en la fecha k; no debe reutilizarse across
%           fechas).

    if nargin < 2 || isempty(eps_esc)
        eps_esc = 1e-6;
    end

    med = median(z, 1);
    q = prctile(z, [25, 75], 1);
    iqr_ = q(2, :) - q(1, :);
    scale = max(iqr_, eps_esc);

    z_std = (z - med) ./ scale;
end
