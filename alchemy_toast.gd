extends PanelContainer
class_name AlchemyToast

const POTION_TEXTURES: Dictionary = {
	"healing": preload("res://resources/pixel_resources_pack/static/085_health_potion.png"),
	"strength": preload("res://resources/pixel_resources_pack/static/092_elixir.png"),
	"slow": preload("res://resources/pixel_resources_pack/static/086_mana_potion.png"),
	"berserk": preload("res://resources/pixel_resources_pack/static/091_poison.png"),
	"ironskin": preload("res://resources/pixel_resources_pack/static/089_oil_flask.png"),
}

@onready var toast_icon: TextureRect = $HBox/Icon
@onready var toast_label: Label = $HBox/Label

func _ensure_nodes() -> void:
	if not toast_icon:
		toast_icon = get_node_or_null("HBox/Icon")
	if not toast_label:
		toast_label = get_node_or_null("HBox/Label")

func pop(potion_name: String, tint: Color, start_pos: Vector2) -> void:
	_ensure_nodes()
	if toast_label:
		toast_label.text = "+1 %s!" % potion_name.to_upper()
		toast_label.add_theme_color_override("font_color", tint)
	if toast_icon:
		var p_key := potion_name.to_lower()
		if POTION_TEXTURES.has(p_key):
			toast_icon.texture = POTION_TEXTURES[p_key]
			toast_icon.self_modulate = Color.WHITE
		else:
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
