# scripts/modules/reactor_module.gd
extends ModularInventoryBase
class_name ReactorModule

# Reactor-specific exports
@export var reactor_ui_scene: PackedScene

# Reactor configuration
var generation_rate: float = 100.0  # PU/sec
var max_storage: float = 10000.0  # PU
var is_online: bool = true

func _get_default_inventory_size() -> int:
	"""Reactor doesn't need inventory slots for now"""
	return 0

func _get_ui_scene() -> PackedScene:
	"""Use reactor-specific UI scene if provided"""
	return reactor_ui_scene if reactor_ui_scene else ui_scene

func _post_setup():
	"""Reactor-specific initialization"""
	super._post_setup()
	
	# Initialize PowerManager with reactor settings
	if PowerManager:
		PowerManager.max_power_storage = max_storage
		PowerManager.current_power = max_storage  # Start full
		PowerManager.set_power_generation_rate(generation_rate)
	
	print("Reactor online: %d PU/sec generation, %d PU storage" % [generation_rate, max_storage])

func _on_interaction_requested():
	"""Handle reactor interaction - open power monitoring UI"""
	super._on_interaction_requested()

# ------------------------------------------------------------------
# REACTOR CONTROL METHODS
# ------------------------------------------------------------------

func set_online(online: bool):
	"""Turn reactor on/off"""
	is_online = online
	if PowerManager:
		PowerManager.set_power_generation_rate(generation_rate if online else 0.0)
	
	print("Reactor %s" % ("online" if online else "offline"))

func get_reactor_status() -> Dictionary:
	"""Get reactor status for UI display"""
	return {
		"is_online": is_online,
		"generation_rate": generation_rate,
		"max_storage": max_storage,
		"power_info": PowerManager.get_power_info() if PowerManager else {}
	}
