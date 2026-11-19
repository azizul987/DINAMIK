extends StaticBody3D
class_name DestructibleProp

signal prop_damaged(current_hp: float, max_hp: float)
signal prop_destroyed()

const ITEM_DROP_SCENE: PackedScene = preload("res://item_drop.tscn")
const BREAK_PARTICLES_SCENE: PackedScene = preload("res://wood_break_particles.tscn")

@export_group("Durability")
@export var max_health: float = 20.0
@export var destroy_on_zero_hp: bool = true

@export_group("Loot Drops")
@export var drops_loot: bool = true
@export var drop_item_type: String = "goblin_ear"
@export var drop_item_amount: int = 1
@export var drop_item_color: Color = Color(0.95, 0.35, 0.15, 1.0)
@export var additional_drops: Array[Dictionary] = []

@export_group("Audio")
@export var hit_sound_enabled: bool = true
@export var break_sound_enabled: bool = true
@export_enum("wood", "ceramic", "metal") var prop_material: String = "wood"

var current_health: float = 20.0
var is_destroyed: bool = false
var _initial_scale: Vector3 = Vector3.ONE
var _wobble_tween: Tween = null

static var _cached_wood_hit_stream: AudioStreamWAV = null
static var _cached_ceramic_hit_stream: AudioStreamWAV = null
static var _cached_metal_hit_stream: AudioStreamWAV = null

@onready var visual_root: Node3D = $VisualRoot if has_node("VisualRoot") else self
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio if has_node("HitAudio") else null

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	collision_layer = 1
	collision_mask = 0
	current_health = max_health
	_initial_scale = scale
	add_to_group("destructible_props")
	_auto_detect_material()
	_setup_audio()

func _auto_detect_material() -> void:
	if prop_material != "wood":
		return
	var lower_name: String = name.to_lower()
	var lower_file: String = scene_file_path.to_lower()
	if lower_name.contains("jar") or lower_name.contains("pot") or lower_file.contains("jar") or lower_file.contains("pot"):
		prop_material = "ceramic"
	elif lower_name.contains("chest") or lower_file.contains("chest"):
		prop_material = "metal"

func _setup_audio() -> void:
	if not hit_audio:
		return
	match prop_material:
		"ceramic":
			if _cached_ceramic_hit_stream == null:
				_cached_ceramic_hit_stream = _generate_ceramic_hit_sound()
			hit_audio.stream = _cached_ceramic_hit_stream
		"metal":
			if _cached_metal_hit_stream == null:
				_cached_metal_hit_stream = _generate_metal_hit_sound()
			hit_audio.stream = _cached_metal_hit_stream
		_:
			if _cached_wood_hit_stream == null:
				_cached_wood_hit_stream = _generate_wood_hit_sound()
			hit_audio.stream = _cached_wood_hit_stream

static func _generate_wood_hit_sound() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.14
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 36.0)
		var thud := sin(t * 140.0 * TAU)
		var knock := sin(t * 320.0 * TAU) * 0.4
		var sample_val := (thud * 0.7 + knock * 0.3) * env * 32767.0
		var val := clampi(int(sample_val), -32768, 32767)
		buffer.encode_s16(i * 2, val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_hz)
	stream.data = buffer
	return stream

static func _generate_ceramic_hit_sound() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.10
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 42.0)
		var ping1 := sin(t * 980.0 * TAU) * 0.6
		var ping2 := sin(t * 2240.0 * TAU) * 0.4
		var sample_val := (ping1 + ping2) * env * 32767.0
		var val := clampi(int(sample_val), -32768, 32767)
		buffer.encode_s16(i * 2, val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_hz)
	stream.data = buffer
	return stream

static func _generate_metal_hit_sound() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.16
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 24.0)
		var strike := sin(t * 680.0 * TAU) * 0.55
		var overtone := sin(t * 1420.0 * TAU) * 0.35
		var sample_val := (strike + overtone) * env * 32767.0
		var val := clampi(int(sample_val), -32768, 32767)
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

	if current_health <= 0.0 and destroy_on_zero_hp:
		destroy_prop()

func _play_hit_feedback() -> void:
	if _wobble_tween and _wobble_tween.is_valid():
		_wobble_tween.kill()

	_wobble_tween = create_tween()
	_wobble_tween.tween_property(self, "scale", _initial_scale * Vector3(1.15, 0.85, 1.15), 0.05).set_trans(Tween.TRANS_QUAD)
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

	_spawn_break_particles()
	if drops_loot:
		_spawn_loot_drops()

	visible = false
	await get_tree().create_timer(0.35).timeout
	queue_free()

func _spawn_break_particles() -> void:
	if not BREAK_PARTICLES_SCENE:
		return
	var part = BREAK_PARTICLES_SCENE.instantiate() as Node3D
	if part:
		var parent_scene = get_parent() if get_parent() else get_tree().current_scene
		if parent_scene:
			parent_scene.add_child(part)
			part.global_position = global_position + Vector3(0.0, 0.35, 0.0)
			if part.has_method("setup_material"):
				part.setup_material(prop_material)

func _spawn_loot_drops() -> void:
	_spawn_single_drop(drop_item_type, drop_item_amount, drop_item_color)
	for extra in additional_drops:
		var e_type: String = str(extra.get("type", "slime_gel"))
		var e_amt: int = int(extra.get("amount", 1))
		var e_col: Color = extra.get("color", Color.WHITE)
		_spawn_single_drop(e_type, e_amt, e_col)

func _spawn_single_drop(item_type: String, amount: int, color: Color) -> void:
	if not ITEM_DROP_SCENE:
		return
	var drop = ITEM_DROP_SCENE.instantiate() as ItemDrop3D
	if drop:
		drop.item_type = item_type
		drop.item_amount = amount
		drop.item_color = color
		var parent_scene = get_parent() if get_parent() else get_tree().current_scene
		if parent_scene:
			parent_scene.add_child(drop)
			drop.global_position = global_position + Vector3(randf_range(-0.25, 0.25), 0.5, randf_range(-0.25, 0.25))
			drop.set_drop_color(color)
