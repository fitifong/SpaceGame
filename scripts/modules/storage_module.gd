# scripts/modules/storage_module.gd
extends ModularInventoryBase
class_name StorageModule

# Storage-specific configuration
@export var storage_ui_scene: PackedScene

func _get_default_inventory_size() -> int:
	"""Storage modules have 25 slots by default"""
	return GameConstants.STORAGE_MODULE_SIZE

func _get_ui_scene() -> PackedScene:
	"""Use storage-specific UI scene if provided, otherwise use default"""
	return storage_ui_scene if storage_ui_scene else ui_scene

func _post_setup():
	"""Storage-specific initialization after components are set up"""
	super._post_setup()
	# Storage modules don't need any special setup beyond the base class
	pass

func _on_ui_opened(ui_instance: Control):
	"""Handle storage UI opening"""
	super._on_ui_opened(ui_instance)
	# Storage modules can add specific UI setup here if needed
	pass

func _on_ui_closed():
	"""Handle storage UI closing"""
	super._on_ui_closed()
	# Storage modules can add specific cleanup here if needed
	pass

# Storage modules use the default interaction behavior (toggle UI)
# No need to override _on_interaction_requested()
