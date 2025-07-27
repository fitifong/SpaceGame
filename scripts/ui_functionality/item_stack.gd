class_name ItemStack

## Represents a stack of items in the inventory.

## Item ID (must match the one in ItemDatabase).
var id: int

## Quantity of items in this stack.
var quantity: int

## Optional: Max stack size (you can use a global constant instead).
const MAX_STACK_SIZE: int = 99

func _init(id: int = -1, quantity: int = 0) -> void:
	self.id = id
	self.quantity = quantity

func is_empty() -> bool:
	return quantity <= 0 or id == -1

func can_merge_with(other: ItemStack) -> bool:
	return other != null and id == other.id

func merge_with(other: ItemStack) -> int:
	if not can_merge_with(other):
		return other.quantity  # Can't merge, return all of it as remainder

	var space_left = MAX_STACK_SIZE - quantity
	var to_merge = min(space_left, other.quantity)
	quantity += to_merge
	other.quantity -= to_merge
	return other.quantity  # Returns remainder (could be 0)
