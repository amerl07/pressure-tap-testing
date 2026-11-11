# Pressure Tap Logging – Test Notes

Transcribed from handwritten notebook. Times are as written: Session 1 in 12h (PM), Session 2 in 24h. File names are `HHMM` (24h) of export/pull.
Items marked ⚠️ are ambiguous in the original or need follow-up. Durations marked *(derived)* were calculated, not written.

---

## Session 1 — Nov 7 

### Block 0a — Warm-up

| Event               | Time      | Notes                                 |
| ------------------- | --------- | ------------------------------------- |
| Power on            | 15:27:37  | Note reads "(1:1 earlier)" ⚠️ unclear |
| **run00** log start | 15:33:20  | ≈ engine start                        |
| run00 run start     | 15:35:50  |                                       |
| run00 log stop      | 15:37:14  |                                       |
| run01, run02        | —         | Debugging runs                        |
| —                   | —         | Runs deleted from ESP                 |
| Export              | **15:54** | File `1554`                           |
| Power off           | —         |                                       |

Run window: 15:35:50 → 15:37:14 = **1 min 24 s** *(derived)*

### Block 0b — Warm-up

| Event               | Time      | Notes                        |
| ------------------- | --------- | ---------------------------- |
| Power on            | 16:35     |                              |
| **run00** log start | 16:35:27  | Warm-up run                  |
| run00 run start     | 16:36:41  |                              |
| run00 run stop      | 16:38:17  |                              |
| run00 press stop    | 16:38:42  |                              |
| **run01** log start | 16:55:05  | Warm-up run                  |
| Engine stop         | 16:55:21  | Stopped 16 s after log start |
| run01 run start     | 16:56:02  | Warm-up, engine restarts     |
| Warm-up done        | 17:00:58  |                              |
| run01 run stop      | 17:01:13  |                              |
| run01 log stop      | 17:01:35  |                              |
| Power off           | —         |                              |
| Pull data           | **17:08** | File `1708`                  |

Run windows *(derived)*:
- run00: 16:36:41 → 16:38:17 = **1 min 36 s**
- run01: 16:56:02 → 17:01:13 = **5 min 11 s** (warm-up portion ends 17:00:58 → ~4 min 56 s)

### Block 1 — CAD ride height

| Event               | Time      | Notes                   |
| ------------------- | --------- | ----------------------- |
| Power on            | 17:22:53  |                         |
| **run00** log start | 17:29:45  | 2 warm-up laps included |
| run00 run start     | 17:30:08  |                         |
| run00 run stop      | 17:37:32  |                         |
| run00 log stop      | 17:38:05  |                         |
| Pull data           | **17:45** | File `1745`             |

Run window: 17:30:08 → 17:37:32 = **7 min 24 s** *(derived)*

---

## Session 2 — Nov 8

### Block 2 — Squat Down (rear RH lowered)

- Warm-up for Block 2 **not logged**.

| Event               | Time  | Notes                                            |
| ------------------- | ----- | ------------------------------------------------ |
| **run06** run start | 13:46 |                                                  |
| run06 run stop      | 13:56 |                                                  |
| run06 log stop      | 13:56 |                                                  |
| File dump           | —     | Saved as `1109_0928`, **renamed to `1108_1356`** |

Run window: 13:46 → 13:56 ≈ **10 min** *(derived)*

---

## Data Files

| File        | Contents                | Status                                               |
| ----------- | ----------------------- | ---------------------------------------------------- |
| `1107_1554` | Block 0a                | Warm-up 1                                            |
| `1107_1708` | Block 0b (run00, run01) | Warm-up 2, 3                                         |
| `1107_1745` | Block 1 (run00)         | run00 valid                                          |
| `1108_1356` | Block 2 (run06)         | Renamed from `1109_0928` (dump timestamp ≠ run time) |
