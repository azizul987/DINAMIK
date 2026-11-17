extends GPUParticles3D
class_name FootstepDust

func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
	get_tree().create_timer(lifetime + 0.15).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
