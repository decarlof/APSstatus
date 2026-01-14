import tkinter as tk
from tkinter import ttk
import epics
from epics import caget
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)

class PVMonitorApp:
    def __init__(self, root, pv_dict):
        self.root = root
        self.root.title("EPICS PV Monitor")
        self.root.geometry("370x305")  # Adjusted height since bar graphs are removed
        self.root.configure(bg="#2C2F33")  # Dark background

        self.pv_dict = pv_dict  

        self.style = ttk.Style()
        self.style.configure("Treeview", font=("Arial", 12), rowheight=30)
        self.style.configure("Treeview.Heading", font=("Arial", 14, "bold"))

        self.setup_gui()
        self.update_pv_values()

    def setup_gui(self):
        frame = ttk.Frame(self.root, padding=10)
        frame.grid(row=0, column=0, sticky="nsew")

        self.tree = ttk.Treeview(frame, columns=('Display Name', 'Value'), show='headings', height=6)
        self.tree.heading('Display Name', text='Display Name')
        self.tree.heading('Value', text='Value')
        self.tree.column('Display Name', width=200, anchor="center")
        self.tree.column('Value', width=150, anchor="center")
        self.tree.grid(row=0, column=0, columnspan=2, pady=10)

        style = ttk.Style()
        style.configure("Treeview", rowheight=25)
        style.map("Treeview", background=[("selected", "black")])
        self.tree.tag_configure("evenrow", background="#f0f0f0")
        self.tree.tag_configure("oddrow", background="#ffffff")

        EXCLUDED_PVS = {"Shutter A", "Shutter B", "Shutter Q"}

        for index, (display_name, pv_name) in enumerate(self.pv_dict.items()):
            if display_name in EXCLUDED_PVS:
                continue
            tag = "evenrow" if index % 2 == 0 else "oddrow"
            self.tree.insert('', 'end', iid=pv_name, values=(display_name, ''), tags=(tag,))

        # Horizontal layout for shutter indicators
        shutter_frame = ttk.Frame(frame)
        shutter_frame.grid(row=1, column=0, columnspan=2, pady=20)

        def create_shutter_indicator(canvas_attr, update_func, col, label_text):
            canvas = tk.Canvas(shutter_frame, width=30, height=30, highlightthickness=0)
            canvas.grid(row=0, column=col, padx=40)
            setattr(self, canvas_attr, canvas)
            update_func("N/A")
            ttk.Label(shutter_frame, text=label_text, font=("Arial", 10), foreground="black").grid(row=1, column=col)

        create_shutter_indicator("canvas_shutter_a", self.update_shutter_a_dot, 0, "Shutter A")
        create_shutter_indicator("canvas_shutter_b", self.update_shutter_b_dot, 1, "Shutter B")
        create_shutter_indicator("canvas_shutter_q", self.update_shutter_q_dot, 2, "Shutter Q")

    def update_pv_values(self):
        EXCLUDED_PVS = {"Shutter A", "Shutter B", "Shutter Q"}
        for display_name, pv_name in self.pv_dict.items():
            value = caget(pv_name) or "N/A"
            if isinstance(value, (float, int)):
                value = f"{value:.4f}"

            if display_name not in EXCLUDED_PVS and self.tree.exists(pv_name):
                self.tree.item(pv_name, values=(display_name, value))

            if pv_name == "S12BM-PSS:FES:BeamBlockingM":
                self.update_shutter_a_dot(value)
            elif pv_name == "S12BM-PSS:SBS:BeamPresentM":
                self.update_shutter_b_dot(value)
            elif pv_name == "12bmb1:uniblitz:asyn.AOUT":
                self.update_shutter_q_dot(value)

        self.root.after(1000, self.update_pv_values)

    def update_shutter_a_dot(self, value):
        self.canvas_shutter_a.delete("all")
        color = "green" if value == "0.0000" else "red"
        self.canvas_shutter_a.create_oval(5, 5, 25, 25, fill=color, outline=color)

    def update_shutter_b_dot(self, value):
        self.canvas_shutter_b.delete("all")
        color = "green" if value == "1.0000" else "red"
        self.canvas_shutter_b.create_oval(5, 5, 25, 25, fill=color, outline=color)

    def update_shutter_q_dot(self, value):
        self.canvas_shutter_q.delete("all")
        color = "red" if value == "A" else "green"
        self.canvas_shutter_q.create_oval(5, 5, 25, 25, fill=color, outline=color)

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
        "Ring Current": "S:SRcurrentAI.VAL"
    }

    root = tk.Tk()
    app = PVMonitorApp(root, pv_dict)
    root.mainloop()

if __name__ == "__main__":
    main()

