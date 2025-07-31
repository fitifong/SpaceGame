extends ItemContainerUI
class_name FabricatorUI

# -------------------- INVENTORY SLOTS --------------------
@export var input_slots: Array[Button] = []
@export var output_slot: Button

# -------------------- RECIPE CONTROLS --------------------
@export var make_button: Button
@export var recipe_selector: OptionButton
@export var quantity_spinbox: SpinBox
@export var preview_time_label: Label

var module_ref: FabricatorModule = null
var current_recipe: FabricatorRecipe = null
var available_recipes: Array[FabricatorRecipe] = []
var is_showing_preview := false

func _ready():
	add_to_group("interactable_ui")
	slot_type_map = {3: "output"}  # Assuming slot 3 is output
	super._ready()  # This sets up the inventory slots via ItemContainerUI
	visible = true

	# Connect UI signals (with null checks)
	if make_button:
		make_button.pressed.connect(_on_make_pressed)
	if recipe_selector:
		recipe_selector.item_selected.connect(_on_recipe_selected)
	if quantity_spinbox:
		quantity_spinbox.value_changed.connect(_on_quantity_changed)
	
	# Initial state
	_update_make_button_state()

# -------------------- MODULE CONNECTION --------------------
func set_module_ref(module: FabricatorModule) -> void:
	module_ref = module
	inventory_data_ref = module  # For ItemContainerUI compatibility
	
	# DON'T connect to slot_updated signal - we'll handle updates differently
	print("✅ Module reference set")
	
	# Initial recipe check
	_update_available_recipes()

# ⭐ REMOVED: No more signal connection to avoid infinite loops
# Instead, we'll override update_slot to directly update recipes

# ⭐ SIMPLIFIED: Override update_slot without signal emissions
func update_slot(index: int) -> void:
	print("🔄 FabricatorUI: Slot ", index, " updated")
	
	# Call parent update first (handles visual updates)
	super.update_slot(index)
	
	# ⭐ DIRECT UPDATE: Check recipes immediately without signals
	if slot_type_map.get(index, "input") == "input":
		print("📋 Input slot changed, updating recipes directly")
		_update_available_recipes()
	
	# Handle output slot preview state
	var output_slot_index = _get_output_slot_index()
	if index == output_slot_index:
		var actual_item = module_ref.inventory[index] if module_ref else null
		
		if actual_item != null:
			# Real item exists, clear preview
			is_showing_preview = false
			_set_output_slot_preview_style(false)
		elif current_recipe and not is_showing_preview:
			# No real item but have recipe selected, show preview
			_show_output_preview()

# -------------------- RECIPE MANAGEMENT --------------------
func _update_available_recipes():
	if not module_ref:
		return
	
	print("=== UPDATING AVAILABLE RECIPES ===")
	
	# Get current input items from module's actual inventory
	var input_items = _get_current_input_items()
	print("📦 Current input items: ", input_items.size())
	for item in input_items:
		if item.has("id") and item["id"]:
			print("  - ", item["id"].name, " x", item["quantity"])
	
	# ⭐ DIRECT CALL: Ask module for matching recipes (no signals involved)
	available_recipes = module_ref.get_available_recipes(input_items)
	print("🔍 Found ", available_recipes.size(), " matching recipes")
	
	# Update recipe dropdown (with null check)
	if recipe_selector:
		recipe_selector.clear()
		recipe_selector.add_item("Select Recipe...")
		
		for i in range(available_recipes.size()):
			var recipe = available_recipes[i]
			recipe_selector.add_item(recipe.output_item.name)
			print("➕ Added recipe: ", recipe.output_item.name)
	
	# Reset selection
	current_recipe = null
	_update_recipe_preview()
	_update_make_button_state()

func _get_current_input_items() -> Array[Dictionary]:
	var inputs: Array[Dictionary] = []
	
	if not module_ref:
		return inputs
	
	# Collect all non-output slots from the actual inventory
	for i in range(module_ref.inventory.size()):
		if slot_type_map.get(i, "input") == "input":
			var item = module_ref.inventory[i]
			if item != null:
				inputs.append(item)
	
	return inputs

# -------------------- RECIPE SELECTION & PREVIEW --------------------
func _on_recipe_selected(index: int):
	if index <= 0 or index > available_recipes.size():
		current_recipe = null
	else:
		current_recipe = available_recipes[index - 1]  # -1 because first item is "Select Recipe..."
	
	_update_recipe_preview()
	_update_quantity_limits()
	_update_make_button_state()

func _update_recipe_preview():
	if not current_recipe:
		_clear_preview()
		return
	
	# Show preview in output slot
	_show_output_preview()
	
	# Update time preview
	_update_time_preview()

func _clear_preview():
	# Clear time label
	if preview_time_label:
		preview_time_label.text = ""
	
	# Clear output slot preview
	_clear_output_preview()

func _show_output_preview():
	if not current_recipe or not output_slot:
		return
	
	var output_slot_index = _get_output_slot_index()
	var actual_item = module_ref.inventory[output_slot_index] if module_ref else null
	
	# If there's already a real item in the output slot, don't show preview
	if actual_item != null:
		is_showing_preview = false
		return
	
	# Show preview item in output slot
	var selected_quantity = int(quantity_spinbox.value) if quantity_spinbox else 1
	var total_output = current_recipe.output_quantity * selected_quantity
	
	# Create preview item data
	var preview_item = {
		"id": current_recipe.output_item,
		"quantity": total_output
	}
	
	# Display preview in output slot
	set_item(output_slot, preview_item)
	is_showing_preview = true
	
	# Make the slot visually distinct (preview state)
	_set_output_slot_preview_style(true)

func _clear_output_preview():
	if not output_slot:
		return
	
	var output_slot_index = _get_output_slot_index()
	var actual_item = module_ref.inventory[output_slot_index] if module_ref else null
	
	# Only clear if showing preview and no real item exists
	if is_showing_preview and actual_item == null:
		set_empty(output_slot)
		is_showing_preview = false
		_set_output_slot_preview_style(false)

func _set_output_slot_preview_style(is_preview: bool):
	if not output_slot:
		return
	
	if is_preview:
		# Make slot appear as preview (slightly transparent, different tint)
		output_slot.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
		
		# Add preview indicator if slot has a background
		var slot_sprite = output_slot.get_slot_sprite()
		if slot_sprite:
			slot_sprite.modulate = Color.CYAN  # Tint background cyan for preview
	else:
		# Normal slot appearance
		output_slot.modulate = Color.WHITE
		
		var slot_sprite = output_slot.get_slot_sprite()
		if slot_sprite:
			slot_sprite.modulate = Color.WHITE

# -------------------- QUANTITY & VALIDATION --------------------
func _update_quantity_limits():
	if not current_recipe or not module_ref:
		if quantity_spinbox:
			quantity_spinbox.max_value = 0
			quantity_spinbox.value = 0
		return
	
	var input_items = _get_current_input_items()
	var max_from_inputs = module_ref.get_max_craftable(current_recipe, input_items)
	
	# Also check output slot capacity (from actual inventory)
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
	return -1

func _get_output_slot_capacity(output_index: int) -> int:
	if output_index < 0 or not module_ref:
		return 0
	
	# Check actual inventory slot capacity
	var output_item = module_ref.inventory[output_index]
	
	if output_item == null:
		# Empty slot can hold up to 99
		return 99 / current_recipe.output_quantity
	elif output_item["id"] == current_recipe.output_item:
		# Same item, check remaining capacity
		var remaining_capacity = 99 - output_item["quantity"]
		return remaining_capacity / current_recipe.output_quantity
	else:
		# Different item, can't place anything
		return 0

# -------------------- TIME & STATE MANAGEMENT --------------------
func _on_quantity_changed(value: float):
	_update_time_preview()
	_update_make_button_state()
	# Update preview quantity in output slot
	if current_recipe:
		_show_output_preview()

func _update_time_preview():
	if not current_recipe or not preview_time_label:
		return
	
	var selected_quantity = int(quantity_spinbox.value) if quantity_spinbox else 1
	var total_time = current_recipe.fab_time * selected_quantity
	
	preview_time_label.text = "Time: %d seconds" % total_time

func _update_make_button_state():
	if not make_button:
		return
		
	var can_make = false
	
	if current_recipe and module_ref:
		var selected_quantity = quantity_spinbox.value if quantity_spinbox else 1
		if selected_quantity > 0:
			var input_items = _get_current_input_items()
			var max_craftable = module_ref.get_max_craftable(current_recipe, input_items)
			var output_capacity = _get_output_slot_capacity(_get_output_slot_index())
			
			can_make = (max_craftable >= selected_quantity and 
					   output_capacity >= selected_quantity)
	
	make_button.disabled = not can_make
	make_button.modulate = Color.WHITE if can_make else Color.GRAY

# -------------------- OVERRIDE SLOT INTERACTION FOR OUTPUT --------------------
# Override the slot interaction to prevent grabbing preview items
func _on_slot_gui_input(event: InputEvent, slot: Button):
	# If this is the output slot and showing preview, block interaction
	if slot == output_slot and is_showing_preview:
		if event is InputEventMouseButton and event.pressed:
			# Block all mouse interactions with preview
			return
	
	# Otherwise, use normal slot interaction
	super._on_slot_gui_input(event, slot)

# -------------------- FABRICATION TRIGGER --------------------
func _on_make_pressed():
	if not current_recipe or not module_ref:
		return
	
	var selected_quantity = int(quantity_spinbox.value) if quantity_spinbox else 1
	
	# Clear preview before starting fabrication
	_clear_output_preview()
	
	# Start fabrication via module
	module_ref.start_fabrication(current_recipe, selected_quantity)
