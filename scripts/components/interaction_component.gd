# scripts/components/interaction_component.gd
extends Node
class_name InteractionComponent

signal interaction_requested()
signal player_entered_range(player: Node)
signal player_exited_range(player: Node)

var parent_node: Node = null
var area_node: Area2D = null
var prompt_node: Control = null
var players_in_range: Array[Node] = []
var closest_player: Node = null

func initialize(parent: Node, area2d: Area2D, prompt: Control = null) -> bool:
	if not parent or not area2d:
		push_error("InteractionComponent: Invalid parent or area2d")
		return false
	
	parent_node = parent
	area_node = area2d
	prompt_node = prompt
	
	area_node.body_entered.connect(_on_body_entered)
	area_node.body_exited.connect(_on_body_exited)
	
	if prompt_node:
		prompt_node.visible = false
		if "z_index" in prompt_node:
			prompt_node.z_index = 999
	
	return true

func _on_body_entered(body: Node):
	if not (body.is_in_group("player") or body is Player):
		return
	
	players_in_range.append(body)
	
	if "modules_in_range" in body and parent_node:
		body.modules_in_range.append(parent_node)
	
	_update_closest_player()
	
	if body == closest_player and prompt_node:
		prompt_node.visible = true
	
	player_entered_range.emit(body)

func _on_body_exited(body: Node):
	if not (body.is_in_group("player") or body is Player):
		return
	
	players_in_range.erase(body)
	
	if "modules_in_range" in body and parent_node:
		body.modules_in_range.erase(parent_node)
	
	var was_closest = (body == closest_player)
	_update_closest_player()
	
	if was_closest and closest_player == null and prompt_node:
		prompt_node.visible = false
	elif closest_player != null and prompt_node:
		prompt_node.visible = true
	
	player_exited_range.emit(body)

func _update_closest_player():
	if players_in_range.is_empty():
		closest_player = null
		return
	
	if not parent_node:
		closest_player = players_in_range[0]
		return
	
	var closest_distance = INF
	var new_closest = null
	
	for player in players_in_range:
		if not is_instance_valid(player):
			continue
		
		var distance = parent_node.global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			new_closest = player
	
	closest_player = new_closest

func request_interaction():
	interaction_requested.emit()

func has_players_nearby() -> bool:
	return not players_in_range.is_empty()

func get_closest_player() -> Node:
	return closest_player

func _exit_tree():
	if area_node:
		if area_node.body_entered.is_connected(_on_body_entered):
			area_node.body_entered.disconnect(_on_body_entered)
		if area_node.body_exited.is_connected(_on_body_exited):
			area_node.body_exited.disconnect(_on_body_exited)
