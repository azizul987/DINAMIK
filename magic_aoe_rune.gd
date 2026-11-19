class_name MagicAoeRune
extends Node3D

signal detonated(pos: Vector3)

@export_group("Stats")
@export var telegraph_duration: float = 1.2
@export var damage: float = 18.0
@export var knockback_lift: float = 6.0

@onready var rune_ring: MeshInstance3D = $RuneRing if has_node("RuneRing") else null
@onready var pillar_mesh: MeshInstance3D = $PillarMesh if has_node("PillarMesh") else null
@onready var hit_area: Area3D = $HitArea if has_node("HitArea") else null
@onready var burst_particles: CPUParticles3D = $BurstParticles if has_node("BurstParticles") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null

var _is_detonated: bool = false
var _charge_timer: float = 0.0

static var _cached_charge_wav: AudioStreamWAV = null
static var _cached_burst_wav: AudioStreamWAV = null

func _ready() -> void:
	if pillar_mesh:
		pillar_mesh.visible = false
	if hit_area:
		hit_area.monitoring = false
	_ensure_cached_audio()
	_play_sfx(_cached_charge_wav, 1.0)
	_animate_telegraph()

func _animate_telegraph() -> void:
	if not rune_ring:
		return
	rune_ring.scale = Vector3(0.1, 1.0, 0.1)
	var tw := create_tween()
	tw.tween_property(rune_ring, "scale", Vector3(1.0, 1.0, 1.0), telegraph_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_detonate)

func _detonate() -> void:
	if _is_detonated:
		return
	_is_detonated = true

	_play_sfx(_cached_burst_wav, 1.05)

	if rune_ring:
		rune_ring.visible = false

	if pillar_mesh:
		pillar_mesh.visible = true
		pillar_mesh.scale = Vector3(0.6, 0.1, 0.6)
		var p_tw := create_tween()
		p_tw.tween_property(pillar_mesh, "scale", Vector3(1.2, 1.0, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		p_tw.tween_property(pillar_mesh, "scale:y", 0.0, 0.2).set_ease(Tween.EASE_IN)

	if burst_particles:
		burst_particles.restart()
		burst_particles.emitting = true

	if hit_area:
		hit_area.monitoring = true
		var bodies := hit_area.get_overlapping_bodies()
		for b in bodies:
			_check_and_damage_body(b)

	detonated.emit(global_position)

	var cleanup_tw := create_tween()
	cleanup_tw.tween_interval(0.35)
	cleanup_tw.tween_callback(queue_free)

func _check_and_damage_body(b: Node) -> void:
	if b.is_in_group("player") or b.name == "Players":
		if b.has_method("take_damage"):
			var kb := Vector3(randf_range(-1.0, 1.0), knockback_lift, randf_range(-1.0, 1.0)).normalized() * 5.0
			kb.y = knockback_lift
			b.take_damage(damage, kb, false)

func _on_hit_area_body_entered(body: Node3D) -> void:
	if _is_detonated:
		_check_and_damage_body(body)

func _play_sfx(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if not audio_player or not stream:
		return
	audio_player.stream = stream
	audio_player.pitch_scale = pitch
	audio_player.play()

static func _ensure_cached_audio() -> void:
	if not _cached_charge_wav:
		_cached_charge_wav = _generate_tone_wav(22050, 0.35, 120.0, 480.0, 0.25)
	if not _cached_burst_wav:
		_cached_burst_wav = _generate_tone_wav(22050, 0.3, 380.0, 60.0, 0.6)

static func _generate_tone_wav(sample_hz: int, duration: float, start_freq: float, end_freq: float, noise_mix: float) -> AudioStreamWAV:
	var num_samples: int = int(float(sample_hz) * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples * 2)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_hz)
		var progress: float = t / duration
		var freq: float = lerpf(start_freq, end_freq, progress)
		var env: float = exp(-t * 7.0) * (1.0 - progress)
		var sine_val: float = sin(t * freq * TAU)
		var noise_val: float = randf() * 2.0 - 1.0
		var mixed: float = (sine_val * (1.0 - noise_mix) + noise_val * noise_mix) * env * 0.8
		var sample_val: int = int(clampf(mixed, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, sample_val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_hz
	wav.data = buffer
	return wav
