extends Node2D

# Whether an item is currently being dragged.
var dragging: bool = false

# Data about the item currently in the user's "hand".
# Now stores an ItemResource as the ID (was int before).
var drag_data := {
	"id": null,  # Use null to indicate no item
	"quantity": 0
}

# Remember the original slot so we can revert if the drag is canceled.
var original_source_container: ItemContainerUI = null
var original_source_index: int = -1

# Floating visual for the dragged item.
var dragged_visual: Control = null
var dragged_item_scene: PackedScene = preload("res://scenes/ui/dragged_item.tscn")

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

	if source_item["id"] is int:
		source_item["id"] = ItemDatabase.get_item_data(source_item["id"])

	# Decide if it's a full drag or a right-click split.
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Full drag: take the entire stack.
		drag_data["id"] = source_item["id"]
		drag_data["quantity"] = source_item["quantity"]
		inv_manager.inventory[index] = null
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click split: drag half the stack.
		var half_stack = ceil(source_item["quantity"] / 2)
		drag_data["id"] = source_item["id"]
		drag_data["quantity"] = half_stack
		# 🔄 RESTORED – remove the half from the source stack
		source_item["quantity"] -= half_stack
		if source_item["quantity"] <= 0:
			inv_manager.inventory[index] = null
	else:
		return  # Other mouse buttons not handled

	# Remember the original source so that we can revert if needed.
	original_source_container = container
	original_source_index     = index

	# Create the floating dragged icon.
	dragged_visual = dragged_item_scene.instantiate()
	dragged_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through
	UIManager.add_ui(dragged_visual)

	# NEW: centralised refresh
	update_drag_visual()

	dragging = true
	
	# Refresh UI so the source slot now shows the updated (reduced or empty) stack.
	container.update_slot(index)

# If the player cancels the drag (clicks the background or presses ESC), revert any remaining items back to the source slot.
func cancel_drag():
	if not dragging:
		return

	if drag_data["quantity"] > 0 and original_source_container:
		var index = original_source_index
		var inv_manager = original_source_container.inventory_data_ref
		var slot_item  = inv_manager.inventory[index]

		if slot_item == null:
			# If the source is still empty, restore the dragged items.
			inv_manager.inventory[index] = {
				"id": drag_data["id"],
				"quantity": drag_data["quantity"]
			}
		else:
			# If there's already something there, check if it’s the same item.
			if slot_item["id"] == drag_data["id"]:
				slot_item["quantity"] += drag_data["quantity"]
			# else: different item – leave drag_data unchanged (swap handled elsewhere)

		original_source_container.update_slot(index)

	end_drag()

# ------------------------------------------------------------------
# 🔵 PARTIAL DROP (RIGHT-CLICK) & FULL DROP (LEFT-CLICK)
# ------------------------------------------------------------------

func partial_drop(container: ItemContainerUI, slot_button: Button) -> void:
	if not dragging:
		return
	if drag_data["quantity"] <= 0:
		end_drag(); return

	var index = container.get_slot_index(slot_button)
	if index < 0 or slot_button.slot_type == "output":
		return

	var inv_manager = container.inventory_data_ref
	var dest_item = inv_manager.inventory[index]

	# We always deposit 1 item on partial_drop.
	var deposit_amount = 1

	if dest_item == null:
		inv_manager.inventory[index] = {
			"id": drag_data["id"],
			"quantity": deposit_amount
		}
		drag_data["quantity"] -= deposit_amount
	else:
		if dest_item["id"] != drag_data["id"]:
			return  # Partial drop only for identical items

		var capacity_left = 99 - dest_item["quantity"]
		if capacity_left <= 0:
			return

		dest_item["quantity"] += deposit_amount
		drag_data["quantity"] -= deposit_amount

	# Update visual & UI
	update_drag_visual()
	container.update_slot(index)

	if drag_data["quantity"] <= 0:
		end_drag()

func full_drop(container: ItemContainerUI, slot_button: Button) -> void:
	if not dragging:
		return
	if drag_data["quantity"] <= 0:
		end_drag(); return

	var index = container.get_slot_index(slot_button)
	if index < 0 or slot_button.slot_type == "output":
		return

	var inv_manager = container.inventory_data_ref
	var dest_item = inv_manager.inventory[index]

	if dest_item == null:
		var deposit = min(drag_data["quantity"], 99)
		inv_manager.inventory[index] = {
			"id": drag_data["id"],
			"quantity": deposit
		}
		drag_data["quantity"] -= deposit
	else:
		if dest_item["id"] == drag_data["id"]:
			# Same item → merge
			var capacity_left = 99 - dest_item["quantity"]
			if capacity_left <= 0:
				return
			var deposit = min(drag_data["quantity"], capacity_left)
			dest_item["quantity"] += deposit
			drag_data["quantity"] -= deposit
		else:
			# Different item → swap
			var temp_item = {
				"id": dest_item["id"],
				"quantity": dest_item["quantity"]
			}
			dest_item["id"] = drag_data["id"]
			dest_item["quantity"] = drag_data["quantity"]

			drag_data["id"] = temp_item["id"]
			drag_data["quantity"] = temp_item["quantity"]

	# Update visual & UI
	update_drag_visual()
	container.update_slot(index)

	if drag_data["quantity"] <= 0:
		end_drag()

# ------------------------------------------------------------------
# 🔴 ENDING DRAG & PER-FRAME UPDATE
# ------------------------------------------------------------------

func end_drag():
	dragging = false
	drag_data = { "id": null, "quantity": 0 }
	original_source_container = null
	original_source_index     = -1

	if dragged_visual:
		dragged_visual.queue_free()
		dragged_visual = null

func _process(_delta: float) -> void:
	if dragging and dragged_visual:
		dragged_visual.position = get_viewport().get_mouse_position() - Vector2(32, 32)

# ------------------------------------------------------------------
# 🟣 HELPER – keep icon & quantity in sync
# ------------------------------------------------------------------
func update_drag_visual() -> void:
	if not dragged_visual:
		return

	var icon = dragged_visual.get_node("ItemIcon")
	var qty  = dragged_visual.get_node("ItemQuantity")

	qty.text = str(drag_data["quantity"])

	var item_res = drag_data["id"]
	if item_res is ItemResource:
		icon.texture = item_res.texture
	else:
		push_error("DragManager expected an ItemResource, got: %s" % str(item_res))
		icon.texture = null
