function r3_figuras()
% R3_FIGURAS  R3: figuras de prueba y validacion en PDF y PNG. Solo lee
% resultados de results_v2/; no optimiza nada. Ninguna cifra se escribe a mano.
%
%   1 riqueza_prueba            2 drawdown_prueba
%   3 riesgo_neff_prueba        4 turnover_costo_prueba
%   5 mapa_* (validacion, G1 y G2, siete metricas)
%   6 riqueza_vs_eta_validacion 7 exposicion_eta_alto (diagnostico, G1, delta=0.90)
%   8 dk_contraste_principal    (contrastes 1 y 2, emparejados)
%   9 riqueza_referencias_prueba     (elegidas frente a las referencias)
%  10 turnover_con_sin_costos_prueba (nominal con tau = 0.001 y tau = 0)
%
% Estilo para blanco y negro: tipo de linea = modelo (nominal, G1, G2),
% marcador = delta; mapas de calor en escala de grises.
%
% Salidas en results_finales/figuras/: *.pdf, *.png, r3_verificacion.csv y LISTA_R3.md

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root, fullfile(root, 'wdro-market'), fileparts(mfilename('fullpath')));
    RES = fullfile(root, 'results_v2');
    PANEL = fullfile(root, 'data', 'processed_2026-01-01', 'monthly_panel_hibrido.csv');
    OUT = fullfile(root, 'results_finales', 'figuras');
    if ~isfolder(OUT), mkdir(OUT); end

    TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
    TEST = {datetime(2019,1,1), datetime(2025,12,31), 84};
    RISK_EPS = 1e-8;                                          % igual que compute_metrics.m
    ORDER = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.80, 0.01)", "G1 (0.90, 0.01)", ...
             "G2 (0.80, 0.01)", "G2 (0.90, 0.01)"];
    CHOSEN = ["G1 (0.90, 0.01)", "G2 (0.80, 0.01)"];          % seleccion de T9
    CHOSEN_CELL = struct('G1', [0.90, 0.01], 'G2', [0.80, 0.01]);

    set(groot, 'defaultAxesFontSize', 10, 'defaultTextFontSize', 10, ...
        'defaultAxesTickLabelInterpreter', 'tex', 'defaultLegendInterpreter', 'tex');
    cleanup = onCleanup(@() set(groot, 'defaultAxesFontSize', 'remove', 'defaultTextFontSize', 'remove', ...
        'defaultAxesTickLabelInterpreter', 'remove', 'defaultLegendInterpreter', 'remove'));

    M = readtable(fullfile(RES, 'results_prueba_v2', 'metricas_por_tramo.csv'), 'TextType', 'string');
    MB = readtable(fullfile(RES, 'results_benchmarks', 'metricas_por_tramo_benchmarks.csv'), ...
        'TextType', 'string', 'Encoding', 'UTF-8');                      % main_benchmarks.m
    M = [M; MB];
    data = load_monthly_data(PANEL, TICKERS);
    traj = cargar_trayectorias(RES, data);
    chk = {};
    lista = {};

    % Tramo de prueba de cada estrategia (recorte y re-base, extract_period_results.m)
    sub = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for s = ORDER
        r = extract_period_results(traj(char(s)), TEST{1}, TEST{2});
        chk{end + 1} = check_row("n_meses_prueba", s, TEST{3}, numel(r.dates)); %#ok<AGROW>
        sub(char(s)) = r;
    end
    mrow = @(s, tramo) M(M.estrategia == s & M.tramo == tramo, :);

    %% 1. Riqueza de prueba
    fig = new_fig(780, 420);
    hold on
    for s = ORDER
        r = sub(char(s));
        plot_series(wealth_dates(r), r.wealth, s, CHOSEN);
        chk{end + 1} = check_row("riqueza_final_prueba", s, mrow(s, "prueba").riqueza_final, r.wealth(end)); %#ok<AGROW>
    end
    hold off
    ylabel('Riqueza (base 1)'); title('Riqueza, prueba');
    finish_axes('northwest');
    lista(end + 1, :) = save_fig(fig, OUT, 'riqueza_prueba', 'trayectorias (cargar_trayectorias.m) recortadas a 2019-2025', ...
        'Riqueza re-basada a 1 al inicio de la prueba de las seis estrategias evaluadas.');

    %% 2. Drawdown de prueba
    fig = new_fig(780, 420);
    hold on
    for s = ORDER
        r = sub(char(s));
        dd = 1 - r.wealth ./ cummax(r.wealth);
        plot_series(wealth_dates(r), 100 * dd, s, CHOSEN);
        chk{end + 1} = check_row("mdd_prueba", s, mrow(s, "prueba").max_drawdown, max(dd)); %#ok<AGROW>
    end
    hold off
    set(gca, 'YDir', 'reverse');
    ylabel('Caída desde el máximo (%)'); title('Caída desde el máximo, prueba');
    finish_axes('southwest');
    lista(end + 1, :) = save_fig(fig, OUT, 'drawdown_prueba', 'trayectorias recortadas a 2019-2025', ...
        'Caída porcentual desde el máximo previo de la riqueza (eje invertido), seis estrategias.');

    %% 3. Proporcion en riesgo y N_eff
    SUBSET = ["Nominal (0.80)", "Nominal (0.90)", "G1 (0.90, 0.01)", "G2 (0.80, 0.01)"];
    fig = new_fig(780, 600);
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); hold(ax1, 'on');
    ax2 = nexttile(tl); hold(ax2, 'on');
    for s = SUBSET
        r = sub(char(s));
        risky = sum(r.x, 2);
        valid = risky > RISK_EPS;
        neff = zeros(size(risky));
        neff(valid) = 1 ./ sum((r.x(valid, :) ./ risky(valid)).^2, 2);
        axes(ax1); plot_series(r.dates, 100 * risky, s, CHOSEN); %#ok<LAXES>
        axes(ax2); plot_series(r.dates, neff, s, CHOSEN); %#ok<LAXES>
        m = mrow(s, "prueba");
        chk{end + 1} = check_row("proporcion_riesgo_media", s, m.proporcion_riesgo_media, mean(risky)); %#ok<AGROW>
        chk{end + 1} = check_row("Neff_promedio", s, m.Neff_promedio, mean(neff(valid))); %#ok<AGROW>
    end
    axes(ax1); ylabel('En riesgo (%)'); title('Proporción en riesgo, prueba'); finish_axes('southwest');
    axes(ax2); ylabel('N_{eff}'); title('N_{eff}, prueba'); finish_axes([]);
    lista(end + 1, :) = save_fig(fig, OUT, 'riesgo_neff_prueba', 'trayectorias recortadas a 2019-2025', ...
        'Proporción invertida en activos riesgosos y número efectivo de activos riesgosos por mes (N_eff = 0 sin exposición).');

    %% 4. Turnover y costo monetario acumulados
    fig = new_fig(780, 600);
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); hold(ax1, 'on');
    ax2 = nexttile(tl); hold(ax2, 'on');
    for s = ORDER
        r = sub(char(s));
        T = numel(r.turnover);
        to_acum = cumsum(r.turnover);
        costo_acum = cumsum(r.wealth(1:T) .* r.params.tau .* r.turnover) / r.wealth(1);
        axes(ax1); plot_series(r.dates, to_acum, s, CHOSEN); %#ok<LAXES>
        axes(ax2); plot_series(r.dates, costo_acum, s, CHOSEN); %#ok<LAXES>
        m = mrow(s, "prueba");
        chk{end + 1} = check_row("turnover_total", s, m.turnover_total, to_acum(end)); %#ok<AGROW>
        chk{end + 1} = check_row("costo_monetario", s, m.costo_monetario, costo_acum(end)); %#ok<AGROW>
    end
    axes(ax1); ylabel('Turnover acumulado'); title('Turnover acumulado, prueba'); finish_axes('northwest');
    axes(ax2); ylabel('Costo (riqueza inicial = 1)'); title('Costo monetario acumulado, prueba'); finish_axes([]);
    lista(end + 1, :) = save_fig(fig, OUT, 'turnover_costo_prueba', 'trayectorias recortadas a 2019-2025', ...
        'Turnover acumulado y costo monetario acumulado (suma de W_k tau TO_k / W_0) de las seis estrategias.');

    %% 5. Mapas de calor de validacion
    V.G1 = readtable(fullfile(RES, 'results_validacion_grid', 'tabla_maestra_metricas_validacion.csv'));
    V.G2 = readtable(fullfile(RES, 'wdro-market', 'results_validacion_grid_market', 'tabla_maestra_metricas_validacion.csv'));
    Dc = readtable(fullfile(RES, 'results_seleccion', 'diagnostico_cota_delta.csv'), 'TextType', 'string');
    deltas = unique(V.G1.delta);
    etas = unique(V.G1.eta);
    for g = ["G1", "G2"]
        T = V.(g);
        assert(height(T) == numel(deltas) * numel(etas) && isequal(unique(T.eta), etas) && isequal(unique(T.delta), deltas), ...
            'Malla de %s inesperada.', g);
        assert(all(T.n_meses == 48), 'Validacion de %s sin 48 meses.', g);
        assert(isequal(T.es_baseline == 1, T.eta == 0), 'es_baseline no coincide con eta = 0 en %s.', g);
        d = Dc(Dc.geometria == g, :);
        [tf, loc] = ismember([T.delta, T.eta], [d.delta, d.eta], 'rows');
        assert(all(tf), 'Faltan celdas de %s en diagnostico_cota_delta.csv.', g);
        T.meses_cota_activa = d.meses_cota_activa(loc);
        V.(g) = T;
    end
    % Equivalencia con eta = 0: G1 y G2 coinciden con el nominal de cada delta
    for dl = deltas'
        a = V.G1(V.G1.delta == dl & V.G1.eta == 0, :);
        b = V.G2(V.G2.delta == dl & V.G2.eta == 0, :);
        tag = sprintf('delta=%.2f', dl);
        chk{end + 1} = check_row("eta0_G1_igual_G2_riqueza", tag, a.riqueza_final, b.riqueza_final, 1e-9); %#ok<AGROW>
        nom = mrow(sprintf("Nominal (%.2f)", dl), "validacion");
        if ~isempty(nom)
            chk{end + 1} = check_row("eta0_G1_igual_nominal_riqueza", tag, nom.riqueza_final, a.riqueza_final, 1e-9); %#ok<AGROW>
        end
    end
    MAPS = {'riqueza_final', 'Riqueza final', 'Riqueza final', 1, '%.2f'
            'CVaR_perdida', 'CVaR 95 %', 'CVaR 95 % (pérdida, %)', 100, '%.1f'
            'sharpe', 'Sharpe', 'Sharpe', 1, '%.2f'
            'costo_monetario', 'Costo monetario', 'Costo (riqueza inicial = 1)', 1, '%.3f'
            'proporcion_riesgo_media', 'Proporción en riesgo', 'En riesgo media (%)', 100, '%.1f'
            'meses_cota_activa', 'Meses con la cota \delta activa', 'Meses (de 48)', 1, '%d'
            'fraccion_factible', 'Fracción de meses con solución óptima', 'Fracción', 1, '%.2f'};
    MAP_FILES = {'mapa_riqueza', 'mapa_cvar', 'mapa_sharpe', 'mapa_costo', 'mapa_riesgo', 'mapa_cota_activa', 'mapa_optima'};
    for q = 1:size(MAPS, 1)
        [col, ttl, cblab, scale, fmtq] = MAPS{q, :};
        Z.G1 = grid_matrix(V.G1, col, deltas, etas) * scale;
        Z.G2 = grid_matrix(V.G2, col, deltas, etas) * scale;
        lims = [min([Z.G1(:); Z.G2(:)]), max([Z.G1(:); Z.G2(:)])];
        if strcmp(col, 'fraccion_factible'), lims = [0, 1]; end
        if lims(1) == lims(2), lims = lims + [-0.5, 0.5]; end
        fig = new_fig(1150, 390);
        tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        for g = ["G1", "G2"]
            ax = nexttile(tl);
            draw_heatmap(ax, Z.(g), deltas, etas, lims, fmtq, CHOSEN_CELL.(g));
            title(ax, char(g + " — " + ttl));
        end
        cb = colorbar(ax);
        cb.Layout.Tile = 'east';
        cb.Label.String = cblab;
        lista(end + 1, :) = save_fig(fig, OUT, MAP_FILES{q}, ...
            'tabla_maestra_metricas_validacion.csv (G1 y G2)' + string(ifelse(strcmp(col, 'meses_cota_activa'), ...
            ' y diagnostico_cota_delta.csv', '')), ...
            "Validación 2015-2018, malla delta x eta: " + string(strrep(ttl, '\delta', 'delta')) + ...
            "; recuadro = configuración elegida (T9)."); %#ok<AGROW>
    end

    %% 6. Riqueza de validacion frente a eta
    W = readtable(fullfile(RES, 'results_seleccion', 'riqueza_vs_eta.csv'), 'TextType', 'string');
    DMARK = {'o', 's', '^', 'd', 'v', 'p'};
    fig = new_fig(1000, 420);
    tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    gray_levels = linspace(0, 0.6, numel(deltas));
    for g = ["G1", "G2"]
        ax = nexttile(tl); hold(ax, 'on');
        for i = 1:numel(deltas)
            w = W(W.geometria == g & W.delta == deltas(i), :);
            w = sortrows(w, 'eta');
            assert(isequal(w.eta, etas), 'riqueza_vs_eta.csv incompleta.');
            plot(ax, 1:numel(etas), w.riqueza_final, '-', 'Marker', DMARK{i}, ...
                'Color', gray_levels(i) * [1 1 1], 'LineWidth', 1.2, 'MarkerSize', 5, ...
                'DisplayName', sprintf('\\delta = %.2f', deltas(i)));
            chk{end + 1} = check_row("riqueza_vs_eta_menos_tabla_maestra_max", g + sprintf(" delta=%.2f", deltas(i)), ...
                0, max(abs(grid_matrix(V.(g), 'riqueza_final', deltas(i), etas)' - w.riqueza_final))); %#ok<AGROW>
        end
        set(ax, 'XTick', 1:numel(etas), 'XTickLabel', compose('%g', etas));
        xlabel(ax, '\eta'); ylabel(ax, 'Riqueza final');
        title(ax, char(g + " — riqueza vs. \eta, validación"));
        grid(ax, 'on'); box(ax, 'on');
        if g == "G1", legend(ax, 'Location', 'southwest'); end
    end
    lista(end + 1, :) = save_fig(fig, OUT, 'riqueza_vs_eta_validacion', 'results_seleccion/riqueza_vs_eta.csv', ...
        'Riqueza final de validación frente a eta (espaciado categórico), una línea por delta, para cada geometría.');

    %% 7. Exposicion riesgosa con eta alto (diagnostico, G1, delta = 0.90)
    E = readtable(fullfile(RES, 'results_estado_solver', 'diagnostico_eta_alto.csv'));
    ETA_DIAG = [0, 0.10, 0.15, 0.30];
    STY = {'-', '--', '-.', ':'};
    fig = new_fig(780, 420);
    hold on
    for i = 1:numel(ETA_DIAG)
        tag = strrep(sprintf('eta_%.2f', ETA_DIAG(i)), '.', '_');
        plot(E.fecha_decision, 100 * E.(['exposicion_riesgo_', tag]), STY{i}, ...
            'Color', 0.2 * (i - 1) * [1 1 1], 'LineWidth', 1.8, ...
            'DisplayName', sprintf('\\eta = %.2f', ETA_DIAG(i)));
    end
    xline(datetime(2018,12,31), 'k:', 'Inicio de la prueba', 'LabelVerticalAlignment', 'middle', ...
        'HandleVisibility', 'off');
    hold off
    xlabel('Fecha de decisión'); ylabel('En riesgo (%)');
    title('Exposición riesgosa, G1 con \delta = 0.90');
    finish_axes('east');
    chk{end + 1} = check_row("n_decisiones_diagnostico", "G1 delta=0.90", 132, height(E)); %#ok<AGROW>
    lista(end + 1, :) = save_fig(fig, OUT, 'exposicion_eta_alto', 'results_estado_solver/diagnostico_eta_alto.csv', ...
        'Proporción en riesgo de G1 con delta = 0.90 y eta en {0, 0.10, 0.15, 0.30}, 132 decisiones (diagnóstico de trayectorias planas).');

    %% 8. D_k del contraste principal (contrastes 1 y 2, emparejados)
    K = readtable(fullfile(RES, 'results_prueba_v2', 'contrastes_prueba.csv'), 'TextType', 'string');
    K = K(startsWith(K.contraste, "emparejado"), :);
    assert(height(K) == 2, 'Se esperaban dos contrastes emparejados.');
    fig = new_fig(780, 560);
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for i = 1:2
        a = sub(char(K.A(i))); b = sub(char(K.B(i)));
        Dk = log(a.growth_real) - log(b.growth_real);
        chk{end + 1} = check_row("suma_D", K.contraste(i), K.suma_D(i), sum(Dk)); %#ok<AGROW>
        ax = nexttile(tl);
        stem(ax, a.dates, 100 * Dk, 'k', 'filled', 'MarkerSize', 3, 'LineWidth', 0.8);
        yline(ax, 0, 'k-');
        ylabel(ax, 'D_k (p. p.)');
        title(ax, sprintf('Contraste %d: %s menos %s, prueba', i, K.A(i), K.B(i)));
        grid(ax, 'on'); box(ax, 'on');
    end
    lista(end + 1, :) = save_fig(fig, OUT, 'dk_contraste_principal', 'trayectorias recortadas a 2019-2025; contrastes_prueba.csv', ...
        'Diferencia mensual de crecimiento logarítmico D_k (en puntos porcentuales) de los contrastes 1 y 2 (G2 frente a G1 con los mismos parámetros).');

    %% 9. Riqueza de prueba frente a las estrategias de referencia
    REF_FIG = ["G1 (0.90, 0.01)", "G2 (0.80, 0.01)", "Nominal (0.90)", ...
               "Igual ponderación", "SPY pasivo", "Bajo riesgo"];
    fig = new_fig(780, 420);
    hold on
    for s = REF_FIG
        r = extract_period_results(traj(char(s)), TEST{1}, TEST{2});
        chk{end + 1} = check_row("n_meses_prueba", s, TEST{3}, numel(r.dates)); %#ok<AGROW>
        plot_series(wealth_dates(r), r.wealth, s, CHOSEN);
        chk{end + 1} = check_row("riqueza_final_prueba_referencias", s, mrow(s, "prueba").riqueza_final, r.wealth(end)); %#ok<AGROW>
    end
    hold off
    ylabel('Riqueza (base 1)'); title('Riqueza, prueba: estrategias elegidas y de referencia');
    finish_axes('northwest');
    lista(end + 1, :) = save_fig(fig, OUT, 'riqueza_referencias_prueba', ...
        'trayectorias recortadas a 2019-2025 (incluye results_benchmarks/benchmarks.mat)', ...
        'Riqueza re-basada a 1 en la prueba: G1 y G2 elegidas, nominal (0.90), igual ponderación, SPY pasivo y bajo riesgo.');

    %% 10. Turnover acumulado del nominal con y sin costos
    TAU_FIG = ["Nominal (0.80)", "Nominal sin costos (0.80)", "Nominal (0.90)", "Nominal sin costos (0.90)"];
    fig = new_fig(780, 420);
    hold on
    for s = TAU_FIG
        r = extract_period_results(traj(char(s)), TEST{1}, TEST{2});
        to_acum = cumsum(r.turnover);
        plot_series(r.dates, to_acum, s, CHOSEN);
        chk{end + 1} = check_row("turnover_total_con_sin_costos", s, mrow(s, "prueba").turnover_total, to_acum(end)); %#ok<AGROW>
    end
    hold off
    ylabel('Turnover acumulado'); title('Turnover acumulado del Kelly nominal con y sin costos, prueba');
    finish_axes('northwest');
    lista(end + 1, :) = save_fig(fig, OUT, 'turnover_con_sin_costos_prueba', ...
        'trayectorias recortadas a 2019-2025 (incluye results_benchmarks/benchmarks.mat)', ...
        'Turnover acumulado de prueba del Kelly nominal con tau = 0.001 y con tau = 0 (turnover canónico), para delta = 0.80 y 0.90.');

    %% Verificacion y lista
    Vt = vertcat(chk{:});
    writetable(Vt, fullfile(OUT, 'r3_verificacion.csv'));
    md = ["# Figuras R3 (generadas por `results_finales/r3_figuras.m`)", "", ...
          "Cada figura está en PDF (vectorial) y PNG. Fuente: `results_v2/`. † = configuración elegida en validación (T9).", "", ...
          "| Archivo | Fuente | Qué muestra |", "|---|---|---|"];
    for i = 1:size(lista, 1)
        md(end + 1) = "| `" + lista{i, 1} + ".pdf/.png` | " + lista{i, 2} + " | " + lista{i, 3} + " |"; %#ok<AGROW>
    end
    md = [md, "", "## Verificación", "", sprintf("%d comprobaciones, %d fallidas (detalle en `r3_verificacion.csv`).", ...
          height(Vt), sum(~Vt.ok))];
    writelines(md, fullfile(OUT, 'LISTA_R3.md'), 'Encoding', 'UTF-8');
    fprintf('R3: %d figuras, %d comprobaciones, %d fallidas. Salidas en %s\n', size(lista, 1), height(Vt), sum(~Vt.ok), OUT);
    if any(~Vt.ok)
        disp(Vt(~Vt.ok, :));
        error('r3_figuras:verificacion', 'Hay comprobaciones fallidas.');
    end
end


function st = style_of(s)
% Estilo fijo por estrategia: linea = modelo, marcador = delta
    s = string(s);
    % Estrategias de referencia (main_benchmarks.m)
    switch s
        case "Igual ponderación", st = struct('line', ':', 'marker', '^', 'color', [0.15 0.15 0.15]); return
        case "SPY pasivo",        st = struct('line', '-', 'marker', 'none', 'color', [0.60 0.60 0.60]); return
        case "Bajo riesgo",       st = struct('line', ':', 'marker', 'none', 'color', [0.45 0.45 0.45]); return
    end
    if startsWith(s, "Nominal sin costos")
        st.line = ':';
        if contains(s, "0.80"), st.marker = 'o'; st.color = [0.45 0.45 0.45];
        else,                   st.marker = 's'; st.color = [0 0 0];
        end
        return
    end
    if startsWith(s, "Nominal"), st.line = '-';  base = [0 0 0];
    elseif startsWith(s, "G1"),  st.line = '--'; base = [0 0.30 0.60];
    else,                        st.line = '-.'; base = [0.80 0.33 0];
    end
    if contains(s, "0.80")
        st.marker = 'o'; st.color = base + 0.45 * (1 - base);   % tono claro
    else
        st.marker = 's'; st.color = base;
    end
end


function plot_series(t, y, s, chosen)
    st = style_of(s);
    lab = char(s);
    if ismember(s, chosen), lab = [lab ' †']; end
    n = numel(y);
    plot(t, y, st.line, 'Color', st.color, 'LineWidth', 1.4, 'Marker', st.marker, ...
        'MarkerIndices', 1:12:n, 'MarkerSize', 5, 'MarkerFaceColor', 'w', 'DisplayName', lab);
end


function t = wealth_dates(r)
% wealth tiene T+1 puntos: el primero es el inicio del tramo (fin del mes previo)
    t = [dateshift(r.dates(1), 'end', 'month', -1); r.dates];
end


function fig = new_fig(w, h)
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [100, 100, w, h]);
end


function finish_axes(loc)
    grid on; box on;
    if ~isempty(loc), legend('Location', loc, 'NumColumns', 2); end
end


function row = save_fig(fig, out, name, fuente, descr)
    exportgraphics(fig, fullfile(out, [name '.pdf']), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(out, [name '.png']), 'Resolution', 200);
    close(fig);
    row = {string(name), string(fuente), string(descr)};
end


function Z = grid_matrix(T, col, deltas, etas)
    Z = nan(numel(deltas), numel(etas));
    for i = 1:numel(deltas)
        for j = 1:numel(etas)
            v = T.(col)(abs(T.delta - deltas(i)) < 1e-12 & abs(T.eta - etas(j)) < 1e-12);
            assert(numel(v) == 1);
            Z(i, j) = v;
        end
    end
end


function draw_heatmap(ax, Z, deltas, etas, lims, fmt, chosen)
% Mapa de calor en grises (claro = bajo, oscuro = alto) con el valor en cada celda
    cmap = flipud(gray(256));
    cmap = cmap(26:230, :);                      % sin blanco ni negro puros
    imagesc(ax, Z, lims);
    colormap(ax, cmap);
    set(ax, 'XTick', 1:numel(etas), 'XTickLabel', compose('%g', etas), ...
        'YTick', 1:numel(deltas), 'YTickLabel', compose('%.2f', deltas), 'FontSize', 9);
    xlabel(ax, '\eta'); ylabel(ax, '\delta');
    for i = 1:size(Z, 1)
        for j = 1:size(Z, 2)
            u = (Z(i, j) - lims(1)) / diff(lims);
            txt = sprintf(fmt, Z(i, j));
            text(ax, j, i, txt, 'HorizontalAlignment', 'center', 'FontSize', 7, ...
                'Color', ifelse(u > 0.55, [1 1 1], [0 0 0]));
        end
    end
    i = find(abs(deltas - chosen(1)) < 1e-12);
    j = find(abs(etas - chosen(2)) < 1e-12);
    rectangle(ax, 'Position', [j - 0.5, i - 0.5, 1, 1], 'EdgeColor', [0.85 0.1 0.1], 'LineWidth', 2);
end


function v = ifelse(c, a, b)
    if c, v = a; else, v = b; end
end


function T = check_row(chequeo, objeto, esperado, obtenido, tol)
    if nargin < 5, tol = 1e-12; end
    ok = isequal(esperado, obtenido) || abs(esperado - obtenido) <= tol * max(1, abs(esperado));
    T = table(string(chequeo), string(objeto), esperado, obtenido, abs(esperado - obtenido), ok, ...
        'VariableNames', {'chequeo', 'objeto', 'esperado', 'obtenido', 'dif_abs', 'ok'});
end
