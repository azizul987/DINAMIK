@tool
class_name ProceduralBipedAnimator
extends Node3D

enum MobState {
	IDLE,
	PATROL,
	CHASE
}

@export_group("Target Nodes")
@export var skeleton: Skeleton3D
@export var animation_player: AnimationPlayer
@export var visual_root: Node3D

@export_group("Autonomous Patrol & Movement")
@export var auto_walk_enabled: bool = true
@export var patrol_radius: float = 4.0
@export var walk_speed: float = 2.2
@export var chase_speed: float = 3.2
@export var turn_speed: float = 6.0
@export var idle_wait_time_min: float = 1.2
@export var idle_wait_time_max: float = 2.8
@export var chase_player: bool = true
@export var detection_range: float = 8.0
@export var lose_interest_range: float = 12.0
@export var stop_distance: float = 1.8

@export_group("Procedural Mathematical Dynamics")
@export var procedural_bob_enabled: bool = true
@export var body_bob_height: float = 0.04
@export var body_sway_deg: float = 3.0
@export var step_frequency: float = 6.28

@export_group("Animation Parameters")
@export var anim_library: AnimationLibrary = preload("res://resources/mob/mob_anim_library.tres")
@export var blend_time: float = 0.25
@export var walk_anim_speed: float = 1.0
@export var chase_anim_speed: float = 1.35

var current_state: MobState = MobState.IDLE
var spawn_position: Vector3 = Vector3.ZERO
var target_destination: Vector3 = Vector3.ZERO

var _idle_timer: float = 1.5
var _detection_timer: float = 0.0
var _step_time: float = 0.0
var _player_ref: Node3D = null
var _last_played_anim: StringName = &""
var _initial_visual_y: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	target_destination = spawn_position
	_idle_timer = randf_range(idle_wait_time_min, idle_wait_time_max)
	_setup_animation_player()
	if visual_root:
		_initial_visual_y = visual_root.position.y

func _setup_animation_player() -> void:
	if not skeleton:
		skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
		if not skeleton and get_parent():
			skeleton = get_parent().find_child("Skeleton3D", true, false) as Skeleton3D

	if skeleton:
		skeleton.clear_bones_global_pose_override()

	if not visual_root:
		var arm := find_child("Armature", true, false) as Node3D
		if not arm and get_parent():
			arm = get_parent().find_child("Armature", true, false) as Node3D
		visual_root = arm if arm else self

	if not animation_player:
		animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
		if not animation_player:
			animation_player = AnimationPlayer.new()
			animation_player.name = "AnimationPlayer"
			add_child(animation_player)

	if animation_player:
		animation_player.root_node = NodePath("..")
		if anim_library:
			if not animation_player.has_animation_library(""):
				animation_player.add_animation_library("", anim_library)
			elif animation_player.get_animation_library("") != anim_library:
				animation_player.remove_animation_library("")
				animation_player.add_animation_library("", anim_library)

		animation_player.playback_default_blend_time = blend_time
		_play_animation(&"idle", 1.0)

func _process(delta: float) -> void:
	# Di editor viewport: majukan frame animasi secara aktif agar terlihat bergerak live
	if Engine.is_editor_hint():
		if not animation_player:
			_setup_animation_player()
		if animation_player:
			if not animation_player.is_playing():
				_play_animation(&"idle", 1.0)
			animation_player.advance(delta)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not animation_player:
		_setup_animation_player()

	if not auto_walk_enabled:
		_play_animation(&"idle", 1.0)
		return

	_update_player_detection(delta)

	match current_state:
		MobState.IDLE:
			_process_idle_state(delta)
		MobState.PATROL:
			_process_patrol_state(delta)
		MobState.CHASE:
			_process_chase_state(delta)

func _update_player_detection(delta: float) -> void:
	if not chase_player or not is_inside_tree():
		return

	_detection_timer -= delta
	if _detection_timer > 0.0:
		return
	_detection_timer = 0.25

	if not is_instance_valid(_player_ref):
		var tree := get_tree()
		if tree:
			var players := tree.get_nodes_in_group("player")
			if players.size() > 0:
				_player_ref = players[0] as Node3D

	if is_instance_valid(_player_ref):
		var dist := global_position.distance_to(_player_ref.global_position)
		if current_state == MobState.CHASE:
			if dist > lose_interest_range:
				current_state = MobState.IDLE
				_idle_timer = randf_range(idle_wait_time_min, idle_wait_time_max)
		else:
			if dist <= detection_range:
				current_state = MobState.CHASE

func _process_idle_state(delta: float) -> void:
	_play_animation(&"idle", 1.0)
	_reset_procedural_sway(delta)
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_pick_new_patrol_destination()

func _process_patrol_state(delta: float) -> void:
	var to_dest := target_destination - global_position
	to_dest.y = 0.0
	var dist := to_dest.length()

	if dist < 0.4:
		current_state = MobState.IDLE
		_idle_timer = randf_range(idle_wait_time_min, idle_wait_time_max)
		_play_animation(&"idle", 1.0)
		return

	var move_dir := to_dest.normalized()
	_face_direction(move_dir, delta)
	global_position += move_dir * walk_speed * delta
	_apply_procedural_walk_math(delta, 1.0)
	_play_animation(&"walk", walk_anim_speed)

func _process_chase_state(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		current_state = MobState.IDLE
		_idle_timer = randf_range(idle_wait_time_min, idle_wait_time_max)
		_play_animation(&"idle", 1.0)
		return

	var to_player := _player_ref.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var move_dir := to_player.normalized()

	_face_direction(move_dir, delta)

	if dist > stop_distance:
		global_position += move_dir * chase_speed * delta
		_apply_procedural_walk_math(delta, 1.35)
		_play_animation(&"walk", chase_anim_speed)
	else:
		_reset_procedural_sway(delta)
		_play_animation(&"idle", 1.0)

func _pick_new_patrol_destination() -> void:
	var angle := randf() * TAU
	var radius := randf_range(1.5, patrol_radius)
	target_destination = spawn_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	current_state = MobState.PATROL

func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.001:
		return
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)

func _apply_procedural_walk_math(delta: float, speed_scale: float) -> void:
	if not procedural_bob_enabled or not visual_root:
		return
	_step_time += delta * step_frequency * speed_scale
	var bob := absf(sin(_step_time)) * body_bob_height
	var sway := sin(_step_time * 0.5) * deg_to_rad(body_sway_deg)
	visual_root.position.y = _initial_visual_y + bob
	visual_root.rotation.z = sway

func _reset_procedural_sway(delta: float) -> void:
	if not visual_root:
		return
	visual_root.position.y = move_toward(visual_root.position.y, _initial_visual_y, delta * 0.5)
	visual_root.rotation.z = move_toward(visual_root.rotation.z, 0.0, delta * 3.0)

func _play_animation(anim_name: StringName, speed: float = 1.0) -> void:
	if not animation_player:
		return
	if not animation_player.has_animation(anim_name):
		return

	animation_player.speed_scale = speed
	if _last_played_anim != anim_name or not animation_player.is_playing():
		_last_played_anim = anim_name
		animation_player.play(anim_name, blend_time)

## Memperbarui animasi secara manual jika dipanggil oleh controller eksternal.
func update_animation(_delta: float, is_moving: bool, speed_ratio: float = 1.0) -> void:
	if is_moving:
		_play_animation(&"walk", maxf(0.5, speed_ratio))
	else:
		_play_animation(&"idle", 1.0)
