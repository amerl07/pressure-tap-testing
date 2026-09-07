clear; clc; close all;

%% Load Data
data = readtable('run000.csv'); % REPLACE THIS WITH THE FILE YOU WANT TO PLOT

t        = data.time_ms / 1000;
pitot    = data.pitot_pa;
tap      = data.tap_pa;
airspeed = data.airspeed_ms;
Cp       = data.Cp;

%% Parameters — tune these for on-car data
sgWindow          = 31;   % Savitzky-Golay window — must be odd, increase for smoother
sgOrder           = 3;    % Savitzky-Golay polynomial order — 3 preserves peaks well
spikeWindow       = 5;    % median filter window for spike removal
pitot_floor       = 5;    % Pa — minimum pitot to show Cp
min_airspeed      = 2;    % m/s — threshold for "moving"
zero_timeout      = 20;   % seconds — mask data only if stopped longer than this
ylim_pad          = 0.15; % fraction of data range added as headroom on every y-axis

%% Stage 1 — Spike removal (median filter)
pitot_ds    = medfilt1(pitot,    spikeWindow);
tap_ds      = medfilt1(tap,      spikeWindow);
airspeed_ds = medfilt1(airspeed, spikeWindow);

%% Stage 2 — Savitzky-Golay smoothing
pitot_filt    = sgolayfilt(pitot_ds,    sgOrder, sgWindow);
tap_filt      = sgolayfilt(tap_ds,      sgOrder, sgWindow);
airspeed_filt = sgolayfilt(airspeed_ds, sgOrder, sgWindow);

%% Smart masking — only remove data if stopped > zero_timeout seconds
dt           = mean(diff(t));
zero_samples = round(zero_timeout / dt);
is_stopped   = airspeed_filt < min_airspeed;

flow_mask = ~is_stopped;
stopped_regions = bwconncomp(is_stopped);
for i = 1:stopped_regions.NumObjects
    region = stopped_regions.PixelIdxList{i};
    if length(region) > zero_samples
        flow_mask(region) = false;
    else
        flow_mask(region) = true;
    end
end

%% Trim to active range
first_flow = find(flow_mask, 1, 'first');
last_flow  = find(flow_mask, 1, 'last');
plot_range = first_flow:last_flow;

t_plot       = t(plot_range);
pitot_raw    = pitot(plot_range);
tap_raw      = tap(plot_range);
airspeed_raw = airspeed(plot_range);
pitot_f      = pitot_filt(plot_range);
tap_f        = tap_filt(plot_range);
airspeed_f   = airspeed_filt(plot_range);
flow_p       = flow_mask(plot_range);

%% Cp — spike removal then Savitzky-Golay
Cp_ds = medfilt1(fillmissing(Cp, 'linear'), spikeWindow);
Cp_ds(isnan(Cp)) = NaN;
Cp_clean = Cp_ds(plot_range);
Cp_clean(pitot_f < pitot_floor) = NaN;
Cp_clean(~flow_p) = NaN;

Cp_filled = fillmissing(Cp_clean, 'linear');
Cp_f = sgolayfilt(Cp_filled, sgOrder, sgWindow);
Cp_f(~flow_p) = NaN;
Cp_f(pitot_f < pitot_floor) = NaN;

%% Apply flow mask
pitot_f(~flow_p)    = NaN;
tap_f(~flow_p)      = NaN;
airspeed_f(~flow_p) = NaN;

%% Run Statistics
run_duration = sum(flow_p) * dt;
max_airspeed = max(airspeed_f, [], 'omitnan');
mean_Cp      = mean(Cp_f, 'omitnan');
max_pitot    = max(pitot_f, [], 'omitnan');

%% Colors
raw_color      = [0.55 0.55 0.55];
pitot_color    = [0.2  0.6  1.0 ];
tap_color      = [1.0  0.5  0.1 ];
airspeed_color = [0.2  0.85 0.5 ];
cp_color       = [0.9  0.2  0.3 ];
bg_color       = [0.12 0.12 0.12];
ax_color       = [0.18 0.18 0.18];
grid_color     = [0.28 0.28 0.28];

%% Auto-scaled y-limits — data-driven, with padding, so peaks are never clipped
pitot_ylim    = auto_ylim([pitot_raw; pitot_f+5; pitot_f-5], false, ylim_pad, [-20 50]);
tap_ylim      = auto_ylim([tap_raw; tap_f],                   true,  ylim_pad, [-50 50]);
airspeed_ylim = auto_ylim([airspeed_raw; airspeed_f],         false, ylim_pad, [0 40]);
airspeed_ylim(1) = min(airspeed_ylim(1), 0);
Cp_ylim       = auto_ylim([Cp_clean; Cp_f],                   true,  ylim_pad, [-1.5 1.5]);

style_ax = @(ax) set(ax, ...
    'Color', ax_color, ...
    'XColor', 'w', ...
    'YColor', 'w', ...
    'GridColor', grid_color, ...
    'GridAlpha', 0.5, ...
    'FontSize', 10, ...
    'Box', 'off');

%% Aggregate figure — all four channels stacked
fig_all = figure('Position', [50, 50, 1600, 950], 'Color', bg_color);
sgtitle('DAQ — C-Channel Pressure Tap Validation', ...
    'Color', 'w', 'FontSize', 15, 'FontWeight', 'bold');

ax1 = subplot(4,1,1);
draw_pitot(ax1, t_plot, pitot_raw, pitot_f, pitot_color, raw_color, pitot_ylim, style_ax);

ax2 = subplot(4,1,2);
draw_tap(ax2, t_plot, tap_raw, tap_f, tap_color, raw_color, tap_ylim, style_ax);

ax3 = subplot(4,1,3);
draw_airspeed(ax3, t_plot, airspeed_raw, airspeed_f, airspeed_color, raw_color, airspeed_ylim, style_ax);

ax4 = subplot(4,1,4);
draw_cp(ax4, t_plot, Cp_clean, Cp_f, cp_color, raw_color, Cp_ylim, style_ax);
xlabel(ax4, 'Time (s)', 'Color', 'w', 'FontSize', 11);

stats_str = sprintf('Active Run Duration: %.1fs     Max Airspeed: %.1f m/s (%.0f km/h)     Max Pitot: %.1f Pa     Mean Cp (during flow): %.3f', ...
    run_duration, max_airspeed, max_airspeed*3.6, max_pitot, mean_Cp);
annotation(fig_all, 'textbox', [0.1 0.01 0.8 0.03], ...
    'String', stats_str, ...
    'Color', 'w', ...
    'BackgroundColor', [0.2 0.2 0.2], ...
    'EdgeColor', [0.4 0.4 0.4], ...
    'FontSize', 9, ...
    'HorizontalAlignment', 'center', ...
    'FitBoxToText', false);

linkaxes([ax1 ax2 ax3 ax4], 'x');
pan(fig_all, 'on');

%% Individual full-size figures — one per channel
fig_pitot = figure('Position', [80, 80, 1400, 700], 'Color', bg_color);
ax_p = axes(fig_pitot);
draw_pitot(ax_p, t_plot, pitot_raw, pitot_f, pitot_color, raw_color, pitot_ylim, style_ax);
xlabel(ax_p, 'Time (s)', 'Color', 'w', 'FontSize', 11);
title(ax_p, 'Pitot Pressure', 'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
pan(fig_pitot, 'on');

fig_tap = figure('Position', [110, 110, 1400, 700], 'Color', bg_color);
ax_t = axes(fig_tap);
draw_tap(ax_t, t_plot, tap_raw, tap_f, tap_color, raw_color, tap_ylim, style_ax);
xlabel(ax_t, 'Time (s)', 'Color', 'w', 'FontSize', 11);
title(ax_t, 'Tap Pressure', 'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
pan(fig_tap, 'on');

fig_airspeed = figure('Position', [140, 140, 1400, 700], 'Color', bg_color);
ax_a = axes(fig_airspeed);
draw_airspeed(ax_a, t_plot, airspeed_raw, airspeed_f, airspeed_color, raw_color, airspeed_ylim, style_ax);
xlabel(ax_a, 'Time (s)', 'Color', 'w', 'FontSize', 11);
title(ax_a, 'Airspeed', 'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
pan(fig_airspeed, 'on');

fig_cp = figure('Position', [170, 170, 1400, 700], 'Color', bg_color);
ax_c = axes(fig_cp);
draw_cp(ax_c, t_plot, Cp_clean, Cp_f, cp_color, raw_color, Cp_ylim, style_ax);
xlabel(ax_c, 'Time (s)', 'Color', 'w', 'FontSize', 11);
title(ax_c, 'Pressure Coefficient (Cp)', 'Color', 'w', 'FontSize', 13, 'FontWeight', 'bold');
pan(fig_cp, 'on');

%% ===================== Local Functions =====================

function lims = auto_ylim(vals, symmetric, pad_frac, default_lims)
%AUTO_YLIM  Data-driven y-axis limits with padding, so peaks/troughs aren't clipped.
%   vals         - all raw/filtered samples relevant to this axis (NaNs ignored)
%   symmetric    - true to center the range on zero (good for signed signals)
%   pad_frac     - fraction of the data range added as headroom top/bottom
%   default_lims - fallback [lo hi] used only if vals has no finite data
    vals = vals(isfinite(vals));
    if isempty(vals)
        lims = default_lims;
        return
    end
    lo = min(vals);
    hi = max(vals);
    if symmetric
        m   = max(abs(lo), abs(hi));
        pad = max(m * pad_frac, 1e-6);
        lims = [-(m + pad), (m + pad)];
    else
        rng = hi - lo;
        pad = rng * pad_frac;
        if pad == 0
            pad = max(abs(hi), 1) * pad_frac;
        end
        lims = [lo - pad, hi + pad];
    end
end

function draw_pitot(ax, t_plot, pitot_raw, pitot_f, pitot_color, raw_color, ylims, style_ax)
    axes(ax); %#ok<LAXES>
    fill([t_plot; flipud(t_plot)], [pitot_f+5; flipud(pitot_f-5)], ...
        pitot_color, 'FaceAlpha', 0.1, 'EdgeColor', 'none'); hold(ax, 'on');
    plot(t_plot, pitot_raw, 'Color', [raw_color 0.15], 'LineWidth', 0.5);
    plot(t_plot, pitot_f, 'Color', pitot_color, 'LineWidth', 2);
    ylabel(ax, 'Pitot (Pa)', 'Color', 'w', 'FontSize', 11);
    ylim(ax, ylims);
    legend(ax, {'Confidence Band','Raw','Filtered'}, ...
        'TextColor','w','Color',[0.2 0.2 0.2],'Location','northeast','FontSize',9);
    grid(ax, 'on'); xlim(ax, [min(t_plot) max(t_plot)]);
    style_ax(ax);
end

function draw_tap(ax, t_plot, tap_raw, tap_f, tap_color, raw_color, ylims, style_ax)
    axes(ax); %#ok<LAXES>
    plot(t_plot, tap_raw, 'Color', [raw_color 0.15], 'LineWidth', 0.5); hold(ax, 'on');
    plot(t_plot, tap_f, 'Color', tap_color, 'LineWidth', 2);
    yline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
    ylabel(ax, 'Tap (Pa)', 'Color', 'w', 'FontSize', 11);
    ylim(ax, ylims);
    legend(ax, {'Raw','Filtered'}, ...
        'TextColor','w','Color',[0.2 0.2 0.2],'Location','northeast','FontSize',9);
    grid(ax, 'on'); xlim(ax, [min(t_plot) max(t_plot)]);
    style_ax(ax);
end

function draw_airspeed(ax, t_plot, airspeed_raw, airspeed_f, airspeed_color, raw_color, ylims, style_ax)
    axes(ax); %#ok<LAXES>
    plot(t_plot, airspeed_raw, 'Color', [raw_color 0.15], 'LineWidth', 0.5); hold(ax, 'on');
    plot(t_plot, airspeed_f, 'Color', airspeed_color, 'LineWidth', 2);
    ylabel(ax, 'Airspeed (m/s)', 'Color', 'w', 'FontSize', 11);
    ylim(ax, ylims);
    legend(ax, {'Raw','Filtered'}, ...
        'TextColor','w','Color',[0.2 0.2 0.2],'Location','northeast','FontSize',9);
    grid(ax, 'on'); xlim(ax, [min(t_plot) max(t_plot)]);
    style_ax(ax);
end

function draw_cp(ax, t_plot, Cp_clean, Cp_f, cp_color, raw_color, ylims, style_ax)
    axes(ax); %#ok<LAXES>
    plot(t_plot, Cp_clean, 'Color', [raw_color 0.15], 'LineWidth', 0.5); hold(ax, 'on');
    plot(t_plot, Cp_f, 'Color', cp_color, 'LineWidth', 2);
    yline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    ylabel(ax, 'Cp', 'Color', 'w', 'FontSize', 11);
    ylim(ax, ylims);
    legend(ax, {'Raw','Filtered'}, ...
        'TextColor','w','Color',[0.2 0.2 0.2],'Location','northeast','FontSize',9);
    grid(ax, 'on'); xlim(ax, [min(t_plot) max(t_plot)]);
    style_ax(ax);
end
