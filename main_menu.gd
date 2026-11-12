class_name MainMenu
extends Control

@onready var btn_play: Button = $CenterContainer/MainVBox/MenuCard/Margin/Buttons/BtnPlay
@onready var btn_guide: Button = $CenterContainer/MainVBox/MenuCard/Margin/Buttons/BtnGuide
@onready var btn_quit: Button = $CenterContainer/MainVBox/MenuCard/Margin/Buttons/BtnQuit
@onready var guide_modal: Control = $GuideModal
@onready var btn_close_guide: Button = $GuideModal/Center/Card/Margin/VBox/BtnCloseGuide

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	guide_modal.visible = false

	btn_play.pressed.connect(_on_play_pressed)
	btn_guide.pressed.connect(_on_guide_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_close_guide.pressed.connect(_on_close_guide_pressed)

func _on_play_pressed() -> void:
	GlobalLogic.reset_game_state()
	get_tree().change_scene_to_file("res://main.tscn")

func _on_guide_pressed() -> void:
	guide_modal.visible = true

func _on_close_guide_pressed() -> void:
	guide_modal.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()
