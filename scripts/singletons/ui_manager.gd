# scripts/ui_managers/ui_manager.gd
# CONSOLIDATED VERSION - Absorbs DragManager and ShiftClickManager functionality
extends Node

@export var ui_root: Node  # Drag your "GUIs" node into this in the editor

var active_ui_containers: Array = []

# =============================================================================
# DRAG MANAGEMENT (formerly DragManager)
# =============================================================================

# Core drag state
var dragging: bool = false
var drag_data := {"id": null, "quantity": 0}

# Source tracking for cancellation
var original_source_container: ItemContainerUI = null
var original_source_index: int = -1

# Visual representation
var dragged_visual: Control = null
var dragged_item_scene: PackedScene = preload("res://scenes/ui/dragged_item.tscn")

# =============================================================================
# UI REGISTRATION & MANAGEMENT
# =============================================================================

func register_ui(ui: Control) -> void:
	if ui and ui not in active_ui_containers:
		active_ui_containers.append(ui)

func unregister_ui(ui: Control) -> void:
	if ui in active_ui_containers:
		active_ui_containers.erase(ui)

func add_ui(ui: Control) -> void:
	if ui_root:
		ui_root.add_child(ui)
	else:
		push_error("[UIManager] ui_root not assigned. Cannot parent UI.")

func get_active_ui() -> Control:
	# Return the first visible UI that is *not* the PlayerInventoryUI
	for ui in active_ui_containers:
		if ui.visible and not (ui is PlayerInventoryUI):
			return ui
	return null

func get_inventory_ui() -> PlayerInventoryUI:
	for ui in active_ui_containers:
		if ui is PlayerInventoryUI:
			return ui
	return null

func is_ui_active() -> bool:
	return active_ui_containers.size() > 0

func clear_all_ui():
	active_ui_containers.clear()

func print_active_ui():
	print("Active UIs:", active_ui_containers)

# =============================================================================
# DRAG OPERATIONS
# =============================================================================

func is_dragging() -> bool:
	return dragging

func start_drag(container: ItemContainerUI, slot_button: Button, event: InputEventMouseButton) -> void:
	if dragging or not _validate_drag_start(container, slot_button, event):
		return
	
	var index = container.get_slot_global_index(slot_button)
	var source_item = _get_item_from_inventory(container.inventory_data_ref, index)
	if not source_item or source_item.is_empty():
		return
	
	# Ensure item ID is ItemResource
	_ensure_item_resource(source_item)
	
	# Calculate drag amount based on click type
	var drag_amount = _calculate_drag_amount(source_item, event.button_index)
	if drag_amount <= 0:
		return
	
	# Set up drag state
	_setup_drag_state(container, index, source_item, drag_amount)
	
	# Update source inventory
	_update_source_after_drag(source_item, drag_amount, container, index)
	
	# Create visual and start dragging
	_create_drag_visual()
	dragging = true

func cancel_drag():
	if not dragging or drag_data["quantity"] <= 0:
		end_drag()
		return
	
	_return_items_to_source()
	end_drag()

func end_drag():
	dragging = false
	drag_data = {"id": null, "quantity": 0}
	original_source_container = null
	original_source_index = -1
	
	if dragged_visual:
		dragged_visual.queue_free()
		dragged_visual = null

func partial_drop(container: ItemContainerUI, slot_button: Button) -> void:
	if not _validate_drop(container, slot_button):
		return
	
	_perform_drop(container, slot_button, 1)

func full_drop(container: ItemContainerUI, slot_button: Button) -> void:
	if not _validate_drop(container, slot_button):
		return
	
	_perform_drop(container, slot_button, drag_data["quantity"])

# =============================================================================
# SHIFT-CLICK TRANSFERS (formerly ShiftClickManager)
# =============================================================================

func shift_click(container: ItemContainerUI, slot_index: int) -> void:
	# Get inventory size using component-aware method
	var inventory_size = _get_inventory_size(container.inventory_data_ref)
	
	# Validate the container and slot index
	if container == null or slot_index < 0 or slot_index >= inventory_size:
		return

	var source_inv = container.inventory_data_ref
	var item_data = _get_item_from_inventory(source_inv, slot_index)
	if item_data == null or item_data.is_empty():
		return

	var target_ui: ItemContainerUI

	if container is PlayerInventoryUI:
		# from player → send to whatever other UI is open
		target_ui = get_active_ui() as ItemContainerUI
	else:
		# from ANY other UI → send back to the player inventory
		target_ui = get_inventory_ui()
	
	if target_ui == null or target_ui == container:
		return

	_transfer_item_between_inventories(source_inv, target_ui, slot_index)

func _transfer_item_between_inventories(source_inv, target_ui: ItemContainerUI, source_slot: int) -> void:
	var source_item = _get_item_from_inventory(source_inv, source_slot)
	if source_item == null or source_item.is_empty():
		return

	var moved_quantity = _attempt_stack_in_inventory(target_ui, source_item)
	source_item["quantity"] -= moved_quantity

	if source_item["quantity"] <= 0:
		_remove_item_from_inventory(source_inv, source_slot)
	else:
		_set_item_in_inventory(source_inv, source_slot, source_item)

	_emit_slot_updated(source_inv, source_slot)

func _attempt_stack_in_inventory(container: ItemContainerUI, item_data) -> int:
	var total_moved = 0
	var quantity_to_move = item_data["quantity"]
	var inventory_ref = container.inventory_data_ref
	var inventory_size = _get_inventory_size(inventory_ref)

	# Pass 1: Merge into existing stacks
	for i in range(inventory_size):
		if quantity_to_move <= 0:
			break
		
		var slot_item = _get_item_from_inventory(inventory_ref, i)

		if slot_item != null and not slot_item.is_empty() and slot_item["id"] == item_data["id"]:
			var slot_button = container.get_slot_by_global_index(i)
			if slot_button and "slot_type" in slot_button and slot_button.slot_type == "output":
				continue

			var capacity = GameConstants.MAX_STACK_SIZE - slot_item["quantity"]
			if capacity > 0:
				var move_amount = min(capacity, quantity_to_move)
				slot_item["quantity"] += move_amount
				quantity_to_move -= move_amount
				total_moved += move_amount
				_set_item_in_inventory(inventory_ref, i, slot_item)
				_emit_slot_updated(inventory_ref, i)

	# Pass 2: Place in empty slots
	for i in range(inventory_size):
		if quantity_to_move <= 0:
			break
		
		var slot_item = _get_item_from_inventory(inventory_ref, i)
		if slot_item == null or slot_item.is_empty():
			var slot_button = container.get_slot_by_global_index(i)
			if slot_button and "slot_type" in slot_button and slot_button.slot_type == "output":
				continue

			var move_amount = min(GameConstants.MAX_STACK_SIZE, quantity_to_move)
			var new_item = {
				"id": item_data["id"],
				"quantity": move_amount
			}
			_set_item_in_inventory(inventory_ref, i, new_item)
			quantity_to_move -= move_amount
			total_moved += move_amount
			_emit_slot_updated(inventory_ref, i)

	return total_moved

# =============================================================================
# COMPONENT-AWARE HELPER METHODS
# =============================================================================

func _get_item_from_inventory(inventory_ref, index: int) -> Dictionary:
	"""Get item from component-based or singleton inventory"""
	if not inventory_ref:
		return {}
	
	# Method 1: Component-based (modules)
	if inventory_ref.has_method("get_node_or_null"):
		var inventory_component = inventory_ref.get_node_or_null("Inventory")
		if inventory_component and inventory_component.has_method("get_item"):
			return inventory_component.get_item(index)
	
	# Method 2: Direct component property
	if "inventory" in inventory_ref and inventory_ref.inventory:
		if inventory_ref.inventory.has_method("get_item"):
			return inventory_ref.inventory.get_item(index)
	
	# Method 3: PlayerInventory singleton (component-based now)
	if inventory_ref == PlayerInventory and "inventory_component" in inventory_ref:
		if inventory_ref.inventory_component and inventory_ref.inventory_component.has_method("get_item"):
			return inventory_ref.inventory_component.get_item(index)
	
	return {}

func _set_item_in_inventory(inventory_ref, index: int, item: Dictionary):
	"""Set item in component-based or singleton inventory"""
	if not inventory_ref:
		return
	
	# Method 1: Component-based (modules)
	if inventory_ref.has_method("get_node_or_null"):
		var inventory_component = inventory_ref.get_node_or_null("Inventory")
		if inventory_component and inventory_component.has_method("add_item"):
			inventory_component.add_item(index, item)
			return
	
	# Method 2: Direct component property
	if "inventory" in inventory_ref and inventory_ref.inventory:
		if inventory_ref.inventory.has_method("add_item"):
			inventory_ref.inventory.add_item(index, item)
			return
	
	# Method 3: PlayerInventory singleton (component-based now)
	if inventory_ref == PlayerInventory and "inventory_component" in inventory_ref:
		if inventory_ref.inventory_component and inventory_ref.inventory_component.has_method("add_item"):
			inventory_ref.inventory_component.add_item(index, item)

func _remove_item_from_inventory(inventory_ref, index: int):
	"""Remove item from component-based or singleton inventory"""
	if not inventory_ref:
		return
	
	# Method 1: Component-based (modules)
	if inventory_ref.has_method("get_node_or_null"):
		var inventory_component = inventory_ref.get_node_or_null("Inventory")
		if inventory_component and inventory_component.has_method("remove_item"):
			inventory_component.remove_item(index)
			return
	
	# Method 2: Direct component property
	if "inventory" in inventory_ref and inventory_ref.inventory:
		if inventory_ref.inventory.has_method("remove_item"):
			inventory_ref.inventory.remove_item(index)
			return
	
	# Method 3: PlayerInventory singleton (component-based now)
	if inventory_ref == PlayerInventory and "inventory_component" in inventory_ref:
		if inventory_ref.inventory_component and inventory_ref.inventory_component.has_method("remove_item"):
			inventory_ref.inventory_component.remove_item(index)

func _get_inventory_size(inventory_ref) -> int:
	"""Get inventory size from component-based or singleton inventory"""
	if not inventory_ref:
		return 0
	
	# Method 1: Component-based (modules)
	if inventory_ref.has_method("get_node_or_null"):
		var inventory_component = inventory_ref.get_node_or_null("Inventory")
		if inventory_component and "inventory_size" in inventory_component:
			return inventory_component.inventory_size
	
	# Method 2: Direct component property
	if "inventory" in inventory_ref and inventory_ref.inventory:
		if "inventory_size" in inventory_ref.inventory:
			return inventory_ref.inventory.inventory_size
	
	# Method 3: PlayerInventory singleton (component-based now)
	if inventory_ref == PlayerInventory and "inventory_component" in inventory_ref:
		if inventory_ref.inventory_component and "inventory_size" in inventory_ref.inventory_component:
			return inventory_ref.inventory_component.inventory_size
	
	return 0

func _emit_slot_updated(inventory_ref, index: int):
	"""Emit slot_updated signal from inventory"""
	if not inventory_ref:
		return
	
	# All inventories should have this signal
	if inventory_ref.has_signal("slot_updated"):
		inventory_ref.slot_updated.emit(index)

func _update_slot(container: ItemContainerUI, index: int):
	"""Update a slot in the UI"""
	if container:
		container.update_slot(index)

# =============================================================================
# DRAG PRIVATE HELPER METHODS
# =============================================================================

func _validate_drag_start(container: ItemContainerUI, slot_button: Button, event: InputEventMouseButton) -> bool:
	return (container and slot_button and event and 
			container.inventory_data_ref and 
			event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT])

func _ensure_item_resource(source_item: Dictionary) -> void:
	if source_item["id"] is int:
		var item_resource = ItemDatabase.get_item_data(source_item["id"])
		if item_resource:
			source_item["id"] = item_resource

func _calculate_drag_amount(source_item: Dictionary, button: int) -> int:
	match button:
		MOUSE_BUTTON_LEFT:
			return source_item["quantity"]
		MOUSE_BUTTON_RIGHT:
			return ceili(source_item["quantity"] / 2.0)
		_:
			return 0

func _setup_drag_state(container: ItemContainerUI, index: int, source_item: Dictionary, amount: int) -> void:
	drag_data["id"] = source_item["id"]
	drag_data["quantity"] = amount
	original_source_container = container
	original_source_index = index

func _update_source_after_drag(source_item: Dictionary, drag_amount: int, container: ItemContainerUI, index: int) -> void:
	source_item["quantity"] -= drag_amount
	if source_item["quantity"] <= 0:
		_remove_item_from_inventory(container.inventory_data_ref, index)
	else:
		_set_item_in_inventory(container.inventory_data_ref, index, source_item)
	
	_update_slot(container, index)

func _create_drag_visual() -> void:
	dragged_visual = dragged_item_scene.instantiate()
	if dragged_visual:
		dragged_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_ui(dragged_visual)
		update_drag_visual()

func _return_items_to_source() -> void:
	if not original_source_container or not original_source_container.inventory_data_ref:
		return
	
	var inv_manager = original_source_container.inventory_data_ref
	var index = original_source_index
	var inventory_size = _get_inventory_size(inv_manager)
	
	if index < 0 or index >= inventory_size:
		return
	
	var slot_item = _get_item_from_inventory(inv_manager, index)
	
	if not slot_item or slot_item.is_empty():
		# Restore to empty slot
		_set_item_in_inventory(inv_manager, index, {
			"id": drag_data["id"],
			"quantity": drag_data["quantity"]
		})
	elif slot_item["id"] == drag_data["id"]:
		# Merge with existing stack
		slot_item["quantity"] += drag_data["quantity"]
		_set_item_in_inventory(inv_manager, index, slot_item)
	
	_update_slot(original_source_container, index)

func _validate_drop(container: ItemContainerUI, slot_button: Button) -> bool:
	if not dragging or drag_data["quantity"] <= 0:
		return false
	
	if not container or not slot_button or not container.inventory_data_ref:
		return false
	
	# Check if it's an output slot
	if "slot_type" in slot_button and slot_button.slot_type == GameConstants.SLOT_TYPE_OUTPUT:
		return false
	
	return container.get_slot_global_index(slot_button) >= 0

func _perform_drop(container: ItemContainerUI, slot_button: Button, max_amount: int) -> void:
	var index = container.get_slot_global_index(slot_button)
	var inv_manager = container.inventory_data_ref
	var dest_item = _get_item_from_inventory(inv_manager, index)
	
	var deposit_amount = min(max_amount, drag_data["quantity"])
	
	if not dest_item or dest_item.is_empty():
		# Drop into empty slot
		var final_amount = min(deposit_amount, GameConstants.MAX_STACK_SIZE)
		_set_item_in_inventory(inv_manager, index, {
			"id": drag_data["id"],
			"quantity": final_amount
		})
		drag_data["quantity"] -= final_amount
	elif dest_item["id"] == drag_data["id"]:
		# Merge with same item
		var capacity_left = GameConstants.MAX_STACK_SIZE - dest_item["quantity"]
		var actual_deposit = min(deposit_amount, capacity_left)
		dest_item["quantity"] += actual_deposit
		_set_item_in_inventory(inv_manager, index, dest_item)
		drag_data["quantity"] -= actual_deposit
	else:
		# Swap different items (only for full drops)
		if max_amount == drag_data["quantity"]:
			var temp_id = dest_item["id"]
			var temp_quantity = dest_item["quantity"]
			
			_set_item_in_inventory(inv_manager, index, {
				"id": drag_data["id"],
				"quantity": drag_data["quantity"]
			})
			
			drag_data["id"] = temp_id
			drag_data["quantity"] = temp_quantity
		else:
			return  # Can't partial drop different items
	
	update_drag_visual()
	_update_slot(container, index)
	
	if drag_data["quantity"] <= 0:
		end_drag()

# =============================================================================
# VISUAL UPDATES
# =============================================================================

func _process(_delta: float) -> void:
	if dragging and dragged_visual:
		dragged_visual.position = get_viewport().get_mouse_position() - GameConstants.DRAG_VISUAL_OFFSET

func update_drag_visual() -> void:
	if not dragged_visual:
		return
	
	var icon = dragged_visual.get_node_or_null("ItemIcon")
	var qty = dragged_visual.get_node_or_null("ItemQuantity")
	
	if not icon or not qty:
		return
	
	qty.text = str(drag_data["quantity"])
	
	var item_res = drag_data["id"]
	if item_res is ItemResource:
		icon.texture = item_res.texture
	else:
		icon.texture = null
