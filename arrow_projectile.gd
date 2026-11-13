class_name ArrowProjectile
extends Area3D

signal hit_target(target: Node3D, point: Vector3)

@export_group("Stats")
@export var speed: float = 17.0
@export var damage: float = 12.0
@export var knockback_force: float = 5.5
@export var max_lifetime: float = 4.5
@export var gravity_influence: float = 1.8

@onready var visual_node: Node3D = $VisualNode if has_node("VisualNode") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var trail_particles: CPUParticles3D = $TrailParticles if has_node("TrailParticles") else null
@onready var impact_particles: CPUParticles3D = $ImpactParticles if has_node("ImpactParticles") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null

var shooter: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var is_stuck: bool = false
var lifetime_timer: float = 0.0

static var _cached_whoosh: AudioStreamWAV = null
static var _cached_hit: AudioStreamWAV = null

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_ensure_cached_audio()
	_play_sfx(_cached_whoosh, 0.95)

func init_shot(from_shooter: Node3D, target_position: Vector3, custom_speed: float = -1.0) -> void:
	shooter = from_shooter
	if custom_speed > 0.0:
		speed = custom_speed

	var origin: Vector3 = global_position if is_inside_tree() else position
	var dir: Vector3 = (target_position - origin).normalized()
	velocity = dir * speed
	if dir.length_squared() > 0.001 and is_inside_tree():
		look_at(global_position + dir, Vector3.UP)

func _physics_process(delta: float) -> void:
	if is_stuck:
		return

	lifetime_timer += delta
	if lifetime_timer >= max_lifetime:
		queue_free()
		return

	velocity.y -= gravity_influence * delta
	global_position += velocity * delta

	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if is_stuck:
		return
	if body == shooter:
		return

	var is_player: bool = body.is_in_group("player") or body.name == "Players"
	if is_player:
		_hit_player(body)
	else:
		_stick_to_surface(body)

func _hit_player(player_body: Node3D) -> void:
	is_stuck = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var to_player: Vector3 = (player_body.global_position - global_position).normalized()
	var knockback: Vector3 = to_player * knockback_force
	knockback.y = 1.5

	if player_body.has_method("take_damage"):
		player_body.take_damage(damage, knockback, true)

	_trigger_impact_effects()
	hit_target.emit(player_body, global_position)

	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(queue_free)

func _stick_to_surface(surface: Node3D) -> void:
	is_stuck = true
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
	tween.tween_interval(1.5)
	if visual_node:
		tween.tween_property(visual_node, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _trigger_impact_effects() -> void:
	_play_sfx(_cached_hit, 1.05)
	if impact_particles:
		impact_particles.restart()
		impact_particles.emitting = true

static func _ensure_cached_audio() -> void:
	if _cached_whoosh and _cached_hit:
		return

	var sample_hz := 22050.0

	if not _cached_whoosh:
		var dur_whoosh := 0.20
		var samples_w := int(sample_hz * dur_whoosh)
		var buf_w := PackedByteArray()
		buf_w.resize(samples_w * 2)
		for i in range(samples_w):
			var t := float(i) / sample_hz
			var env := sin((float(i) / float(samples_w)) * PI)
			var freq := lerpf(700.0, 350.0, t / dur_whoosh)
			var val := int(sin(t * freq * TAU) * env * 0.45 * 32767.0)
			buf_w.encode_s16(i * 2, val)
		_cached_whoosh = AudioStreamWAV.new()
		_cached_whoosh.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_whoosh.mix_rate = int(sample_hz)
		_cached_whoosh.data = buf_w

	if not _cached_hit:
		var dur_hit := 0.15
		var samples_h := int(sample_hz * dur_hit)
		var buf_h := PackedByteArray()
		buf_h.resize(samples_h * 2)
		for i in range(samples_h):
			var t := float(i) / sample_hz
			var env := exp(-t * 24.0)
			var noise := randf_range(-0.4, 0.4)
			var tone := sin(t * 190.0 * TAU) * 0.5
			var val := int((noise + tone) * env * 0.6 * 32767.0)
			buf_h.encode_s16(i * 2, val)
		_cached_hit = AudioStreamWAV.new()
		_cached_hit.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_hit.mix_rate = int(sample_hz)
		_cached_hit.data = buf_h

func _play_sfx(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if not audio_player or not stream:
		return
	audio_player.stream = stream
	audio_player.pitch_scale = pitch + randf_range(-0.06, 0.06)
	audio_player.play()
