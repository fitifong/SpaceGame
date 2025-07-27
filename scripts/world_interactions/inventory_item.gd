extends Node2D
class_name InventoryItem

@export var item_id: ItemResource
@export var item_quantity: int

var scene_path: String = "res://scenes/inventory_item.tscn"

@onready var icon_sprite: Sprite2D = $Sprite2D
var player_in_range = false

# ----------------- 🟢 INITIALIZATION ----------------- #
func _ready() -> void:
	if not Engine.is_editor_hint():
		icon_sprite.texture = item_id.texture

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		icon_sprite.texture = item_id.texture

	if player_in_range and Input.is_action_just_pressed("pickup_item"):
		pickup_item()

# ----------------- 🔵 ITEM PICKUP ----------------- #
# Adds item to player's inventory, reverts leftover to ground if can't fit all.
func pickup_item():
	# Safeguard
	if item_id == null:
		push_error("InventoryItem is missing an item_id")
		return

	# Dictionary uses the resource directly.
	var pickup_data = {
		"item_id": item_id,  # ✅ Now a reference to the ItemResource
		"quantity": item_quantity
	}

	if PlayerInventory.player_node:
		var leftover = PlayerInventory.add_pickup(pickup_data)

		if leftover <= 0:
			queue_free()  # All items picked up
		else:
			item_quantity = leftover  # Leave the remainder
# ----------------- 🟠 PLAYER INTERACTION ----------------- #
# Toggle 'player_in_range' on collision
func _on_area_2d_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		body.pickup_ui.visible = true

func _on_area_2d_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		body.pickup_ui.visible = false
