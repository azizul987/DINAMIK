@tool
class_name TutorialMarker
extends Area3D

@export var marker_color: Color = Color(0.2, 0.9, 0.5, 1.0):
	set(val):
		marker_color = val
		_apply_color()

@export var pulse_speed: float = 3.2
@export var float_speed: float = 2.8
@export var float_height: float = 0.12

@onready var outer_ring: MeshInstance3D = $OuterRing if has_node("OuterRing") else null
@onready var inner_ring: MeshInstance3D = $InnerRing if has_node("InnerRing") else null
@onready var center_disc: MeshInstance3D = $CenterDisc if has_node("CenterDisc") else null
@onready var light_pillar: MeshInstance3D = $LightPillar if has_node("LightPillar") else null
@onready var floating_diamond: MeshInstance3D = $FloatingDiamond if has_node("FloatingDiamond") else null
@onready var particles: CPUParticles3D = $Particles if has_node("Particles") else null

var _outer_mat: StandardMaterial3D = null
var _inner_mat: StandardMaterial3D = null
var _disc_mat: StandardMaterial3D = null
var _pillar_mat: StandardMaterial3D = null
var _diamond_mat: StandardMaterial3D = null

var _time: float = 0.0
var _is_fading_out: bool = false
var _initial_diamond_y: float = 1.1

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
	if not center_disc and has_node("CenterDisc"):
		center_disc = $CenterDisc as MeshInstance3D
	if not light_pillar and has_node("LightPillar"):
		light_pillar = $LightPillar as MeshInstance3D
	if not floating_diamond and has_node("FloatingDiamond"):
		floating_diamond = $FloatingDiamond as MeshInstance3D
	if not particles and has_node("Particles"):
		particles = $Particles as CPUParticles3D

	if outer_ring:
		_outer_mat = _get_unique_material(outer_ring)
	if inner_ring:
		_inner_mat = _get_unique_material(inner_ring)
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
		_inner_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.70)
	if _disc_mat:
		_disc_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.16)
	if _pillar_mat:
		_pillar_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.14)
	if _diamond_mat:
		_diamond_mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.90)
		_diamond_mat.emission = marker_color
		_diamond_mat.emission_enabled = true
		_diamond_mat.emission_energy_multiplier = 0.8
	if particles:
		particles.color = Color(marker_color.r, marker_color.g, marker_color.b, 0.85)

func _process(delta: float) -> void:
	if _is_fading_out:
		return

	_time += delta

	if outer_ring:
		outer_ring.rotate_y(delta * 0.6)
	if inner_ring:
		inner_ring.rotate_y(-delta * 1.1)

	if floating_diamond:
		floating_diamond.rotate_y(delta * 1.6)
		floating_diamond.position.y = _initial_diamond_y + sin(_time * float_speed) * float_height

	var pulse := (sin(_time * pulse_speed) + 1.0) * 0.5
	if _outer_mat:
		_outer_mat.albedo_color.a = lerpf(0.65, 0.95, pulse)
	if _pillar_mat:
		_pillar_mat.albedo_color.a = lerpf(0.08, 0.20, pulse)

func play_reached_animation() -> void:
	_is_fading_out = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.3, 0.1, 1.3), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _outer_mat:
		tw.tween_property(_outer_mat, "albedo_color:a", 0.0, 0.25)
	if _inner_mat:
		tw.tween_property(_inner_mat, "albedo_color:a", 0.0, 0.25)
	if _disc_mat:
		tw.tween_property(_disc_mat, "albedo_color:a", 0.0, 0.25)
	if _pillar_mat:
		tw.tween_property(_pillar_mat, "albedo_color:a", 0.0, 0.25)
	if _diamond_mat:
		tw.tween_property(_diamond_mat, "albedo_color:a", 0.0, 0.25)
	if floating_diamond:
		tw.tween_property(floating_diamond, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
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
	_apply_color()
