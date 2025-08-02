extends StaticBody2D
class_name FabricatorModule

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)
signal fabrication_progress_updated(progress: float)

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

# Fabrication processing variables
var current_recipe: FabricatorRecipe = null
var current_quantity: int = 0
var fabrication_timer: float = 0.0
var total_fabrication_time: float = 0.0
var last_completed_recipe: FabricatorRecipe = null  # Store for UI restoration

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

func _process(delta: float):
	if is_processing and current_recipe:
		fabrication_timer += delta
		
		# Calculate progress (0.0 to 1.0)
		var progress = fabrication_timer / total_fabrication_time
		
		# Update animation frame based on progress
		_update_process_animation_frame(progress)
		
		# Emit progress signal if UI is open
		if ui_instance:
			fabrication_progress_updated.emit(progress)
		
		# Check if fabrication is complete
		if fabrication_timer >= total_fabrication_time:
			_complete_fabrication()

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
	return recipe_db.get_matching_recipes(input_items)

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
		# If fabrication is complete (frame 9), allow opening with door animation
		if fabricator_sprite.frame == 9:
			# Fabrication is done, player can open to collect (with door animation)
			open_with_door_animation()
			return
		else:
			# Still processing, show message
			print("Fabrication in progress... Please wait.")
			return
	
	if anim_busy:
		return
		
	if ui_instance:
		close()
	else:
		open()  # Normal open without door animation

# -------------------- UI MANAGEMENT --------------------
func open():
	# Normal open without door animation (instant)
	if ui_instance or anim_busy or fabricator_ui_scene == null:
		return

	interaction_prompt.visible = false
	
	# Instantiate & wire the UI immediately
	ui_instance = fabricator_ui_scene.instantiate() as FabricatorUI
	ui_instance.set_module_ref(self)  # Pass module reference to UI

	UIManager.add_ui(ui_instance)
	UIManager.register_ui(ui_instance)
	emit_signal("module_opened", ui_instance)

func open_with_door_animation():
	# Special open for when fabrication is complete (with door animation)
	if ui_instance or anim_busy or fabricator_ui_scene == null:
		return

	interaction_prompt.visible = false
	anim_busy = true

	var cb = Callable(self, "_on_door_opened_for_ui_after_fabrication")
	if not fabricator_sprite.is_connected("animation_finished", cb):
		fabricator_sprite.connect("animation_finished", cb)

	# Play door opening animation (reverse)
	fabricator_sprite.play("door", -1.0, true)

func _on_door_opened_for_ui_after_fabrication() -> void:
	fabricator_sprite.disconnect("animation_finished", Callable(self, "_on_door_opened_for_ui_after_fabrication"))
	
	# Now that door is open, show static_open
	fabricator_sprite.play("static_open")
	
	# Instantiate & wire the UI
	ui_instance = fabricator_ui_scene.instantiate() as FabricatorUI
	ui_instance.set_module_ref(self)  # Pass module reference to UI

	UIManager.add_ui(ui_instance)
	UIManager.register_ui(ui_instance)
	emit_signal("module_opened", ui_instance)
	
	# Clear the last completed recipe since we've now opened the UI
	clear_last_completed_recipe()
	
	anim_busy = false

func close():
	# Normal close without door animation (instant)
	if ui_instance == null:
		return

	# Tear down UI immediately
	UIManager.unregister_ui(ui_instance)
	ui_instance.queue_free()
	ui_instance = null
	emit_signal("closed")

	interaction_prompt.visible = true

# -------------------- FABRICATION PROCESS --------------------
func start_fabrication(recipe: FabricatorRecipe, quantity: int):
	if is_processing or anim_busy or not recipe:
		return
	
	# Validate recipe with current inputs
	if not validate_recipe(recipe, quantity):
		print("Cannot start fabrication: insufficient materials")
		return

	print("Starting fabrication: ", recipe.output_item.name, " x", quantity)
	
	# Consume input materials
	_consume_recipe_materials(recipe, quantity)
	
	# Start the fabrication timer
	current_recipe = recipe
	current_quantity = quantity
	is_processing = true
	fabrication_timer = 0.0
	total_fabrication_time = recipe.fab_time * quantity
	
	# Close UI first
	if ui_instance:
		close()
	
	# Play door closing animation, then start processing
	anim_busy = true
	var cb = Callable(self, "_on_door_closed_for_fabrication")
	if not fabricator_sprite.is_connected("animation_finished", cb):
		fabricator_sprite.connect("animation_finished", cb)

	fabricator_sprite.play("door")

func _on_door_closed_for_fabrication() -> void:
	fabricator_sprite.disconnect("animation_finished", Callable(self, "_on_door_closed_for_fabrication"))
	
	# Now start the process animation
	fabricator_sprite.play("process")
	fabricator_sprite.pause()  # Pause so we can control frames manually
	fabricator_sprite.frame = 0  # Start at frame 0
	
	anim_busy = false

func _consume_recipe_materials(recipe: FabricatorRecipe, quantity: int):
	# Remove materials from input slots
	for i in range(recipe.get_ingredient_count()):
		var required_item = recipe.get_ingredient_item(i)
		var required_quantity = recipe.get_ingredient_quantity(i) * quantity
		
		# Find and consume from inventory
		for slot_index in range(inventory.size()):
			if slot_index != 3:  # Skip output slot (assuming slot 3 is output)
				var slot_item = inventory[slot_index]
				if slot_item and slot_item["id"] == required_item:
					slot_item["quantity"] -= required_quantity
					if slot_item["quantity"] <= 0:
						inventory[slot_index] = null
					slot_updated.emit(slot_index)
					required_quantity = 0
					break
		
		if required_quantity > 0:
			push_error("Failed to consume required materials for fabrication!")

func _complete_fabrication():
	# Produce the output item
	var output_slot_index = _get_output_slot_index()
	var output_item = inventory[output_slot_index]
	var total_output = current_recipe.output_quantity * current_quantity
	
	if output_item == null:
		inventory[output_slot_index] = {
			"id": current_recipe.output_item,
			"quantity": total_output
		}
	else:
		# Stack with existing items
		output_item["quantity"] += total_output
	
	slot_updated.emit(output_slot_index)
	
	# Keep the animation at frame 9 (complete state)
	fabricator_sprite.frame = 9
	
	# Store the completed recipe for potential UI restoration
	last_completed_recipe = current_recipe
	
	# Reset fabrication state
	is_processing = false
	current_recipe = null
	current_quantity = 0
	fabrication_timer = 0.0
	total_fabrication_time = 0.0
	
	print("Fabrication complete!")

func _update_process_animation_frame(progress: float):
	if not fabricator_sprite or fabricator_sprite.animation != "process":
		return
	
	# Map progress (0.0-1.0) to frame (0-9)
	# Clamp to ensure we don't exceed frame 9
	var frame_index = int(progress * 9.0)
	frame_index = clamp(frame_index, 0, 9)
	
	fabricator_sprite.frame = frame_index

func _get_output_slot_index() -> int:
	# Find output slot based on slot_type_map or default to slot 3
	return 3  # Based on your current setup

# -------------------- HELPER FUNCTIONS --------------------
func get_last_completed_recipe() -> FabricatorRecipe:
	return last_completed_recipe

func clear_last_completed_recipe():
	last_completed_recipe = null

func _get_current_input_items() -> Array[Dictionary]:
	var inputs: Array[Dictionary] = []
	
	# Collect all input items (assuming slot 3 is output)
	for i in range(inventory.size()):
		if i != 3:  # Skip output slot
			var item = inventory[i]
			if item != null:
				inputs.append(item)
	
	return inputs
