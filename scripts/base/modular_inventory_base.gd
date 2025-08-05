# scripts/base/modular_inventory_base.gd
extends StaticBody2D
class_name ModularInventoryBase

# Component references
@onready var inventory: InventoryComponent = InventoryComponent.new()
@onready var ui_handler: UIHandlerComponent = UIHandlerComponent.new()
@onready var interaction: InteractionComponent = InteractionComponent.new()

# Configuration exports
@export var default_inventory_size: int = 10
@export var ui_scene: PackedScene
@export var interaction_area: Area2D
@export var interaction_prompt: Control

# Signals that modules can emit
signal module_opened(ui_instance)
signal closed
signal slot_updated(index)

func _ready():
	add_to_group("interactable_modules")
	_create_components()
	_connect_signals()
	_post_setup()

# ------------------------------------------------------------------
# COMPONENT SETUP
# ------------------------------------------------------------------

func _create_components():
	"""Initialize all components with proper configuration"""
	# Set up inventory component
	inventory.name = "Inventory"
	add_child(inventory)
	var size = _get_default_inventory_size()
	if not inventory.initialize(size):
		push_error("Failed to initialize inventory component in %s" % name)
		return
	
	# Set up UI handler component
	ui_handler.name = "UIHandler"
	add_child(ui_handler)
	var scene = _get_ui_scene()
	if scene and not ui_handler.initialize(self, scene):
		push_error("Failed to initialize UI handler component in %s" % name)
		return
	
	# Set up interaction component
	interaction.name = "Interaction"
	add_child(interaction)
	var area = _get_interaction_area()
	var prompt = _get_interaction_prompt()
	if area and not interaction.initialize(self, area, prompt):
		push_error("Failed to initialize interaction component in %s" % name)
		return

func _connect_signals():
	"""Wire component signals to virtual methods"""
	# Inventory signals
	if inventory.slot_updated.is_connected(slot_updated.emit):
		inventory.slot_updated.disconnect(slot_updated.emit)
	inventory.slot_updated.connect(slot_updated.emit)
	inventory.slot_updated.connect(_on_slot_updated)
	inventory.inventory_changed.connect(_on_inventory_changed)
	
	# UI handler signals
	if ui_handler.ui_opened.is_connected(module_opened.emit):
		ui_handler.ui_opened.disconnect(module_opened.emit)
	ui_handler.ui_opened.connect(module_opened.emit)
	ui_handler.ui_opened.connect(_on_ui_opened)
	ui_handler.ui_closed.connect(closed.emit)
	ui_handler.ui_closed.connect(_on_ui_closed)
	
	# Interaction signals
	interaction.interaction_requested.connect(_on_interaction_requested)
	interaction.player_entered_range.connect(_on_player_entered_range)
	interaction.player_exited_range.connect(_on_player_exited_range)

# ------------------------------------------------------------------
# CONFIGURATION GETTERS (Override in subclasses)
# ------------------------------------------------------------------

func _get_default_inventory_size() -> int:
	"""Override to provide custom inventory size"""
	return default_inventory_size

func _get_ui_scene() -> PackedScene:
	"""Override to provide custom UI scene"""
	return ui_scene

func _get_interaction_area() -> Area2D:
	"""Override to provide custom interaction area"""
	return interaction_area

func _get_interaction_prompt() -> Control:
	"""Override to provide custom interaction prompt"""
	return interaction_prompt

# ------------------------------------------------------------------
# VIRTUAL METHODS (Override in subclasses)
# ------------------------------------------------------------------

func _post_setup():
	"""Called after all components are set up. Override for custom initialization."""
	pass

func _on_ui_opened(_ui_instance: Control):
	"""Called when UI opens. Override for custom behavior."""
	pass

func _on_ui_closed():
	"""Called when UI closes. Override for custom behavior."""
	pass

func _on_interaction_requested():
	"""Called when player requests interaction. Override for custom behavior."""
	_default_interaction()

func _on_slot_updated(_index: int):
	"""Called when inventory slot is updated. Override for custom behavior."""
	pass

func _on_inventory_changed():
	"""Called when entire inventory changes. Override for custom behavior."""
	pass

func _on_player_entered_range(_player: Node):
	"""Called when player enters interaction range. Override for custom behavior."""
	pass

func _on_player_exited_range(_player: Node):
	"""Called when player exits interaction range. Override for custom behavior."""
	pass

# ------------------------------------------------------------------
# DEFAULT BEHAVIORS
# ------------------------------------------------------------------

func _default_interaction():
	"""Default interaction behavior - toggle UI"""
	if ui_handler.is_open():
		ui_handler.close()
	else:
		ui_handler.open()

# ------------------------------------------------------------------
# PUBLIC API (for external use)
# ------------------------------------------------------------------

func open():
	"""Open the module's UI"""
	ui_handler.open()

func close():
	"""Close the module's UI"""
	ui_handler.close()

func is_ui_open() -> bool:
	"""Check if UI is currently open"""
	return ui_handler.is_open()

func get_ui_instance() -> Control:
	"""Get the current UI instance"""
	return ui_handler.get_ui_instance()

func has_players_nearby() -> bool:
	"""Check if any players are in interaction range"""
	return interaction.has_players_nearby()

func get_closest_player() -> Node:
	"""Get the closest player in range"""
	return interaction.get_closest_player()

# ------------------------------------------------------------------
# INVENTORY CONVENIENCE METHODS
# ------------------------------------------------------------------

func get_item(index: int) -> Dictionary:
	"""Get item from inventory slot"""
	return inventory.get_item(index)

func add_item(index: int, item: Dictionary) -> bool:
	"""Add item to inventory slot"""
	return inventory.add_item(index, item)

func remove_item(index: int) -> Dictionary:
	"""Remove item from inventory slot"""
	return inventory.remove_item(index)

func is_slot_empty(index: int) -> bool:
	"""Check if inventory slot is empty"""
	return inventory.is_slot_empty(index)

func auto_stack_item(item: Dictionary) -> int:
	"""Automatically stack item in best available slot, returns leftover"""
	return inventory.auto_stack_item(item)

func clear_inventory():
	"""Clear all inventory slots"""
	inventory.clear_inventory()

# ------------------------------------------------------------------
# PROCESS METHOD
# ------------------------------------------------------------------

func _process(_delta: float):
	"""Base process method that modules can override"""
	# Base class doesn't need to do anything in _process
	# But having this method allows modules to call super._process(delta)
	pass

# ------------------------------------------------------------------
# VALIDATION & ERROR HANDLING
# ------------------------------------------------------------------

func _validate_setup() -> bool:
	"""Validate that all required components are properly set up"""
	if not inventory:
		push_error("ModularInventoryBase: Missing inventory component")
		return false
	
	if not ui_handler:
		push_error("ModularInventoryBase: Missing ui_handler component")
		return false
	
	if not interaction:
		push_error("ModularInventoryBase: Missing interaction component")
		return false
	
	return true

func _exit_tree():
	"""Clean up when node is removed from tree"""
	if interaction:
		interaction._exit_tree()
	if ui_handler:
		ui_handler._exit_tree()
