# camera_pivot.gd
extends Node3D

@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -60.0
@export var max_pitch: float = 40.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
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
			global_rotation.y = lerp_angle(global_rotation.y, target_yaw, 10.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clampf(spring_arm.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
