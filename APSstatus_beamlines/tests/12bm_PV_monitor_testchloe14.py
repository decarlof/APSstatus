import sys 
from PyQt5.QtWidgets import (
	QApplication, QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout, QLineEdit, QComboBox, QCheckBox, QGridLayout, QGroupBox, QLCDNumber, QStackedWidget, QFileDialog, QSlider
)
from PyQt5.QtCore import QTimer, Qt
from PyQt5.QtGui import QFont
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
import epics 
from epics import caget 
import math
import matplotlib.patches as mpatches
from matplotlib.patches import Rectangle

class BeamlineMonitor(QWidget):
	def __init__(self):
		super().__init__()
		self.setWindowTitle("12 BM Monitor")
		# was 600 x 1000 01/09/2026
		self.resize(500,900)
		
		self.main_layout = QVBoxLayout()
		
		#Top display (Alarm Light, I0, I1,I2)
		top_layout = QHBoxLayout()
		
		#Alarm light with label above
		self.alarm_light = QPushButton()
		self.alarm_light.setFixedSize(40,40)
		self.alarm_light.setStyleSheet("border: none; border-radius: 20px; background-color: black")
		alarm_label = QLabel("Alarm Light")
		alarm_label.setAlignment(Qt.AlignHCenter)
		
		alarm_layout = QVBoxLayout()
		alarm_layout.setAlignment(Qt.AlignVCenter)
		alarm_layout.addWidget(alarm_label)
		alarm_layout.addWidget(self.alarm_light)
		
		alarm_widget = QWidget()
		alarm_widget.setLayout(alarm_layout)
		top_layout.addWidget(alarm_widget)
		
		# Top of the display (I0, I1, I2 values shown)
		self.i0_display = self.create_lcd_display("I0")
		self.i1_display = self.create_lcd_display("I1")
		self.i2_display = self.create_lcd_display("I2")
		self.deadtime_label = self.create_lcd_display(" Deadtime (%):") 
		top_layout.addWidget(self.i0_display)
		top_layout.addWidget(self.i1_display)
		top_layout.addWidget(self.i2_display)
		top_layout.addWidget(self.deadtime_label)
		
		self.main_layout.addLayout(top_layout)
		
		# initializing the values 
		self.time_vals = []
		self.i0_vals = []
		self.i1_vals = []
		self.i2_vals = []
		self.energy_vals = []
		self.mu01_vals = []
		self.mu12_vals = []
		self.t = 0
		
		self.figures = []
		self.axes = []
		self.canvases = []

		## initializing main plot [mu01, mu12, and flatot vs Energy]
		self.energy_plot_fig = Figure(figsize = (6,5.5))
		self.energy_plot_canvas = FigureCanvas(self.energy_plot_fig)
		self.energy_plot_ax = self.energy_plot_fig.add_subplot(111)
		self.energy_plot_ax2 = self.energy_plot_ax.twinx()
		self.energy_plot_ax.set_title("Transmission & Flourescence")
		self.energy_plot_ax.set_xlabel("Energy (keV)")
		self.energy_plot_ax.set_ylabel("Transmission")
		self.energy_plot_ax2.set_ylabel("Fluorescence")
		self.energy_plot_fig.patch.set_facecolor('whitesmoke')
		self.energy_plot_canvas.setStyleSheet("background-color: whitesmoke")
		
		self.main_layout.addWidget(self.energy_plot_canvas)
		
		
		# Controls section (might delete) 
		controls_layout = QGridLayout()
		#controls_layout.addWidget(QLabel("Spec Server:"), 0, 0)
		#self.server_combo = QComboBox()
		#self.server_combo.addItems(["Navy"])
		#controls_layout.addWidget(self.server_combo, 1, 0)
		
		self.cb_mu01 = QCheckBox("mu01")
		self.cb_mu12 = QCheckBox("mu12")
		self.cb_flatot = QCheckBox("flatot")
		for i, cb in enumerate([self.cb_mu01, self.cb_mu12, self.cb_flatot]):
			cb.setChecked(True)
			controls_layout.addWidget(cb, 0, i+1)
			
		self.main_layout.addLayout(controls_layout)
		
		#Second plot for Mt Output (Bar Graph) 
		self.canvas= FigureCanvas(Figure(figsize = (4,2)))
		middle_layout = QVBoxLayout()
		middle_layout.addWidget(self.canvas)
		
		self.ax = self.canvas.figure.add_subplot(111)
		self.ax.set_xlim(0,70000)
		self.ax.set_ylim(0,1)
		self.ax.get_xaxis().set_visible(False)
		self.ax.get_yaxis().set_visible(False)
		self.canvas.setFixedHeight(120)
		self.ax.set_title('Mostab Output')
		self.green_patch = None
		self.yellow_patch = None
		self.red_patch = None
		self.yellow_two_patch = None
		self.red_two_patch = None
		
		self.canvas.figure.subplots_adjust(top =.78, bottom = .01, left = .00, right = .999)
		self.main_layout.addLayout(middle_layout)
		
		
		self.mt_slider = QSlider(Qt.Horizontal)
		self.mt_slider.setMinimum(0) 
		self.mt_slider.setMaximum(70000)
		self.mt_slider.setStyleSheet("background-color: lightGray")
		self.mt_slider.setFixedHeight(30)
		
		self.mt_slider.setStyleSheet("""
			QSlider:: groove:horizontal {
				border: 1px solid #444;
				height: 10px;
				background: black;
				margin: 0px;
				border-radius: 5px;
			}
		""")
		self.value_text = None
		
		self.main_layout.addWidget(self.mt_slider)
		
		
		
		
		
		# Bottom section read outs (Energy, Ring Current, and Mt)
		readout_layout = QHBoxLayout()
		self.energy_display = self.create_lcd_display("Energy (keV)", color = "cyan")
		#self.slide_display = self.create_lcd_display("Slide at (keV)")
		self.ring_display = self.create_lcd_display("Ring Current", color = "yellow")
		self.mt_output = self.create_lcd_display("Mostab Output", color = "pink")
		self.mt_prefaction = self.create_lcd_display("Mostab Prefaction", color = "green")
		readout_layout.addWidget(self.energy_display)
		#readout_layout.addWidget(self.slide_display)
		readout_layout.addWidget(self.ring_display)
		readout_layout.addWidget(self.mt_output)
		readout_layout.addWidget(self.mt_prefaction)
		self.main_layout.addLayout(readout_layout)
		
		
		# Shutters
		bottom_layout = QGridLayout()
		self.a_shutter = QPushButton("Shutter A")
		self.b_shutter = QPushButton("Shutter B") 
		self.q_shutter = QPushButton("Shutter Q") 
		self.a_shutter.setFixedSize(200,40)
		self.b_shutter.setFixedSize(200,40)
		self.q_shutter.setFixedSize(200,40)
		self.a_shutter.setFont(QFont('Arial', 15))
		self.b_shutter.setFont(QFont('Arial', 15))
		self.q_shutter.setFont(QFont('Arial', 15))
		bottom_layout.addWidget(self.a_shutter, 1, 0)
		bottom_layout.addWidget(self.b_shutter, 1, 1)
		bottom_layout.addWidget(self.q_shutter, 1, 2)
		
		self.main_layout.addLayout(bottom_layout)
		
		self.setLayout(self.main_layout)
		
		# Dictionary of PVs
		self.pv_dict = {
			"Energy": "12bma:EnCalc",
			"Shutter A": "S12BM-PSS:FES:BeamBlockingM",
			"Shutter B": "S12BM-PSS:SBS:BeamPresentM",
			"Shutter Q": "12bmb1:uniblitz:asyn.AOUT",
			"I0": "12bm_panda:POSITIONS:12:VAL",
			"I1": "12bm_panda:POSITIONS:13:VAL",
			"I2": "12bm_panda:POSITIONS:14:VAL",
			"Det DT": "12bm_xsp3:MaxDeadTime_RBV",
			"Ring Current": "S:SRcurrentAI.VAL",
			"Alarm Light": "12bm:BLEPS:ALARM:GREEN",	
			"Mostab Output": "12bmb2:mt_output",
			"Mostab Prefaction": "12bmb2:mt_prefaction",
			"Mostab Setvalue": "12bmb2:mt_setvalue"
	}
		
		#Timer to update data 
		self.timer = QTimer()
		self.timer.timeout.connect(self.update_data)
		self.timer.start(1000)
		
		self.allow_energy_update = False
		self.last_energy_plot_time = -1
	
	#color gradient from red to green for second plot 	
	def show_gradient_background(self):
		self.ax.clear()
		self.ax.set_xlim(0,70000)
		self.ax.set_ylim(0,1)
		self.ax.axis('off')
		self.figure.patch.set_facecolor('black')
		
		self.ax.axhspan(0, 1, xmin=0, xmax= 10000 / 70000, color = 'red', zorder = 0)
		self.ax.axhspan(0, 1, xmin = 10000 / 70000, xmax = 20000 / 70000, color = 'yellow', zorder = 0)
		self.ax.axhspan(0, 1, xmin = 20000 / 70000, xmax = 50000/70000, color = 'green', zorder = 0)
		self.ax.axhspan(0, 1, xmin= 50000/70000, xmax= 60000 / 70000, color = 'yellow', zorder = 0)
		self.ax.axhspan(0, 1, xmin = 60000/ 70000, xmax = 70000 / 70000, color = 'red', zorder = 0)
				
		border = mpatches.Rectangle((0, .3), 50000, .4, linewidth = .1, edgecolor = 'black', facecolor = 'none', zorder = 1)
		
		self.canvas.draw()
    
	## display variables and style 
	def create_lcd_display(self, label, color= "white"):
    		box = QGroupBox(label)
    		vbox = QVBoxLayout()
    		lcd = QLCDNumber()
    		lcd.display(0.0)
    		lcd.setSegmentStyle(QLCDNumber.Flat)
    		lcd.setStyleSheet(f"color: {color}; background-color: black;")
    		lcd.setFont(QFont("Times", 30, QFont.Bold))
    		box.lcd =lcd
    		vbox.addWidget(lcd)
    		box.setLayout(vbox)
    		return box
    	
    	#Update shutter color based on Pv ( 0 = open, 1 = closed) may need to update later	
	def update_shutter_button_a_and_b(self, button, pv_val):
		if pv_val == 0:
    			button.setStyleSheet("background-color: green; color: white")
		else:
    			button.setStyleSheet("background-color: red; color: white")
    	
    	#Update shutter color for Q based on PV ( A = closed, B = open) ( not based on A and B shutter btw)		
	def update_shutter_button_Q(self, button, pv_val):
		if pv_val == "A":
			button.setStyleSheet("background-color: red; color: white")
		else:
			button.setStyleSheet("background-color: green; color: white")
			
    	#updating data for output sections, graphs, shutters, and alarm	
	def update_data(self):
		try:
			alarm_val = caget(self.pv_dict["Alarm Light"])
			if alarm_val == 1:
				self.alarm_light.setStyleSheet("QPushButton {border: black; border-radius: 20px; background-color: green}")
			else: 
				self.alarm_light.setStyleSheet("QPushButton {border: black; border-radius: 20px; background-color: red}")
			
			i0 = caget(self.pv_dict["I0"])
			i1 = caget(self.pv_dict["I1"])
			i2 = caget(self.pv_dict["I2"])
			energy = caget(self.pv_dict["Energy"])
			ring = caget(self.pv_dict["Ring Current"])
			deadtime = caget(self.pv_dict["Det DT"])
			output = caget(self.pv_dict["Mostab Output"])
			prefaction = caget(self.pv_dict["Mostab Prefaction"])
			setvalue = caget(self.pv_dict["Mostab Setvalue"])
			sh_a = caget(self.pv_dict["Shutter A"])
			sh_b = caget(self.pv_dict["Shutter B"])
			sh_q = caget(self.pv_dict["Shutter Q"]) 
			
			if energy <= 0:
				energy_vals = "Error"
			
			if i0 > 0 and i1 > 0:
				mu01 = math.log(i0/ i1)
			else: 
				mu01 = 0
			if i1 > 0 and i2 > 0:
				mu12 = math.log(i1/i2)
			else:
				mu12 = 0				
			
		except Exception as e:
			print(f"Error reading PVs: {e}")
			return 
		
		
		self.time_vals.append(self.t)
		self.i0_vals.append(i0)
		self.i1_vals.append(i1)
		self.i2_vals.append(i2)
		self.t += 1
		
		self.energy_vals.append(energy)
		self.mu01_vals.append(mu01)
		self.mu12_vals.append(mu12)
		

		self.i0_display.lcd.display(i0)
		self.i1_display.lcd.display(i1)
		self.i2_display.lcd.display(i2)
		self.energy_display.lcd.display(energy)
		#self.slide_display.lcd.display(energy)
		self.ring_display.lcd.display(ring)
		self.deadtime_label.lcd.display(deadtime)
		self.mt_output.lcd.display(output)
		self.mt_prefaction.lcd.display(prefaction)
		
		self.update_shutter_button_a_and_b(self.a_shutter, sh_a)
		self.update_shutter_button_a_and_b(self.b_shutter, sh_b)
		self.update_shutter_button_Q(self.q_shutter, sh_q)

		#main graph showing mu01 and mu12 values 	
		shutters_open = all([
			str(sh_a).strip() in ['1', 1],
			str(sh_b).strip() in ['1', 1],
			str(sh_q).strip() != 'A'
		])
		
		if not hasattr(self, '_graph_cleared_on_open'):
			self._graph_cleared_on_open = False 
			

				
		if shutters_open:
			if not self._graph_cleared_on_open:
				energy_plot_ax = self.energy_plot_ax
				energy_plot_canvas = self.energy_plot_canvas
				self.energy_plot_ax.clear()
				energy_plot_ax.set_facecolor('black')
				self.energy_plot_canvas.draw()
				self._graph_cleared_on_open = True
				self.allow_energy_update = True 
				self.last_energy_plot_time = self.t
				self._graph_cleared_on_open
			else:
				self.allow_energy_update = False
				
			if self.allow_energy_update:
				updated = False
				if self.cb_mu01.isChecked():
					energy_plot_ax.plot(self.energy_vals, self.mu01_vals, label = "mu01", color = "magenta")
					updated = True
				if self.cb_mu12.isChecked():
					energy_plot_ax.plot(self.energy_vals, self.mu12_vals, label = "mu12", color = "cyan")
					updated = True
				if updated:
					energy_plot_ax.set_title("Transmission & Fluorescence")
					energy_plot_ax.set_xlabel("Energy (keV)")
					energy_plot_ax.set_ylabel("Transmission")
					energy_plot_ax.legend()
					self.energy_plot_canvas.draw()	
			else:
				self.allow_energy_update = False
				self._graph_cleared_on_open = False
				
		if sh_a == '0':
			self.energy_plot_ax.clear()
			self.energy_vals = []
			self.mu01_vals = []
			self.mu12_vals = []
		if sh_b == '0':
			self.energy_plot_ax.clear()
			self.energy_vals = []
			self.mu01_vals = []
			self.mu12_vals = []
		if sh_q == 'A':
			self.energy_plot_ax.clear()
			self.energy_vals = []
			self.mu01_vals = []
			self.mu12_vals = []
			
			
		#second plot for mt output (might need to change thresholds for red, yellow, and green) 
		value = caget(self.pv_dict["Mostab Output"])
		if value is None or math.isnan(value):
			value = 0
		value = min(max(value, 0), 70000)
		
		if self.green_patch:
			self.green_patch.remove()
		if self.yellow_patch:
			self.yellow_patch.remove()
		if self.red_patch:
			self.red_patch.remove()
		if self.red_two_patch:
			self.red_two_patch.remove()
		if self.yellow_two_patch:
			self.yellow_two_patch.remove()
				
		red_limit = min(value, 10000)
		yellow_limit = min(max(value - 10000, 0), 20000)
		green_limit = min(max(value-20000, 0), 50000)
		yellow_two_limit = min(max(value-50000, 0), 60000)
		red_two_limit = min(max(value-60000, 0), 70000)
		
		self.red_patch = mpatches.Rectangle((0, .25), red_limit, .5, color = 'red', zorder =2)
		self.yellow_patch = mpatches.Rectangle((10000, .25), yellow_limit, .5, color = 'yellow', zorder =2)
		self.green_patch = mpatches.Rectangle((20000, .25), green_limit, .5, color = 'green', zorder =2)
		self.yellow_two_patch = mpatches.Rectangle((50000, .25), yellow_two_limit, .5, color = 'yellow', zorder = 2)
		self.red_two_patch = mpatches.Rectangle((60000, .25), red_two_limit, .5, color = 'red', zorder = 2)
		
		self.ax.add_patch(self.red_patch)
		self.ax.add_patch(self.yellow_patch)
		self.ax.add_patch(self.green_patch)
		self.ax.add_patch(self.yellow_two_patch)
		self.ax.add_patch(self.red_two_patch)
		
		if hasattr(self, 'value_text') and self.value_text:
			self.value_text.remove()
			
		self.value_text = self.ax.text(
			value + 500, 
			5,
			f"{value: .1f}",
			va = 'center',
			ha = 'left',
			fontsize = 10,
			color = 'white',
			weight = 'bold',
			zorder = 1
		)
		
		self.ax.set_facecolor('black')
		
		self.canvas.draw()
		
		# horizontal slider for mostab setvalue
		mt_set_value = caget(self.pv_dict["Mostab Setvalue"])
		if mt_set_value is None or math.isnan(mt_set_value):
			mt_set_value = 0
		mt_set_value = min(max(mt_set_value, 0), 70000)
		
		self.mt_slider.setValue(int(mt_set_value))
		
if __name__ == '__main__':
	app = QApplication(sys.argv)
	window = BeamlineMonitor()
	window.show()
	sys.exit(app.exec())
