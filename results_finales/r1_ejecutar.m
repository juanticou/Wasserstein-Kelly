function r1_ejecutar(pasos)
% R1_EJECUTAR  Corre pasos del pipeline (ver MANIFIESTO.md) con el panel
% hibrido del cierre del 31-dic-2025 y la raiz de resultados results_v2/.
% Ejemplo:  r1_ejecutar({'main_grid_delta_eta', 'main_validation_grid'})
% Cada paso corre en su propio espacio de trabajo y deja un log con su tiempo.

    root = fileparts(fileparts(mfilename('fullpath')));
    cd(root);
    addpath(root);
    addpath(fullfile(root, 'wdro-market'));
    setenv('WK_PANEL', fullfile(root, 'data', 'processed_2026-01-01', 'monthly_panel_hibrido.csv'));
    setenv('WK_RESULTS_ROOT', fullfile(root, 'results_v2'));
    if ~exist(fullfile(root, 'results_v2'), 'dir')
        mkdir(fullfile(root, 'results_v2'));
    end
    log_path = fullfile(root, 'results_v2', 'log_ejecucion.csv');

    for p = 1:numel(pasos)
        paso = pasos{p};
        fprintf('\n===== %s =====\n', paso);
        t0 = tic;
        correr(paso);
        t = toc(t0);
        fprintf('===== %s: %.1f s =====\n', paso, t);
        fid = fopen(log_path, 'a');
        fprintf(fid, '%s,%s,%.1f\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), paso, t);
        fclose(fid);
        close all;
    end
end

function correr(paso)
% Espacio de trabajo propio: los scripts empiezan con `clear` o dejan variables.
    run(which([paso '.m']));
end
