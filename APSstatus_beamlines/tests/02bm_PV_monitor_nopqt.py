# matplotlib_dashboard_tk_replacement.py
#
# Matplotlib-only "dashboard" version of your first Tkinter PV monitor.
# Headless-friendly: produces a PNG once per minute (or run interactively).
#
# No tkinter, no PyQt5, no EPICS required (dummy PVs included).

import time
import math
from datetime import datetime

import matplotlib
matplotlib.use("Agg")  # headless backend
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle


class DummyPVSource:
    """Dummy PV generator with values that change over time."""
    def __init__(self):
        self.t0 = time.time()

    def caget(self, pv_name):
        t = time.time() - self.t0

        if pv_name == "12bma:EnCalc":
            return 12.0 + 0.5 * math.sin(t / 3)

        if pv_name == "12bm_panda:POSITIONS:12:VAL":  # I0
            return 1000 + 80 * math.sin(t / 2.0)
        if pv_name == "12bm_panda:POSITIONS:13:VAL":  # I1
            return 900 + 70 * math.sin(t / 2.2)
        if pv_name == "12bm_panda:POSITIONS:14:VAL":  # I2
            return 800 + 60 * math.sin(t / 2.5)

        if pv_name == "12bm_xsp3:MaxDeadTime_RBV":
            return 10 + 5 * (0.5 + 0.5 * math.sin(t / 4.0))

        if pv_name == "S:SRcurrentAI.VAL":
            return 100.0 + 2.0 * math.sin(t / 5.0)

        # Shutters: match your original color logic
        # Shutter A green if value == 0.0000 else red
        if pv_name == "S12BM-PSS:FES:BeamBlockingM":
            return 0.0 if int(t) % 12 < 9 else 1.0

        # Shutter B green if value == 1.0000 else red
        if pv_name == "S12BM-PSS:SBS:BeamPresentM":
            return 1.0 if int(t) % 12 < 9 else 0.0

        # Shutter Q red if "A" else green
        if pv_name == "12bmb1:uniblitz:asyn.AOUT":
            return "A" if int(t) % 12 < 3 else "B"

        return None


def shutter_color_a(val_str):
    return "green" if val_str == "0.0000" else "red"


def shutter_color_b(val_str):
    return "green" if val_str == "1.0000" else "red"


def shutter_color_q(val_str):
    return "red" if val_str == "A" else "green"


def format_value(v):
    if v is None:
        return "N/A"
    if isinstance(v, (int, float)):
        return f"{v:.4f}"
    return str(v)


def render_dashboard_png(pv_dict, caget_func, out_png="pv_monitor.png"):
    """
    Render a single dashboard PNG in a Matplotlib figure.
    """
    excluded = {"Shutter A", "Shutter B", "Shutter Q"}

    # --- Collect values ---
    rows = []
    shutter_vals = {}
    for display_name, pv_name in pv_dict.items():
        v = caget_func(pv_name)
        vs = format_value(v)

        if display_name in excluded:
            shutter_vals[display_name] = vs
        else:
            rows.append((display_name, vs))

    # Provide defaults if missing
    sh_a = shutter_vals.get("Shutter A", "N/A")
    sh_b = shutter_vals.get("Shutter B", "N/A")
    sh_q = shutter_vals.get("Shutter Q", "N/A")

    # --- Figure setup (roughly matching your Tk geometry) ---
    # 370x305 px -> with dpi=100 => 3.70 x 3.05 inches
    dpi = 100
    fig = plt.figure(figsize=(3.70, 3.05), dpi=dpi, facecolor="#2C2F33")
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_axis_off()

    # Title
    ax.text(
        0.5, 0.95, "EPICS PV Monitor",
        ha="center", va="center",
        fontsize=13, fontweight="bold",
        color="white"
    )

    # Timestamp
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ax.text(0.5, 0.905, ts, ha="center", va="center", fontsize=8.5, color="#D0D0D0")

    # --- Table area ---
    left = 0.06
    right = 0.94
    top = 0.84
    bottom = 0.30

    # Header background
    ax.add_patch(Rectangle((left, top), right - left, 0.06, facecolor="#1F2226", edgecolor="none"))
    ax.text(left + 0.28, top + 0.03, "Display Name", ha="center", va="center",
            fontsize=10.5, fontweight="bold", color="white")
    ax.text(left + 0.74, top + 0.03, "Value", ha="center", va="center",
            fontsize=10.5, fontweight="bold", color="white")

    # Rows
    n = max(len(rows), 1)
    row_h = (top - bottom) / n

    for i, (name, val) in enumerate(rows):
        y0 = top - (i + 1) * row_h
        bg = "#f0f0f0" if i % 2 == 0 else "#ffffff"
        ax.add_patch(Rectangle((left, y0), right - left, row_h, facecolor=bg, edgecolor="#DDDDDD", linewidth=0.5))

        ax.text(left + 0.28, y0 + row_h / 2, name, ha="center", va="center", fontsize=9.8, color="black")
        ax.text(left + 0.74, y0 + row_h / 2, val, ha="center", va="center", fontsize=9.8, color="black")

    # Vertical separator line between columns
    sep_x = left + 0.56 * (right - left)
    ax.plot([sep_x, sep_x], [bottom, top + 0.06], color="#DDDDDD", linewidth=0.8)

    # --- Shutter indicators (3 dots) ---
    shutter_y = 0.17
    cols_x = [0.22, 0.50, 0.78]

    colors = [
        shutter_color_a(sh_a),
        shutter_color_b(sh_b),
        shutter_color_q(sh_q),
    ]
    labels = ["Shutter A", "Shutter B", "Shutter Q"]
    vals = [sh_a, sh_b, sh_q]

    for x, c, lab, v in zip(cols_x, colors, labels, vals):
        ax.add_patch(Circle((x, shutter_y + 0.03), 0.035, facecolor=c, edgecolor=c))
        ax.text(x, shutter_y - 0.02, lab, ha="center", va="center", fontsize=9, color="white")
        ax.text(x, shutter_y - 0.06, f"({v})", ha="center", va="center", fontsize=8, color="#D0D0D0")

    fig.savefig(out_png, bbox_inches="tight", pad_inches=0.02)
    plt.close(fig)


def main():
    pv_dict = {
        "Energy (keV)": "12bma:EnCalc",
        "Shutter A": "S12BM-PSS:FES:BeamBlockingM",
        "Shutter B": "S12BM-PSS:SBS:BeamPresentM",
        "Shutter Q": "12bmb1:uniblitz:asyn.AOUT",
        "I0": "12bm_panda:POSITIONS:12:VAL",
        "I1": "12bm_panda:POSITIONS:13:VAL",
        "I2": "12bm_panda:POSITIONS:14:VAL",
        "Det DT (%)": "12bm_xsp3:MaxDeadTime_RBV",
        "Ring Current": "S:SRcurrentAI.VAL",
    }

    dummy = DummyPVSource()

    # Write one PNG per minute forever
    while True:
        render_dashboard_png(pv_dict, dummy.caget, out_png="pv_monitor.png")
        time.sleep(5)


if __name__ == "__main__":
    main()
