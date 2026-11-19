class_name SafeRoom
extends Node3D

func _ready() -> void:
	# Pulihkan darah penuh dan netralkan racun di area aman
	GlobalLogic.reset_safe_zone()
	GlobalLogic.complete_tutorial()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Auto-save progres saat pemain berhasil tiba di safe room
	GlobalLogic.save_game()
