class_name PauseMenu
extends Control

@onready var btn_resume: Button = %BtnResume
@onready var btn_save: Button = %BtnSave
@onready var btn_restart: Button = %BtnRestart
@onready var btn_main_menu: Button = %BtnMainMenu
@onready var menu_card: PanelContainer = %MenuCard
@onready var dark_overlay: ColorRect = %DarkOverlay
@onready var save_toast: Label = %SaveToast

var is_paused: bool = false
var _toast_tween: Tween = null

func _ready() -> void:
	visible = false
	if save_toast:
		save_toast.visible = false
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_resume.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_save.pressed.connect(_on_save_pressed)
	btn_save.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_restart.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_main_menu.mouse_entered.connect(GlobalLogic.play_ui_hover)

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
	if save_toast:
		save_toast.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GlobalLogic.play_ui_switch()
	GlobalLogic.duck_bgm(true)

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
	if save_toast:
		save_toast.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GlobalLogic.duck_bgm(false)

func _on_resume_pressed() -> void:
	GlobalLogic.play_ui_click()
	resume()

func _on_save_pressed() -> void:
	GlobalLogic.play_ui_click()
	var success := GlobalLogic.save_game()
	if success:
		_show_save_toast("Permainan Berhasil Disimpan!")
	else:
		_show_save_toast("Gagal Menyimpan Permainan!")

func _show_save_toast(msg: String) -> void:
	if not save_toast:
		return
	save_toast.text = msg
	save_toast.visible = true
	save_toast.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(save_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func():
		if is_instance_valid(save_toast):
			save_toast.visible = false
	)

func _on_restart_pressed() -> void:
	GlobalLogic.play_ui_click()
	resume()
	GlobalLogic.reset_game_state()
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	GlobalLogic.play_ui_click()
	resume()
	GlobalLogic.reset_game_state()
	get_tree().change_scene_to_file("res://main_menu.tscn")
