extends Node3D
class_name SpikeTrap

enum TrapState { IDLE, WARNING, EXTENDED, RETRACTING }

@export_group("Trap Configuration")
@export var trap_damage: float = 25.0
@export var trap_knockback_lift: float = 4.8
@export var idle_duration: float = 2.4
@export var warning_duration: float = 0.45
@export var extended_duration: float = 1.0
@export var retract_duration: float = 0.35

var current_state: TrapState = TrapState.IDLE
var state_timer: float = 0.0

@onready var spikes_pivot: Node3D = $SpikesPivot
@onready var trigger_area: Area3D = $TriggerArea
@onready var base_plate: CSGBox3D = $BasePlate
@onready var trap_audio: AudioStreamPlayer3D = $TrapAudio if has_node("TrapAudio") else null

var base_mat: StandardMaterial3D = null
var default_base_color: Color = Color(0.18, 0.20, 0.24)
var warning_base_color: Color = Color(0.65, 0.15, 0.15)

const RETRACTED_Y: float = -0.55
const EXTENDED_Y: float = 0.35

func _ready() -> void:
	add_to_group("traps")
	_setup_materials()
	state_timer = idle_duration
	if spikes_pivot:
		spikes_pivot.position.y = RETRACTED_Y
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)

func _setup_materials() -> void:
	if base_plate:
		base_mat = StandardMaterial3D.new()
		base_mat.albedo_color = default_base_color
		base_mat.roughness = 0.75
		base_mat.metallic = 0.3
		base_plate.material = base_mat

func _process(delta: float) -> void:
	state_timer -= delta

	match current_state:
		TrapState.IDLE:
			if state_timer <= 0.0:
				_start_warning()

		TrapState.WARNING:
			if spikes_pivot:
				spikes_pivot.position.y = RETRACTED_Y + randf_range(0.04, 0.10)
			if state_timer <= 0.0:
				_thrust_spikes()

		TrapState.EXTENDED:
			if state_timer <= 0.0:
				_retract_spikes()

		TrapState.RETRACTING:
			if state_timer <= 0.0:
				current_state = TrapState.IDLE
				state_timer = idle_duration
				if base_mat:
					base_mat.albedo_color = default_base_color
					base_mat.emission_enabled = false

func _start_warning() -> void:
	current_state = TrapState.WARNING
	state_timer = warning_duration
	if base_mat:
		base_mat.albedo_color = warning_base_color
		base_mat.emission_enabled = true
		base_mat.emission = Color(0.8, 0.1, 0.1)
		base_mat.emission_energy_multiplier = 0.6
	_play_trap_sfx(700.0, 0.12, 0.25) # Warning click

func _thrust_spikes() -> void:
	current_state = TrapState.EXTENDED
	state_timer = extended_duration

	if spikes_pivot:
		var tw := create_tween()
		tw.tween_property(spikes_pivot, "position:y", EXTENDED_Y, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_play_trap_sfx(180.0, 0.22, 0.75) # Heavy metallic spike snap
	_apply_damage_to_overlapping()

func _retract_spikes() -> void:
	current_state = TrapState.RETRACTING
	state_timer = retract_duration

	if spikes_pivot:
		var tw := create_tween()
		tw.tween_property(spikes_pivot, "position:y", RETRACTED_Y, retract_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node3D) -> void:
	if current_state == TrapState.EXTENDED:
		_damage_entity(body)
	elif current_state == TrapState.IDLE:
		state_timer = minf(state_timer, 0.25)

func _apply_damage_to_overlapping() -> void:
	if not trigger_area:
		return
	var bodies := trigger_area.get_overlapping_bodies()
	for b in bodies:
		_damage_entity(b)

func _damage_entity(entity: Node3D) -> void:
	if not entity or not is_instance_valid(entity):
		return

	if entity.has_method("take_damage"):
		var lift_vector := Vector3(0.0, trap_knockback_lift, 0.0)
		entity.take_damage(trap_damage, lift_vector, true)

func _play_trap_sfx(freq: float, duration: float, volume: float) -> void:
	if not trap_audio:
		return

	var sample_hz := 22050.0
	var total_samples := int(sample_hz * duration)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 16.0)
		var val := int(sin(t * freq * TAU) * env * volume * 32767.0)
		buffer.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	trap_audio.stream = wav
	trap_audio.play()
