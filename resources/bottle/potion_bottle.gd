class_name PotionBottle
extends Node3D

## Skrip pengontrol visual botol ramuan alchemical dan warna cairan.

const COLOR_HEALING: Color = Color(0.22, 0.95, 0.45, 0.9)
const COLOR_STRENGTH: Color = Color(1.0, 0.65, 0.15, 0.9)
const COLOR_SLOW: Color = Color(0.25, 0.82, 1.0, 0.9)
const COLOR_BERSERK: Color = Color(0.95, 0.15, 0.25, 0.95)
const COLOR_IRONSKIN: Color = Color(0.85, 0.92, 0.98, 0.9)
const COLOR_NIGHTVISION: Color = Color(0.6, 1.0, 0.35, 0.9)

static var _cached_materials: Dictionary = {}

@onready var bottle_mesh: MeshInstance3D = null

func _ready() -> void:
	var mesh_node := _get_bottle_mesh()
	if mesh_node and mesh_node.mesh:
		set_potion_type("healing")

func _get_bottle_mesh() -> MeshInstance3D:
	if not bottle_mesh or not is_instance_valid(bottle_mesh):
		bottle_mesh = find_child("LabuBawah_001", true, false) as MeshInstance3D
		if not bottle_mesh:
			bottle_mesh = find_child("BottleMesh", true, false) as MeshInstance3D
		if not bottle_mesh:
			for child in find_children("*", "MeshInstance3D", true, false):
				bottle_mesh = child as MeshInstance3D
				break
	return bottle_mesh

## Mengubah warna material cairan kaca pada botol sesuai tipe ramuan.
func set_potion_type(potion_name: String) -> void:
	var mesh_node := _get_bottle_mesh()
	if not mesh_node:
		return

	var key: String = potion_name.to_lower()
	var mat: StandardMaterial3D = _get_or_create_liquid_material(key)
	mesh_node.set_surface_override_material(0, mat)

func _get_or_create_liquid_material(potion_name: String) -> StandardMaterial3D:
	if _cached_materials.has(potion_name):
		return _cached_materials[potion_name] as StandardMaterial3D

	var col: Color = COLOR_HEALING
	match potion_name:
		"strength":
			col = COLOR_STRENGTH
		"slow":
			col = COLOR_SLOW
		"berserk":
			col = COLOR_BERSERK
		"ironskin":
			col = COLOR_IRONSKIN
		"nightvision":
			col = COLOR_NIGHTVISION
		_:
			col = COLOR_HEALING

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.15
	mat.metallic = 0.1
	mat.emission_enabled = true
	mat.emission = col * 0.4
	mat.emission_energy_multiplier = 1.2

	_cached_materials[potion_name] = mat
	return mat
