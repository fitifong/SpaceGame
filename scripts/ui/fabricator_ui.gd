extends ItemContainerUI
class_name FabricatorUI

@export var make_button: Button
@export var recipe_selector: OptionButton
@export var input_slots: Array[Button] = []
@export var output_slot: Button

var module_ref: FabricatorModule = null  # Set by the module when UI is opened

func _ready():
	add_to_group("interactable_ui")
	slot_type_map = {3: "output"}
	super._ready()
	visible = true

	make_button.pressed.connect(_on_make_pressed)
	recipe_selector.item_selected.connect(_on_recipe_selected)

#func set_module_ref(module: FabricatorModule):
	#module_ref = module
	#update_recipe_list()

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
