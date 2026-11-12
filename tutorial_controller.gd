# tutorial_controller.gd
class_name TutorialController
extends Node3D

signal step_started(step_index: int, title: String)
signal step_completed(step_index: int)
signal tutorial_finished()

enum Step {
	MOVEMENT = 0,
	PICKUP = 1,
	POTION = 2,
	COMBAT = 3,
	COMPLETED = 4
}

@export_group("Positioning")
@export var marker_position: Vector3 = Vector3(0.0, 0.26, -4.5)
@export var marker_radius: float = 1.4
@export var marker_color: Color = UIPalette.EMERALD
@export var drop_position: Vector3 = Vector3(0.0, 0.4, -6.5)
@export var auto_start: bool = true

const PANEL_TEMPLATE: StyleBox = preload("res://resources/ui/panel_box.tres")

var current_step: Step = Step.MOVEMENT
var is_transitioning: bool = false
var _elapsed_time: float = 0.0

# 3D Visual Elements
var marker_area: Area3D = null
var marker_ring: MeshInstance3D = null
var marker_disc: MeshInstance3D = null
var marker_mat_ring: StandardMaterial3D = null
var marker_mat_disc: StandardMaterial3D = null

var tutorial_drop_node: Node3D = null
var combat_dummy_ref: Node3D = null

# Minimalist HUD Elements (Menggunakan Palet Eksak Meja Alkimia / CraftingPanel)
var ui_canvas: CanvasLayer = null
var ui_container: PanelContainer = null
var ui_panel_style: StyleBoxFlat = null
var ui_task: Label = null

func _ready() -> void:
	_setup_ui()
	_connect_global_signals()
	if auto_start:
		start_step(Step.MOVEMENT)

func _connect_global_signals() -> void:
	if not GlobalLogic.inventory_updated.is_connected(_on_inventory_updated):
		GlobalLogic.inventory_updated.connect(_on_inventory_updated)
	if not GlobalLogic.potion_consumed.is_connected(_on_potion_consumed):
		GlobalLogic.potion_consumed.connect(_on_potion_consumed)

func _process(delta: float) -> void:
	_elapsed_time += delta
	_update_marker_visuals(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_step == Step.PICKUP and not is_transitioning:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
			_check_manual_pickup()

func start_step(step: Step) -> void:
	current_step = step
	is_transitioning = false
	GlobalLogic.set_tutorial_step(int(step))
	_clear_3d_markers()

	match step:
		Step.MOVEMENT:
			_start_movement_step()
		Step.PICKUP:
			_start_pickup_step()
		Step.POTION:
			_start_potion_step()
		Step.COMBAT:
			_start_combat_step()
		Step.COMPLETED:
			_start_completed_step()

# ==============================================================================
# STEP 1: GERAKAN
# ==============================================================================
func _start_movement_step() -> void:
	_set_task("Berjalan ke lingkaran target (W, A, S, D)")
	_spawn_ground_marker()
	step_started.emit(Step.MOVEMENT, "Berjalan ke lingkaran target (W, A, S, D)")

func _spawn_ground_marker() -> void:
	marker_area = Area3D.new()
	marker_area.name = "TutorialMarker"
	marker_area.position = marker_position
	add_child(marker_area)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = marker_radius
	cyl.height = 1.0
	col.shape = cyl
	col.position.y = 0.5
	marker_area.add_child(col)

	# Ring luar
	marker_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = marker_radius - 0.12
	torus.outer_radius = marker_radius
	torus.rings = 24
	torus.ring_segments = 12
	marker_ring.mesh = torus

	marker_mat_ring = StandardMaterial3D.new()
	marker_mat_ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat_ring.albedo_color = marker_color
	marker_mat_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_ring.material_override = marker_mat_ring
	marker_ring.position.y = 0.04
	marker_area.add_child(marker_ring)

	# Pendaran alas dalam
	marker_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = marker_radius - 0.15
	disc.bottom_radius = marker_radius - 0.15
	disc.height = 0.01
	marker_disc.mesh = disc

	marker_mat_disc = StandardMaterial3D.new()
	marker_mat_disc.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.18)
	marker_mat_disc.emission_enabled = true
	marker_mat_disc.emission = Color(marker_color.r, marker_color.g, marker_color.b)
	marker_mat_disc.emission_energy_multiplier = 0.6
	marker_mat_disc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_disc.material_override = marker_mat_disc
	marker_disc.position.y = 0.02
	marker_area.add_child(marker_disc)

	marker_area.body_entered.connect(_on_marker_body_entered)

func _on_marker_body_entered(body: Node3D) -> void:
	if is_transitioning:
		return
	if body.name == "Players" or body is CharacterBody3D:
		is_transitioning = true
		_play_chime()

		if marker_area and is_instance_valid(marker_area):
			var tw := create_tween()
			tw.tween_property(marker_area, "scale", Vector3(1.25, 0.2, 1.25), 0.2).set_trans(Tween.TRANS_SINE)
			if marker_mat_ring:
				tw.parallel().tween_property(marker_mat_ring, "albedo_color:a", 0.0, 0.2)
			tw.chain().tween_callback(marker_area.queue_free)

		_show_step_done("✓ Lingkaran target tercapai")
		step_completed.emit(Step.MOVEMENT)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.PICKUP)

func _update_marker_visuals(delta: float) -> void:
	if marker_ring and is_instance_valid(marker_ring) and not is_transitioning:
		marker_ring.rotate_y(delta * 0.7)
		if marker_mat_ring:
			var pulse := (sin(_elapsed_time * 3.5) + 1.0) * 0.5
			marker_mat_ring.albedo_color.a = lerpf(0.55, 0.9, pulse)

# ==============================================================================
# STEP 2: AMBIL BAHAN
# ==============================================================================
func _start_pickup_step() -> void:
	_set_task("Ambil Slime Gel di depan (E)")
	_spawn_slime_drop()
	step_started.emit(Step.PICKUP, "Ambil Slime Gel di depan (E)")

func _spawn_slime_drop() -> void:
	var item_script = load("res://item_drop.gd")
	if not item_script:
		return

	var drop = item_script.new()
	drop.name = "TutorialSlimeDrop"
	drop.item_type = "slime_gel"
	drop.item_amount = 1
	drop.item_color = Color(0.2, 0.9, 0.5, 0.95)
	drop.pop_force_y = 0.5
	drop.pop_spread_xz = 0.0
	drop.magnet_radius = 3.0
	drop.pickup_distance = 1.3

	var parent_scene: Node = get_parent()
	if not parent_scene:
		parent_scene = self
	parent_scene.add_child(drop)
	drop.global_position = drop_position
	tutorial_drop_node = drop

func _check_manual_pickup() -> void:
	var player: Node3D = _get_player()
	if not player or not tutorial_drop_node or not is_instance_valid(tutorial_drop_node):
		return

	if player.global_position.distance_to(tutorial_drop_node.global_position) <= 3.5:
		if tutorial_drop_node.has_method("_collect"):
			tutorial_drop_node.call("_collect")
		else:
			GlobalLogic.add_material("slime_gel", 1)
			tutorial_drop_node.queue_free()

func _on_inventory_updated() -> void:
	if current_step == Step.PICKUP and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Slime Gel tersimpan di inventori")
		step_completed.emit(Step.PICKUP)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.POTION)

# ==============================================================================
# STEP 3: MINUM RAMUAN & TOXICITY
# ==============================================================================
func _start_potion_step() -> void:
	if GlobalLogic.potions.get("healing", 0) <= 0:
		GlobalLogic.potions["healing"] = 1
		GlobalLogic.inventory_updated.emit()

	if GlobalLogic.current_hp >= 95.0:
		GlobalLogic.current_hp = 70.0
		GlobalLogic.player_hp_changed.emit(70.0, GlobalLogic.max_hp)

	_set_task("Gunakan Healing Potion (1) • Waspada bar Toxicity di kiri atas")
	step_started.emit(Step.POTION, "Gunakan Healing Potion (1)")

func _on_potion_consumed(potion_name: String) -> void:
	if current_step == Step.POTION and not is_transitioning:
		if potion_name == "healing":
			is_transitioning = true
			_play_chime()
			_show_step_done("✓ Ramuan diminum (Racun bertambah)")
			step_completed.emit(Step.POTION)

			await get_tree().create_timer(1.3).timeout
			start_step(Step.COMBAT)

# ==============================================================================
# STEP 4: PERTARUNGAN
# ==============================================================================
func _start_combat_step() -> void:
	_set_task("Serang boneka slime di depan (Klik Kiri)")
	combat_dummy_ref = _get_dummy_slime()
	if combat_dummy_ref and combat_dummy_ref.has_signal("damaged"):
		if not combat_dummy_ref.is_connected("damaged", _on_dummy_damaged):
			combat_dummy_ref.connect("damaged", _on_dummy_damaged)
	step_started.emit(Step.COMBAT, "Serang boneka slime di depan (Klik Kiri)")

func _on_dummy_damaged(_amount: float) -> void:
	if current_step == Step.COMBAT and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Serangan berhasil mendarat")
		step_completed.emit(Step.COMBAT)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.COMPLETED)

# ==============================================================================
# STEP 5: SELESAI
# ==============================================================================
func _start_completed_step() -> void:
	_set_task("Latihan selesai • Pintu dungeon terbuka")
	if ui_task:
		ui_task.add_theme_color_override("font_color", UIPalette.EMERALD)

	_play_chime()
	tutorial_finished.emit()
	GlobalLogic.complete_tutorial()

	await get_tree().create_timer(5.0).timeout
	if ui_container and is_instance_valid(ui_container):
		var tw := create_tween()
		tw.tween_property(ui_container, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(ui_container.hide)

# ==============================================================================
# MINIMALIST HUD (Palet Eksak StyleBoxFlat_crafting dari Meja Alkimia)
# ==============================================================================
func _setup_ui() -> void:
	var control_root: Control = null
	var main_control = get_tree().root.find_child("Control", true, false)
	if main_control and main_control is Control and main_control.get_parent() is CanvasLayer:
		control_root = main_control
	else:
		ui_canvas = CanvasLayer.new()
		ui_canvas.name = "TutorialHUD"
		ui_canvas.layer = 10
		add_child(ui_canvas)

		var custom_root := Control.new()
		custom_root.name = "TutorialRoot"
		custom_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		custom_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_canvas.add_child(custom_root)
		control_root = custom_root

	# Kotak Bar Tipis & Rapi di Bagian Atas
	ui_container = PanelContainer.new()
	ui_container.name = "ObjectiveBar"
	ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ui_container.anchor_left = 0.5
	ui_container.anchor_right = 0.5
	ui_container.offset_left = -220.0
	ui_container.offset_top = 18.0
	ui_container.offset_right = 220.0
	ui_container.offset_bottom = 54.0

	# Gunakan template StyleBoxFlat terpusat (res://resources/ui/panel_box.tres)
	ui_panel_style = PANEL_TEMPLATE.duplicate() as StyleBoxFlat
	ui_container.add_theme_stylebox_override("panel", ui_panel_style)
	control_root.add_child(ui_container)

	# Label langsung tanpa header/kategori "TUTORIAL"
	ui_task = Label.new()
	ui_task.text = ""
	ui_task.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_task.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_task.add_theme_font_size_override("font_size", 13)
	ui_task.add_theme_color_override("font_color", UIPalette.TEXT_TITLE)
	ui_container.add_child(ui_task)

func _set_task(task: String) -> void:
	if not ui_container:
		return
	ui_task.text = task
	ui_task.add_theme_color_override("font_color", UIPalette.TEXT_TITLE)
	ui_panel_style.border_color = UIPalette.BORDER_SLATE
	ui_container.modulate.a = 1.0

func _show_step_done(done_text: String) -> void:
	if not ui_task:
		return
	ui_task.text = done_text
	ui_task.add_theme_color_override("font_color", UIPalette.EMERALD)
	ui_panel_style.border_color = UIPalette.EMERALD

	var tw := create_tween()
	tw.tween_property(ui_container, "scale", Vector2(1.03, 1.03), 0.08)
	tw.tween_property(ui_container, "scale", Vector2(1.0, 1.0), 0.1)

func _clear_3d_markers() -> void:
	if marker_area and is_instance_valid(marker_area):
		marker_area.queue_free()

func _get_player() -> Node3D:
	var p = get_tree().root.find_child("Players", true, false)
	if p is Node3D:
		return p
	return null

func _get_dummy_slime() -> Node3D:
	var dummy = get_parent().get_node_or_null("DummySlime")
	if dummy:
		return dummy
	var enemy = get_tree().get_first_node_in_group("enemies")
	if enemy is Node3D:
		return enemy
	return null

func _play_chime() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.bus = "Master"
	var sample_hz := 22050.0
	var dur := 0.28
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var note_idx := int(t / (dur / 3.0))
		var freqs := [587.33, 739.99, 880.0]
		var freq: float = freqs[mini(note_idx, 2)]
		var note_t: float = t - (float(note_idx) * (dur / 3.0))
		var env := exp(-note_t * 16.0)
		var val := int(sin(t * freq * TAU) * env * 0.35 * 32767.0)
		buffer.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	sfx.stream = wav
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
