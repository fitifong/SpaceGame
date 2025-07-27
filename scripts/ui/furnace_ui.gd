extends ItemContainerUI

@onready var smelt_button: Button = $NinePatchRect/SmeltButton
@onready var input_slot: Button = $NinePatchRect/GridContainer/SlotUI1
@onready var output_slot: Button = $NinePatchRect/GridContainer/OutputSlot

func _ready() -> void:
	add_to_group("interactable_ui")
	slot_type_map = {0: "input", 1: "output"}
	super._ready()
	visible = true

	smelt_button.pressed.connect(_on_smelt_pressed)
	# (No direct slot_updated connection here— it’s done by FurnaceModule.gd in open())

func set_inventory_ref(ref) -> void:
	inventory_data_ref = ref

	# Connect smelt progress signal
	if inventory_data_ref.has_signal("smelt_progress_updated"):
		if not inventory_data_ref.smelt_progress_updated.is_connected(update_progress_bar):
			inventory_data_ref.smelt_progress_updated.connect(update_progress_bar)

	# Restore smelt button visual
	update_smelt_button_visuals()

	# If there's a current recipe and the timer is > 0, restore the bar
	if inventory_data_ref.current_recipe != null and inventory_data_ref.smelt_timer > 0:
		var percent = inventory_data_ref.smelt_timer / inventory_data_ref.current_recipe.smelt_time
		update_progress_bar(percent)
	else:
		# Or, if you want to hide it when there's no partial smelt in progress, do:
		update_progress_bar(0.0)  # "hide" logic inside `update_progress_bar`

func _on_smelt_pressed() -> void:
	if inventory_data_ref == null:
		return
	inventory_data_ref.is_smelting = not inventory_data_ref.is_smelting
	update_smelt_button_visuals()

func update_smelt_button_visuals() -> void:
	if inventory_data_ref == null:
		return

	var is_active = inventory_data_ref.is_smelting
	smelt_button.modulate = Color(1, 0.6, 0.2) if is_active else Color(1, 1, 1)

	# Optional furnace sprite change
	if inventory_data_ref.has_method("update_furnace_sprite"):
		inventory_data_ref.update_furnace_sprite(is_active)

func update_progress_bar(percent: float) -> void:
	var progress_sprite = get_node_or_null("NinePatchRect/ProgressBar")
	if progress_sprite == null:
		return
	
	# If we receive 0.0, that means "smelting is done" → hide the bar
	if percent <= 0.0:
		progress_sprite.visible = false
		return

	# Otherwise show and update the frame
	progress_sprite.visible = true

	var clamped_percent = clamp(percent, 0.0, 1.0)
	var frame_index = int(clamped_percent * 100/9)  # 0..10 for 11 frames
	frame_index = clamp(frame_index, 0, 10)

	if progress_sprite.has_method("set_frame"):
		progress_sprite.set_frame(frame_index)


func _on_output_slot_updated(index: int) -> void:
	# This is called from FurnaceModule’s slot_updated.emit()
	if index != 1:
		return

	if inventory_data_ref == null:
		return

	# If the output slot is empty, hide the bar
	var bar = get_node_or_null("NinePatchRect/ProgressBar")
	var output_item = inventory_data_ref.inventory[1]

	# If there's no item in the output slot, we hide the bar
	if output_item == null and bar:
		bar.visible = false

func get_slot_index_by_type(requested_type: String) -> int:
	# Safeguard if slot_type_map isn't defined
	if not slot_type_map:
		return -1

	for index in slot_type_map.keys():
		if slot_type_map[index] == requested_type:
			return index
	return -1  # If not found
