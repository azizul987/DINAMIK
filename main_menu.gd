class_name MainMenu
extends Control

@onready var btn_continue: Button = %BtnContinue
@onready var btn_play: Button = %BtnPlay
@onready var btn_guide: Button = %BtnGuide
@onready var btn_quit: Button = %BtnQuit
@onready var guide_modal: Control = %GuideModal
@onready var btn_close_guide: Button = %BtnCloseGuide

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	guide_modal.visible = false
	GlobalLogic.play_bgm(GlobalLogic.BGM_MENU_PATH, "menu", 1.2, -7.0)

	_update_continue_button_state()

	btn_continue.pressed.connect(_on_continue_pressed)
	btn_continue.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_play.pressed.connect(_on_play_pressed)
	btn_play.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_guide.pressed.connect(_on_guide_pressed)
	btn_guide.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_quit.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_close_guide.pressed.connect(_on_close_guide_pressed)
	btn_close_guide.mouse_entered.connect(GlobalLogic.play_ui_hover)

func _update_continue_button_state() -> void:
	if btn_continue:
		var has_save := GlobalLogic.has_save_file()
		btn_continue.disabled = not has_save
		btn_continue.modulate.a = 1.0 if has_save else 0.45

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if guide_modal and guide_modal.visible:
			GlobalLogic.play_ui_click()
			guide_modal.visible = false
			get_viewport().set_input_as_handled()

func _on_continue_pressed() -> void:
	if GlobalLogic.has_save_file():
		GlobalLogic.play_ui_click()
		GlobalLogic.load_game()

func _on_play_pressed() -> void:
	GlobalLogic.play_ui_click()
	GlobalLogic.reset_game_state()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_guide_pressed() -> void:
	GlobalLogic.play_ui_click()
	guide_modal.visible = true

func _on_close_guide_pressed() -> void:
	GlobalLogic.play_ui_click()
	guide_modal.visible = false

func _on_quit_pressed() -> void:
	GlobalLogic.play_ui_click()
	get_tree().quit()
