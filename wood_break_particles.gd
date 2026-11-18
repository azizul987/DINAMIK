extends Node3D

@onready var particles: CPUParticles3D = $Particles if has_node("Particles") else null
@onready var audio: AudioStreamPlayer3D = $Audio if has_node("Audio") else null

static var _cached_break_stream: AudioStreamWAV = null

func _ready() -> void:
	_setup_audio()
	if particles:
		particles.restart()
		particles.emitting = true
	if audio and audio.stream:
		audio.play()

	var tw := create_tween()
	tw.tween_interval(0.65)
	tw.tween_callback(queue_free)

func _setup_audio() -> void:
	if not audio:
		return
	if _cached_break_stream == null:
		_cached_break_stream = _generate_wood_break_sound()
	audio.stream = _cached_break_stream

static func _generate_wood_break_sound() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.28
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 22.0)
		var noise := (randf() * 2.0 - 1.0)
		var thud := sin(t * 110.0 * TAU) * exp(-t * 30.0)
		var crack := sin(t * 420.0 * TAU) * exp(-t * 18.0) * 0.4
		var sample_val := (noise * 0.5 + thud * 0.35 + crack * 0.15) * env * 32767.0
		var val := clampi(int(sample_val), -32768, 32767)
		buffer.encode_s16(i * 2, val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_hz)
	stream.data = buffer
	return stream
