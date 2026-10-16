function data_t = truncate_data(data, end_date)
% TRUNCATE_DATA  Recorta el struct de load_monthly_data.m para que SOLO
% contenga filas con fecha <= end_date. Como cada decision del backtest de
% origen movil solo mira hacia atras, correr el backtest sobre estos datos
% recortados da exactamente las mismas decisiones que correrlo sobre los
% datos completos y mirar solo hasta end_date -- pero con una garantia
% fisica de que el codigo nunca tuvo acceso al periodo posterior (util
% para que la seleccion de parametros en validacion no pueda tocar el
% periodo de prueba, ni siquiera por accidente).
%
% ENTRADAS
%   data     : struct de load_monthly_data.m (dates, R, tickers,
%              mkt_return, vix, rf_return)
%   end_date : datetime, ultima fecha (inclusive) que se conserva
%
% SALIDA
%   data_t : mismo struct con todas las series recortadas

    keep = data.dates <= end_date;
    if ~any(keep)
        error('truncate_data:empty', 'Ninguna fecha de data es <= %s.', datestr(end_date));
    end
    data_t = data;
    data_t.dates      = data.dates(keep);
    data_t.R          = data.R(keep, :);
    data_t.mkt_return = data.mkt_return(keep);
    data_t.vix        = data.vix(keep);
    data_t.rf_return  = data.rf_return(keep);
end
