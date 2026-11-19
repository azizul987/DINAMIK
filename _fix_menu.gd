extends Node

const SCENE := "res://main_menu_3d_bg.tscn"

func _ready() -> void:
	var packed: PackedScene = load(SCENE)
	var root: Node = packed.instantiate()

	var cl := root.get_node_or_null("room/CanvasLayer")
	print("[B] CanvasLayer found = ", cl != null)
	if cl:
		var parent := cl.get_parent()
		parent.remove_child(cl)
		cl.free()

	var out := PackedScene.new()
	print("[B] pack err = ", out.pack(root))
	print("[B] save err = ", ResourceSaver.save(out, SCENE))
	root.free()
	get_tree().quit()