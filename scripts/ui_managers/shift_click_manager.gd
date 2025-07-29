extends Node

# Manages shift-clicking to transfer items between inventories.
# Items are transferred to the Player Inventory UI when the source is another UI.

func shift_click(container: ItemContainerUI, slot_index: int) -> void:
	# Validate the container and slot index.
	if container == null or slot_index < 0 or slot_index >= container.inventory_data_ref.inventory.size():
		return

	var source_inv = container.inventory_data_ref
	var item_data  = source_inv.inventory[slot_index]
	if item_data == null:
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
	var source_item = source_inv.inventory[source_slot]
	if source_item == null:
		return  # No item to transfer.

	var moved_quantity = attempt_stack_in_inventory(target_ui, source_item)
	source_item["quantity"] -= moved_quantity

	if source_item["quantity"] <= 0:
		source_inv.inventory[source_slot] = null

	source_inv.emit_signal("slot_updated", source_slot)


func attempt_stack_in_inventory(container: ItemContainerUI, item_data) -> int:
	var total_moved = 0
	var quantity_to_move = item_data["quantity"]
	var inventory = container.inventory_data_ref

	# Pass 1: Merge into existing stacks.
	for i in range(inventory.inventory_size):
		if quantity_to_move <= 0:
			break
		var slot_item = inventory.inventory[i]

		if slot_item != null and slot_item["id"] == item_data["id"]:
			var slot_button = container.get_slot_button(i)
			if slot_button.slot_type == "output":
				continue

			var capacity = 99 - slot_item["quantity"]
			if capacity > 0:
				var move_amount = min(capacity, quantity_to_move)
				slot_item["quantity"] += move_amount
				quantity_to_move -= move_amount
				total_moved += move_amount
				inventory.emit_signal("slot_updated", i)

	# Pass 2: Place in empty slots.
	for i in range(inventory.inventory_size):
		if quantity_to_move <= 0:
			break
		if inventory.inventory[i] == null:
			var slot_button = container.get_slot_button(i)
			if slot_button.slot_type == "output":
				continue

			var move_amount = min(99, quantity_to_move)
			inventory.inventory[i] = {
				"id": item_data["id"],
				"quantity": move_amount
			}
			quantity_to_move -= move_amount
			total_moved += move_amount
			inventory.emit_signal("slot_updated", i)

	return total_moved
