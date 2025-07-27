extends Node

@export var ui_root: Node  # Drag your "GUIs" node into this in the editor

var active_ui_containers: Array = []

# ----------------- 🟢 REGISTERING UI ELEMENTS ----------------- #
func register_ui(ui: Control) -> void:
	if ui and ui not in active_ui_containers:
		active_ui_containers.append(ui)

func unregister_ui(ui: Control) -> void:
	if ui in active_ui_containers:
		active_ui_containers.erase(ui)

func add_ui(ui: Control) -> void:
	if ui_root:
		ui_root.add_child(ui)
	else:
		push_error("[UIManager] ui_root not assigned. Cannot parent UI.")

# ----------------- 🔵 RETRIEVING ACTIVE UI ----------------- #
func get_active_ui() -> Control:
	# Return the first open UI that isn't the player inventory
	for ui in active_ui_containers:
		if ui.visible:
			return ui
	return null  # No valid UI found

func get_inventory_ui() -> PlayerInventoryUI:
	for ui in active_ui_containers:
		if ui is PlayerInventoryUI:
			return ui
	return null

func is_ui_active() -> bool:
	return active_ui_containers.size() > 0

# ----------------- 🟠 CLEANUP & DEBUG ----------------- #
func clear_all_ui():
	active_ui_containers.clear()

func print_active_ui():
	print("Active UIs:", active_ui_containers)
