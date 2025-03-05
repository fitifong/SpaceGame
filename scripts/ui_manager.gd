extends Node

var active_ui_containers: Array = []

# ----------------- 🟢 REGISTERING UI ELEMENTS ----------------- #
func register_ui(ui: Control) -> void:
	if ui and ui not in active_ui_containers:
		active_ui_containers.append(ui)

func unregister_ui(ui: Control) -> void:
	if ui in active_ui_containers:
		active_ui_containers.erase(ui)

# ----------------- 🔵 RETRIEVING ACTIVE UI ----------------- #
func get_active_ui() -> Control:
	# Return the first open UI that isn't the player inventory
	for ui in active_ui_containers:
		if ui.visible:
			return ui
	return null  # No valid UI found

func is_ui_active() -> bool:
	return active_ui_containers.size() > 0

# ----------------- 🟠 CLEANUP & DEBUG ----------------- #
func clear_all_ui():
	active_ui_containers.clear()

func print_active_ui():
	print("Active UIs:", active_ui_containers)
