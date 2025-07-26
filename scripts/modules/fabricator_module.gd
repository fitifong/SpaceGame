extends StaticBody2D
class_name FabricatorModule

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)

@onready var interaction_prompt: Control = $InteractionPrompt
@onready var interaction_area: Area2D = $InteractionArea
@onready var fabricator_sprite: AnimatedSprite2D = $FabricatorSprite
@onready var fabricator_ui_scene = preload("res://scenes/ui/module_ui/fabricator_ui.tscn")

var inventory: Array = []
var inventory_size := 0
var ui_instance: Control = null
var is_processing := false

# New flags to track door animation state
var awaiting_door_to_close: bool = false  # True while the door closing animation is playing
var awaiting_door_to_open: bool = false   # True while the door opening animation is playing

# ------------------------- READY -------------------------
func _ready():
	add_to_group("interactable_modules")
	interaction_prompt.z_index = 999
	interaction_prompt.visible = false
	fabricator_sprite.play("static_closed")
	set_inventory_size(4)
	
func set_inventory_size(size: int) -> void:
	inventory_size = size
	inventory.resize(size)

# -------------------- PLAYER INTERACTION --------------------
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.append(self)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.erase(self)
		if ui_instance:
			close()

func interact():
	if is_processing:
		return  # Prevent interaction while processing
	# Use the open() method instead of the old animation helper. The open() method
	# will now handle playing the door closing animation before showing the UI.
	open()


# -------------------- ANIMATION + UI HANDLING --------------------
func play_door_open_and_show_ui():
	var anim_name = "door"
	var frame_count = fabricator_sprite.sprite_frames.get_frame_count(anim_name)
	var fps = fabricator_sprite.sprite_frames.get_animation_speed(anim_name)
	var duration = float(frame_count) / float(fps)

	fabricator_sprite.play("door", -1.0, true)  # Reverse = door opening
	await get_tree().create_timer(duration).timeout

	fabricator_sprite.play("static_open")
	open()

# ----------------------------------------------------------------------
# 🔧 ANIMATION CALLBACKS
#
# These helper functions are connected to the AnimatedSprite2D's
# animation_finished signal. They allow us to sequence the door closing and
# opening animations without blocking the caller. After the door closes
# completely, the UI is created and displayed. After the door opens,
# the static frame is set and the interaction prompt is re-shown.
#
func _on_door_close_animation_finished() -> void:
	# This callback runs once the door closing animation finishes.
	# Disconnect the signal to avoid multiple calls and clear the flag.
	if fabricator_sprite.animation_finished.is_connected(_on_door_close_animation_finished):
		fabricator_sprite.animation_finished.disconnect(_on_door_close_animation_finished)
	awaiting_door_to_close = false

	# Ensure the sprite stays on the closed frame
	fabricator_sprite.play("static_open")

	# Instantiate and register the UI now that the door is closed
	if ui_instance == null:
		var gui_layer = get_node("/root/Game/GUIs")
		ui_instance = fabricator_ui_scene.instantiate()
		gui_layer.add_child(ui_instance)
		UIManager.register_ui(ui_instance)
		# Set up inventory access
		ui_instance.set_inventory_ref(self)
		# Emit the module_opened signal for any listeners
		module_opened.emit(ui_instance)

func _on_door_open_animation_finished() -> void:
	# This callback runs once the door opening (reverse) animation finishes.
	# Disconnect the signal and clear the flag.
	if fabricator_sprite.animation_finished.is_connected(_on_door_open_animation_finished):
		fabricator_sprite.animation_finished.disconnect(_on_door_open_animation_finished)
	awaiting_door_to_open = false

	# Set the sprite to the static open frame so it stays open
	fabricator_sprite.play("static_closed")
	# Re-enable the interaction prompt so the player can interact again
	interaction_prompt.visible = true

func open():
	# Modified to play the door closing animation before opening the UI.
	# If the UI is already present, do nothing.
	if ui_instance != null:
		return

	# Prevent opening while processing (fabrication in progress)
	if is_processing:
		return

	# Safety check for the UI scene
	if fabricator_ui_scene == null:
		push_error("[ERROR] fabricator_ui_scene is null! Ensure it's assigned.")
		return

	# If a door animation is already playing, do not attempt to start another
	if awaiting_door_to_close or awaiting_door_to_open:
		return

	# Hide the interaction prompt immediately
	interaction_prompt.visible = false

	# Start closing the door. We connect to the animation_finished signal so that
	# once the door has fully closed we can instantiate and display the UI. We
	# mark the flag so that subsequent open() calls won't trigger additional
	# animations.
	awaiting_door_to_close = true
	# Ensure previous connections are cleared to avoid duplicate calls
	if fabricator_sprite.animation_finished.is_connected(_on_door_close_animation_finished):
		fabricator_sprite.animation_finished.disconnect(_on_door_close_animation_finished)
	fabricator_sprite.animation_finished.connect(_on_door_close_animation_finished)

	# Play the door animation forward (custom_speed = 1.0). This will visually
	# close the door. Once finished, the connected callback will run.
	fabricator_sprite.play("door", 1.0)

func close():
	# Modified to play the door opening animation (in reverse) after closing the UI.
	# If there is no UI to close, simply ensure the door is open.
	if ui_instance != null:
		# Unregister and remove the UI instance immediately
		UIManager.unregister_ui(ui_instance)
		ui_instance.queue_free()
		ui_instance = null

	# Emit the closed signal so listeners know the UI has been closed
	closed.emit()

	# If a door animation is already in progress, do not start another
	if awaiting_door_to_open or awaiting_door_to_close:
		return

	# Start opening the door in reverse. When the animation finishes the
	# connected callback will update the sprite to the static open frame and
	# re-enable the interaction prompt.
	awaiting_door_to_open = true
	if fabricator_sprite.animation_finished.is_connected(_on_door_open_animation_finished):
		fabricator_sprite.animation_finished.disconnect(_on_door_open_animation_finished)
	fabricator_sprite.animation_finished.connect(_on_door_open_animation_finished)
	fabricator_sprite.play("door", -1.0, true)  # Negative speed with from_end = true plays it backwards


# -------------------- (TO BE IMPLEMENTED) --------------------
func start_fabrication():
	is_processing = true

	# Step 5.2+ will control this with recipe logic
	fabricator_sprite.play("door")  # door closes
	await fabricator_sprite.animation_finished

	fabricator_sprite.play("process")  # fabrication in progress
	# NOTE: We'll manage timing + post-animation logic in 5.2/5.3
