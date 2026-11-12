@tool
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
@export var marker_color: Color = UIPalette.EMERALD:
	set(val):
		marker_color = val
		_apply_marker_color()
@export var drop_position: Vector3 = Vector3(0.0, 0.4, -6.5):
	set(val):
		drop_position = val
		if has_node("TutorialSlimeDrop"):
			var d_node = get_node("TutorialSlimeDrop")
			if d_node and d_node is Node3D:
				d_node.position = val
@export var auto_start: bool = true
@export var starting_player_hp: float = 60.0

const PANEL_TEMPLATE: StyleBox = preload("res://resources/ui/panel_box.tres")
const ITEM_DROP_SCENE: PackedScene = preload("res://item_drop.tscn")

var current_step: Step = Step.MOVEMENT
var is_transitioning: bool = false
var _elapsed_time: float = 0.0

# 3D Visual Elements & Audio (Node resmi di scene main.tscn)
@onready var marker_area: Area3D = $TutorialMarker if has_node("TutorialMarker") else null
@onready var marker_ring: MeshInstance3D = $TutorialMarker/MarkerRing if has_node("TutorialMarker/MarkerRing") else null
@onready var marker_disc: MeshInstance3D = $TutorialMarker/MarkerDisc if has_node("TutorialMarker/MarkerDisc") else null
@onready var chime_player: AudioStreamPlayer = $ChimePlayer if has_node("ChimePlayer") else null

var marker_mat_ring: StandardMaterial3D = null
var marker_mat_disc: StandardMaterial3D = null
var _chime_stream: AudioStreamWAV = null

var tutorial_drop_node: Node3D = null
var combat_dummy_ref: Node3D = null

# Minimalist HUD Elements (Menggunakan Palet Eksak Meja Alkimia / CraftingPanel)
var ui_canvas: CanvasLayer = null
var ui_container: PanelContainer = null
var ui_task: Label = null

func _ready() -> void:
	_setup_marker_nodes()
	_setup_drop_node()
	if Engine.is_editor_hint():
		return
	_apply_initial_player_hp()
	_setup_chime_stream()
	_setup_ui()
	_connect_global_signals()
	if auto_start:
		start_step(Step.MOVEMENT)

func _apply_initial_player_hp() -> void:
	if GlobalLogic:
		GlobalLogic.current_hp = starting_player_hp
		GlobalLogic.player_hp_changed.emit(GlobalLogic.current_hp, GlobalLogic.max_hp)

func _setup_drop_node() -> void:
	if not tutorial_drop_node and has_node("TutorialSlimeDrop"):
		tutorial_drop_node = $TutorialSlimeDrop
	if tutorial_drop_node:
		if tutorial_drop_node.position != drop_position and drop_position == Vector3(0.0, 0.4, -6.5):
			drop_position = tutorial_drop_node.position
		if not Engine.is_editor_hint():
			tutorial_drop_node.visible = false
			tutorial_drop_node.process_mode = Node.PROCESS_MODE_DISABLED

func _setup_marker_nodes() -> void:
	if not marker_area and has_node("TutorialMarker"):
		marker_area = $TutorialMarker as Area3D
	if marker_area:
		# Jika posisi TutorialMarker digeser langsung di 3D viewport scene, gunakan posisi tersebut
		if marker_area.position != marker_position and marker_position == Vector3(0.0, 0.26, -4.5):
			marker_position = marker_area.position

		if not marker_ring:
			marker_ring = marker_area.get_node_or_null("MarkerRing") as MeshInstance3D
		if not marker_disc:
			marker_disc = marker_area.get_node_or_null("MarkerDisc") as MeshInstance3D

		if marker_ring:
			if not marker_ring.material_override:
				if marker_ring.mesh and marker_ring.mesh.material:
					marker_ring.material_override = marker_ring.mesh.material.duplicate()
			marker_mat_ring = marker_ring.material_override as StandardMaterial3D

		if marker_disc:
			if not marker_disc.material_override:
				if marker_disc.mesh and marker_disc.mesh.material:
					marker_disc.material_override = marker_disc.mesh.material.duplicate()
			marker_mat_disc = marker_disc.material_override as StandardMaterial3D

		_apply_marker_color()

func _apply_marker_color() -> void:
	if not marker_ring or not marker_disc:
		if has_node("TutorialMarker"):
			_setup_marker_nodes()
	if marker_mat_ring:
		var current_a: float = marker_mat_ring.albedo_color.a
		marker_mat_ring.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, current_a)
	if marker_mat_disc:
		var current_a: float = marker_mat_disc.albedo_color.a
		marker_mat_disc.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, current_a)
		if marker_mat_disc.emission_enabled:
			marker_mat_disc.emission = marker_color

func _connect_global_signals() -> void:
	if not GlobalLogic.inventory_updated.is_connected(_on_inventory_updated):
		GlobalLogic.inventory_updated.connect(_on_inventory_updated)
	if not GlobalLogic.potion_consumed.is_connected(_on_potion_consumed):
		GlobalLogic.potion_consumed.connect(_on_potion_consumed)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_elapsed_time += delta
	_update_marker_visuals(delta)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
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
	if not marker_area:
		_setup_marker_nodes()
	if not marker_area:
		return

	marker_area.position = marker_position
	marker_area.scale = Vector3.ONE
	marker_area.visible = true
	marker_area.monitoring = true

	_apply_marker_color()
	if marker_mat_ring:
		marker_mat_ring.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.8)

	if not marker_area.body_entered.is_connected(_on_marker_body_entered):
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
			tw.chain().tween_callback(func():
				if is_instance_valid(marker_area):
					marker_area.visible = false
					marker_area.monitoring = false
			)

		_show_step_done("✓ Lingkaran target tercapai")
		step_completed.emit(Step.MOVEMENT)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.PICKUP)

func _update_marker_visuals(delta: float) -> void:
	if marker_ring and is_instance_valid(marker_ring) and not is_transitioning:
		marker_ring.rotate_y(delta * 0.7)
		if marker_mat_ring:
			var pulse := (sin(_elapsed_time * 3.5) + 1.0) * 0.5
			marker_mat_ring.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, lerpf(0.55, 0.9, pulse))

# ==============================================================================
# STEP 2: AMBIL BAHAN
# ==============================================================================
func _start_pickup_step() -> void:
	_set_task("Ambil Slime Gel di depan (E)")
	_spawn_slime_drop()
	step_started.emit(Step.PICKUP, "Ambil Slime Gel di depan (E)")

func _spawn_slime_drop() -> void:
	if not tutorial_drop_node and has_node("TutorialSlimeDrop"):
		tutorial_drop_node = $TutorialSlimeDrop

	if tutorial_drop_node and is_instance_valid(tutorial_drop_node):
		tutorial_drop_node.position = drop_position
		tutorial_drop_node.visible = true
		tutorial_drop_node.process_mode = Node.PROCESS_MODE_INHERIT
		if tutorial_drop_node is CharacterBody3D:
			tutorial_drop_node.velocity = Vector3(0.0, 2.0, 0.0)
		return

	if not ITEM_DROP_SCENE:
		return

	var drop = ITEM_DROP_SCENE.instantiate() as ItemDrop3D
	if not drop:
		return
	drop.name = "TutorialSlimeDrop"
	drop.item_type = "slime_gel"
	drop.item_amount = 1
	drop.item_color = Color(0.2, 0.9, 0.5, 0.95)
	drop.pop_force_y = 1.0
	drop.pop_spread_xz = 0.0
	drop.magnet_radius = 2.5
	drop.pickup_distance = 1.3

	add_child(drop)
	drop.position = drop_position
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
		GlobalLogic.current_hp = starting_player_hp
		GlobalLogic.player_hp_changed.emit(starting_player_hp, GlobalLogic.max_hp)

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
# MINIMALIST HUD (Menggunakan Template res://resources/ui/panel_box.tres)
# ==============================================================================
func _setup_ui() -> void:
	# Hubungkan ke ObjectiveBar yang ada di scene utama (main.tscn)
	var main_control = get_tree().root.find_child("Control", true, false)
	if main_control:
		var bar = main_control.get_node_or_null("ObjectiveBar")
		if bar and bar is PanelContainer:
			ui_container = bar
			ui_task = bar.get_node_or_null("ObjectiveText") as Label
			if not ui_task and bar.get_child_count() > 0 and bar.get_child(0) is Label:
				ui_task = bar.get_child(0) as Label
			return
	push_warning("ObjectiveBar node not found in scene tree.")

func _set_task(task: String) -> void:
	if not ui_container or not ui_task:
		return
	ui_task.text = task
	ui_task.add_theme_color_override("font_color", UIPalette.TEXT_TITLE)
	ui_container.modulate.a = 1.0

func _show_step_done(done_text: String) -> void:
	if not ui_task or not ui_container:
		return
	ui_task.text = done_text
	ui_task.add_theme_color_override("font_color", UIPalette.EMERALD)

	var tw := create_tween()
	tw.tween_property(ui_container, "scale", Vector2(1.03, 1.03), 0.08)
	tw.tween_property(ui_container, "scale", Vector2(1.0, 1.0), 0.1)

func _clear_3d_markers() -> void:
	if marker_area and is_instance_valid(marker_area):
		marker_area.visible = false
		marker_area.monitoring = false
	if current_step != Step.PICKUP and tutorial_drop_node and is_instance_valid(tutorial_drop_node):
		if not Engine.is_editor_hint():
			tutorial_drop_node.visible = false
			tutorial_drop_node.process_mode = Node.PROCESS_MODE_DISABLED

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

func _setup_chime_stream() -> void:
	if not chime_player and has_node("ChimePlayer"):
		chime_player = $ChimePlayer as AudioStreamPlayer

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

	_chime_stream = AudioStreamWAV.new()
	_chime_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_chime_stream.mix_rate = int(sample_hz)
	_chime_stream.data = buffer

	if chime_player:
		chime_player.stream = _chime_stream

func _play_chime() -> void:
	if not chime_player and has_node("ChimePlayer"):
		chime_player = $ChimePlayer as AudioStreamPlayer
	if chime_player:
		if not chime_player.stream and _chime_stream:
			chime_player.stream = _chime_stream
		chime_player.play()
