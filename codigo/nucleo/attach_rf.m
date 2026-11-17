function results = attach_rf(results, data)
% ATTACH_RF  Anade results.rf (T_dec x 1) a un `results` COMPLETO guardado
% antes de que los run_backtest_*.m registraran la tasa: rf(i) es
% data.rf_return en la fecha de decision results.dates(i), la misma r^f_k
% que uso el backtest para el activo de bajo riesgo en el mes k+1.
% Aplicarlo ANTES de extract_period_results.m (que recorta rf si existe).
%
% ENTRADAS
%   results : struct de run_backtest_*.m (dates = fechas de decision)
%   data    : struct de load_monthly_data.m

    [tf, loc] = ismember(results.dates, data.dates);
    if ~all(tf)
        error('attach_rf:dateMismatch', ...
            '%d fechas de decision de results no estan en data.dates.', sum(~tf));
    end
    results.rf = data.rf_return(loc);
end
