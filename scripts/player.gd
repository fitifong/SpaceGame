extends CharacterBody2D
class_name Player

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var pickup_ui = $PickupUI
@onready var interaction_area: Area2D = $InteractionArea

const MOVE_SPEED = 125.0
var facing_direction = "down"
var closest_module: Node = null

# This will track all modules that the player is inside the Area2D of
var modules_in_range: Array = []

# ----------------- 🟢 INITIALIZATION ----------------- #
func _ready():
	PlayerInventory.set_player_reference(self)

# ----------------- 🔵 PLAYER MOVEMENT ----------------- #
# Determines movement direction based on input
func get_input() -> Vector2:
	var input_vector = Vector2()
	var horizontal_pressed = false
	var vertical_pressed = false

	# --- Collect ALL presses so we can do diagonal movement ---
	# Horizontal
	if Input.is_action_pressed("move_right"):
		input_vector.x = 1
		horizontal_pressed = true
	elif Input.is_action_pressed("move_left"):
		input_vector.x = -1
		horizontal_pressed = true

	# Vertical
	if Input.is_action_pressed("move_down"):
		input_vector.y = 1
		vertical_pressed = true
	elif Input.is_action_pressed("move_up"):
		input_vector.y = -1
		vertical_pressed = true

	# --- Decide facing_direction and animation priority ---
	# If horizontal is pressed at all, it overrides facing
	if horizontal_pressed:
		if input_vector.x > 0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	# If no horizontal but we do have vertical
	elif vertical_pressed:
		if input_vector.y > 0:
			facing_direction = "down"
		else:
			facing_direction = "up"

	# --- Normalize diagonal movement if both x and y are pressed ---
	if input_vector.length() > 1:
		input_vector = input_vector.normalized()

	return input_vector
	
func _physics_process(_delta):
	var direction = get_input()
	
	# If the player tries to move (direction != Vector2.ZERO)
	# and there's a closest_module with an open UI, close it.
	if direction != Vector2.ZERO and closest_module and closest_module.ui_instance != null:
		# This means the module is currently open
		closest_module.close()
	
	if direction == Vector2.ZERO:
		animation_player.play("idle_" + facing_direction)
	else:
		match facing_direction:
			"left":
				animation_player.play("walk_left")
			"right":
				animation_player.play("walk_right")
			"up":
				animation_player.play("walk_up")
			"down":
				animation_player.play("walk_down")
		
	velocity = direction * MOVE_SPEED
	move_and_slide()

# ----------------- 🟠 INTERACTING WITH MODULES ----------------- #
# Checks for the closest interactable module
func update_closest_module():
	# If no modules in range, nothing to prompt
	if modules_in_range.is_empty():
		# Hide leftover prompt from previous frame, if any
		if closest_module:
			closest_module.interaction_prompt.visible = false
			closest_module = null
		return  # Skip the rest of the logic

	# --- Otherwise, find the physically closest among modules_in_range
	var closest_dist = INF
	var new_closest = null

	for module in modules_in_range:
		if not module.visible:
			continue
		var dist = global_position.distance_to(module.global_position)
		if dist < closest_dist:
			closest_dist = dist
			new_closest = module

	if new_closest != closest_module:
		# If a new module is closer, hide the old one's prompt, show new one
		if closest_module:
			closest_module.interaction_prompt.visible = false
		closest_module = new_closest

	# Show the new closest module's prompt
	if closest_module:
		closest_module.interaction_prompt.visible = true


# Handles opening and closing interactable modules
func _process(_delta):
	update_closest_module()
	if Input.is_action_just_pressed("interact") and closest_module:
		if closest_module.ui_instance != null:
			closest_module.close()
		else:
			closest_module.open()
