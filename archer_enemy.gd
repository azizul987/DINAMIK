class_name ArcherEnemy
extends CharacterBody3D

signal defeated()
signal damaged(amount: float)
signal arrow_fired(projectile: ArrowProjectile)

enum State {
	IDLE,
	PATROL,
	CHASE,
	KITE,
	AIMING,
	SHOOTING,
	HURT,
	DEAD
}

const ARROW_PROJECTILE_SCENE: PackedScene = preload("res://arrow_projectile.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")
const ITEM_DROP_SCENE: PackedScene = preload("res://item_drop.tscn")

@export_group("Stats")
@export var max_health: float = 35.0
@export var arrow_damage: float = 12.0
@export var arrow_speed: float = 17.5
@export var shoot_cooldown: float = 2.2
@export var aim_draw_duration: float = 0.65

@export_group("AI Ranges")
@export var detection_radius: float = 14.0
@export var lose_interest_radius: float = 18.0
@export var preferred_shoot_distance: float = 8.0
@export var min_kite_distance: float = 3.8
@export var walk_speed: float = 2.8
@export var kite_speed: float = 2.2
@export var turn_speed: float = 6.0
@export var gravity: float = 18.0

@export_group("Patrol")
@export var patrol_radius: float = 5.0
@export var min_idle_time: float = 1.2
@export var max_idle_time: float = 2.8

var current_health: float = 35.0
var current_state: State = State.IDLE
var is_dead: bool = false
var spawn_position: Vector3 = Vector3.ZERO
var target_destination: Vector3 = Vector3.ZERO

var player_ref: Node3D = null
var idle_timer: float = 0.0
var state_timer: float = 0.0
var shoot_timer: float = 0.0
var hurt_timer: float = 0.0
var _detection_check_timer: float = 0.0

@onready var visual_root: Node3D = $VisualRoot if has_node("VisualRoot") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var bow_pivot: Node3D = $VisualRoot/BowPivot if has_node("VisualRoot/BowPivot") else null
@onready var arrow_spawn_point: Marker3D = $VisualRoot/BowPivot/ArrowSpawnPoint if has_node("VisualRoot/BowPivot/ArrowSpawnPoint") else null
@onready var aim_laser: MeshInstance3D = $VisualRoot/BowPivot/AimLaser if has_node("VisualRoot/BowPivot/AimLaser") else null
@onready var hit_particles: CPUParticles3D = $HitParticles if has_node("HitParticles") else null
@onready var hp_viewport: SubViewport = $HpViewport if has_node("HpViewport") else null
@onready var hp_bar: ProgressBar = $HpViewport/HpBar if has_node("HpViewport/HpBar") else null
@onready var hp_lag_bar: ProgressBar = $HpViewport/HpLagBar if has_node("HpViewport/HpLagBar") else null
@onready var hp_sprite: Sprite3D = $HpSprite if has_node("HpSprite") else null
@onready var shoot_audio: AudioStreamPlayer3D = $ShootAudio if has_node("ShootAudio") else null
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio if has_node("HitAudio") else null

var _hp_lag_tween: Tween = null
var _flash_material: StandardMaterial3D = null
var _bow_initial_transform: Transform3D = Transform3D.IDENTITY
var _flash_meshes: Array[MeshInstance3D] = []

static var _cached_draw_stream: AudioStreamWAV = null
static var _cached_release_stream: AudioStreamWAV = null
static var _cached_hurt_stream: AudioStreamWAV = null

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	current_health = max_health
	idle_timer = randf_range(min_idle_time, max_idle_time)

	if bow_pivot:
		_bow_initial_transform = bow_pivot.transform

	_cache_mesh_list()
	_setup_health_bar()
	_setup_flash_material()
	_ensure_cached_audio()

func _cache_mesh_list() -> void:
	_flash_meshes.clear()
	if visual_root:
		for child in visual_root.find_children("*", "MeshInstance3D", true, false):
			var m := child as MeshInstance3D
			if m and m != aim_laser:
				_flash_meshes.append(m)

func _setup_health_bar() -> void:
	if hp_viewport:
		hp_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	if hp_sprite and hp_viewport and not hp_sprite.texture:
		hp_sprite.texture = hp_viewport.get_texture()

	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health

	if hp_lag_bar:
		hp_lag_bar.max_value = max_health
		hp_lag_bar.value = current_health

func _setup_flash_material() -> void:
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if shoot_timer > 0.0:
		shoot_timer = maxf(0.0, shoot_timer - delta)

	_detection_check_timer -= delta
	if _detection_check_timer <= 0.0:
		_detection_check_timer = 0.15
		_update_player_detection()

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.KITE:
			_process_kite(delta)
		State.AIMING:
			_process_aiming(delta)
		State.SHOOTING:
			_process_shooting(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()

func _update_player_detection() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as Node3D

	if not player_ref or not is_instance_valid(player_ref):
		return

	if GlobalLogic.is_dead:
		player_ref = null
		if current_state != State.IDLE and current_state != State.PATROL:
			current_state = State.IDLE
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if current_state == State.AIMING or current_state == State.SHOOTING or current_state == State.HURT:
		return

	if dist <= detection_radius:
		if shoot_timer <= 0.0 and dist <= preferred_shoot_distance * 1.25 and dist >= min_kite_distance:
			_start_aiming()
		elif dist < min_kite_distance:
			current_state = State.KITE
		else:
			current_state = State.CHASE
	elif dist > lose_interest_radius:
		if current_state == State.CHASE or current_state == State.KITE:
			current_state = State.IDLE
			idle_timer = randf_range(min_idle_time, max_idle_time)

func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)

	idle_timer -= delta
	if idle_timer <= 0.0:
		_pick_new_patrol_destination()

func _process_patrol(delta: float) -> void:
	var to_dest: Vector3 = target_destination - global_position
	to_dest.y = 0.0
	var dist := to_dest.length()

	if dist < 0.5:
		current_state = State.IDLE
		idle_timer = randf_range(min_idle_time, max_idle_time)
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var dir := to_dest.normalized()
	velocity.x = dir.x * walk_speed * 0.7
	velocity.z = dir.z * walk_speed * 0.7
	_face_direction(dir, delta)

func _pick_new_patrol_destination() -> void:
	var angle := randf() * TAU
	var radius := randf_range(1.5, patrol_radius)
	target_destination = spawn_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	current_state = State.PATROL

func _process_chase(delta: float) -> void:
	if not is_instance_valid(player_ref):
		current_state = State.IDLE
		return

	var to_player: Vector3 = player_ref.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist <= preferred_shoot_distance and shoot_timer <= 0.0:
		_start_aiming()
		return

	var dir := to_player.normalized()
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	_face_direction(dir, delta)

func _process_kite(delta: float) -> void:
	if not is_instance_valid(player_ref):
		current_state = State.IDLE
		return

	var to_player: Vector3 = player_ref.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist >= min_kite_distance * 1.2:
		if shoot_timer <= 0.0:
			_start_aiming()
		else:
			current_state = State.CHASE
		return

	var away_dir := -to_player.normalized()
	velocity.x = away_dir.x * kite_speed
	velocity.z = away_dir.z * kite_speed
	_face_direction(to_player.normalized(), delta)

func _start_aiming() -> void:
	current_state = State.AIMING
	state_timer = aim_draw_duration
	velocity.x = 0.0
	velocity.z = 0.0

	if aim_laser:
		aim_laser.visible = true

	if shoot_audio and _cached_draw_stream:
		shoot_audio.stream = _cached_draw_stream
		shoot_audio.pitch_scale = randf_range(0.95, 1.05)
		shoot_audio.play()

	if bow_pivot:
		var tw := create_tween()
		tw.tween_property(bow_pivot, "position:z", _bow_initial_transform.origin.z - 0.15, aim_draw_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process_aiming(delta: float) -> void:
	if not is_instance_valid(player_ref):
		_cancel_aiming()
		return

	var to_player: Vector3 = player_ref.global_position - global_position
	to_player.y = 0.0
	_face_direction(to_player.normalized(), delta * 1.5)

	state_timer -= delta
	if state_timer <= 0.0:
		_release_arrow()

func _cancel_aiming() -> void:
	current_state = State.IDLE
	if aim_laser:
		aim_laser.visible = false
	if bow_pivot:
		bow_pivot.transform = _bow_initial_transform

func _release_arrow() -> void:
	current_state = State.SHOOTING
	state_timer = 0.35
	shoot_timer = shoot_cooldown

	if aim_laser:
		aim_laser.visible = false

	if shoot_audio and _cached_release_stream:
		shoot_audio.stream = _cached_release_stream
		shoot_audio.pitch_scale = randf_range(0.95, 1.08)
		shoot_audio.play()

	if ARROW_PROJECTILE_SCENE and is_instance_valid(player_ref):
		var arrow := ARROW_PROJECTILE_SCENE.instantiate() as ArrowProjectile
		if arrow:
			var parent_node := get_parent()
			if not parent_node:
				parent_node = get_tree().current_scene
			parent_node.add_child(arrow)

			var spawn_pos := arrow_spawn_point.global_position if arrow_spawn_point else global_position + Vector3(0.0, 0.9, 0.0)
			arrow.global_position = spawn_pos
			var target_point := player_ref.global_position + Vector3(0.0, 0.9, 0.0)
			arrow.init_shot(self, target_point, arrow_speed)
			arrow.damage = arrow_damage
			arrow_fired.emit(arrow)

	if bow_pivot:
		var tw := create_tween()
		tw.tween_property(bow_pivot, "position:z", _bow_initial_transform.origin.z + 0.08, 0.06).set_trans(Tween.TRANS_BACK)
		tw.tween_property(bow_pivot, "position:z", _bow_initial_transform.origin.z, 0.22)

func _process_shooting(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.IDLE
		idle_timer = randf_range(0.4, 0.8)

func _process_hurt(delta: float) -> void:
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		current_state = State.CHASE

func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.001:
		return
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, _is_sharp: bool = false) -> void:
	if is_dead:
		return

	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount)

	_trigger_hit_flash()
	_update_hp_bar()
	_spawn_damage_number(amount)

	if hit_audio and _cached_hurt_stream:
		hit_audio.stream = _cached_hurt_stream
		hit_audio.pitch_scale = randf_range(0.9, 1.1)
		hit_audio.play()

	if hit_particles:
		hit_particles.restart()
		hit_particles.emitting = true

	if knockback.length_squared() > 0.01:
		velocity = knockback

	if current_health <= 0.0:
		_die()
	else:
		current_state = State.HURT
		hurt_timer = 0.35
		if aim_laser:
			aim_laser.visible = false

func _update_hp_bar() -> void:
	if hp_viewport:
		hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	if hp_bar:
		hp_bar.value = current_health

	if hp_lag_bar:
		if _hp_lag_tween and _hp_lag_tween.is_valid():
			_hp_lag_tween.kill()
		_hp_lag_tween = create_tween()
		_hp_lag_tween.tween_interval(0.2)
		_hp_lag_tween.tween_property(hp_lag_bar, "value", current_health, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hp_lag_tween.tween_callback(func():
			if is_instance_valid(hp_viewport):
				hp_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		)
	else:
		if is_instance_valid(hp_viewport):
			hp_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _trigger_hit_flash() -> void:
	if not _flash_material or _flash_meshes.is_empty():
		return
	for mesh_inst in _flash_meshes:
		if is_instance_valid(mesh_inst):
			mesh_inst.material_override = _flash_material

	var tw := create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(func():
		for mesh_inst in _flash_meshes:
			if is_instance_valid(mesh_inst):
				mesh_inst.material_override = null
	)

func _spawn_damage_number(amount: float) -> void:
	if not FLOATING_TEXT_SCENE:
		return
	var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
	if not label:
		return

	var display_text := str(roundi(amount))
	var text_color := Color(1.0, 1.0, 1.0, 1.0)
	var f_size := 36
	var rise_height := 0.7

	if amount >= 30.0:
		display_text = str(roundi(amount)) + "!"
		text_color = Color(1.0, 0.25, 0.25, 1.0)
		f_size = 48
		rise_height = 0.95
	elif amount >= 20.0:
		text_color = Color(1.0, 0.75, 0.2, 1.0)
		f_size = 42

	var spawn_pos := global_position + Vector3(randf_range(-0.25, 0.25), 1.6, randf_range(-0.25, 0.25))
	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(label)
		label.global_position = spawn_pos
		label.pop(display_text, text_color, f_size, rise_height, 0.45)

func _die() -> void:
	is_dead = true
	current_state = State.DEAD
	velocity = Vector3.ZERO
	defeated.emit()

	if aim_laser:
		aim_laser.visible = false
	if hp_sprite:
		hp_sprite.visible = false
	if collision_shape:
		collision_shape.disabled = true

	_spawn_loot()

	if visual_root:
		var tw := create_tween()
		tw.tween_property(visual_root, "scale", Vector3(1.3, 0.2, 1.3), 0.18).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(visual_root, "position:y", 0.1, 0.18)
		tw.tween_interval(0.4)
		tw.tween_property(visual_root, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_loot() -> void:
	if not ITEM_DROP_SCENE:
		return
	var drop := ITEM_DROP_SCENE.instantiate() as ItemDrop3D
	if not drop:
		return

	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(drop)
		drop.global_position = global_position + Vector3(0.0, 0.5, 0.0)
		drop.velocity = Vector3(randf_range(-1.0, 1.0), 3.0, randf_range(-1.0, 1.0))

static func _ensure_cached_audio() -> void:
	if _cached_draw_stream and _cached_release_stream and _cached_hurt_stream:
		return

	var sample_hz := 22050.0

	# 1. Bow draw sound
	if not _cached_draw_stream:
		var dur_draw := 0.35
		var samples_d := int(sample_hz * dur_draw)
		var buf_d := PackedByteArray()
		buf_d.resize(samples_d * 2)
		for i in range(samples_d):
			var t := float(i) / sample_hz
			var env := float(i) / float(samples_d)
			var freq := lerpf(180.0, 320.0, t / dur_draw)
			var val := int((sin(t * freq * TAU) * 0.4 + randf_range(-0.1, 0.1)) * env * 0.5 * 32767.0)
			buf_d.encode_s16(i * 2, val)
		_cached_draw_stream = AudioStreamWAV.new()
		_cached_draw_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_draw_stream.mix_rate = int(sample_hz)
		_cached_draw_stream.data = buf_d

	# 2. Bow release twang
	if not _cached_release_stream:
		var dur_rel := 0.22
		var samples_r := int(sample_hz * dur_rel)
		var buf_r := PackedByteArray()
		buf_r.resize(samples_r * 2)
		for i in range(samples_r):
			var t := float(i) / sample_hz
			var env := exp(-t * 18.0)
			var freq := 440.0 + sin(t * 120.0) * 80.0
			var val := int(sin(t * freq * TAU) * env * 0.65 * 32767.0)
			buf_r.encode_s16(i * 2, val)
		_cached_release_stream = AudioStreamWAV.new()
		_cached_release_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_release_stream.mix_rate = int(sample_hz)
		_cached_release_stream.data = buf_r

	# 3. Archer hurt voice/grunt
	if not _cached_hurt_stream:
		var dur_hurt := 0.18
		var samples_ht := int(sample_hz * dur_hurt)
		var buf_ht := PackedByteArray()
		buf_ht.resize(samples_ht * 2)
		for i in range(samples_ht):
			var t := float(i) / sample_hz
			var env := exp(-t * 14.0)
			var val := int(sin(t * 140.0 * TAU) * env * 0.6 * 32767.0)
			buf_ht.encode_s16(i * 2, val)
		_cached_hurt_stream = AudioStreamWAV.new()
		_cached_hurt_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_hurt_stream.mix_rate = int(sample_hz)
		_cached_hurt_stream.data = buf_ht
