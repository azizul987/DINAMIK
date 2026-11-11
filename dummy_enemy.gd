# dummy_enemy.gd
extends CharacterBody3D

@export var max_health: float = 30.0
@export var respawn_time: float = 3.0

var current_health: float = 30.0
var is_dead: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	current_health -= amount
	velocity += knockback * 3.0

	var tween := create_tween()
	mesh.scale = Vector3(1.3, 0.7, 1.3)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if current_health <= 0.0:
		die()

func die() -> void:
	is_dead = true
	var global = get_node_or_null("/root/GlobalLogic")
	if global:
		global.add_material("slime_gel", 1)

	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	collision_shape.disabled = true

	await get_tree().create_timer(respawn_time).timeout
	respawn()

func respawn() -> void:
	current_health = max_health
	is_dead = false
	visible = true
	collision_shape.disabled = false
	mesh.scale = Vector3.ONE
