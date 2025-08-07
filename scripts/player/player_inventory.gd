# scripts/player/player_inventory.gd
# COMPONENT-BASED VERSION to match other modules
extends Node

signal slot_updated(index)

var inventory_component: InventoryComponent
var player_node: Node = null

# Legacy compatibility - forward to component
var inventory: Array:
	get:
		return inventory_component.inventory if inventory_component else []
var inventory_size: int:
	get:
		return inventory_component.inventory_size if inventory_component else 0

func _ready():
	await get_tree().process_frame
	_create_component()
	_set_initial_items()

func _create_component():
	inventory_component = InventoryComponent.new()
	inventory_component.name = "Inventory"
	add_child(inventory_component)
	inventory_component.initialize(GameConstants.PLAYER_INVENTORY_SIZE)
	
	# Forward component signals
	inventory_component.slot_updated.connect(slot_updated.emit)

func _set_initial_items():
	if ItemDatabase:
		var iron_ore = ItemDatabase.get_item_data(2)
		var dirty_water = ItemDatabase.get_item_data(7)
		var water_filter = ItemDatabase.get_item_data(9)
		var dirty_water_filter = ItemDatabase.get_item_data(10)
		
		if iron_ore:
			inventory_component.add_item(0, {"id": iron_ore, "quantity": 10})
		if dirty_water:
			inventory_component.add_item(1, {"id": dirty_water, "quantity": 10})
		if water_filter:
			inventory_component.add_item(2, {"id": water_filter, "quantity": 1})
		if dirty_water_filter:
			inventory_component.add_item(3, {"id": dirty_water_filter, "quantity": 1})

func set_player_reference(player):
	if not player:
		push_error("Cannot set null player reference")
		return
	player_node = player

func add_pickup(pickup_item: Dictionary) -> int:
	"""Add item to inventory, returns leftover quantity"""
	if not pickup_item or not pickup_item.has("item_id") or not pickup_item.has("quantity"):
		return pickup_item.get("quantity", 0)

	var item_id = pickup_item["item_id"]
	var leftover = pickup_item["quantity"]

	if not (item_id is ItemResource) or leftover <= 0:
		return leftover

	# Use component's auto_stack_item method
	var item_to_add = {"id": item_id, "quantity": leftover}
	return inventory_component.auto_stack_item(item_to_add)

# Legacy methods that forward to component
func update_inventory_slot(index: int, new_item: Dictionary = {}):
	if inventory_component:
		inventory_component.add_item(index, new_item)

func get_item_from_slot(index: int) -> Dictionary:
	if inventory_component:
		return inventory_component.get_item(index)
	return {}

func remove_item_from_slot(index: int) -> Dictionary:
	if inventory_component:
		return inventory_component.remove_item(index)
	return {}
