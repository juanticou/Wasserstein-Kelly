function cfg = config_rutas()
% CONFIG_RUTAS  Rutas de datos y resultados del proyecto.
%
% Sin configurar nada devuelve las rutas historicas:
%   panel        : <proyecto>/data/processed/monthly_panel.csv
%   results_root : <proyecto>/resultados/linea_base  (results_* y wdro-market/results_* cuelgan de aqui)
%
% Para regenerar con otros datos sin tocar lo existente, antes de correr
% cualquier script del pipeline (ver resultados/finales/MANIFIESTO.md):
%   setenv('WK_PANEL', fullfile(pwd, 'data', 'processed_2026-01-01', 'monthly_panel.csv'));
%   setenv('WK_RESULTS_ROOT', fullfile(pwd, 'resultados', 'v2'));
% Se usan variables de entorno porque los scripts empiezan con `clear` y
% no reciben argumentos. Para volver a las rutas historicas:
%   setenv('WK_PANEL', ''); setenv('WK_RESULTS_ROOT', '');
%
% SALIDA (struct):
%   cfg.project_dir  : carpeta raiz del proyecto (ver raiz_proyecto.m)
%   cfg.panel        : ruta del panel mensual
%   cfg.results_root : raiz de las carpetas de resultados
%   cfg.is_default   : true si results_root es la raiz historica

    cfg.project_dir = raiz_proyecto();

    cfg.panel = getenv('WK_PANEL');
    if isempty(cfg.panel)
        cfg.panel = fullfile(cfg.project_dir, 'data', 'processed', 'monthly_panel.csv');
    end
    if ~isfile(cfg.panel)
        error('config_rutas:panelNotFound', 'No se encontro el panel:\n  %s', cfg.panel);
    end

    cfg.results_root = getenv('WK_RESULTS_ROOT');
    cfg.is_default = isempty(cfg.results_root);
    if cfg.is_default
        cfg.results_root = fullfile(cfg.project_dir, 'resultados', 'linea_base');
    elseif strcmpi(strip(cfg.results_root, 'right', filesep), cfg.project_dir)
        error('config_rutas:rootIsProject', ...
            'WK_RESULTS_ROOT apunta a la carpeta del proyecto; dejala vacia para usar la raiz historica.');
    end
end
