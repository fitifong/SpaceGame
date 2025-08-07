# scripts/ui/water_recycler_ui.gd
extends ItemContainerUI
class_name WaterRecyclerUI

# UI Elements
@export var input_slot: Button  # Dirty water
@export var filter_slot: Button  # Water filter (becomes used filter)
@export var output_slot: Button  # Clean water

@export var process_button: Button  # Manual process button
@export var auto_mode_toggle: CheckBox  # Auto processing toggle
@export var progress_bar: ProgressBar  # Processing progress
@export var status_label: Label  # Current status
@export var filter_durability_bar: ProgressBar  # Filter wear
@export var filter_durability_label: Label  # Filter durability text
@export var power_status_label: Label  # Power availability

var module_ref: WaterRecyclerModule = null

func _ready():
	add_to_group("interactable_ui")
	slot_type_map = {
		GameConstants.WATER_RECYCLER_INPUT_SLOT: "input",
		GameConstants.WATER_RECYCLER_FILTER_SLOT: "filter", 
		GameConstants.WATER_RECYCLER_OUTPUT_SLOT: "output"
	}
	super._ready()
	visible = true
	
	# Connect UI signals
	if process_button:
		process_button.pressed.connect(_on_process_pressed)
	if auto_mode_toggle:
		auto_mode_toggle.toggled.connect(_on_auto_mode_toggled)
	
	_update_ui_state()

func set_module_ref(module: WaterRecyclerModule) -> void:
	module_ref = module
	inventory_data_ref = module
	
	# Connect to module signals
	if module_ref.has_signal("processing_progress_updated"):
		if not module_ref.processing_progress_updated.is_connected(_on_processing_progress_updated):
			module_ref.processing_progress_updated.connect(_on_processing_progress_updated)
	
	if module_ref.has_signal("filter_durability_changed"):
		if not module_ref.filter_durability_changed.is_connected(_on_filter_durability_changed):
			module_ref.filter_durability_changed.connect(_on_filter_durability_changed)
	
	if module_ref.has_signal("processing_mode_changed"):
		if not module_ref.processing_mode_changed.is_connected(_on_processing_mode_changed):
			module_ref.processing_mode_changed.connect(_on_processing_mode_changed)
	
	# Connect to PowerManager for live power updates
	if PowerManager:
		if not PowerManager.power_level_changed.is_connected(_on_power_level_changed):
			PowerManager.power_level_changed.connect(_on_power_level_changed)
	
	_update_ui_state()
	_update_filter_durability()
	_update_power_status()

func _on_processing_progress_updated(progress: float):
	"""Update processing progress display"""
	if progress_bar:
		progress_bar.value = progress * 100.0
		progress_bar.visible = progress > 0.0
	
	_update_status_display()

func _on_filter_durability_changed(current: int, max_durability: int):
	"""Update filter durability display"""
	if filter_durability_bar:
		var percentage = (float(current) / float(max_durability)) * 100.0 if max_durability > 0 else 0.0
		filter_durability_bar.value = percentage
		
		# Color code the durability bar
		if percentage <= 10.0:
			filter_durability_bar.modulate = Color.RED
		elif percentage <= 30.0:
			filter_durability_bar.modulate = Color.ORANGE
		else:
			filter_durability_bar.modulate = Color.GREEN
	
	if filter_durability_label:
		filter_durability_label.text = "Filter: %d/%d uses" % [current, max_durability]

func _on_processing_mode_changed(auto_mode: bool):
	"""Update auto mode toggle"""
	if auto_mode_toggle and auto_mode_toggle.button_pressed != auto_mode:
		auto_mode_toggle.button_pressed = auto_mode
	
	_update_ui_state()

func _on_power_level_changed(_current_power: float, _max_power: float):
	"""Update power status when power levels change"""
	_update_power_status()

func _on_process_pressed():
	"""Handle manual process button press"""
	if not module_ref:
		return
	
	if module_ref.is_water_processing():
		module_ref.stop_processing()
	else:
		module_ref.start_manual_processing()

func _on_auto_mode_toggled(toggled_on: bool):
	"""Handle auto mode toggle"""
	if module_ref:
		module_ref.set_auto_processing_mode(toggled_on)

func update_slot(index: int) -> void:
	super.update_slot(index)
	
	# Update UI state when inventory changes
	_update_ui_state()
	
	# Update filter durability when filter slot changes
	if index == GameConstants.WATER_RECYCLER_FILTER_SLOT:
		_update_filter_durability()

func _get_module_item(index: int) -> Dictionary:
	return module_ref.inventory.get_item(index) if module_ref else {}

func _get_module_inventory_size() -> int:
	return module_ref.inventory.inventory_size if module_ref else 0

func _update_ui_state():
	"""Update all UI elements based on current state"""
	if not module_ref:
		return
	
	var is_processing = module_ref.is_water_processing()
	var auto_mode = module_ref.is_auto_mode()
	var can_process = module_ref._can_start_processing() if module_ref.has_method("_can_start_processing") else false
	
	# Update process button
	if process_button:
		if auto_mode:
			process_button.disabled = true
			process_button.text = "Auto Mode"
		else:
			process_button.disabled = false
			if is_processing:
				process_button.text = "Stop"
				process_button.modulate = Color.RED
			else:
				process_button.text = "Process"
				process_button.modulate = Color.GREEN if can_process else Color.GRAY
	
	# Update auto mode toggle
	if auto_mode_toggle and auto_mode_toggle.button_pressed != auto_mode:
		auto_mode_toggle.button_pressed = auto_mode
	
	_update_status_display()

func _update_status_display():
	"""Update the status label"""
	if not status_label or not module_ref:
		return
	
	var status_text = ""
	
	if module_ref.is_water_processing():
		var progress = module_ref.get_processing_progress()
		status_text = "Processing... %.0f%%" % (progress * 100.0)
		status_label.modulate = Color.CYAN
	elif module_ref.is_auto_mode():
		if module_ref._can_start_processing():
			status_text = "Auto Mode - Ready"
			status_label.modulate = Color.GREEN
		else:
			status_text = "Auto Mode - Waiting"
			status_label.modulate = Color.YELLOW
	else:
		status_text = "Manual Mode - Idle"
		status_label.modulate = Color.WHITE
	
	# Add power status if no power
	if not module_ref.has_power():
		status_text += " (No Power)"
		status_label.modulate = Color.RED
	
	status_label.text = status_text

func _update_filter_durability():
	"""Update filter durability display"""
	if not module_ref:
		return
	
	var filter_info = module_ref.get_filter_durability()
	_on_filter_durability_changed(filter_info.current, filter_info.max)

func _update_power_status():
	"""Update power availability status"""
	if not power_status_label or not module_ref:
		return
	
	if module_ref.has_power():
		power_status_label.text = "Power: Available"
		power_status_label.modulate = Color.GREEN
	else:
		power_status_label.text = "Power: Insufficient"
		power_status_label.modulate = Color.RED

func _on_slot_gui_input(event: InputEvent, slot: Button):
	# Prevent dragging from output slot
	var slot_index = _get_slot_index_from_button(slot)
	if slot_index == GameConstants.WATER_RECYCLER_OUTPUT_SLOT:
		if event is InputEventMouseButton and event.pressed:
			return
	
	super._on_slot_gui_input(event, slot)

func _get_slot_index_from_button(button: Button) -> int:
	"""Helper to get slot index from button reference"""
	if button == input_slot:
		return GameConstants.WATER_RECYCLER_INPUT_SLOT
	elif button == filter_slot:
		return GameConstants.WATER_RECYCLER_FILTER_SLOT
	elif button == output_slot:
		return GameConstants.WATER_RECYCLER_OUTPUT_SLOT
	return -1
