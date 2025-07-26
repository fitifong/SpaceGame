extends Node

# Maps input item ID → output item ID
var recipes := {
	2: { "output_id": 4, "smelt_time": 10.0 },  # iron ore, iron bar
	5: { "output_id": 6, "smelt_time": 6.0 },  # copper ore, copper bar
}

func get_recipe(input_id: int) -> Dictionary:
	return recipes.get(input_id, {})
