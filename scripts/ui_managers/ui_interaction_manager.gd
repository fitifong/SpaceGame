extends Node
class_name UIInteractionManager

# -------------------------------------------------------------------
# A thin façade that routes all UI interaction calls to the proper
# single‑responsibility autoload managers:
#
#  • DragManager       – drag & drop
#  • ShiftClickManager – shift+click transfers
#  • TooltipManager    – hover tooltips
#  • ContextMenuManager– right‑click context menus
# -------------------------------------------------------------------

# -------------------- Drag-and-Drop API --------------------

func is_dragging() -> bool:
	return DragManager.dragging

func start_drag(container: ItemContainerUI, slot_button: Button, event: InputEventMouseButton) -> void:
	DragManager.start_drag(container, slot_button, event)

func full_drop(container: ItemContainerUI, target_slot: Button) -> void:
	DragManager.full_drop(container, target_slot)

func partial_drop(container: ItemContainerUI, target_slot: Button) -> void:
	DragManager.partial_drop(container, target_slot)

func cancel_drag() -> void:
	DragManager.cancel_drag()

# -------------------- Shift-Click API --------------------
func shift_click(container: ItemContainerUI, slot_index: int) -> void:
	ShiftClickManager.shift_click(container, slot_index)
