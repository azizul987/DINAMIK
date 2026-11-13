@tool
class_name Portal
extends Area3D

signal player_entered(portal: Node3D, target_scene: String)

const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")

@export var portal_id: String = "portal_exit"
@export var target_scene_path: String = "res://scenes/level_1.tscn"
@export var is_active: bool = true:
	set(val):
		is_active = val
		_update_active_state()

@export var portal_color: Color = Color(0.15, 0.75, 1.0, 1.0):
	set(val):
		portal_color = val
		_apply_color()

@export var pulse_speed: float = 2.4
@export var float_speed: float = 2.2
@export var float_height: float = 0.15

@onready var outer_ring: MeshInstance3D = $OuterRing if has_node("OuterRing") else null
@onready var inner_ring: MeshInstance3D = $InnerRing if has_node("InnerRing") else null
@onready var vortex_ring: MeshInstance3D = $VortexRing if has_node("VortexRing") else null
@onready var center_disc: MeshInstance3D = $CenterDisc if has_node("CenterDisc") else null
@onready var light_pillar: MeshInstance3D = $LightPillar if has_node("LightPillar") else null
@onready var floating_crystal: MeshInstance3D = $FloatingCrystal if has_node("FloatingCrystal") else null
@onready var particles: CPUParticles3D = $Particles if has_node("Particles") else null
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D if has_node("AudioStreamPlayer3D") else null

var _outer_mat: StandardMaterial3D = null
var _inner_mat: StandardMaterial3D = null
var _vortex_mat: StandardMaterial3D = null
var _disc_mat: StandardMaterial3D = null
var _pillar_mat: StandardMaterial3D = null
var _crystal_mat: StandardMaterial3D = null

var _time: float = 0.0
var _initial_crystal_y: float = 1.3
var _is_surging: bool = false
var _cooldown: float = 0.0

func _ready() -> void:
	_setup_materials()
	_setup_audio()
	_apply_color()
	if floating_crystal:
		_initial_crystal_y = floating_crystal.position.y

	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _setup_materials() -> void:
	if not outer_ring and has_node("OuterRing"):
		outer_ring = $OuterRing as MeshInstance3D
	if not inner_ring and has_node("InnerRing"):
		inner_ring = $InnerRing as MeshInstance3D
	if not vortex_ring and has_node("VortexRing"):
		vortex_ring = $VortexRing as MeshInstance3D
	if not center_disc and has_node("CenterDisc"):
		center_disc = $CenterDisc as MeshInstance3D
	if not light_pillar and has_node("LightPillar"):
		light_pillar = $LightPillar as MeshInstance3D
	if not floating_crystal and has_node("FloatingCrystal"):
		floating_crystal = $FloatingCrystal as MeshInstance3D
	if not particles and has_node("Particles"):
		particles = $Particles as CPUParticles3D
	if not light and has_node("OmniLight3D"):
		light = $OmniLight3D as OmniLight3D
	if not audio_player and has_node("AudioStreamPlayer3D"):
		audio_player = $AudioStreamPlayer3D as AudioStreamPlayer3D

	if outer_ring:
		_outer_mat = _get_unique_material(outer_ring)
	if inner_ring:
		_inner_mat = _get_unique_material(inner_ring)
	if vortex_ring:
		_vortex_mat = _get_unique_material(vortex_ring)
	if center_disc:
		_disc_mat = _get_unique_material(center_disc)
	if light_pillar:
		_pillar_mat = _get_unique_material(light_pillar)
	if floating_crystal:
		_crystal_mat = _get_unique_material(floating_crystal)

func _get_unique_material(mesh_inst: MeshInstance3D) -> StandardMaterial3D:
	if not mesh_inst.material_override:
		if mesh_inst.mesh and mesh_inst.mesh.material:
			mesh_inst.material_override = mesh_inst.mesh.material.duplicate()
		else:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_inst.material_override = mat
	return mesh_inst.material_override as StandardMaterial3D

func _setup_audio() -> void:
	if audio_player and not audio_player.stream:
		# Procedural warp synthesizer
		var sample_hz := 22050.0
		var dur := 0.65
		var total_samples := int(sample_hz * dur)
		var buffer := PackedByteArray()
		buffer.resize(total_samples * 2)

		for i in range(total_samples):
			var t := float(i) / sample_hz
			var env := sin((float(i) / float(total_samples)) * PI)
			# Ascending chime frequencies
			var freq := lerpf(440.0, 880.0, t)
			var val := int((sin(t * freq * TAU) * 0.5 + sin(t * (freq * 1.5) * TAU) * 0.3) * env * 0.5 * 32767.0)
			buffer.encode_s16(i * 2, val)

		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_hz)
		wav.data = buffer
		audio_player.stream = wav

func _apply_color() -> void:
	if not _outer_mat:
		_setup_materials()

	if _outer_mat:
		_outer_mat.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.85)
	if _inner_mat:
		_inner_mat.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.75)
	if _vortex_mat:
		_vortex_mat.albedo_color = Color(portal_color.r * 1.2, portal_color.g * 1.2, portal_color.b * 1.2, 0.90)
	if _disc_mat:
		_disc_mat.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.22)
	if _pillar_mat:
		_pillar_mat.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.18)
	if _crystal_mat:
		_crystal_mat.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.95)
		_crystal_mat.emission = portal_color
		_crystal_mat.emission_enabled = true
		_crystal_mat.emission_energy_multiplier = 1.2
	if particles:
		particles.color = Color(portal_color.r, portal_color.g, portal_color.b, 0.88)
	if light:
		light.light_color = portal_color

func _update_active_state() -> void:
	monitoring = is_active
	visible = is_active

func _process(delta: float) -> void:
	if not is_active:
		return

	_time += delta
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)

	if outer_ring:
		outer_ring.rotate_y(delta * 0.45)
	if inner_ring:
		inner_ring.rotate_y(-delta * 0.85)
	if vortex_ring:
		vortex_ring.rotate_y(delta * 2.2)

	if floating_crystal:
		floating_crystal.rotate_y(delta * 1.4)
		floating_crystal.position.y = _initial_crystal_y + sin(_time * float_speed) * float_height

	if not _is_surging:
		var pulse := (sin(_time * pulse_speed) + 1.0) * 0.5
		if _outer_mat:
			_outer_mat.albedo_color.a = lerpf(0.65, 0.95, pulse)
		if _pillar_mat:
			_pillar_mat.albedo_color.a = lerpf(0.12, 0.28, pulse)
		if light:
			light.light_energy = lerpf(1.2, 2.2, pulse)

func _on_body_entered(body: Node3D) -> void:
	if not is_active or _cooldown > 0.0:
		return
	if body.name == "Players" or body is CharacterBody3D or body.is_in_group("player"):
		trigger_teleport(body)

func trigger_teleport(_player_node: Node3D = null) -> void:
	_cooldown = 2.5
	_is_surging = true

	# Print teleport output as requested
	print("[Portal] Teleportasi pemain ke scene berikutnya: %s (Portal ID: %s)" % [target_scene_path, portal_id])

	if audio_player:
		audio_player.play()

	# Floating text announcement
	if FLOATING_TEXT_SCENE and is_inside_tree():
		var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
		if label:
			get_tree().root.add_child(label)
			label.global_position = global_position + Vector3(0.0, 1.8, 0.0)
			label.pop("PORTAL AKTIF", portal_color.lightened(0.2), 34, 0.9, 0.8)

	# Surge visual animation
	var tw := create_tween()
	tw.set_parallel(true)
	if light:
		tw.tween_property(light, "light_energy", 4.5, 0.15).set_trans(Tween.TRANS_BACK)
		tw.tween_property(light, "light_energy", 1.8, 0.6).set_delay(0.15).set_ease(Tween.EASE_OUT)

	if light_pillar:
		tw.tween_property(light_pillar, "scale", Vector3(1.4, 1.4, 1.4), 0.18).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(light_pillar, "scale", Vector3.ONE, 0.5).set_delay(0.18)

	tw.chain().tween_callback(func():
		_is_surging = false
	)

	player_entered.emit(self, target_scene_path)
