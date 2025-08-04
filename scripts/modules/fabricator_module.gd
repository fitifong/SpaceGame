# scripts/modules/fabricator_module.gd
extends StaticBody2D
class_name FabricatorModule

const InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const UIHandlerComponent = preload("res://scripts/components/ui_handler_component.gd")
const InteractionComponent = preload("res://scripts/components/interaction_component.gd")

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)
signal fabrication_progress_updated(progress: float)

@export var fabricator_ui_scene: PackedScene
@export var interaction_prompt: Control
@export var interaction_area: Area2D
@export var fabricator_sprite: AnimatedSprite2D

var inventory: InventoryComponent
var ui_handler: UIHandlerComponent
var interaction: InteractionComponent

@onready var recipe_db := FabricatorRecipeDatabase.new()
var is_processing := false
var anim_busy := false
var current_recipe: FabricatorRecipe = null
var current_quantity: int = 0
var fabrication_timer: float = 0.0
var total_fabrication_time: float = 0.0
var last_completed_recipe: FabricatorRecipe = null

func _ready():
	add_to_group("interactable_modules")
	_create_components()
	_connect_signals()

	if fabricator_sprite:
		fabricator_sprite.play("static_open")

	recipe_db.load_all_recipes()

func _create_components():
	inventory = InventoryComponent.new()
	inventory.name = "Inventory"
	add_child(inventory)
	inventory.initialize(GameConstants.FABRICATOR_SLOTS)

	ui_handler = UIHandlerComponent.new()
	ui_handler.name = "UIHandler"
	add_child(ui_handler)
	ui_handler.initialize(self, fabricator_ui_scene)

	interaction = InteractionComponent.new()
	interaction.name = "Interaction"
	add_child(interaction)
	interaction.initialize(self, interaction_area, interaction_prompt)

func _connect_signals():
	inventory.slot_updated.connect(slot_updated.emit)
	ui_handler.ui_opened.connect(module_opened.emit)
	ui_handler.ui_closed.connect(closed.emit)
	interaction.interaction_requested.connect(_on_interaction_requested)

func _process(delta: float):
	if is_processing and current_recipe:
		fabrication_timer += delta
		var progress = fabrication_timer / total_fabrication_time
		_update_animation_frame(progress)
		if ui_handler.is_open():
			fabrication_progress_updated.emit(progress)
		if fabrication_timer >= total_fabrication_time:
			_complete_fabrication()

func _on_interaction_requested():
	# If still fabricating, only allow opening once it has finished and paused
	if is_processing:
		if fabricator_sprite and fabricator_sprite.frame == GameConstants.FABRICATION_COMPLETE_FRAME:
			_open_with_door_animation()
		else:
			print("Fabrication in progress... Please wait.")
		return

	if anim_busy:
		return

	# --- NEW: if fabrication just completed (sprite paused at last frame), play door-open animation first ---
	if fabricator_sprite and fabricator_sprite.frame == GameConstants.FABRICATION_COMPLETE_FRAME:
		_open_with_door_animation()
		return

	# Otherwise, toggle UI immediately with no animation delay
	if ui_handler.is_open():
		ui_handler.close()
	else:
		ui_handler.open()

func start_fabrication(recipe: FabricatorRecipe, quantity: int):
	if not recipe or quantity <= 0 or is_processing or anim_busy:
		return

	if not _validate_recipe(recipe, quantity):
		print("Cannot start fabrication: insufficient materials")
		return

	_consume_materials(recipe, quantity)

	current_recipe = recipe
	current_quantity = quantity
	is_processing = true
	fabrication_timer = 0.0
	total_fabrication_time = recipe.fab_time * quantity

	if ui_handler.is_open():
		ui_handler.close()

	_play_door_close_animation()

func _validate_recipe(recipe: FabricatorRecipe, quantity: int) -> bool:
	var input_items = _get_current_input_items()
	var max_possible = recipe_db.get_max_craftable(recipe, input_items)
	return max_possible >= quantity

func _consume_materials(recipe: FabricatorRecipe, quantity: int):
	for i in range(recipe.get_ingredient_count()):
		var required_item = recipe.get_ingredient_item(i)
		var required_quantity = recipe.get_ingredient_quantity(i) * quantity
		for slot_index in range(inventory.inventory_size):
			if slot_index != GameConstants.OUTPUT_SLOT_INDEX:
				var slot_item = inventory.get_item(slot_index)
				if not slot_item.is_empty() and slot_item.get("id") == required_item:
					slot_item["quantity"] -= required_quantity
					if slot_item["quantity"] <= 0:
						inventory.remove_item(slot_index)
					else:
						inventory.add_item(slot_index, slot_item)
					break

func _complete_fabrication():
	var output_slot_index = GameConstants.OUTPUT_SLOT_INDEX
	var output_item = inventory.get_item(output_slot_index)
	var total_output = current_recipe.output_quantity * current_quantity

	if output_item.is_empty():
		inventory.add_item(output_slot_index, {
			"id": current_recipe.output_item,
			"quantity": total_output
		})
	else:
		output_item["quantity"] += total_output
		inventory.add_item(output_slot_index, output_item)

	if fabricator_sprite:
		fabricator_sprite.frame = GameConstants.FABRICATION_COMPLETE_FRAME

	last_completed_recipe = current_recipe
	is_processing = false
	current_recipe = null
	current_quantity = 0
	fabrication_timer = 0.0
	total_fabrication_time = 0.0

func _update_animation_frame(progress: float):
	if fabricator_sprite and fabricator_sprite.animation == "process":
		var frame_index = int(progress * GameConstants.FABRICATION_COMPLETE_FRAME)
		frame_index = clamp(frame_index, 0, GameConstants.FABRICATION_COMPLETE_FRAME)
		fabricator_sprite.frame = frame_index

func _play_door_close_animation():
	anim_busy = true
	if fabricator_sprite:
		fabricator_sprite.animation_finished.connect(_on_door_closed, CONNECT_ONE_SHOT)
		fabricator_sprite.play("door")

func _on_door_closed():
	if fabricator_sprite:
		fabricator_sprite.play("process")
		fabricator_sprite.pause()
		fabricator_sprite.frame = 0
	anim_busy = false

func _open_with_door_animation():
	anim_busy = true
	if fabricator_sprite:
		fabricator_sprite.animation_finished.connect(_on_door_opened, CONNECT_ONE_SHOT)
		# play "door" in reverse to open
		fabricator_sprite.play("door", -1.0, true)

func _on_door_opened():
	if fabricator_sprite:
		fabricator_sprite.play("static_open")
	ui_handler.open()
	last_completed_recipe = null
	anim_busy = false

func _get_current_input_items() -> Array[Dictionary]:
	var inputs: Array[Dictionary] = []
	for i in range(inventory.inventory_size):
		if i != GameConstants.OUTPUT_SLOT_INDEX:
			var item = inventory.get_item(i)
			if not item.is_empty():
				inputs.append(item)
	return inputs

func get_available_recipes(input_items: Array[Dictionary]) -> Array[FabricatorRecipe]:
	return recipe_db.get_matching_recipes(input_items) if recipe_db else []

func get_max_craftable(recipe: FabricatorRecipe, input_items: Array[Dictionary]) -> int:
	return recipe_db.get_max_craftable(recipe, input_items) if recipe_db and recipe else 0

func get_last_completed_recipe() -> FabricatorRecipe:
	return last_completed_recipe

# Expose direct UI control if needed elsewhere
func open():
	ui_handler.open()

func close():
	ui_handler.close()

func is_ui_open() -> bool:
	return ui_handler.is_open()
