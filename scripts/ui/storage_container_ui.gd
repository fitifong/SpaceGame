extends ItemContainerUI
class_name StorageContainerUI

var storage_data = null  # Storage inventory reference

# ----------------- 🟢 INITIALIZATION ----------------- #
func _ready():
	add_to_group("interactable_ui")
	super._ready()
	visible = true
