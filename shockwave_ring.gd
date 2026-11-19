class_name ShockwaveRing
extends Node3D

signal wave_finished()

@export_group("Stats")
@export var expansion_speed: float = 7.8
@export var max_radius: float = 14.0
@export var damage: float = 15.0
@export var ring_height: float = 0.35

@onready var ring_mesh: MeshInstance3D = $RingMesh if has_node("RingMesh") else null
@onready var hit_area: Area3D = $HitArea if has_node("HitArea") else null
@onready var collision_shape: CollisionShape3D = $HitArea/CollisionShape3D if has_node("HitArea/CollisionShape3D") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null

var current_radius: float = 0.6
var _hit_players: Array[Node] = []
var _cylinder_shape: CylinderShape3D = null

static var _cached_expand_wav: AudioStreamWAV = null

func _ready() -> void:
	if collision_shape and collision_shape.shape is CylinderShape3D:
		_cylinder_shape = collision_shape.shape as CylinderShape3D
	_ensure_cached_audio()
	_play_sfx(_cached_expand_wav, 0.9)
	_update_scale()

func _physics_process(delta: float) -> void:
	current_radius += expansion_speed * delta
	if current_radius >= max_radius:
		set_physics_process(false)
		_fade_and_free()
		return

	_update_scale()

func _update_scale() -> void:
	if ring_mesh:
		ring_mesh.scale = Vector3(current_radius, 1.0, current_radius)
	if _cylinder_shape:
		_cylinder_shape.radius = current_radius

func _on_hit_area_body_entered(body: Node3D) -> void:
	if _hit_players.has(body):
		return

	var is_player: bool = body.is_in_group("player") or body.name == "Players"
	if not is_player:
		return

	# Cek apakah pemain melompat (tidak menyentuh lantai)
	var on_floor: bool = true
	if "is_on_floor" in body:
		on_floor = body.is_on_floor()

	if on_floor:
		_hit_players.append(body)
		if body.has_method("take_damage"):
			var kb_dir: Vector3 = (body.global_position - global_position).normalized()
			kb_dir.y = 0.0
			var kb: Vector3 = kb_dir * 4.5
			kb.y = 5.5
			body.take_damage(damage, kb, false)

func _fade_and_free() -> void:
	wave_finished.emit()
	if ring_mesh:
		var tw := create_tween()
		tw.tween_property(ring_mesh, "scale:y", 0.0, 0.2)
		tw.tween_callback(queue_free)
	else:
		queue_free()

func _play_sfx(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if not audio_player or not stream:
		return
	audio_player.stream = stream
	audio_player.pitch_scale = pitch
	audio_player.play()

static func _ensure_cached_audio() -> void:
	if not _cached_expand_wav:
		_cached_expand_wav = _generate_tone_wav(22050, 0.45, 95.0, 45.0, 0.5)

static func _generate_tone_wav(sample_hz: int, duration: float, start_freq: float, end_freq: float, noise_mix: float) -> AudioStreamWAV:
	var num_samples: int = int(float(sample_hz) * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples * 2)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_hz)
		var progress: float = t / duration
		var freq: float = lerpf(start_freq, end_freq, progress)
		var env: float = exp(-t * 5.0) * (1.0 - progress)
		var sine_val: float = sin(t * freq * TAU)
		var noise_val: float = randf() * 2.0 - 1.0
		var mixed: float = (sine_val * (1.0 - noise_mix) + noise_val * noise_mix) * env * 0.85
		var sample_val: int = int(clampf(mixed, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, sample_val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_hz
	wav.data = buffer
	return wav
