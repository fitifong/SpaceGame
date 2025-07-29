extends Node 

@export_dir var ITEMS_DIR := "res://resources/items"

var _items: Dictionary = {}   # id → ItemResource

func _ready() -> void:
	_load_item_resources()

# ------------------------ INTERNAL --------------------------
func _load_item_resources() -> void:
	_items.clear()

	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("[ItemDatabase] Cannot open items dir: %s" % ITEMS_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res_path := ITEMS_DIR.path_join(file_name)
			var res := load(res_path)
			if res is ItemResource:
				if res.id in _items:
					push_warning("[ItemDatabase] Duplicate ID %d in %s – skipping"
								 % [res.id, res_path])
				else:
					_items[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()

# -------------------- PUBLIC API (unchanged names) ----------------------------
func get_item_data(id: int) -> ItemResource:
	return _items.get(id, null)

func has_item(id: int) -> bool:
	return _items.has(id)

func get_item_name(id: int) -> String:
	var res: ItemResource = get_item_data(id)
	return res.name if res else ""

func get_item_texture(id: int) -> Texture2D:
	var res: ItemResource = get_item_data(id)
	return res.texture if res else null
