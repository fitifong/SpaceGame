extends Node
class_name FabricatorRecipeDatabase

@export var recipes: Array[FabricatorRecipe] = []

# Tries to match any valid recipes for the current input contents
func get_matching_recipes(input_items: Array[Dictionary]) -> Array[FabricatorRecipe]:
	var matches := []

	for recipe in recipes:
		if _recipe_matches_input(recipe, input_items):
			matches.append(recipe)

	return matches

# Expects each input to be: { "item": ItemResource, "quantity": int }
func _recipe_matches_input(recipe: FabricatorRecipe, input_items: Array[Dictionary]) -> bool:
	for ingredient in recipe.inputs:
		var matched := false

		for input in input_items:
			if input.has("item") and input.has("quantity"):
				if input["item"] == ingredient.item and input["quantity"] >= ingredient.quantity:
					matched = true
					break

		if not matched:
			return false

	return true
