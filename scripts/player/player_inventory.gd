extends Node

signal slot_updated(index)

var inventory: Array = []
var inventory_size: int = 0
var player_node: Node = null

# ----------------- 🟢 PLAYER INVENTORY SETUP ----------------- #
func _ready():
	await get_tree().process_frame     # ← guarantees ItemDatabase is ready
	set_inventory_size(GameConstants.PLAYER_INVENTORY_SIZE)
	
	# FIXED: Null safety when setting initial items
	if ItemDatabase:
		var iron_ore = ItemDatabase.get_item_data(2)
		var metal_sheet = ItemDatabase.get_item_data(5)
		
		if iron_ore:
			inventory[0] = {"id": iron_ore, "quantity": 10}
		else:
			push_warning("[PlayerInventory] Could not find item with ID 2")
			
		if metal_sheet:
			inventory[1] = {"id": metal_sheet, "quantity": 10}
		else:
			push_warning("[PlayerInventory] Could not find item with ID 5")
	else:
		push_error("[PlayerInventory] ItemDatabase not available")

func set_inventory_size(size: int) -> void:
	# FIXED: Input validation
	if size < 0:
		push_error("[PlayerInventory] Invalid inventory size: %d" % size)
		return
		
	inventory_size = size
	inventory.resize(size)

# Stores reference to the player for item pickups
func set_player_reference(player):
	# FIXED: Null safety
	if not player:
		push_error("[PlayerInventory] Cannot set null player reference")
		return
		
	player_node = player

##
# Attempts to place 'item' in this inventory, obeying a stack limit.
# Returns an integer: the number of leftover items that couldn't be placed.
#    - If leftover == 0, all items fit in the inventory.
#    - If leftover > 0, the inventory is full (or all stacks are at max).
func add_pickup(pickup_item: Dictionary) -> int:
	# FIXED: Input validation
	if not pickup_item:
		push_error("[PlayerInventory] add_pickup() called with null pickup_item")
		return 0
		
	if not pickup_item.has("item_id") or pickup_item["item_id"] == null:
		push_error("[PlayerInventory] add_pickup() called with missing 'item_id'")
		return pickup_item.get("quantity", 0)

	if not pickup_item.has("quantity") or pickup_item["quantity"] <= 0:
		push_warning("[PlayerInventory] add_pickup() called with invalid quantity: %s" % str(pickup_item.get("quantity", "null")))
		return pickup_item.get("quantity", 0)

	var item_id = pickup_item["item_id"]  # ✅ This is now an ItemResource!
	var leftover = pickup_item["quantity"]

	# FIXED: Validate item_id is ItemResource
	if not (item_id is ItemResource):
		push_error("[PlayerInventory] item_id must be ItemResource, got: %s" % str(typeof(item_id)))
		return leftover

	# ----------------------- PASS 1: Merge into existing stacks -----------------------
	for i in range(inventory.size()):
		if leftover <= 0:
			break
		var slot_item = inventory[i]
		if slot_item != null and slot_item["id"] == item_id:
			var capacity_left = GameConstants.MAX_STACK_SIZE - slot_item["quantity"]
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
			var to_place = min(GameConstants.MAX_STACK_SIZE, leftover)
			inventory[i] = {"id": item_id, "quantity": to_place}
			leftover -= to_place
			emit_signal("slot_updated", i)

	return leftover
