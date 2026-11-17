extends Node3D
class_name GroundSlamShockwave

@onready var shockwave_ring: MeshInstance3D = $ShockwaveRing
@onready var dust_debris: GPUParticles3D = $DustDebris
@onready var impact_audio: AudioStreamPlayer3D = $ImpactAudio

static var _cached_impact_wav: AudioStreamWAV = null

func _ready() -> void:
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
	if dust_debris:
		dust_debris.emitting = true

	if shockwave_ring and shockwave_ring.material_override:
		var base_mat := shockwave_ring.material_override as StandardMaterial3D
		if base_mat:
			var mat := base_mat.duplicate() as StandardMaterial3D
			shockwave_ring.material_override = mat
			mat.albedo_color = Color(1.0, 0.82, 0.45, 0.85)
			shockwave_ring.scale = Vector3(0.3, 0.04, 0.3)
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(shockwave_ring, "scale", Vector3(3.2, 0.04, 3.2), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(mat, "albedo_color:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	get_tree().create_timer(0.48).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
