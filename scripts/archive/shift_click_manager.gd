# scripts/ui_managers/shift_click_manager.gd
# UPDATED to work with component-based modules
extends Node

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
		target_ui = UIManager.get_active_ui() as ItemContainerUI
	else:
		# from ANY other UI → send back to the player inventory
		target_ui = UIManager.get_inventory_ui()
	
	if target_ui == null or target_ui == container:
		return

	transfer_item_between_inventories(source_inv, target_ui, slot_index)

func transfer_item_between_inventories(source_inv, target_ui: ItemContainerUI, source_slot: int) -> void:
	var source_item = _get_item_from_inventory(source_inv, source_slot)
	if source_item == null or source_item.is_empty():
		return

	var moved_quantity = attempt_stack_in_inventory(target_ui, source_item)
	source_item["quantity"] -= moved_quantity

	if source_item["quantity"] <= 0:
		_remove_item_from_inventory(source_inv, source_slot)
	else:
		_set_item_in_inventory(source_inv, source_slot, source_item)

	_emit_slot_updated(source_inv, source_slot)

func attempt_stack_in_inventory(container: ItemContainerUI, item_data) -> int:
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

func _emit_slot_updated(inventory_ref, index: int):
	"""Emit slot_updated signal from inventory"""
	if not inventory_ref:
		return
	
	# All inventories should have this signal
	if inventory_ref.has_signal("slot_updated"):
		inventory_ref.slot_updated.emit(index)
