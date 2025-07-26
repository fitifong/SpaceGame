extends StaticBody2D
class_name FurnaceModule

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)
signal smelt_progress_updated(progress: float)

@onready var interaction_prompt: Control = $InteractionPrompt
@onready var interaction_area: Area2D     = $InteractionArea
@onready var furnace_ui_scene            = preload("res://scenes/ui/module_ui/furnace_ui.tscn")

var is_smelting       := false
var smelt_timer       := 0.0
var current_recipe    := {}
var reserved_input: Dictionary = {}  # the ore/ingredient being smelted right now

var inventory: Array  = []
var inventory_size: int = 0
var ui_instance: Control = null

func _ready():
	add_to_group("interactable_modules")
	interaction_prompt.z_index = 999
	interaction_prompt.visible = false
	set_inventory_size(2)

	# Connect our own slot_updated signal so we can cancel mid-process
	if not is_connected("slot_updated", Callable(self, "_on_slot_updated")):
		slot_updated.connect(Callable(self, "_on_slot_updated"))

func set_inventory_size(size: int) -> void:
	inventory_size = size
	inventory.resize(size)

# Utility to get input/output indices dynamically
func get_slot_index_by_type(slot_type: String) -> int:
	if ui_instance:
		if ui_instance.has_method("get_slot_index_by_type"):
			return ui_instance.get_slot_index_by_type(slot_type)
		else:
			push_warning("UI instance lacks get_slot_index_by_type() method.")
	else:
		# Don't warn if UI is simply closed — normal during _process()
		pass

	# Fallback default: input = 0, output = 1
	return 0 if slot_type == "input" else 1


# Called both by the module (when inventory changes) and by UI for visuals
func _on_slot_updated(index: int) -> void:
	var in_index = get_slot_index_by_type("input")
	# If the input slot was cleared, cancel any active smelt
	if index == in_index and inventory[in_index] == null:
		cancel_smelting()

func cancel_smelting() -> void:
	is_smelting = false
	smelt_timer = 0.0
	current_recipe = {}
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
		if input_item == null:
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
		var recipe    = current_recipe
		var output_id = recipe["output_id"]      # <— declare it here
		smelt_timer  += delta

		if smelt_timer >= recipe["smelt_time"]:
			# --- Validate output slot before consuming input ---
			if output_item != null and output_item["id"] != output_id:
				return
			elif output_item != null and output_item["quantity"] >= 99:
				# Full stack, wait
				return

			# --- Consume input now that output is valid ---
			if input_item["quantity"] > 1:
				input_item["quantity"] -= 1
			else:
				inventory[in_index] = null
			slot_updated.emit(in_index)

			# --- Produce output ---
			if output_item == null:
				inventory[out_index] = {
					"id": output_id,
					"quantity": 1
				}
			else:
				output_item["quantity"] += 1
			slot_updated.emit(out_index)

			# --- Finalize this smelt cycle ---
			smelt_timer      = 0.0
			reserved_input   = {}
			current_recipe   = {}

			# Hide bar and stop if no more input
			var refreshed = inventory[in_index]
			if refreshed == null or refreshed["quantity"] <= 0:
				smelt_progress_updated.emit(0.0)
				is_smelting = false
			return

		# Still smelting—emit progress
		var pct = smelt_timer / recipe["smelt_time"]
		smelt_progress_updated.emit(clamp(pct, 0.0, 1.0))
		return

	# 4) Start a fresh smelt if input is valid
	if input_item != null and input_item["quantity"] > 0:
		var recipe = FurnaceRecipeDatabase.get_recipe(input_item["id"])
		if recipe == null or not recipe.has("smelt_time"):
			# No smelt recipe—do nothing
			return

		is_smelting    = true
		reserved_input = {"id": input_item["id"]}
		current_recipe = recipe
		smelt_timer    = 0.0
		smelt_progress_updated.emit(0.0)

# -----------------------------------------
#   PLAYER INTERACTION & UI
# -----------------------------------------
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.append(self)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.erase(self)
		if ui_instance:
			close()

func open():
	if ui_instance == null:
		if furnace_ui_scene == null:
			push_error("[ERROR] furnace_ui_scene is null!")
			return

		interaction_prompt.visible = false
		var gui_layer = get_node("/root/Game/GUIs")
		ui_instance = furnace_ui_scene.instantiate()
		gui_layer.add_child(ui_instance)
		
		UIManager.register_ui(ui_instance)
		ui_instance.set_inventory_ref(self)

		# Connect UI’s output-slot update handler
		if not self.slot_updated.is_connected(ui_instance._on_output_slot_updated):
			self.slot_updated.connect(ui_instance._on_output_slot_updated)

		module_opened.emit(ui_instance)

func close():
	interaction_prompt.visible = true
	UIManager.unregister_ui(ui_instance)
	closed.emit()
	if ui_instance:
		ui_instance.queue_free()
		ui_instance = null
