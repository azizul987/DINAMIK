class_name ImpAxeEnemy
extends CharacterBody3D

signal defeated()
signal damaged(amount: float)

enum State {
	IDLE,
	PATROL,
	CHASE,
	WINDUP,
	STRIKE,
	RECOVER,
	HURT,
	DEAD
}

const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")
const ITEM_DROP_SCENE: PackedScene = preload("res://item_drop.tscn")

@export_group("Stats")
@export var max_health: float = 40.0
@export var axe_damage: float = 14.0
@export var attack_cooldown: float = 1.7
@export var attack_range: float = 2.4
@export var attack_windup: float = 0.38
@export var attack_strike: float = 0.16
@export var attack_recover: float = 0.35
@export var attack_arc_deg: float = 140.0
@export var knockback_force: float = 8.5
@export var knockback_lift: float = 0.4
@export var attack_lunge_speed: float = 5.0

@export_group("AI Ranges")
@export var detection_radius: float = 12.0
@export var lose_interest_radius: float = 18.0
@export var hp_bar_visible_radius: float = 10.0
@export var walk_speed: float = 3.0
@export var chase_speed: float = 3.6
@export var turn_speed: float = 7.0
@export var gravity: float = 18.0

@export_group("Patrol")
@export var patrol_radius: float = 5.0
@export var min_idle_time: float = 1.2
@export var max_idle_time: float = 2.8

@export_group("Dungeon Glow")
@export var glow_color: Color = Color(1.0, 0.4, 0.15, 1.0)
@export var glow_intensity: float = 0.04
@export var glow_pulse: float = 0.15

@export_group("Loot Drop")
@export var drop_item_type: String = "frost_wing"
@export var drop_item_name: String = "Frost Wing"
@export var drop_item_amount: int = 1
@export var drop_item_color: Color = Color(0.5, 0.85, 1.0, 0.95)

var current_health: float = 40.0
var current_state: State = State.IDLE
var is_dead: bool = false
var spawn_position: Vector3 = Vector3.ZERO
var target_destination: Vector3 = Vector3.ZERO

var player_ref: Node3D = null
var idle_timer: float = 0.0
var state_timer: float = 0.0
var attack_timer: float = 0.0
var hurt_timer: float = 0.0
var _detection_check_timer: float = 0.0
var _has_hit_in_current_attack: bool = false

@onready var visual_root: Node3D = $VisualRoot if has_node("VisualRoot") else (find_child("VisualRoot", true, false) as Node3D)
@onready var animation_player: AnimationPlayer = $VisualRoot/AnimationPlayer if has_node("VisualRoot/AnimationPlayer") else (find_child("AnimationPlayer", true, false) as AnimationPlayer)
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else (find_child("CollisionShape3D", true, false) as CollisionShape3D)
@onready var axe_pivot: Node3D = find_child("AxePivot", true, false) as Node3D
@onready var hit_particles: CPUParticles3D = $HitParticles if has_node("HitParticles") else null
@onready var hp_viewport: SubViewport = $HpViewport if has_node("HpViewport") else null
@onready var hp_bar: ProgressBar = $HpViewport/HpBar if has_node("HpViewport/HpBar") else null
@onready var hp_lag_bar: ProgressBar = $HpViewport/HpLagBar if has_node("HpViewport/HpLagBar") else null
@onready var hp_sprite: Sprite3D = $HpSprite if has_node("HpSprite") else null
@onready var attack_audio: AudioStreamPlayer3D = $AttackAudio if has_node("AttackAudio") else null
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio if has_node("HitAudio") else null

var _hp_lag_tween: Tween = null
static var _cached_overlay_mat: ShaderMaterial = null
var _flash_tween: Tween = null
var _axe_rest_rotation: Vector3 = Vector3.ZERO
var _axe_raised_rotation: Vector3 = Vector3.ZERO
var _flash_meshes: Array[MeshInstance3D] = []

static var _cached_swing_stream: AudioStreamWAV = null
static var _cached_hurt_stream: AudioStreamWAV = null

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	current_health = max_health
	idle_timer = randf_range(min_idle_time, max_idle_time)

	if visual_root:
		var mace := visual_root.find_child("Imp_Mace", true, false) as VisualInstance3D
		if mace:
			mace.visible = false

	_setup_axe()
	_cache_mesh_list()
	_setup_health_bar()
	_setup_flash_material()
	_ensure_cached_audio()

	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

func _setup_axe() -> void:
	if not axe_pivot:
		axe_pivot = find_child("AxePivot", true, false) as Node3D
	if axe_pivot:
		_axe_rest_rotation = axe_pivot.rotation
		_axe_raised_rotation = _axe_rest_rotation + Vector3(deg_to_rad(-65.0), 0.0, 0.0)

func _cache_mesh_list() -> void:
	_flash_meshes.clear()
	if visual_root:
		for child in visual_root.find_children("*", "MeshInstance3D", true, false):
			var m := child as MeshInstance3D
			if m and m.name != "Imp_Mace" and m.name != "AxeModel":
				_flash_meshes.append(m)

func _setup_health_bar() -> void:
	if hp_viewport:
		hp_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	if hp_sprite and hp_viewport and not hp_sprite.texture:
		hp_sprite.texture = hp_viewport.get_texture()

	if hp_sprite:
		hp_sprite.visible = false

	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health

	if hp_lag_bar:
		hp_lag_bar.max_value = max_health
		hp_lag_bar.value = current_health

func _setup_flash_material() -> void:
	if not _cached_overlay_mat:
		var shader := load("res://shaders/dungeon_glow_overlay.gdshader") as Shader
		if shader:
			_cached_overlay_mat = ShaderMaterial.new()
			_cached_overlay_mat.shader = shader
	if _cached_overlay_mat:
		for mesh_inst in _flash_meshes:
			if is_instance_valid(mesh_inst):
				mesh_inst.material_overlay = _cached_overlay_mat
				mesh_inst.set_instance_shader_parameter("glow_color", glow_color)
				mesh_inst.set_instance_shader_parameter("glow_intensity", glow_intensity)
				mesh_inst.set_instance_shader_parameter("glow_pulse", glow_pulse)
				mesh_inst.set_instance_shader_parameter("hit_flash", 0.0)
				mesh_inst.set_instance_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if attack_timer > 0.0:
		attack_timer = maxf(0.0, attack_timer - delta)

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
		State.WINDUP:
			_process_windup(delta)
		State.STRIKE:
			_process_strike(delta)
		State.RECOVER:
			_process_recover(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()

func _update_player_detection() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as Node3D

	if not player_ref or not is_instance_valid(player_ref):
		if hp_sprite and not is_dead:
			hp_sprite.visible = false
		return

	if GlobalLogic.is_dead:
		player_ref = null
		if hp_sprite and not is_dead:
			hp_sprite.visible = false
		if current_state != State.IDLE and current_state != State.PATROL:
			current_state = State.IDLE
		return

	var dist := global_position.distance_to(player_ref.global_position)
	_update_hp_bar_visibility(dist)

	if current_state == State.WINDUP or current_state == State.STRIKE or current_state == State.RECOVER or current_state == State.HURT:
		return

	if dist <= detection_radius:
		current_state = State.CHASE
	elif dist > lose_interest_radius:
		if current_state == State.CHASE:
			current_state = State.IDLE
			idle_timer = randf_range(min_idle_time, max_idle_time)

func _update_hp_bar_visibility(dist: float) -> void:
	if not hp_sprite or is_dead:
		return
	var in_range: bool = dist <= hp_bar_visible_radius or (current_health < max_health and dist <= lose_interest_radius) or (current_state != State.IDLE and current_state != State.PATROL and dist <= lose_interest_radius)
	var should_show: bool = in_range and _has_line_of_sight()
	if hp_sprite.visible != should_show:
		hp_sprite.visible = should_show

func _has_line_of_sight() -> bool:
	if not is_instance_valid(player_ref) or GlobalLogic.is_dead:
		return false
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return false

	var from_pos := global_position + Vector3(0.0, 0.75, 0.0)
	var to_pos := player_ref.global_position + Vector3(0.0, 0.9, 0.0)

	var exclude_rids: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	for _i in range(5):
		query.exclude = exclude_rids
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			return true
		var col: Object = hit.collider
		if col == player_ref:
			return true
		if col is Node:
			var node := col as Node
			if node.is_in_group("player") or player_ref.is_ancestor_of(node):
				return true
			if node.is_in_group("enemies") or node.is_in_group("drops"):
				exclude_rids.append(hit.rid)
				continue
		return false

	return false

func _process_idle(delta: float) -> void:
	if animation_player and animation_player.current_animation != "idle" and animation_player.has_animation("idle"):
		animation_player.play("idle", 0.15)

	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)

	idle_timer -= delta
	if idle_timer <= 0.0:
		_pick_new_patrol_destination()

func _process_patrol(delta: float) -> void:
	if animation_player and animation_player.current_animation != "walk" and animation_player.has_animation("walk"):
		animation_player.play("walk", 0.15)

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

	if animation_player and animation_player.current_animation != "walk" and animation_player.has_animation("walk"):
		animation_player.play("walk", 0.15)

	var to_player: Vector3 = player_ref.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist <= attack_range and attack_timer <= 0.0 and _has_line_of_sight():
		_start_attack()
		return

	var dir := to_player.normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	_face_direction(dir, delta)

func _start_attack() -> void:
	current_state = State.WINDUP
	state_timer = attack_windup
	velocity.x = 0.0
	velocity.z = 0.0
	_has_hit_in_current_attack = false

	if is_instance_valid(player_ref):
		var to_player: Vector3 = player_ref.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			rotation.y = atan2(to_player.x, to_player.z)

	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle", 0.1)

	if axe_pivot:
		var tw := create_tween()
		tw.tween_property(axe_pivot, "rotation", _axe_raised_rotation, attack_windup).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process_windup(delta: float) -> void:
	if not is_instance_valid(player_ref):
		_cancel_attack()
		return

	var to_player: Vector3 = player_ref.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		_face_direction(to_player.normalized(), delta * 0.8)

	state_timer -= delta
	if state_timer <= 0.0:
		_do_strike()

func _cancel_attack() -> void:
	current_state = State.IDLE
	_has_hit_in_current_attack = false
	if axe_pivot:
		var tw := create_tween()
		tw.tween_property(axe_pivot, "rotation", _axe_rest_rotation, 0.2)

func _do_strike() -> void:
	current_state = State.STRIKE
	state_timer = attack_strike
	attack_timer = attack_cooldown
	_has_hit_in_current_attack = false

	if axe_pivot:
		var tw := create_tween()
		tw.tween_property(axe_pivot, "rotation", _axe_rest_rotation + Vector3(deg_to_rad(75.0), 0.0, 0.0), attack_strike).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	if attack_audio and _cached_swing_stream:
		attack_audio.stream = _cached_swing_stream
		attack_audio.pitch_scale = randf_range(0.92, 1.08)
		attack_audio.play()

	# Imp menghadap ke arah +basis.z, terjang maju ke arah pemain
	var forward: Vector3 = global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.01:
		forward = forward.normalized()
		velocity.x = forward.x * attack_lunge_speed
		velocity.z = forward.z * attack_lunge_speed

	_check_melee_hit()

func _check_melee_hit() -> void:
	if _has_hit_in_current_attack or not is_instance_valid(player_ref) or GlobalLogic.is_dead:
		return

	var to_player: Vector3 = player_ref.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > attack_range + 0.65:
		return

	var forward: Vector3 = global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()

	if to_player.length_squared() > 0.01:
		var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
		if angle > attack_arc_deg * 0.5:
			return

	if not _has_line_of_sight():
		return

	_has_hit_in_current_attack = true

	if player_ref.has_method("take_damage"):
		var kb_dir: Vector3 = to_player.normalized() if to_player.length_squared() > 0.01 else forward
		var kb := kb_dir * knockback_force
		kb.y = knockback_lift
		player_ref.take_damage(axe_damage, kb, true)

func _process_strike(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)

	if not _has_hit_in_current_attack:
		_check_melee_hit()

	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.RECOVER
		state_timer = attack_recover

func _process_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	state_timer -= delta
	if state_timer <= 0.0:
		if axe_pivot:
			var tw := create_tween()
			tw.tween_property(axe_pivot, "rotation", _axe_rest_rotation, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		current_state = State.CHASE

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

	if hp_sprite and not is_dead and _has_line_of_sight():
		hp_sprite.visible = true

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
		_has_hit_in_current_attack = false
		hurt_timer = 0.35
		if axe_pivot:
			var tw := create_tween()
			tw.tween_property(axe_pivot, "rotation", _axe_rest_rotation, 0.18)

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
	if _flash_meshes.is_empty():
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	for mesh_inst in _flash_meshes:
		if is_instance_valid(mesh_inst):
			mesh_inst.set_instance_shader_parameter("hit_flash", 1.0)

	_flash_tween = create_tween()
	_flash_tween.tween_method(func(val: float):
		for mesh_inst in _flash_meshes:
			if is_instance_valid(mesh_inst):
				mesh_inst.set_instance_shader_parameter("hit_flash", val)
	, 1.0, 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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

	var spawn_pos := global_position + Vector3(randf_range(-0.25, 0.25), 1.35, randf_range(-0.25, 0.25))
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

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	for mesh_inst in _flash_meshes:
		if is_instance_valid(mesh_inst):
			mesh_inst.set_instance_shader_parameter("hit_flash", 0.0)

	if hp_sprite:
		hp_sprite.visible = false
	if hp_viewport:
		hp_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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

	drop.item_type = drop_item_type
	drop.item_name_display = drop_item_name
	drop.item_amount = drop_item_amount
	drop.item_color = drop_item_color

	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(drop)
		drop.global_position = global_position + Vector3(0.0, 0.5, 0.0)
		drop.set_drop_color(drop_item_color)
		drop.velocity = Vector3(randf_range(-1.0, 1.0), 3.0, randf_range(-1.0, 1.0))

static func _ensure_cached_audio() -> void:
	if _cached_swing_stream and _cached_hurt_stream:
		return

	var sample_hz := 22050.0

	# 1. Axe swing whoosh
	if not _cached_swing_stream:
		var dur_sw := 0.3
		var samples_s := int(sample_hz * dur_sw)
		var buf_s := PackedByteArray()
		buf_s.resize(samples_s * 2)
		for i in range(samples_s):
			var t := float(i) / sample_hz
			var env := sin((float(i) / float(samples_s)) * PI)
			var freq := lerpf(900.0, 300.0, t / dur_sw)
			var val := int((sin(t * freq * TAU) * 0.5 + (randf() * 2.0 - 1.0) * 0.35) * env * 0.6 * 32767.0)
			buf_s.encode_s16(i * 2, val)
		_cached_swing_stream = AudioStreamWAV.new()
		_cached_swing_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_swing_stream.mix_rate = int(sample_hz)
		_cached_swing_stream.data = buf_s

	# 2. Imp hurt grunt
	if not _cached_hurt_stream:
		var dur_hurt := 0.18
		var samples_ht := int(sample_hz * dur_hurt)
		var buf_ht := PackedByteArray()
		buf_ht.resize(samples_ht * 2)
		for i in range(samples_ht):
			var t := float(i) / sample_hz
			var env := exp(-t * 14.0)
			var val := int(sin(t * 150.0 * TAU) * env * 0.6 * 32767.0)
			buf_ht.encode_s16(i * 2, val)
		_cached_hurt_stream = AudioStreamWAV.new()
		_cached_hurt_stream.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_hurt_stream.mix_rate = int(sample_hz)
		_cached_hurt_stream.data = buf_ht
