# Run Comparison: Nov 7–8 Alameda Testing

All five ESP32 runs in `esp32_data/` analysed against `pitot_log_notes.md`. Every run uses the same filtering as `PressureDataPlots.m` (5-sample median filter, then Savitzky-Golay order 3 with a 31-sample window). On top of that: a regression of tap pressure against pitot q, Cp in speed bands, and a check of the timing lag between the two sensors. Reproduce everything with `compare_runs.m`.

---

## Setup context (from `Ride Height, Weight Distribution and Alignment - Sheet1.csv`)

| Config | Front RH (in) | Rear RH (in) | Rear weight (%) | Camber FL / RL / FR / RR |
|---|---|---|---|---|
| CAD RH run (Block 1) | 4.00 | 5.70 | 50.9 | −1.4 / −1.0 / −1.5 / +0.3 |
| Squat Down (Block 2) | 4.00 | 5.25 | 50.9 | −0.5 / +0.3 / −1.2 / −0.9 |

Squat Down lowers only the **rear**, by 0.45 in, with the front unchanged, so it also **reduces rake**. Camber changed too. Both changes should be considered when explaining the Block 1 vs Block 2 difference.

---

## Main comparison: Block 1 (CAD ride height) vs Block 2 (Squat Down)

| Measure (filtered, q > 20 Pa) | Block 1 `1107_1745` | Block 2 `1108_1356` | Change |
|---|---|---|---|
| Slope of tap vs q (Cp from the fit) | **−1.98** | **−2.10** | ~6% more suction |
| Fit intercept | +2.6 Pa | +3.6 Pa | both ≈ 0, which is good |
| Fit quality r | 0.91 | 0.93 | |
| Median Cp, 10–13 m/s | −1.93 | −1.99 | |
| Median Cp, 13–16 m/s | −1.98 | −2.13 | |
| Median Cp, 16–20 m/s | −1.91 | −2.08 | |

- **Lowering the ride height made the tap pressure more negative by about 5–8%**, and this holds in every speed band. That fits the usual underbody result: lower ride height gives faster flow underneath and more suction. Both runs have hundreds to thousands of samples per band, so it's unlikely to be noise. But each configuration has only one run, so the ride-height effect can't yet be separated from day-to-day variation (Nov 7 vs Nov 8).
- **Cp stays nearly constant from 10 to 20 m/s.** The tap pressure scales with q, so Cp doesn't depend much on speed. That's what makes the comparison with the CFD at 20 m/s valid even though 20 m/s was rarely reached. Peak speed was about 19.7 m/s (~44 mph), and only about 30 samples per run are above 18 m/s.

## Warm-up runs vs the real runs

| Run | Fit slope | Intercept |
|---|---|---|
| 0a `1554` | −1.55 | −24 Pa |
| 0b run00 | −1.52 | −22 Pa |
| 0b run01 | −1.69 | −14 Pa |
| Block 1 | −1.98 | +3 Pa |

- **In the warm-up runs, the tap reads a steady 14–24 Pa more negative than q explains, and that offset shrinks run by run.** By Block 1 it's gone. At rest the readings are fine: both sensors read within ±1 Pa when stopped, so this is not a zero-calibration error.
- Likely causes are the sensors, tubing or car warming up (tyre pressure and ride height change as the car heats up), or a different driving pattern. Either way, **leave the warm-ups out of the Cp-vs-CFD comparison.** They can be cited as evidence that warm-up matters.

## Data quality

- **Use the regression slope, or q-weighted Cp above about 50 Pa (~9 m/s), as the headline Cp.** Don't use a plain mean of Cp. Dividing tap by pitot sample by sample throws spikes: raw Cp ranges from −41 to +24. Below about 8 m/s the median Cp drifts to between −2.4 and −3.3 because q is tiny. The 5 Pa `pitot_floor` in `PressureDataPlots.m` is too low, which pulls its "Mean Cp" more negative.
- **The tap reading leads the pitot by about 100 ms** in every run. That's probably because the two tube runs have different lengths. Shifting the tap channel by one sample raises the correlation from about 0.6 to above 0.9. This matters for the time plots and less for averaged Cp.
- **Logging rate is a steady 10 Hz with no NaNs.** The I²C pull-ups are working. Run006 has 22 small gaps of 300–363 ms, which don't matter.
- **There are almost no steady-speed stretches.** Less than 3 s per run held a constant speed above 12 m/s, so the "average over a steady segment" step in the project plan can't really be done. Regression over the whole run is the better approach for this kind of driving.

## Checks on the test log

- **The file timestamps confirm most of the written times.** Block 1: power on at 17:22:53 plus the file's 412.1 s start offset gives a log start of 17:29:45, which matches exactly. Block 0b run01 puts power-on at about 16:35:22.
- **Block 0a doesn't line up.** The file says logging started 374 s after boot, but the notes give only 343 s. That would put power-on at about 15:27:06, which may explain the unclear "(1:1 earlier)" note.
- **Run006 doesn't match its log entry.** It starts 7 s after boot but is 12.7 min long, against the ~10 min (13:46 to 13:56) written down. Logging probably started around 13:43. It's also named run006, so check where runs 1–5 went in Session 2.
- **No run records which tap was connected.** For the Cp-vs-x/c deliverable, add a tap ID column to the log. If all of these runs used the same tap, note that.
