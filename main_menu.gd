class_name MainMenu
extends Control

@onready var btn_play: Button = %BtnPlay
@onready var btn_guide: Button = %BtnGuide
@onready var btn_quit: Button = %BtnQuit
@onready var guide_modal: Control = %GuideModal
@onready var btn_close_guide: Button = %BtnCloseGuide

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	guide_modal.visible = false

	btn_play.pressed.connect(_on_play_pressed)
	btn_guide.pressed.connect(_on_guide_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_close_guide.pressed.connect(_on_close_guide_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if guide_modal and guide_modal.visible:
			guide_modal.visible = false
			get_viewport().set_input_as_handled()

func _on_play_pressed() -> void:
	GlobalLogic.reset_game_state()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_guide_pressed() -> void:
	guide_modal.visible = true

func _on_close_guide_pressed() -> void:
	guide_modal.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()
