extends Resource
class_name FabricatorRecipe

# Simple ingredient definition with item and quantity
@export var input_items: Array[ItemResource] = []
@export var input_quantities: Array[int] = []

@export var output_item: ItemResource
@export var output_quantity: int = 1
@export var fab_time: int = 10  # Seconds to fabricate

# Helper function to get ingredient info easily
func get_ingredient_count() -> int:
	return min(input_items.size(), input_quantities.size())

func get_ingredient_item(index: int) -> ItemResource:
	if index >= 0 and index < input_items.size():
		return input_items[index]
	return null

func get_ingredient_quantity(index: int) -> int:
	if index >= 0 and index < input_quantities.size():
		return input_quantities[index]
	return 0
