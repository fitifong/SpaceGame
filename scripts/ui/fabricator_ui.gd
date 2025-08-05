# scripts/ui/fabricator_ui.gd
extends ItemContainerUI
class_name FabricatorUI

@export var input_slots: Array[Button] = []
@export var output_slot: Button
@export var make_button: Button
@export var recipe_selector: OptionButton
@export var quantity_spinbox: SpinBox
@export var preview_time_label: Label
@export var progress_bar: ProgressBar

# Power control UI elements
@export var power_efficiency_slider: HSlider
@export var power_efficiency_label: Label
@export var power_consumption_label: Label
@export var power_status_label: Label

var module_ref: FabricatorModule = null
var current_recipe: FabricatorRecipe = null
var available_recipes: Array[FabricatorRecipe] = []
var is_showing_preview := false

func _ready():
	add_to_group("interactable_ui")
	slot_type_map = {3: "output"}
	super._ready()
	visible = true

	if make_button:
		make_button.pressed.connect(_on_make_pressed)
	if recipe_selector:
		recipe_selector.item_selected.connect(_on_recipe_selected)
	if quantity_spinbox:
		quantity_spinbox.value_changed.connect(_on_quantity_changed)
	
	# Connect power control signals
	if power_efficiency_slider:
		power_efficiency_slider.value_changed.connect(_on_efficiency_changed)
		power_efficiency_slider.min_value = 0.5
		power_efficiency_slider.max_value = 1.5
		power_efficiency_slider.step = 0.05
		power_efficiency_slider.value = 1.0
	
	_update_make_button_state()
	_update_power_displays()

func set_module_ref(module: FabricatorModule) -> void:
	module_ref = module
	inventory_data_ref = module
	
	if module_ref.has_signal("fabrication_progress_updated"):
		if not module_ref.fabrication_progress_updated.is_connected(_on_fabrication_progress_updated):
			module_ref.fabrication_progress_updated.connect(_on_fabrication_progress_updated)
	
	# Connect to PowerManager for live power updates
	if PowerManager:
		if not PowerManager.power_level_changed.is_connected(_on_power_level_changed):
			PowerManager.power_level_changed.connect(_on_power_level_changed)
	
	_check_for_completed_fabrication()
	_update_available_recipes()
	_attempt_recipe_restoration()  # Try to restore any previous selection
	_update_power_displays()

func _check_for_completed_fabrication():
	if module_ref and module_ref.fabricator_sprite.animation == "process" and module_ref.fabricator_sprite.frame == 9:
		var last_recipe = module_ref.get_last_completed_recipe()
		if last_recipe:
			call_deferred("_restore_last_recipe", last_recipe)

func _on_fabrication_progress_updated(progress: float):
	if progress_bar:
		progress_bar.value = progress
		progress_bar.visible = progress > 0.0
	
	if preview_time_label and module_ref and module_ref.fabrication_active:
		var remaining_time = module_ref.total_fabrication_time - module_ref.fabrication_timer
		preview_time_label.text = "Time remaining: %.1f seconds" % remaining_time

func _on_power_level_changed(_current_power: float, _max_power: float):
	"""Update power status when power levels change"""
	_update_power_status()

func _on_efficiency_changed(value: float):
	"""Handle efficiency slider changes"""
	if module_ref and module_ref.has_power_component():
		module_ref.set_power_efficiency(value)
	
	_update_power_displays()
	_update_time_preview()

func _update_power_displays():
	"""Update all power-related UI elements"""
	if not module_ref or not module_ref.has_power_component():
		_hide_power_controls()
		return
	
	_show_power_controls()
	
	var power_info = module_ref.get_power_info()
	var efficiency = power_info.get("efficiency", 1.0)
	
	# Update efficiency display
	if power_efficiency_label:
		power_efficiency_label.text = "Efficiency: %.0f%%" % (efficiency * 100.0)
	
	if power_efficiency_slider and abs(power_efficiency_slider.value - efficiency) > 0.01:
		power_efficiency_slider.value = efficiency
	
	# Update power consumption display
	if power_consumption_label and current_recipe:
		var base_power = 400.0  # Base fabricator power consumption
		var actual_power = module_ref.get_power_cost_for_efficiency(base_power, efficiency)
		power_consumption_label.text = "Power: %.0f PU/s" % actual_power
	
	_update_power_status()

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

func _show_power_controls():
	"""Show power control UI elements"""
	if power_efficiency_slider:
		power_efficiency_slider.visible = true
	if power_efficiency_label:
		power_efficiency_label.visible = true
	if power_consumption_label:
		power_consumption_label.visible = true
	if power_status_label:
		power_status_label.visible = true

func _hide_power_controls():
	"""Hide power control UI elements"""
	if power_efficiency_slider:
		power_efficiency_slider.visible = false
	if power_efficiency_label:
		power_efficiency_label.visible = false
	if power_consumption_label:
		power_consumption_label.visible = false
	if power_status_label:
		power_status_label.visible = false

func update_slot(index: int) -> void:
	super.update_slot(index)
	
	if slot_type_map.get(index, "input") == "input":
		_update_available_recipes()
		_attempt_recipe_restoration()  # Try to restore after inventory changes
	
	var output_slot_index = _get_output_slot_index()
	if index == output_slot_index:
		var actual_item = _get_module_item(index)
		
		if actual_item != null and not actual_item.is_empty():
			is_showing_preview = false
			_set_output_slot_preview_style(false)
		elif current_recipe and not is_showing_preview:
			_show_output_preview()

func _get_module_item(index: int) -> Dictionary:
	return module_ref.inventory.get_item(index) if module_ref else {}

func _get_module_inventory_size() -> int:
	return module_ref.inventory.inventory_size if module_ref else 0

func _update_available_recipes():
	if not module_ref:
		return
	
	var input_items = _get_current_input_items()
	available_recipes = module_ref.get_available_recipes(input_items)
	
	if recipe_selector:
		recipe_selector.clear()
		recipe_selector.add_item("Select Recipe...")
		
		for recipe in available_recipes:
			recipe_selector.add_item(recipe.output_item.name)
	
	current_recipe = null
	_update_recipe_preview()
	_update_make_button_state()

func _get_current_input_items() -> Array[Dictionary]:
	var inputs: Array[Dictionary] = []
	
	if not module_ref:
		return inputs
	
	var inventory_size = _get_module_inventory_size()
	
	for i in range(inventory_size):
		if slot_type_map.get(i, "input") == "input":
			var item = _get_module_item(i)
			if item != null and not item.is_empty():
				inputs.append(item)
	
	return inputs

func _on_recipe_selected(index: int):
	if index <= 0 or index > available_recipes.size():
		current_recipe = null
		if module_ref:
			module_ref.set_last_selected_recipe(null)
	else:
		current_recipe = available_recipes[index - 1]
		if module_ref:
			module_ref.set_last_selected_recipe(current_recipe)
	
	_update_recipe_preview()
	_update_quantity_limits()
	_update_make_button_state()
	_update_power_displays()

func _update_recipe_preview():
	if not current_recipe:
		_clear_preview()
		return
	
	_show_output_preview()
	_update_time_preview()

func _clear_preview():
	if preview_time_label:
		preview_time_label.text = ""
	
	if progress_bar:
		progress_bar.visible = false
	
	_clear_output_preview()

func _show_output_preview():
	if not current_recipe or not output_slot:
		return
	
	var output_slot_index = _get_output_slot_index()
	var actual_item = _get_module_item(output_slot_index)
	
	if actual_item != null and not actual_item.is_empty():
		is_showing_preview = false
		return
	
	var selected_quantity = int(quantity_spinbox.value) if quantity_spinbox else 1
	var total_output = current_recipe.output_quantity * selected_quantity
	
	var preview_item = {
		"id": current_recipe.output_item,
		"quantity": total_output
	}
	
	set_item(output_slot, preview_item)
	is_showing_preview = true
	_set_output_slot_preview_style(true)

func _clear_output_preview():
	if not output_slot:
		return
	
	var output_slot_index = _get_output_slot_index()
	var actual_item = _get_module_item(output_slot_index)
	
	if is_showing_preview and (actual_item == null or actual_item.is_empty()):
		set_empty(output_slot)
		is_showing_preview = false
		_set_output_slot_preview_style(false)

func _set_output_slot_preview_style(is_preview: bool):
	if not output_slot:
		return
	
	if is_preview:
		output_slot.modulate = Color(1, 1, 1, 0.7)
		var slot_sprite = output_slot.get_slot_sprite()
		if slot_sprite:
			slot_sprite.modulate = Color.CYAN
	else:
		output_slot.modulate = Color.WHITE
		var slot_sprite = output_slot.get_slot_sprite()
		if slot_sprite:
			slot_sprite.modulate = Color.WHITE

func _update_quantity_limits():
	if not current_recipe or not module_ref:
		if quantity_spinbox:
			quantity_spinbox.max_value = 0
			quantity_spinbox.value = 0
		return
	
	var input_items = _get_current_input_items()
	var max_from_inputs = module_ref.get_max_craftable(current_recipe, input_items)
	var output_slot_index = _get_output_slot_index()
	var max_from_output = _get_output_slot_capacity(output_slot_index)
	var max_craftable = min(max_from_inputs, max_from_output)
	
	if quantity_spinbox:
		quantity_spinbox.max_value = max(1, max_craftable)
		quantity_spinbox.value = min(1, max_craftable)

func _get_output_slot_index() -> int:
	for index in slot_type_map.keys():
		if slot_type_map[index] == "output":
			return index
	return 3

func _get_output_slot_capacity(output_index: int) -> int:
	if output_index < 0 or not module_ref:
		return 0
	
	var output_item = _get_module_item(output_index)
	
	if output_item == null or output_item.is_empty():
		return int(99.0 / current_recipe.output_quantity)
	elif output_item["id"] == current_recipe.output_item:
		var remaining_capacity = 99 - output_item["quantity"]
		return int(remaining_capacity / current_recipe.output_quantity)
	else:
		return 0

func _on_quantity_changed(_value: float):
	_update_time_preview()
	_update_make_button_state()
	if current_recipe:
		_show_output_preview()

func _update_time_preview():
	if not current_recipe or not preview_time_label:
		return
	
	var selected_quantity = int(quantity_spinbox.value) if quantity_spinbox else 1
	var base_time = current_recipe.fab_time * selected_quantity
	
	var efficiency = 1.0
	if power_efficiency_slider:
		efficiency = power_efficiency_slider.value
	else:
		efficiency = 1.0
	var actual_time = base_time
	if module_ref:
		actual_time = module_ref.get_fabrication_time_for_efficiency(base_time, efficiency)
	
	preview_time_label.text = "Time: %.1f seconds" % actual_time

func _update_make_button_state():
	if not make_button:
		return
		
	var can_make = false
	
	if current_recipe and module_ref:
		var selected_quantity = int(quantity_spinbox.value) if quantity_spinbox else 1
		if selected_quantity > 0:
			var input_items = _get_current_input_items()
			var max_craftable = module_ref.get_max_craftable(current_recipe, input_items)
			var output_capacity = _get_output_slot_capacity(_get_output_slot_index())
			var has_power = module_ref.has_power()
			
			can_make = (max_craftable >= selected_quantity and output_capacity >= selected_quantity and has_power)
	
	make_button.disabled = not can_make
	if can_make:
		make_button.modulate = Color.WHITE
	else:
		make_button.modulate = Color.GRAY

func _on_slot_gui_input(event: InputEvent, slot: Button):
	if slot == output_slot and is_showing_preview:
		if event is InputEventMouseButton and event.pressed:
			return
	
	super._on_slot_gui_input(event, slot)

func _on_make_pressed():
	if not current_recipe or not module_ref:
		return
	
	var selected_quantity = int(quantity_spinbox.value) if quantity_spinbox else 1
	var efficiency = power_efficiency_slider.value if power_efficiency_slider else 1.0
	
	_clear_output_preview()
	module_ref.start_fabrication(current_recipe, selected_quantity, efficiency)

func _restore_last_recipe(last_recipe: FabricatorRecipe):
	if not last_recipe or not recipe_selector:
		return
	
	for i in range(available_recipes.size()):
		if available_recipes[i] == last_recipe:
			recipe_selector.selected = i + 1
			current_recipe = last_recipe
			_update_recipe_preview()
			_update_quantity_limits()
			_update_make_button_state()
			_update_power_displays()
			return

func _attempt_recipe_restoration():
	"""Try to restore the last selected recipe if available and craftable"""
	if not module_ref:
		return
	
	var last_selected = module_ref.get_last_selected_recipe()
	if not last_selected:
		return
	
	print("Attempting to restore recipe: %s" % last_selected.output_item.name)
	
	# Check if recipe is in available recipes
	var recipe_available = false
	for recipe in available_recipes:
		if recipe == last_selected:
			recipe_available = true
			break
	
	if not recipe_available:
		print("Recipe not available with current materials")
		module_ref.set_last_selected_recipe(null)
		return
	
	# Check if we have enough materials
	var input_items = _get_current_input_items()
	var max_craftable = module_ref.get_max_craftable(last_selected, input_items)
	
	if max_craftable > 0:
		_restore_last_recipe(last_selected)
		print("Successfully restored recipe: %s" % last_selected.output_item.name)
	else:
		print("Cannot restore recipe: insufficient materials")
		module_ref.set_last_selected_recipe(null)
