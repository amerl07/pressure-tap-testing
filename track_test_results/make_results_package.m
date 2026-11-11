%MAKE_PACKAGE  Build the plots + data package in track_test_results/processed_results_package/.
%   Uses PressureDataPlots.m (time series with lap dividers) and compare_runs.m
%   (per-lap / per-run Cp), so the numbers match those scripts exactly.
%   Non-warm-up runs only. Run from anywhere:  run('track_test_results/make_results_package.m')

pkgScriptDir = fileparts(mfilename('fullpath'));
repoDir = fullfile(pkgScriptDir, '..');
outDir  = fullfile(pkgScriptDir, 'processed_results_package');
plotDir = fullfile(outDir, 'plots');
dataDir = fullfile(outDir, 'data');
rawDir  = fullfile(dataDir, 'raw_esp32');
for d = {outDir, plotDir, dataDir, rawDir}
    if ~exist(d{1}, 'dir'), mkdir(d{1}); end
end
% The called scripts clear the workspace, so keep paths in appdata
setappdata(0, 'vd_pkg_dirs', struct('repo', repoDir, 'out', outDir, 'plot', plotDir, ...
    'data', dataDir, 'raw', rawDir, 'script', pkgScriptDir, 'oldDir', pwd));

%% 1) Time series with lap dividers (PressureDataPlots.m makes 5 figures per run)
cd(repoDir);   % PressureDataPlots.m uses repo-relative paths
run(fullfile(repoDir, 'PressureDataPlots.m'));   % clears the workspace
P = getappdata(0, 'vd_pkg_dirs');
export_fig_dark(figure(1), fullfile(P.plot, '4_timeseries_block1_CAD_RH.png'));
export_fig_dark(figure(6), fullfile(P.plot, '5_timeseries_block2_squat_down.png'));

% Block 1 vs Block 2, one channel per image (single-channel figures: run 1 = 2..4, run 2 = 7..9)
channels = {2, 'pitot'; 3, 'tap'; 4, 'airspeed'};
for c = 1:size(channels, 1)
    f = figure('Position', [50, 50, 1600, 1000], 'Color', get(figure(1), 'Color'));
    newAx = gobjects(1, 2);
    for r = 1:2
        src = figure(channels{c,1} + 5*(r-1));
        srcAx = findobj(src, 'Type', 'axes');
        srcLg = findobj(src, 'Type', 'Legend');
        copied = copyobj([srcLg, srcAx], f);
        newAx(r) = copied(2);
        set(newAx(r), 'Units', 'normalized', 'OuterPosition', [0, 1 - r/2, 1, 0.5]);
    end
    % Same y-scale on both so the runs can be compared directly
    yl = [ylim(newAx(1)); ylim(newAx(2))];
    ylim(newAx, [min(yl(:,1)), max(yl(:,2))]);
    export_fig_dark(f, fullfile(P.plot, sprintf('%d_%s_block1_vs_block2.png', 5 + c, channels{c,2})));
end

% Overlays: both runs on one axis, x = time since lap 1 start (filtered signals only)
lapIdxPkg = readtable(fullfile(P.script, 'esp32_lap_index.csv'), 'TextType', 'char');
ylabels = {'Pitot q (Pa)', 'Tap pressure (Pa)', 'Airspeed (m/s)'};
for c = 1:size(channels, 1)
    srcFigs = [figure(channels{c,1}), figure(channels{c,1} + 5)];
    export_fig_dark(make_overlay(srcFigs, lapIdxPkg, ylabels{c}), ...
        fullfile(P.plot, sprintf('%d_%s_overlay.png', 8 + c, channels{c,2})));
end
close all;

%% 2) Cp comparison (compare_runs.m), warm-ups hidden
showWarmups_override = false; %#ok<NASGU>
run(fullfile(P.script, 'compare_runs.m'));        % clears everything except the override
P = getappdata(0, 'vd_pkg_dirs');
export_fig_dark(fig4, fullfile(P.plot, '1_per_lap_cp.png'));
export_fig_dark(fig1, fullfile(P.plot, '2_tap_vs_q.png'));
export_fig_dark(fig2, fullfile(P.plot, '3_cp_by_speed_band.png'));

%% 3) Processed data
main = find(~[R.isWarmup]);
writetable(T(main, :), fullfile(P.data, 'run_summary.csv'));
writetable(LT, fullfile(P.data, 'per_lap_results.csv'));

% Hot-lap statistics per run
H = table();
for k = main
    hl = R(k).laps(R(k).laps.isHot, :);
    H = [H; table(string(R(k).label), height(hl), ...
        mean(hl.Cp_qweighted, 'omitnan'), std(hl.Cp_qweighted, 'omitnan'), ...
        mean(hl.Cp_slope, 'omitnan'), std(hl.Cp_slope, 'omitnan'), ...
        mean(hl.Vmean_ms, 'omitnan'), ...
        'VariableNames', {'Run', 'n_hotlaps', 'Cp_qweighted_mean', 'Cp_qweighted_std', ...
                          'Cp_slope_mean', 'Cp_slope_std', 'Vmean_ms'})]; %#ok<AGROW>
end
writetable(H, fullfile(P.data, 'hotlap_summary.csv'));

% Lap-tagged, filtered, lag-compensated time series (one CSV per run)
for k = main
    Lk = lapIdx(strcmp(lapIdx.esp_file, R(k).file), :);
    t  = R(k).t;
    lap = zeros(size(t)); note = repmat({''}, size(t)); hot = false(size(t));
    for j = 1:height(Lk)
        in = t >= Lk.esp_start_ms(j)/1000 & t < Lk.esp_end_ms(j)/1000;
        lap(in) = Lk.lap(j); note(in) = Lk.note(j); hot(in) = strcmp(Lk.note{j}, 'Hotlap');
    end
    cp = R(k).p ./ R(k).q;
    cp(R(k).q <= qBandMin) = NaN;
    TS = table(round(t, 3), lap, note, hot, round(R(k).q, 2), round(R(k).p, 2), ...
        round(R(k).v, 2), round(cp, 3), ...
        'VariableNames', {'time_s', 'lap', 'lap_note', 'is_hotlap', 'q_pa', 'tap_pa', ...
                          'airspeed_ms', 'cp'});
    name = regexprep(lower(R(k).label), '[^a-z0-9]+', '_');
    writetable(TS, fullfile(P.data, sprintf('timeseries_%s.csv', name)));

    % Raw logger file, renamed so the run is obvious
    copyfile(fullfile(P.repo, 'esp32_data', R(k).file), ...
        fullfile(P.raw, sprintf('%s__%s', name, strrep(R(k).file, '/', '_'))));
end

% Lap boundaries and car setup sheet
copyfile(fullfile(P.script, 'esp32_lap_index.csv'), fullfile(P.data, 'lap_index.csv'));
copyfile(fullfile(P.script, 'Ride Height, Weight Distribution and Alignment - Sheet1.csv'), ...
    fullfile(P.data, 'car_setup.csv'));

cd(P.oldDir);
rmappdata(0, 'vd_pkg_dirs');
fprintf('\nVD package written to %s\n', P.out);

%% ===================== Local Functions =====================
function f = make_overlay(srcFigs, lapIdx, ylab)
%MAKE_OVERLAY  Filtered trace of each run on one axis, x = time since that run's lap 1 start.
%   Lap dividers are drawn in each run's colour (Block 1 labels at the top, Block 2 at the bottom).
    runNames = {'Block 1 CAD RH', 'Block 2 Squat Down'};
    settings = {'CAD Ride Height', 'Squat Down'};
    cols = [1.0 0.5 0.1; 0.2 0.6 1.0];   % same colours as compare_runs.m
    f  = figure('Position', [50, 50, 1600, 700], 'Color', [0.12 0.12 0.12]);
    ax = axes(f); hold(ax, 'on');
    h  = gobjects(1, 2);
    yall = [];
    for r = 1:2
        srcAx = findobj(srcFigs(r), 'Type', 'axes');
        ln = findobj(srcAx, 'Type', 'line', 'LineWidth', 2);   % filtered trace
        L  = lapIdx(strcmp(lapIdx.setting, settings{r}), :);
        t0 = L.esp_start_ms(1) / 1000;
        h(r) = plot(ax, ln.XData - t0, ln.YData, 'Color', cols(r,:), 'LineWidth', 1.6);
        yall = [yall, ln.YData]; %#ok<AGROW>
        if r == 1, va = 'top'; else, va = 'bottom'; end
        for j = 1:height(L)
            lbl = sprintf('L%d', L.lap(j));
            if ~strcmp(L.note{j}, 'Hotlap'), lbl = [lbl '*']; end %#ok<AGROW>
            xline(ax, L.esp_start_ms(j)/1000 - t0, '--', lbl, 'Color', cols(r,:), ...
                'Alpha', 0.45, 'LineWidth', 0.8, 'FontSize', 8, ...
                'LabelVerticalAlignment', va, 'LabelHorizontalAlignment', 'right', ...
                'LabelOrientation', 'horizontal', 'HandleVisibility', 'off');
        end
    end
    yall = yall(isfinite(yall));
    pad = 0.12 * (max(yall) - min(yall));
    ylim(ax, [min(yall) - pad, max(yall) + pad]);
    xlim(ax, [0, max(arrayfun(@(l) max(l.XData), h))]);
    xlabel(ax, 'Time since lap 1 start (s)', 'Color', 'w', 'FontSize', 11);
    ylabel(ax, ylab, 'Color', 'w', 'FontSize', 11);
    sgtitle(f, sprintf('%s  |  Block 1 CAD RH vs Block 2 Squat Down (filtered)', ylab), ...
        'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
    legend(ax, h, runNames, 'TextColor', 'w', 'Color', [0.2 0.2 0.2], ...
        'Location', 'northoutside', 'Orientation', 'horizontal', 'FontSize', 9);
    grid(ax, 'on');
    set(ax, 'Color', [0.18 0.18 0.18], 'XColor', 'w', 'YColor', 'w', ...
        'GridColor', [0.28 0.28 0.28], 'GridAlpha', 0.5, 'FontSize', 10, 'Box', 'off');
end

function export_fig_dark(fig, path)
    exportgraphics(fig, path, 'BackgroundColor', 'current', 'Resolution', 150);
end
