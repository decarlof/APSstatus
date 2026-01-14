# 02bm_PV_monitor_plot.py
#
# Matplotlib-only 2-BM Monitor PNG generator (+ optional --view).
#
# Data sources:
# - EPICS CA scalars via pyepics (caget)
# - EPICS PVA detector image via PvaPy/pvapy (module: pvaccess)
# - Optional --dummy mode for offline testing (includes synthetic image)
#
# Features:
# - Energy (keV), Mode (string), Current (mA)
# - Detector snapshot (PVA): 2bmSP1:Pva1:Image or 2bmSP2:Pva1:Image
# - Detector name over image: "Detector: Oryx 5MP" (SP1) or "Detector: Oryx 32MP" (SP2)
# - Image title also includes: Acquire, Temp., File count (same line)
# - Scale bar in microns using 2bm:MCTOptics:ImagePixelSize (assumed µm/pixel)
# - Shutter A/B buttons (no numeric text)
# - IOC/Server status panel (centered header):
#     * green/red dot for each ServerRunning PV
#     * status strings printed next to server status
#
# Usage:
#   python 02bm_PV_monitor_plot.py                 # EPICS+PVA, headless PNG loop
#   python 02bm_PV_monitor_plot.py --view          # EPICS+PVA, show window + save
#   python 02bm_PV_monitor_plot.py --dummy         # Dummy PVs + synthetic image
#   python 02bm_PV_monitor_plot.py --view --dummy  # Dummy + show window + save
#
# Requirements:
#   pip install matplotlib numpy pyepics pvapy
#
# Notes:
# - Mode/Acquire are read as strings via caget(..., as_string=True).
# - For "red if not found/timeout", we use caget(timeout=...) and treat None as red.

import argparse
import time
import math
from datetime import datetime

import os, sys

# optional: force TkAgg on macOS when viewing
if "--view" in sys.argv and sys.platform == "darwin":
    os.environ.setdefault("MPLBACKEND", "TkAgg")

import matplotlib
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import numpy as np


# ----------------------------
# IOC Groups (MEDM-inspired)
# ----------------------------

IOC_GROUPS = [
    {
        "label": "mctOptics",
        "running_pv": "2bm:MCTOptics:ServerRunning",
        "status_pv": "2bm:MCTOptics:MCTStatus",
        "mode": "server_running",
    },
    {
        "label": "TomoScan",
        "running_pv": "2bmb:TomoScan:ServerRunning",
        "status_pv": "2bmb:TomoScan:ScanStatus",
        "mode": "server_running",
    },
    {
        "label": "TomoScanStream",
        "running_pv": "2bmb:TomoScanStream:ServerRunning",
        "status_pv": "2bmb:TomoScanStream:ScanStatus",
        "mode": "server_running",
    },
    {
        "label": "TomoStream",
        "running_pv": "2bmb:TomoStream:ServerRunning",
        "status_pv": "2bmb:TomoStream:ReconStatus",
        "mode": "server_running",
    },
    {
        "label": "Energy",
        "running_pv": "2bm:Energy:ServerRunning",
        "status_pv": "2bm:Energy:EnergyStatus",
        "mode": "server_running",
    },
]


# ----------------------------
# Data sources
# ----------------------------

class DummyPVSource:
    """Dummy PV generator + synthetic image. CameraSelected flips 0/1 each refresh."""
    def __init__(self):
        self.t0 = time.time()
        self._camera_selected = 0
        self._tick = 0

    def next_refresh(self):
        self._tick += 1
        self._camera_selected = 1 - self._camera_selected

    def caget(self, pv_name, **kwargs):
        t = time.time() - self.t0

        if pv_name == "2bm:Energy:Energy":
            return 24.0 + 2.0 * math.sin(t / 15.0)

        if pv_name == "2bm:Energy:EnergyMode":
            return "Mono" if int(t) % 20 < 10 else "Pink"

        if pv_name == "S:SRcurrentAI.VAL":
            return 100.0 + 3.0 * math.sin(t / 30.0)

        if pv_name == "PA:02BM:STA_A_FES_OPEN_PL":
            return 1 if int(t) % 18 < 14 else 0

        if pv_name == "PA:02BM:STA_B_SBS_OPEN_PL":
            return 1 if int(t) % 18 < 12 else 0

        if pv_name == "2bm:MCTOptics:CameraSelected.VAL":
            return self._camera_selected

        # microns/pixel (dummy)
        if pv_name == "2bm:MCTOptics:ImagePixelSize":
            return 1.3  # µm/pixel

        # IOC status demo PVs
        if pv_name.endswith(":ServerRunning"):
            return "Running" if (self._tick % 6) else "Stopped"
        if pv_name.endswith(":MCTStatus"):
            return "OK (dummy)"
        if pv_name.endswith(":ScanStatus"):
            return "Idle (dummy)"
        if pv_name.endswith(":ReconStatus"):
            return "Not running (dummy)"
        if pv_name.endswith(":EnergyStatus"):
            return "OK (dummy)"

        # SP1
        if pv_name == "2bmSP1:cam1:DetectorState_RBV":
            return "Idle" if (self._tick % 4) else "Waiting"
        if pv_name == "2bmSP1:cam1:Acquire":
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

        return None

    def pva_image(self, channel_name):
        # Synthetic image (changes slowly)
        h, w = 600, 900
        y = np.linspace(-1, 1, h)[:, None]
        x = np.linspace(-1, 1, w)[None, :]
        tt = (time.time() - self.t0) / 3.0
        img = (
            0.6 * np.exp(-((x - 0.3*np.sin(tt))**2 + (y - 0.2*np.cos(tt))**2) / 0.08)
            + 0.35 * np.exp(-((x + 0.2*np.cos(tt/2))**2 + (y + 0.25*np.sin(tt/2))**2) / 0.04)
        )
        img += 0.03 * np.random.default_rng(self._tick).standard_normal((h, w))
        img = np.clip(img, 0, None)
        return (img * 65535).astype(np.uint16)


class EpicsPVSource:
    """
    EPICS CA via pyepics PV objects (fast connection checks) + PVA image via pvaccess.

    Performance feature:
      Dead PVs are put on a cooldown so we don't block each refresh trying to connect.
    """

    def __init__(self, connect_timeout=0.15, dead_cooldown=10.0):
        import epics
        import pvaccess as pva

        self._epics = epics
        self._connect_timeout = float(connect_timeout)
        self._dead_cooldown = float(dead_cooldown)

        self._pv_cache = {}     # pvname -> epics.PV
        self._dead_until = {}   # pvname -> monotonic timestamp

        self._pva = pva
        self._pva_cache = {}    # channel_name -> pvaccess.Channel

    def next_refresh(self):
        pass

    def _pv(self, pvname):
        pv = self._pv_cache.get(pvname)
        if pv is None:
            pv = self._epics.PV(
                pvname,
                connection_timeout=self._connect_timeout,
                auto_monitor=False,
            )
            self._pv_cache[pvname] = pv
        return pv

    def caget(self, pvname, as_string=False, timeout=None, **_kwargs):
        """
        Fast CA getter.

        - If PV is in cooldown, return None immediately.
        - If not connected, attempt quick connect; on failure set cooldown and return None.
        - If connected, pv.get() with short timeout.
        """
        now = time.monotonic()
        if now < self._dead_until.get(pvname, 0.0):
            return None

        pv = self._pv(pvname)

        if not pv.connected:
            pv.wait_for_connection(timeout=self._connect_timeout)
            if not pv.connected:
                self._dead_until[pvname] = now + self._dead_cooldown
                return None

        try:
            return pv.get(as_string=as_string, timeout=timeout or 0.05)
        except Exception:
            self._dead_until[pvname] = now + self._dead_cooldown
            return None

    def _get_channel(self, channel_name):
        ch = self._pva_cache.get(channel_name)
        if ch is None:
            ch = self._pva.Channel(channel_name)
            self._pva_cache[channel_name] = ch
        return ch

    def pva_image(self, channel_name):
        try:
            ch = self._get_channel(channel_name)
            pva_img = ch.get("")
        except Exception:
            return None

        try:
            width = int(pva_img["dimension"][0]["size"])
            height = int(pva_img["dimension"][1]["size"])
            val = pva_img["value"]
            if val is None or len(val) < 1:
                return None
            v0 = val[0]
        except Exception:
            return None

        arr1d = None
        for k in (
            "ubyteValue", "ushortValue", "uintValue", "ulongValue",
            "byteValue", "shortValue", "intValue", "longValue",
            "floatValue", "doubleValue", "booleanValue",
        ):
            try:
                if k in v0:
                    arr1d = np.asarray(v0[k])
                    break
            except Exception:
                pass

        if arr1d is None:
            return None
        if width <= 0 or height <= 0 or arr1d.size < width * height:
            return None

        return arr1d[: width * height].reshape((height, width))


# ----------------------------
# Helpers
# ----------------------------

def caget_str(caget_func, pvname, timeout=0.3):
    """Read PV as string if possible (EPICS enums), else fall back."""
    try:
        return caget_func(pvname, as_string=True, timeout=timeout)
    except TypeError:
        # dummy source doesn't accept as_string/timeout
        try:
            return caget_func(pvname, as_string=True)
        except TypeError:
            return caget_func(pvname)

def caget_num(caget_func, pvname, timeout=0.3):
    """Numeric PV read with timeout; returns None on failure."""
    try:
        return caget_func(pvname, timeout=timeout)
    except TypeError:
        return caget_func(pvname)

def _fmt_num(v, nd=3):
    if v is None:
        return "N/A"
    if isinstance(v, (int, float)):
        return f"{v:.{nd}f}"
    return str(v)

def _fmt_str(v):
    if v is None:
        return "N/A"
    return str(v)

def _shutter_color_open_pl(v):
    return "green" if str(v).strip() in ("1", "1.0") else "red"

def dot_color_for_running(val, mode):
    """
    mode:
      - 'server_running': green if value indicates running
    """
    if val is None:
        return "red"

    s = str(val).strip().lower()
    if s in ("1", "true", "yes", "running", "on", "ok"):
        return "green"

    return "red"

def add_scale_bar(ax, img_shape, um_per_px, bar_um=200.0, margin_px=20, height_px=8):
    """
    Draw a scale bar in data coordinates (pixel coordinates).
    um_per_px assumed microns/pixel.
    """
    if um_per_px is None:
        return
    try:
        um_per_px = float(um_per_px)
    except Exception:
        return
    if um_per_px <= 0:
        return

    h, w = img_shape[:2]
    max_bar_px = max(10, int(0.30 * w))
    bar_px = int(round(bar_um / um_per_px))
    if bar_px <= 0:
        return

    if bar_px > max_bar_px:
        bar_px = max_bar_px
        bar_um = bar_px * um_per_px

    x0 = margin_px
    y0 = h - margin_px - height_px

    ax.add_patch(
        Rectangle(
            (x0, y0),
            bar_px,
            height_px,
            facecolor="white",
            edgecolor="black",
            linewidth=1.0,
            alpha=0.9,
        )
    )
    ax.text(
        x0 + bar_px / 2,
        y0 - 6,
        f"{bar_um:.0f} µm",
        color="white",
        ha="center",
        va="bottom",
        fontsize=10,
        fontweight="bold",
        bbox=dict(facecolor="black", alpha=0.35, edgecolor="none", pad=2),
    )


# ----------------------------
# PV config
# ----------------------------

PV_DISPLAY = {
    "Energy": "2bm:Energy:Energy",
    "Mode": "2bm:Energy:EnergyMode",
    "Current": "S:SRcurrentAI.VAL",

    "Shutter A": "PA:02BM:STA_A_FES_OPEN_PL",
    "Shutter B": "PA:02BM:STA_B_SBS_OPEN_PL",

    "Camera Selected": "2bm:MCTOptics:CameraSelected.VAL",
    "Image Pixel Size": "2bm:MCTOptics:ImagePixelSize",  # µm/px

    "SP1 Acquire": "2bmSP1:cam1:Acquire",
    "SP1 Temp.": "2bmSP1:cam1:TemperatureActual",
    "SP1 File count": "2bmSP1:HDF1:FileNumber_RBV",

    "SP2 Acquire": "2bmSP2:cam1:AcquireBusy",
    "SP2 Temp.": "2bmSP2:cam1:TemperatureActual",
    "SP2 File count": "2bmSP2:HDF1:FileNumber_RBV",

    "SP1 PVA Image": "2bmSP1:Pva1:Image",
    "SP2 PVA Image": "2bmSP2:Pva1:Image",
}


# ----------------------------
# Rendering
# ----------------------------

def render_2bm_dashboard(fig, source, pv, out_png=None):
    caget_func = source.caget

    energy = caget_num(caget_func, pv["Energy"], timeout=0.3)
    mode = caget_str(caget_func, pv["Mode"], timeout=0.3)
    current = caget_num(caget_func, pv["Current"], timeout=0.3)

    sh_a = caget_num(caget_func, pv["Shutter A"], timeout=0.3)
    sh_b = caget_num(caget_func, pv["Shutter B"], timeout=0.3)

    cam_sel = caget_num(caget_func, pv["Camera Selected"], timeout=0.3)
    cam_is_sp1 = str(cam_sel).strip() in ("0", "0.0")
    det_name = "Oryx 5MP" if cam_is_sp1 else "Oryx 32MP"
    pva_chan = pv["SP1 PVA Image"] if cam_is_sp1 else pv["SP2 PVA Image"]

    um_per_px = caget_num(caget_func, pv["Image Pixel Size"], timeout=0.3)

    sp1_acq = caget_str(caget_func, pv["SP1 Acquire"], timeout=0.3)
    sp1_temp = caget_num(caget_func, pv["SP1 Temp."], timeout=0.3)
    sp1_file = caget_num(caget_func, pv["SP1 File count"], timeout=0.3)

    sp2_acq = caget_str(caget_func, pv["SP2 Acquire"], timeout=0.3)
    sp2_temp = caget_num(caget_func, pv["SP2 Temp."], timeout=0.3)
    sp2_file = caget_num(caget_func, pv["SP2 File count"], timeout=0.3)

    if cam_is_sp1:
        acq, temp, filecount = sp1_acq, sp1_temp, sp1_file
    else:
        acq, temp, filecount = sp2_acq, sp2_temp, sp2_file

    # Compose image header extra fields
    acq_txt = _fmt_str(acq)
    temp_txt = "N/A" if temp is None else f"{_fmt_num(temp, 2)} \N{DEGREE SIGN}C"
    file_txt = _fmt_num(filecount, 0)

    img = source.pva_image(pva_chan)

    # Layout
    fig.clf()
    fig.set_facecolor("#1e1e1e")
    gs = fig.add_gridspec(
        nrows=24, ncols=6,
        left=0.06, right=0.94, top=0.97, bottom=0.05,
        hspace=0.55, wspace=0.35
    )

    # Title
    ax_title = fig.add_subplot(gs[0, :])
    ax_title.set_axis_off()
    ax_title.text(0.0, 0.7, "microCT Monitor", fontsize=16, fontweight="bold",
                  color="white", ha="left", va="center")
    ax_title.text(1.0, 0.7, datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                  fontsize=9.5, color="#cfcfcf", ha="right", va="center")

    # Readouts
    ax_read = fig.add_subplot(gs[1:3, :])
    ax_read.set_axis_off()

    def lcd(ax, x, y, w, h, label, value, color="white"):
        ax.add_patch(Rectangle((x, y), w, h, transform=ax.transAxes,
                               facecolor="black", edgecolor="#555555", linewidth=1.0))
        ax.text(x + w/2, y + h + 0.08, label, transform=ax.transAxes,
                ha="center", va="bottom", fontsize=10, color="white")
        ax.text(x + w/2, y + h/2, value, transform=ax.transAxes,
                ha="center", va="center", fontsize=18, fontweight="bold", color=color)

    lcd(ax_read, 0.00, 0.10, 0.32, 0.65, "Energy (keV)", _fmt_num(energy, 4), color="cyan")
    lcd(ax_read, 0.34, 0.10, 0.32, 0.65, "Mode", _fmt_str(mode), color="white")
    lcd(ax_read, 0.68, 0.10, 0.32, 0.65, "Current (mA)", _fmt_num(current, 3), color="yellow")

    # Image snapshot
    ax_img = fig.add_subplot(gs[3:12, :])
    ax_img.set_facecolor("black")
    ax_img.set_xticks([])
    ax_img.set_yticks([])
    ax_img.set_title(
        f"Detector: {det_name}    Acquire: {acq_txt}    Temp.: {temp_txt}    File count: {file_txt}",
        color="white",
        fontsize=11,
    )

    if img is None:
        ax_img.text(
            0.5, 0.5,
            f"No PVA image / parse failed:\n{pva_chan}",
            transform=ax_img.transAxes,
            ha="center", va="center",
            color="#cfcfcf", fontsize=11
        )
    else:
        arr = np.asarray(img)
        vmin = np.percentile(arr, 1)
        vmax = np.percentile(arr, 99)
        if not np.isfinite(vmin) or not np.isfinite(vmax) or vmax <= vmin:
            vmin, vmax = float(arr.min()), float(arr.max()) if arr.size else (0, 1)
        ax_img.imshow(arr, cmap="gray", vmin=vmin, vmax=vmax, aspect="auto")

        add_scale_bar(ax_img, arr.shape, um_per_px, bar_um=200.0)

        if um_per_px is not None:
            try:
                ax_img.text(
                    0.99, 0.01,
                    f"{float(um_per_px):.3f} µm/px",
                    transform=ax_img.transAxes,
                    ha="right", va="bottom",
                    color="white", fontsize=9,
                    bbox=dict(facecolor="black", alpha=0.35, edgecolor="none", pad=2),
                )
            except Exception:
                pass

    # Shutters (no numeric text)
    ax_sh = fig.add_subplot(gs[12:14, :])
    ax_sh.set_axis_off()

    def shutter_button(ax, x, w, label, color):
        ax.add_patch(Rectangle((x, 0.30), w, 0.55, transform=ax.transAxes,
                               facecolor=color, edgecolor="black", linewidth=1.2))
        ax.text(x + w/2, 0.58, label, transform=ax.transAxes,
                ha="center", va="center", fontsize=14, color="white", fontweight="bold")

    shutter_button(ax_sh, 0.10, 0.38, "Shutter A", _shutter_color_open_pl(sh_a))
    shutter_button(ax_sh, 0.52, 0.38, "Shutter B", _shutter_color_open_pl(sh_b))

    # IOC / Server status panel (moved up to fill removed detector panel)
    ax_ioc = fig.add_subplot(gs[14:24, :])
    ax_ioc.set_axis_off()
    ax_ioc.add_patch(Rectangle((0, 0), 1, 1, transform=ax_ioc.transAxes,
                               facecolor="#252525", edgecolor="#404040", linewidth=1.0))
    # Column headers
    ax_ioc.text(0.08, 0.86, "Component", transform=ax_ioc.transAxes,
                ha="left", va="center", fontsize=10, color="#cfcfcf", fontweight="bold")
    ax_ioc.text(0.40, 0.86, "EPICS IOC", transform=ax_ioc.transAxes,
                ha="left", va="center", fontsize=10, color="#cfcfcf", fontweight="bold")
    ax_ioc.text(0.60, 0.86, "Status", transform=ax_ioc.transAxes,
                ha="left", va="center", fontsize=10, color="#cfcfcf", fontweight="bold")

    y = 0.74
    dy = 0.10

    for grp in IOC_GROUPS:
        label = grp["label"]
        run_pv = grp["running_pv"]
        status_pv = grp.get("status_pv")
        mode_kind = grp.get("mode", "server_running")

        run_val = caget_str(caget_func, run_pv, timeout=0.3)
        status_val = caget_str(caget_func, status_pv, timeout=0.3) if status_pv else None

        dot = dot_color_for_running(run_val, mode_kind)

        ax_ioc.add_patch(plt.Circle((0.04, y), 0.015, transform=ax_ioc.transAxes,
                                    facecolor=dot, edgecolor="black", linewidth=1.0))

        ax_ioc.text(0.08, y, label, transform=ax_ioc.transAxes,
                    ha="left", va="center", fontsize=10.0, color="white")
        ax_ioc.text(0.40, y, _fmt_str(run_val), transform=ax_ioc.transAxes,
                    ha="left", va="center", fontsize=9.5, color="#cfcfcf")

        if status_pv:
            ax_ioc.text(0.60, y, _fmt_str(status_val), transform=ax_ioc.transAxes,
                        ha="left", va="center", fontsize=9.5, color="#f0f0f0")

        y -= dy

    fig.canvas.draw()
    if out_png:
        fig.savefig(out_png, bbox_inches="tight", pad_inches=0.06)


# ----------------------------
# Main
# ----------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--view", action="store_true",
                        help="Show a live-updating window (also saves PNG).")
    parser.add_argument("--dummy", action="store_true",
                        help="Use dummy PV values (and synthetic image) instead of EPICS/PVA.")
    parser.add_argument("--out", default="2bm_monitor.png",
                        help="Output PNG path.")
    parser.add_argument("--period", type=int, default=60,
                        help="Update period in seconds.")
    args = parser.parse_args()

    # If not viewing, force Agg for headless rendering
    if not args.view:
        matplotlib.use("Agg")

    source = DummyPVSource() if args.dummy else EpicsPVSource()
    fig = plt.figure(figsize=(6.5, 11.0), dpi=120)

    if args.view:
        while plt.fignum_exists(fig.number):
            source.next_refresh()
            render_2bm_dashboard(fig, source, PV_DISPLAY, out_png=args.out)
            plt.pause(0.1)
            time.sleep(args.period)
    else:
        while True:
            source.next_refresh()
            render_2bm_dashboard(fig, source, PV_DISPLAY, out_png=args.out)
            time.sleep(args.period)


if __name__ == "__main__":
    main()
