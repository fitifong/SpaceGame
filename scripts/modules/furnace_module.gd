# scripts/modules/furnace_module.gd
extends StaticBody2D
class_name FurnaceModule

const InventoryComponent   = preload("res://scripts/components/inventory_component.gd")
const UIHandlerComponent   = preload("res://scripts/components/ui_handler_component.gd")
const InteractionComponent = preload("res://scripts/components/interaction_component.gd")

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)
signal smelt_progress_updated(progress: float)

@export var interaction_prompt: Control
@export var interaction_area: Area2D
@export var furnace_ui_scene: PackedScene

var inventory: InventoryComponent
var ui_handler: UIHandlerComponent
var interaction: InteractionComponent

@onready var recipe_db := FurnaceRecipeDatabase.new()

# --- toggle state; when true we auto-start smelts on new input
var smelt_enabled := false

# --- runtime state
var is_smelting   := false
var cooling_down  := false
var smelt_timer   := 0.0
var current_recipe: FurnaceRecipe = null
var reserved_input: Dictionary     = {}

func _ready():
	add_to_group("interactable_modules")
	_create_components()
	_connect_signals()
	recipe_db.load_all_recipes()

func _create_components():
	inventory = InventoryComponent.new()
	inventory.name = "Inventory"
	add_child(inventory)
	inventory.initialize(GameConstants.FURNACE_SLOTS)

	ui_handler = UIHandlerComponent.new()
	ui_handler.name = "UIHandler"
	add_child(ui_handler)
	ui_handler.initialize(self, furnace_ui_scene)

	interaction = InteractionComponent.new()
	interaction.name = "Interaction"
	add_child(interaction)
	interaction.initialize(self, interaction_area, interaction_prompt)

func _connect_signals():
	inventory.slot_updated.connect(slot_updated.emit)
	inventory.slot_updated.connect(_on_slot_updated)
	ui_handler.ui_opened.connect(module_opened.emit)
	ui_handler.ui_closed.connect(closed.emit)
	interaction.interaction_requested.connect(_on_interaction_requested)

func _process(delta: float):
	# --- Active smelting: just advance forward ---
	if is_smelting:
		smelt_timer += delta
		var progress = smelt_timer / current_recipe.smelt_time
		smelt_progress_updated.emit(progress)

		if smelt_timer >= current_recipe.smelt_time:
			_complete_smelt(inventory.get_item(0), inventory.get_item(1))
		return
	# --- Toggle-off cooldown: reverse until zero ---
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
	# idle—nothing happening

func toggle_smelting_enabled():
	smelt_enabled = not smelt_enabled

	if smelt_enabled:
		_start_smelting_if_possible()
	else:
		# mid-smelt? begin cooldown; else just clear
		if is_smelting:
			cooling_down = true
			is_smelting  = false
		else:
			_cancel_smelting()

func _start_smelting_if_possible():
	if is_smelting or cooling_down or not smelt_enabled:
		return

	var input_item = inventory.get_item(0)
	if input_item.is_empty():
		return

	var recipe = _get_recipe(input_item.id)
	if recipe and recipe.smelt_time > 0.0:
		is_smelting    = true
		reserved_input = { "id": input_item.id }
		current_recipe = recipe
		smelt_timer    = 0.0
		smelt_progress_updated.emit(0.0)

func _cancel_smelting():
	is_smelting    = false
	cooling_down   = false
	smelt_timer    = 0.0
	current_recipe = null
	reserved_input = {}
	smelt_progress_updated.emit(0.0)

func _complete_smelt(input_item: Dictionary, output_item: Dictionary):
	var output_id = current_recipe.output_item

	if output_item and not output_item.is_empty():
		if output_item.id != output_id or output_item.quantity >= GameConstants.MAX_STACK_SIZE:
			return

	# consume one ore
	if input_item.quantity > 1:
		input_item.quantity -= 1
		inventory.add_item(0, input_item)
	else:
		inventory.remove_item(0)

	# produce bar
	if output_item.is_empty():
		inventory.add_item(1, { "id": output_id, "quantity": 1 })
	else:
		output_item.quantity += 1
		inventory.add_item(1, output_item)

	# reset timer & reserved_input
	smelt_timer    = 0.0
	reserved_input = {}
	is_smelting    = false

	# continuous smelt?
	if smelt_enabled:
		_start_smelting_if_possible()

func _on_slot_updated(index: int):
	if index != 0:
		return

	# only react if smelt is enabled
	if not smelt_enabled:
		return

	var input_item = inventory.get_item(0)
	if input_item.is_empty():
		_cancel_smelting()
		return

	var recipe = _get_recipe(input_item.id)
	if recipe:
		# restart immediately with new ore
		current_recipe = recipe
		reserved_input = { "id": input_item.id }
		smelt_timer    = 0.0
		is_smelting    = true
		cooling_down   = false
		smelt_progress_updated.emit(0.0)
	else:
		_cancel_smelting()

func _get_recipe(item_id) -> FurnaceRecipe:
	for recipe in recipe_db.recipes:
		if recipe.input_item == item_id:
			return recipe
	return null

func _on_interaction_requested():
	if ui_handler.is_open():
		ui_handler.close()
	else:
		ui_handler.open()

# External UI helpers—unchanged
func open() -> void:
	ui_handler.open()
func close() -> void:
	ui_handler.close()
func is_ui_open() -> bool:
	return ui_handler.is_open()
func get_slot_index_by_type(slot_type: String) -> int:
	if slot_type == "input":
		return 0
	else:
		return 1
