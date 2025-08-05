# scripts/modules/fabricator_module.gd
extends ModularInventoryBase
class_name FabricatorModule

# Fabricator-specific signals
signal fabrication_progress_updated(progress: float)

# Fabricator-specific exports
@export var fabricator_ui_scene: PackedScene
@export var fabricator_sprite: AnimatedSprite2D

# Fabricator-specific components and state
@onready var recipe_db := FabricatorRecipeDatabase.new()

# Processing state
var fabrication_active := false
var anim_busy := false
var current_recipe: FabricatorRecipe = null
var current_quantity: int = 0
var fabrication_timer: float = 0.0
var total_fabrication_time: float = 0.0
var last_completed_recipe: FabricatorRecipe = null

func _get_default_inventory_size() -> int:
	"""Fabricator modules have 4 slots (3 input + 1 output)"""
	return GameConstants.FABRICATOR_SLOTS

func _get_ui_scene() -> PackedScene:
	"""Use fabricator-specific UI scene if provided, otherwise use default"""
	return fabricator_ui_scene if fabricator_ui_scene else ui_scene

func _post_setup():
	"""Fabricator-specific initialization after components are set up"""
	super._post_setup()
	
	if fabricator_sprite:
		fabricator_sprite.play("static_open")
	
	recipe_db.load_all_recipes()

func _process(delta: float):
	super._process(delta)
	_handle_fabrication_process(delta)

func _handle_fabrication_process(delta: float):
	"""Handle the fabrication process logic"""
	if fabrication_active and current_recipe:
		fabrication_timer += delta
		var progress = fabrication_timer / total_fabrication_time
		_update_animation_frame(progress)
		
		if is_ui_open():
			fabrication_progress_updated.emit(progress)
		
		if fabrication_timer >= total_fabrication_time:
			_complete_fabrication()

func _on_interaction_requested():
	"""Handle interaction requests with fabrication state awareness"""
	# If still fabricating, only allow opening once it has finished and paused
	if fabrication_active:
		if fabricator_sprite and fabricator_sprite.frame == GameConstants.FABRICATION_COMPLETE_FRAME:
			_open_with_door_animation()
		else:
			print("Fabrication in progress... Please wait.")
		return

	if anim_busy:
		return

	# If fabrication just completed (sprite paused at last frame), play door-open animation first
	if fabricator_sprite and fabricator_sprite.frame == GameConstants.FABRICATION_COMPLETE_FRAME:
		_open_with_door_animation()
		return

	# Otherwise, use default interaction behavior
	super._on_interaction_requested()

# ------------------------------------------------------------------
# FABRICATION METHODS
# ------------------------------------------------------------------

func start_fabrication(recipe: FabricatorRecipe, quantity: int):
	"""Start fabricating items with the given recipe and quantity"""
	if not recipe or quantity <= 0 or fabrication_active or anim_busy:
		return

	if not _validate_recipe(recipe, quantity):
		print("Cannot start fabrication: insufficient materials")
		return

	_consume_materials(recipe, quantity)

	current_recipe = recipe
	current_quantity = quantity
	fabrication_active = true
	fabrication_timer = 0.0
	total_fabrication_time = recipe.fab_time * quantity

	if is_ui_open():
		close()

	_play_door_close_animation()

func _validate_recipe(recipe: FabricatorRecipe, quantity: int) -> bool:
	"""Validate that we have enough materials for the recipe"""
	var input_items = _get_current_input_items()
	var max_possible = recipe_db.get_max_craftable(recipe, input_items)
	return max_possible >= quantity

func _consume_materials(recipe: FabricatorRecipe, quantity: int):
	"""Consume materials for fabrication"""
	for i in range(recipe.get_ingredient_count()):
		var required_item = recipe.get_ingredient_item(i)
		var required_quantity = recipe.get_ingredient_quantity(i) * quantity
		
		for slot_index in range(inventory.inventory_size):
			if slot_index != GameConstants.OUTPUT_SLOT_INDEX:
				var slot_item = get_item(slot_index)
				if not slot_item.is_empty() and slot_item.get("id") == required_item:
					slot_item["quantity"] -= required_quantity
					if slot_item["quantity"] <= 0:
						remove_item(slot_index)
					else:
						add_item(slot_index, slot_item)
					break

func _complete_fabrication():
	"""Complete the fabrication process"""
	var output_slot_index = GameConstants.OUTPUT_SLOT_INDEX
	var output_item = get_item(output_slot_index)
	var total_output = current_recipe.output_quantity * current_quantity

	if output_item.is_empty():
		add_item(output_slot_index, {
			"id": current_recipe.output_item,
			"quantity": total_output
		})
	else:
		output_item["quantity"] += total_output
		add_item(output_slot_index, output_item)

	if fabricator_sprite:
		fabricator_sprite.frame = GameConstants.FABRICATION_COMPLETE_FRAME

	last_completed_recipe = current_recipe
	fabrication_active = false
	current_recipe = null
	current_quantity = 0
	fabrication_timer = 0.0
	total_fabrication_time = 0.0

# ------------------------------------------------------------------
# ANIMATION METHODS
# ------------------------------------------------------------------

func _update_animation_frame(progress: float):
	"""Update animation frame based on fabrication progress"""
	if fabricator_sprite and fabricator_sprite.animation == "process":
		var frame_index = int(progress * GameConstants.FABRICATION_COMPLETE_FRAME)
		frame_index = clamp(frame_index, 0, GameConstants.FABRICATION_COMPLETE_FRAME)
		fabricator_sprite.frame = frame_index

func _play_door_close_animation():
	"""Play door closing animation before fabrication"""
	anim_busy = true
	if fabricator_sprite:
		fabricator_sprite.animation_finished.connect(_on_door_closed, CONNECT_ONE_SHOT)
		fabricator_sprite.play("door")

func _on_door_closed():
	"""Handle door closed animation completion"""
	if fabricator_sprite:
		fabricator_sprite.play("process")
		fabricator_sprite.pause()
		fabricator_sprite.frame = 0
	anim_busy = false

func _open_with_door_animation():
	"""Open UI with door opening animation"""
	anim_busy = true
	if fabricator_sprite:
		fabricator_sprite.animation_finished.connect(_on_door_opened, CONNECT_ONE_SHOT)
		# Play "door" in reverse to open
		fabricator_sprite.play("door", -1.0, true)

func _on_door_opened():
	"""Handle door opened animation completion"""
	if fabricator_sprite:
		fabricator_sprite.play("static_open")
	open()
	last_completed_recipe = null
	anim_busy = false

# ------------------------------------------------------------------
# RECIPE HELPER METHODS
# ------------------------------------------------------------------

func _get_current_input_items() -> Array[Dictionary]:
	"""Get all input items (excluding output slot)"""
	var inputs: Array[Dictionary] = []
	for i in range(inventory.inventory_size):
		if i != GameConstants.OUTPUT_SLOT_INDEX:
			var item = get_item(i)
			if not item.is_empty():
				inputs.append(item)
	return inputs

func get_available_recipes(input_items: Array[Dictionary]) -> Array[FabricatorRecipe]:
	"""Get recipes that can be made with current input items"""
	return recipe_db.get_matching_recipes(input_items) if recipe_db else []

func get_max_craftable(recipe: FabricatorRecipe, input_items: Array[Dictionary]) -> int:
	"""Get maximum number of items that can be crafted with current materials"""
	return recipe_db.get_max_craftable(recipe, input_items) if recipe_db and recipe else 0

func get_last_completed_recipe() -> FabricatorRecipe:
	"""Get the last completed recipe (for UI restoration)"""
	return last_completed_recipe
