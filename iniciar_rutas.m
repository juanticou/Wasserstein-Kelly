%% INICIAR_RUTAS  Agrega codigo/ y sus subcarpetas al path de MATLAB.
% Correr una vez por sesion desde la raiz del proyecto. Cada script del
% pipeline tambien agrega estas rutas por su cuenta.
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), 'codigo')));
fprintf('Rutas de codigo/ agregadas. Raiz del proyecto: %s\n', raiz_proyecto());
