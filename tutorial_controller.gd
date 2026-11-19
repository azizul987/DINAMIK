@tool
class_name TutorialController
extends Node3D

signal step_started(step_index: int, title: String)
signal step_completed(step_index: int)
signal tutorial_finished()

enum Step {
	MOVEMENT = 0,
	PICKUP = 1,
	CRAFT_HEALING = 2,
	USE_HEALING = 3,
	COMBAT = 4,
	CRAFT_BERSERK = 5,
	USE_BERSERK = 6,
	EXIT_PORTAL = 7,
	COMPLETED = 8
}

@export_group("Positioning")
@export var marker_position: Vector3 = Vector3(0.0, 0.26, -4.5)
@export var marker_radius: float = 1.4
@export var marker_color: Color = Color(0.15, 0.75, 1.0, 1.0):
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

@onready var marker_area: Area3D = $TutorialMarker if has_node("TutorialMarker") else null
@onready var marker_ring: MeshInstance3D = $TutorialMarker/MarkerRing if has_node("TutorialMarker/MarkerRing") else null
@onready var marker_disc: MeshInstance3D = $TutorialMarker/MarkerDisc if has_node("TutorialMarker/MarkerDisc") else null
@onready var chime_player: AudioStreamPlayer = $ChimePlayer if has_node("ChimePlayer") else null

var marker_mat_ring: StandardMaterial3D = null
var marker_mat_disc: StandardMaterial3D = null
var _chime_stream: AudioStreamWAV = null

var tutorial_drop_node: Node3D = null
var combat_dummy_ref: Node3D = null
var door_ref: DungeonDoor = null
var door2_ref: DungeonDoor = null
var door3_ref: DungeonDoor = null
var portal_ref: Portal = null
var tracked_slimes: Array[Node3D] = []

var ui_canvas: CanvasLayer = null
var ui_container: PanelContainer = null
var ui_task: Label = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Jika tutorial sudah selesai, matikan controller
	if GlobalLogic and "is_tutorial_completed" in GlobalLogic and GlobalLogic.is_tutorial_completed:
		_setup_ui()
		if ui_container:
			ui_container.visible = false
		visible = false
		set_process(false)
		set_process_unhandled_input(false)
		return

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
	# Fallback: TutorialMarker bisa jadi sibling (bukan child), misal di main.tscn
	if not marker_area and get_parent():
		marker_area = get_parent().get_node_or_null("TutorialMarker") as Area3D
	if marker_area:
		if marker_area.position != marker_position and marker_position == Vector3(0.0, 0.26, -4.5):
			marker_position = marker_area.position

		if marker_area.has_method("set"):
			marker_area.set("marker_color", marker_color)

		if not marker_ring:
			marker_ring = marker_area.get_node_or_null("OuterRing") as MeshInstance3D
			if not marker_ring:
				marker_ring = marker_area.get_node_or_null("MarkerRing") as MeshInstance3D
		if not marker_disc:
			marker_disc = marker_area.get_node_or_null("CenterDisc") as MeshInstance3D
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
	if marker_area and is_instance_valid(marker_area) and marker_area.has_method("set"):
		marker_area.set("marker_color", marker_color)
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

	if is_transitioning:
		return

	match current_step:
		Step.COMBAT:
			if _are_all_slimes_dead():
				_on_all_slimes_defeated()
		Step.EXIT_PORTAL:
			var d3 := _get_berserk_door()
			if d3 and d3.is_open and not is_transitioning:
				_on_berserk_door_opened()
				return
			var player := _get_player()
			var portal := _get_level_exit_portal()
			if player and portal and player.global_position.distance_to(portal.global_position) <= 2.8:
				_on_exit_portal_entered(portal, "res://SafeRoom.tscn")

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
		Step.CRAFT_HEALING:
			_start_craft_healing_step()
		Step.USE_HEALING:
			_start_use_healing_step()
		Step.COMBAT:
			_start_combat_step()
		Step.CRAFT_BERSERK:
			_start_craft_berserk_step()
		Step.USE_BERSERK:
			_start_use_berserk_step()
		Step.EXIT_PORTAL:
			_start_exit_portal_step()
		Step.COMPLETED:
			_start_completed_step()

func _start_movement_step() -> void:
	_set_task("Masuki lingkaran")
	_spawn_ground_marker()
	step_started.emit(Step.MOVEMENT, "Masuki lingkaran")

func _spawn_ground_marker() -> void:
	if not marker_area:
		_setup_marker_nodes()
	if not marker_area:
		return

	marker_area.position = marker_position
	if marker_area.has_method("reset_marker"):
		marker_area.reset_marker()
	else:
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
	if body.name == "Players" or body.is_in_group("player"):
		is_transitioning = true
		_play_chime()

		if marker_area and is_instance_valid(marker_area):
			if marker_area.has_method("play_reached_animation"):
				marker_area.play_reached_animation()
			else:
				var tw := create_tween()
				tw.tween_property(marker_area, "scale", Vector3(1.25, 0.2, 1.25), 0.2).set_trans(Tween.TRANS_SINE)
				if marker_mat_ring:
					tw.parallel().tween_property(marker_mat_ring, "albedo_color:a", 0.0, 0.2)
				tw.chain().tween_callback(func():
					if is_instance_valid(marker_area):
						marker_area.visible = false
						marker_area.monitoring = false
				)

		_show_step_done("✓ Lingkaran tercapai")
		step_completed.emit(Step.MOVEMENT)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.PICKUP)

func _update_marker_visuals(delta: float) -> void:
	if marker_area and marker_area.has_method("play_reached_animation"):
		return
	if marker_ring and is_instance_valid(marker_ring) and not is_transitioning:
		marker_ring.rotate_y(delta * 0.7)
		if marker_mat_ring:
			var pulse := (sin(_elapsed_time * 3.5) + 1.0) * 0.5
			marker_mat_ring.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, lerpf(0.55, 0.9, pulse))

func _start_pickup_step() -> void:
	_set_task("Ambil Slime Gel")
	_spawn_slime_drop()
	step_started.emit(Step.PICKUP, "Ambil Slime Gel")

func _spawn_slime_drop() -> void:
	if not tutorial_drop_node and has_node("TutorialSlimeDrop"):
		tutorial_drop_node = $TutorialSlimeDrop

	if tutorial_drop_node and is_instance_valid(tutorial_drop_node):
		tutorial_drop_node.position = drop_position
		tutorial_drop_node.visible = true
		tutorial_drop_node.process_mode = Node.PROCESS_MODE_INHERIT
		if "magnet_radius" in tutorial_drop_node:
			tutorial_drop_node.magnet_radius = 2.0
		if "pickup_distance" in tutorial_drop_node:
			tutorial_drop_node.pickup_distance = 1.0
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
	drop.magnet_radius = 2.0
	drop.pickup_distance = 1.0

	add_child(drop)
	drop.position = drop_position
	tutorial_drop_node = drop

func _check_manual_pickup() -> void:
	var player: Node3D = _get_player()
	if not player or not tutorial_drop_node or not is_instance_valid(tutorial_drop_node):
		return

	if player.global_position.distance_to(tutorial_drop_node.global_position) <= 2.2:
		if tutorial_drop_node.has_method("_collect"):
			tutorial_drop_node.call("_collect")
		else:
			GlobalLogic.add_material("slime_gel", 1)
			tutorial_drop_node.queue_free()

func _on_inventory_updated() -> void:
	if current_step == Step.PICKUP and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Slime Gel tersimpan")
		step_completed.emit(Step.PICKUP)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.CRAFT_HEALING)
	elif current_step == Step.CRAFT_HEALING and not is_transitioning:
		if GlobalLogic.potions.get("healing", 0) >= 1:
			_advance_from_craft_healing()
	elif current_step == Step.CRAFT_BERSERK and not is_transitioning:
		if GlobalLogic.potions.get("berserk", 0) >= 1:
			_advance_from_craft_berserk()
		elif GlobalLogic.materials.get("goblin_ear", 0) >= 1 or GlobalLogic.materials.get("fire_essence", 0) >= 1:
			_set_task("Racik Berserk Potion")

func _start_craft_healing_step() -> void:
	if GlobalLogic.materials.get("slime_gel", 0) < 1 and GlobalLogic.potions.get("healing", 0) < 1:
		GlobalLogic.materials["slime_gel"] = 1
		GlobalLogic.inventory_updated.emit()

	_set_task("Racik Healing Potion")
	step_started.emit(Step.CRAFT_HEALING, "Racik Healing Potion")

	if GlobalLogic.potions.get("healing", 0) >= 1:
		_advance_from_craft_healing()

func _advance_from_craft_healing() -> void:
	if current_step == Step.CRAFT_HEALING and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Healing Potion diracik")
		step_completed.emit(Step.CRAFT_HEALING)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.USE_HEALING)

func _start_use_healing_step() -> void:
	if GlobalLogic.current_hp >= 95.0:
		GlobalLogic.current_hp = starting_player_hp
		GlobalLogic.player_hp_changed.emit(starting_player_hp, GlobalLogic.max_hp)

	_set_task("Minum Healing Potion")
	step_started.emit(Step.USE_HEALING, "Minum Healing Potion")

func _on_potion_consumed(potion_name: String) -> void:
	if current_step == Step.USE_HEALING and not is_transitioning:
		if potion_name == "healing":
			is_transitioning = true
			_play_chime()
			_show_step_done("✓ Ramuan diminum")
			step_completed.emit(Step.USE_HEALING)

			var d1 := _get_door()
			if d1 and not d1.is_open:
				d1.open_door()

			await get_tree().create_timer(1.2).timeout
			start_step(Step.COMBAT)
	elif current_step == Step.USE_BERSERK and not is_transitioning:
		if potion_name == "berserk":
			_advance_from_use_berserk()

func _start_combat_step() -> void:
	_set_task("Kalahkan Slime")
	step_started.emit(Step.COMBAT, "Kalahkan Slime")

	tracked_slimes.clear()
	var dummy := _get_dummy_slime()
	if dummy and is_instance_valid(dummy):
		tracked_slimes.append(dummy)

	var all_enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy is CharacterBody3D and "Slime" in enemy.name and not tracked_slimes.has(enemy):
			tracked_slimes.append(enemy)

	if tracked_slimes.is_empty() or _are_all_slimes_dead():
		_on_all_slimes_defeated()
		return

	for s in tracked_slimes:
		if s.has_signal("defeated") and not s.is_connected("defeated", _check_slimes_status):
			s.connect("defeated", _check_slimes_status)

func _check_slimes_status() -> void:
	if current_step != Step.COMBAT or is_transitioning:
		return
	if _are_all_slimes_dead():
		_on_all_slimes_defeated()

func _are_all_slimes_dead() -> bool:
	if tracked_slimes.is_empty():
		return true
	for s in tracked_slimes:
		if is_instance_valid(s):
			if "is_dead" in s and not s.is_dead:
				return false
			if "current_health" in s and s.current_health > 0.0:
				return false
	return true

func _on_all_slimes_defeated() -> void:
	if current_step == Step.COMBAT and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Slime dikalahkan")
		step_completed.emit(Step.COMBAT)

		var d2 := _get_sealed_door()
		if d2 and not d2.is_open:
			d2.open_door()

		await get_tree().create_timer(1.4).timeout
		start_step(Step.CRAFT_BERSERK)

func _start_craft_berserk_step() -> void:
	var has_berserk_mat: bool = GlobalLogic.materials.get("goblin_ear", 0) >= 1 or GlobalLogic.materials.get("fire_essence", 0) >= 1
	var task_text: String = "Racik Berserk Potion" if has_berserk_mat else "Hancurkan Peti"

	_set_task(task_text)
	step_started.emit(Step.CRAFT_BERSERK, task_text)

	if GlobalLogic.potions.get("berserk", 0) >= 1:
		_advance_from_craft_berserk()

func _advance_from_craft_berserk() -> void:
	if current_step == Step.CRAFT_BERSERK and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Berserk Potion diracik")
		step_completed.emit(Step.CRAFT_BERSERK)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.USE_BERSERK)

func _start_use_berserk_step() -> void:
	if GlobalLogic.potions.get("berserk", 0) < 1 and not GlobalLogic.is_potion_active("berserk"):
		GlobalLogic.potions["berserk"] = 1
		GlobalLogic.inventory_updated.emit()

	_set_task("Minum Berserk Potion")
	step_started.emit(Step.USE_BERSERK, "Minum Berserk Potion")

	if GlobalLogic.is_potion_active("berserk"):
		_advance_from_use_berserk()

func _advance_from_use_berserk() -> void:
	if current_step == Step.USE_BERSERK and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Mode Berserk aktif")
		step_completed.emit(Step.USE_BERSERK)

		await get_tree().create_timer(1.2).timeout
		start_step(Step.EXIT_PORTAL)

func _start_exit_portal_step() -> void:
	var d3 := _get_berserk_door()
	if d3 and not d3.is_open:
		_set_task("Hancurkan Pintu Segel")
		step_started.emit(Step.EXIT_PORTAL, "Hancurkan Pintu Segel")
		if not d3.door_opened.is_connected(_on_berserk_door_opened):
			d3.door_opened.connect(_on_berserk_door_opened)
	else:
		_set_task("Masuki Safe Room")
		step_started.emit(Step.EXIT_PORTAL, "Masuki Safe Room")

	var portal := _get_level_exit_portal()
	if portal:
		if not portal.player_entered.is_connected(_on_exit_portal_entered):
			portal.player_entered.connect(_on_exit_portal_entered)

func _on_berserk_door_opened() -> void:
	if current_step == Step.EXIT_PORTAL and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Pintu Segel Hancur")
		step_completed.emit(Step.EXIT_PORTAL)

		await get_tree().create_timer(1.0).timeout
		start_step(Step.COMPLETED)

func _on_exit_portal_entered(_portal: Node3D = null, _target_scene: String = "") -> void:
	if current_step == Step.EXIT_PORTAL and not is_transitioning:
		is_transitioning = true
		_play_chime()
		_show_step_done("✓ Memasuki Safe Room...")
		step_completed.emit(Step.EXIT_PORTAL)

		await get_tree().create_timer(0.8).timeout
		start_step(Step.COMPLETED)

func _get_door() -> DungeonDoor:
	if door_ref and is_instance_valid(door_ref):
		return door_ref
	var d := get_tree().root.find_child("door", true, false)
	if d is DungeonDoor:
		door_ref = d
		return d
	return null

func _get_sealed_door() -> DungeonDoor:
	if door2_ref and is_instance_valid(door2_ref):
		return door2_ref
	var d := get_tree().root.find_child("door2", true, false)
	if d is DungeonDoor:
		door2_ref = d
		return d
	return null

func _get_berserk_door() -> DungeonDoor:
	if door3_ref and is_instance_valid(door3_ref):
		return door3_ref
	var d := get_tree().root.find_child("door3", true, false)
	if d is DungeonDoor:
		door3_ref = d
		return d
	return null

func _get_level_exit_portal() -> Portal:
	if portal_ref and is_instance_valid(portal_ref):
		return portal_ref
	var p := get_tree().root.find_child("Exit", true, false)
	if not p:
		p = get_tree().root.find_child("LevelExitPortal", true, false)
	if p is Portal:
		portal_ref = p
		return p
	return null

func _start_completed_step() -> void:
	_set_task("✓ Tutorial Selesai")
	if ui_task:
		ui_task.add_theme_color_override("font_color", UIPalette.EMERALD)

	_play_chime()
	tutorial_finished.emit()
	GlobalLogic.complete_tutorial()

	await get_tree().create_timer(1.8).timeout
	if ui_container and is_instance_valid(ui_container):
		var tw := create_tween()
		tw.tween_property(ui_container, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(ui_container.hide)

func _setup_ui() -> void:
	var main_control = get_tree().root.find_child("Control", true, false)
	if main_control:
		var bar = main_control.get_node_or_null("ObjectiveBar")
		if bar and bar is PanelContainer:
			ui_container = bar
			ui_container.visible = true
			ui_container.modulate.a = 1.0
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
	ui_container.visible = true

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
