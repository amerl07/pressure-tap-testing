# Undertray Pressure Tap Validation

An ESP32 logs a pitot-static sensor and one undertray pressure tap on the car. From the two we compute the pressure coefficient $C_p$, and compare it to CFD.

**Start here:**

| **Task**                                           | Go to                                                                                                                                                                                        |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Understand the project, method and current results | [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md)                                                                                                                                                 |
| Build (perfboard), wire, flash, run the logger and pull data off it | [`HARDWARE_SETUP.md`](HARDWARE_SETUP.md)                                                                                                                                                     |
| See the Nov 7–8 Alameda track test results         | [`track_test_results/run_comparison.md`](track_test_results/run_comparison.md) and [`track_test_results/processed_results_package/`](track_test_results/processed_results_package/README.md) |
| Know how laps were matched to the logger data      | [`track_test_results/LAP_ALIGNMENT.md`](track_test_results/LAP_ALIGNMENT.md)                                                                                                                 |

---

## Repo layout

```
├── README.md                     ← this index
├── PROJECT_OVERVIEW.md       ← project plan, method, math, results, task list
├── HARDWARE_SETUP.md             ← sensor facts, perfboard wiring, tubing, power, flashing, logging, data retrieval, hardware TODO
├── perfboard wiring diagram.png
│
├── Logging/Logging.ino           ← main firmware: logs both sensors to flash (BOOT button = start/stop)
├── DumpingData/DumpingData.ino   ← firmware that dumps saved runs over serial
├── i2c_scan/i2c_scan.ino         ← debug firmware: checks both sensors respond
├── esp32_dump.py                 ← PC side: saves dumped runs as CSVs
├── check_logs.py                 ← PC side: lists / deletes runs on the board
│
├── PressureDataPlots.m           ← time-series plots (pitot, tap, airspeed, Cp) with lap dividers
├── esp32_data/                   ← raw logger files, one folder per pull: <MMDD_HHMM>/runNNN.csv
│
└── track_test_results/           ← Nov 7–8 Alameda test
    ├── pitot_log_notes.md        ← test log: which run is which, power-on/start/stop times
    ├── laptimes.csv              ← lap times from video
    ├── Ride Height, Weight Distribution and Alignment - Sheet1.csv
    ├── track_layout.png
    ├── align_laps.py             ← places laps on the logger timeline → esp32_lap_index.csv, esp32_lap_alignment.png
    ├── compare_runs.m            ← Cp fits, speed bands, per-lap Cp → compare_runs_summary.csv, compare_runs_laps.csv
    ├── make_results_package.m    ← builds processed_results_package/ (plots + data for VD)
    ├── run_comparison.md         ← write-up of the run comparison
    ├── LAP_ALIGNMENT.md          ← lap alignment method and checks
    └── processed_results_package/
```

---

## Workflow

**1. Collect data:** see [`HARDWARE_SETUP.md`](HARDWARE_SETUP.md).
- Flash `Logging.ino` and power on. **Write down the power-on time to the second**, the tap ID / $x/c$ and the setup.
- Press BOOT to start and stop each run.

**2. Retrieve data:**
- Flash `DumpingData.ino`, close the Serial Monitor, then run `python3 esp32_dump.py`.
- Move the `~/Desktop/esp32_data/<MMDD_HHMM>/` folder it creates into this repo's `esp32_data/`.
- Re-flash `Logging.ino` before the next run.

**3. Log the test:** add the runs to a test log like `track_test_results/pitot_log_notes.md`. Note which file is which run, the times, and which runs are warm-ups.

**4. Analyse (in this order):**

| Step | Command | Needs | Produces |
|---|---|---|---|
| a. Lap alignment | `cd track_test_results && python3 align_laps.py` | `laptimes.csv`, raw runs, power-on/run-start times (set in the script) | `esp32_lap_index.csv`, `esp32_lap_alignment.png` |
| b. Time-series plots | Run `PressureDataPlots.m` in MATLAB from the repo root | `esp32_lap_index.csv` | Figures for each run listed in the lap index |
| c. Run comparison | Run `track_test_results/compare_runs.m` | Run list at the top of the script, `esp32_lap_index.csv` | Figures, `compare_runs_summary.csv`, `compare_runs_laps.csv` |
| d. Results package | `run('track_test_results/make_results_package.m')` | Steps a–c set up | `processed_results_package/` (plots, processed CSVs, README) |

Requirements: MATLAB with the Signal Processing Toolbox (`medfilt1`, `sgolayfilt`) and the Image Processing Toolbox (`bwconncomp`); Python 3 with `numpy`, `pandas`, `scipy`, `matplotlib`; `pyserial` for `esp32_dump.py`.

**For a new test day:**
- Add the new runs to `BLOCKS` and the anchor times in `align_laps.py`.
- Add them to the `runs` list in `compare_runs.m`.
- Make a new results folder like `track_test_results/` for that day.

---

## Current status

- **The first track test is done** (Nov 7–8): one tap, CAD ride height vs Squat Down. Squat Down gave about 6 % more suction ($C_{p,\text{qw}}$: $-1.92 \rightarrow -2.04$).
- **Next:** run the remaining tap locations, log the tap ID, check the pitot against wheel speed, then plot $C_p$ vs $x/c$ against CFD.
- The full task list is in [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md#tasks-to-be-completed).
