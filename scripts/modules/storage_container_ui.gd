extends ItemContainerUI
class_name StorageContainerUI

@onready var player_inventory_ui: Control = get_node("/root/Game/GUIs/PlayerInventoryUI")  

var storage_data = null  # Storage inventory reference

# ----------------- 🟢 INITIALIZATION ----------------- #
func _ready():
	add_to_group("interactable_ui")
	super._ready()
	visible = true

# Retrieves the player's inventory as the other UI for item transfers
func get_active_container():
	return player_inventory_ui
