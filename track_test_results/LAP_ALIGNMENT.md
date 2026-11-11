# Lap Alignment: `laptimes.csv` → ESP32 data

Goal: find where each lap in `laptimes.csv` falls in the ESP32 pressure logs.

**Output:** `esp32_lap_index.csv` (one row per lap) and `esp32_lap_alignment.png` (airspeed trace with the lap boundaries drawn on).
**Reproduce:** `cd track_test_results && python3 align_laps.py`

The script uses:
- `laptimes.csv`
- `esp32_data/1107_1745/run000.csv` (Block 1) and `esp32_data/1108_1356/run006.csv` (Block 2)
- two times from `pitot_log_notes.md` (Block 1 power on and run start)

The autoX car logs are used once as an independent check (see below).

---

## The problem

`laptimes.csv` times are seconds from an unknown zero (timed from video, 1/30 s resolution). ESP32 `time_ms` is milliseconds since the ESP was powered on. For each block we need one number:

```
esp_time_s = lap_time_s + offset
```

| Setting in `laptimes.csv` | ESP32 file | Block in notes |
|---|---|---|
| CAD Ride Height | `1107_1745/run000.csv` | Block 1 |
| Squat Down | `1108_1356/run006.csv` | Block 2 |

## Step 1: Block 1 offset, taken from the notes

1. **ESP time counts from power on.** This is confirmed: power on 17:22:53, log start 17:29:45, so the log starts 412 s after power on. The file's first sample is `time_ms = 412114`. ✔
2. **Lap time 0 is the "run start".** Lap 1 is marked "Outlap 1 (Stationary)" with no start time, so the clock starts when the car pulls away. The notes record run start as **17:30:08**.
3. Offset = 17:30:08 − 17:22:53 = **435 s** (±1 s, since the notes are to the second).

Why we can't fit this from the data alone: every Block 1 lap is about 37 s and they all look alike. Shift every lap boundary by a few seconds and the laps still match each other just as well. (The lap-to-lap similarity score is flat from 431 to 440 s.) The data can confirm a start/finish position, but it can't find one. An anchor from the notes is needed.

## Step 2: Block 2 offset, found by matching lap shape

The Session 2 notes give whole minutes only (13:46 → 13:56), and power on wasn't written down. So instead:

1. Using the Block 1 offset, cut out each Block 1 hot lap's airspeed (5-sample median filter, then Savitzky-Golay order 3 / 31 samples). Stretch each lap to the same length (0 to 1 of a lap) and average them. This gives a **template lap that starts at the finish line**.
2. For each candidate Block 2 offset (0.01 s steps), cut out the Block 2 hot laps the same way. Correlate each one with the template and average the correlations.
3. Keep the best offset. **Result: 146.57 s, mean r = 0.925.** The peak is sharp: offsets a few seconds either side score below 0.45.

This works for Block 2 because the template has a fixed start/finish position. Step 1 didn't have one.

## Checks

| Check                                                                      | Result                                                                                                                                                                                                |
| -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Block 1 hot laps vs template                                               | r = 0.96–0.99                                                                                                                                                                                         |
| Block 2 hot laps vs template                                               | r = 0.87–0.97                                                                                                                                                                                         |
| Block 2 laps 4 and 8 ("did not complete figure 8")                         | r = 0.24–0.34. They should match poorly, and they do. ✔                                                                                                                                               |
| Block 2 laps 6 and 7 (power cut)                                           | r = 0.77–0.88 (right shape, lower speed) ✔                                                                                                                                                            |
| Block 1: airspeed first rises above 2 m/s                                  | ESP 436.1 s, about 1 s after the 435 s anchor (the car needs time to reach pitot-readable speed) ✔                                                                                                    |
| Block 2: lap 1 start vs when airspeed rises                                | Lap 1 starts at ESP 168.9 s; airspeed rises at about 174 s. Fits a standing start ✔                                                                                                                   |
| Block 2 power on, estimated                                                | 13:46 run start − 169 s ≈ 13:43; 13:56 stop − 770 s (end of file) ≈ 13:43. The two agree ✔                                                                                                            |
| **Independent check with the car logs (one time only, not in the script)** | Wheel speed from `autoX_*.csv` correlates with ESP airspeed at r = 0.98. That alignment gives Block 1 lap 0 at 435.43 s and Block 2 at 146.98 s. Both are **0.4 s later** than the notes-only values. |

**Accuracy:** about ±0.5 s per lap boundary, set by how precise the notes are. That's less than 1.5% of a 37 s lap, which doesn't matter for per-lap averages. To match the car logs exactly, set `REF_OFFSET = 435.43` in `align_laps.py`.

## Things to know

- **Block 1 has about 80 s of extra driving.** Between lap 10's finish (ESP 794 s) and run stop (879 s) there are about two more laps that aren't in `laptimes.csv`.
- **Block 2 has no clock times.** Power on wasn't logged, so `wall_start`/`wall_end` are left blank. Block 2 is aligned by lap shape only.
- **Warm-up blocks:** `1107_1554` and `1107_1708` have no lap times and aren't aligned.

## Using the index

The columns in `esp32_lap_index.csv`:
- `esp_start_ms`, `esp_end_ms`: filter the ESP CSV on `time_ms` between these.
- `row_start`, `row_end`: 1-based line numbers in the ESP CSV, counting the header as line 1.
- `wall_start`, `wall_end`: clock times, Block 1 only.
- `r_vs_template`: how well that lap matches the average lap.

MATLAB example:

```matlab
idx = readtable('esp32_lap_index.csv');
d   = readtable('../esp32_data/1107_1745/run000.csv');
lap = idx(strcmp(idx.setting,'CAD Ride Height') & idx.lap==5, :);
seg = d(d.time_ms >= lap.esp_start_ms & d.time_ms < lap.esp_end_ms, :);
```
