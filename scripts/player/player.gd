# scripts/player/player.gd
extends CharacterBody2D
class_name Player

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var pickup_ui = $PickupUI
@onready var interaction_area: Area2D = $InteractionArea

const MOVE_SPEED = 125.0
var facing_direction = "down"
var closest_module: Node = null
var modules_in_range: Array = []

func _ready():
	PlayerInventory.set_player_reference(self)

func get_input() -> Vector2:
	var input_vector = Vector2()
	var horizontal_pressed = false
	var vertical_pressed = false

	if Input.is_action_pressed("move_right"):
		input_vector.x = 1
		horizontal_pressed = true
	elif Input.is_action_pressed("move_left"):
		input_vector.x = -1
		horizontal_pressed = true

	if Input.is_action_pressed("move_down"):
		input_vector.y = 1
		vertical_pressed = true
	elif Input.is_action_pressed("move_up"):
		input_vector.y = -1
		vertical_pressed = true

	if horizontal_pressed:
		facing_direction = "right" if input_vector.x > 0 else "left"
	elif vertical_pressed:
		facing_direction = "down" if input_vector.y > 0 else "up"

	if input_vector.length() > 1:
		input_vector = input_vector.normalized()

	return input_vector

func _physics_process(_delta):
	var direction = get_input()
	
	if direction != Vector2.ZERO and closest_module and _is_module_ui_open(closest_module):
		_close_module_ui(closest_module)
	
	if direction == Vector2.ZERO:
		animation_player.play("idle_" + facing_direction)
	else:
		match facing_direction:
			"left": animation_player.play("walk_left")
			"right": animation_player.play("walk_right")
			"up": animation_player.play("walk_up")
			"down": animation_player.play("walk_down")
		
	velocity = direction * MOVE_SPEED
	move_and_slide()

func update_closest_module():
	if modules_in_range.is_empty():
		if closest_module:
			_hide_module_prompt(closest_module)
			closest_module = null
		return

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
		if closest_module:
			_hide_module_prompt(closest_module)
		closest_module = new_closest

	if closest_module:
		_show_module_prompt(closest_module)

func _process(_delta):
	update_closest_module()
	if Input.is_action_just_pressed("interact") and closest_module:
		_interact_with_module(closest_module)

func _is_module_ui_open(module: Node) -> bool:
	return module.is_ui_open() if module.has_method("is_ui_open") else false

func _close_module_ui(module: Node):
	if module.has_method("close"):
		module.close()

func _show_module_prompt(module: Node):
	var interaction_component = module.get_node_or_null("Interaction")
	if interaction_component and "prompt_node" in interaction_component and interaction_component.prompt_node:
		interaction_component.prompt_node.visible = true

func _hide_module_prompt(module: Node):
	var interaction_component = module.get_node_or_null("Interaction")
	if interaction_component and "prompt_node" in interaction_component and interaction_component.prompt_node:
		interaction_component.prompt_node.visible = false

func _interact_with_module(module: Node):
	var interaction_component = module.get_node_or_null("Interaction")
	if interaction_component and interaction_component.has_method("request_interaction"):
		interaction_component.request_interaction()
	elif module.has_method("open") and module.has_method("close"):
		if _is_module_ui_open(module):
			module.close()
		else:
			module.open()
