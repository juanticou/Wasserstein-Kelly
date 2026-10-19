function out = bootstrap_block_diff(GA, GB, ell, B, seed)
% BOOTSTRAP_BLOCK_DIFF  Bootstrap movil por bloques (Kunsch, 1989) para
% la media de las diferencias mensuales pareadas del crecimiento
% logaritmico entre dos estrategias (seccion "Inferencia sobre las
% diferencias" de metodologia_2.tex):
%
%   D_k = log G^A_k - log G^B_k
%
% Se remuestrean bloques SOLAPADOS de ell meses consecutivos. Cada bloque
% toma los mismos meses de A y de B, de modo que los dos resultados de un
% mismo mes se mueven juntos (no se remuestrea cada estrategia por
% separado). En cada replica se concatenan ceil(T/ell) bloques con inicio
% uniforme en {1, ..., T-ell+1} y se trunca a T meses; el estadistico es
% la media de D en la replica. El intervalo del 95 % es el percentil
% 2.5-97.5 de las B medias.
%
% ENTRADAS
%   GA, GB : (T x 1) factores de crecimiento realizados G^real, alineados
%            por mes (mismo mes en la misma fila), todos > 0
%   ell    : (opcional) longitud de bloque. Default 6.
%   B      : (opcional) numero de replicas. Default 10000.
%   seed   : (opcional) semilla del generador. Default 20261019. Se usa un
%            RandStream propio, asi que no altera el generador global.
%
% SALIDA (struct)
%   n, ell, B, seed
%   mean_D, median_D, prop_D_pos  : estadisticos de la muestra original
%   n_ties                        : meses con |D_k| < 1e-6 (empates numericos)
%   ci_lo, ci_hi                  : percentiles 2.5 y 97.5 de las medias
%   boot_se                       : desviacion estandar de las medias bootstrap
%   boot_means                    : (B x 1) medias bootstrap

    if nargin < 3 || isempty(ell),  ell = 6;          end
    if nargin < 4 || isempty(B),    B = 10000;        end
    if nargin < 5 || isempty(seed), seed = 20261019;  end

    GA = GA(:); GB = GB(:);
    T = numel(GA);
    if numel(GB) ~= T
        error('bootstrap_block_diff:sizeMismatch', 'GA y GB deben tener la misma longitud.');
    end
    if any(GA <= 0) || any(GB <= 0)
        error('bootstrap_block_diff:nonPositive', 'Los factores de crecimiento deben ser > 0.');
    end
    if ell < 1 || ell > T
        error('bootstrap_block_diff:badBlock', 'ell debe estar en [1, T].');
    end

    D = log(GA) - log(GB);

    n_starts = T - ell + 1;
    n_blocks = ceil(T / ell);
    offsets  = 0:(ell - 1);
    stream   = RandStream('mt19937ar', 'Seed', seed);

    boot_means = zeros(B, 1);
    for b = 1:B
        starts = randi(stream, n_starts, n_blocks, 1);
        idx = reshape((starts + offsets)', [], 1);   % bloques concatenados
        idx = idx(1:T);
        % Mismos meses para A y B: el par se remuestrea junto.
        boot_means(b) = mean(log(GA(idx)) - log(GB(idx)));
    end

    out.n          = T;
    out.ell        = ell;
    out.B          = B;
    out.seed       = seed;
    out.mean_D     = mean(D);
    out.median_D   = median(D);
    out.prop_D_pos = mean(D > 0);
    out.n_ties     = sum(abs(D) < 1e-6);
    out.ci_lo      = prctile(boot_means, 2.5);
    out.ci_hi      = prctile(boot_means, 97.5);
    out.boot_se    = std(boot_means);
    out.boot_means = boot_means;
end
