class_name FloatingText
extends Label3D

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true

func pop(display_text: String, text_color: Color = Color.WHITE, size: int = 32, rise: float = 0.85, duration: float = 0.55) -> void:
	text = display_text
	modulate = text_color
	font_size = size
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:y", global_position.y + rise, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
