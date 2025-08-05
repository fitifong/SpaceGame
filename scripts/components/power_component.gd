# scripts/components/power_component.gd
extends Node
class_name PowerComponent

signal power_efficiency_changed(efficiency: float)
signal power_consumption_changed(consumption: float)

# Power configuration
var idle_power_draw: float = 0.0  # PU/sec when idle
var active_power_draw: float = 0.0  # PU/sec when active
var has_efficiency_control: bool = false  # Can adjust power/time tradeoff
var auto_operation: bool = true  # Auto vs manual operation mode

# Current state
var is_active: bool = false
var power_efficiency: float = 1.0  # 0.5 to 1.5 (50% to 150%)
var current_consumption: float = 0.0
var requested_consumption: float = 0.0  # What we asked for
var parent_node: Node = null

# Power availability tracking
var has_sufficient_power: bool = true
var last_power_check: float = 0.0

func initialize(parent: Node, idle_draw: float = 0.0, active_draw: float = 0.0, efficiency_control: bool = false) -> bool:
	if not parent:
		push_error("PowerComponent: Invalid parent node")
		return false
	
	parent_node = parent
	idle_power_draw = idle_draw
	active_power_draw = active_draw
	has_efficiency_control = efficiency_control
	
	# Start consuming idle power immediately
	_update_power_consumption()
	
	return true

func set_active(active: bool):
	"""Set the active state of this component"""
	if is_active != active:
		is_active = active
		_update_power_consumption()

func set_power_efficiency(efficiency: float):
	"""Set power efficiency (0.5 to 1.5). Only works if has_efficiency_control is true."""
	if not has_efficiency_control:
		return
	
	power_efficiency = clamp(efficiency, 0.5, 1.5)
	_update_power_consumption()
	power_efficiency_changed.emit(power_efficiency)

func set_auto_operation(auto: bool):
	"""Set whether this component operates automatically or manually"""
	auto_operation = auto

func get_current_power_draw() -> float:
	"""Get the current power consumption in PU/sec"""
	return current_consumption

func get_efficiency_multiplier() -> float:
	"""Get the time multiplier based on current efficiency (for speed calculations)"""
	return power_efficiency

func get_power_multiplier() -> float:
	"""Get the power multiplier based on current efficiency"""
	if not has_efficiency_control:
		return 1.0
	
	# Quadratic scaling: 150% speed = 225% power, 50% speed = 25% power
	return power_efficiency * power_efficiency

func has_power() -> bool:
	"""Check if there's sufficient power for current operation"""
	return has_sufficient_power

func can_operate() -> bool:
	"""Check if this component can operate (has power and is set to operate)"""
	if not has_power():
		return false
	
	if auto_operation:
		return true
	
	# For manual operation, parent should call this when player initiates action
	return true

func _update_power_consumption():
	"""Update current power consumption and notify PowerManager"""
	var old_consumption = current_consumption
	var new_consumption: float
	
	if is_active:
		var base_consumption = active_power_draw
		var power_multiplier = get_power_multiplier()
		new_consumption = base_consumption * power_multiplier
	else:
		new_consumption = idle_power_draw
	
	requested_consumption = new_consumption
	
	# Queue the power change with PowerManager (will be processed atomically)
	if PowerManager:
		PowerManager._update_component_consumption(self, old_consumption, new_consumption)

func _power_change_approved(approved_consumption: float):
	"""Called by PowerManager when power change is approved"""
	current_consumption = approved_consumption
	has_sufficient_power = true
	power_consumption_changed.emit(current_consumption)
	
	# Notify parent if power status changed
	if parent_node and parent_node.has_method("_on_power_availability_changed"):
		parent_node._on_power_availability_changed(true)

func _power_change_denied(current_consumption_stays: float):
	"""Called by PowerManager when power change is denied"""
	current_consumption = current_consumption_stays
	has_sufficient_power = false
	
	# If we were trying to become active but got denied, force back to inactive
	if is_active and requested_consumption > current_consumption:
		is_active = false
		print("Power request denied - component forced inactive")
	
	# Notify parent of power shortage
	if parent_node and parent_node.has_method("_on_power_availability_changed"):
		parent_node._on_power_availability_changed(false)

func _update_power_availability():
	"""Called by PowerManager to update power availability status"""
	var old_status = has_sufficient_power
	has_sufficient_power = PowerManager.can_consume_power(current_consumption)
	
	# If power status changed, notify parent
	if old_status != has_sufficient_power and parent_node:
		if parent_node.has_method("_on_power_availability_changed"):
			parent_node._on_power_availability_changed(has_sufficient_power)

func get_power_info() -> Dictionary:
	"""Get detailed power information for UI display"""
	return {
		"current_draw": current_consumption,
		"idle_draw": idle_power_draw,
		"active_draw": active_power_draw,
		"efficiency": power_efficiency,
		"has_efficiency_control": has_efficiency_control,
		"is_active": is_active,
		"has_power": has_sufficient_power,
		"auto_operation": auto_operation
	}

func _exit_tree():
	"""Clean up when component is removed"""
	if PowerManager:
		PowerManager._update_component_consumption(self, current_consumption, 0.0)
