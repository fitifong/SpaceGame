extends Button

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

	var item_data = ItemDatabase.get_item_data(slot_data["id"])
	if item_data:
		item_icon.texture = item_data.texture
		item_quantity.text = str(slot_data["quantity"])
