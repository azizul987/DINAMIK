class_name DashGhost
extends Node3D

@export var fade_duration: float = 0.28

@onready var skeleton: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
var _ghost_meshes: Array[MeshInstance3D] = []
var _ghost_material: StandardMaterial3D = null

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_collect_meshes()

func _collect_meshes() -> void:
	_ghost_meshes.clear()
	for child in find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi:
			_ghost_meshes.append(mi)

func copy_skeleton_pose(source_skeleton: Skeleton3D) -> void:
	if not source_skeleton:
		return
	if not skeleton:
		skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		return

	var count := mini(source_skeleton.get_bone_count(), skeleton.get_bone_count())
	for b in range(count):
		skeleton.set_bone_pose_position(b, source_skeleton.get_bone_pose_position(b))
		skeleton.set_bone_pose_rotation(b, source_skeleton.get_bone_pose_rotation(b))
		skeleton.set_bone_pose_scale(b, source_skeleton.get_bone_pose_scale(b))

func start_fade(ghost_color: Color = Color(0.85, 0.95, 1.0, 0.45), source_skeleton: Skeleton3D = null) -> void:
	if source_skeleton:
		copy_skeleton_pose(source_skeleton)

	if _ghost_meshes.is_empty():
		_collect_meshes()

	_ghost_material = StandardMaterial3D.new()
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = ghost_color

	for mi in _ghost_meshes:
		mi.material_override = _ghost_material

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_ghost_material, "albedo_color:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "scale", scale * 1.08, fade_duration).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(queue_free)
