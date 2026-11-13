extends CharacterBody3D

const DASH_GHOST_SCENE: PackedScene = preload("res://dash_ghost.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")

@export_group("Movement")
@export var walk_speed: float = 4.5
@export var run_speed: float = 7.0
@export var jump_force: float = 7.5
@export var gravity: float = 20.0
@export var air_control: float = 0.3
@export var coyote_time: float = 0.12

@export_group("Combat - Attack")
@export var base_damage: float = 15.0
@export var attack_cooldown: float = 0.35
@export var base_knockback_force: float = 9.0
@export var knockback_lift: float = 0.45
@export var strength_damage_multiplier: float = 2.0
@export var berserk_damage_multiplier: float = 3.0
@export var strength_knockback_multiplier: float = 1.25
@export var berserk_knockback_multiplier: float = 1.5
@export var attack_slash_angle_deg: float = 65.0
@export var attack_slash_duration: float = 0.12
@export var attack_recovery_duration: float = 0.15
@export var attack_lunge_speed: float = 4.2
@export var attack_lunge_duration: float = 0.08

@export_group("Combat - Defense & Recoil")
@export var invulnerability_duration: float = 0.6
@export var received_knockback_duration: float = 0.25
@export var received_knockback_damping: float = 9.0
@export var hit_trauma_shake: float = 0.55
@export var hit_flash_duration: float = 0.08
@export var hit_blink_interval: float = 0.06

@export_group("Combat - Dash")
@export var dash_speed: float = 16.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.5
@export var dash_ghost_interval: float = 0.045
@export var dash_ghost_color: Color = Color(0.65, 0.08, 0.12, 0.55)

@export_group("Target Lock-On")
@export var lock_on_max_distance: float = 18.0
@export var lock_on_turn_speed: float = 15.0

@export_group("Targeting - Auto Aim Assist")
@export var auto_target_enabled: bool = true
@export var auto_target_radius: float = 4.2
@export var auto_target_cone_deg: float = 130.0
@export var auto_target_point_blank_radius: float = 1.8

var speed_multiplier: float = 1.0
var coyote_timer: float = 0.0
var is_attacking: bool = false
var can_attack: bool = true
var locked_target: Node3D = null

var is_invulnerable: bool = false
var knockback_timer: float = 0.0
var _hit_targets_this_swing: Array[Node] = []
var lunge_timer: float = 0.0
var lunge_direction: Vector3 = Vector3.ZERO

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_ghost_timer: float = 0.0

var slash_arc_mat: StandardMaterial3D = null
var flash_material: StandardMaterial3D = null
var dash_material: StandardMaterial3D = null
var _hit_blink_tween: Tween = null

@onready var camera_pivot: Node3D = $CameraPivot
@onready var mesh_instance: MeshInstance3D = $MeshInstance
@onready var weapon_pivot: Node3D = $MeshInstance/WeaponPivot
@onready var hitbox: Area3D = %Hitbox
@onready var slash_arc: MeshInstance3D = %SlashArc if has_node("%SlashArc") else null
@onready var deflect_audio: AudioStreamPlayer = $DeflectAudio if has_node("DeflectAudio") else null

func _ready() -> void:
	add_to_group("player")
	GlobalLogic.toxicity_stage_changed.connect(_on_toxicity_stage_changed)
	GlobalLogic.player_died.connect(_on_player_died)
	GlobalLogic.potion_consumed.connect(_on_potion_consumed)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_setup_slash_arc()
	_setup_flash_material()
	_setup_dash_material()
	_setup_deflect_audio()

func _setup_dash_material() -> void:
	dash_material = StandardMaterial3D.new()
	dash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dash_material.albedo_color = Color(dash_ghost_color.r, dash_ghost_color.g, dash_ghost_color.b, 0.85)

func _setup_deflect_audio() -> void:
	if not deflect_audio and has_node("DeflectAudio"):
		deflect_audio = $DeflectAudio as AudioStreamPlayer
	if deflect_audio and not deflect_audio.stream:
		var sample_hz := 22050.0
		var dur := 0.25
		var total_samples := int(sample_hz * dur)
		var buffer := PackedByteArray()
		buffer.resize(total_samples * 2)

		for i in range(total_samples):
			var t := float(i) / sample_hz
			var env := exp(-t * 20.0)
			var val := int((sin(t * 1100.0 * TAU) * 0.5 + sin(t * 1650.0 * TAU) * 0.3 + sin(t * 2750.0 * TAU) * 0.2) * env * 0.55 * 32767.0)
			buffer.encode_s16(i * 2, val)

		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_hz)
		wav.data = buffer
		deflect_audio.stream = wav

func _setup_slash_arc() -> void:
	if not slash_arc and weapon_pivot:
		slash_arc = weapon_pivot.get_node_or_null("SlashArc") as MeshInstance3D
	if slash_arc:
		if slash_arc.material_override:
			slash_arc_mat = slash_arc.material_override as StandardMaterial3D
		elif slash_arc.mesh and slash_arc.mesh.material:
			slash_arc_mat = slash_arc.mesh.material as StandardMaterial3D
		else:
			slash_arc_mat = StandardMaterial3D.new()
			slash_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			slash_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			slash_arc.material_override = slash_arc_mat

func _trigger_slash_arc() -> void:
	if not slash_arc or not slash_arc_mat:
		return
	slash_arc.visible = true
	var arc_color := Color(1.0, 0.25, 0.2, 0.85) if GlobalLogic.is_berserk_active else (Color(1.0, 0.8, 0.2, 0.85) if GlobalLogic.is_strength_active else Color(1.0, 1.0, 1.0, 0.85))
	slash_arc_mat.albedo_color = arc_color
	slash_arc.scale = Vector3(0.8, 0.04, 0.8)

	var tw := create_tween()
	tw.tween_property(slash_arc, "scale", Vector3(1.3, 0.04, 1.3), attack_slash_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(slash_arc_mat, "albedo_color:a", 0.0, attack_slash_duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(slash_arc):
			slash_arc.visible = false
	)

func _on_toxicity_stage_changed(stage: GlobalLogic.ToxicityStage) -> void:
	match stage:
		GlobalLogic.ToxicityStage.SAFE, GlobalLogic.ToxicityStage.MODERATE:
			speed_multiplier = 1.0
		GlobalLogic.ToxicityStage.HIGH:
			speed_multiplier = 0.65
		GlobalLogic.ToxicityStage.OVERDOSE:
			speed_multiplier = 0.40

func _physics_process(delta: float) -> void:
	if GlobalLogic.is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if locked_target != null:
		if not is_instance_valid(locked_target) or locked_target.get("is_dead") == true or global_position.distance_to(locked_target.global_position) > 22.0:
			locked_target = null

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and coyote_timer > 0.0:
		velocity.y = jump_force
		coyote_timer = 0.0

	var is_sprinting := Input.is_key_pressed(KEY_SHIFT)
	var base_speed := run_speed if is_sprinting else walk_speed
	var target_speed := base_speed * speed_multiplier

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := _get_camera_relative_direction(input_dir)

	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		dash_ghost_timer -= delta
		if dash_ghost_timer <= 0.0:
			dash_ghost_timer = dash_ghost_interval
			_spawn_ghost_trail()
		if dash_timer <= 0.0:
			is_dashing = false
			is_invulnerable = false
			mesh_instance.rotation.x = 0.0
			mesh_instance.scale = Vector3.ONE
			if mesh_instance.material_override == dash_material:
				mesh_instance.material_override = null
	elif lunge_timer > 0.0:
		lunge_timer -= delta
		velocity.x = lunge_direction.x * attack_lunge_speed
		velocity.z = lunge_direction.z * attack_lunge_speed
	elif knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = move_toward(velocity.x, direction.x * target_speed, received_knockback_damping * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, received_knockback_damping * delta)
	elif is_on_floor():
		if direction:
			velocity.x = direction.x * target_speed
			velocity.z = direction.z * target_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, target_speed)
			velocity.z = move_toward(velocity.z, 0.0, target_speed)
	else:
		var target_vel_x := direction.x * target_speed
		var target_vel_z := direction.z * target_speed
		velocity.x = lerpf(velocity.x, target_vel_x, air_control)
		velocity.z = lerpf(velocity.z, target_vel_z, air_control)

	if locked_target and is_instance_valid(locked_target):
		var to_enemy: Vector3 = locked_target.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.01:
			var target_yaw := atan2(to_enemy.x, to_enemy.z)
			mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, target_yaw, lock_on_turn_speed * delta)
	elif direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, target_angle, 12.0 * delta)

	move_and_slide()

func _get_camera_relative_direction(input: Vector2) -> Vector3:
	var cam_basis := camera_pivot.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (forward * -input.y + right * input.x).normalized()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.keycode == KEY_TAB:
			toggle_lock_on()
		elif event.keycode == KEY_SHIFT:
			dash()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			toggle_lock_on()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_attack and not GlobalLogic.is_dead:
				attack()

func dash() -> void:
	if is_dashing or dash_cooldown_timer > 0.0 or GlobalLogic.is_dead:
		return

	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	is_invulnerable = true
	dash_ghost_timer = 0.0

	if not dash_material:
		_setup_dash_material()
	dash_material.albedo_color = Color(dash_ghost_color.r, dash_ghost_color.g, dash_ghost_color.b, 0.85)
	mesh_instance.material_override = dash_material

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_dir := _get_camera_relative_direction(input_dir)

	var target_candidate: Node3D = locked_target if (locked_target and is_instance_valid(locked_target)) else _find_soft_target()
	if target_candidate and is_instance_valid(target_candidate):
		var to_enemy: Vector3 = target_candidate.global_position - global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		if input_dir.length_squared() > 0.1:
			dash_direction = move_dir
		elif dist > 1.2:
			dash_direction = to_enemy.normalized()
		else:
			dash_direction = -to_enemy.normalized()

		if dash_direction.length_squared() > 0.01:
			mesh_instance.rotation.y = atan2(dash_direction.x, dash_direction.z)
	elif move_dir.length_squared() > 0.01:
		dash_direction = move_dir
		mesh_instance.rotation.y = atan2(dash_direction.x, dash_direction.z)
	else:
		dash_direction = Vector3(sin(mesh_instance.rotation.y), 0.0, cos(mesh_instance.rotation.y)).normalized()

	var tw := create_tween()
	mesh_instance.scale = Vector3(1.25, 0.50, 1.50)
	mesh_instance.rotation.x = deg_to_rad(24.0)

	tw.set_parallel(true)
	tw.tween_property(mesh_instance, "scale", Vector3.ONE, dash_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mesh_instance, "rotation:x", 0.0, dash_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if camera_pivot and camera_pivot.has_method("fov_punch"):
		camera_pivot.fov_punch(-4.5, dash_duration + 0.10)

	_spawn_ghost_trail()

func _spawn_ghost_trail() -> void:
	if not is_inside_tree() or not DASH_GHOST_SCENE:
		return

	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if not parent_node:
		return

	var ghost := DASH_GHOST_SCENE.instantiate() as DashGhost
	if not ghost:
		return

	parent_node.add_child(ghost)
	ghost.global_position = mesh_instance.global_position
	ghost.global_rotation = mesh_instance.global_rotation
	ghost.scale = mesh_instance.scale
	ghost.start_fade(dash_ghost_color)

func toggle_lock_on() -> void:
	if locked_target != null:
		locked_target = null
		return
	locked_target = _find_best_target()

func _find_best_target() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_dist: float = lock_on_max_distance

	var cam_basis: Basis = camera_pivot.global_transform.basis
	var cam_forward: Vector3 = -cam_basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()

	for enemy in enemies:
		var enemy_node := enemy as Node3D
		if not enemy_node or not is_instance_valid(enemy_node):
			continue
		if enemy_node.get("is_dead") == true or not enemy_node.visible:
			continue

		var to_enemy: Vector3 = enemy_node.global_position - global_position
		var dist: float = to_enemy.length()
		if dist > lock_on_max_distance:
			continue

		to_enemy.y = 0.0
		var dir: Vector3 = to_enemy.normalized()
		var dot: float = cam_forward.dot(dir)
		if dot > 0.0:
			if dist < best_dist:
				best_dist = dist
				best_target = enemy_node

	return best_target

func _find_soft_target() -> Node3D:
	if not auto_target_enabled:
		return null

	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_score: float = -9999.0

	var cam_basis: Basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	for enemy in enemies:
		var enemy_node := enemy as Node3D
		if not enemy_node or not is_instance_valid(enemy_node):
			continue
		if enemy_node.get("is_dead") == true or not enemy_node.visible:
			continue

		var to_enemy: Vector3 = enemy_node.global_position - global_position
		to_enemy.y = 0.0
		var dist: float = to_enemy.length()
		if dist > auto_target_radius or dist < 0.01:
			continue

		var dir: Vector3 = to_enemy.normalized()
		var dot: float = forward.dot(dir)

		if dist <= auto_target_point_blank_radius:
			var score: float = 100.0 - dist * 10.0
			if score > best_score:
				best_score = score
				best_target = enemy_node
		elif dot >= cos(deg_to_rad(auto_target_cone_deg * 0.5)):
			var score: float = (dot * 2.0) - (dist / auto_target_radius)
			if score > best_score:
				best_score = score
				best_target = enemy_node

	return best_target

func attack() -> void:
	can_attack = false
	is_attacking = true
	_hit_targets_this_swing.clear()

	var target_to_face: Node3D = locked_target if (locked_target and is_instance_valid(locked_target)) else _find_soft_target()

	if target_to_face and is_instance_valid(target_to_face):
		var to_enemy: Vector3 = target_to_face.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.01:
			mesh_instance.rotation.y = atan2(to_enemy.x, to_enemy.z)
	else:
		var cam_basis: Basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
		var forward: Vector3 = -cam_basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.01:
			mesh_instance.rotation.y = atan2(forward.x, forward.z)

	var damage := base_damage
	if GlobalLogic.is_berserk_active:
		damage *= berserk_damage_multiplier
	elif GlobalLogic.is_strength_active:
		damage *= strength_damage_multiplier

	lunge_direction = Vector3(sin(mesh_instance.rotation.y), 0.0, cos(mesh_instance.rotation.y)).normalized()
	lunge_timer = attack_lunge_duration
	_trigger_slash_arc()

	var tween := create_tween()
	tween.tween_property(weapon_pivot, "rotation:y", deg_to_rad(attack_slash_angle_deg), attack_slash_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_pivot, "rotation:y", 0.0, attack_recovery_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	hitbox.monitoring = true
	var bodies := hitbox.get_overlapping_bodies()
	for b in bodies:
		if b != self and b.has_method("take_damage"):
			_apply_hit_to_target(b)

	await get_tree().create_timer(attack_slash_duration).timeout
	hitbox.monitoring = false
	is_attacking = false

	await get_tree().create_timer(maxf(0.01, attack_cooldown - attack_slash_duration)).timeout
	can_attack = true

func _apply_hit_to_target(target: Node) -> void:
	if not target or target == self or not target.has_method("take_damage"):
		return
	if _hit_targets_this_swing.has(target):
		return
	_hit_targets_this_swing.append(target)

	var damage := base_damage
	var kb_force: float = base_knockback_force
	if GlobalLogic.is_berserk_active:
		damage *= berserk_damage_multiplier
		kb_force *= berserk_knockback_multiplier
	elif GlobalLogic.is_strength_active:
		damage *= strength_damage_multiplier
		kb_force *= strength_knockback_multiplier

	var to_body: Vector3 = target.global_position - global_position
	to_body.y = 0.0
	var knockback_dir: Vector3 = to_body.normalized() if to_body.length_squared() > 0.01 else -global_transform.basis.z
	knockback_dir.y = knockback_lift
	knockback_dir = knockback_dir.normalized()

	target.take_damage(damage, knockback_dir * kb_force)

	GlobalLogic.hit_stop(0.05, 0.05)
	if camera_pivot:
		var is_buffed: bool = GlobalLogic.is_berserk_active or GlobalLogic.is_strength_active
		var trauma_val: float = 0.65 if is_buffed else 0.42
		var punch_val: float = 2.4 if is_buffed else 1.5
		if camera_pivot.has_method("add_trauma"):
			camera_pivot.add_trauma(trauma_val)
		if camera_pivot.has_method("fov_punch"):
			camera_pivot.fov_punch(punch_val)

func _on_hitbox_body_entered(body: Node) -> void:
	if not is_attacking or body == self:
		return
	_apply_hit_to_target(body)

func _setup_flash_material() -> void:
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

func _on_player_died() -> void:
	if _hit_blink_tween:
		_hit_blink_tween.kill()
	if is_instance_valid(mesh_instance):
		mesh_instance.material_override = null
		mesh_instance.visible = true

func _trigger_hit_feedback() -> void:
	if not mesh_instance or not flash_material:
		return

	if _hit_blink_tween:
		_hit_blink_tween.kill()

	flash_material.albedo_color = Color(1.0, 0.2, 0.2, 0.95)
	mesh_instance.material_override = flash_material
	mesh_instance.visible = true

	_hit_blink_tween = create_tween()
	_hit_blink_tween.tween_interval(hit_flash_duration)
	_hit_blink_tween.tween_callback(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.material_override = null
	)

	var remaining_time: float = maxf(0.0, invulnerability_duration - hit_flash_duration)
	var cycles: int = int(remaining_time / (hit_blink_interval * 2.0))
	for i in range(cycles):
		_hit_blink_tween.tween_callback(func():
			if is_instance_valid(mesh_instance):
				mesh_instance.visible = false
		)
		_hit_blink_tween.tween_interval(hit_blink_interval)
		_hit_blink_tween.tween_callback(func():
			if is_instance_valid(mesh_instance):
				mesh_instance.visible = true
		)
		_hit_blink_tween.tween_interval(hit_blink_interval)

	_hit_blink_tween.tween_callback(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.visible = true
			mesh_instance.material_override = null
		is_invulnerable = false
	)

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, is_sharp: bool = false) -> void:
	if is_invulnerable or GlobalLogic.is_dead:
		return

	if is_sharp and GlobalLogic.is_ironskin_active:
		_trigger_ironskin_deflection()
		return

	is_invulnerable = true
	GlobalLogic.modify_hp(-amount)
	_spawn_player_floating_text("-%d" % roundi(amount), Color(1.0, 0.22, 0.25, 1.0), 38, 0.85, 0.6)

	if knockback.length_squared() > 0.01:
		velocity = knockback
		knockback_timer = received_knockback_duration

	var tween := create_tween()
	mesh_instance.scale = Vector3(0.8, 1.25, 0.8)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if camera_pivot:
		if camera_pivot.has_method("add_trauma"):
			camera_pivot.add_trauma(hit_trauma_shake)
		if camera_pivot.has_method("fov_punch"):
			camera_pivot.fov_punch(2.0)

	_trigger_hit_feedback()

func _on_potion_consumed(potion_name: String) -> void:
	match potion_name:
		"healing":
			_spawn_player_floating_text("+35 HP", Color(0.35, 1.0, 0.5, 1.0), 32, 0.75, 0.6)
			await get_tree().create_timer(0.08).timeout
			_spawn_player_floating_text("+15 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.95, 0.6)
		"strength":
			_spawn_player_floating_text("+20 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.85, 0.6)
		"slow":
			_spawn_player_floating_text("+15 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.85, 0.6)
		"berserk":
			_spawn_player_floating_text("+35 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.85, 0.6)
		"ironskin":
			_spawn_player_floating_text("+20 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.85, 0.6)
	_trigger_potion_mesh_flash()

func _trigger_potion_mesh_flash() -> void:
	if not mesh_instance or not flash_material:
		return
	flash_material.albedo_color = Color(0.25, 1.0, 0.5, 0.85)
	mesh_instance.material_override = flash_material
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		if is_instance_valid(mesh_instance) and not is_invulnerable:
			mesh_instance.material_override = null
	)

func _spawn_player_floating_text(display_text: String, text_color: Color, size: int = 32, rise: float = 0.85, duration: float = 0.6) -> void:
	if not FLOATING_TEXT_SCENE or not is_inside_tree():
		return
	var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
	if not label:
		return
	get_tree().root.add_child(label)
	var spawn_pos := global_position + Vector3(randf_range(-0.15, 0.15), 1.2, randf_range(-0.15, 0.15))
	label.global_position = spawn_pos
	label.pop(display_text, text_color, size, rise, duration)

func _trigger_ironskin_deflection() -> void:
	if deflect_audio:
		deflect_audio.play()

	if FLOATING_TEXT_SCENE:
		var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
		if label:
			get_tree().root.add_child(label)
			label.global_position = global_position + Vector3(0.0, 1.2, 0.0)
			label.pop("DEFLECTED!", Color(0.92, 0.94, 0.98, 1.0), 28, 0.85, 0.55)

	if camera_pivot and camera_pivot.has_method("add_trauma"):
		camera_pivot.add_trauma(0.18)
