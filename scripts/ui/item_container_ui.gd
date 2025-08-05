# scripts/ui/item_container_ui.gd
# UPDATED VERSION - Uses consolidated UIManager instead of separate managers
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

# Reference to module with component-based inventory
var inventory_data_ref = null

# Performance optimization for hover states
var last_mouse_pos: Vector2 = Vector2.ZERO

# ------------------------------------------------------------------
# INITIALIZATION
# ------------------------------------------------------------------
func _ready():
	await get_tree().process_frame
	grid_containers = find_all_grid_containers(self)
	if grid_containers.is_empty():
		push_error("[ItemContainerUI] No GridContainer found in %s" % name)
		return

	_store_grid_container_configs()

	if inventory_data_ref:
		_inventory_refresh()
		_connect_inventory_signals()

	_connect_ui_closed_signals()

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
			"original_children": [],
			"slot_count": 0
		}
		
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
	if not (node is Button):
		return false
	
	return node.has_method("get_slot_sprite") or node.has_method("get_icon") or node.has_method("get_quantity")

func _connect_inventory_signals():
	var inventory_component = _get_inventory_component()
	if inventory_component and inventory_component.has_signal("slot_updated"):
		if not inventory_component.slot_updated.is_connected(update_slot):
			inventory_component.slot_updated.connect(update_slot)

func _connect_ui_closed_signals():
	var modules = get_tree().get_nodes_in_group("interactable_modules")
	for module in modules:
		if module.has_signal("closed") and not module.closed.is_connected(_on_ui_closed):
			module.closed.connect(_on_ui_closed)

# ------------------------------------------------------------------
# COMPONENT ACCESS HELPERS
# ------------------------------------------------------------------
func _get_inventory_component():
	"""Get the inventory component from the module"""
	if not inventory_data_ref:
		return null
	
	# Direct component access via get_node
	if inventory_data_ref.has_method("get_node_or_null"):
		return inventory_data_ref.get_node_or_null("Inventory")
	
	# Component property access
	if "inventory" in inventory_data_ref:
		return inventory_data_ref.inventory
	
	return null

func _get_inventory_data() -> Array:
	"""Get inventory data array from component"""
	var inventory_component = _get_inventory_component()
	if inventory_component and "inventory" in inventory_component:
		return inventory_component.inventory
	return []

func _get_inventory_size() -> int:
	"""Get inventory size from component"""
	var inventory_component = _get_inventory_component()
	if inventory_component and "inventory_size" in inventory_component:
		return inventory_component.inventory_size
	return 0

# ------------------------------------------------------------------
# INVENTORY UPDATES & UI HANDLING
# ------------------------------------------------------------------
func _inventory_refresh():
	if not inventory_data_ref:
		push_warning("[ItemContainerUI] No inventory_data_ref set")
		return

	var inv_size = _get_inventory_size()
	var current_inventory_index = 0
	
	for grid_index in range(grid_containers.size()):
		var grid_container = grid_containers[grid_index]
		if not grid_container:
			continue
			
		var config = grid_container_configs.get(grid_index, {})
		var slots_for_this_grid = config.get("slot_count", _calculate_default_slots_for_grid(grid_index, inv_size, current_inventory_index))
		var start_inv_index = config.get("start_inventory_index", current_inventory_index)
		
		_rebuild_grid_container(grid_container, config, slots_for_this_grid, start_inv_index)
		current_inventory_index += slots_for_this_grid

func _rebuild_grid_container(grid_container: GridContainer, config: Dictionary, _slot_count: int, start_inventory_index: int):
	var slots_to_cleanup: Array = []
	
	# Remove all children, queue slots for cleanup
	while grid_container.get_child_count() > 0:
		var child = grid_container.get_child(0)
		grid_container.remove_child(child)
		if _is_slot_node(child):
			slots_to_cleanup.append(child)
	
	if slots_to_cleanup.size() > 0:
		call_deferred("_cleanup_old_slots", slots_to_cleanup)

	var original_children = config.get("original_children", [])
	var inventory_data = _get_inventory_data()
	var inventory_index_counter = start_inventory_index
	
	# Rebuild in original order
	for child_info in original_children:
		if child_info.is_slot:
			if inventory_index_counter >= inventory_data.size():
				continue
				
			var slot_type = slot_type_map.get(inventory_index_counter, "input")
			var new_slot = null
			
			if slot_type == "output":
				new_slot = output_slot_template.instantiate() if output_slot_template else null
			else:
				new_slot = slot_template.instantiate() if slot_template else null

			if not new_slot:
				continue

			if new_slot.has_signal("gui_input"):
				new_slot.gui_input.connect(_on_slot_gui_input.bind(new_slot))

			grid_container.add_child(new_slot)

			# Display the item
			var real_item = inventory_data[inventory_index_counter]
			if real_item != null:
				set_item(new_slot, real_item)
			else:
				set_empty(new_slot)
			
			inventory_index_counter += 1
		else:
			# Re-add original non-slot node
			var original_node = child_info.node
			if original_node and is_instance_valid(original_node):
				grid_container.add_child(original_node)

func _cleanup_old_slots(slots: Array):
	for slot in slots:
		if slot and is_instance_valid(slot):
			slot.queue_free()

func _calculate_default_slots_for_grid(grid_index: int, total_inventory_size: int, current_inventory_index: int) -> int:
	var config = grid_container_configs.get(grid_index, {})
	var original_slot_count = 0
	
	var original_children = config.get("original_children", [])
	for child_info in original_children:
		if child_info.is_slot:
			original_slot_count += 1
	
	if original_slot_count > 0:
		return original_slot_count
	
	# Fallback: distribute remaining slots
	var remaining_grids = grid_containers.size() - grid_index
	var remaining_slots = total_inventory_size - current_inventory_index
	
	if remaining_grids <= 0:
		return 0
	
	return ceili(float(remaining_slots) / float(remaining_grids))

func update_slot(index: int) -> void:
	if not inventory_data_ref:
		push_error("[ItemContainerUI] Cannot update slot: no inventory_data_ref")
		return
	
	var inventory_data = _get_inventory_data()
	var inventory_size = _get_inventory_size()
	
	if index < 0 or index >= inventory_size:
		push_error("[ItemContainerUI] Invalid slot index: %d (inventory size: %d)" % [index, inventory_size])
		return
	
	var slot = get_slot_by_global_index(index)
	if not slot:
		push_warning("[ItemContainerUI] Could not find slot for index %d" % index)
		return

	var real_item = inventory_data[index] if index < inventory_data.size() else null
	if real_item != null:
		set_item(slot, real_item)
	else:
		set_empty(slot)

func _on_ui_closed():
	if UIManager and UIManager.dragging:
		UIManager.cancel_drag()

# ------------------------------------------------------------------
# SLOT INTERACTION - UPDATED TO USE CONSOLIDATED UIMANAGER
# ------------------------------------------------------------------
func _on_slot_gui_input(event: InputEvent, slot: Button):
	if not event or not slot:
		return
		
	if event is InputEventMouseButton and event.pressed:
		var index = get_slot_global_index(slot)
		if index < 0:
			return
		
		# SHIFT + LEFT CLICK
		if event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT):
			if UIManager:
				UIManager.shift_click(self, index)
			return

		# Normal drag logic - Now using consolidated UIManager
		if UIManager:
			if UIManager.is_dragging():
				if event.button_index == MOUSE_BUTTON_RIGHT:
					UIManager.partial_drop(self, slot)
				elif event.button_index == MOUSE_BUTTON_LEFT:
					UIManager.full_drop(self, slot)
			else:
				if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
					UIManager.start_drag(self, slot, event)

# ------------------------------------------------------------------
# SLOT VISUALS (OPTIMIZED)
# ------------------------------------------------------------------
func _process(_delta):
	var current_mouse_pos = get_viewport().get_mouse_position()
	if current_mouse_pos.distance_to(last_mouse_pos) < GameConstants.MOUSE_MOVE_THRESHOLD:
		return
	last_mouse_pos = current_mouse_pos
	
	_update_hover_states()

func _update_hover_states():
	var hovered_slot = get_slot_under_mouse()
	
	for grid_container in grid_containers:
		if not grid_container:
			continue
			
		for child in grid_container.get_children():
			if not _is_slot_node(child):
				continue
				
			var slot = child as Button
			if not slot or not slot.has_method("get_slot_sprite"):
				continue
			
			var slot_sprite = slot.get_slot_sprite()
			if not slot_sprite:
				continue

			# Check if this is the drag source slot - Updated to use UIManager
			var is_drag_source = false
			if UIManager and UIManager.dragging:
				var global_index = get_slot_global_index(slot)
				if UIManager.original_source_container == self and global_index == UIManager.original_source_index:
					is_drag_source = true

			if is_drag_source:
				slot_sprite.texture = ui_slot_drag
			elif slot == hovered_slot:
				slot_sprite.texture = ui_slot_hover
			else:
				slot_sprite.texture = ui_slot

# ------------------------------------------------------------------
# SLOT LOOKUP & UTILITIES
# ------------------------------------------------------------------
func get_slot_global_index(slot: Control) -> int:
	if not slot:
		return -1
	
	var global_index = 0
	for grid_container in grid_containers:
		if not grid_container:
			continue
			
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
		if not grid_container:
			continue
			
		for child in grid_container.get_children():
			if _is_slot_node(child):
				if current_index == global_index:
					return child as Button
				current_index += 1
	return null

func get_slot_under_mouse() -> Button:
	var mouse_pos = get_viewport().get_mouse_position()
	for grid_container in grid_containers:
		if not grid_container:
			continue
			
		for child in grid_container.get_children():
			if not _is_slot_node(child):
				continue
			var slot_control := child as Control
			if not slot_control:
				continue
				
			if Rect2(slot_control.global_position, slot_control.size).has_point(mouse_pos):
				return slot_control as Button
	return null

func get_active_other_ui() -> ItemContainerUI:
	var ui_nodes = get_tree().get_nodes_in_group("interactable_ui")
	for ui in ui_nodes:
		if ui is ItemContainerUI and ui != self and ui.visible:
			return ui as ItemContainerUI
	return null

# ------------------------------------------------------------------
# SLOT VISUAL HELPERS
# ------------------------------------------------------------------
func set_empty(slot: Button):
	if not slot:
		return
		
	var icon = slot.get_icon()
	var quantity = slot.get_quantity()
	if icon:
		icon.texture = null
	if quantity:
		quantity.text = ""

func set_item(slot: Button, new_item: Dictionary) -> void:
	if not slot or not new_item:
		return

	var icon = slot.get_icon()
	var quantity = slot.get_quantity()
	var item_res = new_item.get("id", null)

	if icon:
		if item_res is ItemResource:
			icon.texture = item_res.texture
		else:
			icon.texture = null

	if quantity:
		quantity.text = str(new_item.get("quantity", 0))

# ------------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------------
func set_slot_type_map(map: Dictionary) -> void:
	slot_type_map = map

func set_grid_container_config(grid_index: int, slot_count: int, start_inventory_index: int = 0):
	if grid_index < 0 or grid_index >= grid_containers.size():
		push_error("[ItemContainerUI] Invalid grid_index: %d" % grid_index)
		return
		
	if slot_count < 0:
		push_error("[ItemContainerUI] Invalid slot_count: %d" % slot_count)
		return
		
	if not grid_container_configs.has(grid_index):
		grid_container_configs[grid_index] = {"original_children": []}
	
	grid_container_configs[grid_index].slot_count = slot_count
	grid_container_configs[grid_index].start_inventory_index = start_inventory_index
