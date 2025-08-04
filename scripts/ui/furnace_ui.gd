# scripts/ui/furnace_ui.gd
extends ItemContainerUI

@export var smelt_button: Button
@export var input_slot: Button
@export var output_slot: Button
@export var progress_bar_sprite: AnimatedSprite2D  # drag-in your ProgressBar here

var module_ref

func _ready() -> void:
	add_to_group("interactable_ui")
	slot_type_map = { 0: "input", 1: "output" }
	super._ready()
	visible = true

	if smelt_button:
		smelt_button.pressed.connect(_on_smelt_pressed)

	if progress_bar_sprite:
		progress_bar_sprite.animation = "progress"
		progress_bar_sprite.visible   = false

func set_module_ref(ref) -> void:
	module_ref = ref
	inventory_data_ref = ref

	if module_ref and module_ref.has_signal("smelt_progress_updated"):
		if not module_ref.smelt_progress_updated.is_connected(update_progress_bar):
			module_ref.smelt_progress_updated.connect(update_progress_bar)

	_update_smelt_button_visuals()

	if module_ref.smelt_enabled and module_ref.is_smelting:
		var pct = module_ref.smelt_timer / module_ref.current_recipe.smelt_time
		update_progress_bar(pct)
	else:
		update_progress_bar(0.0)

func _on_smelt_pressed() -> void:
	if module_ref:
		module_ref.toggle_smelting_enabled()
		_update_smelt_button_visuals()

func _update_smelt_button_visuals() -> void:
	if not smelt_button or not module_ref:
		return

	if module_ref.smelt_enabled:
		smelt_button.modulate = Color(1, 0.6, 0.2)
	else:
		smelt_button.modulate = Color(1, 1, 1)

func update_progress_bar(percent: float) -> void:
	if not progress_bar_sprite:
		return

	if percent <= 0.0:
		progress_bar_sprite.visible = false
		return

	progress_bar_sprite.visible = true
	var idx = int(clamp(percent, 0.0, 1.0) * 10)
	progress_bar_sprite.frame = idx

func _on_output_slot_updated(index: int) -> void:
	if index != 1:
		return
	var out = inventory_data_ref.get_item(1)
	if out == null or out.is_empty():
		if progress_bar_sprite:
			progress_bar_sprite.visible = false
