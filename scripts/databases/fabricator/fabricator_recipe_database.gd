extends Node
class_name FabricatorRecipeDatabase

var recipes: Array[FabricatorRecipe] = []

func load_all_recipes():
	recipes.clear()
	
	var dir = DirAccess.open("res://resources/recipes/fabricator/fabricator_recipes/")
	if dir == null:
		print("ERROR: Cannot access fabricator recipes directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = "res://resources/recipes/fabricator/fabricator_recipes/" + file_name
			var recipe = load(path)
			if recipe is FabricatorRecipe:
				recipes.append(recipe)
				print("✅ Loaded recipe: ", recipe.output_item.name)
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
	# Safety checks
	if not recipe or not recipe.output_item or not recipe.input_items:
		return false
	
	# Check if recipe has ingredients
	if recipe.input_items.is_empty():
		return false
	
	# Direct array access to avoid any potential recursion
	var ingredient_count = recipe.input_items.size()
	var quantity_count = recipe.input_quantities.size()
	
	# Make sure arrays match
	if ingredient_count != quantity_count:
		return false
	
	# Check each ingredient requirement using direct array access
	for i in range(ingredient_count):
		var required_item = recipe.input_items[i]
		var required_quantity = recipe.input_quantities[i]
		
		if not required_item or required_quantity <= 0:
			continue
		
		var matched := false
		
		# Look for this ingredient in current inputs
		for input in input_items:
			if input.has("id") and input.has("quantity"):
				if input["id"] == required_item and input["quantity"] >= required_quantity:
					matched = true
					break
		
		if not matched:
			return false
	
	return true

func get_max_craftable(recipe: FabricatorRecipe, input_items: Array[Dictionary]) -> int:
	# Safety checks
	if not recipe or not recipe.input_items or recipe.input_items.is_empty():
		return 0
	
	var max_craftable = 999
	var ingredient_count = recipe.input_items.size()
	var quantity_count = recipe.input_quantities.size()
	
	# Make sure arrays match
	if ingredient_count != quantity_count:
		return 0
	
	# Check each ingredient to find the limiting factor
	for i in range(ingredient_count):
		var required_item = recipe.input_items[i]
		var required_quantity = recipe.input_quantities[i]
		
		if not required_item or required_quantity <= 0:
			continue
		
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
