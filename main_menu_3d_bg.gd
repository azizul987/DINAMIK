class_name MainMenu3DBG
extends Node3D

@export_group("Camera Sway")
@export var enable_camera_sway: bool = true
@export var sway_speed: float = 0.35
@export var sway_yaw_deg: float = 3.0
@export var sway_pitch_deg: float = 1.0

@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera: Camera3D = %Camera3D
@onready var props: Node3D = %Props

var _time: float = 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if not enable_camera_sway or not camera_pivot:
		return
	
	_time += delta
	camera_pivot.rotation.y = sin(_time * sway_speed) * deg_to_rad(sway_yaw_deg)
	camera_pivot.rotation.x = sin(_time * sway_speed * 0.7) * deg_to_rad(sway_pitch_deg)
