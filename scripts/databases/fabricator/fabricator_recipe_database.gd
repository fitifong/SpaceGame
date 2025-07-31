extends Node
class_name FabricatorRecipeDatabase

var recipes: Array[FabricatorRecipe] = []

func load_all_recipes():
	recipes.clear()
	print("Loading fabricator recipes...")
	
	var dir = DirAccess.open("res://resources/recipes/fabricator/fabricator_recipes/")
	if dir == null:
		print("ERROR: Cannot access fabricator recipes directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = "res://resources/recipes/fabricator/fabricator_recipes/" + file_name
			print("Loading recipe: ", path)
			var recipe = load(path)
			if recipe is FabricatorRecipe:
				recipes.append(recipe)
				print("✅ Loaded: ", recipe.output_item.name)
			else:
				print("❌ Invalid recipe file: ", path)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	print("Total fabricator recipes loaded: ", recipes.size())

func get_matching_recipes(input_items: Array[Dictionary]) -> Array[FabricatorRecipe]:
	var matches: Array[FabricatorRecipe] = []
	
	for recipe in recipes:
		if _recipe_matches_input(recipe, input_items):
			matches.append(recipe)
	
	return matches

func _recipe_matches_input(recipe: FabricatorRecipe, input_items: Array[Dictionary]) -> bool:
	# Check if recipe has ingredients
	if recipe.input_items.is_empty():
		print("Recipe ", recipe.output_item.name, " has no inputs - cannot craft")
		return false
	
	# Check each ingredient requirement
	for i in range(recipe.get_ingredient_count()):
		var required_item = recipe.get_ingredient_item(i)
		var required_quantity = recipe.get_ingredient_quantity(i)
		var matched := false
		
		# Look for this ingredient in current inputs
		for input in input_items:
			if input.has("id") and input.has("quantity"):
				if input["id"] == required_item and input["quantity"] >= required_quantity:
					matched = true
					break
		
		if not matched:
			print("Missing ingredient: ", required_item.name, " x", required_quantity)
			return false
	
	return true

func get_max_craftable(recipe: FabricatorRecipe, input_items: Array[Dictionary]) -> int:
	if recipe.input_items.is_empty():
		return 0
	
	var max_craftable = 999
	
	# Check each ingredient to find the limiting factor
	for i in range(recipe.get_ingredient_count()):
		var required_item = recipe.get_ingredient_item(i)
		var required_quantity = recipe.get_ingredient_quantity(i)
		var available_quantity = 0
		
		# Find how much of this ingredient we have
		for input in input_items:
			if input.has("id") and input["id"] == required_item:
				available_quantity = input["quantity"]
				break
		
		# Calculate how many times we can make this recipe with this ingredient
		var times_possible = available_quantity / required_quantity
		max_craftable = min(max_craftable, times_possible)
	
	return max(0, max_craftable)
