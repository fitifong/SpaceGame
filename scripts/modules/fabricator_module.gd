extends StaticBody2D
class_name FabricatorModule

signal module_opened(ui_instance)
signal closed
signal slot_updated(index)

@export var fabricator_ui_scene : PackedScene
@export var interaction_prompt  : Control
@export var interaction_area    : Area2D
@export var fabricator_sprite   : AnimatedSprite2D   # has "door" + "static_open" + "static_closed"

var inventory      : Array = []
var inventory_size := 0
var ui_instance    : FabricatorUI = null
var is_processing  := false

var anim_busy := false   # true while the door animation is running

# -------------------------------------------------- READY
func _ready():
	add_to_group("interactable_modules")
	interaction_prompt.visible = false
	interaction_prompt.z_index = 999
	fabricator_sprite.play("static_open")           # starts open
	set_inventory_size(4)

func set_inventory_size(size: int) -> void:
	inventory_size = size
	inventory.resize(size)

# -------------------------------------------------- INTERACTION
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.append(self)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		body.modules_in_range.erase(self)
		if ui_instance:
			close()

func interact():
	if is_processing or anim_busy:
		return
	if ui_instance:
		close()
	else:
		open()

# -------------------- OPEN --------------------
func open():
	if ui_instance or is_processing or anim_busy or fabricator_ui_scene == null:
		return

	interaction_prompt.visible = false
	anim_busy = true

	var cb = Callable(self, "_on_door_closed")
	if not fabricator_sprite.is_connected("animation_finished", cb):
		fabricator_sprite.connect("animation_finished", cb)

	fabricator_sprite.play("door")  # forward = door closes

func _on_door_closed() -> void:
	fabricator_sprite.disconnect("animation_finished", Callable(self, "_on_door_closed"))

	# Instantiate & wire the UI
	ui_instance = fabricator_ui_scene.instantiate() as FabricatorUI
	
	# --- GUARDED PLAYER INVENTORY INJECTION ---
	var inv_ui = UIManager.get_inventory_ui()
	if inv_ui:
		ui_instance.player_inventory_ui = inv_ui
	else:
		push_warning("[FabricatorModule] No PlayerInventoryUI found; UI will be non‑functional")

	ui_instance.inventory_data_ref = self
	UIManager.add_ui(ui_instance)
	UIManager.register_ui(ui_instance)
	emit_signal("module_opened", ui_instance)

	# Reverse‑play door to open
	var open_cb = Callable(self, "_on_door_opened")
	if not fabricator_sprite.is_connected("animation_finished", open_cb):
		fabricator_sprite.connect("animation_finished", open_cb)
	fabricator_sprite.play("door", -1.0, true)
	fabricator_sprite.play("static_closed")
	anim_busy = false

# -------------------- CLOSE --------------------
func close():
	if ui_instance == null or anim_busy:
		return

	# tear down UI
	UIManager.unregister_ui(ui_instance)
	ui_instance.queue_free()
	ui_instance = null
	emit_signal("closed")

	anim_busy = true

	var cb = Callable(self, "_on_door_opened")
	if not fabricator_sprite.is_connected("animation_finished", cb):
		fabricator_sprite.connect("animation_finished", cb)

	fabricator_sprite.play("door", -1.0, true)  # reverse = door opens

func _on_door_opened() -> void:
	fabricator_sprite.disconnect("animation_finished", Callable(self, "_on_door_opened"))
	fabricator_sprite.play("static_open")
	interaction_prompt.visible = true
	anim_busy = false

# -------------------- (TO BE IMPLEMENTED) --------------------
func start_fabrication():
	is_processing = true

	# Step 5.2+ will control this with recipe logic
	fabricator_sprite.play("door")  # door closes
	await fabricator_sprite.animation_finished

	fabricator_sprite.play("process")  # fabrication in progress
	# NOTE: We'll manage timing + post-animation logic in 5.2/5.3
