# scripts/singletons/power_manager.gd
extends Node

signal power_level_changed(current_power: float, max_power: float)
signal power_generation_changed(generation_rate: float)
signal total_consumption_changed(consumption: float)
signal power_critical(power_remaining: float)  # Emitted when power drops below 10%
signal power_restored()  # Emitted when power goes above 20% after being critical

# Power storage and generation
var max_power_storage: float = 10000.0  # PU
var current_power: float = 10000.0  # PU (start full)
var power_generation_rate: float = 100.0  # PU/sec

# Power consumption tracking
var total_consumption: float = 0.0  # PU/sec
var registered_components: Array[PowerComponent] = []
var pending_power_changes: Array[Dictionary] = []  # Queue for atomic updates

# Power state
var is_power_critical: bool = false
var last_update_time: float = 0.0

func _ready():
	set_process(true)
	last_update_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + Time.get_time_dict_from_system()["minute"] * 60.0 + Time.get_time_dict_from_system()["second"]
	
	# Set up timer for periodic console logging
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_log_power_status)
	timer.autostart = true
	add_child(timer)

func _process(delta: float):
	_process_pending_power_changes()  # Handle all power changes atomically first
	_update_power_levels(delta)
	_check_power_availability()
	_check_critical_power()

func _log_power_status():
	"""Log current power status to console every second"""
	print("Reactor Power: %.0f/%.0f PU (%.1f%%) | Generation: +%.0f PU/s | Consumption: -%.0f PU/s | Net: %.0f PU/s" % [
		current_power,
		max_power_storage,
		get_power_percentage(),
		power_generation_rate,
		total_consumption,
		get_net_power_flow()
	])

func _process_pending_power_changes():
	"""Process all pending power changes atomically to prevent race conditions"""
	if pending_power_changes.is_empty():
		return
	
	# Calculate total power change if all requests were approved
	var total_change: float = 0.0
	for change in pending_power_changes:
		var power_diff = change.new_consumption - change.old_consumption
		total_change += power_diff
	
	# Check if we can handle the total change
	var new_total_consumption = total_consumption + total_change
	var can_approve_all = (new_total_consumption <= 0.0 or current_power > 0.0)
	
	# Process each change
	for change in pending_power_changes:
		var component = change.component
		var power_diff = change.new_consumption - change.old_consumption
		
		if can_approve_all or power_diff <= 0.0:  # Always allow power decreases
			# Approve the change
			total_consumption += power_diff
			total_consumption = max(total_consumption, 0.0)
			if is_instance_valid(component):
				component._power_change_approved(change.new_consumption)
		else:
			# Deny the change
			if is_instance_valid(component):
				component._power_change_denied(change.old_consumption)
	
	# Clear processed changes
	pending_power_changes.clear()
	total_consumption_changed.emit(total_consumption)
func _update_power_levels(delta: float):
	"""Update power generation and consumption"""
	# Generate power
	var power_generated = power_generation_rate * delta
	current_power = min(current_power + power_generated, max_power_storage)
	
	# Consume power
	var power_consumed = total_consumption * delta
	current_power = max(current_power - power_consumed, 0.0)
	
	power_level_changed.emit(current_power, max_power_storage)

func _check_power_availability():
	"""Update all components about power availability"""
	for component in registered_components:
		if is_instance_valid(component):
			component._update_power_availability()

func _check_critical_power():
	"""Check for critical power levels"""
	var power_percentage = current_power / max_power_storage
	
	if not is_power_critical and power_percentage <= 0.1:
		is_power_critical = true
		power_critical.emit(current_power)
	elif is_power_critical and power_percentage >= 0.2:
		is_power_critical = false
		power_restored.emit()

# ------------------------------------------------------------------
# COMPONENT REGISTRATION
# ------------------------------------------------------------------

func register_power_component(component: PowerComponent):
	"""Register a power component for tracking"""
	if component and not registered_components.has(component):
		registered_components.append(component)
		_recalculate_total_consumption()

func unregister_power_component(component: PowerComponent):
	"""Unregister a power component"""
	if component and registered_components.has(component):
		registered_components.erase(component)
		_recalculate_total_consumption()

func _update_component_consumption(component: PowerComponent, old_consumption: float, new_consumption: float):
	"""Queue a power consumption change for atomic processing"""
	if not component or not registered_components.has(component):
		return
	
	pending_power_changes.append({
		"component": component,
		"old_consumption": old_consumption,
		"new_consumption": new_consumption
	})

func _recalculate_total_consumption():
	"""Recalculate total consumption from all registered components"""
	total_consumption = 0.0
	for component in registered_components:
		if is_instance_valid(component):
			total_consumption += component.get_current_power_draw()
	total_consumption_changed.emit(total_consumption)

# ------------------------------------------------------------------
# POWER QUERIES
# ------------------------------------------------------------------

func can_consume_power(power_amount: float) -> bool:
	"""Check if the specified power amount can be consumed sustainably"""
	# Check if we have enough power for at least 1 second of operation
	return current_power >= power_amount

func has_power_for_duration(power_per_second: float, duration_seconds: float = 1.0) -> bool:
	"""Check if there's enough power for a specific duration of operation"""
	var power_needed = power_per_second * duration_seconds
	return current_power >= power_needed

func get_power_percentage() -> float:
	"""Get current power as a percentage of max storage"""
	return (current_power / max_power_storage) * 100.0

func get_net_power_flow() -> float:
	"""Get net power flow (positive = charging, negative = draining)"""
	return power_generation_rate - total_consumption

func get_time_until_empty() -> float:
	"""Get estimated time until power runs out (in seconds). Returns -1 if charging."""
	var net_flow = get_net_power_flow()
	if net_flow >= 0:
		return -1.0  # Not draining
	return current_power / abs(net_flow)

func get_time_until_full() -> float:
	"""Get estimated time until power is full (in seconds). Returns -1 if draining."""
	var net_flow = get_net_power_flow()
	if net_flow <= 0:
		return -1.0  # Not charging
	var power_needed = max_power_storage - current_power
	return power_needed / net_flow

# ------------------------------------------------------------------
# REACTOR CONTROL
# ------------------------------------------------------------------

func set_power_generation_rate(rate: float):
	"""Set the power generation rate (called by reactor modules)"""
	power_generation_rate = max(rate, 0.0)
	power_generation_changed.emit(power_generation_rate)

func add_power_storage(amount: float):
	"""Add to max power storage (for upgrades)"""
	max_power_storage += amount
	current_power = min(current_power, max_power_storage)
	power_level_changed.emit(current_power, max_power_storage)

func add_power(amount: float):
	"""Directly add power (for emergency power cells, etc.)"""
	current_power = min(current_power + amount, max_power_storage)
	power_level_changed.emit(current_power, max_power_storage)

# ------------------------------------------------------------------
# DEBUG/UI HELPERS
# ------------------------------------------------------------------

func get_power_info() -> Dictionary:
	"""Get comprehensive power system information"""
	return {
		"current_power": current_power,
		"max_power": max_power_storage,
		"generation_rate": power_generation_rate,
		"total_consumption": total_consumption,
		"net_flow": get_net_power_flow(),
		"power_percentage": get_power_percentage(),
		"is_critical": is_power_critical,
		"time_until_empty": get_time_until_empty(),
		"time_until_full": get_time_until_full(),
		"component_count": registered_components.size()
	}

func get_component_power_breakdown() -> Array[Dictionary]:
	"""Get power consumption breakdown by component"""
	var breakdown: Array[Dictionary] = []
	for component in registered_components:
		if is_instance_valid(component):
			var info = component.get_power_info()
			info["component_name"] = component.parent_node.name if component.parent_node else "Unknown"
			breakdown.append(info)
	return breakdown
