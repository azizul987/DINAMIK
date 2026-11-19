class_name BossAltar
extends StaticBody3D

signal prop_damaged(current_hp: float, max_hp: float)
signal prop_destroyed()
signal boss_spawned(boss: Node3D)

const ITEM_DROP_SCENE: PackedScene = preload("res://item_drop.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")

@export_group("Durability")
@export var max_health: float = 30.0

@export_group("Boss Spawn")
@export var boss_scene: PackedScene = preload("res://boss_mage.tscn")
@export var spawn_delay: float = 0.9
@export var spawn_offset: Vector3 = Vector3(0.0, 0.6, 2.5)
@export var spawn_announce_text: String = "BOS TERBANGKIT"

@export_group("Loot Drops")
@export var drops_loot: bool = true
@export var drop_item_type: String = "fire_essence"
@export var drop_item_amount: int = 1
@export var drop_item_color: Color = Color(0.95, 0.45, 0.12, 1.0)

@export_group("Audio")
@export var hit_sound_enabled: bool = true

var current_health: float = 30.0
var is_destroyed: bool = false
var _initial_scale: Vector3 = Vector3.ONE
var _wobble_tween: Tween = null

static var _cached_hit_stream: AudioStreamWAV = null

@onready var visual_root: Node3D = $VisualRoot if has_node("VisualRoot") else self
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio if has_node("HitAudio") else null

func _ready() -> void:
	current_health = max_health
	_initial_scale = scale
	add_to_group("destructible_props")
	_setup_audio()

func _setup_audio() -> void:
	if not hit_audio:
		return
	if _cached_hit_stream == null:
		_cached_hit_stream = _generate_hit_sound()
	hit_audio.stream = _cached_hit_stream

static func _generate_hit_sound() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.16
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 30.0)
		var thud := sin(t * 150.0 * TAU) * 0.6
		var ring := sin(t * 1180.0 * TAU) * 0.4
		var val := clampi(int((thud + ring) * env * 32767.0), -32768, 32767)
		buffer.encode_s16(i * 2, val)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_hz)
	stream.data = buffer
	return stream

func take_damage(amount: float, _knockback: Vector3 = Vector3.ZERO, _is_sharp: bool = false) -> void:
	if is_destroyed:
		return

	current_health -= amount
	prop_damaged.emit(current_health, max_health)
	_play_hit_feedback()

	if hit_audio and hit_sound_enabled and hit_audio.stream:
		hit_audio.pitch_scale = randf_range(0.9, 1.15)
		hit_audio.play()

	if current_health <= 0.0:
		destroy_prop()

func _play_hit_feedback() -> void:
	if _wobble_tween and _wobble_tween.is_valid():
		_wobble_tween.kill()

	_wobble_tween = create_tween()
	_wobble_tween.tween_property(self, "scale", _initial_scale * Vector3(1.12, 0.88, 1.12), 0.05).set_trans(Tween.TRANS_QUAD)
	_wobble_tween.tween_property(self, "scale", _initial_scale, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func destroy_prop() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	prop_destroyed.emit()

	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if drops_loot:
		_spawn_loot()

	# Sembunyikan visual altar saat hancur
	if visual_root:
		visual_root.visible = false

	# Mulai memunculkan bos setelah jeda
	if spawn_delay > 0.0:
		await get_tree().create_timer(spawn_delay).timeout
	if boss_scene and is_inside_tree():
		_spawn_boss()

	queue_free()

func _spawn_boss() -> void:
	var boss := boss_scene.instantiate() as Node3D
	if not boss:
		return
	var parent_node := get_parent() if get_parent() else get_tree().current_scene
	if not parent_node:
		boss.queue_free()
		return
	parent_node.add_child(boss)
	boss.global_position = global_position + spawn_offset
	boss_spawned.emit(boss)

	if not spawn_announce_text.is_empty():
		_announce_boss_spawn()

func _announce_boss_spawn() -> void:
	if not FLOATING_TEXT_SCENE:
		return
	var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
	if not label:
		return
	var root := get_tree().current_scene
	if not root:
		return
	root.add_child(label)
	label.global_position = global_position + spawn_offset + Vector3(0.0, 2.2, 0.0)
	label.pop(spawn_announce_text, Color(1.0, 0.35, 0.3, 1.0), 46, 1.1, 1.2)

func _spawn_loot() -> void:
	if not ITEM_DROP_SCENE:
		return
	var drop := ITEM_DROP_SCENE.instantiate() as ItemDrop3D
	if not drop:
		return
	drop.item_type = drop_item_type
	drop.item_amount = drop_item_amount
	drop.item_color = drop_item_color
	var parent_node := get_parent() if get_parent() else get_tree().current_scene
	if parent_node:
		parent_node.add_child(drop)
		drop.global_position = global_position + Vector3(0.0, 0.5, 0.0)
		drop.set_drop_color(drop_item_color)
