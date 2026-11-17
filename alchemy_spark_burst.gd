extends CPUParticles2D
class_name AlchemySparkBurst

func pop(pos: Vector2, burst_color: Color) -> void:
	global_position = pos
	color = burst_color
	emitting = true
	finished.connect(queue_free)
	get_tree().create_timer(lifetime + 0.15).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
