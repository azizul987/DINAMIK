class_name DashWindEffect
extends Node3D

@onready var wind_ring: MeshInstance3D = $WindRing if has_node("WindRing") else null
@onready var wind_streaks: CPUParticles3D = $WindStreaks if has_node("WindStreaks") else null
@onready var wind_audio: AudioStreamPlayer3D = $WindAudio if has_node("WindAudio") else null

static var _cached_swoosh_stream: AudioStreamWAV = null

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_setup_audio()

func _setup_audio() -> void:
	if not wind_audio:
		return
	if _cached_swoosh_stream == null:
		_cached_swoosh_stream = _generate_wind_swoosh_sound()
	wind_audio.stream = _cached_swoosh_stream

func setup(dash_dir: Vector3) -> void:
	if dash_dir.length_squared() > 0.01:
		var target_look := global_position + dash_dir
		if not global_position.is_equal_approx(target_look):
			look_at(target_look, Vector3.UP)

	_play_audio()
	_animate_ring()
	_trigger_particles()

	var cleanup_tw := create_tween()
	cleanup_tw.tween_interval(0.40)
	cleanup_tw.tween_callback(queue_free)

func _play_audio() -> void:
	if not wind_audio:
		return
	if not wind_audio.stream and _cached_swoosh_stream:
		wind_audio.stream = _cached_swoosh_stream
	if wind_audio.stream:
		wind_audio.pitch_scale = randf_range(0.96, 1.10)
		wind_audio.play()

func _animate_ring() -> void:
	if not wind_ring:
		return

	var ring_mat: StandardMaterial3D = null
	if wind_ring.material_override and wind_ring.material_override is StandardMaterial3D:
		ring_mat = wind_ring.material_override.duplicate() as StandardMaterial3D
	elif wind_ring.mesh and wind_ring.mesh.material and wind_ring.mesh.material is StandardMaterial3D:
		ring_mat = wind_ring.mesh.material.duplicate() as StandardMaterial3D
	else:
		ring_mat = StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color = Color(0.88, 0.96, 1.0, 0.75)

	wind_ring.material_override = ring_mat
	wind_ring.scale = Vector3(0.25, 0.25, 0.25)
	ring_mat.albedo_color.a = 0.75

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wind_ring, "scale", Vector3(2.3, 2.3, 2.3), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _trigger_particles() -> void:
	if wind_streaks:
		wind_streaks.restart()
		wind_streaks.emitting = true

static func _generate_wind_swoosh_sound() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.22
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var progress := t / dur

		# Envelope: fast rise, exponential decay
		var env := sin(progress * PI) * exp(-progress * 2.8)

		# Frequency sweep: rush from high frequency down to deep whoosh
		var freq := 820.0 * (1.0 - progress * 0.65)
		var tonal := sin(t * freq * TAU) * 0.35

		# White noise component representing rushed air
		var noise := (randf() * 2.0 - 1.0) * 0.65

		var sample_val := (tonal + noise) * env * 0.95 * 32767.0
		var val := clampi(int(sample_val), -32768, 32767)
		buffer.encode_s16(i * 2, val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_hz)
	stream.data = buffer
	return stream
