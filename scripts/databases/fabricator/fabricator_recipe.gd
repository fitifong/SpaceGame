extends Resource
class_name FabricatorRecipe

@export var inputs: Array[FabricatorIngredient]
@export var output_item: ItemResource
@export var output_quantity: int = 1
@export var fab_time: int = 10  # Seconds to fabricate
