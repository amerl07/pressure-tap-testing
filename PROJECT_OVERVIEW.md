# **Undertray Pressure Tap Validation Project**

## **Project Overview**

The purpose of this project is to perform a quick on-car aerodynamic validation of the undertray by measuring pressure coefficient ($C_p$) at multiple chordwise locations and comparing those values to CFD results.

This is not intended to be a permanent instrumentation system. The goal is to create a simple, functional setup that can collect useful validation data for one nominal aero configuration.

The final deliverable is a plot of measured $C_p$ vs chordwise location ($x/c$) overlaid with CFD $C_p$ at the same locations. Optional additional outputs include velocity vs time and pressure vs time, but these are secondary.

---

## **Current Status (Nov 10)**

* **The logger works on the car.** Both sensors log at a steady 10 Hz to the ESP32's internal flash, with no dropouts in the main runs.
* **First track test done** (Alameda, Nov 7–8). There were two configurations, each with one tap: CAD ride height (Block 1) and Squat Down (Block 2, rear lowered 0.45 in).
* **Result:** the tap reads $C_p \approx -1.9$ to $-2.0$, and the value holds steady from 9 to 17 m/s. Squat Down gave about 6 % more suction (q-weighted $C_p$: $-1.92 \rightarrow -2.04$).
* **Still not done:** $C_p$ vs $x/c$. Only one tap location has been run. The CFD comparison also needs to be done.

Details are in [Track Test Results](#track-test-results-nov-78-alameda) below, in `track_test_results/run_comparison.md`, and in the package for VD (`track_test_results/processed_results_package/`).

---

## **Measurement Concept**

The system uses two identical differential pressure sensors (4525DO-based).

Two sensors are available:

* One sensor will be used continuously as a pitot-static sensor to measure freestream dynamic pressure and velocity
* One sensor will be used to measure one surface pressure tap at a time

To obtain a full $C_p$ distribution:

* Approximately 5 chordwise tap locations will be defined
* Each tap will be tested in separate runs
* Data from all runs will be combined to form $C_p$ vs $x/c$

This is strictly a chordwise study, not spanwise.

---

## **Hardware**

Sensors:

* 2x Pixhawk digital differential airspeed sensor kits (4525DO, 1 psi range)

Controller:

* ESP32 Feather V2. Each sensor gets its own I2C bus, because both have the same address (0x28). See `README.md` for wiring.

Other components:

* Pitot-static tube (included with kit)
* Pressure tap tubing
* Logging: the ESP32's internal flash, written as CSV. Files are pulled off with `esp32_dump.py`. There's no SD card.
* Power: a 3.7 V LiPo for on-car runs
* Electronics enclosure (planned in endplate region)

---

## **Measurement Architecture**

### **Pitot Sensor**

One sensor is dedicated to the pitot-static tube.

It measures dynamic pressure:

$$q_\infty = P_t - P_\infty$$

Velocity is computed as:

$$V = \sqrt{\frac{2\,q_\infty}{\rho}}, \qquad \rho = 1.225\ \text{kg/m}^3$$

This sensor provides the denominator for the $C_p$ calculation.

### **Surface Pressure Sensor**

The second sensor measures pressure at one undertray tap location.

It measures:

$$\Delta P_\text{tap} = P_\text{surface} - P_\infty$$

This is done by connecting:

* One port to the pressure tap
* One port to a static reference

A negative reading ($\Delta P_\text{tap} < 0$) means suction: the tap pressure is below static.

### **$C_p$ Calculation**

$C_p$ is calculated as:

$$C_p = \frac{P_\text{surface} - P_\infty}{q_\infty} = \frac{\Delta P_\text{tap}}{q_\infty}$$

Dynamic pressure q comes directly from the pitot sensor, so velocity does not need to be explicitly used unless desired for reporting.

The logger also computes a per-sample $C_p$ on the board, but it's very noisy at low speed. The $C_p$ values we actually report are worked out in post-processing (see [How the Numbers Are Derived](#how-the-numbers-are-derived)).

---

## **Static Reference Strategy**

The static port of the pitot-static tube is used as the reference pressure for the surface pressure sensor. It is connected to both sensors. This keeps all measurements referenced to the same static pressure source and simplifies the setup.

---

## **Pressure Tap Plan**

* Approximately 5 pressure taps will be placed along the chord of the undertray
* All taps will be on the bottom surface
* Only one tap will be connected at a time
* Each tap corresponds to a specific $x/c$ location from CFD

Tap locations must be selected from CFD and documented before testing.

Final plots should use nondimensional chordwise position ($x/c$).

---

## **Test Conditions**

Original plan:

* Straight-line runs only
* Single aero configuration
* Static ride height (no sweep)
* Target speed up to ~45 mph
* CFD reference condition is 20 m/s

What actually happened (Nov 7–8):

* **The car drove figure-8 laps instead of straight lines.** About 37 s per lap, 8 hot laps per configuration.
* **Two configurations** (see below), not one.
* **Peak airspeed was about 17–20 m/s; it averaged about 11 m/s.** There are almost no steady-speed stretches (less than 3 s above 12 m/s in any run), so the "average over a steady segment" step is replaced by the methods below.
* **The CFD condition of 20 m/s was barely reached.** $C_p$ is flat with speed from 9 to 17 m/s, so comparing to CFD at 20 m/s is still reasonable.

---

## **Data Logging Requirements**

The system should log the following:

* Timestamp ✅ (`time_ms`, ms since power-on)
* Pitot differential pressure ✅ (`pitot_pa`, $q_\infty$)
* Surface pressure differential ✅ (`tap_pa`, $\Delta P_\text{tap}$)
* Calculated velocity ✅ (`airspeed_ms`, $V$)
* Calculated $C_p$ ✅ (`Cp`, the raw per-sample ratio)
* Tap location identifier ❌ **Not logged yet.** Add a tap ID to the file, or at minimum write it in the test log for every run, when doing chord-wise study in the future.

Important:
 Both raw pressure data and processed values must be saved.

Also record in the test log for every run: power-on time to the second (logger time counts from power-on, so this ties the data to clock time), run start and stop, and the setup/configuration.

---

## **Test Procedure** (For Chordwise Study)

1. Select one tap location **and write its ID / $x/c$ in the log**
2. Connect tubing from tap to surface pressure sensor
3. Mount pitot tube facing freestream
4. Install enclosure and electronics
5. Power on, **writing down the time to the second**
6. Perform runs (warm the car up first; see below)
7. Log all data onboard
8. Repeat run if needed
9. Move to next tap location
10. Repeat until all taps are tested

**Warm-up matters.** In the three warm-up runs on Nov 7, the tap read a steady 14–24 Pa more suction than $q_\infty$ explained. This offset shrank with each run and was gone by Block 1. Don't use data from before the car, tubing and sensors have warmed up.

---

## **Data Processing**

Original plan: average pitot and tap pressure over a steady-speed segment, then take the ratio. Track driving had no steady segments, so the processing now works as described below.

### Pipeline

| Step                                                      | Script                                      | Output                                              |
| --------------------------------------------------------- | ------------------------------------------- | --------------------------------------------------- |
| 1. Pull the logs off the ESP32                            | `esp32_dump.py`                             | `esp32_data/<MMDD_HHMM>/runNNN.csv`                 |
| 2. Time-series plots with lap dividers                    | `PressureDataPlots.m`                       | Figures                                             |
| 3. Place laps on the logger timeline                      | `track_test_results/align_laps.py`          | `esp32_lap_index.csv`, `esp32_lap_alignment.png`    |
| 4. Compare runs: fits, $C_p$ by speed band, per-lap $C_p$ | `track_test_results/compare_runs.m`         | `compare_runs_summary.csv`, `compare_runs_laps.csv` |
| 5. Build the results package                              | `track_test_results/make_results_package.m` | `processed_results_package/` (+ zip)                |

### How the Numbers Are Derived

Notation: sample $i$ has pitot dynamic pressure $q_i$ and tap pressure $p_i = \Delta P_{\text{tap},i}$, logged at 10 Hz ($\Delta t = 0.1$ s).

**1. Filtering (in MATLAB plotting).** Each pressure channel goes through a 5-sample median filter, which removes single-sample spikes. Then a Savitzky-Golay filter smooths it (order 3, 31-sample window $\approx 3$ s), which keeps the peaks in shape.

**2. Lag correction.** The script tries shifting the tap channel against the pitot channel by $k$ samples, for every $k$ from $-30$ to $+30$, and keeps the shift with the strongest correlation:

$$k^* = \arg\max_{|k| \le 30} \left|\operatorname{corr}\left(q_{i+k},\ p_i\right)\right|$$

This gives $k^* = +1$ (100 ms, tap ahead) in every main run. The tap channel is shifted by that amount before anything else is computed.

**3. Tap vs $q$ regression ("fit slope" $C_p$).** Take every sample with $q_i > 20$ Pa and plot $p_i$ (y) against $q_i$ (x). If $C_p$ were perfectly constant, then $p_i = C_p\,q_i$ and the points would sit on a straight line through the origin with slope $C_p$. We fit by least squares:

$$p_i = C_p\,q_i + b$$

* **Slope $= C_p$.** For example, $C_p = -1.98$ means that for every 1 Pa of dynamic pressure, the tap reads 1.98 Pa below static.
* **Intercept $b$** is an offset that $q$ doesn't explain. It should be close to 0. The main runs give $b = +2.6$ and $+3.6$ Pa (good). The warm-up runs give $b = -14$ to $-24$ Pa, which is the warm-up offset.
* **Correlation $r$** says how tightly the points sit on the line, from 0 (no relationship) to 1 (a perfect line):

$$r = \frac{\sum_i (q_i - \bar q)(p_i - \bar p)}{\sqrt{\sum_i (q_i - \bar q)^2 \, \sum_i (p_i - \bar p)^2}}$$

  The value used is $|r|$, since the slope is negative. The main runs give **$|r| = 0.91$ and $0.93$**, so $r^2 = 0.83$–$0.87$: $q$ explains about 85 % of the variation in tap pressure. The remaining scatter comes from cornering and yaw on the figure 8, wind, and sensor noise.

**4. q-weighted $C_p$.** Over samples with $q_i > 50$ Pa ($V \approx 9$ m/s):

$$C_{p,\text{qw}} = \frac{\sum_i p_i}{\sum_i q_i} = \frac{\sum_i q_i\,C_{p,i}}{\sum_i q_i}, \qquad C_{p,i} = \frac{p_i}{q_i}$$

  This is the per-sample $C_{p,i}$ averaged with each sample weighted by its $q_i$. Fast samples count most, and slow samples (where dividing by a small $q_i$ blows up the noise) are dropped. It assumes $b \approx 0$, which holds for the main runs. **This is the main number for per-lap results**: it varies about $\pm 0.06$ between laps, while the fit slope varies about $\pm 0.15$. On a single 37 s lap, the slope and intercept trade off against each other.

**5. $C_p$ by speed band.** Per-sample $C_{p,i} = p_i / q_i$ (only where $q_i > 5$ Pa), grouped into 2 m/s airspeed bands. The median and the 25th–75th percentiles are reported for any band with at least 10 samples. This is a check that $C_p$ doesn't change with speed. Bands below about 9 m/s are unreliable because $q$ is tiny.

**6. Lap alignment.** Lap times (from video, $\tfrac{1}{30}$ s resolution) are measured from an unknown zero, while logger time counts from power-on. Each block needs one offset $c$:

$$t_\text{logger} = t_\text{lap} + c$$

* **Block 1:** the offset is the run start minus power-on from the test log: $c_1 = \text{17:30:08} - \text{17:22:53} = 435$ s.
* **Block 2:** only whole-minute times were written down. So each hot lap's airspeed shape was matched against the Block 1 average lap. The best match is $c_2 = 146.57$ s, with $r = 0.93$ and one clear peak.
* **Check:** the car's wheel-speed log agrees with both offsets to within 0.4 s.
* **Accuracy** is about $\pm 0.5$ s per lap boundary. Full method in `track_test_results/LAP_ALIGNMENT.md`.

**7. Hot-lap statistics.** Only laps marked "Hotlap" are used. Out-laps, incomplete figure 8s and power-cut laps are excluded. That leaves $n = 8$ hot laps per configuration. Each configuration is reported as the mean $\pm$ standard deviation across those laps. The difference between configurations is compared against the standard error of the difference:

$$\text{SE} = \sqrt{\frac{s_1^2}{n_1} + \frac{s_2^2}{n_2}} = \sqrt{\frac{0.063^2}{8} + \frac{0.067^2}{8}} \approx 0.032, \qquad \frac{|\Delta C_{p,\text{qw}}|}{\text{SE}} = \frac{0.115}{0.032} \approx 3.5$$

Final output (still the goal):

* Plot $C_p$ vs $x/c$
* Overlay CFD $C_p$

Optional:

* Velocity vs time ✅
* Pressure vs time ✅

---

## **Track Test Results (Nov 7–8, Alameda)**

| Config | Front RH | Rear RH | Rear weight | Camber FL / RL / FR / RR |
|---|---|---|---|---|
| Block 1: CAD RH | 4.00 in | 5.70 in | 50.9 % | $-1.4$ / $-1.0$ / $-1.5$ / $+0.3$ |
| Block 2: Squat Down | 4.00 in | 5.25 in | 50.9 % | $-0.5$ / $+0.3$ / $-1.2$ / $-0.9$ |

| | Block 1 CAD RH | Block 2 Squat Down | Change |
|---|---|---|---|
| **$C_{p,\text{qw}}$, hot-lap mean $\pm$ std ($n = 8$)** | **$-1.92 \pm 0.06$** | **$-2.04 \pm 0.07$** | **$-0.115$ ($-6$ %)** |
| Fit slope $C_p$, hot-lap mean $\pm$ std | $-1.98 \pm 0.15$ | $-2.08 \pm 0.16$ | $-0.10$ |
| Whole-run fit: $C_p$ / $b$ / $\lvert r \rvert$ | $-1.98$ / $+2.6$ Pa / $0.91$ | $-2.10$ / $+3.6$ Pa / $0.93$ | |
| Mean airspeed (hot laps) | 11.6 m/s | 10.9 m/s | |

* **Squat Down gives more suction.** The shift is about $3.5\times$ the standard error, so it isn't lap-to-lap noise.
* **But it can't be put down to ride height alone.** Rake and camber also changed, and the runs were on different days, with one run each.
* **The absolute $C_p$ may be inflated** if the pitot is reading a low $q_\infty$. See Static Reference Strategy.

Data files: `esp32_data/1107_1745/run000.csv` (Block 1), `esp32_data/1108_1356/run006.csv` (Block 2). The warm-up files `1107_1554` and `1107_1708` are excluded from the results. The test log is `track_test_results/pitot_log_notes.md`.

---

## **Known Limitations**

* Only one tap measured per run
* Possible vibration noise in data
* Static reference may not be perfectly freestream. $C_p \approx -2$ suggests the pitot may read $q_\infty$ low.
* Temporary mounting and packaging
* Limited testing conditions
* Figure-8 driving instead of straight lines: no steady-speed segments, and yaw/cornering add scatter
* There's a warm-up offset (14–24 Pa) until the car has warmed up
* The tap ID wasn't logged for the Nov 7–8 runs
* There's only one run per configuration, and the two were on different days

---

## **Tasks to be Completed**

Electronics:

* [x] Determine wiring and communication for 4525DO sensors with ESP32 (two I2C buses)
* [x] Ensure both sensors can be read simultaneously
* [x] Implement sensor reading code

Logging:

* [x] Integrate onboard logging (internal flash; `esp32_dump.py` to retrieve)
* [x] Define data format (CSV)
* [ ] Add tap ID to the log file

Tap Design:

* [ ] Select 5 chordwise locations from CFD (record the $x/c$ of the tap used on Nov 7–8)
* [ ] Choose tap hole size (~0.5–1.0 mm recommended)
* [ ] Design tubing connections. Match the tube lengths to remove the 100 ms lag.

Testing:

* [x] Bench test sensors
* [x] Verify sign conventions (tap reads negative = suction, as expected)
* [x] Perform on-car runs (Nov 7–8, one tap, two configurations)
* [ ] Check the pitot airspeed against GPS/wheel speed on a straight
* [ ] Run the remaining tap locations, warming the car up first
* [ ] Repeat a configuration on the same day, to separate the setup change from day-to-day variation

Post-Processing:

* [x] Extract data
* [x] Compute $C_p$ (fit slope, q-weighted, by speed band, per lap)
* [ ] Generate $C_p$ vs $x/c$ plot
* [ ] Compare with CFD
