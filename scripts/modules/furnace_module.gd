# scripts/modules/furnace_module.gd
extends ModularInventoryBase
class_name FurnaceModule

# Furnace-specific signals
signal smelt_progress_updated(progress: float)

# Furnace-specific exports
@export var furnace_ui_scene: PackedScene

# Furnace-specific components and state
@onready var recipe_db := FurnaceRecipeDatabase.new()

# Smelting state
var smelt_enabled := false
var is_smelting := false
var cooling_down := false
var smelt_timer := 0.0
var current_recipe: FurnaceRecipe = null
var reserved_input: Dictionary = {}

func _get_default_inventory_size() -> int:
	"""Furnace modules have 2 slots (input + output)"""
	return GameConstants.FURNACE_SLOTS

func _get_ui_scene() -> PackedScene:
	"""Use furnace-specific UI scene if provided, otherwise use default"""
	return furnace_ui_scene if furnace_ui_scene else ui_scene

func _post_setup():
	"""Furnace-specific initialization after components are set up"""
	super._post_setup()
	recipe_db.load_all_recipes()

func _process(delta: float):
	super._process(delta)
	_handle_smelting_process(delta)

func _handle_smelting_process(delta: float):
	"""Handle the smelting process logic"""
	# Active smelting: advance forward
	if is_smelting:
		smelt_timer += delta
		var progress = smelt_timer / current_recipe.smelt_time
		smelt_progress_updated.emit(progress)

		if smelt_timer >= current_recipe.smelt_time:
			_complete_smelt()
		return
	
	# Toggle-off cooldown: reverse until zero
	elif cooling_down:
		smelt_timer -= delta
		if smelt_timer <= 0.0:
			cooling_down = false
			_cancel_smelting()
			if smelt_enabled:
				_start_smelting_if_possible()
		else:
			var rev_progress = smelt_timer / current_recipe.smelt_time
			smelt_progress_updated.emit(rev_progress)
		return

func _on_slot_updated(index: int):
	"""Handle slot updates for furnace logic"""
	super._on_slot_updated(index)
	
	if index != 0:  # Only react to input slot changes
		return

	# Only react if smelt is enabled
	if not smelt_enabled:
		return

	var input_item = get_item(0)
	if input_item.is_empty():
		_cancel_smelting()
		return

	var recipe = _get_recipe(input_item.get("id"))
	if recipe:
		# Restart immediately with new ore
		current_recipe = recipe
		reserved_input = {"id": input_item.get("id")}
		smelt_timer = 0.0
		is_smelting = true
		cooling_down = false
		smelt_progress_updated.emit(0.0)
	else:
		_cancel_smelting()

# ------------------------------------------------------------------
# FURNACE-SPECIFIC METHODS
# ------------------------------------------------------------------

func toggle_smelting_enabled():
	"""Toggle the auto-smelting feature"""
	smelt_enabled = not smelt_enabled

	if smelt_enabled:
		# If we're in cooldown, resume smelting immediately at current progress
		if cooling_down:
			cooling_down = false
			is_smelting = true
			# smelt_timer already has the current progress, so we continue from there
		else:
			_start_smelting_if_possible()
	else:
		# Mid-smelt? Begin cooldown; else just clear
		if is_smelting:
			cooling_down = true
			is_smelting = false
		else:
			_cancel_smelting()

func _start_smelting_if_possible():
	"""Start smelting if conditions are met"""
	if is_smelting or cooling_down or not smelt_enabled:
		return

	var input_item = get_item(0)
	if input_item.is_empty():
		return

	var recipe = _get_recipe(input_item.get("id"))
	if recipe and recipe.smelt_time > 0.0:
		is_smelting = true
		reserved_input = {"id": input_item.get("id")}
		current_recipe = recipe
		smelt_timer = 0.0
		smelt_progress_updated.emit(0.0)

func _cancel_smelting():
	"""Cancel current smelting operation"""
	is_smelting = false
	cooling_down = false
	smelt_timer = 0.0
	current_recipe = null
	reserved_input = {}
	smelt_progress_updated.emit(0.0)

func _complete_smelt():
	"""Complete the current smelting operation"""
	var input_item = get_item(0)
	var output_item = get_item(1)
	var output_id = current_recipe.output_item

	# Check if output slot can accept the result
	if output_item and not output_item.is_empty():
		if output_item.get("id") != output_id or output_item.get("quantity", 0) >= GameConstants.MAX_STACK_SIZE:
			return

	# Consume one input item
	if input_item.get("quantity", 0) > 1:
		input_item["quantity"] -= 1
		add_item(0, input_item)
	else:
		remove_item(0)

	# Produce output item
	if output_item.is_empty():
		add_item(1, {"id": output_id, "quantity": 1})
	else:
		output_item["quantity"] += 1
		add_item(1, output_item)

	# Reset state
	smelt_timer = 0.0
	reserved_input = {}
	is_smelting = false

	# Continue smelting if enabled
	if smelt_enabled:
		_start_smelting_if_possible()

func _get_recipe(item_id) -> FurnaceRecipe:
	"""Find recipe for the given input item"""
	if not recipe_db or not item_id:
		return null
	
	for recipe in recipe_db.recipes:
		if recipe.input_item == item_id:
			return recipe
	return null

# ------------------------------------------------------------------
# LEGACY API COMPATIBILITY
# ------------------------------------------------------------------

func get_slot_index_by_type(slot_type: String) -> int:
	"""Legacy method for UI compatibility"""
	if slot_type == "input":
		return 0
	else:
		return 1
