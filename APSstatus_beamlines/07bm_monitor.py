# 07bm_monitor.py
#
# Matplotlib-only 7-BM Monitor PNG generator (+ optional --view).
#
# CHANGE IMPLEMENTED:
# - The PV "PB:07BM:INBD_WHITE_SW.VAL" is treated as an ON/OFF switch.
#   If ON (or 1/true/yes) -> Mode label shows "WHITE"
#   Otherwise              -> Mode label shows "MONO"
#
# Usage:
#   python 07bm_monitor.py                 # EPICS+PVA, headless PNG loop
#   python 07bm_monitor.py --view          # EPICS+PVA, show window + save
#   python 07bm_monitor.py --dummy         # Dummy PVs + synthetic image
#   python 07bm_monitor.py --view --dummy  # Dummy + show window + save
#
# Requirements:
#   pip install matplotlib numpy pyepics pvapy

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
        "label": "TomoScan",
        "running_pv": "7bmtomo:TomoScan:ServerRunning",
        "status_pv": "7bmtomo:TomoScan:ScanStatus",
        "mode": "server_running",
    },
    {
        "label": "Images Saved",
        "running_pv": "7bmtomo:TomoScan:ImagesSaved",
        "status_pv": None,
        "mode": "nonzero_ok",
    },
    {
        "label": "Remaining Time",
        "running_pv": "7bmtomo:TomoScan:RemainingTime",
        "status_pv": None,
        "mode": "nonzero_ok",
    },
]


# ----------------------------
# Data sources
# ----------------------------

class DummyPVSource:
    """Dummy PV generator + synthetic image."""
    def __init__(self):
        self.t0 = time.time()
        self._tick = 0

    def next_refresh(self):
        self._tick += 1

    def caget(self, pv_name, **kwargs):
        t = time.time() - self.t0

        if pv_name == "7bma1:filter1:Position":
            return "IN" if int(t) % 20 < 10 else "OUT"

        if pv_name == "7bma1:filter2:Position":
            return "IN" if int(t) % 26 < 13 else "OUT"

        # Mode switch PV (dummy): simulate ON/OFF (so mapping works)
        if pv_name == "PB:07BM:INBD_WHITE_SW.VAL":
            return "ON" if int(t) % 20 < 10 else "OFF"

        if pv_name == "S:SRcurrentAI.VAL":
            return 100.0 + 3.0 * math.sin(t / 30.0)

        # Shutter closed status PVs: 1 means closed (so open when 0)
        if pv_name == "PB:07BM:STA_A_FES_CLSD_PL.VAL":
            return 0 if int(t) % 18 < 14 else 1
        if pv_name == "PB:07BM:STA_B_SBS_CLSD_PL.VAL":
            return 0 if int(t) % 18 < 12 else 1

        # microns/pixel (dummy)
        if pv_name == "7bmtomo:TomoScan:ImagePixelSize":
            return 1.3  # µm/pixel

        # detector / camera
        if pv_name == "7bmSP1:cam1:Acquire":
            return "Acquiring" if (self._tick % 6 in (0, 1, 2)) else "Done"
        if pv_name == "7bmSP1:cam1:AcquireTime_RBV":
            return 0.050 + 0.010 * math.sin(t / 8.0)
        if pv_name == "7bmSP1:cam1:TemperatureActual":
            return 25.0 + 0.6 * math.sin(t / 10.0)
        if pv_name == "7bmSP1:HDF1:FileNumber_RBV":
            return 1000 + self._tick

        # TomoScan scalars
        if pv_name == "7bmtomo:TomoScan:ScanStatus":
            return "Idle (dummy)" if (self._tick % 8) else "Running (dummy)"
        if pv_name == "7bmtomo:TomoScan:ImagesSaved":
            return 200 + self._tick
        if pv_name == "7bmtomo:TomoScan:RemainingTime":
            return max(0, 300 - 5 * (self._tick % 70))
        if pv_name == "7bmtomo:TomoScan:ServerRunning":
            return "Running" if (self._tick % 6) else "Stopped"

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
    EPICS CA via pyepics PV objects + PVA image via pvaccess.
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
    try:
        return caget_func(pvname, as_string=True, timeout=timeout)
    except TypeError:
        try:
            return caget_func(pvname, as_string=True)
        except TypeError:
            return caget_func(pvname)

def caget_num(caget_func, pvname, timeout=0.3):
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

def _shutter_color_closed_pl(v):
    """
    PV is 'CLOSED pilot light':
      - 1 => closed => red
      - 0 => not closed (open/unknown) => green
    """
    s = str(v).strip()
    return "red" if s in ("1", "1.0", "true", "True") else "green"

def dot_color_for_running(val, mode):
    if val is None:
        return "red"

    if mode == "nonzero_ok":
        try:
            return "green" if float(val) != 0.0 else "red"
        except Exception:
            return "green" if str(val).strip() not in ("0", "0.0", "") else "red"

    s = str(val).strip().lower()
    if s in ("1", "true", "yes", "running", "on", "ok"):
        return "green"
    return "red"

def add_scale_bar(ax, img_shape, um_per_px, bar_um=200.0, margin_px=20, height_px=8):
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

def mode_label_from_inbd_white(pv_value) -> str:
    """
    PB:07BM:INBD_WHITE_SW.VAL:
      - ON / 1 / True / Yes => WHITE
      - anything else       => MONO
    """
    if pv_value is None:
        return "N/A"
    s = str(pv_value).strip().lower()
    if s in ("1", "1.0", "on", "true", "yes"):
        return "WHITE"
    return "MONO"


# ----------------------------
# PV config (7-BM)
# ----------------------------

PV_DISPLAY = {
    "Filter 1": "7bma1:filter1:Position",
    "Filter 2": "7bma1:filter2:Position",
    "Mode": "PB:07BM:INBD_WHITE_SW.VAL",
    "Current": "S:SRcurrentAI.VAL",

    "Shutter A": "PB:07BM:STA_A_FES_CLSD_PL.VAL",
    "Shutter B": "PB:07BM:STA_B_SBS_CLSD_PL.VAL",

    "Image Pixel Size": "7bmtomo:TomoScan:ImagePixelSize",  # µm/px

    "Acquire": "7bmSP1:cam1:Acquire",
    "Exposure": "7bmSP1:cam1:AcquireTime_RBV",
    "Temp.": "7bmSP1:cam1:TemperatureActual",
    "File": "7bmSP1:HDF1:FileNumber_RBV",

    "PVA Image": "7bmSP1:Pva1:Image",

    "Scan Status": "7bmtomo:TomoScan:ScanStatus",
    "Images Saved": "7bmtomo:TomoScan:ImagesSaved",
    "Remaining Time": "7bmtomo:TomoScan:RemainingTime",
    "Server Running": "7bmtomo:TomoScan:ServerRunning",
}


# ----------------------------
# Rendering
# ----------------------------

def render_7bm_dashboard(fig, source, pv, out_png=None):
    caget_func = source.caget

    filt1 = caget_str(caget_func, pv["Filter 1"], timeout=0.3)
    filt2 = caget_str(caget_func, pv["Filter 2"], timeout=0.3)

    mode_raw = caget_str(caget_func, pv["Mode"], timeout=0.3)
    mode = mode_label_from_inbd_white(mode_raw)

    current = caget_num(caget_func, pv["Current"], timeout=0.3)

    sh_a = caget_num(caget_func, pv["Shutter A"], timeout=0.3)
    sh_b = caget_num(caget_func, pv["Shutter B"], timeout=0.3)

    um_per_px = caget_num(caget_func, pv["Image Pixel Size"], timeout=0.3)

    acq = caget_str(caget_func, pv["Acquire"], timeout=0.3)
    exposure = caget_num(caget_func, pv["Exposure"], timeout=0.3)
    temp = caget_num(caget_func, pv["Temp."], timeout=0.3)
    filecount = caget_num(caget_func, pv["File"], timeout=0.3)

    acq_txt = _fmt_str(acq)
    # (3) temperature: no digits after the dot
    temp_txt = "N/A" if temp is None else f"{_fmt_num(temp, 0)} \N{DEGREE SIGN}C"
    # (2) exposure: 2 digits after the dot, no space before 's' (e.g. 0.00s)
    exp_txt = "N/A" if exposure is None else f"{_fmt_num(exposure, 2)}s"
    file_txt = _fmt_num(filecount, 0)

    img = source.pva_image(pv["PVA Image"])

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
    ax_title.text(0.0, 0.7, "7-BM Monitor", fontsize=16, fontweight="bold",
                  color="white", ha="left", va="center")

    # Readouts
    ax_read = fig.add_subplot(gs[1:3, :])
    ax_read.set_axis_off()

    def lcd(ax, x, y, w, h, label, value, color="white"):
        ax.add_patch(Rectangle((x, y), w, h, transform=ax.transAxes,
                               facecolor="black", edgecolor="#555555", linewidth=1.0))
        ax.text(x + w/2, y + h + 0.06, label, transform=ax.transAxes,
                ha="center", va="bottom", fontsize=10, color="white")
        ax.text(x + w/2, y + h/2, value, transform=ax.transAxes,
                ha="center", va="center", fontsize=16, fontweight="bold", color=color)

    # Add more vertical space between rows to prevent overlap
    top_y = 0.58
    bot_y = 0.02
    tile_h = 0.32
    tile_w = 0.32

    # Top row
    lcd(ax_read, 0.00, top_y, tile_w, tile_h, "Filter 1", _fmt_str(filt1), color="cyan")
    lcd(ax_read, 0.34, top_y, tile_w, tile_h, "Filter 2", _fmt_str(filt2), color="cyan")
    lcd(ax_read, 0.68, top_y, tile_w, tile_h, "Mode", _fmt_str(mode), color="white")

    # Bottom row
    lcd(ax_read, 0.00, bot_y, tile_w, tile_h, "Current (mA)", _fmt_num(current, 3), color="yellow")

    # Image snapshot
    ax_img = fig.add_subplot(gs[3:12, :])
    ax_img.set_facecolor("black")
    ax_img.set_xticks([])
    ax_img.set_yticks([])
    ax_img.set_title(
        # (1) remove detector prefix label from title
        f"Acquire: {acq_txt}    Exp.: {exp_txt}    Temp.: {temp_txt}    File: {file_txt}",
        color="white",
        fontsize=11,
    )

    if img is None:
        ax_img.text(
            0.5, 0.5,
            f"No PVA image / parse failed:\n{pv['PVA Image']}",
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

    shutter_button(ax_sh, 0.10, 0.38, "Shutter A", _shutter_color_closed_pl(sh_a))
    shutter_button(ax_sh, 0.52, 0.38, "Shutter B", _shutter_color_closed_pl(sh_b))

    # IOC / Server status panel
    ax_ioc = fig.add_subplot(gs[14:24, :])
    ax_ioc.set_axis_off()
    ax_ioc.add_patch(Rectangle((0, 0), 1, 1, transform=ax_ioc.transAxes,
                               facecolor="#252525", edgecolor="#404040", linewidth=1.0))
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

    # --- Update timestamp at the bottom center ---
    ax_time = fig.add_axes([0, 0, 1, 0.05])  # left, bottom, width, height in figure coords
    ax_time.set_axis_off()
    ax_time.text(
        0.5, 0.5,
        f"Update: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        ha="center", va="center",
        color="#cfcfcf", fontsize=14, fontweight="bold"
    )

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
    parser.add_argument("--out", default="/net/joulefs/coulomb_Public/docroot/tomolog/07bm_monitor.png",
                        help="Output PNG path.")
    parser.add_argument("--period", type=int, default=60,
                        help="Update period in seconds.")
    args = parser.parse_args()

    if not args.view:
        matplotlib.use("Agg")

    source = DummyPVSource() if args.dummy else EpicsPVSource()
    fig = plt.figure(figsize=(6.5, 11.0), dpi=120)

    if args.view:
        while plt.fignum_exists(fig.number):
            source.next_refresh()
            render_7bm_dashboard(fig, source, PV_DISPLAY, out_png=args.out)
            plt.pause(0.1)
            time.sleep(args.period)
    else:
        while True:
            source.next_refresh()
            render_7bm_dashboard(fig, source, PV_DISPLAY, out_png=args.out)
            time.sleep(args.period)


if __name__ == "__main__":
    main()
