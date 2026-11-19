extends CanvasLayer

## Layar akhir permainan: dipakai untuk kondisi "Kamu Mati" dan kondisi menang.

@onready var dim: ColorRect = $Dim
@onready var title: Label = $Center/VBox/Title
@onready var subtitle: Label = $Center/VBox/Subtitle
@onready var button_box: VBoxContainer = %ButtonBox
@onready var btn_main_menu: Button = %BtnMainMenu
@onready var btn_restart: Button = %BtnRestart

var _is_shown: bool = false
var _is_victory: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if dim:
		dim.color = Color(0, 0, 0, 0)
	if button_box:
		button_box.modulate.a = 0.0

	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu_pressed)
		btn_main_menu.mouse_entered.connect(GlobalLogic.play_ui_hover)
	if btn_restart:
		btn_restart.pressed.connect(_on_restart_pressed)
		btn_restart.mouse_entered.connect(GlobalLogic.play_ui_hover)

## Menampilkan layar akhir dengan judul, warna tema, dan subjudul opsional.
func show_end(title_text: String, color: Color, subtitle_text: String = "") -> void:
	if _is_shown:
		return
	_is_shown = true
	_is_victory = title_text.to_lower().contains("menang") or title_text.to_lower().contains("win")

	if title:
		title.text = title_text
		title.add_theme_color_override("font_color", color)

	if subtitle:
		var clean_sub := subtitle_text.strip_edges()
		if clean_sub.is_empty():
			subtitle.visible = false
		else:
			subtitle.visible = true
			subtitle.text = clean_sub
			subtitle.add_theme_color_override("font_color", color.lightened(0.35))

	if btn_restart:
		btn_restart.text = "Main Lagi" if _is_victory else "Coba Lagi"
	if btn_main_menu:
		btn_main_menu.text = "Ke Main Menu"

	visible = true

	# Pastikan kursor mouse terlihat untuk memilih tombol
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

	if dim:
		var tw := create_tween()
		tw.tween_property(dim, "color:a", 0.85, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if title:
		title.modulate.a = 0.0
		title.pivot_offset = title.size * 0.5
		title.scale = Vector2(0.65, 0.65)
		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(title, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_property(title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if subtitle and subtitle.visible:
		subtitle.modulate.a = 0.0
		var tw3 := create_tween()
		tw3.tween_interval(0.3)
		tw3.tween_property(subtitle, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if button_box:
		button_box.modulate.a = 0.0
		var tw4 := create_tween()
		tw4.tween_interval(0.4)
		tw4.tween_property(button_box, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_main_menu_pressed() -> void:
	GlobalLogic.play_ui_click()
	get_tree().paused = false
	GlobalLogic.reset_game_state()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_restart_pressed() -> void:
	GlobalLogic.play_ui_click()
	get_tree().paused = false
	GlobalLogic.reset_game_state()
	if _is_victory:
		get_tree().change_scene_to_file("res://main_menu.tscn")
	else:
		get_tree().reload_current_scene()
