clearvars -except showWarmups_override; clc; close all;
%COMPARE_RUNS  Compare Cp across all logged runs (warm-ups, Block 1, Block 2).
%   - Same filtering as PressureDataPlots.m (median + Savitzky-Golay)
%   - Compensates the pitot/tap time lag (tubing length mismatch)
%   - Fits tap = slope*q + intercept  (slope = Cp, intercept = offset)
%   - Cp median/IQR per speed band
%   - Per-lap Cp for the non-warm-up runs (laps from esp32_lap_index.csv,
%     made by align_laps.py; see LAP_ALIGNMENT.md)
%   Writes compare_runs_summary.csv and compare_runs_laps.csv next to this script.

%% Run list — edit labels / warm-up flags here
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
dataDir = fullfile(scriptDir, '..', 'esp32_data');

runs = {
%   file                     label                     isWarmup
    '1107_1554/run000.csv',  'Block 0a warm-up',       true
    '1107_1708/run000.csv',  'Block 0b run00 warm-up', true
    '1107_1708/run001.csv',  'Block 0b run01 warm-up', true
    '1107_1745/run000.csv',  'Block 1 CAD RH',         false
    '1108_1356/run006.csv',  'Block 2 Squat Down',     false
};
showWarmups = true;   % false = plot only the non-warm-up runs
if exist('showWarmups_override', 'var'), showWarmups = showWarmups_override; end  % set by make_results_package.m

%% Parameters
spikeWindow = 5;      % median filter window
sgOrder     = 3;      % Savitzky-Golay order
sgWindow    = 31;     % Savitzky-Golay window (odd)
rho         = 1.225;  % kg/m^3 (matches firmware)
maxLag      = 30;     % samples searched each way for pitot/tap lag
qFitMin     = 20;     % Pa — samples used for tap-vs-q regression
qCpMin      = 50;     % Pa (~9 m/s) — samples used for q-weighted Cp
qBandMin    = 5;      % Pa — minimum q for per-sample Cp in speed bands
minBinN     = 10;     % minimum samples for a speed band to be reported
bandEdges   = [5 8 10 12 14 16 18 20];   % m/s
minLapN     = 20;     % minimum q > qFitMin samples for a lap fit

%% Lap boundaries (non-warm-up runs only)
lapIdx = readtable(fullfile(scriptDir, 'esp32_lap_index.csv'), 'TextType', 'char');

%% Process each run
nR = size(runs, 1);
nB = numel(bandEdges) - 1;
bandCenters = bandEdges(1:end-1) + diff(bandEdges)/2;
R = struct([]);

for k = 1:nR
    d  = readtable(fullfile(dataDir, runs{k,1}));
    dt = median(diff(d.time_ms)) / 1000;
    t  = d.time_ms / 1000;

    q = sgolayfilt(medfilt1(d.pitot_pa, spikeWindow), sgOrder, sgWindow);
    p = sgolayfilt(medfilt1(d.tap_pa,   spikeWindow), sgOrder, sgWindow);

    lag    = best_lag(q, p, maxLag);
    [q, p, pIdx] = apply_lag(q, p, lag);
    t      = t(pIdx);   % time stamp of each (lag-paired) sample
    v      = sqrt(2 * max(q, 0) / rho);

    % Regression tap vs q
    m  = q > qFitMin;
    c  = polyfit(q(m), p(m), 1);
    rr = corrcoef(q(m), p(m));

    % q-weighted Cp at decent q
    mq = q > qCpMin;

    % Speed-band Cp
    cp    = p ./ q;
    valid = q > qBandMin;
    [bMed, bLo, bHi, bN] = deal(nan(1, nB));
    for b = 1:nB
        sel = valid & v > bandEdges(b) & v <= bandEdges(b+1);
        bN(b) = sum(sel);
        if bN(b) >= minBinN
            x = cp(sel);
            bMed(b) = median(x);
            bLo(b)  = qtile(x, 0.25);
            bHi(b)  = qtile(x, 0.75);
        end
    end

    R(k).label     = runs{k,2};
    R(k).isWarmup  = runs{k,3};
    R(k).file      = runs{k,1};
    R(k).t         = t;
    R(k).v         = v;
    R(k).q         = q;
    R(k).p         = p;
    R(k).fitMask   = m;
    R(k).lag_ms    = lag * dt * 1000;
    R(k).slope     = c(1);
    R(k).intercept = c(2);
    R(k).r         = abs(rr(1,2));
    R(k).cp_qw     = sum(p(mq)) / sum(q(mq));
    R(k).vmax      = max(v);
    R(k).bMed      = bMed;
    R(k).bLo       = bLo;
    R(k).bHi       = bHi;
    R(k).bN        = bN;

    % Per-lap Cp
    L = lapIdx(strcmp(lapIdx.esp_file, runs{k,1}), :);
    nL = height(L);
    [lSlope, lInt, lQw, lV] = deal(nan(nL, 1));
    for j = 1:nL
        inLap = t >= L.esp_start_ms(j)/1000 & t < L.esp_end_ms(j)/1000;
        lV(j) = mean(v(inLap));
        mj = inLap & m;
        if sum(mj) >= minLapN
            cj = polyfit(q(mj), p(mj), 1);
            lSlope(j) = cj(1);
            lInt(j)   = cj(2);
        end
        mqj = inLap & mq;
        if any(mqj), lQw(j) = sum(p(mqj)) / sum(q(mqj)); end
    end
    R(k).laps = table(L.lap, L.note, strcmp(L.note, 'Hotlap'), lSlope, lInt, lQw, lV, ...
        'VariableNames', {'lap', 'note', 'isHot', 'Cp_slope', 'Intercept_Pa', ...
                          'Cp_qweighted', 'Vmean_ms'});
end

%% Summary table
T = table(string({R.label})', [R.lag_ms]', [R.slope]', [R.intercept]', ...
          [R.r]', [R.cp_qw]', [R.vmax]', ...
    'VariableNames', {'Run', 'Lag_ms', 'Cp_slope', 'Intercept_Pa', ...
                      'r', 'Cp_qweighted', 'Vmax_ms'});
bandNames = arrayfun(@(a,b) sprintf('Cp_%g_%g', a, b), ...
    bandEdges(1:end-1), bandEdges(2:end), 'UniformOutput', false);
T = [T, array2table(vertcat(R.bMed), 'VariableNames', bandNames)];

fprintf('Lag > 0: tap leads pitot; lag < 0: tap lags pitot.\n\n');
disp(T);
writetable(T, fullfile(scriptDir, 'compare_runs_summary.csv'));

% Per-lap table
main = find(~[R.isWarmup]);
LT = table();
for k = main
    if isempty(R(k).laps), continue, end
    LT = [LT; [table(repmat(string(R(k).label), height(R(k).laps), 1), ...
        'VariableNames', {'Run'}), R(k).laps]]; %#ok<AGROW>
end
fprintf('\nPer-lap Cp (non-warm-up runs):\n');
disp(LT);
writetable(LT, fullfile(scriptDir, 'compare_runs_laps.csv'));

fprintf('Hot laps only (mean +/- std across laps):\n');
for k = main
    hl = R(k).laps(R(k).laps.isHot, :);
    fprintf('  %-22s n = %2d   Cp slope %.3f +/- %.3f   q-weighted Cp %.3f +/- %.3f\n', ...
        R(k).label, height(hl), mean(hl.Cp_slope, 'omitnan'), std(hl.Cp_slope, 'omitnan'), ...
        mean(hl.Cp_qweighted, 'omitnan'), std(hl.Cp_qweighted, 'omitnan'));
end

if numel(main) == 2
    a = R(main(1)); b = R(main(2));
    fprintf('\n%s vs %s:\n', b.label, a.label);
    fprintf('  Cp slope:      %.3f -> %.3f  (%+.1f%%)\n', a.slope, b.slope, ...
        100 * (b.slope - a.slope) / abs(a.slope));
    fprintf('  q-weighted Cp: %.3f -> %.3f  (%+.1f%%)\n', a.cp_qw, b.cp_qw, ...
        100 * (b.cp_qw - a.cp_qw) / abs(a.cp_qw));
end

%% Colors / style (matches PressureDataPlots.m)
bg_color   = [0.12 0.12 0.12];
ax_color   = [0.18 0.18 0.18];
grid_color = [0.28 0.28 0.28];
mainColors = [1.0 0.5 0.1; 0.2 0.6 1.0; 0.9 0.2 0.3; 0.2 0.85 0.5];
warmShades = [0.45; 0.6; 0.75];

cols   = zeros(nR, 3);
styles = cell(nR, 1);
iw = 0; im = 0;
for k = 1:nR
    if R(k).isWarmup
        iw = iw + 1;
        cols(k,:) = warmShades(mod(iw-1, numel(warmShades)) + 1) * [1 1 1];
        styles{k} = '--';
    else
        im = im + 1;
        cols(k,:) = mainColors(mod(im-1, size(mainColors,1)) + 1, :);
        styles{k} = '-';
    end
end

plotIdx = find(~[R.isWarmup] | showWarmups);

style_ax = @(ax) set(ax, 'Color', ax_color, 'XColor', 'w', 'YColor', 'w', ...
    'GridColor', grid_color, 'GridAlpha', 0.5, 'FontSize', 10, 'Box', 'off');
style_leg = @(lg) set(lg, 'TextColor', 'w', 'Color', [0.2 0.2 0.2], 'FontSize', 9);

%% Figure 1 — tap vs q with fit lines
fig1 = figure('Position', [50, 50, 1200, 750], 'Color', bg_color);
ax = axes(fig1); hold(ax, 'on');
h = gobjects(0); names = {};
for k = plotIdx
    idx = find(R(k).fitMask);
    idx = idx(1:3:end);   % thin the scatter for readability
    scatter(ax, R(k).q(idx), R(k).p(idx), 6, cols(k,:), 'filled', ...
        'MarkerFaceAlpha', 0.15, 'MarkerEdgeColor', 'none');
    qq = linspace(qFitMin, max(R(k).q), 50);
    h(end+1) = plot(ax, qq, polyval([R(k).slope R(k).intercept], qq), ...
        styles{k}, 'Color', cols(k,:), 'LineWidth', 2.2); %#ok<SAGROW>
    names{end+1} = sprintf('%s  (Cp = %.2f, b = %+.1f Pa)', ...
        R(k).label, R(k).slope, R(k).intercept); %#ok<SAGROW>
end
xlabel(ax, 'Pitot dynamic pressure q (Pa)', 'Color', 'w', 'FontSize', 11);
ylabel(ax, 'Tap pressure (Pa)', 'Color', 'w', 'FontSize', 11);
title(ax, sprintf('Tap vs q  (filtered, lag-compensated, q > %d Pa)', qFitMin), ...
    'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
grid(ax, 'on'); style_ax(ax);
style_leg(legend(ax, h, names, 'Location', 'southwest'));

%% Figure 2 — Cp vs speed band
fig2 = figure('Position', [80, 80, 1200, 700], 'Color', bg_color);
ax = axes(fig2); hold(ax, 'on');
h = gobjects(0); names = {};
for k = plotIdx
    h(end+1) = errorbar(ax, bandCenters, R(k).bMed, ...
        R(k).bMed - R(k).bLo, R(k).bHi - R(k).bMed, ['o' styles{k}], ...
        'Color', cols(k,:), 'MarkerFaceColor', cols(k,:), ...
        'LineWidth', 1.8, 'CapSize', 6); %#ok<SAGROW>
    names{end+1} = R(k).label; %#ok<SAGROW>
end
xline(ax, sqrt(2 * qCpMin / rho), ':', sprintf('q = %d Pa', qCpMin), ...
    'Color', [0.7 0.7 0.7], 'LabelVerticalAlignment', 'bottom', ...
    'FontSize', 9, 'HandleVisibility', 'off');
xlabel(ax, 'Airspeed band center (m/s)', 'Color', 'w', 'FontSize', 11);
ylabel(ax, 'Cp  (median, IQR bars)', 'Color', 'w', 'FontSize', 11);
title(ax, 'Cp by speed band', 'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
xlim(ax, [bandEdges(1) bandEdges(end)]);
grid(ax, 'on'); style_ax(ax);
style_leg(legend(ax, h, names, 'Location', 'southeast'));

%% Figure 3 — slope and intercept per run
fig3 = figure('Position', [110, 110, 1200, 600], 'Color', bg_color);
sgtitle(fig3, 'Regression results per run', 'Color', 'w', ...
    'FontSize', 13, 'FontWeight', 'bold');
labels = {R(plotIdx).label};

ax = subplot(1, 2, 1);
bh = bar(ax, [R(plotIdx).slope], 'FaceColor', 'flat', 'EdgeColor', 'none');
bh.CData = cols(plotIdx, :);
ylabel(ax, 'Cp (fit slope)', 'Color', 'w', 'FontSize', 11);
set(ax, 'XTickLabel', labels, 'XTickLabelRotation', 25);
grid(ax, 'on'); style_ax(ax);

ax = subplot(1, 2, 2);
bh = bar(ax, [R(plotIdx).intercept], 'FaceColor', 'flat', 'EdgeColor', 'none');
bh.CData = cols(plotIdx, :);
ylabel(ax, 'Intercept (Pa) — offset not explained by q', 'Color', 'w', 'FontSize', 11);
set(ax, 'XTickLabel', labels, 'XTickLabelRotation', 25);
grid(ax, 'on'); style_ax(ax);

%% Figure 4 — per-lap Cp (non-warm-up runs), x-axis labelled by lap
%  Filled markers = hot laps; hollow markers + "*" = out-laps / irregular laps
%  (see the note column in esp32_lap_index.csv). Dashed line = hot-lap mean.
fig4 = figure('Position', [140, 60, 1300, 1050], 'Color', bg_color);
sgtitle(fig4, 'Per-lap results  (filled = hot lap, hollow / * = out-lap or irregular)', ...
    'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
nLapMax = max(arrayfun(@(r) height(r.laps), R(main)));
offs = linspace(-0.12, 0.12, numel(main));   % small x offset so runs don't overlap

panels = {'Cp_slope',     'Cp (fit slope)';
          'Cp_qweighted', sprintf('q-weighted Cp (q > %d Pa)', qCpMin);
          'Vmean_ms',     'Mean airspeed (m/s)'};
for s = 1:size(panels, 1)
    ax = subplot(size(panels, 1), 1, s); hold(ax, 'on');
    h = gobjects(0); names = {};
    for i = 1:numel(main)
        k  = main(i);
        Lk = R(k).laps;
        y  = Lk.(panels{s,1});
        x  = Lk.lap + offs(i);
        plot(ax, x, y, '-', 'Color', [cols(k,:) 0.4], 'LineWidth', 1, 'HandleVisibility', 'off');
        h(end+1) = plot(ax, x(Lk.isHot), y(Lk.isHot), 'o', 'Color', cols(k,:), ...
            'MarkerFaceColor', cols(k,:), 'MarkerSize', 7); %#ok<SAGROW>
        plot(ax, x(~Lk.isHot), y(~Lk.isHot), 'o', 'Color', cols(k,:), ...
            'MarkerFaceColor', 'none', 'MarkerSize', 7, 'LineWidth', 1.5, 'HandleVisibility', 'off');
        yline(ax, mean(y(Lk.isHot), 'omitnan'), '--', 'Color', cols(k,:), ...
            'LineWidth', 1, 'Alpha', 0.7, 'HandleVisibility', 'off');
        names{end+1} = sprintf('%s  (hot-lap mean %.2f)', R(k).label, ...
            mean(y(Lk.isHot), 'omitnan')); %#ok<SAGROW>
        % Lap labels next to each point, with * on out-laps / irregular laps
        for j = 1:height(Lk)
            if isnan(y(j)), continue, end
            lbl = sprintf('L%d', Lk.lap(j));
            if ~Lk.isHot(j), lbl = [lbl '*']; end %#ok<AGROW>
            text(ax, x(j), y(j), ['  ' lbl], 'Color', cols(k,:), 'FontSize', 7, ...
                'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
        end
    end
    set(ax, 'XTick', 1:nLapMax, 'XTickLabel', compose('L%d', 1:nLapMax));
    xlim(ax, [0.5 nLapMax + 0.5]);
    ylabel(ax, panels{s,2}, 'Color', 'w', 'FontSize', 11);
    grid(ax, 'on'); style_ax(ax);
    style_leg(legend(ax, h, names, 'Location', 'best'));
end
xlabel(ax, 'Lap', 'Color', 'w', 'FontSize', 11);

%% ===================== Local Functions =====================

function lag = best_lag(q, p, maxLag)
%BEST_LAG  Lag (samples) that best pairs tap(i) with q(i+lag).
    qa = q - mean(q);
    pa = p - mean(p);
    n    = numel(q);
    lags = -maxLag:maxLag;
    idx  = (maxLag + 1):(n - maxLag);
    r    = nan(size(lags));
    for i = 1:numel(lags)
        c = corrcoef(qa(idx + lags(i)), pa(idx));
        r(i) = c(1, 2);
    end
    [~, j] = max(abs(r));
    lag = lags(j);
end

function [q2, p2, pIdx] = apply_lag(q, p, lag)
%APPLY_LAG  Trim both signals so p2(i) lines up with q2(i) = q(i+lag).
%   pIdx are the original sample indices of p2 (use to trim time too).
    n = numel(q);
    if lag >= 0
        q2 = q(1+lag:n);
        pIdx = (1:n-lag)';
    else
        q2 = q(1:n+lag);
        pIdx = (1-lag:n)';
    end
    p2 = p(pIdx);
end

function y = qtile(x, prob)
%QTILE  Linear-interpolated quantile (no Statistics Toolbox needed).
    x   = sort(x(:));
    pos = 1 + (numel(x) - 1) * prob;
    lo  = floor(pos);
    hi  = ceil(pos);
    y   = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
