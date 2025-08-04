# scripts/modules/storage_module.gd
extends StaticBody2D
class_name StorageModule

const InventoryComponent = preload("res://scripts/components/inventory_component.gd")
const UIHandlerComponent = preload("res://scripts/components/ui_handler_component.gd")
const InteractionComponent = preload("res://scripts/components/interaction_component.gd")

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)

@export var storage_ui_scene: PackedScene
@export var interaction_prompt: Control
@export var interaction_area: Area2D

var inventory: InventoryComponent
var ui_handler: UIHandlerComponent
var interaction: InteractionComponent

func _ready():
	add_to_group("interactable_modules")
	_create_components()
	_connect_signals()

func _create_components():
	inventory = InventoryComponent.new()
	inventory.name = "Inventory"
	add_child(inventory)
	inventory.initialize(25)
	
	ui_handler = UIHandlerComponent.new()
	ui_handler.name = "UIHandler"
	add_child(ui_handler)
	ui_handler.initialize(self, storage_ui_scene)
	
	interaction = InteractionComponent.new()
	interaction.name = "Interaction"
	add_child(interaction)
	interaction.initialize(self, interaction_area, interaction_prompt)

func _connect_signals():
	inventory.slot_updated.connect(slot_updated.emit)
	ui_handler.ui_opened.connect(module_opened.emit)
	ui_handler.ui_closed.connect(closed.emit)
	interaction.interaction_requested.connect(_on_interaction_requested)

func _on_interaction_requested():
	if ui_handler.is_open():
		ui_handler.close()
	else:
		ui_handler.open()

func open():
	ui_handler.open()

func close():
	ui_handler.close()

func is_ui_open() -> bool:
	return ui_handler.is_open()
