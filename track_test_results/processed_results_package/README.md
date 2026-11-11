# Undertray Pressure Tap: Ride Height Comparison (Alameda, Nov 7–8)

For full project see: https://github.com/amerl07/pressure-tap-testing 
One undertray pressure tap and one pitot tube were logged by an ESP32 at 10 Hz on the autocross course. The two setups compared:

| Run | Date | Front RH | Rear RH | Rear weight | Camber FL / RL / FR / RR |
|---|---|---|---|---|---|
| **Block 1: CAD RH** | Nov 7 | 4.00 in | 5.70 in | 50.9 % | −1.4 / −1.0 / −1.5 / +0.3 |
| **Block 2: Squat Down** | Nov 8 | 4.00 in | 5.25 in | 50.9 % | −0.5 / +0.3 / −1.2 / −0.9 |

## Result Overview

**Lowering the rear by 0.45 in made the tap about 6 % more suction-heavy.** Cp went from about −1.92 to −2.04.

| Hot laps only (n = 8 each) | Block 1 CAD RH | Block 2 Squat Down | Change |
|---|---|---|---|
| q-weighted Cp, mean ± lap-to-lap std | **−1.92 ± 0.06** | **−2.04 ± 0.07** | −0.115 (−6.0 %) |
| Cp from fit slope, mean ± std | −1.98 ± 0.15 | −2.08 ± 0.16 | −0.10 |
| Mean airspeed | 11.6 m/s | 10.9 m/s | |
> q = dynamic pressure

- **The shift is bigger than the scatter between laps.** It is about 3.5 standard errors of the hot-lap means.
- **Cp is roughly constant from 9 to 17 m/s** in both setups (plot 3). The tap pressure scales with q, so the result should carry over to higher speeds.
- **The whole-run fits are clean.** tap = Cp·q + b gives Cp = −1.98 vs −2.10, the offsets b are only +2.6 / +3.6 Pa, and r = 0.91 / 0.93.

**What is Cp** 
- Cp = tap pressure (on the undertray) / pitot dynamic pressure q.
- `q-weighted Cp` means Σ tap / Σ q over samples with q > 50 Pa (≈ 9 m/s). 
	- Average of the per-sample Cp values, with each sample weighted by its q.
	- Faster, cleaner samples count more than noisy low-speed points

## Plots (`plots/`)

| File                                                                                            | Content                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `1_per_lap_cp.png`                                                                              | Cp (fit slope), q-weighted Cp and mean airspeed for every lap. Filled = hot lap; hollow / `*` = out-lap or irregular lap. Dashed line = hot-lap mean. **Start here.**                                                                                                                                                                                                                                                                                                                           |
| `2_tap_vs_q.png`                                                                                | Each dot is one 0.1 s sample (every 3rd sample shown, q > 20 Pa): pitot q on x, tap pressure on y. If Cp were constant, the points would sit on a straight line through the origin, so the fitted line's **slope is Cp** and its intercept `b` is an offset q can't explain (+3 Pa here, close to 0). Correlation r = 0.91 / 0.93, so q explains about 85 % of the variation in tap pressure. The rest is cornering, yaw and noise. The Squat Down line is steeper: more suction at the same q. |
| `3_cp_by_speed_band.png`                                                                        | Median Cp (with IQR bars) in 2 m/s airspeed bands. Below about 9 m/s q is too small                                                                                                                                                                                                                                                                                                                                                                                                             |
| `4_timeseries_block1_CAD_RH.png`, `5_timeseries_block2_squat_down.png`                          | Pitot, tap, airspeed and Cp against time, from the start of lap 1, with a divider at each lap (`L3`, `L4*`, …).                                                                                                                                                                                                                                                                                                                                                                                                          |
| `6_pitot_block1_vs_block2.png`, `7_tap_block1_vs_block2.png`, `8_airspeed_block1_vs_block2.png` | One channel per image: Block 1 on top, Block 2 below, on the same y-scale, with lap dividers. The x-axis is logger time, so the two runs start at different times.                                                                                                                                                                                                                                                                                                                              |
| `9_pitot_overlay.png`, `10_tap_overlay.png`, `11_airspeed_overlay.png` | Both runs overlaid on one axis (filtered signal only). The x-axis is time since each run's lap 1 start. Lap dividers are in each run's colour: Block 1 labels at the top, Squat Down at the bottom. The runs drift out of step lap by lap because lap times differ, so compare levels and peak heights rather than lining up individual peaks. |

## Data (`data/`)

| File                                                                 | Contents                                                                                                                                                                                                                                                                                                                                                                                                       |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hotlap_summary.csv`                                                 | The headline numbers above, one row per run.                                                                                                                                                                                                                                                                                                                                                                   |
| `per_lap_results.csv`                                                | One row per lap: lap note, `isHot`, Cp (fit slope), intercept (Pa), q-weighted Cp, mean airspeed.                                                                                                                                                                                                                                                                                                              |
| `run_summary.csv`                                                    | Whole-run fit (Cp slope, intercept, r), q-weighted Cp, max airspeed, and median Cp in each speed band.                                                                                                                                                                                                                                                                                                         |
| `timeseries_block_1_cad_rh.csv`, `timeseries_block_2_squat_down.csv` | **Processed time series at 10 Hz**. Columns: `time_s` (s since logger power-on), `lap` (0 = outside a timed lap), `lap_note`, `is_hotlap`, `q_pa`, `tap_pa`, `airspeed_ms` (from q), `cp` (tap/q, NaN when q ≤ 5 Pa). Filtered with a 5-sample median and a Savitzky-Golay filter (order 3, 31 samples). The tap channel is shifted 100 ms to line up with the pitot, because the tubes are different lengths. |
| `lap_index.csv`                                                      | Start and end time of every lap in logger time (`esp_start_ms`, `esp_end_ms`), plus the lap times as recorded.                                                                                                                                                                                                                                                                                                 |
| `car_setup.csv`                                                      | Ride height, weight distribution and alignment sheet.                                                                                                                                                                                                                                                                                                                                                          |
| `raw_esp32/`                                                         | Unprocessed logger files (`time_ms, pitot_pa, tap_pa, airspeed_ms, Cp`). Cp here is the logger's own raw per-sample ratio and is very noisy. Use the processed files instead.                                                                                                                                                                                                                                  |

Air density is taken as 1.225 kg/m³ throughout.
