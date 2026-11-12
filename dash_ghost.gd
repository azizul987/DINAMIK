class_name DashGhost
extends MeshInstance3D

@export var fade_duration: float = 0.28

func start_fade(ghost_color: Color = Color(0.2, 0.9, 0.5, 0.45)) -> void:
	if material_override and material_override is StandardMaterial3D:
		material_override = material_override.duplicate()
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material_override = mat

	var mat = material_override as StandardMaterial3D
	mat.albedo_color = ghost_color
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "scale", scale * 1.12, fade_duration).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(queue_free)
