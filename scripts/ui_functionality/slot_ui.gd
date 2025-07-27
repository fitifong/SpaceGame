extends Button
class_name SlotUI

@onready var item_icon = $SlotSprite/ItemIcon
@onready var item_quantity = $SlotSprite/ItemQuantity

@export var slot_type := "input" 

var slot_data = {}  # { "id": int, "quantity": int }

# Accept any item drop by default
func can_accept_drop() -> bool:
	return true

# Allow external systems to set this slot's data
func set_slot_data(data: Dictionary) -> void:
	slot_data = data
	update_ui()

# Update visuals based on slot_data contents
func update_ui() -> void:
	if slot_data.is_empty():
		item_icon.texture = null
		item_quantity.text = ""
		return

	var item_res = slot_data["id"]   # now always an ItemResource
	if item_res is ItemResource:
		item_icon.texture = item_res.texture
	else:
		push_warning("SlotUI: unexpected id type %s" % typeof(item_res))
		item_icon.texture = null

	item_quantity.text = str(slot_data["quantity"])

func get_slot_sprite() -> Sprite2D:
	return get_node_or_null("SlotSprite")

func get_icon() -> Sprite2D:
	return item_icon

func get_quantity() -> Label:
	return item_quantity
