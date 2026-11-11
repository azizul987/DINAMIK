extends CharacterBody3D

@export var walk_speed: float = 4.5
@export var run_speed: float = 7.0
@export var jump_force: float = 7.5
@export var gravity: float = 20.0
@export var air_control: float = 0.3
@export var coyote_time: float = 0.12
@export var base_damage: float = 15.0
@export var attack_cooldown: float = 0.35

var speed_multiplier: float = 1.0
var coyote_timer: float = 0.0
var is_attacking: bool = false
var can_attack: bool = true
var locked_target: Node3D = null
const LOCK_ON_MAX_DISTANCE: float = 18.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var mesh_instance: Node3D = $MeshInstance
@onready var weapon_pivot: Node3D = $MeshInstance/WeaponPivot
@onready var hitbox: Area3D = %Hitbox

func _ready() -> void:
	GlobalLogic.toxicity_stage_changed.connect(_on_toxicity_stage_changed)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

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

	# Validate locked target
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

	if is_on_floor():
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

	# Face locked target or face movement direction
	if locked_target and is_instance_valid(locked_target):
		var to_enemy: Vector3 = locked_target.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.01:
			var target_yaw := atan2(to_enemy.x, to_enemy.z)
			mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, target_yaw, 15.0 * delta)
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

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			toggle_lock_on()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_attack and not GlobalLogic.is_dead:
				attack()

func toggle_lock_on() -> void:
	if locked_target != null:
		locked_target = null
		return
	locked_target = _find_best_target()

func _find_best_target() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_dist: float = LOCK_ON_MAX_DISTANCE

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
		if dist > LOCK_ON_MAX_DISTANCE:
			continue

		to_enemy.y = 0.0
		var dir: Vector3 = to_enemy.normalized()
		var dot: float = cam_forward.dot(dir)
		if dot > 0.0:
			if dist < best_dist:
				best_dist = dist
				best_target = enemy_node

	return best_target

func attack() -> void:
	can_attack = false
	is_attacking = true

	# Snap orientation directly to locked target or camera forward!
	if locked_target and is_instance_valid(locked_target):
		var to_enemy: Vector3 = locked_target.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.01:
			mesh_instance.rotation.y = atan2(to_enemy.x, to_enemy.z)
	else:
		var cam_basis: Basis = camera_pivot.global_transform.basis
		var forward: Vector3 = -cam_basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.01:
			mesh_instance.rotation.y = atan2(forward.x, forward.z)

	var damage := base_damage
	if GlobalLogic.is_berserk_active:
		damage *= 3.0
	elif GlobalLogic.is_strength_active:
		damage *= 2.0

	var tween := create_tween()
	tween.tween_property(weapon_pivot, "rotation:y", deg_to_rad(65.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_pivot, "rotation:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	hitbox.monitoring = true
	var bodies := hitbox.get_overlapping_bodies()
	for b in bodies:
		if b != self and b.has_method("take_damage"):
			var knockback: Vector3 = (b.global_position - global_position).normalized()
			knockback.y = 0.2
			b.take_damage(damage, knockback)

	await get_tree().create_timer(0.15).timeout
	hitbox.monitoring = false
	is_attacking = false

	await get_tree().create_timer(attack_cooldown - 0.15).timeout
	can_attack = true

func _on_hitbox_body_entered(body: Node) -> void:
	if not is_attacking or body == self:
		return
	if body.has_method("take_damage"):
		var damage := base_damage
		if GlobalLogic.is_berserk_active:
			damage *= 3.0
		elif GlobalLogic.is_strength_active:
			damage *= 2.0
		var knockback: Vector3 = (body.global_position - global_position).normalized()
		knockback.y = 0.2
		body.take_damage(damage, knockback)
