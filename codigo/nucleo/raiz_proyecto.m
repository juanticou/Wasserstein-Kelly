function root = raiz_proyecto()
% RAIZ_PROYECTO  Carpeta raiz del repositorio Wasserstein-Kelly.
%
% Este archivo vive en <raiz>/codigo/nucleo/, asi que la raiz esta dos
% niveles por encima de su carpeta. Todas las rutas a data/ y resultados/
% se construyen a partir de aqui.

    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
