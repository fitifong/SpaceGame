extends Node

signal slot_updated(index)

var inventory: Array = [
	{"id": 2, "quantity": 10}
]
var inventory_size: int = 0
var player_node: Node = null

# ----------------- 🟢 PLAYER INVENTORY SETUP ----------------- #
func _ready():
	set_inventory_size(9)

func set_inventory_size(size: int) -> void:
	inventory_size = size
	inventory.resize(size)

# Stores reference to the player for item pickups
func set_player_reference(player):
	player_node = player

##
# Attempts to place 'item' in this inventory, obeying a 99 stack limit.
# Returns an integer: the number of leftover items that couldn't be placed.
#    - If leftover == 0, all items fit in the inventory.
#    - If leftover > 0, the inventory is full (or all stacks are at 99).
func add_pickup(pickup_item: Dictionary) -> int:
	var item_id = pickup_item["item_id"]
	var item_data = ItemDatabase.get_item_data(item_id)
	if item_data == null:
		# Item not found in database; nothing to add.
		return pickup_item["item_quantity"]

	var leftover = pickup_item["item_quantity"]

	# -----------------------
	# PASS 1: Merge into existing stacks (up to 99 each)
	# -----------------------
	for i in range(inventory.size()):
		if leftover <= 0:
			break
		var slot_item = inventory[i]
		if slot_item != null and slot_item["id"] == item_id:
			var capacity_left = 99 - slot_item["quantity"]
			if capacity_left > 0:
				var deposit = min(capacity_left, leftover)
				slot_item["quantity"] += deposit
				leftover -= deposit
				if deposit > 0:
					emit_signal("slot_updated", i)

	# -----------------------
	# PASS 2: Place items into empty slots (up to 99 each)
	# -----------------------
	for i in range(inventory.size()):
		if leftover <= 0:
			break
		if inventory[i] == null:
			var to_place = min(99, leftover)
			inventory[i] = {"id": item_id, "quantity": to_place}
			leftover -= to_place
			emit_signal("slot_updated", i)

	return leftover
