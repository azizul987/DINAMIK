class_name MagicOrbProjectile
extends Area3D

signal hit_target(target: Node3D, point: Vector3)

@export_group("Stats")
@export var speed: float = 14.0
@export var slow_speed_multiplier: float = 0.42
@export var damage: float = 14.0
@export var knockback_force: float = 6.0
@export var max_lifetime: float = 4.0
@export var is_sharp: bool = true

@onready var visual_node: Node3D = $VisualNode if has_node("VisualNode") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var trail_particles: CPUParticles3D = $TrailParticles if has_node("TrailParticles") else null
@onready var impact_particles: CPUParticles3D = $ImpactParticles if has_node("ImpactParticles") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null

var shooter: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var is_spent: bool = false
var lifetime_timer: float = 0.0

static var _cached_orb_hum: AudioStreamWAV = null
static var _cached_orb_impact: AudioStreamWAV = null

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_ensure_cached_audio()
	_play_sfx(_cached_orb_hum, 0.95)

func init_shot(from_shooter: Node3D, target_position: Vector3, custom_speed: float = -1.0) -> void:
	shooter = from_shooter
	if custom_speed > 0.0:
		speed = custom_speed

	var origin: Vector3 = global_position if is_inside_tree() else position
	direction = (target_position - origin).normalized()
	if direction.length_squared() < 0.001:
		direction = -from_shooter.global_transform.basis.z if from_shooter else Vector3.FORWARD

	if is_inside_tree():
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	if is_spent:
		return

	lifetime_timer += delta
	if lifetime_timer >= max_lifetime:
		queue_free()
		return

	var current_speed: float = speed
	if GlobalLogic.is_potion_active("slow"):
		current_speed *= slow_speed_multiplier

	velocity = direction * current_speed
	global_position += velocity * delta

func _on_body_entered(body: Node3D) -> void:
	if is_spent or body == shooter:
		return

	var is_player: bool = body.is_in_group("player") or body.name == "Players"
	if is_player:
		_hit_player(body)
	else:
		_hit_surface(body)

func _hit_player(player_body: Node3D) -> void:
	is_spent = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var to_player: Vector3 = (player_body.global_position - global_position).normalized()
	var knockback: Vector3 = to_player * knockback_force
	knockback.y = 1.2

	if player_body.has_method("take_damage"):
		player_body.take_damage(damage, knockback, is_sharp)

	_trigger_impact_effects()
	hit_target.emit(player_body, global_position)

	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(queue_free)

func _hit_surface(surface: Node3D) -> void:
	is_spent = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	_trigger_impact_effects()
	hit_target.emit(surface, global_position)

	if trail_particles:
		trail_particles.emitting = false

	var tween := create_tween()
	if visual_node:
		tween.tween_property(visual_node, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.2)
	tween.tween_callback(queue_free)

func _trigger_impact_effects() -> void:
	_play_sfx(_cached_orb_impact, 1.1)
	if impact_particles:
		impact_particles.restart()
		impact_particles.emitting = true

func _play_sfx(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if not audio_player or not stream:
		return
	audio_player.stream = stream
	audio_player.pitch_scale = pitch
	audio_player.play()

static func _ensure_cached_audio() -> void:
	if not _cached_orb_hum:
		_cached_orb_hum = _generate_tone_wav(22050, 0.22, 280.0, 140.0, 0.5)
	if not _cached_orb_impact:
		_cached_orb_impact = _generate_tone_wav(22050, 0.25, 420.0, 90.0, 0.75)

static func _generate_tone_wav(sample_hz: int, duration: float, start_freq: float, end_freq: float, noise_mix: float) -> AudioStreamWAV:
	var num_samples: int = int(float(sample_hz) * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples * 2)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_hz)
		var progress: float = t / duration
		var freq: float = lerpf(start_freq, end_freq, progress)
		var env: float = exp(-t * 8.0) * (1.0 - progress)
		var sine_val: float = sin(t * freq * TAU)
		var noise_val: float = randf() * 2.0 - 1.0
		var mixed: float = (sine_val * (1.0 - noise_mix) + noise_val * noise_mix) * env * 0.75
		var sample_val: int = int(clampf(mixed, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, sample_val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_hz
	wav.data = buffer
	return wav
