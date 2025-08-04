# scripts/components/ui_handler_component.gd
extends Node
class_name UIHandlerComponent

signal ui_opened(instance: Control)
signal ui_closed()

var ui_instance: Control = null
var parent_node: Node = null
var ui_scene: PackedScene = null

func initialize(parent: Node, scene: PackedScene) -> bool:
	if not parent or not scene:
		push_error("UIHandlerComponent: Invalid parent or scene")
		return false
	
	parent_node = parent
	ui_scene = scene
	return true

func open() -> bool:
	if ui_instance != null:
		return true
	
	if not ui_scene:
		push_error("UIHandlerComponent: No UI scene assigned")
		return false
	
	ui_instance = ui_scene.instantiate()
	if not ui_instance:
		push_error("UIHandlerComponent: Failed to instantiate UI scene")
		return false
	
	UIManager.add_ui(ui_instance)
	UIManager.register_ui(ui_instance)
	
	_setup_ui_instance()
	ui_opened.emit(ui_instance)
	return true

func close() -> bool:
	if not ui_instance:
		return true
	
	UIManager.unregister_ui(ui_instance)
	ui_instance.queue_free()
	ui_instance = null
	ui_closed.emit()
	return true

func is_open() -> bool:
	return ui_instance != null and is_instance_valid(ui_instance)

func get_ui_instance() -> Control:
	return ui_instance if is_open() else null

func _setup_ui_instance():
	if not ui_instance or not parent_node:
		return
	
	if ui_instance.has_method("set_module_ref"):
		ui_instance.set_module_ref(parent_node)
	elif "inventory_data_ref" in ui_instance:
		ui_instance.inventory_data_ref = parent_node

func _exit_tree():
	close()
