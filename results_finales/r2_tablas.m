function r2_tablas()
% R2_TABLAS  R2: tablas de desempeno de prueba y validacion en CSV, Markdown
% y .tex (\hline, sin booktabs). Solo lee resultados de results_v2/;
% no optimiza nada. Ninguna cifra se escribe a mano.
%
%   (a) prueba, desempeno       (b) prueba, operacion
%   (c) prueba, restricciones   (d) validacion, configuraciones elegidas
%
% La unica cifra que no esta en metricas_por_tramo.csv es "meses con la cota
% delta activa", que se calcula aqui con la regla de diagnostico_seleccion.m
% (min_s G_ks - delta <= 1e-6 en la ventana de 60 meses). Control: sobre
% validacion debe reproducir results_seleccion/diagnostico_cota_delta.csv.
%
% Salidas en results_finales/tablas/: tabla_[a-d]_*.csv/.tex, r2_cota_delta.csv,
% r2_verificacion.csv y TABLAS_R2.md

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root, fullfile(root, 'wdro-market'));
    RES = fullfile(root, 'results_v2');
    PANEL = fullfile(root, 'data', 'processed_2026-01-01', 'monthly_panel_hibrido.csv');
    OUT = fullfile(root, 'results_finales', 'tablas');
    if ~isfolder(OUT), mkdir(OUT); end

    TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
    PERIODS = {'validacion', datetime(2015,1,1), datetime(2018,12,31), 48; ...
               'prueba',     datetime(2019,1,1), datetime(2025,12,31), 84};
    ACTIVE_TOL = 1e-6;
    ORDER = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.80, 0.01)", "G1 (0.90, 0.01)", ...
             "G2 (0.80, 0.01)", "G2 (0.90, 0.01)"];
    CHOSEN = ["G1 (0.90, 0.01)", "G2 (0.80, 0.01)"];          % seleccion de T9

    REF = ["Bajo riesgo", "Igual ponderación", "SPY pasivo", ...
           "Nominal sin costos (0.80)", "Nominal sin costos (0.90)"];   % main_benchmarks.m

    M = readtable(fullfile(RES, 'results_prueba_v2', 'metricas_por_tramo.csv'), 'TextType', 'string');
    assert(all(ismember(ORDER, M.estrategia)), 'Faltan estrategias en metricas_por_tramo.csv.');
    MB = readtable(fullfile(RES, 'results_benchmarks', 'metricas_por_tramo_benchmarks.csv'), ...
        'TextType', 'string', 'Encoding', 'UTF-8');
    assert(isequal(MB.Properties.VariableNames, M.Properties.VariableNames), ...
        'metricas_por_tramo_benchmarks.csv no tiene las columnas de metricas_por_tramo.csv.');
    assert(all(ismember(REF, MB.estrategia)), 'Faltan referencias en metricas_por_tramo_benchmarks.csv.');
    M = [M; MB];

    %% 1. Meses con la cota delta activa (validacion y prueba)
    data = load_monthly_data(PANEL, TICKERS);
    traj = cargar_trayectorias(RES, data);          % results_finales/cargar_trayectorias.m
    rows = {};
    for s = ORDER
        r = traj(char(s));
        for q = 1:size(PERIODS, 1)
            sub = extract_period_results(r, PERIODS{q, 2}, PERIODS{q, 3});
            dec = dateshift(sub.dates, 'end', 'month', -1);       % fecha de decision k
            [tf, kk] = ismember(dec, data.dates);
            assert(all(tf) && numel(kk) == PERIODS{q, 4}, 'Meses del tramo %s inesperados.', PERIODS{q, 1});
            p = sub.params;
            slack = zeros(numel(kk), 1);
            for t = 1:numel(kk)
                k = kk(t);
                Rw = data.R(k - p.N + 1 : k, :);
                G = sub.x0(t) * (1 + data.rf_return(k)) + (1 + Rw) * sub.x(t, :)';
                slack(t) = min(G) - p.delta;
            end
            rows{end + 1} = table(s, string(PERIODS{q, 1}), numel(kk), sum(slack <= ACTIVE_TOL), ...
                min(slack), 'VariableNames', {'estrategia', 'tramo', 'n_meses', ...
                'meses_cota_activa', 'holgura_minima'}); %#ok<AGROW>
        end
    end
    C = vertcat(rows{:});
    writetable(C, fullfile(OUT, 'r2_cota_delta.csv'));

    % Control: validacion reproduce diagnostico_cota_delta.csv (celdas WK)
    D = readtable(fullfile(RES, 'results_seleccion', 'diagnostico_cota_delta.csv'), 'TextType', 'string');
    chk = {};
    for s = ORDER(~startsWith(ORDER, "Nominal"))
        m = M(M.estrategia == s & M.tramo == "validacion", :);
        d = D(D.geometria == m.geometria & abs(D.delta - m.delta) < 1e-12 & abs(D.eta - m.eta) < 1e-12, :);
        c = C(C.estrategia == s & C.tramo == "validacion", :);
        chk{end + 1} = check_row("cota_activa_validacion", s, "meses_cota_activa", ...
            d.meses_cota_activa, c.meses_cota_activa); %#ok<AGROW>
        chk{end + 1} = check_row("cota_activa_validacion", s, "holgura_minima", ...
            d.holgura_minima, c.holgura_minima); %#ok<AGROW>
    end

    %% 2. Especificacion de las tablas: {columna, etiqueta, formato}
    % formatos: pct (x100, 2 dec., %), dec2/dec3/dec4 (decimales), int
    A = {'riqueza_final', 'Riqueza final (base 1)', 'dec3'
         'log_crecimiento_medio', 'Crecimiento logaritmico medio mensual', 'pct'
         'CAGR', 'CAGR', 'pct'
         'max_drawdown', 'Maxima caida (MDD)', 'pct'
         'peor_mes', 'Peor mes', 'pct'
         'VaR_perdida', 'VaR 95 % (perdida mensual)', 'pct'
         'CVaR_perdida', 'CVaR 95 % (perdida mensual)', 'pct'
         'sharpe', 'Sharpe', 'dec3'
         'sortino', 'Sortino', 'dec3'
         'calmar', 'Calmar', 'dec3'};
    B = {'turnover_total', 'Turnover acumulado', 'dec2'
         'n_transacciones', 'Meses con transaccion', 'int'
         'costo_fraccional', 'Costo fraccional acumulado', 'pct'
         'costo_monetario', 'Costo monetario acumulado (riqueza inicial = 1)', 'dec4'
         'peso_max_promedio', 'Peso maximo medio', 'pct'
         'Neff_promedio', 'N_eff medio', 'dec2'
         'proporcion_riesgo_media', 'Proporcion en riesgo media', 'pct'};
    Cc = {'violaciones_delta', 'Meses con factor realizado < delta', 'int'
          'min_factor_crecimiento', 'Minimo factor de crecimiento realizado', 'dec4'
          'meses_cota_activa', 'Meses con la cota delta activa en la ventana', 'int'
          'meses_sin_optimizacion', 'Meses sin optimizacion', 'int'
          'n_meses', 'Meses evaluados', 'int'};
    VAL_ORDER = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.90, 0.01)", "G2 (0.80, 0.01)"];
    E = [A; B(ismember(B(:, 1), {'turnover_total', 'n_transacciones', 'costo_monetario', ...
         'Neff_promedio', 'proporcion_riesgo_media'}), :)];          % tablas (e) y (f)

    % Version .tex: notacion de tab:contrastes (c1 = (0.90, 0.01), c2 = (0.80, 0.01))
    TEX_STRAT = containers.Map( ...
        {'Nominal (0.80)', 'Nominal (0.90)', 'G1 (0.80, 0.01)', 'G1 (0.90, 0.01)', 'G2 (0.80, 0.01)', 'G2 (0.90, 0.01)', ...
         'Bajo riesgo', 'Igual ponderación', 'SPY pasivo', 'Nominal sin costos (0.80)', 'Nominal sin costos (0.90)'}, ...
        {'$\mathrm{Nom}(\delta_2^\star)$', '$\mathrm{Nom}(\delta_1^\star)$', '$G_1(c_2)$', '$G_1(c_1)$', '$G_2(c_2)$', '$G_2(c_1)$', ...
         'Bajo riesgo', 'Igual pond.', 'SPY pasivo', '$\mathrm{Nom}_{\tau=0}(\delta_2^\star)$', '$\mathrm{Nom}_{\tau=0}(\delta_1^\star)$'});
    TEX_ROW = containers.Map( ...
        {'riqueza_final', 'log_crecimiento_medio', 'CAGR', 'max_drawdown', 'peor_mes', 'VaR_perdida', 'CVaR_perdida', ...
         'sharpe', 'sortino', 'calmar', 'turnover_total', 'n_transacciones', 'costo_fraccional', 'costo_monetario', ...
         'peso_max_promedio', 'Neff_promedio', 'proporcion_riesgo_media', 'violaciones_delta', 'min_factor_crecimiento', ...
         'meses_cota_activa', 'meses_sin_optimizacion', 'n_meses'}, ...
        {'Riqueza final ($W_0=1$)', 'Crecimiento logarítmico medio mensual', 'CAGR', 'Máxima caída (MDD)', 'Peor mes', ...
         'VaR 95\,\% (pérdida mensual)', 'CVaR 95\,\% (pérdida mensual)', 'Sharpe', 'Sortino', 'Calmar', ...
         'Turnover acumulado', 'Meses con transacción', 'Costo fraccional acumulado', 'Costo monetario acumulado ($W_0=1$)', ...
         'Peso máximo medio', '$N_{\mathrm{eff}}$ medio', 'Proporción en riesgo media', ...
         'Meses con $G^{\mathrm{real}}<\delta$', 'Mínimo factor de crecimiento realizado', ...
         'Meses con la cota $\delta$ activa en la ventana', 'Meses sin optimización', 'Meses evaluados'});
    TEX_CAPTION = struct( ...
        'tabla_a_prueba_desempeno', 'Prueba 2019--2025: desempeño de las seis estrategias evaluadas.', ...
        'tabla_b_prueba_operacion', 'Prueba 2019--2025: operación y concentración.', ...
        'tabla_c_prueba_restricciones', 'Prueba 2019--2025: restricciones y solucionador.', ...
        'tabla_d_validacion', 'Validación 2015--2018: configuraciones elegidas y Kelly nominal con el mismo $\delta$.', ...
        'tabla_e_prueba_referencias', 'Prueba 2019--2025: estrategias de referencia.', ...
        'tabla_f_validacion_referencias', 'Validación 2015--2018: estrategias de referencia.');
    TEX_NOTE = "$c_1=(0.90,\,0.01)$, $c_2=(0.80,\,0.01)$, $\delta_1^\star=0.90$, $\delta_2^\star=0.80$; $^{\dagger}$~configuración elegida en validación.";
    TEX_NOTE_REF = "$\mathrm{Nom}_{\tau=0}$: Kelly nominal sin costos ($\tau=0$), con turnover canónico $\sum_j|x_{jk}-h_{jk}|$; " + ...
        "$\delta_1^\star=0.90$, $\delta_2^\star=0.80$. Igual ponderación: $1/d$ en cada acción, rebalanceo mensual con $\tau=0.001$. " + ...
        "SPY pasivo: comprar y mantener, con costo solo en la compra inicial (diciembre de 2014). " + ...
        "---: no definido (sin exposición riesgosa o sin variación del exceso sobre $r^f$) o no aplica (SPY no pertenece al universo de diez acciones).";

    % metricas_por_tramo + cota activa en una sola tabla de consulta
    M = outerjoin(M, C(:, {'estrategia', 'tramo', 'meses_cota_activa'}), ...
        'Keys', {'estrategia', 'tramo'}, 'MergeKeys', true);

    tabs = {'tabla_a_prueba_desempeno', '(a) Prueba 2019-2025: desempeno', 'prueba', ORDER, A, TEX_NOTE
            'tabla_b_prueba_operacion', '(b) Prueba 2019-2025: operacion y concentracion', 'prueba', ORDER, B, TEX_NOTE
            'tabla_c_prueba_restricciones', '(c) Prueba 2019-2025: restricciones y solucionador', 'prueba', ORDER, Cc, TEX_NOTE
            'tabla_d_validacion', '(d) Validacion 2015-2018: configuraciones elegidas y nominal', 'validacion', VAL_ORDER, [A; B], TEX_NOTE
            'tabla_e_prueba_referencias', '(e) Prueba 2019-2025: estrategias de referencia', 'prueba', REF, E, TEX_NOTE_REF
            'tabla_f_validacion_referencias', '(f) Validacion 2015-2018: estrategias de referencia', 'validacion', REF, E, TEX_NOTE_REF};

    md = ["# Tablas R2 (generadas por `results_finales/r2_tablas.m`)", "", ...
          "Fuente: `results_v2/results_prueba_v2/metricas_por_tramo.csv`; la fila de cota delta activa sale de `r2_cota_delta.csv`. " + ...
          "† = configuracion elegida en validacion (T9). Porcentajes con 2 decimales; las cifras exactas estan en los CSV.", "", ...
          "Tablas (e) y (f): `results_v2/results_benchmarks/metricas_por_tramo_benchmarks.csv` (main_benchmarks.m). " + ...
          "Nominal sin costos = Kelly nominal con tau = 0 y turnover canonico; — = no definido o no aplica.", ""];
    for t = 1:size(tabs, 1)
        [name, title, tramo, strat, spec, note] = tabs{t, :};
        vals = zeros(size(spec, 1), numel(strat));
        for j = 1:numel(strat)
            row = M(M.estrategia == strat(j) & M.tramo == tramo, :);
            assert(height(row) == 1);
            for i = 1:size(spec, 1)
                vals(i, j) = row.(spec{i, 1});
            end
        end
        hdr = strat; hdr(ismember(strat, CHOSEN)) = hdr(ismember(strat, CHOSEN)) + " †";

        % CSV exacto: metrica en filas, estrategias en columnas
        cellout = [{'metrica', 'columna_fuente'}, cellstr(hdr); spec(:, 2), spec(:, 1), num2cell(vals)];
        writecell(cellout, fullfile(OUT, [name '.csv']));

        % Markdown y verificacion del texto impreso
        md = [md, "## " + title, "", "CSV: `" + name + ".csv`; .tex: `" + name + ".tex`", "", ...
              "| Metrica | " + strjoin(hdr, " | ") + " |", ...
              "|---|" + strjoin(repmat("---:", 1, numel(strat)), "|") + "|"]; %#ok<AGROW>
        thdr = arrayfun(@(s) "\textbf{" + regexprep(string(TEX_STRAT(char(s))), '\$$', ...
            ifelse(ismember(s, CHOSEN), '^{\\dagger}\$', '\$')) + "}", strat);
        tex = ["% Generado por results_finales/r2_tablas.m; no editar a mano.", ...
               "\begin{table}[h]", "\centering", "\footnotesize", "\setlength{\tabcolsep}{4pt}", ...
               "\caption{" + TEX_CAPTION.(name) + " " + note + "}\label{tab:r2_" + name(7) + "}", ...
               "\begin{tabular}{|l|" + strjoin(repmat("r", 1, numel(strat)), "|") + "|}", "\hline", ...
               "\textbf{Métrica} & " + strjoin(thdr, " & ") + " \\ \hline"];
        for i = 1:size(spec, 1)
            txt = strings(1, numel(strat));
            for j = 1:numel(strat)
                [txt(j), shown, scale] = fmt(vals(i, j), spec{i, 3});
                chk{end + 1} = check_row(string(name), strat(j), string(spec{i, 1}), ...
                    round(vals(i, j) * scale, digits(spec{i, 3})), shown); %#ok<AGROW>
            end
            md(end + 1) = "| " + spec{i, 2} + " | " + strjoin(txt, " | ") + " |"; %#ok<AGROW>
            tex(end + 1) = string(TEX_ROW(spec{i, 1})) + " & " + strjoin(tex_cell(txt), " & ") + " \\ \hline"; %#ok<AGROW>
        end
        md = [md, ""]; %#ok<AGROW>
        writelines([tex, "\end{tabular}", "\end{table}"], fullfile(OUT, [name '.tex']), 'Encoding', 'UTF-8');
    end

    % Conteos de meses por tramo
    for q = 1:size(PERIODS, 1)
        n = M.n_meses(M.tramo == PERIODS{q, 1});
        chk{end + 1} = check_row("n_meses", string(PERIODS{q, 1}), "n_meses", ...
            PERIODS{q, 4}, unique(n)); %#ok<AGROW>
    end

    V = vertcat(chk{:});
    writetable(V, fullfile(OUT, 'r2_verificacion.csv'));
    md = [md, "## Verificacion", "", sprintf("%d comprobaciones, %d fallidas (detalle en `r2_verificacion.csv`).", ...
          height(V), sum(~V.ok))];
    writelines(md, fullfile(OUT, 'TABLAS_R2.md'), 'Encoding', 'UTF-8');
    fprintf('R2: %d comprobaciones, %d fallidas. Salidas en %s\n', height(V), sum(~V.ok), OUT);
    if any(~V.ok)
        disp(V(~V.ok, :));
    end
end


function d = digits(f)
% Decimales mostrados en la escala del formato
    switch f
        case {'pct', 'dec2'}, d = 2;
        case 'dec3', d = 3;
        case 'dec4', d = 4;
        case 'int', d = 0;
    end
end


function [txt, shown, scale] = fmt(v, f)
% Texto de la celda, valor que muestra (releido) y escala aplicada
    scale = 1;
    if strcmp(f, 'pct'), scale = 100; end
    if isnan(v)                                  % no definido o no aplica
        txt = "—"; shown = NaN;
        return
    end
    num = sprintf('%.*f', digits(f), v * scale);
    shown = str2double(num);
    txt = string(num);
    if strcmp(f, 'pct'), txt = txt + " %"; end
end


function s = tex_cell(txt)
% Celda del Markdown -> LaTeX: signo menos matematico y "\,\%"
    s = regexprep(txt, '^-(?=\d)', '$-$');
    s = replace(s, " %", "\,\%");
    s = replace(s, "—", "---");
end


function v = ifelse(c, a, b)
    if c, v = a; else, v = b; end
end


function T = check_row(chequeo, estrategia, columna, esperado, obtenido)
    ok = isequal(esperado, obtenido) || abs(esperado - obtenido) <= 1e-12 * max(1, abs(esperado)) ...
        || (isnan(esperado) && isnan(obtenido));      % "—" en las tablas (e) y (f)
    T = table(string(chequeo), string(estrategia), string(columna), esperado, obtenido, ok, ...
        'VariableNames', {'chequeo', 'estrategia', 'columna', 'esperado', 'obtenido', 'ok'});
end
