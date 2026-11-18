extends Node3D

@export_group("Mouse Controls")
@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -60.0
@export var max_pitch: float = 40.0
@export var default_pitch: float = -12.0

@export_group("Zelda Z-Targeting Camera")
@export var z_target_enabled: bool = true
@export var lock_on_lerp_speed: float = 8.5
@export var snap_speed: float = 14.0
@export var default_distance: float = 3.5
@export var lock_on_min_distance: float = 3.2
@export var lock_on_max_distance: float = 5.2
@export var lock_on_shoulder_offset: float = 0.38
@export var auto_trail_delay: float = 1.2
@export var auto_trail_speed: float = 2.0

@export_group("Camera Trauma & Shake")
@export var trauma_decay: float = 1.8
@export var max_shake_offset: Vector2 = Vector2(0.5, 0.4)
@export var max_shake_roll: float = 0.08

var trauma: float = 0.0
var _noise_timer: float = 0.0
var base_fov: float = 75.0

var _is_snapping: bool = false
var _snap_target_yaw: float = 0.0
var _time_since_last_mouse: float = 0.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func fov_punch(amount: float = 1.6, duration: float = 0.12) -> void:
	if not camera:
		return
	var tw := create_tween()
	camera.fov = base_fov - amount
	tw.tween_property(camera, "fov", base_fov, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Memicu snap kamera instan/halus ke belakang punggung karakter (Zelda Z-Reset / Center Camera).
func snap_behind_player(player_yaw: float) -> void:
	_is_snapping = true
	_snap_target_yaw = wrapf(player_yaw - PI, -PI, PI)
	if spring_arm:
		var tw := create_tween()
		tw.tween_property(spring_arm, "rotation:x", deg_to_rad(default_pitch), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		base_fov = camera.fov
	var parent_body := get_parent()
	if parent_body is CollisionObject3D:
		spring_arm.add_excluded_object(parent_body.get_rid())

func _process(delta: float) -> void:
	_time_since_last_mouse += delta
	var parent_node := get_parent()
	var locked_target: Node3D = null
	if parent_node and "locked_target" in parent_node and parent_node.locked_target and is_instance_valid(parent_node.locked_target):
		locked_target = parent_node.locked_target as Node3D

	# 1. Zelda Z-Targeting Mode (Saat mengunci musuh)
	if locked_target and z_target_enabled:
		_is_snapping = false
		var to_target: Vector3 = locked_target.global_position - global_position
		var dist := to_target.length()
		to_target.y = 0.0

		if to_target.length_squared() > 0.01:
			var target_yaw := atan2(-to_target.x, -to_target.z)
			global_rotation.y = lerp_angle(global_rotation.y, target_yaw, lock_on_lerp_speed * delta)

		var height_diff := (locked_target.global_position.y + 0.6) - global_position.y
		var desired_pitch := clampf(atan2(height_diff, maxf(2.0, dist)) - deg_to_rad(10.0), deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		spring_arm.rotation.x = lerp_angle(spring_arm.rotation.x, desired_pitch, lock_on_lerp_speed * 0.7 * delta)

		var desired_dist := clampf(dist * 0.45 + 2.0, lock_on_min_distance, lock_on_max_distance)
		spring_arm.spring_length = move_toward(spring_arm.spring_length, desired_dist, delta * 4.0)

		if camera:
			camera.h_offset = move_toward(camera.h_offset, lock_on_shoulder_offset, delta * 2.0)

	# 2. Zelda Z-Snap / Camera Reset Mode (Snap ke belakang punggung karakter)
	elif _is_snapping:
		global_rotation.y = lerp_angle(global_rotation.y, _snap_target_yaw, snap_speed * delta)
		if absf(angle_difference(global_rotation.y, _snap_target_yaw)) < deg_to_rad(2.0):
			_is_snapping = false

	# 3. Free Exploration Mode (Normal)
	else:
		spring_arm.spring_length = move_toward(spring_arm.spring_length, default_distance, delta * 3.0)
		if camera:
			camera.h_offset = move_toward(camera.h_offset, 0.0, delta * 2.5)

		if parent_node and "velocity" in parent_node:
			var vel: Vector3 = parent_node.velocity
			vel.y = 0.0
			if vel.length() > 2.0 and _time_since_last_mouse > auto_trail_delay:
				var move_yaw := atan2(-vel.x, -vel.z)
				global_rotation.y = lerp_angle(global_rotation.y, move_yaw, auto_trail_speed * delta)

	# 4. Trauma Screen Shake
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		var shake := trauma * trauma
		_noise_timer += delta * 45.0
		if camera:
			camera.h_offset += max_shake_offset.x * shake * sin(_noise_timer * 1.7)
			camera.v_offset = max_shake_offset.y * shake * sin(_noise_timer * 2.3)
			camera.rotation.z = max_shake_roll * shake * sin(_noise_timer * 1.1)
	else:
		if camera:
			camera.v_offset = 0.0
			camera.rotation.z = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_time_since_last_mouse = 0.0
		var parent_node := get_parent()
		var is_locked := parent_node and "locked_target" in parent_node and parent_node.locked_target != null
		if is_locked and absf(event.relative.x) > 36.0:
			parent_node.locked_target = null
			is_locked = false

		var sens := mouse_sensitivity * (0.25 if is_locked else 1.0)

		if not is_locked:
			rotate_y(-event.relative.x * sens)
		spring_arm.rotate_x(-event.relative.y * sens)
		spring_arm.rotation.x = clampf(spring_arm.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
