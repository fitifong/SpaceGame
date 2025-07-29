extends Node

signal slot_updated(index)

var inventory: Array = []
var inventory_size: int = 0
var player_node: Node = null

# ----------------- 🟢 PLAYER INVENTORY SETUP ----------------- #
func _ready():
	await get_tree().process_frame     # ← guarantees ItemDatabase is ready
	set_inventory_size(9)
	inventory[0] = {"id": ItemDatabase.get_item_data(2),  "quantity": 10}
	inventory[1] = {"id": ItemDatabase.get_item_data(5), "quantity": 10}

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
	if not pickup_item.has("item_id") or pickup_item["item_id"] == null:
		push_error("add_pickup() called with missing 'item_id'")
		return pickup_item.get("quantity", 0)

	var item_id = pickup_item["item_id"]  # ✅ This is now an ItemResource!
	var leftover = pickup_item["quantity"]

	# ----------------------- PASS 1: Merge into existing stacks -----------------------
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

	# ----------------------- PASS 2: Place into empty slots -----------------------
	for i in range(inventory.size()):
		if leftover <= 0:
			break
		if inventory[i] == null or inventory[i]["id"] == null:
			var to_place = min(99, leftover)
			inventory[i] = {"id": item_id, "quantity": to_place}
			leftover -= to_place
			emit_signal("slot_updated", i)

	return leftover
