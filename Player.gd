class_name Player
extends CharacterBody3D

const DASH_GHOST_SCENE: PackedScene = preload("res://dash_ghost.tscn")
const DASH_WIND_SCENE: PackedScene = preload("res://dash_wind_effect.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")
const FOOTSTEP_DUST_SCENE: PackedScene = preload("res://footstep_dust.tscn")
const GROUND_SLAM_SCENE: PackedScene = preload("res://ground_slam_shockwave.tscn")

@export_group("Movement")
@export var walk_speed: float = 4.5
@export var run_speed: float = 7.0
@export var jump_force: float = 7.5
@export var gravity: float = 20.0
@export var air_control: float = 0.3
@export var coyote_time: float = 0.12

@export_group("Combat - Attack & Combo")
@export var base_damage: float = 15.0
@export var attack_cooldown: float = 0.35
@export var base_knockback_force: float = 9.0
@export var knockback_lift: float = 0.45
@export var strength_damage_multiplier: float = 2.0
@export var berserk_damage_multiplier: float = 3.0
@export var strength_knockback_multiplier: float = 1.25
@export var berserk_knockback_multiplier: float = 1.5
@export var attack_slash_angle_deg: float = 65.0
@export var attack_slash_duration: float = 0.12
@export var attack_recovery_duration: float = 0.15
@export var attack_lunge_speed: float = 4.2
@export var attack_lunge_duration: float = 0.08
@export var combo_window: float = 0.95
@export var combo_damage_multipliers: Array[float] = [1.0, 1.3, 1.8]
@export var combo_knockback_multipliers: Array[float] = [1.0, 1.25, 1.7]
@export var combo_speed_scales: Array[float] = [1.8, 1.8, 2.2]
@export var combo_durations: Array[float] = [0.42, 0.45, 1.05]
@export var combo_hit_delays: Array[float] = [0.10, 0.10, 0.68]
@export var combo_hit_durations: Array[float] = [0.18, 0.18, 0.22]

@export_group("Combat - Defense & Recoil")
@export var invulnerability_duration: float = 0.6
@export var received_knockback_duration: float = 0.25
@export var received_knockback_damping: float = 9.0
@export var hit_trauma_shake: float = 0.55
@export var hit_flash_duration: float = 0.08
@export var hit_blink_interval: float = 0.06

@export_group("Combat - Dash")
@export var dash_speed: float = 16.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.5
@export var dash_ghost_interval: float = 0.045
@export var dash_ghost_color: Color = Color(0.85, 0.95, 1.0, 0.45)

@export_group("Target Lock-On")
@export var lock_on_max_distance: float = 18.0
@export var lock_on_turn_speed: float = 15.0

@export_group("Zelda Movement & Camera")
@export var body_turn_with_camera: bool = true
@export var body_turn_speed: float = 14.0

@export_group("Targeting - Auto Aim Assist")
@export var auto_target_enabled: bool = true
@export var auto_target_radius: float = 6.5
@export var auto_target_cone_deg: float = 150.0
@export var auto_target_point_blank_radius: float = 2.2

@export_group("Equipped Weapon")
@export var weapon_mesh: Mesh = preload("res://resources/weapon/OBJ/Sword.obj")
@export var weapon_scale: Vector3 = Vector3(0.22, 0.22, 0.22)
@export var weapon_rotation_degrees: Vector3 = Vector3.ZERO
@export var weapon_position_offset: Vector3 = Vector3.ZERO

@export_group("Equipped Bottle")
@export var potion_bottle: Node3D = null
@export var potion_bottle_scene: PackedScene = preload("res://resources/bottle/botol_model.tscn")
@export var bottle_scale: Vector3 = Vector3(0.9, 0.9, 0.9)
@export var bottle_rotation_degrees: Vector3 = Vector3(-10.0, 75.0, -90.0)
@export var bottle_position_offset: Vector3 = Vector3(0.02, 0.04, -0.01)
@export var drink_speed_multiplier: float = 0.5

@export_group("Effects - Footsteps & Impacts")
@export var footstep_interval_walk: float = 0.38
@export var footstep_interval_run: float = 0.24
@export var footstep_dust_offset_lateral: float = 0.18
@export var landing_impact_threshold: float = -4.0

var equipped_weapon_node: MeshInstance3D = null
var weapon_hand_attachment: BoneAttachment3D = null
var bottle_hand_attachment: BoneAttachment3D = null
var potion_bottle_instance: Node3D = null
var is_drinking: bool = false
var _drink_tween: Tween = null

var _footstep_timer: float = 0.0
var _foot_alternator: bool = false
var _prev_vertical_velocity: float = 0.0
var _was_on_floor_prev: bool = true

var speed_multiplier: float = 1.0
var coyote_timer: float = 0.0
var is_attacking: bool = false
var can_attack: bool = true
var locked_target: Node3D = null
var is_holding_z_target: bool = false
var _rmb_press_time: int = 0

var combo_index: int = 0
var combo_timer: float = 0.0
var _attack_start_rig_pos: Vector3 = Vector3.ZERO
var _idle_rig_pos: Vector3 = Vector3.ZERO
var _current_combo_damage_mult: float = 1.0
var _current_combo_kb_mult: float = 1.0

var is_invulnerable: bool = false
var knockback_timer: float = 0.0
var _hit_targets_this_swing: Array[Node] = []
var lunge_timer: float = 0.0
var lunge_direction: Vector3 = Vector3.ZERO

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_ghost_timer: float = 0.0

const HIT_SPARK_PREFAB: PackedScene = preload("res://hit_spark.tscn")

var slash_arc_mat: StandardMaterial3D = null
var slash_arc_core_mat: StandardMaterial3D = null
var slash_arc_trail_mat: StandardMaterial3D = null
var flash_material: StandardMaterial3D = null
var dash_material: StandardMaterial3D = null
var _hit_blink_tween: Tween = null
var _character_meshes: Array[MeshInstance3D] = []

static var _cached_slash_whoosh_wav: AudioStreamWAV = null
static var _cached_slash_hit_wav: AudioStreamWAV = null

@onready var camera_pivot: Node3D = $CameraPivot
@onready var mesh_instance: Node3D = $Ranger if has_node("Ranger") else ($MeshInstance if has_node("MeshInstance") else self)
@onready var character_rig: Node3D = mesh_instance.find_child("Rig_Medium", true, false) as Node3D if mesh_instance else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var weapon_pivot: Node3D = %WeaponPivot if has_node("%WeaponPivot") else ($Ranger/WeaponPivot if has_node("Ranger/WeaponPivot") else ($MeshInstance/WeaponPivot if has_node("MeshInstance/WeaponPivot") else null))
@onready var hitbox: Area3D = %Hitbox
@onready var slash_arc: MeshInstance3D = %SlashArc if has_node("%SlashArc") else null
@onready var slash_arc_core: MeshInstance3D = %SlashArcCore if has_node("%SlashArcCore") else null
@onready var slash_arc_trail: MeshInstance3D = %SlashArcTrail if has_node("%SlashArcTrail") else null
@onready var slash_sparks: CPUParticles3D = %SlashSparks if has_node("%SlashSparks") else null
@onready var deflect_audio: AudioStreamPlayer = $DeflectAudio if has_node("DeflectAudio") else null
@onready var slash_audio: AudioStreamPlayer3D = %SlashAudio if has_node("%SlashAudio") else ($SlashAudio if has_node("SlashAudio") else null)
@onready var slash_hit_audio: AudioStreamPlayer3D = %SlashHitAudio if has_node("%SlashHitAudio") else ($SlashHitAudio if has_node("SlashHitAudio") else null)
@onready var footstep_audio: AudioStreamPlayer3D = %FootstepAudio if has_node("%FootstepAudio") else ($FootstepAudio if has_node("FootstepAudio") else null)

func _ready() -> void:
	add_to_group("player")
	GlobalLogic.toxicity_stage_changed.connect(_on_toxicity_stage_changed)
	GlobalLogic.player_died.connect(_on_player_died)
	GlobalLogic.potion_consumed.connect(_on_potion_consumed)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_setup_weapon_attachment()
	_setup_bottle_attachment()
	_cache_character_meshes()
	_setup_slash_arc()
	_setup_slash_audio()
	_setup_flash_material()
	_setup_dash_material()
	_setup_deflect_audio()
	if character_rig:
		_idle_rig_pos = character_rig.position
	if animation_player:
		animation_player.playback_default_blend_time = 0.15
		if animation_player.has_animation("idle"):
			animation_player.play("idle")

func _setup_weapon_attachment() -> void:
	if not mesh_instance:
		return
	var skel := mesh_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		return

	var hand_idx := skel.find_bone("handslot.r")
	if hand_idx == -1:
		hand_idx = skel.find_bone("hand.r")
	if hand_idx == -1:
		return

	weapon_hand_attachment = skel.get_node_or_null("RightHandAttachment") as BoneAttachment3D
	if not weapon_hand_attachment:
		weapon_hand_attachment = BoneAttachment3D.new()
		weapon_hand_attachment.name = "RightHandAttachment"
		skel.add_child(weapon_hand_attachment)
		weapon_hand_attachment.bone_name = skel.get_bone_name(hand_idx)
		weapon_hand_attachment.bone_idx = hand_idx

	equipped_weapon_node = weapon_hand_attachment.get_node_or_null("EquippedWeapon") as MeshInstance3D
	if not equipped_weapon_node and weapon_mesh:
		equipped_weapon_node = MeshInstance3D.new()
		equipped_weapon_node.name = "EquippedWeapon"
		equipped_weapon_node.mesh = weapon_mesh
		equipped_weapon_node.scale = weapon_scale
		equipped_weapon_node.rotation_degrees = weapon_rotation_degrees
		equipped_weapon_node.position = weapon_position_offset
		weapon_hand_attachment.add_child(equipped_weapon_node)

	# Sembunyikan balok kubus CSGBox Blade dan Handle bawaan
	if weapon_pivot:
		var blade := weapon_pivot.get_node_or_null("Blade") as VisualInstance3D
		if blade:
			blade.visible = false
		var handle := weapon_pivot.get_node_or_null("Handle") as VisualInstance3D
		if handle:
			handle.visible = false

func _setup_bottle_attachment() -> void:
	if potion_bottle and is_instance_valid(potion_bottle):
		potion_bottle_instance = potion_bottle
		potion_bottle_instance.visible = false
		return

	if not mesh_instance:
		return
	var skel := mesh_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		return

	var hand_idx := skel.find_bone("handslot.l")
	if hand_idx == -1:
		hand_idx = skel.find_bone("hand.l")
	if hand_idx == -1:
		return

	bottle_hand_attachment = skel.get_node_or_null("LeftHandAttachment") as BoneAttachment3D

	if bottle_hand_attachment:
		var child_bottle := bottle_hand_attachment.get_node_or_null("Botol") as Node3D
		if not child_bottle:
			child_bottle = bottle_hand_attachment.get_node_or_null("PotionBottle") as Node3D
		if not child_bottle and bottle_hand_attachment.get_child_count() > 0:
			child_bottle = bottle_hand_attachment.get_child(0) as Node3D
		if child_bottle:
			potion_bottle_instance = child_bottle
			potion_bottle = child_bottle
			potion_bottle_instance.visible = false
			return

	if not bottle_hand_attachment:
		bottle_hand_attachment = BoneAttachment3D.new()
		bottle_hand_attachment.name = "LeftHandAttachment"
		skel.add_child(bottle_hand_attachment)
		bottle_hand_attachment.bone_name = skel.get_bone_name(hand_idx)
		bottle_hand_attachment.bone_idx = hand_idx

	var fallback_scene: PackedScene = potion_bottle_scene
	if not fallback_scene:
		fallback_scene = load("res://resources/bottle/botol_model.tscn") as PackedScene

	if fallback_scene:
		potion_bottle_instance = fallback_scene.instantiate() as Node3D
		potion_bottle_instance.name = "Botol"
		potion_bottle_instance.scale = bottle_scale
		potion_bottle_instance.rotation_degrees = bottle_rotation_degrees
		potion_bottle_instance.position = bottle_position_offset
		bottle_hand_attachment.add_child(potion_bottle_instance)
		potion_bottle = potion_bottle_instance

	if potion_bottle_instance:
		potion_bottle_instance.visible = false

func _cache_character_meshes() -> void:
	_character_meshes.clear()
	if mesh_instance is MeshInstance3D:
		_character_meshes.append(mesh_instance as MeshInstance3D)
	elif is_instance_valid(mesh_instance):
		for child in mesh_instance.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if not mi:
				continue
			if mi == slash_arc or mi == equipped_weapon_node:
				continue
			if weapon_pivot and weapon_pivot.is_ancestor_of(mi):
				continue
			if is_instance_valid(potion_bottle_instance) and (potion_bottle_instance == mi or potion_bottle_instance.is_ancestor_of(mi)):
				continue
			if is_instance_valid(potion_bottle) and (potion_bottle == mi or potion_bottle.is_ancestor_of(mi)):
				continue
			_character_meshes.append(mi)

func _set_model_material_override(mat: Material) -> void:
	for m in _character_meshes:
		if is_instance_valid(m):
			m.material_override = mat

func _get_model_material_override() -> Material:
	if not _character_meshes.is_empty() and is_instance_valid(_character_meshes[0]):
		return _character_meshes[0].material_override
	return null

func _setup_dash_material() -> void:
	dash_material = StandardMaterial3D.new()
	dash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dash_material.albedo_color = Color(dash_ghost_color.r, dash_ghost_color.g, dash_ghost_color.b, 0.85)

func _setup_deflect_audio() -> void:
	if not deflect_audio and has_node("DeflectAudio"):
		deflect_audio = $DeflectAudio as AudioStreamPlayer
	if deflect_audio and not deflect_audio.stream:
		var sample_hz := 22050.0
		var dur := 0.25
		var total_samples := int(sample_hz * dur)
		var buffer := PackedByteArray()
		buffer.resize(total_samples * 2)

		for i in range(total_samples):
			var t := float(i) / sample_hz
			var env := exp(-t * 20.0)
			var val := int((sin(t * 1100.0 * TAU) * 0.5 + sin(t * 1650.0 * TAU) * 0.3 + sin(t * 2750.0 * TAU) * 0.2) * env * 0.55 * 32767.0)
			buffer.encode_s16(i * 2, val)

		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_hz)
		wav.data = buffer
		deflect_audio.stream = wav

func _setup_slash_arc() -> void:
	if not slash_arc and weapon_pivot:
		slash_arc = weapon_pivot.get_node_or_null("SlashArc") as MeshInstance3D
	if not slash_arc_core and weapon_pivot:
		slash_arc_core = weapon_pivot.get_node_or_null("SlashArcCore") as MeshInstance3D
	if not slash_arc_trail and weapon_pivot:
		slash_arc_trail = weapon_pivot.get_node_or_null("SlashArcTrail") as MeshInstance3D
	if not slash_sparks and weapon_pivot:
		slash_sparks = weapon_pivot.get_node_or_null("SlashSparks") as CPUParticles3D

	var crescent_mesh := load("res://resources/weapon/slash_arc_mesh.tres") as Mesh

	if slash_arc:
		if crescent_mesh:
			slash_arc.mesh = crescent_mesh
		slash_arc_mat = StandardMaterial3D.new()
		slash_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		slash_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		slash_arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		slash_arc_mat.vertex_color_use_as_albedo = true
		slash_arc.material_override = slash_arc_mat
		slash_arc.visible = false

	if slash_arc_core:
		if crescent_mesh:
			slash_arc_core.mesh = crescent_mesh
		slash_arc_core_mat = StandardMaterial3D.new()
		slash_arc_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		slash_arc_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		slash_arc_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		slash_arc_core_mat.vertex_color_use_as_albedo = true
		slash_arc_core_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		slash_arc_core.material_override = slash_arc_core_mat
		slash_arc_core.visible = false

	if slash_arc_trail:
		if crescent_mesh:
			slash_arc_trail.mesh = crescent_mesh
		slash_arc_trail_mat = StandardMaterial3D.new()
		slash_arc_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		slash_arc_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		slash_arc_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		slash_arc_trail_mat.vertex_color_use_as_albedo = true
		slash_arc_trail.material_override = slash_arc_trail_mat
		slash_arc_trail.visible = false

func _setup_slash_audio() -> void:
	if not slash_audio and has_node("%SlashAudio"):
		slash_audio = %SlashAudio as AudioStreamPlayer3D
	elif not slash_audio and has_node("SlashAudio"):
		slash_audio = $SlashAudio as AudioStreamPlayer3D

	if not slash_hit_audio and has_node("%SlashHitAudio"):
		slash_hit_audio = %SlashHitAudio as AudioStreamPlayer3D
	elif not slash_hit_audio and has_node("SlashHitAudio"):
		slash_hit_audio = $SlashHitAudio as AudioStreamPlayer3D

	if not _cached_slash_whoosh_wav:
		_cached_slash_whoosh_wav = _generate_slash_whoosh_wav()
	if not _cached_slash_hit_wav:
		_cached_slash_hit_wav = _generate_slash_hit_wav()

	if slash_audio and not slash_audio.stream:
		slash_audio.stream = _cached_slash_whoosh_wav
	if slash_hit_audio and not slash_hit_audio.stream:
		slash_hit_audio.stream = _cached_slash_hit_wav

func _trigger_slash_arc(step: int, duration: float) -> void:
	if not slash_arc or not slash_arc_mat or not mesh_instance:
		return

	var arc_color := Color(0.25, 0.88, 1.0, 0.95)
	var spark_color := Color(0.45, 0.92, 1.0, 1.0)
	if GlobalLogic.is_berserk_active:
		arc_color = Color(1.0, 0.20, 0.08, 0.98)
		spark_color = Color(1.0, 0.35, 0.10, 1.0)
	elif GlobalLogic.is_strength_active:
		arc_color = Color(1.0, 0.88, 0.22, 0.98)
		spark_color = Color(1.0, 0.95, 0.40, 1.0)
	elif step == 2:
		arc_color = Color(1.0, 0.65, 0.18, 0.98)
		spark_color = Color(1.0, 0.75, 0.30, 1.0)

	slash_arc_mat.albedo_color = arc_color
	if slash_arc_core_mat:
		slash_arc_core_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	if slash_arc_trail_mat:
		slash_arc_trail_mat.albedo_color = Color(arc_color.r, arc_color.g, arc_color.b, 0.45)

	var mesh_yaw := mesh_instance.global_rotation.y
	var base_pos := global_position + Vector3(0.0, 0.92, 0.0) + (mesh_instance.global_transform.basis.z * 0.75)
	slash_arc.global_position = base_pos
	if slash_arc_core:
		slash_arc_core.global_position = base_pos
	if slash_arc_trail:
		slash_arc_trail.global_position = base_pos - (mesh_instance.global_transform.basis.z * 0.08)

	var start_rot := Vector3.ZERO
	var target_rot_y := mesh_yaw
	var start_scale := Vector3(0.75, 0.75, 0.75)
	var target_scale := Vector3(1.4, 1.4, 1.4)

	match step:
		0:
			start_rot = Vector3(deg_to_rad(-8.0), mesh_yaw + deg_to_rad(55.0), deg_to_rad(6.0))
			target_rot_y = mesh_yaw - deg_to_rad(60.0)
			start_scale = Vector3(0.75, 0.75, 0.75)
			target_scale = Vector3(1.45, 1.45, 1.45)
		1:
			start_rot = Vector3(deg_to_rad(32.0), mesh_yaw - deg_to_rad(55.0), deg_to_rad(-25.0))
			target_rot_y = mesh_yaw + deg_to_rad(55.0)
			start_scale = Vector3(0.8, 0.8, 0.8)
			target_scale = Vector3(1.55, 1.55, 1.55)
		2:
			start_rot = Vector3(deg_to_rad(75.0), mesh_yaw, deg_to_rad(-8.0))
			target_rot_y = mesh_yaw
			start_scale = Vector3(1.1, 1.1, 1.1)
			target_scale = Vector3(2.2, 2.2, 2.2)

	slash_arc.global_rotation = start_rot
	slash_arc.scale = start_scale
	slash_arc.visible = true

	if slash_arc_core:
		slash_arc_core.global_rotation = start_rot
		slash_arc_core.scale = start_scale * 0.88
		slash_arc_core.visible = true

	if slash_arc_trail:
		slash_arc_trail.global_rotation = start_rot + Vector3(0.0, deg_to_rad(12.0 if step == 0 else -12.0), 0.0)
		slash_arc_trail.scale = start_scale * 1.12
		slash_arc_trail.visible = true

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash_arc, "scale", target_scale, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if step != 2:
		tw.tween_property(slash_arc, "global_rotation:y", target_rot_y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(slash_arc, "global_rotation:x", deg_to_rad(5.0), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(slash_arc_mat, "albedo_color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if slash_arc_core and slash_arc_core_mat:
		tw.tween_property(slash_arc_core, "scale", target_scale * 0.90, duration * 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if step != 2:
			tw.tween_property(slash_arc_core, "global_rotation:y", target_rot_y, duration * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(slash_arc_core, "global_rotation:x", deg_to_rad(5.0), duration * 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(slash_arc_core_mat, "albedo_color:a", 0.0, duration * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if slash_arc_trail and slash_arc_trail_mat:
		tw.tween_property(slash_arc_trail, "scale", target_scale * 1.18, duration * 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if step != 2:
			tw.tween_property(slash_arc_trail, "global_rotation:y", target_rot_y + deg_to_rad(10.0 if step == 0 else -10.0), duration * 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(slash_arc_trail_mat, "albedo_color:a", 0.0, duration * 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.chain().tween_callback(func():
		if is_instance_valid(slash_arc):
			slash_arc.visible = false
		if is_instance_valid(slash_arc_core):
			slash_arc_core.visible = false
		if is_instance_valid(slash_arc_trail):
			slash_arc_trail.visible = false
	)

	if slash_sparks:
		slash_sparks.color = spark_color
		slash_sparks.global_position = base_pos
		var fwd := mesh_instance.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		if step == 0:
			slash_sparks.direction = (fwd + mesh_instance.global_transform.basis.x * -0.6).normalized()
			slash_sparks.amount = 24
		elif step == 1:
			slash_sparks.direction = (fwd + mesh_instance.global_transform.basis.x * 0.6 + Vector3(0.0, 0.4, 0.0)).normalized()
			slash_sparks.amount = 26
		else:
			slash_sparks.direction = (fwd + Vector3(0.0, 0.35, 0.0)).normalized()
			slash_sparks.amount = 38
		slash_sparks.restart()
		slash_sparks.emitting = true

	if slash_audio:
		var pitch := 1.15
		match step:
			0: pitch = 1.18
			1: pitch = 1.34
			2: pitch = 0.76
		if GlobalLogic.is_berserk_active:
			pitch *= 1.12
		slash_audio.pitch_scale = pitch * randf_range(0.96, 1.04)
		slash_audio.play()

func _perform_attack_lunge(step: int) -> void:
	if not is_on_floor() or not mesh_instance:
		return
	var forward := mesh_instance.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var lunge_speed: float = attack_lunge_speed * (1.35 if step == 2 else 1.0)
	velocity.x = forward.x * lunge_speed
	velocity.z = forward.z * lunge_speed
	lunge_timer = attack_lunge_duration
	lunge_direction = forward

func _on_toxicity_stage_changed(stage: GlobalLogic.ToxicityStage) -> void:
	match stage:
		GlobalLogic.ToxicityStage.SAFE, GlobalLogic.ToxicityStage.MODERATE:
			speed_multiplier = 1.0
		GlobalLogic.ToxicityStage.HIGH:
			speed_multiplier = 0.65
		GlobalLogic.ToxicityStage.OVERDOSE:
			speed_multiplier = 0.40

func _physics_process(delta: float) -> void:
	if GlobalLogic.is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0 and not is_attacking:
		combo_index = 0

	if locked_target != null:
		if not is_instance_valid(locked_target) or locked_target.get("is_dead") == true or global_position.distance_to(locked_target.global_position) > 22.0:
			locked_target = null

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and coyote_timer > 0.0 and not is_attacking and not is_drinking:
		velocity.y = jump_force
		coyote_timer = 0.0
		_spawn_footstep_dust()
		_play_footstep_sound()

	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and not is_drinking
	var base_speed := run_speed if is_sprinting else walk_speed
	var target_speed := base_speed * speed_multiplier
	if is_drinking:
		target_speed = walk_speed * drink_speed_multiplier

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := _get_camera_relative_direction(input_dir)

	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		dash_ghost_timer -= delta
		if dash_ghost_timer <= 0.0:
			dash_ghost_timer = dash_ghost_interval
			_spawn_ghost_trail()
		if dash_timer <= 0.0:
			is_dashing = false
			is_invulnerable = false
			mesh_instance.rotation.x = 0.0
			mesh_instance.scale = Vector3.ONE
			if _get_model_material_override() == dash_material:
				_set_model_material_override(null)
	elif lunge_timer > 0.0:
		lunge_timer -= delta
		velocity.x = lunge_direction.x * attack_lunge_speed
		velocity.z = lunge_direction.z * attack_lunge_speed
	elif is_attacking:
		# Selama combo attack, redam velocity gerak agar animasi serangan memimpin pergerakan
		velocity.x = move_toward(velocity.x, 0.0, target_speed * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, target_speed * 3.0 * delta)
	elif knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = move_toward(velocity.x, direction.x * target_speed, received_knockback_damping * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, received_knockback_damping * delta)
	elif is_on_floor():
		if direction:
			velocity.x = direction.x * target_speed
			velocity.z = direction.z * target_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, target_speed)
			velocity.z = move_toward(velocity.z, 0.0, target_speed)
	else:
		var target_vel_x := direction.x * target_speed
		var target_vel_z := direction.z * target_speed
		velocity.x = lerpf(velocity.x, target_vel_x, air_control)
		velocity.z = lerpf(velocity.z, target_vel_z, air_control)

	var is_strafe_active: bool = (locked_target != null and is_instance_valid(locked_target)) or is_holding_z_target
	var cam_basis: Basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var cam_forward: Vector3 = -cam_basis.z
	cam_forward.y = 0.0
	var cam_look_yaw: float = atan2(cam_forward.x, cam_forward.z)

	if locked_target and is_instance_valid(locked_target):
		var to_enemy: Vector3 = locked_target.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.01:
			var target_yaw := atan2(to_enemy.x, to_enemy.z)
			mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, target_yaw, lock_on_turn_speed * delta)
	elif is_attacking:
		# Selama serangan combo berlangsung, kunci arah hadap karakter agar tidak terpelintir
		pass
	elif is_strafe_active:
		# Mode Z-Targeting (RMB ditahan): Badan selalu menghadap ke arah pandangan kamera (ke depan menjauhi kamera)
		mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, cam_look_yaw, body_turn_speed * delta)
	elif body_turn_with_camera and direction.length() < 0.1:
		# Saat kamera diputar dengan mouse saat diam, badan karakter ikut berputar menghadap arah pandangan kamera ke depan!
		mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, cam_look_yaw, body_turn_speed * delta)
	elif direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		mesh_instance.rotation.y = lerp_angle(mesh_instance.rotation.y, target_angle, 12.0 * delta)

	_prev_vertical_velocity = velocity.y
	_was_on_floor_prev = is_on_floor()

	move_and_slide()

	# Deteksi pendaratan tanah (Landing impact dust & subtle thud)
	if not _was_on_floor_prev and is_on_floor() and _prev_vertical_velocity < landing_impact_threshold:
		_spawn_footstep_dust()
		_play_footstep_sound()
		if _prev_vertical_velocity < -7.0:
			_spawn_ground_slam_shockwave(global_position + Vector3(0.0, 0.03, 0.0), 0.85)
			if camera_pivot and camera_pivot.has_method("add_trauma"):
				camera_pivot.add_trauma(0.35)

	# Langkah kaki saat bergerak di atas lantai
	if is_on_floor() and not is_dashing:
		var horiz_vel := Vector2(velocity.x, velocity.z).length()
		if horiz_vel > 0.4:
			var step_interval := footstep_interval_run if is_sprinting else footstep_interval_walk
			step_interval = step_interval / clampf(speed_multiplier, 0.4, 1.2)
			_footstep_timer -= delta
			if _footstep_timer <= 0.0:
				_footstep_timer = step_interval
				_spawn_footstep_dust()
				_play_footstep_sound()
		else:
			_footstep_timer = 0.08
	else:
		_footstep_timer = 0.08

	_update_animation(direction, is_sprinting)

func _update_animation(direction: Vector3, is_sprinting: bool) -> void:
	if not animation_player or GlobalLogic.is_dead:
		return

	if is_attacking or is_drinking:
		return

	if not is_on_floor():
		if animation_player.has_animation("jump"):
			_play_anim("jump")
		elif animation_player.has_animation("jump_idle"):
			_play_anim("jump_idle")
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := horizontal_speed > 0.15 and direction.length_squared() > 0.01

	if is_moving:
		if is_sprinting and animation_player.has_animation("run"):
			_play_anim("run", clampf(horizontal_speed / run_speed, 0.75, 1.4))
		elif animation_player.has_animation("walk"):
			_play_anim("walk", clampf(horizontal_speed / walk_speed, 0.75, 1.5))
		elif animation_player.has_animation("walk_a"):
			_play_anim("walk_a", clampf(horizontal_speed / walk_speed, 0.75, 1.5))
	else:
		if animation_player.has_animation("idle"):
			_play_anim("idle", 1.0)

func _play_anim(anim_name: StringName, speed_scale: float = 1.0) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)
	animation_player.speed_scale = speed_scale

func _get_camera_relative_direction(input: Vector2) -> Vector3:
	var cam_basis := camera_pivot.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (forward * -input.y + right * input.x).normalized()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.keycode == KEY_TAB:
			handle_z_target_input()
		elif event.keycode == KEY_SHIFT:
			dash()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_holding_z_target = true
				_rmb_press_time = Time.get_ticks_msec()
				if locked_target != null:
					locked_target = null
				else:
					handle_z_target_input()
			else:
				var hold_dur := (Time.get_ticks_msec() - _rmb_press_time) / 1000.0
				is_holding_z_target = false
				if hold_dur > 0.22 and locked_target != null:
					locked_target = null
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			handle_z_target_input()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_attack and not GlobalLogic.is_dead:
				attack()

func dash() -> void:
	if is_dashing or dash_cooldown_timer > 0.0 or GlobalLogic.is_dead or is_drinking:
		return

	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	is_invulnerable = true
	dash_ghost_timer = 0.0

	if not dash_material:
		_setup_dash_material()
	dash_material.albedo_color = Color(dash_ghost_color.r, dash_ghost_color.g, dash_ghost_color.b, 0.85)
	_set_model_material_override(dash_material)

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_dir := _get_camera_relative_direction(input_dir)

	var target_candidate: Node3D = locked_target if (locked_target and is_instance_valid(locked_target)) else _find_soft_target()
	if target_candidate and is_instance_valid(target_candidate):
		var to_enemy: Vector3 = target_candidate.global_position - global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		if input_dir.length_squared() > 0.1:
			dash_direction = move_dir
		elif dist > 1.2:
			dash_direction = to_enemy.normalized()
		else:
			dash_direction = -to_enemy.normalized()

		if dash_direction.length_squared() > 0.01:
			mesh_instance.rotation.y = atan2(dash_direction.x, dash_direction.z)
	elif move_dir.length_squared() > 0.01:
		dash_direction = move_dir
		mesh_instance.rotation.y = atan2(dash_direction.x, dash_direction.z)
	else:
		dash_direction = Vector3(sin(mesh_instance.rotation.y), 0.0, cos(mesh_instance.rotation.y)).normalized()

	var tw := create_tween()
	mesh_instance.scale = Vector3(1.25, 0.50, 1.50)
	mesh_instance.rotation.x = deg_to_rad(24.0)

	tw.set_parallel(true)
	tw.tween_property(mesh_instance, "scale", Vector3.ONE, dash_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mesh_instance, "rotation:x", 0.0, dash_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if camera_pivot and camera_pivot.has_method("fov_punch"):
		camera_pivot.fov_punch(-4.5, dash_duration + 0.10)

	_spawn_dash_wind_effect(dash_direction)
	_spawn_ghost_trail()

func _spawn_dash_wind_effect(dir: Vector3) -> void:
	if not is_inside_tree() or not DASH_WIND_SCENE:
		return
	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if not parent_node:
		return
	var wind := DASH_WIND_SCENE.instantiate() as DashWindEffect
	if not wind:
		return
	parent_node.add_child(wind)
	wind.global_position = global_position + Vector3(0.0, 0.85, 0.0)
	wind.setup(dir)

func _spawn_ghost_trail() -> void:
	if not is_inside_tree() or not DASH_GHOST_SCENE:
		return

	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if not parent_node:
		return

	var ghost := DASH_GHOST_SCENE.instantiate() as DashGhost
	if not ghost:
		return

	parent_node.add_child(ghost)
	ghost.global_position = mesh_instance.global_position + Vector3(0.0, 1.0, 0.0)
	ghost.global_rotation = mesh_instance.global_rotation
	ghost.scale = mesh_instance.scale
	ghost.start_fade(dash_ghost_color)

## Memproses input tombol Z-Targeting (RMB / Q / Tab / MMB) ala The Legend of Zelda:
## - Jika ada target musuh terdekat: Kunci musuh (Lock-on).
## - Jika sedang mengunci musuh: Lepaskan kunci (Unlock).
## - Jika tidak ada musuh di sekitar: Reset/snap kamera ke belakang punggung karakter (Z-Snap).
func handle_z_target_input() -> void:
	if locked_target != null:
		locked_target = null
		return

	var candidate := _find_best_target()
	if candidate:
		locked_target = candidate
	else:
		if camera_pivot and camera_pivot.has_method("snap_behind_player"):
			camera_pivot.snap_behind_player(mesh_instance.global_rotation.y)

func toggle_lock_on() -> void:
	handle_z_target_input()

func _find_best_target() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_score: float = -99999.0

	var cam_basis: Basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var cam_forward: Vector3 = -cam_basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()

	for enemy in enemies:
		var enemy_node := enemy as Node3D
		if not enemy_node or not is_instance_valid(enemy_node):
			continue
		if enemy_node.get("is_dead") == true or not enemy_node.visible:
			continue

		var to_enemy: Vector3 = enemy_node.global_position - global_position
		to_enemy.y = 0.0
		var dist: float = to_enemy.length()
		if dist > lock_on_max_distance or dist < 0.1:
			continue

		var dir: Vector3 = to_enemy.normalized()
		var dot: float = cam_forward.dot(dir)
		if dot < 0.2:
			continue

		var score: float = (dot * 24.0) - dist
		if score > best_score:
			best_score = score
			best_target = enemy_node

	return best_target

func _find_soft_target() -> Node3D:
	if not auto_target_enabled:
		return null

	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_target: Node3D = null
	var best_score: float = -99999.0

	var cam_basis: Basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var desire_dir: Vector3 = _get_camera_relative_direction(input_dir) if input_dir.length_squared() > 0.05 else forward

	for enemy in enemies:
		var enemy_node := enemy as Node3D
		if not enemy_node or not is_instance_valid(enemy_node):
			continue
		if enemy_node.get("is_dead") == true or not enemy_node.visible:
			continue

		var to_enemy: Vector3 = enemy_node.global_position - global_position
		to_enemy.y = 0.0
		var dist: float = to_enemy.length()
		if dist > auto_target_radius or dist < 0.01:
			continue

		var dir: Vector3 = to_enemy.normalized()
		var dot: float = desire_dir.dot(dir)

		if dist <= auto_target_point_blank_radius:
			var score: float = 100.0 - dist * 8.0
			if score > best_score:
				best_score = score
				best_target = enemy_node
		elif dot >= cos(deg_to_rad(auto_target_cone_deg * 0.5)):
			var score: float = (dot * 16.0) - (dist / auto_target_radius * 8.0)
			if score > best_score:
				best_score = score
				best_target = enemy_node

	return best_target

const COMBO_ANIMATIONS: Array[StringName] = [&"slash_1", &"slash_2", &"slash_3"]

func attack() -> void:
	if not can_attack or GlobalLogic.is_dead or is_drinking:
		return

	can_attack = false
	is_attacking = true
	_hit_targets_this_swing.clear()

	var current_step: int = combo_index % COMBO_ANIMATIONS.size()
	var anim_name: StringName = COMBO_ANIMATIONS[current_step]
	var anim_speed: float = combo_speed_scales[current_step] if current_step < combo_speed_scales.size() else 1.8
	var attack_dur: float = combo_durations[current_step] if current_step < combo_durations.size() else 0.45
	_current_combo_damage_mult = combo_damage_multipliers[current_step] if current_step < combo_damage_multipliers.size() else 1.0
	_current_combo_kb_mult = combo_knockback_multipliers[current_step] if current_step < combo_knockback_multipliers.size() else 1.0

	# Catat posisi awal rig sebelum animasi diputar
	if character_rig:
		_attack_start_rig_pos = character_rig.position

	# Hadapkan karakter ke target saat lock-on, atau hadapkan ke input arah gerak (WASD) / arah kamera
	if locked_target and is_instance_valid(locked_target):
		var to_enemy: Vector3 = locked_target.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.01:
			mesh_instance.rotation.y = atan2(to_enemy.x, to_enemy.z)
	else:
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir.length_squared() > 0.1:
			var move_dir := _get_camera_relative_direction(input_dir)
			if move_dir.length_squared() > 0.01:
				mesh_instance.rotation.y = atan2(move_dir.x, move_dir.z)
		else:
			var cam_basis: Basis = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
			var forward: Vector3 = -cam_basis.z
			forward.y = 0.0
			if forward.length_squared() > 0.01:
				mesh_instance.rotation.y = atan2(forward.x, forward.z)

	# Mainkan animasi serangan di AnimationPlayer
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.stop()
		animation_player.play(anim_name, -1.0, anim_speed)

	# Fase ayunan aktif (wind-up selesai, pedang menyapu maju ke arah musuh)
	var hit_start_time: float = combo_hit_delays[current_step] if current_step < combo_hit_delays.size() else (attack_dur * 0.16)
	var hit_active_duration: float = combo_hit_durations[current_step] if current_step < combo_hit_durations.size() else (attack_dur * 0.38)

	# Untuk combo finisher #3 (slash_3), timing hit tepat saat pedang mendarat dan menghantam tanah (keyframe 1.50s pada klip animasi)
	if current_step == 2:
		hit_start_time = 1.50 / anim_speed

	await get_tree().create_timer(hit_start_time).timeout
	if not is_inside_tree() or GlobalLogic.is_dead:
		return

	# TEPAT saat pedang mengayun maju atau menghantam tanah: pemicu efek visual tebasan & dorongan lunge!
	_trigger_slash_arc(current_step, hit_active_duration)
	_perform_attack_lunge(current_step)

	if current_step == 2:
		var slam_forward := mesh_instance.global_transform.basis.z if mesh_instance else global_transform.basis.z
		slam_forward.y = 0.0
		slam_forward = slam_forward.normalized()
		var slam_pos := global_position + (slam_forward * 1.45)
		slam_pos.y = global_position.y + 0.03
		_spawn_ground_slam_shockwave(slam_pos, 1.5)

		# Pemicu letupan percikan tanah pada titik impak hantaman
		var ground_spark: Node3D = HIT_SPARK_PREFAB.instantiate() as Node3D
		if ground_spark:
			var p_node := get_parent() if get_parent() else get_tree().current_scene
			if p_node:
				p_node.add_child(ground_spark)
				ground_spark.global_position = slam_pos
				ground_spark.setup(Color(1.0, 0.70, 0.25, 1.0), Vector3.UP)

		if camera_pivot:
			if camera_pivot.has_method("add_trauma"):
				camera_pivot.add_trauma(0.65)
			if camera_pivot.has_method("fov_punch"):
				camera_pivot.fov_punch(2.8, 0.22)

	hitbox.monitoring = true
	var bodies := hitbox.get_overlapping_bodies()
	for b in bodies:
		var target := _resolve_damage_target(b)
		if target:
			_apply_hit_to_target(target)

	await get_tree().create_timer(hit_active_duration).timeout
	if not is_inside_tree():
		return
	hitbox.monitoring = false

	var remaining_time: float = maxf(0.01, attack_dur - (hit_start_time + hit_active_duration))
	await get_tree().create_timer(remaining_time).timeout
	if not is_inside_tree() or GlobalLogic.is_dead:
		return

	# Terapkan pergeseran root motion animasi ke posisi fisik karakter
	_apply_animation_root_displacement()

	# Selesaikan serangan dan perbarui urutan combo
	is_attacking = false
	combo_index = (combo_index + 1) % COMBO_ANIMATIONS.size()
	combo_timer = combo_window

	# Jeda cooldown kecil sebelum pukulan berikutnya bisa dimulai
	await get_tree().create_timer(0.04).timeout
	can_attack = true

func _apply_animation_root_displacement() -> void:
	if not character_rig or not mesh_instance:
		return
	var current_rig_pos: Vector3 = character_rig.position
	var delta_local: Vector3 = current_rig_pos - _attack_start_rig_pos
	delta_local.y = 0.0
	if delta_local.length_squared() > 0.0004:
		var world_displacement: Vector3 = mesh_instance.global_transform.basis * delta_local
		move_and_collide(world_displacement)
		character_rig.position -= delta_local

func _resolve_damage_target(node: Node) -> Node:
	if not node or node == self:
		return null
	var curr: Node = node
	for _i in range(4):
		if not curr or curr == self:
			break
		if curr.has_method("take_damage"):
			return curr
		curr = curr.get_parent()
	return null

func _apply_hit_to_target(target: Node) -> void:
	if not target or target == self or not target.has_method("take_damage"):
		return
	if _hit_targets_this_swing.has(target):
		return
	_hit_targets_this_swing.append(target)

	var damage := base_damage * _current_combo_damage_mult
	var kb_force: float = base_knockback_force * _current_combo_kb_mult
	if GlobalLogic.is_berserk_active:
		damage *= berserk_damage_multiplier
		kb_force *= berserk_knockback_multiplier
	elif GlobalLogic.is_strength_active:
		damage *= strength_damage_multiplier
		kb_force *= strength_knockback_multiplier

	var to_body: Vector3 = target.global_position - global_position
	to_body.y = 0.0
	var knockback_dir: Vector3 = to_body.normalized() if to_body.length_squared() > 0.01 else -global_transform.basis.z
	knockback_dir.y = knockback_lift
	knockback_dir = knockback_dir.normalized()

	target.take_damage(damage, knockback_dir * kb_force)

	# 1. Pemicu efek visual percikan benturan tebasan (Hit Spark)
	var spark_inst: Node3D = HIT_SPARK_PREFAB.instantiate() as Node3D
	if spark_inst:
		var p_node := get_parent() if get_parent() else get_tree().current_scene
		if p_node:
			p_node.add_child(spark_inst)
			var spark_pos: Vector3 = (target.global_position as Vector3) + Vector3(0.0, 0.95, 0.0) if target is Node3D else global_position
			spark_inst.global_position = spark_pos
			var hit_spark_color := Color(0.35, 0.90, 1.0, 1.0)
			if GlobalLogic.is_berserk_active:
				hit_spark_color = Color(1.0, 0.25, 0.08, 1.0)
			elif GlobalLogic.is_strength_active:
				hit_spark_color = Color(1.0, 0.88, 0.20, 1.0)
			elif combo_index == 2:
				hit_spark_color = Color(1.0, 0.65, 0.15, 1.0)
			spark_inst.setup(hit_spark_color, knockback_dir)

	# 2. Audio hantaman tebasan pedang ke musuh (Slash Hit SFX)
	if slash_hit_audio:
		slash_hit_audio.pitch_scale = randf_range(0.92, 1.08)
		slash_hit_audio.play()

	GlobalLogic.hit_stop(0.05, 0.05)
	if camera_pivot:
		var is_buffed: bool = GlobalLogic.is_berserk_active or GlobalLogic.is_strength_active
		var trauma_base: float = 0.75 if (combo_index == 2) else (0.50 if (combo_index == 1) else 0.38)
		var punch_base: float = 3.0 if (combo_index == 2) else (2.0 if (combo_index == 1) else 1.4)
		var trauma_val: float = trauma_base * (1.3 if is_buffed else 1.0)
		var punch_val: float = punch_base * (1.4 if is_buffed else 1.0)
		if camera_pivot.has_method("add_trauma"):
			camera_pivot.add_trauma(trauma_val)
		if camera_pivot.has_method("fov_punch"):
			camera_pivot.fov_punch(punch_val)

func _on_hitbox_body_entered(body: Node) -> void:
	if not is_attacking or body == self:
		return
	var target := _resolve_damage_target(body)
	if target:
		_apply_hit_to_target(target)

func _setup_flash_material() -> void:
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

func _on_player_died() -> void:
	if _drink_tween and _drink_tween.is_valid():
		_drink_tween.kill()
	is_drinking = false
	if is_instance_valid(potion_bottle_instance):
		potion_bottle_instance.visible = false
	if _hit_blink_tween:
		_hit_blink_tween.kill()
	if is_instance_valid(mesh_instance):
		_set_model_material_override(null)
		mesh_instance.visible = true
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")

func _trigger_hit_feedback() -> void:
	if not mesh_instance or not flash_material:
		return

	if _hit_blink_tween:
		_hit_blink_tween.kill()

	flash_material.albedo_color = Color(1.0, 0.2, 0.2, 0.95)
	_set_model_material_override(flash_material)
	mesh_instance.visible = true

	_hit_blink_tween = create_tween()
	_hit_blink_tween.tween_interval(hit_flash_duration)
	_hit_blink_tween.tween_callback(func():
		if is_instance_valid(mesh_instance):
			_set_model_material_override(null)
	)

	var remaining_time: float = maxf(0.0, invulnerability_duration - hit_flash_duration)
	var cycles: int = int(remaining_time / (hit_blink_interval * 2.0))
	for i in range(cycles):
		_hit_blink_tween.tween_callback(func():
			if is_instance_valid(mesh_instance):
				mesh_instance.visible = false
		)
		_hit_blink_tween.tween_interval(hit_blink_interval)
		_hit_blink_tween.tween_callback(func():
			if is_instance_valid(mesh_instance):
				mesh_instance.visible = true
		)
		_hit_blink_tween.tween_interval(hit_blink_interval)

	_hit_blink_tween.tween_callback(func():
		if is_instance_valid(mesh_instance):
			mesh_instance.visible = true
			_set_model_material_override(null)
		is_invulnerable = false
	)

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, is_sharp: bool = false) -> void:
	if is_invulnerable or GlobalLogic.is_dead:
		return

	if is_sharp and GlobalLogic.is_ironskin_active:
		_trigger_ironskin_deflection()
		return

	is_invulnerable = true
	GlobalLogic.modify_hp(-amount)
	_spawn_player_floating_text("-%d" % roundi(amount), Color(1.0, 0.22, 0.25, 1.0), 38, 0.85, 0.6)

	if knockback.length_squared() > 0.01:
		velocity = knockback
		knockback_timer = received_knockback_duration

	var tween := create_tween()
	mesh_instance.scale = Vector3(0.8, 1.25, 0.8)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if camera_pivot:
		if camera_pivot.has_method("add_trauma"):
			camera_pivot.add_trauma(hit_trauma_shake)
		if camera_pivot.has_method("fov_punch"):
			camera_pivot.fov_punch(2.0)

	_trigger_hit_feedback()
	if is_drinking:
		is_drinking = false
		if _drink_tween and _drink_tween.is_valid():
			_drink_tween.kill()
		if is_instance_valid(potion_bottle_instance):
			potion_bottle_instance.visible = false
	if animation_player and animation_player.has_animation("hit") and not GlobalLogic.is_dead:
		animation_player.play("hit")
		animation_player.queue("idle")

func _on_potion_consumed(potion_name: String) -> void:
	_play_drink_sequence(potion_name)

	var flash_col := Color(0.25, 1.0, 0.5, 0.95)
	match potion_name:
		"healing":
			flash_col = Color(0.25, 1.0, 0.5, 0.95)
			_spawn_player_floating_text("+35 HP", Color(0.35, 1.0, 0.5, 1.0), 32, 0.75, 0.6)
			await get_tree().create_timer(0.08).timeout
			_spawn_player_floating_text("+15 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.95, 0.6)
		"strength":
			flash_col = Color(1.0, 0.75, 0.2, 0.95)
			_spawn_player_floating_text("+20 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.85, 0.6)
		"slow":
			flash_col = Color(0.3, 0.85, 1.0, 0.95)
			_spawn_player_floating_text("+15 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.85, 0.6)
		"berserk":
			flash_col = Color(1.0, 0.15, 0.25, 0.98)
			_spawn_player_floating_text("+35 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.85, 0.6)
		"ironskin":
			flash_col = Color(0.9, 0.95, 1.0, 0.95)
			_spawn_player_floating_text("+20 Toxic", Color(0.2, 0.95, 0.5, 1.0), 32, 0.85, 0.6)
	_trigger_potion_mesh_flash(flash_col)

	if mesh_instance:
		mesh_instance.scale = Vector3(1.15, 0.85, 1.15)
		var tw := create_tween()
		tw.tween_property(mesh_instance, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Memutar urutan visual minum ramuan, memunculkan botol dengan warna ramuan dan memainkan animasi drink.
func _play_drink_sequence(potion_name: String) -> void:
	if not potion_bottle_instance:
		_setup_bottle_attachment()

	if potion_bottle_instance:
		if potion_bottle_instance.has_method("set_potion_type"):
			potion_bottle_instance.set_potion_type(potion_name)
		potion_bottle_instance.visible = true

	is_drinking = true

	if _drink_tween and _drink_tween.is_valid():
		_drink_tween.kill()

	if animation_player and animation_player.has_animation("drink"):
		animation_player.play("drink", 0.12, 1.0)

	_drink_tween = create_tween()
	_drink_tween.tween_interval(1.58)
	_drink_tween.tween_callback(func():
		is_drinking = false
		if is_instance_valid(potion_bottle_instance):
			potion_bottle_instance.visible = false
		if animation_player and animation_player.current_animation == "drink":
			animation_player.play("idle", 0.15)
	)

func _trigger_potion_mesh_flash(col: Color = Color(0.25, 1.0, 0.5, 0.85)) -> void:
	if not mesh_instance or not flash_material:
		return
	flash_material.albedo_color = col
	_set_model_material_override(flash_material)
	var tw := create_tween()
	tw.tween_interval(0.14)
	tw.tween_callback(func():
		if is_instance_valid(mesh_instance) and not is_invulnerable:
			_set_model_material_override(null)
	)

func _spawn_player_floating_text(display_text: String, text_color: Color, size: int = 32, rise: float = 0.85, duration: float = 0.6) -> void:
	if not FLOATING_TEXT_SCENE or not is_inside_tree():
		return
	var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
	if not label:
		return
	var spawn_pos := global_position + Vector3(randf_range(-0.15, 0.15), 1.2, randf_range(-0.15, 0.15))
	if get_parent():
		get_parent().add_child(label)
	else:
		get_tree().root.add_child(label)
	label.global_position = spawn_pos
	label.pop(display_text, text_color, size, rise, duration)

func _trigger_ironskin_deflection() -> void:
	if deflect_audio:
		deflect_audio.play()

	if FLOATING_TEXT_SCENE:
		var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
		if label:
			get_tree().root.add_child(label)
			label.global_position = global_position + Vector3(0.0, 1.2, 0.0)
			label.pop("DEFLECTED!", Color(0.92, 0.94, 0.98, 1.0), 28, 0.85, 0.55)

	if camera_pivot and camera_pivot.has_method("add_trauma"):
		camera_pivot.add_trauma(0.18)

static var _cached_footstep_wav: AudioStreamWAV = null

func _play_footstep_sound() -> void:
	if not footstep_audio:
		return
	if not _cached_footstep_wav:
		_cached_footstep_wav = _generate_footstep_wav()
	footstep_audio.stream = _cached_footstep_wav
	footstep_audio.pitch_scale = randf_range(0.88, 1.12)
	footstep_audio.play()

static func _generate_footstep_wav() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.055
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var env := exp(-t * 70.0)
		var freq := lerpf(160.0, 50.0, t / dur)
		var noise := (randf() * 2.0 - 1.0) * 0.35
		var tone := sin(t * freq * TAU) * 0.65
		var val := int((tone + noise) * env * 0.32 * 32767.0)
		buffer.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	return wav

static func _generate_slash_whoosh_wav() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var duration := 0.22
	var total_frames := int(sample_hz * duration)
	var buffer := PackedByteArray()
	buffer.resize(total_frames * 2)

	for i in range(total_frames):
		var t := float(i) / sample_hz
		var progress := t / duration
		var env := pow(sin(progress * PI), 1.6)
		var sweep := lerpf(400.0, 1800.0, sin(progress * PI))
		var tone := sin(t * sweep * TAU) * 0.4
		var noise := (randf() * 2.0 - 1.0) * 0.6
		var sample := (tone + noise) * env * 0.85
		var val := int(clampf(sample, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	return wav

static func _generate_slash_hit_wav() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var duration := 0.16
	var total_frames := int(sample_hz * duration)
	var buffer := PackedByteArray()
	buffer.resize(total_frames * 2)

	for i in range(total_frames):
		var t := float(i) / sample_hz
		var progress := t / duration
		var env := exp(-progress * 14.0)
		var ping := sin(t * 1250.0 * TAU) * 0.5 + sin(t * 2600.0 * TAU) * 0.3
		var crunch := (randf() * 2.0 - 1.0) * 0.5 * exp(-progress * 22.0)
		var thump := sin(t * 110.0 * TAU) * 0.6 * exp(-progress * 18.0)
		var sample := (ping + crunch + thump) * env * 0.95
		var val := int(clampf(sample, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	return wav

func _spawn_footstep_dust() -> void:
	if not FOOTSTEP_DUST_SCENE or not is_inside_tree():
		return
	var dust := FOOTSTEP_DUST_SCENE.instantiate() as Node3D
	if not dust:
		return
	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if not parent_node:
		return
	parent_node.add_child(dust)

	_foot_alternator = not _foot_alternator
	var lateral_sign := 1.0 if _foot_alternator else -1.0
	var side_dir := mesh_instance.global_transform.basis.x if mesh_instance else global_transform.basis.x
	var backward_dir := -(mesh_instance.global_transform.basis.z if mesh_instance else global_transform.basis.z)
	var dust_pos := global_position + (side_dir * footstep_dust_offset_lateral * lateral_sign) + (backward_dir * 0.12)
	dust_pos.y = global_position.y + 0.04
	dust.global_position = dust_pos

func _spawn_ground_slam_shockwave(pos: Vector3, scale_mult: float = 1.0) -> void:
	if not GROUND_SLAM_SCENE or not is_inside_tree():
		return
	var shockwave := GROUND_SLAM_SCENE.instantiate() as Node3D
	if not shockwave:
		return
	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if not parent_node:
		return
	parent_node.add_child(shockwave)
	shockwave.global_position = pos
	shockwave.scale = Vector3.ONE * scale_mult
