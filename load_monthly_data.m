function data = load_monthly_data(csv_path, tickers)
% LOAD_MONTHLY_DATA  Lee el panel mensual construido en Python
% (data/processed/monthly_panel.csv) y lo deja listo para MATLAB.
%
% Se espera un CSV con:
%   - primera columna: fecha (fin de mes)
%   - una columna por cada ticker en `tickers`, con retornos simples
%     mensuales r_{j,m}
%   - columna 'mkt_return'  (retorno mensual de SPY, ecuacion 56)
%   - columna 'vix'         (VIX de fin de mes, ecuacion 57)
%   - columna 'rf_return'   (r^f_k mensual, ecuacion 58)
%
% SALIDA (struct):
%   data.dates      : (T x 1) datetime
%   data.R          : (T x d) retornos simples de las acciones, mismo
%                     orden que `tickers`
%   data.tickers    : cell array con los nombres de columnas usados
%   data.mkt_return : (T x 1)
%   data.vix        : (T x 1)
%   data.rf_return  : (T x 1)

    T_ = readtable(csv_path, 'ReadRowNames', false);

    % La primera columna suele llamarse 'Var1' o el nombre del indice
    % original ('Date'); la identificamos por tipo de dato.
    dateCol = find(varfun(@(x) isdatetime(x) || iscellstr(x) || isstring(x), ...
        T_, 'OutputFormat', 'uniform'), 1, 'first');
    if isempty(dateCol)
        dateCol = 1;
    end
    dates = T_{:, dateCol};
    if ~isdatetime(dates)
        dates = datetime(dates);
    end

    missingTickers = setdiff(tickers, T_.Properties.VariableNames);
    if ~isempty(missingTickers)
        error('load_monthly_data:missingColumns', ...
            'No se encontraron columnas para: %s', strjoin(missingTickers, ', '));
    end

    R = T_{:, tickers};

    requiredCols = {'mkt_return', 'vix', 'rf_return'};
    for i = 1:numel(requiredCols)
        if ~ismember(requiredCols{i}, T_.Properties.VariableNames)
            error('load_monthly_data:missingColumns', ...
                'Falta la columna requerida "%s" en %s', requiredCols{i}, csv_path);
        end
    end

    data.dates      = dates;
    data.R          = R;
    data.tickers    = tickers;
    data.mkt_return = T_.mkt_return;
    data.vix        = T_.vix;
    data.rf_return  = T_.rf_return;
end
