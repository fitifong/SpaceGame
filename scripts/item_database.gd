extends Node

var items = {
	1: {
		"name": "Screw",
		"texture": preload("res://assets/items/screw.aseprite"),
		"type": "component",
		"default_quantity": 1
	},
	2: {
		"name": "Iron Ore",
		"texture": preload("res://assets/items/iron_ore.aseprite"),
		"type": "raw_material",
		"default_quantity": 1
	},
	3: {
		"name": "Metal Sheet",
		"texture": preload("res://assets/items/metal_sheet.aseprite"),
		"type": "component",
		"default_quantity": 1
	},
	4: {
		"name": "Iron Bar",
		"texture": preload("res://assets/items/iron_bar.aseprite"),
		"type": "material",
		"default_quantity": 1
	}
}

func get_item_data(item_id):
	return items.get(item_id, null)
