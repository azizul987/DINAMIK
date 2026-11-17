extends PanelContainer
class_name AlchemyToast

@onready var toast_icon: TextureRect = $HBox/Icon
@onready var toast_label: Label = $HBox/Label

func pop(potion_name: String, tint: Color, start_pos: Vector2) -> void:
	if toast_label:
		toast_label.text = "+1 %s!" % potion_name.to_upper()
		toast_label.add_theme_color_override("font_color", tint)
	if toast_icon:
		toast_icon.self_modulate = tint

	position = start_pos
	pivot_offset = size * 0.5
	scale = Vector2(0.4, 0.4)
	modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", start_pos.y - 38.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
