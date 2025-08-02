extends Node2D

# Core drag state
var dragging: bool = false
var drag_data := {"id": null, "quantity": 0}

# Source tracking for cancellation
var original_source_container: ItemContainerUI = null
var original_source_index: int = -1

# Visual representation
var dragged_visual: Control = null
var dragged_item_scene: PackedScene = preload("res://scenes/ui/dragged_item.tscn")

# ------------------------------------------------------------------
# DRAG LIFECYCLE
# ------------------------------------------------------------------

func start_drag(container: ItemContainerUI, slot_button: Button, event: InputEventMouseButton) -> void:
	if dragging or not _validate_drag_start(container, slot_button, event):
		return
	
	var index = container.get_slot_index(slot_button)
	var source_item = container.inventory_data_ref.inventory[index]
	if not source_item:
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

# ------------------------------------------------------------------
# DROP OPERATIONS
# ------------------------------------------------------------------

func partial_drop(container: ItemContainerUI, slot_button: Button) -> void:
	if not _validate_drop(container, slot_button):
		return
	
	_perform_drop(container, slot_button, 1)

func full_drop(container: ItemContainerUI, slot_button: Button) -> void:
	if not _validate_drop(container, slot_button):
		return
	
	_perform_drop(container, slot_button, drag_data["quantity"])

# ------------------------------------------------------------------
# PRIVATE HELPER METHODS
# ------------------------------------------------------------------

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
		container.inventory_data_ref.inventory[index] = null
	container.update_slot(index)

func _create_drag_visual() -> void:
	dragged_visual = dragged_item_scene.instantiate()
	if dragged_visual:
		dragged_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIManager.add_ui(dragged_visual)
		update_drag_visual()

func _return_items_to_source() -> void:
	if not original_source_container or not original_source_container.inventory_data_ref:
		return
	
	var inv_manager = original_source_container.inventory_data_ref
	var index = original_source_index
	
	if index < 0 or index >= inv_manager.inventory.size():
		return
	
	var slot_item = inv_manager.inventory[index]
	
	if not slot_item:
		# Restore to empty slot
		inv_manager.inventory[index] = {
			"id": drag_data["id"],
			"quantity": drag_data["quantity"]
		}
	elif slot_item["id"] == drag_data["id"]:
		# Merge with existing stack
		slot_item["quantity"] += drag_data["quantity"]
	
	original_source_container.update_slot(index)

func _validate_drop(container: ItemContainerUI, slot_button: Button) -> bool:
	if not dragging or drag_data["quantity"] <= 0:
		return false
	
	if not container or not slot_button or not container.inventory_data_ref:
		return false
	
	# Check if it's an output slot
	if "slot_type" in slot_button and slot_button.slot_type == GameConstants.SLOT_TYPE_OUTPUT:
		return false
	
	return container.get_slot_index(slot_button) >= 0

func _perform_drop(container: ItemContainerUI, slot_button: Button, max_amount: int) -> void:
	var index = container.get_slot_index(slot_button)
	var inv_manager = container.inventory_data_ref
	var dest_item = inv_manager.inventory[index]
	
	var deposit_amount = min(max_amount, drag_data["quantity"])
	
	if not dest_item:
		# Drop into empty slot
		var final_amount = min(deposit_amount, GameConstants.MAX_STACK_SIZE)
		inv_manager.inventory[index] = {
			"id": drag_data["id"],
			"quantity": final_amount
		}
		drag_data["quantity"] -= final_amount
	elif dest_item["id"] == drag_data["id"]:
		# Merge with same item
		var capacity_left = GameConstants.MAX_STACK_SIZE - dest_item["quantity"]
		var actual_deposit = min(deposit_amount, capacity_left)
		dest_item["quantity"] += actual_deposit
		drag_data["quantity"] -= actual_deposit
	else:
		# Swap different items (only for full drops)
		if max_amount == drag_data["quantity"]:
			var temp_id = dest_item["id"]
			var temp_quantity = dest_item["quantity"]
			
			dest_item["id"] = drag_data["id"]
			dest_item["quantity"] = drag_data["quantity"]
			
			drag_data["id"] = temp_id
			drag_data["quantity"] = temp_quantity
		else:
			return  # Can't partial drop different items
	
	update_drag_visual()
	container.update_slot(index)
	
	if drag_data["quantity"] <= 0:
		end_drag()

# ------------------------------------------------------------------
# VISUAL UPDATES
# ------------------------------------------------------------------

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
