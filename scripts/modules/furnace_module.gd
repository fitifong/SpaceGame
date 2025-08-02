extends StaticBody2D
class_name FurnaceModule

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)
signal smelt_progress_updated(progress: float)

@export var interaction_prompt: Control
@export var interaction_area: Area2D
@export var furnace_ui_scene: PackedScene

@onready var recipe_db := FurnaceRecipeDatabase.new()

var is_smelting := false
var smelt_timer := 0.0
var current_recipe: FurnaceRecipe
var reserved_input: Dictionary = {}  # the ore/ingredient being smelted right now

var inventory: Array  = []
var inventory_size: int = 0
var ui_instance: Control = null

# Module state tracking
var module_state: GameConstants.ModuleState = GameConstants.ModuleState.IDLE

func _ready():
	add_to_group("interactable_modules")
	
	# FIXED: Null safety checks
	if interaction_prompt:
		interaction_prompt.z_index = 999
		interaction_prompt.visible = false
	else:
		push_warning("[FurnaceModule] interaction_prompt not assigned")
		
	set_inventory_size(GameConstants.FURNACE_SLOTS)
	
	if recipe_db:
		recipe_db.load_all_recipes()
	else:
		push_error("[FurnaceModule] Failed to create recipe database")

	# Connect our own slot_updated signal so we can cancel mid-process
	if not slot_updated.is_connected(_on_slot_updated):
		slot_updated.connect(_on_slot_updated)

func set_inventory_size(size: int) -> void:
	# FIXED: Input validation
	if size < 0:
		push_error("[FurnaceModule] Invalid inventory size: %d" % size)
		return
		
	inventory_size = size
	inventory.resize(size)

# Utility to get input/output indices dynamically
func get_slot_index_by_type(slot_type: String) -> int:
	if ui_instance and ui_instance.has_method("get_slot_index_by_type"):
		return ui_instance.get_slot_index_by_type(slot_type)
	else:
		# Don't warn if UI is simply closed — normal during _process()
		pass

	# Fallback default: input = 0, output = 1
	return 0 if slot_type == "input" else 1

func get_recipe(item: ItemResource) -> FurnaceRecipe:
	if not recipe_db:
		push_error("[FurnaceModule] No recipe database available")
		return null
		
	if not item:
		return null
		
	for recipe in recipe_db.recipes:
		if recipe and recipe.input_item == item:
			return recipe
	return null

# Called both by the module (when inventory changes) and by UI for visuals
func _on_slot_updated(index: int) -> void:
	# FIXED: Input validation
	if index < 0 or index >= inventory.size():
		push_warning("[FurnaceModule] Invalid slot index in _on_slot_updated: %d" % index)
		return
		
	var in_index = get_slot_index_by_type("input")
	# If the input slot was cleared, cancel any active smelt
	if index == in_index and inventory[in_index] == null:
		cancel_smelting()

func cancel_smelting() -> void:
	is_smelting = false
	module_state = GameConstants.ModuleState.IDLE
	smelt_timer = 0.0
	current_recipe = null
	reserved_input = {}
	smelt_progress_updated.emit(0.0)

func _process(delta: float) -> void:
	# Slot indices (dynamic, but default to 0/1 if UI is closed)
	var in_index  = get_slot_index_by_type("input")
	var out_index = get_slot_index_by_type("output")
	var input_item:  Variant = inventory[in_index]
	var output_item: Variant = inventory[out_index]

	# 1) Mid-smelt guard: cancel if input removed or swapped
	if not reserved_input.is_empty():
		if not input_item:
			# Input cleared entirely
			cancel_smelting()
			return
		elif input_item["id"] != reserved_input["id"]:
			# Swapped to a new ore mid-smelt
			cancel_smelting()
			return

	# 2) If not currently smelting, do nothing
	if not is_smelting:
		return

	# 3) If we are mid-smelt, advance it
	if not reserved_input.is_empty():
		var recipe = current_recipe
		if not recipe:
			cancel_smelting()
			return
			
		var output_id = recipe.output_item
		smelt_timer += delta

		if smelt_timer >= recipe.smelt_time:
			# --- Validate output slot before consuming input ---
			if output_item != null and output_item["id"] != output_id:
				return
			elif output_item != null and output_item["quantity"] >= GameConstants.MAX_STACK_SIZE:
				# Full stack, wait
				return

			# --- Consume input now that output is valid ---
			if input_item["quantity"] > 1:
				input_item["quantity"] -= 1
			else:
				inventory[in_index] = null
			slot_updated.emit(in_index)

			# --- Produce output ---
			if not output_item:
				inventory[out_index] = {
					"id": output_id,
					"quantity": 1
				}
			else:
				output_item["quantity"] += 1
			slot_updated.emit(out_index)

			# --- Finalize this smelt cycle ---
			smelt_timer = 0.0
			reserved_input = {}
			current_recipe = null

			# Hide bar and stop if no more input
			var refreshed = inventory[in_index]
			if not refreshed or refreshed["quantity"] <= 0:
				smelt_progress_updated.emit(0.0)
				is_smelting = false
				module_state = GameConstants.ModuleState.IDLE
			return

		# Still smelting—emit progress
		var pct = smelt_timer / recipe.smelt_time
		smelt_progress_updated.emit(clamp(pct, 0.0, 1.0))
		return

	# 4) Start a fresh smelt if input is valid
	if input_item != null and input_item["quantity"] > 0:
		var recipe = get_recipe(input_item["id"])
		if not recipe:
			return
		if typeof(recipe.smelt_time) != TYPE_FLOAT or recipe.smelt_time <= 0.0:
			# No smelt recipe—do nothing
			return

		is_smelting = true
		module_state = GameConstants.ModuleState.PROCESSING
		reserved_input = {"id": input_item["id"]}
		current_recipe = recipe
		smelt_timer = 0.0
		smelt_progress_updated.emit(0.0)

# -----------------------------------------
#   PLAYER INTERACTION & UI
# -----------------------------------------
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		if "modules_in_range" in body:
			body.modules_in_range.append(self)
		else:
			push_warning("[FurnaceModule] Player missing modules_in_range array")

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		if "modules_in_range" in body:
			body.modules_in_range.erase(self)
		if ui_instance:
			close()

func open():
	if ui_instance != null:
		return
		
	if not furnace_ui_scene:
		push_error("[FurnaceModule] furnace_ui_scene not assigned")
		return

	if interaction_prompt:
		interaction_prompt.visible = false
		
	ui_instance = furnace_ui_scene.instantiate()
	if not ui_instance:
		push_error("[FurnaceModule] Failed to instantiate furnace UI")
		return
		
	if UIManager:
		UIManager.add_ui(ui_instance)
		UIManager.register_ui(ui_instance)
	else:
		push_error("[FurnaceModule] UIManager not available")
		return
		
	if ui_instance.has_method("set_inventory_ref"):
		ui_instance.set_inventory_ref(self)
	else:
		push_error("[FurnaceModule] UI missing set_inventory_ref method")

	# Connect UI's output-slot update handler
	if ui_instance.has_method("_on_output_slot_updated"):
		if not slot_updated.is_connected(ui_instance._on_output_slot_updated):
			slot_updated.connect(ui_instance._on_output_slot_updated)

	module_opened.emit(ui_instance)

func close():
	if interaction_prompt:
		interaction_prompt.visible = true
		
	if UIManager and ui_instance:
		UIManager.unregister_ui(ui_instance)
		
	closed.emit()
	
	if ui_instance:
		ui_instance.queue_free()
		ui_instance = null
