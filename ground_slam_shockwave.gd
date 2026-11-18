class_name GroundSlamShockwave
extends Node3D

@onready var radial_dust: CPUParticles3D = $RadialDustRing if has_node("RadialDustRing") else null
@onready var dust_debris: GPUParticles3D = $DustDebris if has_node("DustDebris") else null
@onready var impact_audio: AudioStreamPlayer3D = $ImpactAudio if has_node("ImpactAudio") else null

static var _cached_impact_wav: AudioStreamWAV = null

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_play_procedural_stomp_audio()
	_animate_shockwave()

func _play_procedural_stomp_audio() -> void:
	if not impact_audio:
		return
	if not _cached_impact_wav:
		_cached_impact_wav = _generate_stomp_wav()
	impact_audio.stream = _cached_impact_wav
	impact_audio.play()

static func _generate_stomp_wav() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var duration := 0.28
	var num_samples := int(sample_hz * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples * 2)

	for i in range(num_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 14.0)
		var freq := lerpf(130.0, 35.0, t / duration)
		var val := int((sin(t * freq * TAU) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * env * 0.85 * 32767.0)
		buffer.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	return wav

func _animate_shockwave() -> void:
	if radial_dust:
		radial_dust.restart()
		radial_dust.emitting = true
	if dust_debris:
		dust_debris.restart()
		dust_debris.emitting = true

	var cleanup_tw := create_tween()
	cleanup_tw.tween_interval(0.45)
	cleanup_tw.tween_callback(queue_free)
