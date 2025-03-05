extends InventoryManager

var player_node: Node = null

# ----------------- 🟢 PLAYER INVENTORY SETUP ----------------- #
func _ready():
    set_inventory_size(9)

# Stores reference to the player for item pickups
func set_player_reference(player):
    player_node = player

##
# Attempts to place 'item' in this inventory, obeying a 99 stack limit.
# Returns an integer: the number of leftover items that couldn't be placed.
#    - If leftover == 0, all items fit in the inventory.
#    - If leftover > 0, the inventory is full (or all stacks are at 99).
func add_pickup(item: Dictionary) -> int:
    var leftover = item["item_quantity"]
    var target_name = item["item_name"]

    # -----------------------
    # PASS 1: Merge into existing stacks (up to 99 each)
    # -----------------------
    for i in range(inventory.size()):
        if leftover <= 0:
            break
        var slot_item = inventory[i]
        if slot_item != null and slot_item["item_name"] == target_name:
            var capacity_left = 99 - slot_item["item_quantity"]
            if capacity_left > 0:
                var deposit = min(capacity_left, leftover)
                slot_item["item_quantity"] += deposit
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
            var new_item = item.duplicate()
            new_item["item_quantity"] = to_place
            inventory[i] = new_item
            leftover -= to_place
            if to_place > 0:
                emit_signal("slot_updated", i)

    return leftover
