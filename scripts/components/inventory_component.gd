# scripts/components/inventory_component.gd
extends Node
class_name InventoryComponent

signal slot_updated(index: int)
signal inventory_changed()

var inventory: Array = []
var inventory_size: int = 0

func initialize(size: int) -> bool:
	if size <= 0:
		push_error("Invalid inventory size: %d" % size)
		return false
	
	inventory_size = size
	inventory.clear()
	inventory.resize(size)
	inventory_changed.emit()
	return true

func add_item(index: int, item: Dictionary) -> bool:
	if index < 0 or index >= inventory_size:
		return false
	
	if item.is_empty():
		inventory[index] = null
	else:
		inventory[index] = item.duplicate()
	
	slot_updated.emit(index)
	inventory_changed.emit()
	return true

func get_item(index: int) -> Dictionary:
	if index < 0 or index >= inventory_size:
		return {}
	
	var item = inventory[index]
	if item != null:
		return item.duplicate()
	else:
		return {}

func remove_item(index: int) -> Dictionary:
	if index < 0 or index >= inventory_size:
		return {}
	
	var removed_item = get_item(index)
	inventory[index] = null
	slot_updated.emit(index)
	inventory_changed.emit()
	return removed_item

func is_slot_empty(index: int) -> bool:
	if index < 0 or index >= inventory_size:
		return false
	return inventory[index] == null

func clear_inventory():
	for i in range(inventory_size):
		inventory[i] = null
	inventory_changed.emit()

func try_stack_item(index: int, item: Dictionary) -> int:
	"""
	Attempts to stack an item into the specified slot.
	Returns the number of items that couldn't be stacked (leftover).
	"""
	if index < 0 or index >= inventory_size or item.is_empty():
		return item.get("quantity", 0)
	
	var slot_item = inventory[index]
	var quantity_to_add = item.get("quantity", 0)
	
	if slot_item == null:
		# Empty slot - place entire item (up to stack limit)
		var max_stack = min(quantity_to_add, GameConstants.MAX_STACK_SIZE)
		inventory[index] = {
			"id": item["id"],
			"quantity": max_stack
		}
		slot_updated.emit(index)
		inventory_changed.emit()
		return quantity_to_add - max_stack
	
	elif slot_item.get("id") == item.get("id"):
		# Same item - try to merge stacks
		var remaining_capacity = GameConstants.MAX_STACK_SIZE - slot_item.get("quantity", 0)
		var amount_to_add = min(quantity_to_add, remaining_capacity)
		
		if amount_to_add > 0:
			slot_item["quantity"] += amount_to_add
			slot_updated.emit(index)
			inventory_changed.emit()
		
		return quantity_to_add - amount_to_add
	
	else:
		# Different item - can't stack
		return quantity_to_add

func auto_stack_item(item: Dictionary) -> int:
	"""
	Attempts to automatically place an item in the best available slot.
	Returns the number of items that couldn't be placed (leftover).
	"""
	if item.is_empty():
		return 0
	
	var remaining_quantity = item.get("quantity", 0)
	var item_to_place = item.duplicate()
	
	# Pass 1: Try to stack with existing items
	for i in range(inventory_size):
		if remaining_quantity <= 0:
			break
		
		var slot_item = inventory[i]
		if slot_item != null and slot_item.get("id") == item.get("id"):
			item_to_place["quantity"] = remaining_quantity
			remaining_quantity = try_stack_item(i, item_to_place)
	
	# Pass 2: Try to place in empty slots
	for i in range(inventory_size):
		if remaining_quantity <= 0:
			break
		
		if inventory[i] == null:
			item_to_place["quantity"] = remaining_quantity
			remaining_quantity = try_stack_item(i, item_to_place)
	
	return remaining_quantity
