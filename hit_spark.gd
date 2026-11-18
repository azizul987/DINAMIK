extends Node3D

@onready var spark_particles: CPUParticles3D = $SparkParticles if has_node("SparkParticles") else null
@onready var flash_mesh: MeshInstance3D = $FlashMesh if has_node("FlashMesh") else null

var _flash_mat: StandardMaterial3D = null

func _ready() -> void:
	if flash_mesh and flash_mesh.material_override:
		_flash_mat = flash_mesh.material_override.duplicate() as StandardMaterial3D
		flash_mesh.material_override = _flash_mat

func setup(spark_color: Color = Color(0.85, 0.95, 1.0, 1.0), slash_dir: Vector3 = Vector3.ZERO) -> void:
	if not is_node_ready():
		await ready

	if spark_particles:
		spark_particles.color = spark_color
		if slash_dir.length_squared() > 0.01:
			spark_particles.direction = (slash_dir.normalized() + Vector3(0.0, 0.35, 0.0)).normalized()
		spark_particles.restart()
		spark_particles.emitting = true

	if flash_mesh and _flash_mat:
		_flash_mat.albedo_color = Color(spark_color.r, spark_color.g, spark_color.b, 0.95)
		flash_mesh.scale = Vector3(0.3, 0.3, 0.3)
		flash_mesh.visible = true

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(flash_mesh, "scale", Vector3(1.4, 1.4, 1.4), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_flash_mat, "albedo_color:a", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var cleanup_tw := create_tween()
	cleanup_tw.tween_interval(0.28)
	cleanup_tw.tween_callback(queue_free)
