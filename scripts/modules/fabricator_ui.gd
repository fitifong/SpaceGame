extends ItemContainerUI
class_name FabricatorUI

@onready var make_button: Button = $NinePatchRect/MakeButton
@onready var recipe_selector: OptionButton = $NinePatchRect/RecipeSelector
@onready var input_slots: Array = [
	$NinePatchRect/GridContainer/InputSlot1,
	$NinePatchRect/GridContainer/InputSlot2,
	$NinePatchRect/GridContainer/InputSlot3,
]
@onready var output_slot: Button = $NinePatchRect/GridContainer/OutputSlot

func _ready():
	add_to_group("interactable_ui")
	slot_type_map = {3: "output"}
	super._ready()
	visible = true

	make_button.pressed.connect(_on_make_pressed)
	recipe_selector.item_selected.connect(_on_recipe_selected)

func _on_make_pressed():
	# Will trigger fabrication
	pass

func _on_recipe_selected(index: int):
	# Will preview the selected output
	pass

func set_inventory_ref(ref) -> void:
	inventory_data_ref = ref
	update_recipe_selector()

func update_recipe_selector():
	pass
