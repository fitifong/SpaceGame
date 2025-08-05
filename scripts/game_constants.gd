# scripts/game_constants.gd
# STATIC VERSION - No longer a singleton
class_name GameConstants

# Inventory and Stack Constants
const MAX_STACK_SIZE = 99
const DEFAULT_STACK_SIZE = 1

# UI Slot Constants
const OUTPUT_SLOT_INDEX = 3  # Default output slot for most modules
const INPUT_SLOT_START = 0   # Where input slots typically start

# Animation Constants
const FABRICATION_COMPLETE_FRAME = 9
const FURNACE_PROGRESS_FRAMES = 11  # 0-10 for progress bar

# Module States
enum ModuleState {
	IDLE,
	PROCESSING,
	COMPLETE,
	ERROR
}

# Slot Types (keeping as strings for compatibility)
const SLOT_TYPE_INPUT = "input"
const SLOT_TYPE_OUTPUT = "output"
const SLOT_TYPE_FUEL = "fuel"
const SLOT_TYPE_CATALYST = "catalyst"

# Mouse interaction constants
const MOUSE_MOVE_THRESHOLD = 1.0  # Minimum pixels before updating hover states
const DRAG_VISUAL_OFFSET = Vector2(32, 32)

# Default inventory sizes
const PLAYER_INVENTORY_SIZE = 9
const STORAGE_MODULE_SIZE = 25
const FABRICATOR_SLOTS = 4
const FURNACE_SLOTS = 2
