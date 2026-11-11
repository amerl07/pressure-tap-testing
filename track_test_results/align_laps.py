"""Map laptimes.csv lap boundaries onto ESP32 time_ms.

Inputs: laptimes.csv, the ESP32 CSVs, and two times from pitot_log_notes.md.
See LAP_ALIGNMENT.md for the full method and checks.

1. Block 1 (CAD RH) anchor: lap t=0 is the "run start" in the notes
   (17:30:08). ESP time_ms counts from power on (17:22:53), so the offset is 435 s.
2. Block 2 (Squat Down): the notes only give minutes, so each hot lap's
   airspeed profile is matched to the Block 1 mean hot-lap profile, which begins
   at the finish line. The offset is found by scanning for the best match.

esp_time_s = lap_time_s + OFFSET[block]
Run:  python3 align_laps.py   (from track_test_results/)
"""
import numpy as np
import pandas as pd
from scipy.signal import medfilt, savgol_filter
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BLOCKS = {
    # setting in laptimes.csv: esp32 file
    "CAD Ride Height": "../esp32_data/1107_1745/run000.csv",
    "Squat Down": "../esp32_data/1108_1356/run006.csv",
}
REFERENCE = "CAD Ride Height"
# From pitot_log_notes.md, Block 1. ESP time_ms counts from power on; this is
# verified by "log start 17:29:45" = 412 s after power on = the file's first time_ms (412114).
POWER_ON = pd.Timestamp("2026-11-07 17:22:53")
RUN_START = pd.Timestamp("2026-11-07 17:30:08")  # = lap time 0 (car pulls away)
REF_OFFSET = (RUN_START - POWER_ON).total_seconds()  # 435 s, +/-1 s (notes to the second)
BOOT_CLOCK = {"CAD Ride Height": POWER_ON}

P = np.linspace(0, 1, 300)


def load_esp(path):
    x = pd.read_csv(path)
    a = savgol_filter(medfilt(x.airspeed_ms.values, 5), 31, 3)
    return x, x.time_ms.values / 1000, a


def load_laps():
    L = pd.read_csv("laptimes.csv", skiprows=2, header=None,
                    names=["setting", "lap", "start", "finish", "laptime", "note", "_"])
    L = L[L.lap.notna()].copy()
    L["finish"] = L.finish.astype(float)
    L["start"] = pd.to_numeric(L.start, errors="coerce")
    L["lap"] = L.lap.astype(int)
    return L.drop(columns="_")


def lap_profile(t, a, s, f, c):
    return np.interp(s + c + P * (f - s), t, a)


def main():
    L = load_laps()
    esp = {k: load_esp(v) for k, v in BLOCKS.items()}

    # Reference template from Block 1 hotlaps
    _, t1, a1 = esp[REFERENCE]
    r = L[(L.setting == REFERENCE) & (L.note == "Hotlap")]
    T = np.mean([lap_profile(t1, a1, s, f, REF_OFFSET) for s, f in zip(r.start, r.finish)], 0)

    offsets = {REFERENCE: REF_OFFSET}
    for name in BLOCKS:
        if name == REFERENCE:
            continue
        _, t, a = esp[name]
        l = L[L.setting == name]
        h = l[l.note == "Hotlap"]
        cs = np.arange(t[0] - l.start.min(), t[-1] - l.finish.max(), 0.01)
        score = [np.mean([np.corrcoef(lap_profile(t, a, s, f, c), T)[0, 1]
                          for s, f in zip(h.start, h.finish)]) for c in cs]
        offsets[name] = round(float(cs[int(np.argmax(score))]), 2)
        print(f"{name}: offset {offsets[name]} s, template r = {max(score):.3f}")

    rows = []
    fig, axes = plt.subplots(len(BLOCKS), 1, figsize=(14, 7), constrained_layout=True)
    for ax, name in zip(axes, BLOCKS):
        _, t, a = esp[name]
        c = offsets[name]
        l = L[L.setting == name]
        ax.plot(t, a, lw=0.8, color="0.3")
        for _, q in l.iterrows():
            s = q.start if np.isfinite(q.start) else 0.0  # lap t=0 = car pulls away
            e0, e1 = s + c, q.finish + c
            i0, i1 = np.searchsorted(t, [e0, e1])
            prof_r = np.corrcoef(lap_profile(t, a, s, q.finish, c), T)[0, 1]
            rows.append(dict(setting=name, esp_file=BLOCKS[name].split("esp32_data/")[1],
                             lap=q.lap, note=q.note, lap_start_s=q.start, lap_end_s=q.finish,
                             esp_start_ms=round(e0 * 1000), esp_end_ms=round(e1 * 1000),
                             row_start=i0 + 2, row_end=i1 + 1,  # 1-based CSV line numbers incl. header
                             wall_start=(BOOT_CLOCK[name] + pd.Timedelta(seconds=e0)).strftime("%H:%M:%S")
                             if name in BOOT_CLOCK else "",
                             wall_end=(BOOT_CLOCK[name] + pd.Timedelta(seconds=e1)).strftime("%H:%M:%S")
                             if name in BOOT_CLOCK else "",
                             r_vs_template=round(prof_r, 2)))
            ax.axvline(e1, color="C3", lw=0.8)
            ax.text((e0 + e1) / 2, ax.get_ylim()[1] * 0.95 if ax.get_ylim()[1] else 20,
                    str(q.lap), ha="center", va="top", fontsize=8,
                    color="C0" if q.note == "Hotlap" else "C1")
        ax.set_title(f"{name}  ({BLOCKS[name].split('esp32_data/')[1]})   esp_t = lap_t + {c} s")
        ax.set_ylabel("airspeed (m/s)")
    axes[-1].set_xlabel("ESP32 time (s since boot)")
    fig.savefig("esp32_lap_alignment.png", dpi=130)

    out = pd.DataFrame(rows)
    out.to_csv("esp32_lap_index.csv", index=False)
    print(out.to_string(index=False))


if __name__ == "__main__":
    main()
