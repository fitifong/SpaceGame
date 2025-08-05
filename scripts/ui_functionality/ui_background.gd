# scripts/ui_functionality/ui_background.gd
# UPDATED VERSION - Uses consolidated UIManager
extends Control

func _ready():
	set_process_input(true)  # Ensure the script processes input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# If the user clicks the background while dragging, cancel it.
		if UIManager.dragging:
			var src_container = UIManager.original_source_container
			# Store the index before canceling the drag (cancel_drag may reset it)
			var src_index = UIManager.original_source_index
			UIManager.cancel_drag()

			# Once the drag is canceled, update only the source slot
			if src_container and src_index != -1:
				src_container.update_slot(src_index)
