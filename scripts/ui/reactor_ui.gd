# scripts/ui/reactor_ui.gd
extends Control
class_name ReactorUI

# UI Elements
@export var power_level_label: Label
@export var generation_rate_label: Label
@export var consumption_rate_label: Label
@export var net_flow_label: Label
@export var time_estimate_label: Label
@export var component_breakdown_container: VBoxContainer
@export var power_progress_bar: ProgressBar

var module_ref: ReactorModule = null
var update_timer: float = 0.0
var update_interval: float = 0.1  # Update UI 10 times per second

func _ready():
	visible = true
	
	# Connect to PowerManager signals for live updates
	if PowerManager:
		if not PowerManager.power_level_changed.is_connected(_on_power_level_changed):
			PowerManager.power_level_changed.connect(_on_power_level_changed)
		if not PowerManager.total_consumption_changed.is_connected(_on_consumption_changed):
			PowerManager.total_consumption_changed.connect(_on_consumption_changed)
		if not PowerManager.power_generation_changed.is_connected(_on_generation_changed):
			PowerManager.power_generation_changed.connect(_on_generation_changed)
	
	_update_all_displays()

func _process(delta: float):
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_dynamic_info()

func set_module_ref(module: ReactorModule):
	module_ref = module
	_update_all_displays()

func _on_power_level_changed(current_power: float, max_power: float):
	"""Update power level display when power changes"""
	if power_level_label:
		power_level_label.text = "Power: %.0f / %.0f PU (%.1f%%)" % [
			current_power, 
			max_power, 
			(current_power / max_power) * 100.0
		]
	
	if power_progress_bar:
		power_progress_bar.value = (current_power / max_power) * 100.0
		
		# Color code the progress bar
		var percentage = (current_power / max_power) * 100.0
		if percentage <= 10.0:
			power_progress_bar.modulate = Color.RED
		elif percentage <= 25.0:
			power_progress_bar.modulate = Color.ORANGE
		else:
			power_progress_bar.modulate = Color.GREEN

func _on_consumption_changed(consumption: float):
	"""Update consumption display when total consumption changes"""
	if consumption_rate_label:
		consumption_rate_label.text = "Consumption: %.1f PU/s" % consumption

func _on_generation_changed(generation: float):
	"""Update generation display when generation rate changes"""
	if generation_rate_label:
		generation_rate_label.text = "Generation: %.1f PU/s" % generation

func _update_dynamic_info():
	"""Update dynamic information that changes frequently"""
	if not PowerManager:
		return
	
	var power_info = PowerManager.get_power_info()
	
	# Update net flow
	if net_flow_label:
		var net_flow = power_info.get("net_flow", 0.0)
		var flow_text = ""
		if net_flow > 0:
			flow_text = "Net: +%.1f PU/s (Charging)" % net_flow
			net_flow_label.modulate = Color.GREEN
		elif net_flow < 0:
			flow_text = "Net: %.1f PU/s (Draining)" % net_flow
			net_flow_label.modulate = Color.RED
		else:
			flow_text = "Net: 0.0 PU/s (Balanced)"
			net_flow_label.modulate = Color.YELLOW
		
		net_flow_label.text = flow_text
	
	# Update time estimates
	if time_estimate_label:
		var time_until_empty = power_info.get("time_until_empty", -1.0)
		var time_until_full = power_info.get("time_until_full", -1.0)
		
		var time_text = ""
		if time_until_empty > 0:
			time_text = "Empty in: %s" % _format_time(time_until_empty)
		elif time_until_full > 0:
			time_text = "Full in: %s" % _format_time(time_until_full)
		else:
			time_text = "Time: Stable"
		
		time_estimate_label.text = time_text

func _update_all_displays():
	"""Update all UI displays"""
	if not PowerManager:
		return
	
	var power_info = PowerManager.get_power_info()
	
	_on_power_level_changed(power_info.get("current_power", 0.0), power_info.get("max_power", 1.0))
	_on_consumption_changed(power_info.get("total_consumption", 0.0))
	_on_generation_changed(power_info.get("generation_rate", 0.0))
	_update_component_breakdown()

func _update_component_breakdown():
	"""Update the component power breakdown display"""
	if not component_breakdown_container or not PowerManager:
		return
	
	# Clear existing breakdown
	for child in component_breakdown_container.get_children():
		child.queue_free()
	
	var breakdown = PowerManager.get_component_power_breakdown()
	
	# Add header
	var header = Label.new()
	header.text = "Component Power Usage:"
	header.add_theme_style_override("font_size", 14)
	component_breakdown_container.add_child(header)
	
	# Add component entries
	for component_info in breakdown:
		var component_label = Label.new()
		var name = component_info.get("component_name", "Unknown")
		var draw = component_info.get("current_draw", 0.0)
		var status = "Active" if component_info.get("is_active", false) else "Idle"
		
		component_label.text = "  %s: %.1f PU/s (%s)" % [name, draw, status]
		component_breakdown_container.add_child(component_label)
	
	# Add total
	var total_label = Label.new()
	var power_info = PowerManager.get_power_info()
	total_label.text = "Total: %.1f PU/s" % power_info.get("total_consumption", 0.0)
	total_label.modulate = Color.CYAN
	component_breakdown_container.add_child(total_label)

func _format_time(seconds: float) -> String:
	"""Format time in seconds to a readable string"""
	if seconds < 60:
		return "%.0fs" % seconds
	elif seconds < 3600:
		return "%.1fm" % (seconds / 60.0)
	else:
		return "%.1fh" % (seconds / 3600.0)
