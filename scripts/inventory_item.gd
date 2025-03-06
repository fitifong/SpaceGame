extends Node2D
class_name InventoryItem

@export var item_id: int = 0
@export var item_texture: Texture
@export var item_quantity: int

var scene_path: String = "res://scenes/inventory_item.tscn"

@onready var icon_sprite: Sprite2D = $Sprite2D
var player_in_range = false

# ----------------- 🟢 INITIALIZATION ----------------- #
func _ready() -> void:
	if not Engine.is_editor_hint():
		icon_sprite.texture = item_texture

# Called each frame; used here to handle pick-up input
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		icon_sprite.texture = item_texture

	if player_in_range and Input.is_action_just_pressed("pickup_item"):
		pickup_item()

# ----------------- 🔵 ITEM PICKUP ----------------- #
# Adds item to player's inventory, reverts leftover to ground if can't fit all.
func pickup_item():
	# Build pickup data with only the unique id and quantity.
	var pickup_data = {
		"item_id": item_id,
		"item_quantity": item_quantity
	}
	
	# Attempt to add the item to the player's inventory.
	if PlayerInventory.player_node:
		var leftover = PlayerInventory.add_pickup(pickup_data)
		
		if leftover <= 0:
			# All items fit; remove the pickup from the world.
			queue_free()
		else:
			# Some items couldn't be added, so update the quantity.
			item_quantity = leftover

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
