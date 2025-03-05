extends Control
class_name ItemContainerUI

@onready var slot_template = preload("res://scenes/slot_ui.tscn")
@onready var grid_container: GridContainer = null

# UI slot textures
const UI_SLOT = preload("res://assets/UI Sprites/UI_slot.aseprite")
const UI_SLOT_HOVER = preload("res://assets/UI Sprites/UI_slot_hover.aseprite")
const UI_SLOT_DRAG = preload("res://assets/UI Sprites/UI_slot_drag.aseprite")

# Reference to an InventoryManager for this container (e.g. player inv, storage inv)
var inventory_data_ref = null

# ------------------------------------------------------------------
# 🟢 INITIALIZATION
# ------------------------------------------------------------------
func _ready():
	await get_tree().process_frame  # Wait 1 frame so nodes exist
	grid_container = find_grid_container(self)
	if grid_container == null:
		push_error("[ERROR] No GridContainer found in %s" % name)
		return

	if inventory_data_ref:
		_inventory_refresh()
		inventory_data_ref.slot_updated.connect(update_slot)

	# Connect to "closed" signals to cancel drag
	var modules = get_tree().get_nodes_in_group("interactable_modules")
	for module in modules:
		if module.has_signal("closed") and not module.closed.is_connected(_on_ui_closed):
			module.closed.connect(_on_ui_closed)

func find_grid_container(node: Node) -> GridContainer:
	for child in node.get_children():
		if child is GridContainer:
			return child
		if child is Control and child.get_child_count() > 0:
			var found = find_grid_container(child)
			if found:
				return found
	return null

# ------------------------------------------------------------------
# 🔵 INVENTORY UPDATES & UI HANDLING
# ------------------------------------------------------------------
func _inventory_refresh():
	if grid_container == null or inventory_data_ref == null:
		return

	# Clear old slots
	clear_grid_container()

	var inv_size = inventory_data_ref.inventory.size()
	for i in range(inv_size):
		var slot = slot_template.instantiate()
		slot.gui_input.connect(_on_slot_gui_input.bind(slot))
		grid_container.add_child(slot)

		# Display the item from the real inventory
		var real_item = inventory_data_ref.inventory[i]
		if real_item != null:
			set_item(slot, real_item)
		else:
			set_empty(slot)


func update_slot(index: int) -> void:
	if inventory_data_ref == null:
		return
	if index < 0 or index >= inventory_data_ref.inventory.size():
		return
	if grid_container == null or index >= grid_container.get_child_count():
		return

	var slot = grid_container.get_child(index)
	var real_item = inventory_data_ref.inventory[index]
	if real_item != null:
		set_item(slot, real_item)
	else:
		set_empty(slot)

func clear_grid_container():
	while grid_container.get_child_count() > 0:
		var child = grid_container.get_child(0)
		grid_container.remove_child(child)
		child.queue_free()

func _on_ui_closed():
	# If the user closes the UI, optionally cancel drag
	if DragManager.dragging:
		DragManager.cancel_drag()

# ------------------------------------------------------------------
# 🟠 SLOT INTERACTION
# ------------------------------------------------------------------
func _on_slot_gui_input(event: InputEvent, slot: Button):
	if event is InputEventMouseButton and event.pressed:
		var index = get_slot_index(slot)
		if index < 0:
			return  # Invalid slot
		
		# SHIFT + LEFT CLICK
		if event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT):
			ShiftClickManager.shift_click(self, index)  # 🔹 Calls ShiftClickManager
			return

		# Otherwise do normal drag logic
		if DragManager.dragging:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				DragManager.partial_drop(self, slot)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				DragManager.full_drop(self, slot)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				DragManager.start_drag(self, slot, event)

# ------------------------------------------------------------------
# 🟡 PER-FRAME SLOT VISUALS (OPTIONAL)
# ------------------------------------------------------------------
func _process(_delta):
	var hovered_slot = get_slot_under_mouse()
	
	for i in range(grid_container.get_child_count()):
		var slot = grid_container.get_child(i)
		var slot_sprite = slot.get_node_or_null("SlotSprite")
		if not slot_sprite:
			continue

		# Is this slot the "original source slot" for the current drag?
		var is_drag_source = false
		if DragManager.dragging:
			# Check if the container is this UI, 
			# and if the slot index is the same as original_source_index:
			if DragManager.original_source_container == self and i == DragManager.original_source_index:
				is_drag_source = true

		if is_drag_source:
			slot_sprite.texture = UI_SLOT_DRAG
		elif slot == hovered_slot:
			slot_sprite.texture = UI_SLOT_HOVER
		else:
			slot_sprite.texture = UI_SLOT


# ------------------------------------------------------------------
# 🔵 SLOT LOOKUP & UTILITIES
# ------------------------------------------------------------------
func get_slot_index(slot: Control) -> int:
	if slot == null:
		return -1
	if grid_container:
		for i in range(grid_container.get_child_count()):
			if grid_container.get_child(i) == slot:
				return i
	return -1

func get_slot_under_mouse() -> Button:
	var mouse_pos = get_viewport().get_mouse_position()
	if grid_container:
		for child in grid_container.get_children():
			if not (child is Control):
				continue  # skip non-Controls
			var slot_control := child as Control
			if Rect2(slot_control.global_position, slot_control.size).has_point(mouse_pos):
				# Optionally check if it's a Button:
				if slot_control is Button:
					return slot_control
	return null

func get_active_other_ui() -> ItemContainerUI:
	var ui_nodes = get_tree().get_nodes_in_group("interactable_ui")
	for ui in ui_nodes:
		# ui must be an ItemContainerUI, must be visible, and not 'self'
		if ui is ItemContainerUI and ui != self and ui.visible:
			return ui as ItemContainerUI
	return null

# ------------------------------------------------------------------
# 🔴 SLOT VISUAL HELPERS
# ------------------------------------------------------------------
func set_empty(slot: Button):
	if slot:
		var icon = slot.get_node_or_null("SlotSprite/ItemIcon")
		var quantity = slot.get_node_or_null("SlotSprite/ItemQuantity")
		if icon:
			icon.texture = null
		if quantity:
			quantity.text = ""

func set_item(slot: Button, new_item: Dictionary):
	if slot:
		var icon = slot.get_node_or_null("SlotSprite/ItemIcon")
		var quantity_label = slot.get_node_or_null("SlotSprite/ItemQuantity")
		if icon:
			icon.texture = new_item["item_texture"]
		if quantity_label:
			quantity_label.text = str(new_item["item_quantity"])
