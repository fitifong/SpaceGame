extends Node2D

# Whether an item is currently being dragged.
var dragging: bool = false

# Data about the item currently in the user's "hand".
# Now stores only the item ID and the quantity.
var drag_data := {
    "id": -1,       # Use -1 or another invalid ID as a default.
    "quantity": 0
}

# Remember the original slot so we can revert if the drag is canceled.
var original_source_container: ItemContainerUI = null
var original_source_index: int = -1

# Floating visual for the dragged item.
var dragged_visual: Control = null
var dragged_item_scene: PackedScene = preload("res://scenes/dragged_item.tscn")

# Hold threshold parameters (milliseconds)
var hold_threshold_ms: int = 300
var hold_start_time: int = 0


# ------------------------------------------------------------------
# 🟢 STARTING & CANCELING DRAG
# ------------------------------------------------------------------

# Called when the user clicks on a slot with items (left or right click).
#   - container: The ItemContainerUI that holds the slot.
#   - slot_button: The Button for that slot.
#   - event: The InputEventMouseButton that initiated the drag.
func start_drag(container: ItemContainerUI, slot_button: Button, event: InputEventMouseButton) -> void:
    if dragging:
        return  # Already dragging something

    # Get the slot index in the container.
    var index = container.get_slot_index(slot_button)
    if index < 0:
        return

    var inv_manager = container.inventory_data_ref
    var source_item = inv_manager.inventory[index]
    if source_item == null:
        return  # Nothing to drag

    # Decide if it's a full drag or a right-click split.
    if event.button_index == MOUSE_BUTTON_LEFT:
        # Full drag: take the entire stack.
        drag_data["quantity"] = source_item["quantity"]
        inv_manager.inventory[index] = null
    elif event.button_index == MOUSE_BUTTON_RIGHT:
        # Right-click split: drag half the stack.
        var half_stack = ceil(source_item["quantity"] / 2.0)
        drag_data["quantity"] = half_stack
        source_item["quantity"] -= half_stack
        if source_item["quantity"] <= 0:
            inv_manager.inventory[index] = null
    else:
        return  # Other mouse buttons not handled

    # Store the item ID for later use.
    drag_data["id"] = source_item["id"]

    # Remember the original source so that we can revert if needed.
    original_source_container = container
    original_source_index = index

    # Create the floating dragged icon.
    dragged_visual = dragged_item_scene.instantiate()
    # Let clicks pass through the dragged icon.
    dragged_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Set the icon texture by looking up the item in the database.
    var item_data = ItemDatabase.get_item_data(drag_data["id"])
    if item_data:
        dragged_visual.get_node("ItemIcon").texture = item_data["texture"]
    else:
        dragged_visual.get_node("ItemIcon").texture = null
    dragged_visual.get_node("ItemQuantity").text = str(drag_data["quantity"])

    # Add the dragged visual to the GUI layer.
    var gui_layer = get_node_or_null("/root/Game/GUIs")
    if gui_layer:
        gui_layer.add_child(dragged_visual)
    else:
        add_child(dragged_visual)

    dragging = true
    
    # Record the time when the drag started.
    hold_start_time = Time.get_ticks_msec()
    
    # Refresh UI so the source slot now shows the updated (reduced or empty) stack.
    container.update_slot(index)

# If the player cancels the drag (clicks the background or presses ESC), revert any remaining items back to the source slot.
func cancel_drag():
    if not dragging:
        return

    if drag_data["quantity"] > 0 and original_source_container:
        var index = original_source_index
        var inv_manager = original_source_container.inventory_data_ref
        var slot_item = inv_manager.inventory[index]

        if slot_item == null:
            # If the source is still empty, restore the dragged items.
            var restored = {
                "id": drag_data["id"],
                "quantity": drag_data["quantity"]
            }
            inv_manager.inventory[index] = restored
        else:
            # If there's already something there, check if it’s the same item.
            if slot_item["id"] == drag_data["id"]:
                slot_item["quantity"] += drag_data["quantity"]
            else:
                # Optionally handle swapping or placing in another slot.
                pass

        original_source_container.update_slot(index)

    end_drag()

# ------------------------------------------------------------------
# 🔵 PARTIAL DROP (RIGHT-CLICK) & FULL DROP (LEFT-CLICK)
# ------------------------------------------------------------------

# Deposits exactly 1 item from drag_data into the target slot.
func partial_drop(container: ItemContainerUI, slot_button: Button):
    if not dragging:
        return
    if drag_data["quantity"] <= 0:
        end_drag()
        return

    var index = container.get_slot_index(slot_button)
    if index < 0:
        return

    var inv_manager = container.inventory_data_ref
    var dest_item = inv_manager.inventory[index]

    # We always deposit 1 item on partial_drop.
    var deposit_amount = 1

    if dest_item == null:
        # Slot is empty – create a new stack.
        deposit_amount = min(deposit_amount, 99)  # Limit new stack to 99.
        var new_item = {
            "id": drag_data["id"],
            "quantity": deposit_amount
        }
        inv_manager.inventory[index] = new_item
        drag_data["quantity"] -= deposit_amount
    else:
        # Slot already contains an item.
        if dest_item["id"] == drag_data["id"]:
            var current_qty = dest_item["quantity"]
            var capacity_left = 99 - current_qty
            if capacity_left <= 0:
                # Slot is already full.
                return

            deposit_amount = min(deposit_amount, capacity_left)
            if deposit_amount <= 0:
                return

            dest_item["quantity"] += deposit_amount
            drag_data["quantity"] -= deposit_amount
        else:
            # Partial drop not allowed for different items.
            return

    # Update the floating icon's quantity display.
    if dragged_visual:
        dragged_visual.get_node("ItemQuantity").text = str(drag_data["quantity"])

    # Refresh UI.
    container.update_slot(index)

    # End the drag if all items have been placed.
    if drag_data["quantity"] <= 0:
        end_drag()

# Deposits everything left in drag_data into the target slot.
# Merges with the slot if it contains the same item;
# if different, performs a swap (or you can choose a different behavior).
func full_drop(container: ItemContainerUI, slot_button: Button):
    if not dragging:
        return
    if drag_data["quantity"] <= 0:
        end_drag()
        return

    var index = container.get_slot_index(slot_button)
    if index < 0:
        return

    var inv_manager = container.inventory_data_ref
    var dest_item = inv_manager.inventory[index]

    if dest_item == null:
        # Case: Slot is empty.
        var deposit = min(drag_data["quantity"], 99)
        var new_item = {
            "id": drag_data["id"],
            "quantity": deposit
        }
        inv_manager.inventory[index] = new_item
        drag_data["quantity"] -= deposit
    else:
        # Case: Slot already contains an item.
        if dest_item["id"] == drag_data["id"]:
            # Same item: merge up to the stack limit.
            var current_qty = dest_item["quantity"]
            var capacity_left = 99 - current_qty
            if capacity_left <= 0:
                # Slot is already full.
                return

            var deposit = min(drag_data["quantity"], capacity_left)
            dest_item["quantity"] += deposit
            drag_data["quantity"] -= deposit
        else:
            # Different item: swap the dragged item with the slot's item.
            var temp_item = {
                "id": dest_item["id"],
                "quantity": dest_item["quantity"]
            }
            # Place the dragged item into the slot.
            dest_item["id"] = drag_data["id"]
            dest_item["quantity"] = drag_data["quantity"]

            # Now the dragged data becomes the item that was in the slot.
            drag_data["id"] = temp_item["id"]
            drag_data["quantity"] = temp_item["quantity"]

            # Update the dragged visual to match the new drag_data.
            var item_data = ItemDatabase.get_item_data(drag_data["id"])
            if item_data:
                dragged_visual.get_node("ItemIcon").texture = item_data["texture"]
            else:
                dragged_visual.get_node("ItemIcon").texture = null
            dragged_visual.get_node("ItemQuantity").text = str(drag_data["quantity"])

    # Refresh UI.
    container.update_slot(index)

    if drag_data["quantity"] <= 0:
        end_drag()
    # Otherwise, the drag continues with any leftover quantity.

# ------------------------------------------------------------------
# 🔴 HOLD RELEASE & HOLD DRAG LOGIC
# ------------------------------------------------------------------
# This function is called when the left mouse button is released.
# - If no slot is under the mouse, cancel the drag.
# - If released over the source slot, cancel and reinitiate a normal drag.
# - Otherwise, use the hold_drag logic.

func handle_left_release(container: ItemContainerUI, slot_button: Button) -> void:
    if slot_button == null:
        cancel_drag()
        return

    var index = container.get_slot_index(slot_button)
    if index < 0:
        cancel_drag()
        return

    # If released over the original source slot, cancel and restart a normal drag.
    if container == original_source_container and index == original_source_index:
        cancel_drag()
        var fake_event = InputEventMouseButton.new()
        fake_event.button_index = MOUSE_BUTTON_LEFT
        fake_event.pressed = true
        start_drag(container, slot_button, fake_event)
        return

    # Otherwise, perform the custom hold-based drop.
    hold_drag(container, slot_button)

# Implements the custom hold-based drop behavior.
func hold_drag(container: ItemContainerUI, slot_button: Button) -> void:
    if not dragging:
        return

    var index = container.get_slot_index(slot_button)
    if index < 0:
        cancel_drag()
        return

    var inv_manager = container.inventory_data_ref
    var dest_item = inv_manager.inventory[index]

    # Case 1: Destination slot is empty.
    if dest_item == null:
        var deposit = min(drag_data["quantity"], 99)
        inv_manager.inventory[index] = {
            "id": drag_data["id"],
            "quantity": deposit
        }
        var leftover = drag_data["quantity"] - deposit
        if leftover > 0 and original_source_container:
            var src_index = original_source_index
            original_source_container.inventory_data_ref.inventory[src_index] = {
                "id": drag_data["id"],
                "quantity": leftover
            }
            original_source_container.update_slot(src_index)
        container.update_slot(index)
        end_drag()
        return

    # Case 2: Destination slot has the same item.
    if dest_item["id"] == drag_data["id"]:
        var capacity = 99 - dest_item["quantity"]
        var deposit = min(drag_data["quantity"], capacity)
        dest_item["quantity"] += deposit
        var leftover = drag_data["quantity"] - deposit
        if leftover > 0 and original_source_container:
            var src_index = original_source_index
            original_source_container.inventory_data_ref.inventory[src_index] = {
                "id": drag_data["id"],
                "quantity": leftover
            }
            original_source_container.update_slot(src_index)
        container.update_slot(index)
        end_drag()
        return

    # Case 3: Destination slot holds a different item; swap and end the drag.
    var temp_item = {
        "id": dest_item["id"],
        "quantity": dest_item["quantity"]
    }
    dest_item["id"] = drag_data["id"]
    dest_item["quantity"] = drag_data["quantity"]

    drag_data["id"] = temp_item["id"]
    drag_data["quantity"] = temp_item["quantity"]

    var item_data = ItemDatabase.get_item_data(drag_data["id"])
    if item_data:
        dragged_visual.get_node("ItemIcon").texture = item_data["texture"]
    else:
        dragged_visual.get_node("ItemIcon").texture = null
    dragged_visual.get_node("ItemQuantity").text = str(drag_data["quantity"])

    container.update_slot(index)
    end_drag()

# ------------------------------------------------------------------
# 🔴 ENDING DRAG & PER-FRAME UPDATE
# ------------------------------------------------------------------

func end_drag():
    dragging = false
    drag_data = {
        "id": -1,
        "quantity": 0
    }
    original_source_container = null
    original_source_index = -1

    if dragged_visual:
        dragged_visual.queue_free()
        dragged_visual = null

func _process(_delta: float) -> void:
    if dragging and dragged_visual:
        dragged_visual.position = get_viewport().get_mouse_position() - Vector2(32, 32)
