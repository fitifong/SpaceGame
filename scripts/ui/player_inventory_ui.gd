# scripts/ui/player_inventory_ui.gd
# SIMPLE VERSION - Now that PlayerInventory uses components
extends ItemContainerUI
class_name PlayerInventoryUI

var is_open: bool = true
var active_container_ui: Control = null

func _ready():
	add_to_group("interactable_ui")
	inventory_data_ref = PlayerInventory  # PlayerInventory now has components!
	super._ready()
	open()

func get_active_container():
	return UIManager.get_active_ui()

func open():
	visible = true
	is_open = true
	if UIManager:
		UIManager.register_ui(self)
	active_container_ui = get_active_container()

func close():
	visible = false
	is_open = false
	if UIManager:
		UIManager.unregister_ui(self)
	active_container_ui = null
