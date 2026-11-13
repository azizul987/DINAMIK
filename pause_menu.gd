class_name PauseMenu
extends Control

@onready var btn_resume: Button = %BtnResume
@onready var btn_restart: Button = %BtnRestart
@onready var btn_main_menu: Button = %BtnMainMenu
@onready var btn_quit: Button = %BtnQuit
@onready var menu_card: PanelContainer = %MenuCard
@onready var dark_overlay: ColorRect = %DarkOverlay

var is_paused: bool = false

func _ready() -> void:
	visible = false
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		var hud := get_tree().root.find_child("Control", true, false)
		if hud:
			var crafting := hud.get_node_or_null("CraftingPanel")
			if crafting and crafting.visible and not is_paused:
				return
		if is_paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()

func pause() -> void:
	is_paused = true
	get_tree().paused = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	dark_overlay.modulate.a = 0.0
	menu_card.scale = Vector2(0.92, 0.92)
	menu_card.pivot_offset = menu_card.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dark_overlay, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(menu_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func resume() -> void:
	is_paused = false
	get_tree().paused = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	resume()
	GlobalLogic.reset_game_state()
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	resume()
	GlobalLogic.reset_game_state()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
