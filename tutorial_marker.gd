@tool
class_name TutorialMarker
extends Area3D

@export var marker_color: Color = Color(0.15, 0.75, 1.0, 1.0):
	set(val):
		marker_color = val
		_apply_color()

@export var pulse_speed: float = 2.4
@export var float_speed: float = 2.2
@export var float_height: float = 0.15

@onready var outer_ring: MeshInstance3D = $OuterRing if has_node("OuterRing") else null
@onready var inner_ring: MeshInstance3D = $InnerRing if has_node("InnerRing") else null
@onready var vortex_ring: MeshInstance3D = $VortexRing if has_node("VortexRing") else null
@onready var center_disc: MeshInstance3D = $CenterDisc if has_node("CenterDisc") else null
@onready var light_pillar: MeshInstance3D = $LightPillar if has_node("LightPillar") else null
@onready var floating_diamond: MeshInstance3D = $FloatingDiamond if has_node("FloatingDiamond") else null
@onready var particles: CPUParticles3D = $Particles if has_node("Particles") else null
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null

var _outer_mat: StandardMaterial3D = null
var _inner_mat: StandardMaterial3D = null
var _vortex_mat: StandardMaterial3D = null
var _disc_mat: StandardMaterial3D = null
var _pillar_mat: StandardMaterial3D = null
var _diamond_mat: StandardMaterial3D = null

var _time: float = 0.0
var _is_fading_out: bool = false
var _initial_diamond_y: float = 1.3

func _ready() -> void:
	_setup_materials()
	_apply_color()
	if floating_diamond:
		_initial_diamond_y = floating_diamond.position.y

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
	if not floating_diamond and has_node("FloatingDiamond"):
		floating_diamond = $FloatingDiamond as MeshInstance3D
	if not particles and has_node("Particles"):
		particles = $Particles as CPUParticles3D
	if not light and has_node("OmniLight3D"):
		light = $OmniLight3D as OmniLight3D

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
	if floating_diamond:
		_diamond_mat = _get_unique_material(floating_diamond)

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

func _apply_color() -> void:
	if not _outer_mat:
		_setup_materials()

	if _outer_mat:
		_outer_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.85)
	if _inner_mat:
		_inner_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.75)
	if _vortex_mat:
		_vortex_mat.albedo_color = Color(marker_color.r * 1.2, marker_color.g * 1.2, marker_color.b * 1.2, 0.90)
	if _disc_mat:
		_disc_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.22)
	if _pillar_mat:
		_pillar_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.18)
	if _diamond_mat:
		_diamond_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.95)
		_diamond_mat.emission = marker_color
		_diamond_mat.emission_enabled = true
		_diamond_mat.emission_energy_multiplier = 1.2
	if particles:
		particles.color = Color(marker_color.r, marker_color.g, marker_color.b, 0.88)
	if light:
		light.light_color = marker_color
		light.light_energy = 1.6

func _process(delta: float) -> void:
	if _is_fading_out:
		return

	_time += delta

	if outer_ring:
		outer_ring.rotate_y(delta * 0.45)
	if inner_ring:
		inner_ring.rotate_y(-delta * 0.85)
	if vortex_ring:
		vortex_ring.rotate_y(delta * 2.2)

	if floating_diamond:
		floating_diamond.rotate_y(delta * 1.4)
		floating_diamond.position.y = _initial_diamond_y + sin(_time * float_speed) * float_height

	var pulse := (sin(_time * pulse_speed) + 1.0) * 0.5
	if _outer_mat:
		_outer_mat.albedo_color.a = lerpf(0.65, 0.95, pulse)
	if _vortex_mat:
		_vortex_mat.albedo_color.a = lerpf(0.70, 1.0, pulse)
	if _pillar_mat:
		_pillar_mat.albedo_color.a = lerpf(0.12, 0.28, pulse)
	if light:
		light.light_energy = lerpf(1.2, 2.2, pulse)

func play_reached_animation() -> void:
	_is_fading_out = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.3, 0.1, 1.3), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _outer_mat:
		tw.tween_property(_outer_mat, "albedo_color:a", 0.0, 0.25)
	if _inner_mat:
		tw.tween_property(_inner_mat, "albedo_color:a", 0.0, 0.25)
	if _vortex_mat:
		tw.tween_property(_vortex_mat, "albedo_color:a", 0.0, 0.25)
	if _disc_mat:
		tw.tween_property(_disc_mat, "albedo_color:a", 0.0, 0.25)
	if _pillar_mat:
		tw.tween_property(_pillar_mat, "albedo_color:a", 0.0, 0.25)
	if _diamond_mat:
		tw.tween_property(_diamond_mat, "albedo_color:a", 0.0, 0.25)
	if floating_diamond:
		tw.tween_property(floating_diamond, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if light:
		tw.tween_property(light, "light_energy", 0.0, 0.25)
	tw.chain().tween_callback(func():
		visible = false
		monitoring = false
	)

func reset_marker() -> void:
	_is_fading_out = false
	scale = Vector3.ONE
	visible = true
	monitoring = true
	if floating_diamond:
		floating_diamond.scale = Vector3.ONE
	if light:
		light.light_energy = 1.6
	_apply_color()
