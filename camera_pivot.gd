extends Node3D

@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -60.0
@export var max_pitch: float = 40.0
@export var trauma_decay: float = 1.8
@export var max_shake_offset: Vector2 = Vector2(0.5, 0.4)
@export var max_shake_roll: float = 0.08
@export var lock_on_lerp_speed: float = 10.0

var trauma: float = 0.0
var _noise_timer: float = 0.0
var base_fov: float = 75.0

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

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		base_fov = camera.fov
	var parent_body := get_parent()
	if parent_body is CollisionObject3D:
		spring_arm.add_excluded_object(parent_body.get_rid())

func _process(delta: float) -> void:
	var parent_node := get_parent()
	if parent_node and "locked_target" in parent_node and parent_node.locked_target and is_instance_valid(parent_node.locked_target):
		var to_target: Vector3 = parent_node.locked_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			var target_yaw := atan2(-to_target.x, -to_target.z)
			global_rotation.y = lerp_angle(global_rotation.y, target_yaw, lock_on_lerp_speed * delta)

	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		var shake := trauma * trauma
		_noise_timer += delta * 45.0
		if camera:
			camera.h_offset = max_shake_offset.x * shake * sin(_noise_timer * 1.7)
			camera.v_offset = max_shake_offset.y * shake * sin(_noise_timer * 2.3)
			camera.rotation.z = max_shake_roll * shake * sin(_noise_timer * 1.1)
	else:
		if camera:
			camera.h_offset = 0.0
			camera.v_offset = 0.0
			camera.rotation.z = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clampf(spring_arm.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
