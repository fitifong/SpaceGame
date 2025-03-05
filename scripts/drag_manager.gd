extends Node2D
# Omit class_name or rename it if needed:
# class_name DragManagerClass  # <-- If you must have a class_name, rename it

##
# This script handles item dragging between slots in any ItemContainerUI.
# Partial drops are "committed" to the real inventory, 
# leftover items revert to the source if canceled.

var dragging: bool = false

# Data about the item currently in the user's "hand"
var drag_data := {
	"item_name": "",
	"item_texture": null,
	"quantity": 0
}

# We remember the original slot so we can revert leftover if canceled
var original_source_container: ItemContainerUI = null
var original_source_index: int = -1

# Floating visual
var dragged_visual: Control = null
var dragged_item_scene: PackedScene = preload("res://scenes/dragged_item.tscn")

# ------------------------------------------------------------------
# 🟢 STARTING & CANCELING DRAG
# ------------------------------------------------------------------

##
# Called when user clicks on a slot with items (left or right click).
#  - container: ItemContainerUI where the slot is
#  - slot_button: the Button for that slot
#  - event: InputEventMouseButton
func start_drag(container: ItemContainerUI, slot_button: Button, event: InputEventMouseButton) -> void:
	if dragging:
		return  # Already dragging something

	# Get the slot index in the container
	var index = container.get_slot_index(slot_button)
	if index < 0:
		return

	var inv_manager = container.inventory_data_ref
	var source_item = inv_manager.inventory[index]
	if source_item == null:
		return  # Nothing to drag

	# Decide if it's a full drag or right-click split
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Full drag
		drag_data["quantity"] = source_item["item_quantity"]
		inv_manager.inventory[index] = null
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click split
		var half_stack = ceil(source_item["item_quantity"] / 2.0)
		drag_data["quantity"] = half_stack
		source_item["item_quantity"] -= half_stack
		if source_item["item_quantity"] <= 0:
			inv_manager.inventory[index] = null
	else:
		return  # Other mouse button not handled

	# Store item metadata
	drag_data["item_name"] = source_item["item_name"]
	drag_data["item_texture"] = source_item["item_texture"]

	# Remember original source
	original_source_container = container
	original_source_index = index

	# Create floating icon
	dragged_visual = dragged_item_scene.instantiate()
	
	# IMPORTANT: let clicks pass through the dragged icon
	dragged_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	dragged_visual.get_node("ItemIcon").texture = drag_data["item_texture"]
	dragged_visual.get_node("ItemQuantity").text = str(drag_data["quantity"])

	# Add to some GUI layer
	var gui_layer = get_node_or_null("/root/Game/GUIs")
	if gui_layer:
		gui_layer.add_child(dragged_visual)
	else:
		add_child(dragged_visual)

	dragging = true

	# Refresh UI so source slot now shows updated remainder or empty
	container.update_slot(index)

##
# If the player clicks the background or hits ESC, we revert 
# leftover items in the "hand" to the original source slot 
# (if there's anything left).
func cancel_drag():
	if not dragging:
		return

	if drag_data["quantity"] > 0 and original_source_container:
		var index = original_source_index
		var inv_manager = original_source_container.inventory_data_ref
		var slot_item = inv_manager.inventory[index]

		if slot_item == null:
			# If the source is still empty, just restore everything,
			# except for committed partial drops
			var restored = {
				"item_name": drag_data["item_name"],
				"item_texture": drag_data["item_texture"],
				"item_quantity": drag_data["quantity"]
			}
			inv_manager.inventory[index] = restored
		else:
			# If there's something there now, decide if same item => stack, etc.
			if slot_item["item_name"] == drag_data["item_name"]:
				slot_item["item_quantity"] += drag_data["quantity"]
			else:
				# Could do a swap, or place it in the next free slot, etc.
				# For simplicity, let's skip that scenario or do nothing.
				pass

		original_source_container.update_slot(index)

	end_drag()

# ------------------------------------------------------------------
# 🔵 PARTIAL DROP (RIGHT-CLICK) & FULL DROP (LEFT-CLICK)
# ------------------------------------------------------------------

##
# Deposits exactly 1 item (or some small #) from drag_data into the target slot, 
# if it's empty or matches the item. 
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

	# We always deposit 1 item on partial_drop
	var deposit_amount = 1

	if dest_item == null:
		# -----------------------
		# If the slot is empty
		# -----------------------
		# But we impose a limit of 99 for a new stack:
		if deposit_amount > 99:
			deposit_amount = 99  # though realistically deposit_amount is 1

		# Create a new stack in that slot
		var new_item = {
			"item_name": drag_data["item_name"],
			"item_texture": drag_data["item_texture"],
			"item_quantity": deposit_amount
		}
		inv_manager.inventory[index] = new_item
		drag_data["quantity"] -= deposit_amount

	else:
		# -----------------------
		# Slot already has something
		# -----------------------
		# If it's the same item, try stacking up to 99
		if dest_item["item_name"] == drag_data["item_name"]:
			var current_qty = dest_item["item_quantity"]
			var capacity_left = 99 - current_qty

			if capacity_left <= 0:
				# Already at 99, do nothing
				return

			# We only want to deposit min(1, capacity_left)
			deposit_amount = min(deposit_amount, capacity_left)
			# deposit_amount is 1 if there's space, or 0 if no space
			if deposit_amount <= 0:
				# No space
				return

			# Do the deposit
			dest_item["item_quantity"] += deposit_amount
			drag_data["quantity"] -= deposit_amount

		else:
			# Different item => partial drop not allowed
			return

	# Update floating icon
	if dragged_visual:
		dragged_visual.get_node("ItemQuantity").text = str(drag_data["quantity"])

	# Refresh UI
	container.update_slot(index)

	# If we've placed everything, end the drag
	if drag_data["quantity"] <= 0:
		end_drag()

##
# Deposits everything left in drag_data into the target slot:
#  - merges if same item
#  - swaps if different item (you can keep dragging the swapped item or end)
#  - if empty, place the entire stack
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
		# --------------------------------
		# Case: Slot is empty
		# --------------------------------
		# We can put up to 99 items in a fresh stack
		var deposit = min(drag_data["quantity"], 99)

		var new_item = {
			"item_name": drag_data["item_name"],
			"item_texture": drag_data["item_texture"],
			"item_quantity": deposit
		}
		inv_manager.inventory[index] = new_item
		drag_data["quantity"] -= deposit

	else:
		# --------------------------------
		# Case: Slot already has an item
		# --------------------------------
		if dest_item["item_name"] == drag_data["item_name"]:
			# --------------------------
			# Same item => partial merge up to 99
			# --------------------------
			var current_qty = dest_item["item_quantity"]
			var capacity_left = 99 - current_qty

			if capacity_left <= 0:
				# Slot is already full
				return

			var deposit = min(drag_data["quantity"], capacity_left)
			dest_item["item_quantity"] += deposit
			drag_data["quantity"] -= deposit

		else:
			# --------------------------
			# Different item => SWAP
			# --------------------------
			# (Ignoring the 99 limit in this example)
			var temp_item = {
				"item_name": dest_item["item_name"],
				"item_texture": dest_item["item_texture"],
				"item_quantity": dest_item["item_quantity"]
			}
			# Put the dragged item in the slot
			dest_item["item_name"] = drag_data["item_name"]
			dest_item["item_texture"] = drag_data["item_texture"]
			dest_item["item_quantity"] = drag_data["quantity"]

			# Now your "hand" has the old slot item
			drag_data["item_name"] = temp_item["item_name"]
			drag_data["item_texture"] = temp_item["item_texture"]
			drag_data["quantity"]     = temp_item["item_quantity"]

			# If you want to end the drag immediately after a swap,
			# set drag_data["quantity"] = 0
			# end_drag()

	# Refresh UI
	container.update_slot(index)

	if drag_data["quantity"] <= 0:
		end_drag()
	# else we keep dragging the leftover

# ------------------------------------------------------------------
# 🔴 ENDING DRAG & PER-FRAME UPDATE
# ------------------------------------------------------------------

func end_drag():
	dragging = false
	drag_data = {
		"item_name": "",
		"item_texture": null,
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
