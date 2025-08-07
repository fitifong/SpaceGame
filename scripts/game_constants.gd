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
const SLOT_TYPE_FILTER = "filter"

# Mouse interaction constants
const MOUSE_MOVE_THRESHOLD = 1.0  # Minimum pixels before updating hover states
const DRAG_VISUAL_OFFSET = Vector2(32, 32)

# Default inventory sizes
const PLAYER_INVENTORY_SIZE = 9
const STORAGE_MODULE_SIZE = 25
const FABRICATOR_SLOTS = 4
const FURNACE_SLOTS = 2
const WATER_RECYCLER_SLOTS = 3  # Input, Filter, Output

# Water Recycler Constants
const WATER_RECYCLER_INPUT_SLOT = 0    # Dirty water input
const WATER_RECYCLER_FILTER_SLOT = 1   # Water filter (becomes used filter)
const WATER_RECYCLER_OUTPUT_SLOT = 2   # Clean water output

# Water Processing Settings
const WATER_PROCESSING_TIME = 3.0  # Seconds to process 1 dirty water
const FILTER_DURABILITY = 10  # Number of uses per filter
const WATER_RECYCLER_POWER_CONSUMPTION = 200.0  # PU/sec when processing
