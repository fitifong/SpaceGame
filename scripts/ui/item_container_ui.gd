extends Control
class_name ItemContainerUI

@export var slot_template: PackedScene
@export var output_slot_template: PackedScene
@onready var grid_containers: Array[GridContainer] = []

# UI slot textures
@export var ui_slot: Texture2D
@export var ui_slot_hover: Texture2D
@export var ui_slot_drag: Texture2D

var slot_type_map := {}  # e.g. {0: "input", 1: "output"}
var grid_container_configs := {}  # Configuration for each grid container

# Reference to an InventoryManager for this container (e.g. player inv, storage inv)
var inventory_data_ref = null

# ------------------------------------------------------------------
# 🟢 INITIALIZATION
# ------------------------------------------------------------------
func _ready():
	await get_tree().process_frame  # Wait 1 frame so nodes exist
	grid_containers = find_all_grid_containers(self)
	if grid_containers.is_empty():
		push_error("[ERROR] No GridContainer found in %s" % name)
		return

	# Store initial configurations of each grid container
	_store_grid_container_configs()

	if inventory_data_ref:
		_inventory_refresh()
		inventory_data_ref.slot_updated.connect(update_slot)

	# Connect to "closed" signals to cancel drag
	var modules = get_tree().get_nodes_in_group("interactable_modules")
	for module in modules:
		if module.has_signal("closed") and not module.closed.is_connected(_on_ui_closed):
			module.closed.connect(_on_ui_closed)

func find_all_grid_containers(node: Node) -> Array[GridContainer]:
	var containers: Array[GridContainer] = []
	
	for child in node.get_children():
		if child is GridContainer:
			containers.append(child)
		elif child is Control and child.get_child_count() > 0:
			var found_containers = find_all_grid_containers(child)
			containers.append_array(found_containers)
	
	return containers

func _store_grid_container_configs():
	for i in range(grid_containers.size()):
		var grid_container = grid_containers[i]
		var config = {
			"original_children": [],  # Stores all children with their types and positions
			"slot_count": 0
		}
		
		# Store all existing children with their information
		for j in range(grid_container.get_child_count()):
			var child = grid_container.get_child(j)
			var child_info = {
				"node": child,
				"position": j,
				"is_slot": _is_slot_node(child),
				"parent": grid_container
			}
			
			config.original_children.append(child_info)
			if child_info.is_slot:
				config.slot_count += 1
		
		grid_container_configs[i] = config

func _is_slot_node(node: Node) -> bool:
	# Check if this node appears to be a slot based on common slot characteristics
	if not (node is Button):
		return false
	
	# Check for slot-specific methods
	if node.has_method("get_slot_sprite") or node.has_method("get_icon") or node.has_method("get_quantity"):
		return true
	
	return false

func set_slot_type_map(map: Dictionary) -> void:
	slot_type_map = map

# Set specific configuration for each grid container
func set_grid_container_config(grid_index: int, slot_count: int, start_inventory_index: int = 0):
	if grid_index >= 0 and grid_index < grid_containers.size():
		if not grid_container_configs.has(grid_index):
			grid_container_configs[grid_index] = {"original_children": []}
		
		grid_container_configs[grid_index].slot_count = slot_count
		grid_container_configs[grid_index].start_inventory_index = start_inventory_index

# ------------------------------------------------------------------
# 🔵 INVENTORY UPDATES & UI HANDLING
# ------------------------------------------------------------------
func _inventory_refresh():
	if inventory_data_ref == null:
		return

	var inv_size = inventory_data_ref.inventory.size()
	var current_inventory_index = 0
	
	for grid_index in range(grid_containers.size()):
		var grid_container = grid_containers[grid_index]
		var config = grid_container_configs.get(grid_index, {})
		
		# Determine how many slots this grid should have
		var slots_for_this_grid = config.get("slot_count", _calculate_default_slots_for_grid(grid_index, inv_size, current_inventory_index))
		var start_inv_index = config.get("start_inventory_index", current_inventory_index)
		
		# Clear and rebuild the grid container properly
		_rebuild_grid_container(grid_container, config, slots_for_this_grid, start_inv_index)
		
		# Update current inventory index for next grid
		current_inventory_index += slots_for_this_grid

func _rebuild_grid_container(grid_container: GridContainer, config: Dictionary, slot_count: int, start_inventory_index: int):
	# Remove all children first
	while grid_container.get_child_count() > 0:
		var child = grid_container.get_child(0)
		grid_container.remove_child(child)
		if _is_slot_node(child):
			child.queue_free()  # Free old slots
		# Keep non-slot nodes alive for re-adding
	
	var original_children = config.get("original_children", [])
	var inventory_index_counter = start_inventory_index
	
	# Rebuild in original order
	for child_info in original_children:
		if child_info.is_slot:
			# Create a new slot to replace the original
			if inventory_index_counter >= inventory_data_ref.inventory.size():
				# No more inventory items, skip this slot
				continue
				
			var slot_type = slot_type_map.get(inventory_index_counter, "input")
			var new_slot = null
			
			if slot_type == "output":
				new_slot = output_slot_template.instantiate()
			else:
				new_slot = slot_template.instantiate()

			if not new_slot.has_method("get_slot_sprite"):
				push_warning("Slot template missing get_slot_sprite() method.")

			new_slot.gui_input.connect(_on_slot_gui_input.bind(new_slot))
			grid_container.add_child(new_slot)

			# Display the item
			var real_item = inventory_data_ref.inventory[inventory_index_counter]
			if real_item != null:
				set_item(new_slot, real_item)
			else:
				set_empty(new_slot)
			
			inventory_index_counter += 1
		else:
			# Re-add the original non-slot node
			var original_node = child_info.node
			if original_node and is_instance_valid(original_node):
				grid_container.add_child(original_node)

func _calculate_default_slots_for_grid(grid_index: int, total_inventory_size: int, current_inventory_index: int) -> int:
	# Use the original slot count from the editor if available
	var config = grid_container_configs.get(grid_index, {})
	var original_slot_count = 0
	
	var original_children = config.get("original_children", [])
	for child_info in original_children:
		if child_info.is_slot:
			original_slot_count += 1
	
	if original_slot_count > 0:
		return original_slot_count
	
	# Fallback: distribute remaining slots evenly among remaining grids
	var remaining_grids = grid_containers.size() - grid_index
	var remaining_slots = total_inventory_size - current_inventory_index
	
	if remaining_grids <= 0:
		return 0
	
	return ceili(float(remaining_slots) / float(remaining_grids))

func _restore_non_slot_nodes(grid_container: GridContainer, config: Dictionary):
	var non_slot_nodes = config.get("non_slot_nodes", [])
	for node_info in non_slot_nodes:
		var node = node_info.node
		if node and is_instance_valid(node) and node.get_parent() != grid_container:
			grid_container.add_child(node)

func update_slot(index: int) -> void:
	if inventory_data_ref == null:
		return
	if index < 0 or index >= inventory_data_ref.inventory.size():
		return
	
	var slot = get_slot_by_global_index(index)
	if slot == null:
		return

	var real_item = inventory_data_ref.inventory[index]
	if real_item != null:
		set_item(slot, real_item)
	else:
		set_empty(slot)

func clear_all_slot_containers():
	for grid_index in range(grid_containers.size()):
		var grid_container = grid_containers[grid_index]
		
		# Only remove and free slot nodes, keep non-slot nodes
		var children_to_remove = []
		for child in grid_container.get_children():
			if _is_slot_node(child):
				children_to_remove.append(child)
		
		for child in children_to_remove:
			grid_container.remove_child(child)
			child.queue_free()

func _on_ui_closed():
	# If the user closes the UI, optionally cancel drag
	if DragManager.dragging:
		DragManager.cancel_drag()

# ------------------------------------------------------------------
# 🟠 SLOT INTERACTION
# ------------------------------------------------------------------
func _on_slot_gui_input(event: InputEvent, slot: Button):
	if event is InputEventMouseButton and event.pressed:
		var index = get_slot_global_index(slot)
		if index < 0:
			return  # Invalid slot
		
	   # SHIFT + LEFT CLICK
		if event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT):
			UiInteractionManager.shift_click(self, index)  # 🔹 Calls ShiftClickManager
			return

		# Otherwise do normal drag logic
		if UiInteractionManager.is_dragging():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				UiInteractionManager.partial_drop(self, slot)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				UiInteractionManager.full_drop(self, slot)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				UiInteractionManager.start_drag(self, slot, event)

	

# ------------------------------------------------------------------
# 🟡 PER-FRAME SLOT VISUALS (OPTIONAL)
# ------------------------------------------------------------------
func _process(_delta):
	var hovered_slot = get_slot_under_mouse()
	
	for grid_container in grid_containers:
		for child in grid_container.get_children():
			# Only process actual slot nodes
			if not _is_slot_node(child):
				continue
				
			var slot = child as Button
			
			# Skip slots without get_slot_sprite()
			if not slot.has_method("get_slot_sprite"):
				continue
			
			var slot_sprite = slot.get_slot_sprite()
			if not slot_sprite:
				continue

			# Is this slot the "original source slot" for the current drag?
			var is_drag_source = false
			if DragManager.dragging:
				# Check if the container is this UI, 
				# and if the slot global index is the same as original_source_index:
				var global_index = get_slot_global_index(slot)
				if DragManager.original_source_container == self and global_index == DragManager.original_source_index:
					is_drag_source = true

			if is_drag_source:
				slot_sprite.texture = ui_slot_drag
			elif slot == hovered_slot:
				slot_sprite.texture = ui_slot_hover
			else:
				slot_sprite.texture = ui_slot


# ------------------------------------------------------------------
# 🔵 SLOT LOOKUP & UTILITIES
# ------------------------------------------------------------------
func get_slot_global_index(slot: Control) -> int:
	if slot == null:
		return -1
	
	var global_index = 0
	for grid_container in grid_containers:
		for child in grid_container.get_children():
			if _is_slot_node(child):
				if child == slot:
					return global_index
				global_index += 1
	return -1

func get_slot_by_global_index(global_index: int) -> Button:
	if global_index < 0:
		return null
	
	var current_index = 0
	for grid_container in grid_containers:
		for child in grid_container.get_children():
			if _is_slot_node(child):
				if current_index == global_index:
					return child as Button
				current_index += 1
	return null

# Legacy function for backwards compatibility
func get_slot_index(slot: Control) -> int:
	return get_slot_global_index(slot)

func get_slot_button(index: int) -> Button:
	return get_slot_by_global_index(index)

func get_slot_under_mouse() -> Button:
	var mouse_pos = get_viewport().get_mouse_position()
	for grid_container in grid_containers:
		for child in grid_container.get_children():
			if not _is_slot_node(child):
				continue  # skip non-slot nodes
			var slot_control := child as Control
			if Rect2(slot_control.global_position, slot_control.size).has_point(mouse_pos):
				return slot_control as Button
	return null

func get_active_other_ui() -> ItemContainerUI:
	var ui_nodes = get_tree().get_nodes_in_group("interactable_ui")
	for ui in ui_nodes:
		# ui must be an ItemContainerUI, must be visible, and not 'self'
		if ui is ItemContainerUI and ui != self and ui.visible:
			return ui as ItemContainerUI
	return null

# ------------------------------------------------------------------
# 🔴 SLOT VISUAL HELPERS
# ------------------------------------------------------------------
func set_empty(slot: Button):
	if slot:
		var icon = slot.get_icon()
		var quantity = slot.get_quantity()
		if icon:
			icon.texture = null
		if quantity:
			quantity.text = ""

func set_item(slot: Button, new_item: Dictionary) -> void:
	if slot == null:
		return

	var icon      = slot.get_icon()
	var quantity  = slot.get_quantity()
	var item_res  = new_item.get("id", null)

	if icon:
		if item_res is ItemResource:
			icon.texture = item_res.texture
		else:
			icon.texture = null

	if quantity:
		quantity.text = str(new_item.get("quantity", 0))
