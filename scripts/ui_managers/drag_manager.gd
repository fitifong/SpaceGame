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
	# FIXED: Input validation
	if not container:
		push_error("[DragManager] Cannot start drag: container is null")
		return
		
	if not slot_button:
		push_error("[DragManager] Cannot start drag: slot_button is null")
		return
		
	if not event:
		push_error("[DragManager] Cannot start drag: event is null")
		return
		
	if dragging:
		return  # Already dragging something

	# Get the slot index in the container.
	var index = container.get_slot_index(slot_button)
	if index < 0:
		push_warning("[DragManager] Invalid slot index for drag start")
		return

	if not container.inventory_data_ref:
		push_error("[DragManager] Container has no inventory_data_ref")
		return

	var inv_manager = container.inventory_data_ref
	if index >= inv_manager.inventory.size():
		push_error("[DragManager] Slot index %d exceeds inventory size %d" % [index, inv_manager.inventory.size()])
		return
		
	var source_item = inv_manager.inventory[index]
	if not source_item:
		return  # Nothing to drag

	# FIXED: Ensure item ID is ItemResource
	if source_item["id"] is int:
		var item_resource = ItemDatabase.get_item_data(source_item["id"])
		if not item_resource:
			push_error("[DragManager] Could not find ItemResource for ID: %d" % source_item["id"])
			return
		source_item["id"] = item_resource

	# Decide if it's a full drag or a right-click split.
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Full drag: take the entire stack.
		drag_data["id"] = source_item["id"]
		drag_data["quantity"] = source_item["quantity"]
		inv_manager.inventory[index] = null
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click split: drag half the stack.
		var half_stack = ceili(source_item["quantity"] / 2.0)
		drag_data["id"] = source_item["id"]
		drag_data["quantity"] = half_stack
		# Remove the half from the source stack
		source_item["quantity"] -= half_stack
		if source_item["quantity"] <= 0:
			inv_manager.inventory[index] = null
	else:
		return  # Other mouse buttons not handled

	# Remember the original source so that we can revert if needed.
	original_source_container = container
	original_source_index     = index

	# Create the floating dragged icon.
	if not dragged_item_scene:
		push_error("[DragManager] dragged_item_scene is null - cannot create drag visual")
		_cleanup_drag_state()
		return
		
	dragged_visual = dragged_item_scene.instantiate()
	if not dragged_visual:
		push_error("[DragManager] Failed to instantiate dragged_item_scene")
		_cleanup_drag_state()
		return
		
	dragged_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through
	
	if UIManager:
		UIManager.add_ui(dragged_visual)
	else:
		push_error("[DragManager] UIManager not available")
		_cleanup_drag_state()
		return

	# Update drag visual
	update_drag_visual()

	dragging = true
	
	# Refresh UI so the source slot now shows the updated (reduced or empty) stack.
	container.update_slot(index)

# FIXED: Helper function to clean up drag state on errors
func _cleanup_drag_state():
	dragging = false
	drag_data = {"id": null, "quantity": 0}
	original_source_container = null
	original_source_index = -1
	if dragged_visual:
		dragged_visual.queue_free()
		dragged_visual = null

# If the player cancels the drag (clicks the background or presses ESC), revert any remaining items back to the source slot.
func cancel_drag():
	if not dragging:
		return

	if drag_data["quantity"] > 0 and original_source_container:
		if not original_source_container.inventory_data_ref:
			push_error("[DragManager] Cannot cancel drag: original container has no inventory_data_ref")
			end_drag()
			return
			
		var index = original_source_index
		if index < 0 or index >= original_source_container.inventory_data_ref.inventory.size():
			push_error("[DragManager] Cannot cancel drag: invalid original index %d" % index)
			end_drag()
			return
			
		var inv_manager = original_source_container.inventory_data_ref
		var slot_item  = inv_manager.inventory[index]

		if not slot_item:
			# If the source is still empty, restore the dragged items.
			inv_manager.inventory[index] = {
				"id": drag_data["id"],
				"quantity": drag_data["quantity"]
			}
		else:
			# If there's already something there, check if it's the same item.
			if slot_item["id"] == drag_data["id"]:
				slot_item["quantity"] += drag_data["quantity"]
			# else: different item – leave drag_data unchanged (swap handled elsewhere)

		original_source_container.update_slot(index)

	end_drag()

# ------------------------------------------------------------------
# 🔵 PARTIAL DROP (RIGHT-CLICK) & FULL DROP (LEFT-CLICK)
# ------------------------------------------------------------------

func partial_drop(container: ItemContainerUI, slot_button: Button) -> void:
	# FIXED: Input validation
	if not container:
		push_error("[DragManager] Cannot partial drop: container is null")
		return
		
	if not slot_button:
		push_error("[DragManager] Cannot partial drop: slot_button is null")
		return
		
	if not dragging:
		return
		
	if drag_data["quantity"] <= 0:
		end_drag()
		return

	var index = container.get_slot_index(slot_button)
	if index < 0:
		push_warning("[DragManager] Invalid slot for partial drop")
		return
		
	# FIXED: Check slot type using property access
	if "slot_type" in slot_button and slot_button.slot_type == GameConstants.SLOT_TYPE_OUTPUT:
		return

	if not container.inventory_data_ref:
		push_error("[DragManager] Cannot partial drop: container has no inventory_data_ref")
		return

	var inv_manager = container.inventory_data_ref
	if index >= inv_manager.inventory.size():
		push_error("[DragManager] Partial drop index %d exceeds inventory size %d" % [index, inv_manager.inventory.size()])
		return
		
	var dest_item = inv_manager.inventory[index]

	# We always deposit 1 item on partial_drop.
	var deposit_amount = 1

	if not dest_item:
		inv_manager.inventory[index] = {
			"id": drag_data["id"],
			"quantity": deposit_amount
		}
		drag_data["quantity"] -= deposit_amount
	else:
		if dest_item["id"] != drag_data["id"]:
			return  # Partial drop only for identical items

		var capacity_left = GameConstants.MAX_STACK_SIZE - dest_item["quantity"]
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
	# FIXED: Input validation
	if not container:
		push_error("[DragManager] Cannot full drop: container is null")
		return
		
	if not slot_button:
		push_error("[DragManager] Cannot full drop: slot_button is null")
		return
		
	if not dragging:
		return
		
	if drag_data["quantity"] <= 0:
		end_drag()
		return

	var index = container.get_slot_index(slot_button)
	if index < 0:
		push_warning("[DragManager] Invalid slot for full drop")
		return
		
	# FIXED: Check slot type using property access
	if "slot_type" in slot_button and slot_button.slot_type == GameConstants.SLOT_TYPE_OUTPUT:
		return

	if not container.inventory_data_ref:
		push_error("[DragManager] Cannot full drop: container has no inventory_data_ref")
		return

	var inv_manager = container.inventory_data_ref
	if index >= inv_manager.inventory.size():
		push_error("[DragManager] Full drop index %d exceeds inventory size %d" % [index, inv_manager.inventory.size()])
		return
		
	var dest_item = inv_manager.inventory[index]

	if not dest_item:
		var deposit = min(drag_data["quantity"], GameConstants.MAX_STACK_SIZE)
		inv_manager.inventory[index] = {
			"id": drag_data["id"],
			"quantity": deposit
		}
		drag_data["quantity"] -= deposit
	else:
		if dest_item["id"] == drag_data["id"]:
			# Same item → merge
			var capacity_left = GameConstants.MAX_STACK_SIZE - dest_item["quantity"]
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
		dragged_visual.position = get_viewport().get_mouse_position() - GameConstants.DRAG_VISUAL_OFFSET

# ------------------------------------------------------------------
# 🟣 HELPER – keep icon & quantity in sync
# ------------------------------------------------------------------
func update_drag_visual() -> void:
	if not dragged_visual:
		return

	var icon = dragged_visual.get_node_or_null("ItemIcon")
	var qty  = dragged_visual.get_node_or_null("ItemQuantity")

	if not icon or not qty:
		push_warning("[DragManager] Dragged visual missing ItemIcon or ItemQuantity nodes")
		return

	qty.text = str(drag_data["quantity"])

	var item_res = drag_data["id"]
	if item_res is ItemResource:
		icon.texture = item_res.texture
	else:
		push_error("DragManager expected an ItemResource, got: %s" % str(item_res))
		icon.texture = null
