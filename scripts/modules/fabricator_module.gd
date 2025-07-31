extends StaticBody2D
class_name FabricatorModule

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)

@export var fabricator_ui_scene: PackedScene
@export var interaction_prompt: Control
@export var interaction_area: Area2D
@export var fabricator_sprite: AnimatedSprite2D

@onready var recipe_db := FabricatorRecipeDatabase.new()

var inventory: Array = []
var inventory_size := 0
var ui_instance: FabricatorUI = null
var is_processing := false
var anim_busy := false

func _ready():
	add_to_group("interactable_modules")
	interaction_prompt.visible = false
	interaction_prompt.z_index = 999
	fabricator_sprite.play("static_open")
	set_inventory_size(4)
	
	# Load recipes (like FurnaceModule does)
	recipe_db.load_all_recipes()
	
	# Debug: Print loaded recipes
	print("=== FABRICATOR DEBUG ===")
	print("Loaded recipes: ", recipe_db.recipes.size())
	for recipe in recipe_db.recipes:
		print("Recipe: ", recipe.output_item.name)
		print("  - Inputs required: ", recipe.input_items.size())
		for i in range(recipe.get_ingredient_count()):
			var item = recipe.get_ingredient_item(i)
			var qty = recipe.get_ingredient_quantity(i)
			print("    * ", item.name, " x", qty)

func set_inventory_size(size: int) -> void:
	inventory_size = size
	inventory.resize(size)

# -------------------- INVENTORY MANAGEMENT WITH SIGNALS --------------------
# This function should be called whenever the inventory changes
func update_inventory_slot(index: int, new_item: Dictionary = {}):
	if index >= 0 and index < inventory.size():
		if new_item.is_empty():
			inventory[index] = null
		else:
			inventory[index] = new_item
		
		# Emit signal so UI can update
		slot_updated.emit(index)
		print("Slot ", index, " updated: ", inventory[index])

# Helper function to add/remove items (with signal emission)
func add_item_to_slot(index: int, item: Dictionary) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	
	inventory[index] = item
	slot_updated.emit(index)
	return true

func remove_item_from_slot(index: int) -> Dictionary:
	if index < 0 or index >= inventory.size():
		return {}
	
	var removed_item = inventory[index] if inventory[index] else {}
	inventory[index] = null
	slot_updated.emit(index)
	return removed_item

# -------------------- RECIPE ACCESS FOR UI --------------------
func get_available_recipes(input_items: Array[Dictionary]) -> Array[FabricatorRecipe]:
	print("=== CHECKING AVAILABLE RECIPES ===")
	print("Current input items: ", input_items.size())
	for item in input_items:
		print("  - ", item["id"].name if item["id"] else "null", " x", item.get("quantity", 0))
	
	var matches = recipe_db.get_matching_recipes(input_items)
	print("Matching recipes: ", matches.size())
	for recipe in matches:
		print("  - Can make: ", recipe.output_item.name)
	
	return matches

func get_max_craftable(recipe: FabricatorRecipe, input_items: Array[Dictionary]) -> int:
	return recipe_db.get_max_craftable(recipe, input_items)

func validate_recipe(recipe: FabricatorRecipe, quantity: int) -> bool:
	var input_items = _get_current_input_items()
	var max_possible = recipe_db.get_max_craftable(recipe, input_items)
	return max_possible >= quantity

# -------------------- INTERACTION --------------------
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.append(self)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.erase(self)
		if ui_instance:
			close()

func interact():
	if is_processing:
		# TODO: Show progress popup
		return
	
	if anim_busy:
		return
		
	if ui_instance:
		close()
	else:
		open()

# -------------------- UI MANAGEMENT --------------------
func open():
	if ui_instance or is_processing or anim_busy or fabricator_ui_scene == null:
		return

	interaction_prompt.visible = false
	anim_busy = true

	var cb = Callable(self, "_on_door_closed_for_ui")
	if not fabricator_sprite.is_connected("animation_finished", cb):
		fabricator_sprite.connect("animation_finished", cb)

	fabricator_sprite.play("door")

func _on_door_closed_for_ui() -> void:
	fabricator_sprite.disconnect("animation_finished", Callable(self, "_on_door_closed_for_ui"))

	# Instantiate & wire the UI
	ui_instance = fabricator_ui_scene.instantiate() as FabricatorUI
	ui_instance.set_module_ref(self)  # Pass module reference to UI

	UIManager.add_ui(ui_instance)
	UIManager.register_ui(ui_instance)
	emit_signal("module_opened", ui_instance)

	# Open door
	var open_cb = Callable(self, "_on_door_opened_for_ui")
	if not fabricator_sprite.is_connected("animation_finished", open_cb):
		fabricator_sprite.connect("animation_finished", open_cb)
	
	fabricator_sprite.play("door", -1.0, true)

func _on_door_opened_for_ui() -> void:
	fabricator_sprite.disconnect("animation_finished", Callable(self, "_on_door_opened_for_ui"))
	fabricator_sprite.play("static_open")
	anim_busy = false

func close():
	if ui_instance == null or anim_busy:
		return

	# Tear down UI
	UIManager.unregister_ui(ui_instance)
	ui_instance.queue_free()
	ui_instance = null
	emit_signal("closed")

	anim_busy = true

	var cb = Callable(self, "_on_door_opened_after_close")
	if not fabricator_sprite.is_connected("animation_finished", cb):
		fabricator_sprite.connect("animation_finished", cb)

	fabricator_sprite.play("door", -1.0, true)

func _on_door_opened_after_close() -> void:
	fabricator_sprite.disconnect("animation_finished", Callable(self, "_on_door_opened_after_close"))
	fabricator_sprite.play("static_open")
	interaction_prompt.visible = true
	anim_busy = false

# -------------------- FABRICATION PROCESS --------------------
func start_fabrication(recipe: FabricatorRecipe, quantity: int):
	if is_processing or anim_busy or not recipe:
		return
	
	# Validate recipe with current inputs
	if not validate_recipe(recipe, quantity):
		print("Cannot start fabrication: insufficient materials")
		return

	print("Starting fabrication: ", recipe.output_item.name, " x", quantity)
	
	# TODO: Implement full fabrication process
	# For now, just close UI
	if ui_instance:
		close()

# -------------------- HELPER FUNCTIONS --------------------
func _get_current_input_items() -> Array[Dictionary]:
	var inputs: Array[Dictionary] = []
	
	# Collect all input items (assuming slot 3 is output)
	for i in range(inventory.size()):
		if i != 3:  # Skip output slot
			var item = inventory[i]
			if item != null:
				inputs.append(item)
	
	return inputs
