extends Resource
class_name ItemResource

# --------------------------------------------------------------------
# 📦  Data fields
# --------------------------------------------------------------------
@export var id: int          # Unique numeric ID (must stay unique)
@export var name: String       # “Iron Ore”, “Metal Sheet”, …
@export var texture: Texture2D    # Sprite used in UI / world
@export var item_type: String       # “raw_material”, “component”, …
@export var quantity: int  = 1     # Stack size the item spawns with
