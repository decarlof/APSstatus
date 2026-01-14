# 02bm_PV_monitor_plot.py
#
# Matplotlib-only 2-BM Monitor PNG generator (+ optional --view).
#
# Updates in this revision:
# - Display AcquireBusy for SP1/SP2 (Done/Acquiring)
# - Dummy DetectorState_RBV now returns Idle/Waiting (strings)
#
# Usage:
#   python 02bm_PV_monitor_plot.py            # headless: saves PNG once/min, no window
#   python 02bm_PV_monitor_plot.py --view     # shows a live-updating window + also saves PNG

import argparse
import time
import math
from datetime import datetime

import matplotlib
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle


class DummyPVSource:
    """
    Dummy PV generator.

    Provides dummy values for:
      - Energy, EnergyMode, Ring Current, Shutter A/B
      - CameraSelected (flips 0/1 each refresh)
      - SP1/SP2 PVs including DetectorState_RBV (Idle/Waiting) and AcquireBusy (Done/Acquiring)
    """
    def __init__(self):
        self.t0 = time.time()
        self._camera_selected = 0
        self._tick = 0

    def next_refresh(self):
        """Call once per dashboard refresh to flip CameraSelected 0/1."""
        self._tick += 1
        self._camera_selected = 1 - self._camera_selected

    def caget(self, pv_name):
        t = time.time() - self.t0

        if pv_name == "2bm:Energy:Energy":
            return 24.0 + 2.0 * math.sin(t / 15.0)

        if pv_name == "2bm:Energy:EnergyMode":
            return "Mono" if int(t) % 20 < 10 else "Pink"

        if pv_name == "S:SRcurrentAI.VAL":
            return 100.0 + 3.0 * math.sin(t / 30.0)

        # Shutters A/B: *_OPEN_PL -> 1 open, 0 closed (assumed)
        if pv_name == "PA:02BM:STA_A_FES_OPEN_PL":
            return 1 if int(t) % 18 < 14 else 0
        if pv_name == "PA:02BM:STA_B_SBS_OPEN_PL":
            return 1 if int(t) % 18 < 12 else 0

        # Camera selection flips each refresh
        if pv_name == "2bm:MCTOptics:CameraSelected.VAL":
            return self._camera_selected

        # SP1
        if pv_name == "2bmSP1:cam1:DetectorState_RBV":
            return "Idle" if (self._tick % 4) else "Waiting"
        if pv_name == "2bmSP1:cam1:AcquireBusy":
            return "Acquiring" if (self._tick % 6 in (0, 1, 2)) else "Done"
        if pv_name == "2bmSP1:cam1:TemperatureActual":
            return 25.0 + 0.6 * math.sin(t / 10.0)
        if pv_name == "2bmSP1:HDF1:FileNumber_RBV":
            return 1000 + self._tick

        # SP2
        if pv_name == "2bmSP2:cam1:DetectorState_RBV":
            return "Idle" if (self._tick % 3) else "Waiting"
        if pv_name == "2bmSP2:cam1:AcquireBusy":
            return "Acquiring" if (self._tick % 5 in (0, 1)) else "Done"
        if pv_name == "2bmSP2:cam1:TemperatureActual":
            return 28.0 + 0.7 * math.sin(t / 9.0)
        if pv_name == "2bmSP2:HDF1:FileNumber_RBV":
            return 2000 + self._tick

        # Not displayed yet
        return None


def _fmt(v, nd=3):
    if v is None:
        return "N/A"
    if isinstance(v, (int, float)):
        return f"{v:.{nd}f}"
    return str(v)


def _shutter_color_open_pl(v):
    return "green" if str(v).strip() in ("1", "1.0") else "red"


def render_2bm_dashboard(fig, caget_func, pv, out_png=None):
    energy = caget_func(pv["Energy"])
    mode = caget_func(pv["Mode"])
    ring = caget_func(pv["Ring Current"])
    sh_a = caget_func(pv["Shutter A"])
    sh_b = caget_func(pv["Shutter B"])

    cam_sel = caget_func(pv["Camera Selected"])

    # read both sets (dashboard will decide which to display)
    sp1_state = caget_func(pv["SP1 Detector State"])
    sp1_busy = caget_func(pv["SP1 Acquire Busy"])
    sp1_temp = caget_func(pv["SP1 Temperature"])
    sp1_file = caget_func(pv["SP1 File Number"])

    sp2_state = caget_func(pv["SP2 Detector State"])
    sp2_busy = caget_func(pv["SP2 Acquire Busy"])
    sp2_temp = caget_func(pv["SP2 Temperature"])
    sp2_file = caget_func(pv["SP2 File Number"])

    if str(cam_sel).strip() in ("0", "0.0"):
        cam_label = "SP1"
        det_state, acq_busy, det_temp, det_file = sp1_state, sp1_busy, sp1_temp, sp1_file
    else:
        cam_label = "SP2"
        det_state, acq_busy, det_temp, det_file = sp2_state, sp2_busy, sp2_temp, sp2_file

    fig.clf()
    fig.set_facecolor("#1e1e1e")

    gs = fig.add_gridspec(
        nrows=12, ncols=6,
        left=0.06, right=0.94, top=0.96, bottom=0.06,
        hspace=0.55, wspace=0.35
    )

    # Title
    ax_title = fig.add_subplot(gs[0, :])
    ax_title.set_axis_off()
    ax_title.text(0.0, 0.7, "2-BM Monitor", fontsize=16, fontweight="bold",
                  color="white", ha="left", va="center")
    ax_title.text(1.0, 0.7, datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                  fontsize=9.5, color="#cfcfcf", ha="right", va="center")

    # LCD-like readouts
    ax_read = fig.add_subplot(gs[1:3, :])
    ax_read.set_axis_off()

    def lcd(ax, x, y, w, h, label, value, color="white"):
        ax.add_patch(Rectangle((x, y), w, h, transform=ax.transAxes,
                               facecolor="black", edgecolor="#555555", linewidth=1.0))
        ax.text(x + w/2, y + h + 0.08, label, transform=ax.transAxes,
                ha="center", va="bottom", fontsize=10, color="white")
        ax.text(x + w/2, y + h/2, value, transform=ax.transAxes,
                ha="center", va="center", fontsize=18, fontweight="bold", color=color)

    lcd(ax_read, 0.00, 0.10, 0.32, 0.65, "Energy", _fmt(energy, 4), color="cyan")
    lcd(ax_read, 0.34, 0.10, 0.32, 0.65, "Mode", _fmt(mode, 0), color="white")
    lcd(ax_read, 0.68, 0.10, 0.32, 0.65, "Ring Current", _fmt(ring, 3), color="yellow")

    # Shutters A/B
    ax_sh = fig.add_subplot(gs[3:5, :])
    ax_sh.set_axis_off()

    def shutter_button(ax, x, w, label, color, val):
        ax.add_patch(Rectangle((x, 0.30), w, 0.55, transform=ax.transAxes,
                               facecolor=color, edgecolor="black", linewidth=1.2))
        ax.text(x + w/2, 0.58, label, transform=ax.transAxes,
                ha="center", va="center", fontsize=14, color="white", fontweight="bold")
        ax.text(x + w/2, 0.18, f"{_fmt(val, 0)}", transform=ax.transAxes,
                ha="center", va="center", fontsize=10, color="#d0d0d0")

    shutter_button(ax_sh, 0.10, 0.38, "Shutter A", _shutter_color_open_pl(sh_a), sh_a)
    shutter_button(ax_sh, 0.52, 0.38, "Shutter B", _shutter_color_open_pl(sh_b), sh_b)

    # Camera section
    ax_cam = fig.add_subplot(gs[5:8, :])
    ax_cam.set_axis_off()
    ax_cam.add_patch(Rectangle((0, 0), 1, 1, transform=ax_cam.transAxes,
                               facecolor="#252525", edgecolor="#404040", linewidth=1.0))

    ax_cam.text(0.02, 0.90, f"Camera Selected: {cam_label} (PV={_fmt(cam_sel, 0)})",
                transform=ax_cam.transAxes, ha="left", va="top",
                fontsize=12, color="white", fontweight="bold")

    def small_kv(ax, y, key, val):
        ax.text(0.03, y, key, transform=ax.transAxes, ha="left", va="center",
                fontsize=11, color="#cfcfcf")
        ax.text(0.55, y, val, transform=ax.transAxes, ha="left", va="center",
                fontsize=12, color="white", fontweight="bold")

    small_kv(ax_cam, 0.68, f"{cam_label} DetectorState_RBV", _fmt(det_state, 0))
    small_kv(ax_cam, 0.50, f"{cam_label} AcquireBusy", _fmt(acq_busy, 0))
    small_kv(ax_cam, 0.32, f"{cam_label} TemperatureActual", _fmt(det_temp, 2))
    small_kv(ax_cam, 0.14, f"{cam_label} HDF1 FileNumber_RBV", _fmt(det_file, 0))

    # Placeholder for future PVs
    ax_future = fig.add_subplot(gs[8:, :])
    ax_future.set_axis_off()
    ax_future.add_patch(Rectangle((0, 0), 1, 1, transform=ax_future.transAxes,
                                  facecolor="#252525", edgecolor="#404040", linewidth=1.0))
    ax_future.text(0.02, 0.90, "Future PVs (not displayed yet):",
                   transform=ax_future.transAxes, ha="left", va="top",
                   fontsize=11, color="white", fontweight="bold")
    ax_future.text(0.02, 0.78,
                   f"{len(FUTURE_PVS)} PVs configured (values read optional later)",
                   transform=ax_future.transAxes, ha="left", va="top",
                   fontsize=10, color="#cfcfcf")

    fig.canvas.draw()

    if out_png:
        fig.savefig(out_png, bbox_inches="tight", pad_inches=0.06)


PV_DISPLAY = {
    "Energy": "2bm:Energy:Energy",
    "Mode": "2bm:Energy:EnergyMode",
    "Shutter A": "PA:02BM:STA_A_FES_OPEN_PL",
    "Shutter B": "PA:02BM:STA_B_SBS_OPEN_PL",
    "Ring Current": "S:SRcurrentAI.VAL",

    "Camera Selected": "2bm:MCTOptics:CameraSelected.VAL",

    "SP1 Detector State": "2bmSP1:cam1:DetectorState_RBV",
    "SP1 Acquire Busy": "2bmSP1:cam1:AcquireBusy",
    "SP1 Temperature": "2bmSP1:cam1:TemperatureActual",
    "SP1 File Number": "2bmSP1:HDF1:FileNumber_RBV",

    "SP2 Detector State": "2bmSP2:cam1:DetectorState_RBV",
    "SP2 Acquire Busy": "2bmSP2:cam1:AcquireBusy",
    "SP2 Temperature": "2bmSP2:cam1:TemperatureActual",
    "SP2 File Number": "2bmSP2:HDF1:FileNumber_RBV",
}

FUTURE_PVS = [
    "S02BM-FEEPS:FES_PermitM",
    "2bm:MCTOptics:MCTStatus",
    "2bm:MCTOptics:ServerRunning",
    "2bmb:TomoScan:ScanStatus",
    "2bmb:TomoScan:ServerRunning",
    "2bmb:TomoScanStream:ScanStatus",
    "2bmb:TomoScanStream:ServerRunning",
    "2bmb:TomoStream:ReconStatus",
    "2bmb:TomoStream:ServerRunning",
    "2bm:Energy:EnergyStatus",
    "2bm:Energy:ServerRunning",
    "2bm:MCTOptics:LensSelect.VAL",
    "2bm:MCTOptics:CameraSelect.VAL",
    "2bmbAERO:m1.VAL",
    "2bmHXP:m1.VAL",
    "2bmHXP:m3.VAL",
    "2bmb:m102.VAL",
    "2bm:MCTOptics:ScintillatorType",
    "2bm:MCTOptics:ScintillatorThickness",
    "2bm:MCTOptics:ImagePixelSize",
    "2bm:MCTOptics:DetectorPixelSize",
    "2bm:MCTOptics:CameraObjective",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--view", action="store_true",
                        help="Show a live-updating window (also saves PNG).")
    parser.add_argument("--out", default="2bm_monitor.png",
                        help="Output PNG path.")
    parser.add_argument("--period", type=int, default=60,
                        help="Update period in seconds.")
    args = parser.parse_args()

    if not args.view:
        matplotlib.use("Agg")

    dummy = DummyPVSource()
    fig = plt.figure(figsize=(5, 7), dpi=120)

    if args.view:
        while plt.fignum_exists(fig.number):
            dummy.next_refresh()
            render_2bm_dashboard(fig, dummy.caget, PV_DISPLAY, out_png=args.out)
            plt.pause(0.1)
            time.sleep(args.period)
    else:
        while True:
            dummy.next_refresh()
            render_2bm_dashboard(fig, dummy.caget, PV_DISPLAY, out_png=args.out)
            time.sleep(args.period)


if __name__ == "__main__":
    main()
