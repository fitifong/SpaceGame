extends ItemContainerUI
class_name PlayerInventoryUI

var is_open: bool = true  # Tracks if the inventory UI is currently open
var active_container_ui: Control = null  # Reference to currently active UI (storage, fabricator, engine, etc.)

# ----------------- 🟢 INITIALIZATION ----------------- #
func _ready():
	add_to_group("interactable_ui")
	inventory_data_ref = PlayerInventory  # Always reference the player's inventory
	super._ready()
	open()

# Returns the currently active UI (excluding Player Inventory) for swaps
func get_active_container():
	return UIManager.get_active_ui()  # Queries UIManager for the active UI

# ----------------- 🟠 OPEN & CLOSE INVENTORY ----------------- #
# Opens the player inventory UI
func open():
	visible = true
	is_open = true
	if UIManager:
		UIManager.register_ui(self)  # ✅ Register with UIManager only if it's available
	active_container_ui = get_active_container()

# Closes the player inventory UI
func close():
	visible = false
	is_open = false
	if UIManager:
		UIManager.unregister_ui(self)  # ✅ Unregister from UIManager
	active_container_ui = null  # Reset the active UI reference
