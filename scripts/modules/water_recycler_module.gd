# scripts/modules/water_recycler_module.gd
extends ModularInventoryBase
class_name WaterRecyclerModule

# Water recycler-specific signals
signal processing_progress_updated(progress: float)
signal filter_durability_changed(current: int, max: int)
signal processing_mode_changed(auto_mode: bool)

# Water recycler-specific exports
@export var water_recycler_ui_scene: PackedScene

# Processing state
var processing_active := false
var auto_processing_mode := true
var processing_timer: float = 0.0
var total_processing_time: float = GameConstants.WATER_PROCESSING_TIME
var current_filter_durability: int = 0
var max_filter_durability: int = GameConstants.FILTER_DURABILITY

func _get_default_inventory_size() -> int:
	"""Water recycler has 3 slots (input, filter, output)"""
	return GameConstants.WATER_RECYCLER_SLOTS

func _get_ui_scene() -> PackedScene:
	"""Use water recycler-specific UI scene if provided"""
	return water_recycler_ui_scene if water_recycler_ui_scene else ui_scene

func _should_use_power() -> bool:
	"""Water recycler uses power when processing"""
	return true

func _get_power_configuration() -> Dictionary:
	"""Configure water recycler power settings"""
	return {
		"idle": 0.0,  # No idle power draw
		"active": GameConstants.WATER_RECYCLER_POWER_CONSUMPTION,  # 200 PU/sec when processing
		"efficiency": false  # No efficiency control (critical life support)
	}

func _post_setup():
	"""Water recycler-specific initialization"""
	super._post_setup()
	print("Water Recycler initialized - Auto mode: %s" % auto_processing_mode)

func _process(delta: float):
	super._process(delta)
	_handle_processing(delta)
	
	# Check for auto-processing start conditions
	if auto_processing_mode and not processing_active:
		_try_start_auto_processing()

func _handle_processing(delta: float):
	"""Handle water processing logic"""
	if not processing_active:
		return
	
	# Check if we still have power
	if not has_power():
		_pause_processing()
		print("Water processing paused: insufficient power")
		return
	
	# Check if we still have materials
	if not _validate_processing_materials():
		_stop_processing()
		print("Water processing stopped: missing materials")
		return
	
	processing_timer += delta
	var progress = processing_timer / total_processing_time
	
	if is_ui_open():
		processing_progress_updated.emit(progress)
	
	if processing_timer >= total_processing_time:
		_complete_processing()

func _on_interaction_requested():
	"""Handle interaction requests"""
	if processing_active:
		print("Water recycler is processing... Cannot access while active.")
		return
	
	super._on_interaction_requested()

func _on_power_availability_changed(has_power_available: bool):
	"""Handle power availability changes"""
	if processing_active and not has_power_available:
		_pause_processing()
		print("Water processing paused: insufficient power")
	elif not processing_active and has_power_available and _can_start_processing():
		if auto_processing_mode:
			_try_start_auto_processing()

func _on_slot_updated(index: int):
	"""Handle inventory slot updates"""
	super._on_slot_updated(index)
	
	# Update filter durability display when filter slot changes
	if index == GameConstants.WATER_RECYCLER_FILTER_SLOT:
		_update_filter_durability()
	
	# Try auto-processing when inventory changes
	if auto_processing_mode and not processing_active:
		_try_start_auto_processing()

# ------------------------------------------------------------------
# PROCESSING METHODS
# ------------------------------------------------------------------

func start_manual_processing():
	"""Start water processing manually (called by UI)"""
	if processing_active:
		print("Already processing water")
		return
	
	if not _can_start_processing():
		print("Cannot start processing: missing requirements")
		return
	
	_start_processing()

func stop_processing():
	"""Stop water processing (called by UI or system)"""
	if processing_active:
		_stop_processing()

func set_auto_processing_mode(auto_mode: bool):
	"""Set automatic processing mode"""
	auto_processing_mode = auto_mode
	processing_mode_changed.emit(auto_processing_mode)
	print("Water recycler auto mode: %s" % ("ON" if auto_mode else "OFF"))
	
	# Try to start processing if switching to auto mode
	if auto_mode and not processing_active:
		_try_start_auto_processing()

func _try_start_auto_processing():
	"""Try to start processing automatically if conditions are met"""
	if auto_processing_mode and _can_start_processing():
		_start_processing()

func _can_start_processing() -> bool:
	"""Check if processing can start"""
	return (has_power() and 
			_validate_processing_materials() and 
			_has_output_space())

func _validate_processing_materials() -> bool:
	"""Check if we have dirty water and a usable filter"""
	var dirty_water = get_item(GameConstants.WATER_RECYCLER_INPUT_SLOT)
	var filter_item = get_item(GameConstants.WATER_RECYCLER_FILTER_SLOT)
	
	# Need dirty water
	if dirty_water.is_empty():
		return false
	
	var dirty_water_id = dirty_water.get("id", "")
	if dirty_water_id != "dirty_water":
		return false
	
	# Need a filter with durability (fresh or partially used)
	if filter_item.is_empty():
		return false
	
	var filter_id = filter_item.get("id", "")
	if filter_id != "water_filter":
		return false  # Only fresh filters can process water
	
	# Check filter durability
	var filter_uses = filter_item.get("filter_uses", 0)
	return filter_uses < max_filter_durability

func _has_output_space() -> bool:
	"""Check if output slot has space for clean water"""
	var clean_water_slot = get_item(GameConstants.WATER_RECYCLER_OUTPUT_SLOT)
	
	# Check clean water output space
	if clean_water_slot.is_empty():
		return true
	
	var clean_water_id = clean_water_slot.get("id", "")
	if clean_water_id == "clean_water" and clean_water_slot.get("quantity", 0) < GameConstants.MAX_STACK_SIZE:
		return true
	
	return false

func _start_processing():
	"""Start the water processing operation"""
	processing_active = true
	processing_timer = 0.0
	set_power_active(true)
	print("Water processing started")

func _pause_processing():
	"""Pause processing (due to power loss)"""
	if processing_active:
		set_power_active(false)
		print("Water processing paused")

func _stop_processing():
	"""Stop processing completely"""
	processing_active = false
	processing_timer = 0.0
	set_power_active(false)
	print("Water processing stopped")

func _complete_processing():
	"""Complete the water processing cycle"""
	# Consume dirty water
	var dirty_water = get_item(GameConstants.WATER_RECYCLER_INPUT_SLOT)
	dirty_water["quantity"] -= 1
	if dirty_water["quantity"] <= 0:
		remove_item(GameConstants.WATER_RECYCLER_INPUT_SLOT)
	else:
		add_item(GameConstants.WATER_RECYCLER_INPUT_SLOT, dirty_water)
	
	# Add clean water to output
	var clean_water_slot = get_item(GameConstants.WATER_RECYCLER_OUTPUT_SLOT)
	if clean_water_slot.is_empty():
		add_item(GameConstants.WATER_RECYCLER_OUTPUT_SLOT, {
			"id": "clean_water",
			"quantity": 1
		})
	else:
		clean_water_slot["quantity"] += 1
		add_item(GameConstants.WATER_RECYCLER_OUTPUT_SLOT, clean_water_slot)
	
	# Use filter and potentially convert to used filter
	var filter_item = get_item(GameConstants.WATER_RECYCLER_FILTER_SLOT)
	var filter_uses = filter_item.get("filter_uses", 0) + 1
	
	# Check if filter breaks
	if filter_uses >= max_filter_durability:
		# Convert filter to used filter in the same slot
		add_item(GameConstants.WATER_RECYCLER_FILTER_SLOT, {
			"id": "used_filter",
			"quantity": 1
		})
		print("Water filter used up - converted to used filter")
	else:
		# Update filter with new usage
		filter_item["filter_uses"] = filter_uses
		add_item(GameConstants.WATER_RECYCLER_FILTER_SLOT, filter_item)
	
	# Update filter durability display
	_update_filter_durability()
	
	# Reset processing state
	processing_active = false
	processing_timer = 0.0
	set_power_active(false)
	
	print("Water processing completed - 1 clean water produced")
	
	# Try to start next cycle if in auto mode
	if auto_processing_mode:
		call_deferred("_try_start_auto_processing")

func _update_filter_durability():
	"""Update filter durability tracking and emit signal"""
	var filter_item = get_item(GameConstants.WATER_RECYCLER_FILTER_SLOT)
	if filter_item.is_empty():
		current_filter_durability = 0
	else:
		var filter_id = filter_item.get("id", "")
		if filter_id == "water_filter":
			var filter_uses = filter_item.get("filter_uses", 0)
			current_filter_durability = max_filter_durability - filter_uses
		elif filter_id == "used_filter":
			current_filter_durability = 0  # Used filter has no durability
		else:
			current_filter_durability = 0  # Unknown item
	
	filter_durability_changed.emit(current_filter_durability, max_filter_durability)

# ------------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------------

func get_processing_progress() -> float:
	"""Get current processing progress (0.0 to 1.0)"""
	if not processing_active:
		return 0.0
	return processing_timer / total_processing_time

func is_water_processing() -> bool:
	"""Check if currently processing water"""
	return processing_active

func is_auto_mode() -> bool:
	"""Check if in automatic processing mode"""
	return auto_processing_mode

func get_filter_durability() -> Dictionary:
	"""Get filter durability information"""
	return {
		"current": current_filter_durability,
		"max": max_filter_durability,
		"percentage": (float(current_filter_durability) / float(max_filter_durability)) * 100.0 if max_filter_durability > 0 else 0.0
	}
