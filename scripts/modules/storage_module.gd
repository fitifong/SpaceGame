extends StaticBody2D
class_name StorageModule

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)

@export var storage_ui_scene: PackedScene
@export var interaction_prompt: Control
@export var interaction_area: Area2D

var inventory: Array = []

var inventory_size: int = 0
var ui_instance: Control = null  # Instance of the storage UI
# ----------------- 🟢 INITIALIZATION ----------------- #
func _ready():
	add_to_group("interactable_modules")
	interaction_prompt.z_index = 999
	interaction_prompt.visible = false
	
	set_inventory_size(25)

func set_inventory_size(size: int) -> void:
	inventory_size = size
	inventory.resize(size)

# ----------------- 🔵 PLAYER INTERACTION ----------------- #
# Shows the interaction prompt when the player enters range
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.append(self)

# Hides the interaction prompt and closes UI if the player leaves
func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.erase(self)
		if ui_instance:
			close()

# ----------------- 🟠 OPENING & CLOSING UI ----------------- #
# Opens the storage UI when interacted with
func open():
	if ui_instance == null:
		if storage_ui_scene == null:
			push_error("[ERROR] storage_ui_scene is null! Ensure it's assigned.")
			return  

		interaction_prompt.visible = false
		
		ui_instance = storage_ui_scene.instantiate()
		
		if ui_instance.has_method("set_inventory_ref"):
			ui_instance.set_inventory_ref(self)
		else:
			ui_instance.inventory_data_ref = self

		ui_instance.inventory_data_ref = self  # ✅ Let the UI show our inventory
		UIManager.add_ui(ui_instance)

		UIManager.register_ui(ui_instance)  # Register the storage UI
		
		# Set the inventory reference
		module_opened.emit(ui_instance)

# Closes the storage UI and cleans up references
func close():
	interaction_prompt.visible = true
	UIManager.unregister_ui(ui_instance)  # Unregister the storage UI
	closed.emit()
	if ui_instance:
		ui_instance.queue_free()
		ui_instance = null
