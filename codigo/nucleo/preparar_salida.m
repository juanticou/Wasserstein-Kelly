function preparar_salida(cfg, out_dir)
% PREPARAR_SALIDA  Crea out_dir y protege los resultados historicos.
%
% Con la raiz historica (cfg.is_default) no se escribe en una carpeta que
% ya tenga archivos, para no sobrescribir resultados existentes. Para
% permitirlo a proposito: setenv('WK_PERMITIR_SOBRESCRIBIR', '1').
% Con una raiz nueva (WK_RESULTS_ROOT) varios scripts comparten carpeta
% (p. ej. results_verificaciones), asi que ahi no se bloquea.

    if exist(out_dir, 'dir')
        listing = dir(out_dir);
        has_files = any(~ismember({listing.name}, {'.', '..'}));
        if cfg.is_default && has_files && ~strcmp(getenv('WK_PERMITIR_SOBRESCRIBIR'), '1')
            error('preparar_salida:wouldOverwrite', ...
                ['%s ya tiene resultados historicos. Usa WK_RESULTS_ROOT para escribir en una ', ...
                 'raiz nueva, o WK_PERMITIR_SOBRESCRIBIR=1 si de verdad quieres sobrescribir.'], out_dir);
        end
    else
        mkdir(out_dir);
    end
end
