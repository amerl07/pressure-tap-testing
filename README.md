# Pressure Tap Validation — Setup Guide

This guide walks through wiring, powering, flashing, running, and retrieving data from the ESP32-based pressure tap logger. It assumes you're starting from a bare ESP32 Feather V2, two 4525DO pressure sensor breakouts, and a 3.7V LiPo battery.

The system has two hardware versions:

- **Breadboard prototype** (Section 1) — the original bench setup. Kept here for reference and for anyone rebuilding from scratch.
- **Soldered perfboard build** (Section 2) — the current on-car version. Breadboard connections were unreliable under vibration, so the circuit was migrated to a soldered board. The electrical design is the same; only the physical build changed.

## What this system does

Two identical differential pressure sensors (4525DO) are read by an ESP32 Feather V2:

- **Sensor 1 (Pitot)** — measures freestream dynamic pressure, used to compute airspeed.
- **Sensor 2 (Tap)** — measures pressure at one surface tap location at a time.

The board computes `Cp = tap_pressure / pitot_pressure` in real time and logs everything to its own internal flash storage. Since only one tap sensor exists, you test one tap location per run and physically move the tubing between runs.

---

## Hardware needed

- ESP32 Feather V2 (Adafruit HUZZAH32 Feather V2, 8 MB flash, with stacking headers)
- 2x Pixhawk-style 4525DO differential pressure sensor breakouts (`PX4AIRSPEEDV1.1`)
- Pitot-static tube + surface tap tubing (+ a tee fitting for the static line)
- 3.7V LiPo battery with JST-PH connector (current: 500 mAh, 503035 size)
- USB-C cable

For the breadboard prototype:
- Breadboard + jumper wires

For the soldered build:
- Double-sided perfboard, 24 rows × 10 columns, 2.54 mm pitch
- 1x 40-pin female header strip (cut into 16-pin and 12-pin pieces)
- 28 AWG stranded hookup wire, heat-shrink, solder (0.6 mm), soldering iron
- Multimeter (Kaiweets KM100 used for all checks below)
- Zip ties and/or hot glue for strain relief

---

## Sensor facts (verified)

These were checked on the actual parts before soldering. Don't skip them if you replace a sensor or cable.

### The sensors are the 5 V version

The chip marking reads `4525DO-5AI 001D`. The digit before `AI` is the supply version (`3` = 3.3 V, `5` = 5 V), so these are **5 V parts running on 3.3 V**.

- **Safe:** the datasheet absolute maximum supply range is 2.7–5.5 V, so 3.3 V does not damage anything.
- **Slightly out of spec:** the factory calibration is at 5 V, so readings may be a little off.
- **Effect on Cp is small:**
  - Offset error is removed by the startup zeroing.
  - Gain error is similar for both identical sensors on the same rail, so it mostly cancels in the ratio: `(k·Δp_tap) / (k·q) = Δp_tap / q`.
- **Effect on airspeed:** absolute airspeed may be off by a few percent. Note this as a known limitation.

### Supply rule

The breakout pad is labelled **`5V`**, but it must **only ever be connected to the Feather's `3V` pin**. Never connect it to `USB` or `BAT`.

- There is no 5 V available on battery anyway: a LiPo is 3.7–4.2 V, and `USB` only has 5 V when a cable is plugged in.
- No voltage regulator is visible on the breakout, so the `5V` pad likely goes straight to the sensor chip.

### Cable colour mapping — do NOT trust colour conventions

Tested with continuity mode from the breakout's back pads to each wire end, on both sensor cables:

| Wire colour | Function |
|---|---|
| **Red** | **GND** |
| White | SDA |
| Blue | SCL |
| **Black** | **Power (`5V` pad → Feather 3V)** |

Red is ground and black is power, the opposite of what you'd expect. Both cable ends are labelled with tape. If a cable is ever replaced, re-test it; don't assume colours.

### Pull-up resistor check

Measured unpowered with a multimeter (20k Ω range):

- **On the sensor breakout:** SDA↔5V read ~14 kΩ and SCL↔5V read open. A real resistor would read the same on both lines, so this looks like the meter current going through the chip's protection diodes. **There are most likely no pull-up resistors on the breakout.**
- **On the Feather:** GPIO22, 20, 14, 32 ↔ 3V all read open. No resistor connects these pins directly to 3V.

What this means:

- **Safe:** nothing on the breakout pulls the I2C lines above 3.3 V, so there's no risk to the ESP32 GPIO (which is not 5 V tolerant).
- **Margin is thin:** the buses likely rely on the ESP32's weak internal pull-ups (~45 kΩ). With ~100 pF of cable capacitance:
  - Internal pull-up: 45 kΩ × 100 pF ≈ **4.5 µs** rise time.
  - I2C standard mode (100 kHz) spec: **≤ 1 µs**.
  - With a 4.7 kΩ external pull-up: 4.7 kΩ × 100 pF ≈ **0.47 µs**, within spec.
- Neither the breadboard prototype nor the soldered build has ever had external pull-ups, and both work reliably on the bench. Rows A–B of the perfboard are reserved so 4x 4.7 kΩ pull-ups (each SDA/SCL line → 3V) can be added later if `NaN` dropouts appear on the car.

---

## 1. Wiring — breadboard prototype

Both sensors share the same I2C address (0x28), so they **cannot** be on the same I2C bus. The firmware creates two independent I2C buses on different pin pairs to work around this.

| Sensor | VCC | GND | SDA | SCL |
|---|---|---|---|---|
| Sensor 1 — Pitot | 3V (via rail) | GND (via rail) | Labeled **SDA** pin (GPIO22) | Labeled **SCL** pin (GPIO20) |
| Sensor 2 — Tap | 3V (via rail) | GND (via rail) | **D14** (GPIO14) | **D32** (GPIO32) |

**Power and ground are shared, not per-device.** Run one wire from the Feather's 3V pin to your breadboard's red rail and one from GND to the black rail, then tap both sensors' VCC/GND into those rails. Only SDA/SCL need to be distinct, dedicated wires per sensor.

**Pull-up resistors.** The prototype runs without any external pull-up resistors and both buses work on the bench. If a sensor intermittently fails to respond (shows up as `NaN` readings), the first fix to try is a 4.7kΩ resistor from each SDA/SCL line to 3V. See "Pull-up resistor check" above for why.

**Onboard components you don't need to wire:**
- The **BOOT button (labeled SW38)** is already on the board and wired to GPIO38 — this is the button you press to start/stop logging.
- The **red status LED (pin 13)** is also onboard — no external LED needed.

---

## 2. Wiring — soldered perfboard build (current)

Same circuit as the breadboard, built on a 24 × 10 perfboard. The Feather plugs into female sockets so it stays removable. The sensor breakouts are **not** soldered to the board; they stay on their own JST-GH cables.

### Feather placement

- **Orientation: USB-C port toward row X (top edge), antenna toward row A.** Inserting the Feather backwards puts 3V and GND on the wrong pins.
- **16-pin socket:** column 09, rows I–X.
- **12-pin socket:** column 01, rows I–T.
- The two rows are 0.8" apart (8 hole spacings), per the Feather spec.
- The Feather has stacking headers (female on top, long male pins underneath), so its male pins plug into the board sockets.

Key Feather pins, counted from the antenna end:

| Row | Pins |
|---|---|
| 12-pin (col 01) | **22 (I), 20 (J), 14 (K), 32 (L)**, 15, 33, 27, 12, 13, USB, EN, BAT (T) |
| 16-pin (col 09) | 37 (I), TX, RX, MISO, MOSI, SCK, A5, A4, A3, A2, A1, A0, **GND (U)**, NC, **3V (W)**, RST (X) |

### Sensor wire landing points (front side)

Sensor wires enter from the front (component side) and are soldered on the back. Signal wires are separated by empty holes so neighbouring joints can't accidentally bridge.

| Hole | Wire |
|---|---|
| E01 | Pitot white (SDA) |
| E03 | Pitot blue (SCL) |
| E07 | Pitot black (power) |
| E09 | Pitot red (GND) |
| D07 | Tap black (power) |
| D09 | Tap red (GND) |
| C01 | Tap white (SDA) |
| C03 | Tap blue (SCL) |
| Rows A–B | Reserved for future pull-up resistors |

### Back-side connections

| Connection | Method | Purpose |
|---|---|---|
| E07 ↔ D07 | Adjacent solder bridge | Joins both power wires |
| E09 ↔ D09 | Adjacent solder bridge | Joins both ground wires |
| D07 → W09 | Jumper wire | Power bus → Feather 3V |
| D09 → U09 | Jumper wire | Ground bus → Feather GND |
| E01 → I01 | Jumper wire | Pitot SDA → GPIO22 |
| E03 → J01 | Jumper wire | Pitot SCL → GPIO20 |
| C01 → K01 | Jumper wire | Tap SDA → GPIO14 |
| C03 → L01 | Jumper wire | Tap SCL → GPIO32 |

- **The back side is mirrored:** column 01 is on the left when the board is flipped. The pin names are marked on the back in marker.
- **Jumper colours:** jumpers don't use red/black, to avoid confusion with the sensor cables' reversed colours.
- The sensor cables' original Dupont ends were cut off; the wires are soldered directly to the board. The JST-GH plugs at the sensor ends are unchanged.

### Strain relief

Solder wicks into stranded wire and makes the end stiff. Vibration then concentrates all the bending at the edge of the solder, and strands break one by one inside the insulation. The joint looks fine but readings go intermittent.

- Zip-tie the sensor cable bundle through the board's bottom corner mounting holes, with a little slack between the tie and the solder joints.
- A dab of hot glue where the wires enter the holes stops them flexing at the joint.
- Secure the cables along the car every so often so they don't swing; otherwise the load ends up on the JST plugs and the solder joints.
- Heat-shrink is insulation only. It is **not** strain relief.

### Pre-power checks (Feather removed, sensors plugged in, nothing powered)

All of these passed on the current build.

**Must beep (end-to-end, sensor pad → Feather socket hole):**

| Sensor pad | Socket hole |
|---|---|
| Pitot GND / 5V / SDA / SCL | GND (U09) / 3V (W09) / 22 (I01) / 20 (J01) |
| Tap GND / 5V / SDA / SCL | GND / 3V / 14 (K01) / 32 (L01) |

**Must NOT beep (between socket holes):**
- **3V ↔ GND** (most important)
- Every pair among 22, 20, 14, 32
- Each of 22, 20, 14, 32 ↔ 3V and ↔ GND

With the sensors plugged in, 3V↔GND may give one short chirp as a capacitor charges. That's normal. A **continuous** beep is a short.

### Power-up sequence

1. **Feather only, USB only, sensors unplugged.** Measure E07↔E09 and D07↔D09 with DC volts (20 V range): both should read ~3.3 V. Nothing should get warm.
2. **Plug in sensors (USB unplugged first), then USB.** The Serial Monitor should show both `Zero 1` and `Zero 2` as small numbers, and `50/50` valid samples for each sensor.
3. **Function test.** Gently blow into the pitot side: only `Pitot_Pa` should change. Then do the tap side: only `Tap_Pa` should change. If the wrong one moves, the buses are swapped.
4. **Wiggle test.** While logging, tap the board and flex the cables. There should be no spikes or `nan`.
5. **Battery test.** Run on LiPo only, log 30 s, then dump the data.

### Bench results (soldered build, `run001.csv`)

- Zero `nan` values across the whole run.
- Static noise: pitot −4 to +4 Pa, tap −6 to +5 Pa (1 count ≈ 1.05 Pa). This is similar to the breadboard.
- Buses confirmed not swapped: blowing into pitot raised only pitot (~650 Pa), and blowing into tap raised only tap (~1380 Pa).
- At the 20 m/s CFD condition, q = ½ × 1.225 × 20² ≈ **245 Pa**. ±2–5 Pa of noise is about 1–2% of q per sample, before averaging over the steady segment.

---

## 3. Tubing

Each sensor reads a **pressure difference between its two ports**:

```
reading = P(high port) − P(low port)
```

Neither port is a "vacuum" port. One port gets the pressure being measured, the other gets the reference (static) pressure.

```
pitot tube ──total Pt───────────→ [Pitot sensor HIGH port]
           └─static P∞──┬───────→ [Pitot sensor LOW port]
                        │ (tee)
                        └───────→ [Tap sensor LOW port]
surface tap ────────────────────→ [Tap sensor HIGH port]
```

- **Pitot sensor:** total pressure → high port, static → low port. The reading should be **positive** when moving.
- **Tap sensor:** surface tap → high port, static → low port. Under the car the surface is in suction, so the reading (and Cp) should be **negative**.
- **The static line is tee'd to both sensors.** Without a tee, the tap sensor's low port can be left open to enclosure air as a fallback. This works, but enclosure pressure may not equal freestream static, which biases Cp.

### Identifying the ports (don't guess — test)

Port 1 / Port 2 are hard to identify by eye on the breakout, so test them with the logger running:

1. **High port on each sensor.**
   - Fit a short tube on one port and blow very gently.
   - If the reading goes **positive**, that's the high port. Mark it "+" with a marker.
   - Repeat for the other sensor.
2. **Pitot tube outlets.**
   - Connect both outlets to the pitot sensor, then point the tube into a fan or blow gently from ~10 cm in front.
   - `Pitot_Pa` should be positive; if negative, swap the tubes.
   - Label the tubes "total" and "static".
3. **Tap end-to-end.**
   - With all tubing connected, apply light suction at the tap end.
   - `Tap_Pa` should go **negative**; if positive, swap the tap sensor's tubes.

Keep all blowing/suction **very gentle**. The range is only 1 psi (≈ 6.9 kPa).

---

## 4. Powering the board

Two ways to power the Feather:

- **USB-C** — for bench testing, flashing firmware, and viewing live Serial output.
- **3.7V LiPo battery (JST-PH connector)** — for untethered on-car test runs, where there's no laptop nearby.

Plug the battery into the small white 2-pin JST connector on the board. There's no separate power switch — it powers on as soon as it has power from either source.

**Charging:** if both USB and the battery are connected, the board runs on USB and automatically trickle-charges the battery. The **CHG LED** (near the USB port, separate from the red status LED) lights up while charging and turns off when done. This is normal and doesn't affect logging.

**Safety note:** the JST connector polarity must match Adafruit-style LiPo batteries — reversed polarity can destroy the board. Most third-party battery connectors are keyed correctly, but if you're ever unsure, verify wire colors (red = positive) before plugging in a new/unfamiliar battery for the first time.

### Mounting the LiPo

- **Don't stick the battery directly to the back of the perfboard.** The pin tails, solder joints and jumpers can wear through or puncture the soft pouch under vibration. A punctured LiPo can swell, smoke or catch fire.
- **Preferred:** battery and board in separate spots inside the enclosure, with foam padding around the battery.
- **Temporary:** put a piece of card or plastic over the back of the board first, then attach the battery with velcro (easier to remove than double-sided tape).
- **Don't zip-tie across the battery.** A tie concentrates pressure on one line; use a velcro strap instead.
- Protect the battery's lead exit (the yellow-taped end); don't flex it.
- Tape the JST-PH plug in place. If it vibrates loose, the current run is lost.
- Keep the battery away from the exhaust, engine and direct sun. Replace it if it swells or the pouch is damaged.

---

## 5. Arduino IDE setup

1. **Install the ESP32 board package** (one-time): Arduino IDE → Settings → Additional Board Manager URLs → add:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
   Then Tools → Board → Boards Manager → search "esp32" → install the package by Espressif Systems.

2. **Select the board:** Tools → Board → esp32 → **Adafruit ESP32 Feather V2** (not the original non-V2 variant — pin numbering differs).

3. **Select the port:** Tools → Port → pick the `/dev/cu.usbserial-...` (Mac) or `COMx` (Windows) entry. Ignore other system ports like debug-console or Bluetooth.

4. **Keep "Erase All Flash Before Sketch Upload" disabled.** Switching between `Logging.ino` and `DumpingData.ino` would otherwise wipe the saved run files.

---

## 6. Flash and run `Logging.ino`

This is the main data-collection firmware. Open it in Arduino IDE and upload (the right-arrow button).

**On boot:**
1. LED flashes 3 times (calibration starting).
2. "Calibrating... keep sensors still" — keep everything still and unobstructed for ~1 second.
3. Serial prints the number of valid calibration samples for each sensor, e.g. `Pitot valid samples: 50/50, Tap valid samples: 50/50`.
4. LED goes solid — armed and ready.

**Calibration fix (Nov 2026):** the original firmware averaged 50 readings straight into the zero offset. One bad (`NaN`) reading at boot made the zero `NaN`, which turned the entire run's pitot column into `nan`. This happened once on the bench (`run000`).

The updated firmware:
- Skips bad readings during calibration. It needs at least **40 of 50** valid samples per sensor.
- If a sensor doesn't respond, it prints `ERROR: Pitot sensor not responding (bus 22/20)` (or the tap equivalent), **fast-blinks the LED**, and retries.
- **Never goes to solid LED until both sensors calibrate.**

**LED states:**

| LED | Meaning |
|---|---|
| 3 slow flashes | Calibration starting |
| Fast blinking (repeated) | **Sensor error** — check JST plugs and Feather seating |
| Solid on | Ready — press BOOT to start logging |
| Blinking every 0.5 s | Logging |
| Off | Logging stopped, file closed, safe to unplug |

**On the car: only press BOOT once the LED is solid.**

**To log a run:**
1. Press the **BOOT (SW38)** button once — LED starts blinking, a new file (`/run000.csv`, `/run001.csv`, ...) is created automatically.
2. Do your test run.
3. Press **BOOT** again — LED goes solid off, file is safely closed. You can now unplug.

Open Tools → Serial Monitor (baud rate **115200**) to watch live readings and confirm sensors are responding (values should not be `nan`).

**Do not press RESET mid-run** — it restarts the firmware and forces a full recalibration, losing your current log.

### Diagnosing a sensor that won't respond: `i2c_scan.ino`

Upload `i2c_scan.ino` to scan both buses every 2 seconds and read raw data. Normal output:

```
Pitot bus (22/20): 0x28
Tap bus   (14/32): 0x28
Pitot raw: status=0 counts=8190
Tap   raw: status=0 counts=8192
```

- `nothing found` on one bus means a hardware problem: check that the JST plug is fully latched, the Feather is fully seated, and the joints are good.
- Wiggle the cables and press on the Feather while it runs. If `0x28` comes and goes, you've found a loose connection.
- Re-flash `Logging.ino` afterwards.

---

## 7. Retrieve data from the board

Run files live on the ESP32's internal flash (LittleFS), not on an SD card — they need to be pulled off over USB. Data survives power-off.

**Storage:** the Feather V2 has 8 MB of flash; LittleFS uses part of it (the exact size is printed as `Total space` by `DumpingData.ino`). Each row is ~30–35 bytes, so at 10 Hz:
- ~350 bytes/s
- ~42 KB per 2-minute run
- ~1.3 MB per hour

That's dozens of runs even on a small partition.

### Step A — Flash `DumpingData.ino`
This replaces `Logging.ino` temporarily (your saved run files are untouched by this). On boot it lists all files and dumps their contents over Serial.

> ⚠️ **10-file limit:** `DumpingData.ino` only loops over `run000`–`run009` (`for (int i = 0; i < 10; i++)`, in both the dump and delete functions). `Logging.ino` keeps creating `run010`, `run011`, … and those will **not** be dumped or deleted. Either dump and delete after every session, or change both loops to `i < 1000`.

### Step B — Pull the data onto your computer

- **`esp32_dump.py`** — captures every run file's full contents into `~/Desktop/esp32_data/` as real `.csv` files, and offers to delete them off the ESP32 afterward.
- **`check_logs.py`** — a lighter check: lists what run files currently exist on the board without dumping their contents, and optionally deletes them.

Before running either, make sure you have the following installed:
```bash
python3 -m pip install pyserial
```
**Close the Arduino Serial Monitor first** — only one program can hold the serial port at a time; leaving it open causes a "Resource busy" error.

Then run:
```bash
python3 esp32_dump.py
```
It auto-detects the ESP32's port. If it can't, it'll list available ports and ask you to type the right one.

### Step C — Re-flash `Logging.ino`
Once data is safely off the board, flash `Logging.ino` again before your next run.

### Trackside check after each run

There's no live telemetry for this test, so check each run before moving the tubing to the next tap:

1. Dump the run over USB.
2. Check that the **max airspeed** reached ~20 m/s.
3. Check that there is a **steady-speed segment** of usable length.
4. Check the **mean Cp** over that segment.

Re-run immediately if any of these look wrong. It costs a minute or two per run but avoids coming back to a missing tap.

---

## 8. Analyze the data

Open `PressureDataPlots.m` in MATLAB, pointed at a dumped `runXXX.csv`, and run the script. It applies spike removal and smoothing, masks out stopped/idle periods, and plots pitot pressure, tap pressure, airspeed, and Cp over time, along with summary stats (max airspeed, mean Cp, etc.).

---

## Known issues / gotchas

- **While bench testing, Cp shows as `NaN` most of the time** — this is intentional. The firmware only computes Cp when pitot pressure exceeds 5 Pa (roughly 2.9 m/s of airflow), to avoid dividing by near-zero values. Sitting still or indoors with no airflow will produce mostly `NaN` — that's expected, not a bug.
- **Static airspeed reads ~1–2 m/s** — that's sensor noise (~1–4 Pa) through `V = sqrt(2q/ρ)`, not real airflow.
- **`esp32_dump.py` fails with `ModuleNotFoundError: No module named 'serial'`** — install pyserial: `python3 -m pip install pyserial`.
- **Whole pitot (or tap) column is `nan`** — see the calibration fix in Section 6. With the updated firmware this shows up as a fast-blinking LED at boot instead of a ruined run.
- **Sensors are 5 V parts running at 3.3 V** — absolute airspeed may be off by a few percent. Cp is largely unaffected (see "Sensor facts").
- **Cable colours are reversed** — red = GND, black = power.

---

## File overview

| File | Purpose |
|---|---|
| `Logging.ino` | Main firmware — reads both sensors, computes Cp/airspeed, logs to flash on BOOT button press. Calibration skips bad readings and reports sensor errors |
| `DumpingData.ino` | Alternate firmware — lists and dumps saved run files over Serial (only `run000`–`run009`, see warning) |
| `i2c_scan.ino` | Diagnostic firmware — scans both I2C buses and reads raw sensor data every 2 s |
| `esp32_dump.py` | PC-side script to capture dumped files as real CSVs, with delete option |
| `check_logs.py` | PC-side script to check what run files exist on the board without a full dump |
| `PressureDataPlots.m` | MATLAB script to clean, plot, and summarize a run's data |

## Next Up TODO
- [x] Migrate breadboard to soldered perfboard (replaces "use shorter breadboard")
- [x] Verify sensor supply voltage, pull-ups, and cable pinout
- [x] Fix calibration so one bad reading can't ruin a run
- [ ] Decide mounting point: 1) above top panel, 2) behind steering wheel, 3) under steering
- [ ] Make mounting / enclosure (separate pocket for the LiPo; non-conductive window if telemetry is added later, since carbon fibre blocks RF)
- [ ] Final strain relief (zip ties through corner holes + hot glue)
- [ ] Seal the wires
- [ ] Get a tee fitting for the static line
- [ ] Identify and mark high/low ports on both sensors and total/static on the pitot tube
- [ ] Change `DumpingData.ino` loops from `i < 10` to `i < 1000`
- [ ] Update EasyEDA schematic with the real cable colour mapping and board layout
- [ ] Optional: add 4x 4.7 kΩ pull-ups (rows A–B reserved) if `NaN` dropouts appear on the car
- [ ] Future: live telemetry via ESP-NOW with a second ESP32 at trackside, if the first dataset proves useful
