extends Node

# Manages shift-clicking to transfer items between inventories.
# Items are transferred to the Player Inventory UI when the source is another UI.

func shift_click(container: ItemContainerUI, slot_index: int) -> void:
	# Validate the container and slot index.
	if container == null or slot_index < 0 or slot_index >= container.inventory_data_ref.inventory.size():
		return

	var source_inv = container.inventory_data_ref
	var item_data = source_inv.inventory[slot_index]
	if item_data == null:
		return  # Nothing to transfer.

	# Determine the target UI.
	var target_ui = UIManager.get_active_ui() if UIManager else null

	# If the source is not the Player Inventory UI, transfer to Player Inventory UI.
	if container.name != "PlayerInventoryUI":
		var player_inv = get_node_or_null("/root/Game/GUIs/PlayerInventoryUI")
		if player_inv:
			target_ui = player_inv
		else:
			return  # Player Inventory UI not found.

	# Ensure a valid target UI exists.
	if target_ui == null or target_ui == container:
		return

	transfer_item_between_inventories(source_inv, target_ui.inventory_data_ref, slot_index)

func transfer_item_between_inventories(source_inv, target_inv, source_slot: int) -> void:
	var source_item = source_inv.inventory[source_slot]
	if source_item == null:
		return  # No item to transfer.

	var moved_quantity = attempt_stack_in_inventory(target_inv, source_item)
	source_item["item_quantity"] -= moved_quantity
	
	# Remove item if quantity reaches zero.
	if source_item["item_quantity"] <= 0:
		source_inv.inventory[source_slot] = null
	
	source_inv.emit_signal("slot_updated", source_slot)

func attempt_stack_in_inventory(inventory, item_data) -> int:
	var total_moved = 0
	var quantity_to_move = item_data["item_quantity"]

	# Pass 1: Merge into existing stacks.
	for i in range(inventory.inventory_size):
		if quantity_to_move <= 0:
			break
		var slot_item = inventory.inventory[i]
		if slot_item != null and slot_item["item_name"] == item_data["item_name"]:
			var capacity = 99 - slot_item["item_quantity"]
			if capacity > 0:
				var move_amount = min(capacity, quantity_to_move)
				slot_item["item_quantity"] += move_amount
				quantity_to_move -= move_amount
				total_moved += move_amount
				inventory.emit_signal("slot_updated", i)

	# Pass 2: Place remaining items in empty slots.
	for i in range(inventory.inventory_size):
		if quantity_to_move <= 0:
			break
		if inventory.inventory[i] == null:
			var move_amount = min(99, quantity_to_move)
			var new_item = item_data.duplicate()
			new_item["item_quantity"] = move_amount
			inventory.inventory[i] = new_item
			quantity_to_move -= move_amount
			total_moved += move_amount
			inventory.emit_signal("slot_updated", i)

	return total_moved
