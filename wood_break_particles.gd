extends Node3D

@onready var particles: CPUParticles3D = $Particles if has_node("Particles") else null
@onready var audio: AudioStreamPlayer3D = $Audio if has_node("Audio") else null

static var _cached_wood_break: AudioStreamWAV = null
static var _cached_ceramic_break: AudioStreamWAV = null
static var _cached_metal_break: AudioStreamWAV = null

var current_material: String = "wood"

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

func setup_material(mat_type: String) -> void:
	current_material = mat_type
	if particles:
		match mat_type:
			"ceramic":
				particles.color = Color(0.85, 0.72, 0.58, 1.0)
				particles.scale_amount_min = 0.5
				particles.scale_amount_max = 1.1
			"metal":
				particles.color = Color(0.72, 0.75, 0.80, 1.0)
				particles.scale_amount_min = 0.6
				particles.scale_amount_max = 1.3
			_:
				particles.color = Color(0.55, 0.35, 0.18, 1.0)
	_setup_audio()
	if audio and audio.stream and not audio.playing:
		audio.play()

func _setup_audio() -> void:
	if not audio:
		return
	match current_material:
		"ceramic":
			if _cached_ceramic_break == null:
				_cached_ceramic_break = _generate_ceramic_break_sound()
			audio.stream = _cached_ceramic_break
		"metal":
			if _cached_metal_break == null:
				_cached_metal_break = _generate_metal_break_sound()
			audio.stream = _cached_metal_break
		_:
			if _cached_wood_break == null:
				_cached_wood_break = _generate_wood_break_sound()
			audio.stream = _cached_wood_break

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

static func _generate_ceramic_break_sound() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.26
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 26.0)
		var noise := (randf() * 2.0 - 1.0) * exp(-t * 32.0) * 0.55
		var ping1 := sin(t * 2100.0 * TAU) * 0.45 * exp(-t * 38.0)
		var ping2 := sin(t * 3600.0 * TAU) * 0.35 * exp(-t * 44.0)
		var sample_val := (noise + ping1 + ping2) * env * 32767.0
		var val := clampi(int(sample_val), -32768, 32767)
		buffer.encode_s16(i * 2, val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_hz)
	stream.data = buffer
	return stream

static func _generate_metal_break_sound() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.32
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 16.0)
		var clang := sin(t * 340.0 * TAU) * 0.5 * exp(-t * 20.0)
		var overtone := sin(t * 880.0 * TAU) * 0.35 * exp(-t * 24.0)
		var lock_snap := sin(t * 1450.0 * TAU) * 0.3 * exp(-t * 35.0)
		var sample_val := (clang + overtone + lock_snap) * env * 32767.0
		var val := clampi(int(sample_val), -32768, 32767)
		buffer.encode_s16(i * 2, val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_hz)
	stream.data = buffer
	return stream
