function r4_inferencia()
% R4_INFERENCIA  R4: bootstrap por bloques y desglose por regimen de los
% siete contrastes de prueba (Tabla tab:contrastes de metodologia_6.tex),
% en CSV, Markdown y .tex (\hline, sin booktabs) y una figura de intervalos.
% Solo lee resultados de results_v2/; no optimiza nada. Ninguna cifra se
% escribe a mano.
%
%   A  bootstrap: 7 contrastes x ell = {3, 6, 12}
%   B  regimen: 7 contrastes x 5 grupos
%   C  cruce 2x2 (VIX x SPY_k) de los contrastes principales 1 y 2
%
% Verificacion: se recalculan D_k desde las trayectorias, se repite el
% bootstrap con bootstrap_block_diff.m (semilla propia) y se recuentan los
% grupos desde clasificacion_meses.csv.
%
% Salidas en results_finales/inferencia/: tabla_r4[a-c]_*.csv/.tex,
% ic_contrastes.pdf/.png, r4_verificacion.csv y TABLAS_R4.md

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root, fullfile(root, 'wdro-market'), fileparts(mfilename('fullpath')));
    RES = fullfile(root, 'results_v2');
    PANEL = fullfile(root, 'data', 'processed_2026-01-01', 'monthly_panel_hibrido.csv');
    OUT = fullfile(root, 'results_finales', 'inferencia');
    if ~isfolder(OUT), mkdir(OUT); end

    TICKERS = {'AAPL', 'MSFT', 'AMZN', 'JPM', 'JNJ', 'XOM', 'PG', 'CAT', 'KO', 'WMT'};
    TEST = {datetime(2019,1,1), datetime(2025,12,31), 84};
    TIE = 1e-6;                                   % empates numericos, igual que T6/T7
    ELLS = [3, 6, 12];

    % Contrastes en el orden de tab:contrastes: {n, A, B, tipo y contraste en los CSV, etiqueta tex}
    CON = {1, "G2 (0.90, 0.01)", "G1 (0.90, 0.01)", "emparejado (0.90, 0.01)", "(ii) G2 vs G1",       '$G_2(c_1)-G_1(c_1)$'
           2, "G2 (0.80, 0.01)", "G1 (0.80, 0.01)", "emparejado (0.80, 0.01)", "(ii) G2 vs G1",       '$G_2(c_2)-G_1(c_2)$'
           3, "G2 (0.80, 0.01)", "G1 (0.90, 0.01)", "seleccionado",            "(ii) G2 vs G1",       '$G_2(c_2)-G_1(c_1)$'
           4, "G1 (0.90, 0.01)", "Nominal (0.90)",  "emparejado (0.90, 0.01)", "(i) G1 vs nominal",   '$G_1(c_1)-\mathrm{Nom}(\delta_1^\star)$'
           5, "G2 (0.90, 0.01)", "Nominal (0.90)",  "emparejado (0.90, 0.01)", "(iii) G2 vs nominal", '$G_2(c_1)-\mathrm{Nom}(\delta_1^\star)$'
           6, "G1 (0.80, 0.01)", "Nominal (0.80)",  "emparejado (0.80, 0.01)", "(i) G1 vs nominal",   '$G_1(c_2)-\mathrm{Nom}(\delta_2^\star)$'
           7, "G2 (0.80, 0.01)", "Nominal (0.80)",  "emparejado (0.80, 0.01)", "(iii) G2 vs nominal", '$G_2(c_2)-\mathrm{Nom}(\delta_2^\star)$'};
    NC = size(CON, 1);
    % Filas del CSV del bootstrap que repiten un contraste: {tipo, contraste, n equivalente}
    DUP = {"seleccionado", "(i) G1 vs nominal", 4
           "seleccionado", "(iii) G2 vs nominal", 7};
    GROUPS = ["todos", "VIX alto", "VIX bajo", "SPY_k negativo", "SPY_k no negativo"];
    GROUP_TEX = {'Todos', 'VIX alto', 'VIX bajo', '$r^{\mathrm{SPY}}_k<0$', '$r^{\mathrm{SPY}}_k\ge 0$'};
    CROSS = ["VIX alto y SPY_k neg.", "VIX alto y SPY_k >= 0"; "VIX bajo y SPY_k neg.", "VIX bajo y SPY_k >= 0"];
    SIZES = struct('todos', 84, 'VIX_alto', 48, 'VIX_bajo', 36, 'SPY_neg', 28, 'SPY_noneg', 56, ...
                   'cruce', [23 25; 5 31]);           % tamanos esperados (R4 de TAREAS_PENDIENTES.md)

    TB = readtable(fullfile(RES, 'results_bootstrap', 'tabla_bootstrap_contrastes.csv'), 'TextType', 'string');
    RG = readtable(fullfile(RES, 'results_regimen', 'desglose_regimen.csv'), 'TextType', 'string');
    CL = readtable(fullfile(RES, 'results_regimen', 'clasificacion_meses.csv'), 'TextType', 'string');
    KP = readtable(fullfile(RES, 'results_prueba_v2', 'contrastes_prueba.csv'), 'TextType', 'string');
    data = load_monthly_data(PANEL, TICKERS);
    traj = cargar_trayectorias(RES, data);
    chk = {};

    %% D_k desde las trayectorias de prueba
    Dk = cell(NC, 1); GA = cell(NC, 1); GB = cell(NC, 1);
    for c = 1:NC
        a = extract_period_results(traj(char(CON{c, 2})), TEST{1}, TEST{2});
        b = extract_period_results(traj(char(CON{c, 3})), TEST{1}, TEST{2});
        assert(isequal(a.dates, b.dates) && numel(a.dates) == TEST{3}, 'Series de prueba no alineadas.');
        GA{c} = a.growth_real; GB{c} = b.growth_real;
        Dk{c} = log(GA{c}) - log(GB{c});
        if c == 1, test_dates = a.dates; end
        assert(isequal(a.dates, test_dates));
        kp = KP(KP.A == CON{c, 2} & KP.B == CON{c, 3}, :);
        chk{end + 1} = check_row("suma_D_vs_contrastes_prueba", c, kp.suma_D, sum(Dk{c})); %#ok<AGROW>
    end

    %% A. Bootstrap
    for d = 1:size(DUP, 1)
        x = TB(TB.tipo == DUP{d, 1} & TB.contraste == DUP{d, 2}, :);
        c = DUP{d, 3};
        y = TB(TB.tipo == CON{c, 4} & TB.contraste == CON{c, 5}, :);
        same = isequal(x.A, y.A) && isequal(x.B, y.B) && isequal(x{:, vartype('numeric')}, y{:, vartype('numeric')});
        chk{end + 1} = check_row("fila_duplicada_bootstrap_" + DUP{d, 1} + " " + DUP{d, 2}, c, 1, double(same)); %#ok<AGROW>
    end
    A = table();
    for c = 1:NC
        D = Dk{c};
        for ell = ELLS
            t = TB(TB.tipo == CON{c, 4} & TB.contraste == CON{c, 5} & TB.ell == ell, :);
            assert(height(t) == 1 && t.A == CON{c, 2} && t.B == CON{c, 3}, 'Fila de bootstrap no encontrada.');
            o = bootstrap_block_diff(GA{c}, GB{c}, ell, t.B_replicas, t.semilla);
            tag = sprintf('ell=%d', ell);
            chk{end + 1} = check_row("bootstrap_IC95_inf " + tag, c, t.IC95_inf, o.ci_lo); %#ok<AGROW>
            chk{end + 1} = check_row("bootstrap_IC95_sup " + tag, c, t.IC95_sup, o.ci_hi); %#ok<AGROW>
            chk{end + 1} = check_row("bootstrap_ee " + tag, c, t.ee_bootstrap, o.boot_se); %#ok<AGROW>
            if ell == ELLS(1)
                chk{end + 1} = check_row("media_D", c, t.media_D, mean(D)); %#ok<AGROW>
                chk{end + 1} = check_row("mediana_D", c, t.mediana_D, median(D)); %#ok<AGROW>
                chk{end + 1} = check_row("prop_D_pos", c, t.prop_D_pos, mean(D > 0)); %#ok<AGROW>
                chk{end + 1} = check_row("empates", c, t.meses_empate_1e6, sum(abs(D) < TIE)); %#ok<AGROW>
                chk{end + 1} = check_row("n_meses", c, TEST{3}, t.n_meses); %#ok<AGROW>
            end
            A = [A; table(c, string(CON{c, 4}), CON{c, 2}, CON{c, 3}, c <= 2, ell, t.n_meses, t.media_D, ...
                t.media_D_anualizada, t.IC95_inf, t.IC95_sup, t.ee_bootstrap, t.mediana_D, t.prop_D_pos, ...
                t.meses_empate_1e6, t.IC_excluye_cero == 1, t.B_replicas, t.semilla, ...
                'VariableNames', {'n_contraste', 'tipo', 'A', 'B', 'principal', 'ell', 'n_meses', 'media_D', ...
                'media_D_anualizada', 'IC95_inf', 'IC95_sup', 'ee_bootstrap', 'mediana_D', 'prop_D_pos', ...
                'empates_1e6', 'IC_excluye_cero', 'B_replicas', 'semilla'})]; %#ok<AGROW>
        end
    end
    writetable(A, fullfile(OUT, 'tabla_r4a_bootstrap.csv'));

    %% B y C. Regimen
    % Meses de prueba en el orden de las trayectorias
    [tf, loc] = ismember(ym(test_dates), ym(CL.mes_realizado_k1));
    assert(all(tf) && height(CL) == TEST{3}, 'clasificacion_meses.csv no cubre la prueba.');
    vix = CL.VIX_alto(loc) == 1;
    spy = CL.SPY_negativo(loc) == 1;
    mask = containers.Map();
    mask('todos') = true(TEST{3}, 1);
    mask('VIX alto') = vix;                    mask('VIX bajo') = ~vix;
    mask('SPY_k negativo') = spy;              mask('SPY_k no negativo') = ~spy;
    mask(char(CROSS(1, 1))) = vix & spy;       mask(char(CROSS(1, 2))) = vix & ~spy;
    mask(char(CROSS(2, 1))) = ~vix & spy;      mask(char(CROSS(2, 2))) = ~vix & ~spy;
    chk{end + 1} = check_row("n_grupo todos", 0, SIZES.todos, nnz(mask('todos'))); %#ok<AGROW>
    chk{end + 1} = check_row("n_grupo VIX alto", 0, SIZES.VIX_alto, nnz(vix)); %#ok<AGROW>
    chk{end + 1} = check_row("n_grupo VIX bajo", 0, SIZES.VIX_bajo, nnz(~vix)); %#ok<AGROW>
    chk{end + 1} = check_row("n_grupo SPY_k negativo", 0, SIZES.SPY_neg, nnz(spy)); %#ok<AGROW>
    chk{end + 1} = check_row("n_grupo SPY_k no negativo", 0, SIZES.SPY_noneg, nnz(~spy)); %#ok<AGROW>
    for i = 1:2
        for j = 1:2
            chk{end + 1} = check_row("n_grupo " + CROSS(i, j), 0, SIZES.cruce(i, j), nnz(mask(char(CROSS(i, j))))); %#ok<AGROW>
        end
    end

    Rall = table();
    for c = 1:NC
        D = Dk{c};
        for g = [GROUPS, CROSS(:)']
            r = RG(RG.tipo == CON{c, 4} & RG.contraste == CON{c, 5} & RG.regimen == g, :);
            assert(height(r) == 1 && r.A == CON{c, 2} && r.B == CON{c, 3}, 'Fila de regimen no encontrada.');
            m = mask(char(g));
            Dg = D(m);
            tag = "regimen " + g;
            chk{end + 1} = check_row(tag + " n", c, r.n_meses, nnz(m)); %#ok<AGROW>
            chk{end + 1} = check_row(tag + " media_D", c, r.media_D, mean(Dg)); %#ok<AGROW>
            chk{end + 1} = check_row(tag + " mediana_D", c, r.mediana_D, median(Dg)); %#ok<AGROW>
            chk{end + 1} = check_row(tag + " prop_D_pos", c, r.prop_D_pos, mean(Dg > 0)); %#ok<AGROW>
            chk{end + 1} = check_row(tag + " empates", c, r.empates_1e6, sum(abs(Dg) < TIE)); %#ok<AGROW>
            chk{end + 1} = check_row(tag + " suma_D", c, r.suma_D, sum(Dg)); %#ok<AGROW>
            Rall = [Rall; table(c, string(CON{c, 4}), CON{c, 2}, CON{c, 3}, c <= 2, g, r.n_meses, r.media_D, ...
                r.mediana_D, r.prop_D_pos, r.empates_1e6, r.prop_D_pos_sin_empates, r.suma_D, ...
                'VariableNames', {'n_contraste', 'tipo', 'A', 'B', 'principal', 'regimen', 'n_meses', 'media_D', ...
                'mediana_D', 'prop_D_pos', 'empates_1e6', 'prop_D_pos_sin_empates', 'suma_D'})]; %#ok<AGROW>
        end
        % El grupo "todos" del desglose coincide con el bootstrap
        a6 = A(A.n_contraste == c & A.ell == 6, :);
        rt = Rall(Rall.n_contraste == c & Rall.regimen == "todos", :);
        chk{end + 1} = check_row("todos_regimen_vs_bootstrap media_D", c, a6.media_D, rt.media_D); %#ok<AGROW>
        chk{end + 1} = check_row("todos_regimen_vs_bootstrap prop_D_pos", c, a6.prop_D_pos, rt.prop_D_pos); %#ok<AGROW>
    end
    RB = Rall(ismember(Rall.regimen, GROUPS), :);
    RC = Rall(ismember(Rall.regimen, CROSS(:)) & Rall.principal, :);
    writetable(RB, fullfile(OUT, 'tabla_r4b_regimen.csv'));
    writetable(RC, fullfile(OUT, 'tabla_r4c_cruce.csv'));

    %% Tablas .tex y Markdown
    md = ["# Tablas R4 (generadas por `results_finales/r4_inferencia.m`)", "", ...
          "Fuentes: `results_v2/results_bootstrap/tabla_bootstrap_contrastes.csv`, `results_v2/results_regimen/desglose_regimen.csv` " + ...
          "y `clasificacion_meses.csv`. Contrastes numerados como en la Tabla `tab:contrastes`; c1 = (0.90, 0.01), c2 = (0.80, 0.01). " + ...
          "D_k = log G^A - log G^B, en % mensual. Contraste principal: 1 y 2 (los demás son exploratorios).", ""];

    % --- A ---
    tex = tex_head('Prueba 2019--2025: media de $D_k$ y su intervalo del 95\,\% por bootstrap móvil por bloques ($B=10\,000$) con $\ell\in\{3,6,12\}$. $D_k$ en \% mensual; «\% $D_k>0$» sobre los 84 meses; empates: meses con $|D_k|<10^{-6}$. Contrastes principales: 1 y 2; 3 a 7 son exploratorios y no se ajustan por comparaciones múltiples.', ...
        'tab:r4_bootstrap', '|c|l|r|r|r|r|c|c|c|', '3pt');
    % Encabezados en dos lineas para que la tabla quepa en el ancho de texto
    tex(end + 1) = "\textbf{N.º} & \textbf{Contraste} & " + strjoin([hd("\textbf{Media}", "(\%)"), ...
        hd("\textbf{Mediana}", "(\%)"), hd("\textbf{\%}", "$D_k>0$"), hd("\textbf{Empates}", "$|D_k|<10^{-6}$"), ...
        hd("\textbf{IC 95\,\%}", "$\ell=3$"), hd("\textbf{IC 95\,\%}", "$\ell=6$"), hd("\textbf{IC 95\,\%}", "$\ell=12$")], ' & ') + ...
        " \\ \hline";
    mdA = ["## A. Bootstrap por bloques (prueba 2019-2025)", "", "CSV: `tabla_r4a_bootstrap.csv`; .tex: `tabla_r4a_bootstrap.tex`", "", ...
           "| N.º | A | B | Media (%) | Mediana (%) | % D>0 | Empates | IC ℓ=3 (%) | IC ℓ=6 (%) | IC ℓ=12 (%) |", ...
           "|---|---|---|---:|---:|---:|---:|---:|---:|---:|"];
    for c = 1:NC
        a = A(A.n_contraste == c, :);
        a6 = a(a.ell == 6, :);
        ic = strings(1, numel(ELLS));
        for q = 1:numel(ELLS)
            aq = a(a.ell == ELLS(q), :);
            ic(q) = "[" + num(100 * aq.IC95_inf, 3) + ", " + num(100 * aq.IC95_sup, 3) + "]";
            chk{end + 1} = shown_check("tex_IC_inf", c, 100 * aq.IC95_inf, 3); %#ok<AGROW>
        end
        cells = [num(100 * a6.media_D, 3), num(100 * a6.mediana_D, 3), num(100 * a6.prop_D_pos, 1), ...
                 string(a6.empates_1e6)];
        tex(end + 1) = sprintf('%d & %s & %s & %s \\\\ \\hline', c, CON{c, 6}, ...
            tex_minus(strjoin(cells, ' & ')), tex_minus(strjoin(ic, ' & '))); %#ok<AGROW>
        if c == 2, tex(end) = tex(end) + " \hline"; end
        mdA(end + 1) = sprintf("| %d | %s | %s | %s | %s |", c, CON{c, 2}, CON{c, 3}, strjoin(cells, ' | '), strjoin(ic, ' | ')); %#ok<AGROW>
    end
    write_tex(fullfile(OUT, 'tabla_r4a_bootstrap.tex'), [tex, tex_tail()]);
    md = [md, mdA, ""];

    % --- B ---
    hdr = strings(1, numel(GROUPS));
    for g = 1:numel(GROUPS)
        hdr(g) = hd("\textbf{" + GROUP_TEX{g} + "}", sprintf('($n=%d$)', nnz(mask(char(GROUPS(g))))));
    end
    tex = tex_head('Prueba 2019--2025: desglose descriptivo por régimen. Cada celda: media de $D_k$ en \% mensual y, entre paréntesis, \% de meses del grupo con $D_k>0$. VIX alto: VIX$_k$ por encima de la mediana de su ventana; $r^{\mathrm{SPY}}_k$: retorno de SPY del mes $k$. Sin inferencia por grupo.', ...
        'tab:r4_regimen', ['|c|l|' repmat('r|', 1, numel(GROUPS))], '3pt');
    tex(end + 1) = "\textbf{N.º} & \textbf{Contraste} & " + strjoin(hdr, ' & ') + " \\ \hline";
    mdB = ["## B. Desglose por régimen (media % y, entre paréntesis, % D>0)", "", "CSV: `tabla_r4b_regimen.csv`; .tex: `tabla_r4b_regimen.tex`", "", ...
           "| N.º | A | B | " + strjoin(GROUPS + " (n=" + arrayfun(@(g) string(nnz(mask(char(g)))), GROUPS) + ")", ' | ') + " |", ...
           "|---|---|---|" + strjoin(repmat("---:", 1, numel(GROUPS)), '|') + "|"];
    for c = 1:NC
        cells = strings(1, numel(GROUPS));
        for g = 1:numel(GROUPS)
            r = RB(RB.n_contraste == c & RB.regimen == GROUPS(g), :);
            cells(g) = num(100 * r.media_D, 3) + " (" + num(100 * r.prop_D_pos, 1) + ")";
        end
        tex(end + 1) = sprintf('%d & %s & %s \\\\ \\hline', c, CON{c, 6}, tex_minus(strjoin(cells, ' & '))); %#ok<AGROW>
        if c == 2, tex(end) = tex(end) + " \hline"; end
        mdB(end + 1) = sprintf("| %d | %s | %s | %s |", c, CON{c, 2}, CON{c, 3}, strjoin(cells, ' | ')); %#ok<AGROW>
    end
    write_tex(fullfile(OUT, 'tabla_r4b_regimen.tex'), [tex, tex_tail()]);
    md = [md, mdB, ""];

    % --- C ---
    tex = tex_head('Prueba 2019--2025: cruce de VIX y retorno de SPY para los contrastes principales. Cada celda: media de $D_k$ en \% mensual, \% de meses con $D_k>0$ entre paréntesis y tamaño del grupo entre corchetes. Descriptivo.', ...
        'tab:r4_cruce', '|c|l|l|r|r|');
    tex(end + 1) = "\textbf{N.º} & \textbf{Contraste} & & \textbf{$r^{\mathrm{SPY}}_k<0$} & \textbf{$r^{\mathrm{SPY}}_k\ge 0$} \\ \hline";
    mdC = ["## C. Cruce 2x2 de los contrastes principales (media %, (% D>0), [n])", "", "CSV: `tabla_r4c_cruce.csv`; .tex: `tabla_r4c_cruce.tex`", "", ...
           "| N.º | Contraste | | SPY_k < 0 | SPY_k ≥ 0 |", "|---|---|---|---:|---:|"];
    VIXLAB = ["VIX alto", "VIX bajo"];
    for c = 1:2
        for i = 1:2
            cells = strings(1, 2);
            for j = 1:2
                r = RC(RC.n_contraste == c & RC.regimen == CROSS(i, j), :);
                cells(j) = num(100 * r.media_D, 3) + " (" + num(100 * r.prop_D_pos, 1) + ") [" + r.n_meses + "]";
            end
            if i == 1                              % sin \multirow: main_6.tex no carga ese paquete
                tex(end + 1) = sprintf('%d & %s & %s & %s \\\\ \\cline{3-5}', c, CON{c, 6}, VIXLAB(i), tex_minus(strjoin(cells, ' & '))); %#ok<AGROW>
            else
                tex(end + 1) = sprintf(' & & %s & %s \\\\ \\hline', VIXLAB(i), tex_minus(strjoin(cells, ' & '))); %#ok<AGROW>
            end
            mdC(end + 1) = sprintf("| %d | %s − %s | %s | %s |", c, CON{c, 2}, CON{c, 3}, VIXLAB(i), strjoin(cells, ' | ')); %#ok<AGROW>
        end
    end
    write_tex(fullfile(OUT, 'tabla_r4c_cruce.tex'), [tex, tex_tail()]);
    md = [md, mdC, ""];

    %% Figura de intervalos
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [100, 100, 860, 470]);
    ax = axes(fig); hold(ax, 'on');
    MK = {'o', 's', '^'}; OFF = [-0.22, 0, 0.22]; GR = [0.55, 0, 0.3];
    for q = 1:numel(ELLS)
        a = A(A.ell == ELLS(q), :);
        y = a.n_contraste + OFF(q);
        errorbar(ax, 100 * a.media_D, y, [], [], 100 * (a.media_D - a.IC95_inf), 100 * (a.IC95_sup - a.media_D), ...
            MK{q}, 'Color', GR(q) * [1 1 1], 'MarkerFaceColor', ifelse(q == 2, GR(q) * [1 1 1], [1 1 1]), ...
            'LineWidth', 1.3, 'MarkerSize', 6, 'CapSize', 4, 'DisplayName', sprintf('%s = %d', char(8467), ELLS(q)));
    end
    xline(ax, 0, 'k-', 'HandleVisibility', 'off');
    yline(ax, 2.5, 'k--', 'HandleVisibility', 'off');
    lab = cell(NC, 1);
    for c = 1:NC
        lab{c} = sprintf('%d: %s', c, tex_to_axis(CON{c, 6}));
    end
    set(ax, 'YDir', 'reverse', 'YTick', 1:NC, 'YTickLabel', lab, 'YLim', [0.4, NC + 0.6], ...
        'TickLabelInterpreter', 'tex', 'FontSize', 10);
    xlabel(ax, 'Media de D_k (% mensual)');
    title(ax, 'IC 95 % de la media de D_k, prueba');
    text(ax, ax.XLim(2), 1.5, 'principal ', 'HorizontalAlignment', 'right', 'FontAngle', 'italic', 'FontSize', 9);
    text(ax, ax.XLim(2), 5, 'exploratorios ', 'HorizontalAlignment', 'right', 'FontAngle', 'italic', 'FontSize', 9);
    grid(ax, 'on'); box(ax, 'on');
    legend(ax, 'Location', 'southwest');
    exportgraphics(fig, fullfile(OUT, 'ic_contrastes.pdf'), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(OUT, 'ic_contrastes.png'), 'Resolution', 200);
    close(fig);
    md = [md, "## Figura", "", "`ic_contrastes.pdf/.png`: media de D_k (% mensual) e IC 95 % por bootstrap de los siete contrastes, " + ...
          "un marcador por ℓ ∈ {3, 6, 12}; la línea discontinua separa el contraste principal (1 y 2) de los exploratorios.", ""];

    %% Verificacion
    V = vertcat(chk{:});
    writetable(V, fullfile(OUT, 'r4_verificacion.csv'));
    md = [md, "## Verificación", "", sprintf("%d comprobaciones, %d fallidas (detalle en `r4_verificacion.csv`).", ...
          height(V), sum(~V.ok))];
    writelines(md, fullfile(OUT, 'TABLAS_R4.md'), 'Encoding', 'UTF-8');
    fprintf('R4: %d comprobaciones, %d fallidas. Salidas en %s\n', height(V), sum(~V.ok), OUT);
    if any(~V.ok)
        disp(V(~V.ok, :));
        error('r4_inferencia:verificacion', 'Hay comprobaciones fallidas.');
    end
end


function k = ym(t)
% Clave ano-mes para alinear fechas de fin de mes
    k = year(t) * 100 + month(t);
end


function s = num(v, d)
% Numero con d decimales; evita "-0.000"
    s = string(sprintf('%.*f', d, v));
    if str2double(s) == 0, s = string(sprintf('%.*f', d, 0)); end
end


function T = shown_check(chequeo, c, v, d)
% El texto impreso, releido, coincide con el valor redondeado
    T = check_row(chequeo, c, round(v, d) + 0, str2double(num(v, d)));
end


function t = tex_head(caption, label, cols, sep)
% sep: \tabcolsep (por defecto 4pt)
    if nargin < 4, sep = '4pt'; end
    t = ["% Generado por results_finales/r4_inferencia.m; no editar a mano.", ...
         "\begin{table}[h]", "\centering", "\footnotesize", "\setlength{\tabcolsep}{" + string(sep) + "}", ...
         "\caption{" + string(caption) + "}\label{" + string(label) + "}", ...
         "\begin{tabular}{" + string(cols) + "}", "\hline"];
end


function s = hd(a, b)
% Encabezado de columna en dos lineas (tabla anidada; no requiere makecell)
    s = "\begin{tabular}[c]{@{}c@{}}" + string(a) + "\\" + string(b) + "\end{tabular}";
end


function t = tex_tail()
    t = ["\end{tabular}", "\end{table}"];
end


function write_tex(path, lines)
    writelines(lines, path, 'Encoding', 'UTF-8');
end


function s = tex_to_axis(s)
% Etiqueta LaTeX de la tabla -> interprete tex de MATLAB
    s = strrep(s, '$', '');
    s = strrep(s, '\mathrm{Nom}', 'Nom');
    s = strrep(s, '^\star', '^*');
    s = strrep(s, '-', ' − ');
end


function v = ifelse(c, a, b)
    if c, v = a; else, v = b; end
end


function T = check_row(chequeo, contraste, esperado, obtenido, tol)
    if nargin < 5, tol = 1e-12; end
    ok = isequal(esperado, obtenido) || abs(esperado - obtenido) <= tol * max(1, abs(esperado));
    T = table(string(chequeo), contraste, esperado, obtenido, abs(esperado - obtenido), ok, ...
        'VariableNames', {'chequeo', 'contraste', 'esperado', 'obtenido', 'dif_abs', 'ok'});
end


function s = tex_minus(s)
% Signo menos matematico en las cifras negativas de una fila .tex
    s = regexprep(s, '(?<![\w)$])-(?=\d)', '$-$');
end
