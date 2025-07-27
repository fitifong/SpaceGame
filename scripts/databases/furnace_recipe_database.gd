extends Node
class_name FurnaceRecipeDatabase

var recipes: Array[FurnaceRecipe] = []

# Called when the FurnaceModule opens the UI
func load_all_recipes():
	recipes.clear()
	var dir = DirAccess.open("res://resources/recipes/furnace_recipes/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var path = "res://resources/recipes/furnace_recipes/" + file_name
				var recipe = load(path)
				if recipe is FurnaceRecipe:
					recipes.append(recipe)
			file_name = dir.get_next()
		dir.list_dir_end()
