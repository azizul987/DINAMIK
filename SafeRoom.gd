class_name SafeRoom
extends Node3D

@onready var next_level_portal: Portal = find_child("NextLevelPortal", true, false) as Portal

func _ready() -> void:
	# Pulihkan darah penuh dan netralkan racun di area aman
	GlobalLogic.reset_safe_zone()
	GlobalLogic.complete_tutorial()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_next_level_portal()
	# Auto-save progres saat pemain berhasil tiba di safe room
	GlobalLogic.save_game()

## Mengarahkan portal safe room ke scene level sesuai lantai saat ini.
func _setup_next_level_portal() -> void:
	if not next_level_portal:
		next_level_portal = find_child("NextLevelPortal", true, false) as Portal
	if not next_level_portal:
		return
	next_level_portal.target_scene_path = GlobalLogic.get_current_level_scene()
	next_level_portal.portal_id = "safe_room_next_level"
	next_level_portal.advance_floor = false
	next_level_portal.display_label = GlobalLogic.get_level_display_name(GlobalLogic.current_floor)
	next_level_portal.portal_color = Color(0.15, 0.75, 1.0, 1.0)
