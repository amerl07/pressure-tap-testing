# C-Channel Pressure Tap Validation — Setup Guide

This guide walks through wiring, powering, flashing, running, and retrieving data from the ESP32-based pressure tap logger. It assumes you're starting from a bare ESP32 Feather V2, two 4525DO pressure sensor breakouts, a breadboard, and a 3.7V LiPo battery.

## What this system does

Two identical differential pressure sensors (4525DO) are read by an ESP32 Feather V2:

- **Sensor 1 (Pitot)** — measures freestream dynamic pressure, used to compute airspeed.
- **Sensor 2 (Tap)** — measures pressure at one surface tap location at a time.

The board computes `Cp = tap_pressure / pitot_pressure` in real time and logs everything to its own internal flash storage. Since only one tap sensor exists, you test one tap location per run and physically move the tubing between runs.

---

## Hardware needed

- ESP32 Feather V2
- 2x Pixhawk-style 4525DO differential pressure sensor breakouts
- Breadboard + jumper wires
- 2x 4.7kΩ resistors (pull-ups — see wiring notes below)
- Pitot-static tube + surface tap tubing
- 3.7V LiPo battery with JST-PH connector (e.g. 500mAh)
- USB-C cable

---

## 1. Wiring

Both sensors share the same I2C address (0x28), so they **cannot** be on the same I2C bus. The firmware creates two independent I2C buses on different pin pairs to work around this.

| Sensor | VCC | GND | SDA | SCL |
|---|---|---|---|---|
| Sensor 1 — Pitot | 3V (via rail) | GND (via rail) | Labeled **SDA** pin (GPIO22) | Labeled **SCL** pin (GPIO20) |
| Sensor 2 — Tap | 3V (via rail) | GND (via rail) | **D14** (GPIO14) | **D32** (GPIO32) |

**Power and ground are shared, not per-device.** Run one wire from the Feather's 3V pin to your breadboard's red rail and one from GND to the black rail, then tap both sensors' VCC/GND into those rails. Only SDA/SCL need to be distinct, dedicated wires per sensor.

**Pull-up resistors matter.** The labeled SDA/SCL pins have built-in pull-ups on the board. The second bus (D14/D32) does **not**. Add a 4.7kΩ resistor from D14 to 3V and another from D32 to 3V, or Sensor 2 may intermittently fail to respond (shows up as `NaN` readings).

**Tubing:**
- Pitot sensor: one port to the pitot tube (total pressure), the other port to the static reference from the same pitot-static assembly.
- Tap sensor: one port to the surface tap tubing, the other port tee'd into the same static reference line as the pitot sensor.

**Onboard components you don't need to wire:**
- The **BOOT button (labeled SW38)** is already on the board and wired to GPIO38 — this is the button you press to start/stop logging.
- The **red status LED (pin 13)** is also onboard — no external LED needed.

---

## 2. Powering the board

Two ways to power the Feather:

- **USB-C** — for bench testing, flashing firmware, and viewing live Serial output.
- **3.7V LiPo battery (JST-PH connector)** — for untethered on-car test runs, where there's no laptop nearby.

Plug the battery into the small white 2-pin JST connector on the board. There's no separate power switch — it powers on as soon as it has power from either source.

**Charging:** if both USB and the battery are connected, the board runs on USB and automatically trickle-charges the battery. The **CHG LED** (near the USB port, separate from the red status LED) lights up while charging and turns off when done. This is normal and doesn't affect logging.

**Safety note:** the JST connector polarity must match Adafruit-style LiPo batteries — reversed polarity can destroy the board. Most third-party battery connectors are keyed correctly, but if you're ever unsure, verify wire colors (red = positive) before plugging in a new/unfamiliar battery for the first time.

---

## 3. Arduino IDE setup

1. **Install the ESP32 board package** (one-time): Arduino IDE → Settings → Additional Board Manager URLs → add:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
   Then Tools → Board → Boards Manager → search "esp32" → install the package by Espressif Systems.

2. **Select the board:** Tools → Board → esp32 → **Adafruit ESP32 Feather V2** (not the original non-V2 variant — pin numbering differs).

3. **Select the port:** Tools → Port → pick the `/dev/cu.usbserial-...` (Mac) or `COMx` (Windows) entry. Ignore other system ports like debug-console or Bluetooth.

---

## 4. Flash and run `Logging.ino`

This is the main data-collection firmware. Open it in Arduino IDE and upload (the right-arrow button).

**On boot:**
1. LED flashes 3 times (calibration starting).
2. "Calibrating... keep sensors still" — keep everything still and unobstructed for ~1 second.
3. LED goes solid — armed and ready.

**To log a run:**
1. Press the **BOOT (SW38)** button once — LED starts blinking, a new file (`/run000.csv`, `/run001.csv`, ...) is created automatically.
2. Do your test run.
3. Press **BOOT** again — LED goes solid off, file is safely closed. You can now unplug.

Open Tools → Serial Monitor (baud rate **115200**) to watch live readings and confirm sensors are responding (values should not be `nan`).

**Do not press RESET mid-run** — it restarts the firmware and forces a full recalibration, losing your current log.

---

## 5. Retrieve data from the board

Run files live on the ESP32's internal flash (LittleFS), not on an SD card — they need to be pulled off over USB.

### Step A — Flash `DumpingData.ino`
This replaces `Logging.ino` temporarily (your saved run files are untouched by this). On boot it lists all files and dumps their contents over Serial.

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

---

## 6. Analyze the data

Open `PressureDataPlots.m` in MATLAB, pointed at a dumped `runXXX.csv`. It applies spike removal and smoothing, masks out stopped/idle periods, and plots pitot pressure, tap pressure, airspeed, and Cp over time, along with summary stats (max airspeed, mean Cp, etc.).

---

## Known issues / gotchas

- **While bench testing, Cp shows as `NaN` most of the time** — this is intentional. The firmware only computes Cp when pitot pressure exceeds 5 Pa (roughly 2.9 m/s of airflow), to avoid dividing by near-zero values. Sitting still or indoors with no airflow will produce mostly `NaN` — that's expected, not a bug.
- **`esp32_dump.py` fails with `ModuleNotFoundError: No module named 'serial'`** — install pyserial: `python3 -m pip install pyserial`.

---

## File overview

| File | Purpose |
|---|---|
| `Logging.ino` | Main firmware — reads both sensors, computes Cp/airspeed, logs to flash on BOOT button press |
| `DumpingData.ino` | Alternate firmware — lists and dumps saved run files over Serial |
| `esp32_dump.py` | PC-side script to capture dumped files as real CSVs, with delete option |
| `check_logs.py` | PC-side script to check what run files exist on the board without a full dump |
| `PressureDataPlots.m` | MATLAB script to clean, plot, and summarize a run's data |