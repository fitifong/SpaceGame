extends TileMapLayer

@onready var player: CharacterBody2D = $"../Player"

#var original_tile_coords = {}
#
#var bridge_wall_trigger_tiles = [
	#Vector2i(-13,3),Vector2i(-12,3),Vector2i(-11,3),Vector2i(-10,3),Vector2i(-9,3),Vector2i(-8,3),
	#Vector2i(-7,4),Vector2i(-6,4),Vector2i(-5,4),Vector2i(-4,4),Vector2i(-3,4),Vector2i(-2,4),
	#Vector2i(-1,4),Vector2i(0,4),Vector2i(1,4),Vector2i(2,4),Vector2i(3,4),Vector2i(4,4),
	#Vector2i(5,4),Vector2i(6,4),Vector2i(7,2),Vector2i(8,2),Vector2i(9,2),Vector2i(10,2),
	#Vector2i(11,2),Vector2i(12,2),Vector2i(13,2),Vector2i(14,2),Vector2i(15,2)]
#
#func _ready() -> void:
	#for tile_pos in bridge_wall_trigger_tiles:
		#var atlas_coords = get_cell_atlas_coords(tile_pos)
		#original_tile_coords[tile_pos] = atlas_coords
#
#
#func _physics_process(_delta: float) -> void:
	#var player_tile_pos = local_to_map(player.position)
	#var atlas_coords = original_tile_coords.get(player_tile_pos)
	#
	#if player_tile_pos in bridge_wall_trigger_tiles:
		#var atlas_top = Vector2i(atlas_coords.x, atlas_coords.y + 3)
		#var atlas_middle = Vector2i(atlas_coords.x, atlas_coords.y + 4)
		#var atlas_bottom = Vector2i(atlas_coords.x, atlas_coords.y + 5)
		#
		#set_cell(Vector2i(player_tile_pos.x, player_tile_pos.y - 2), 0, atlas_top)
		#set_cell(Vector2i(player_tile_pos.x, player_tile_pos.y - 1), 0, atlas_middle)
		#set_cell(player_tile_pos, 0, atlas_bottom)
var player_near_walls = false
var atlas_y = null
var player_y = null

func _process(_delta):
	if player_near_walls == true:
		var player_x = local_to_map(player.position).x
		
		if atlas_y == null:
			atlas_y = get_cell_atlas_coords(local_to_map(player.position)).y
		var atlas_x = get_cell_atlas_coords(local_to_map(player.position)).x
		
		for i in 3:
			set_cell(Vector2i(player_x, player_y + i), 0, Vector2i(atlas_x, 12 + i), 0)
			print(Vector2i(player_x, player_y + i), Vector2i(atlas_x, 12 + i))

func _on_bottom_wall_section_body_entered(body: Node2D) -> void:
	if body == player:
		player_near_walls = true
		player_y = local_to_map(player.position).y
		
func _on_bottom_wall_section_body_exited(body: Node2D) -> void:
	if body == player:
		player_near_walls = false
