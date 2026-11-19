class_name BossMage
extends CharacterBody3D

signal phase_changed(new_phase: int)
signal damaged(amount: float)
signal defeated()

const MAGIC_ORB_SCENE: PackedScene = preload("res://magic_orb_projectile.tscn")
const MAGIC_AOE_SCENE: PackedScene = preload("res://magic_aoe_rune.tscn")
const SHOCKWAVE_SCENE: PackedScene = preload("res://shockwave_ring.tscn")
const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")
const SLIME_MINION_SCENE: PackedScene = preload("res://dummy_slime.tscn")
const ITEM_DROP_SCENE: PackedScene = preload("res://item_drop.tscn")

enum State {
	IDLE,
	CHASE,
	CAST_ORB,
	CAST_AOE,
	SLAM_SHOCKWAVE,
	BARRAGE,
	TELEPORTING,
	PHASE_TRANSITION,
	DEAD
}

@export_group("Stats")
@export var max_health: float = 180.0
@export var phase_2_threshold: float = 120.0
@export var phase_3_threshold: float = 60.0
@export var exit_portal: NodePath = NodePath("../Exit")

@export_group("Movement")
@export var base_speed: float = 3.2
@export var chase_speed_p2: float = 6.8
@export var slowed_speed: float = 2.2
@export var turn_speed: float = 6.0
@export var gravity: float = 18.0

@export_group("Phase 1 - Crystal Aegis")
@export var p1_cast_interval: float = 2.4
@export var p1_aoe_interval: float = 6.0
@export var p1_unbuffed_damage_cap: float = 0.0

@export_group("Phase 2 - Chrono Distortion")
@export var p2_cast_interval: float = 1.4
@export var p2_shockwave_interval: float = 5.2
@export var p2_teleport_distance: float = 8.5
@export var p2_melee_evade_radius: float = 4.2

@export_group("Phase 3 - Toxic Flak Barrage")
@export var p3_barrage_interval: float = 2.2
@export var p3_spiral_bullets: int = 14

var current_health: float = 180.0
var current_phase: int = 1
var current_state: State = State.IDLE
var is_dead: bool = false
var player_ref: Node3D = null
var _has_engaged_hud: bool = false

var _action_timer: float = 0.0
var _aoe_timer: float = 0.0
var _shockwave_timer: float = 0.0
var _teleport_cooldown: float = 0.0
var _barrage_timer: float = 0.0

var _hp_lag_tween: Tween = null
var _flash_tween: Tween = null
var _cached_mesh_instances: Array[MeshInstance3D] = []
static var _hit_flash_material: StandardMaterial3D = null

@onready var visual_root: Node3D = $VisualRoot if has_node("VisualRoot") else null
@onready var animation_player: AnimationPlayer = ($VisualRoot/Skeleton_Mage/AnimationPlayer if has_node("VisualRoot/Skeleton_Mage/AnimationPlayer") else ($VisualRoot/AnimationPlayer if has_node("VisualRoot/AnimationPlayer") else null))
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var cast_point: Marker3D = $CastPoint if has_node("CastPoint") else null
@onready var staff_crystal: Node3D = find_child("Crystal", true, false) as Node3D
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer if has_node("AudioPlayer") else null

@onready var hp_viewport: SubViewport = $HpViewport if has_node("HpViewport") else null
@onready var hp_sprite: Sprite3D = $HpSprite if has_node("HpSprite") else null
@onready var hp_bar: ProgressBar = $HpViewport/Panel/VBox/Bars/HpBar if has_node("HpViewport/Panel/VBox/Bars/HpBar") else null
@onready var hp_lag_bar: ProgressBar = $HpViewport/Panel/VBox/Bars/HpLagBar if has_node("HpViewport/Panel/VBox/Bars/HpLagBar") else null
@onready var phase_label: Label = $HpViewport/Panel/VBox/Header/PhaseLabel if has_node("HpViewport/Panel/VBox/Header/PhaseLabel") else null

static var _cached_teleport_wav: AudioStreamWAV = null
static var _cached_deflect_wav: AudioStreamWAV = null
static var _cached_roar_wav: AudioStreamWAV = null
static var _cached_cast_wav: AudioStreamWAV = null

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	current_phase = 1
	_ensure_cached_audio()
	_setup_health_bar()
	_update_phase_hud()
	_setup_mesh_flash()

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as Node3D
		var to_p := player_ref.global_position - global_position
		to_p.y = 0.0
		if to_p.length_squared() > 0.01:
			rotation.y = atan2(to_p.x, to_p.z)

	if animation_player:
		_play_anim(&"idle")
	if hp_sprite:
		hp_sprite.visible = false

func _setup_mesh_flash() -> void:
	_cached_mesh_instances.clear()
	if visual_root:
		for child in visual_root.find_children("*", "MeshInstance3D"):
			if child is MeshInstance3D and not child.name.contains("Staff") and not child.name.contains("Crystal"):
				_cached_mesh_instances.append(child as MeshInstance3D)
	if not _hit_flash_material:
		_hit_flash_material = StandardMaterial3D.new()
		_hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hit_flash_material.albedo_color = Color(2.5, 2.5, 2.5, 1.0)

func _setup_health_bar() -> void:
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
	if hp_lag_bar:
		hp_lag_bar.max_value = max_health
		hp_lag_bar.value = current_health
	_refresh_hp_viewport()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_find_player_if_missing()

	if _teleport_cooldown > 0.0:
		_teleport_cooldown -= delta

	match current_state:
		State.IDLE, State.CHASE:
			_process_combat_ai(delta)
		State.CAST_ORB, State.CAST_AOE, State.SLAM_SHOCKWAVE, State.BARRAGE:
			# Berdiri diam saat merapal mantra
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		State.PHASE_TRANSITION, State.TELEPORTING, State.DEAD:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()

func _find_player_if_missing() -> void:
	if not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as Node3D

func _process_combat_ai(delta: float) -> void:
	if not is_instance_valid(player_ref) or GlobalLogic.is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var to_player: Vector3 = player_ref.global_position - global_position
	var dist: float = to_player.length()

	if not _has_engaged_hud and dist < 22.0:
		_has_engaged_hud = true
		GlobalLogic.trigger_boss_engaged("ARCHMAGE MALAKOR", max_health, current_health)

	# Rotasi menghadap pemain secara halus (model Skeleton_Mage menghadap sumbu +Z)
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		var target_yaw := atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

	# Mekanik Fase 2: Chrono Distortion Teleport jika pemain mendekat TANPA efek Slow
	if current_phase == 2 and not GlobalLogic.is_potion_active("slow"):
		if dist < p2_melee_evade_radius and _teleport_cooldown <= 0.0:
			_teleport_away_from_player()
			return

	# Pengecekan Timer Aksi berdasarkan Fase
	_action_timer += delta
	_aoe_timer += delta
	_shockwave_timer += delta
	_barrage_timer += delta

	match current_phase:
		1:
			_process_phase_1(dist, delta)
		2:
			_process_phase_2(dist, delta)
		3:
			_process_phase_3(dist, delta)

func _process_phase_1(dist: float, delta: float) -> void:
	var desired_distance: float = 7.0
	if dist > desired_distance + 1.5:
		_move_towards(player_ref.global_position, base_speed, delta)
	elif dist < desired_distance - 1.5:
		_move_towards(global_position - (player_ref.global_position - global_position), base_speed * 0.8, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
		_play_anim("idle")

	if _aoe_timer >= p1_aoe_interval:
		_aoe_timer = 0.0
		_cast_aoe_rune()
	elif _action_timer >= p1_cast_interval:
		_action_timer = 0.0
		_cast_single_orb()

func _process_phase_2(dist: float, delta: float) -> void:
	var speed: float = slowed_speed if GlobalLogic.is_potion_active("slow") else chase_speed_p2
	var cast_int: float = p2_cast_interval * (2.2 if GlobalLogic.is_potion_active("slow") else 1.0)

	var desired_distance: float = 6.0
	if dist > desired_distance + 1.0:
		_move_towards(player_ref.global_position, speed, delta)
	elif dist < desired_distance - 1.0:
		_move_towards(global_position - (player_ref.global_position - global_position), speed, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		_play_anim("idle")

	if _shockwave_timer >= p2_shockwave_interval:
		_shockwave_timer = 0.0
		_slam_shockwave()
	elif _action_timer >= cast_int:
		_action_timer = 0.0
		_cast_triple_orbs()

func _process_phase_3(dist: float, delta: float) -> void:
	# Fase 3: Melancarkan badai peluru beruntun
	var speed: float = base_speed * 1.2
	if dist > 6.0:
		_move_towards(player_ref.global_position, speed, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		_play_anim("idle")

	if _barrage_timer >= p3_barrage_interval:
		_barrage_timer = 0.0
		_unleash_flak_barrage()
	elif _action_timer >= 1.6:
		_action_timer = 0.0
		_cast_single_orb()

func _move_towards(target_pos: Vector3, speed: float, _delta: float) -> void:
	var dir: Vector3 = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_play_anim("walk" if speed <= base_speed else "run")

func _play_anim(anim_name: StringName) -> void:
	if not animation_player:
		return
	var target_anim: StringName = anim_name
	match anim_name:
		&"idle":
			target_anim = &"Idle_Combat" if animation_player.has_animation(&"Idle_Combat") else &"Idle"
		&"walk":
			target_anim = &"Walking_A" if animation_player.has_animation(&"Walking_A") else anim_name
		&"run":
			target_anim = &"Running_A" if animation_player.has_animation(&"Running_A") else anim_name
		&"slash_1", &"slash_2":
			target_anim = &"Spellcast_Shoot" if animation_player.has_animation(&"Spellcast_Shoot") else anim_name
		&"slash_3":
			target_anim = &"Spellcasting" if animation_player.has_animation(&"Spellcasting") else anim_name
		&"attack_heavy":
			target_anim = &"Spellcast_Raise" if animation_player.has_animation(&"Spellcast_Raise") else anim_name
		&"summon":
			target_anim = &"Spellcast_Summon" if animation_player.has_animation(&"Spellcast_Summon") else anim_name
		&"death":
			target_anim = &"Death_A" if animation_player.has_animation(&"Death_A") else anim_name

	if animation_player.current_animation != target_anim:
		if animation_player.has_animation(target_anim):
			animation_player.play(target_anim)

func _cast_single_orb() -> void:
	current_state = State.CAST_ORB
	_play_anim("slash_1")
	_play_sfx(_cached_cast_wav, 1.0)

	var tw := create_tween()
	tw.tween_interval(0.28)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		_spawn_orb_towards_player()
	)
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		current_state = State.IDLE
	)

func _cast_triple_orbs() -> void:
	current_state = State.CAST_ORB
	_play_anim("slash_2")
	_play_sfx(_cached_cast_wav, 1.1)

	var tw := create_tween()
	tw.tween_interval(0.28)
	tw.tween_callback(func() -> void:
		if is_dead or not is_instance_valid(player_ref):
			return
		var spawn_pos: Vector3 = cast_point.global_position if cast_point else global_position + Vector3(0, 1.8, 0)
		var center_dir: Vector3 = (player_ref.global_position + Vector3(0, 1.0, 0) - spawn_pos).normalized()
		var angles: Array[float] = [-0.26, 0.0, 0.26]
		for ang in angles:
			var rot_dir: Vector3 = center_dir.rotated(Vector3.UP, ang)
			_spawn_orb_in_dir(spawn_pos, rot_dir)
	)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		current_state = State.IDLE
	)

func _unleash_flak_barrage() -> void:
	current_state = State.BARRAGE
	_play_anim("slash_3")
	_play_sfx(_cached_cast_wav, 1.25)

	var tw := create_tween()
	for i in range(p3_spiral_bullets):
		var delay: float = float(i) * 0.08
		tw.tween_callback(func() -> void:
			if is_dead:
				return
			var spawn_pos: Vector3 = cast_point.global_position if cast_point else global_position + Vector3(0, 1.8, 0)
			var angle: float = float(i) * (TAU / float(p3_spiral_bullets)) * 1.5
			var dir: Vector3 = Vector3(sin(angle), randf_range(-0.08, 0.08), cos(angle)).normalized()
			_spawn_orb_in_dir(spawn_pos, dir, 12.0)
		).set_delay(delay if i == 0 else 0.08)

	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		current_state = State.IDLE
	)

func _spawn_orb_towards_player() -> void:
	if not is_instance_valid(player_ref):
		return
	var spawn_pos: Vector3 = cast_point.global_position if cast_point else global_position + Vector3(0, 1.8, 0)
	var target_pos: Vector3 = player_ref.global_position + Vector3(0, 1.0, 0)
	var dir: Vector3 = (target_pos - spawn_pos).normalized()
	_spawn_orb_in_dir(spawn_pos, dir)

func _spawn_orb_in_dir(spawn_pos: Vector3, dir: Vector3, custom_speed: float = -1.0) -> void:
	var orb: Area3D = MAGIC_ORB_SCENE.instantiate() as Area3D
	if not orb:
		return
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	parent_node.add_child(orb)
	orb.global_position = spawn_pos
	if orb.has_method("init_shot"):
		orb.init_shot(self, spawn_pos + dir * 10.0, custom_speed)

func _cast_aoe_rune() -> void:
	if not is_instance_valid(player_ref):
		return
	current_state = State.CAST_AOE
	_play_anim("attack_heavy")

	var target_feet: Vector3 = player_ref.global_position
	target_feet.y = global_position.y

	var rune: Node3D = MAGIC_AOE_SCENE.instantiate() as Node3D
	if rune:
		var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
		parent_node.add_child(rune)
		rune.global_position = target_feet

	var tw := create_tween()
	tw.tween_interval(0.65)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		current_state = State.IDLE
	)

func _slam_shockwave() -> void:
	current_state = State.SLAM_SHOCKWAVE
	_play_anim("attack_heavy")

	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		var wave: Node3D = SHOCKWAVE_SCENE.instantiate() as Node3D
		if wave:
			var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
			parent_node.add_child(wave)
			wave.global_position = global_position
	)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		current_state = State.IDLE
	)

func _teleport_away_from_player() -> void:
	if not is_instance_valid(player_ref):
		return
	_teleport_cooldown = 1.8
	current_state = State.TELEPORTING

	_spawn_floating_text("TERLALU CEPAT!", Color(0.25, 0.85, 1.0, 1.0), 30, 1.2)
	_play_sfx(_cached_teleport_wav, 1.1)

	var evade_dir: Vector3 = (global_position - player_ref.global_position).normalized()
	evade_dir.y = 0.0
	evade_dir = evade_dir.rotated(Vector3.UP, randf_range(-0.5, 0.5))
	var new_pos: Vector3 = global_position + evade_dir * p2_teleport_distance

	# Efek fade teleport
	var tw := create_tween()
	if visual_root:
		tw.tween_property(visual_root, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		global_position = new_pos
		if is_instance_valid(player_ref):
			var to_p := player_ref.global_position - global_position
			to_p.y = 0.0
			if to_p.length_squared() > 0.01:
				rotation.y = atan2(to_p.x, to_p.z)
		_play_sfx(_cached_teleport_wav, 1.3)
	)
	if visual_root:
		tw.tween_property(visual_root, "scale", Vector3(1.65, 1.65, 1.65), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		current_state = State.IDLE
	)

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	var final_damage: float = amount

	# Validasi Mekanik Ramuan per Fase
	match current_phase:
		1:
			var has_strength: bool = GlobalLogic.is_potion_active("strength") or GlobalLogic.is_potion_active("berserk")
			if not has_strength:
				final_damage = p1_unbuffed_damage_cap
				_spawn_floating_text("KEBAL!", Color(1.0, 0.3, 0.3, 1.0), 34, 1.3)
				_play_sfx(_cached_deflect_wav, 1.0)
				_trigger_shield_flash()
				return
		2:
			var has_slow: bool = GlobalLogic.is_potion_active("slow")
			if not has_slow:
				# Di fase 2 jika tidak lambat, boss membalas dengan menghindar
				_spawn_floating_text("TERLALU CEPAT!", Color(0.3, 0.8, 1.0, 1.0), 28, 1.1)
		3:
			var has_ironskin: bool = GlobalLogic.is_potion_active("ironskin")
			if not has_ironskin:
				_spawn_floating_text("BADAI PELURU!", Color(1.0, 0.6, 0.2, 1.0), 28, 1.1)

	current_health = maxf(0.0, current_health - final_damage)
	damaged.emit(final_damage)
	GlobalLogic.update_boss_hp(current_health, max_health)
	_spawn_floating_text("-%d" % roundi(final_damage), Color(1.0, 0.85, 0.25, 1.0), 34, 0.9)
	_trigger_hit_flash()
	_update_health_bars()

	if knockback.length_squared() > 0.01:
		velocity += knockback * 0.15

	if current_health <= 0.0:
		_die()
	elif current_phase == 1 and current_health <= phase_2_threshold:
		_transition_to_phase(2)
	elif current_phase == 2 and current_health <= phase_3_threshold:
		_transition_to_phase(3)

func _transition_to_phase(new_phase: int) -> void:
	current_phase = new_phase
	current_state = State.PHASE_TRANSITION
	phase_changed.emit(new_phase)
	GlobalLogic.update_boss_hp(current_health, max_health)
	_update_phase_hud()

	_play_sfx(_cached_roar_wav, 1.0)
	_play_anim("attack_heavy")

	if new_phase == 2:
		_spawn_floating_text("CHRONO DISTORTION!", Color(0.2, 0.9, 1.0, 1.0), 36, 1.6)
	elif new_phase == 3:
		_spawn_floating_text("TOXIC OVERDRIVE!", Color(1.0, 0.35, 0.2, 1.0), 36, 1.6)
		_summon_slime_minions()

	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		current_state = State.IDLE
	)

func _summon_slime_minions() -> void:
	for i in range(2):
		var slime: CharacterBody3D = SLIME_MINION_SCENE.instantiate() as CharacterBody3D
		if slime:
			var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
			parent_node.add_child(slime)
			var offset := Vector3(randf_range(-3.5, 3.5), 0.5, randf_range(-3.5, 3.5))
			slime.global_position = global_position + offset

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = State.DEAD
	set_physics_process(false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	_play_anim("death")
	_spawn_floating_text("ARCHMAGE MALAKOR KALAH!", Color(1.0, 0.85, 0.1, 1.0), 38, 1.8)
	_drop_loot()
	_activate_exit_portal()
	GlobalLogic.trigger_boss_defeated()
	defeated.emit()

	if hp_sprite:
		hp_sprite.visible = false

	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(queue_free)

func _drop_loot() -> void:
	var loot_types: Array[String] = ["slime_gel", "fire_essence", "frost_wing"]
	for item_t in loot_types:
		var drop: CharacterBody3D = ITEM_DROP_SCENE.instantiate() as CharacterBody3D
		if drop:
			if "item_type" in drop:
				drop.item_type = item_t
			var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
			parent_node.add_child(drop)
			drop.global_position = global_position + Vector3(randf_range(-1.2, 1.2), 0.8, randf_range(-1.2, 1.2))

func _activate_exit_portal() -> void:
	var portal_node: Node = null
	if exit_portal != NodePath("") and has_node(exit_portal):
		portal_node = get_node(exit_portal)
	elif has_node("%Exit"):
		portal_node = get_node("%Exit")
	elif get_tree().get_nodes_in_group("portals").size() > 0:
		portal_node = get_tree().get_nodes_in_group("portals")[0]

	if portal_node and "is_active" in portal_node:
		portal_node.is_active = true

func _spawn_floating_text(txt: String, col: Color, font_sz: int, rise: float) -> void:
	var ft: Label3D = FLOATING_TEXT_SCENE.instantiate() as Label3D
	if not ft:
		return
	var parent_node: Node = get_parent() if get_parent() else get_tree().current_scene
	parent_node.add_child(ft)
	ft.global_position = global_position + Vector3(0, 2.6, 0)
	if ft.has_method("pop"):
		ft.pop(txt, col, font_sz, rise, 0.9)

func _update_health_bars() -> void:
	if not hp_bar or not hp_viewport:
		return

	hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hp_bar.value = current_health

	if _hp_lag_tween and _hp_lag_tween.is_valid():
		_hp_lag_tween.kill()

	_hp_lag_tween = create_tween()
	_hp_lag_tween.tween_interval(0.3)
	_hp_lag_tween.tween_property(hp_lag_bar, "value", current_health, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hp_lag_tween.tween_callback(func() -> void:
		_refresh_hp_viewport()
	)

func _update_phase_hud() -> void:
	if not phase_label:
		return
	match current_phase:
		1:
			phase_label.text = "FASE I: BUTUH STRENGTH"
			phase_label.modulate = Color(1.0, 0.45, 0.3)
		2:
			phase_label.text = "FASE II: BUTUH SLOW"
			phase_label.modulate = Color(0.3, 0.85, 1.0)
		3:
			phase_label.text = "FASE III: BUTUH IRONSKIN"
			phase_label.modulate = Color(1.0, 0.8, 0.2)
	_refresh_hp_viewport()

func _refresh_hp_viewport() -> void:
	if not hp_viewport:
		return
	hp_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _trigger_shield_flash() -> void:
	if not visual_root:
		return
	var tw := create_tween()
	tw.tween_property(visual_root, "scale", Vector3(1.85, 1.55, 1.85), 0.08)
	tw.tween_property(visual_root, "scale", Vector3(1.7, 1.7, 1.7), 0.12)

func _trigger_hit_flash() -> void:
	if not visual_root:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	visual_root.position.y = 0.12
	_flash_tween.tween_property(visual_root, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for mi in _cached_mesh_instances:
		if is_instance_valid(mi):
			mi.material_override = _hit_flash_material
	_flash_tween.tween_callback(func() -> void:
		for mi in _cached_mesh_instances:
			if is_instance_valid(mi):
				mi.material_override = null
	).set_delay(0.08)

func _play_sfx(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if not audio_player or not stream:
		return
	audio_player.stream = stream
	audio_player.pitch_scale = pitch
	audio_player.play()

static func _ensure_cached_audio() -> void:
	if not _cached_teleport_wav:
		_cached_teleport_wav = _generate_tone_wav(22050, 0.3, 520.0, 160.0, 0.35)
	if not _cached_deflect_wav:
		_cached_deflect_wav = _generate_tone_wav(22050, 0.22, 980.0, 720.0, 0.15)
	if not _cached_roar_wav:
		_cached_roar_wav = _generate_tone_wav(22050, 0.65, 110.0, 55.0, 0.65)
	if not _cached_cast_wav:
		_cached_cast_wav = _generate_tone_wav(22050, 0.25, 340.0, 680.0, 0.2)

static func _generate_tone_wav(sample_hz: int, duration: float, start_freq: float, end_freq: float, noise_mix: float) -> AudioStreamWAV:
	var num_samples: int = int(float(sample_hz) * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples * 2)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_hz)
		var progress: float = t / duration
		var freq: float = lerpf(start_freq, end_freq, progress)
		var env: float = exp(-t * 6.0) * (1.0 - progress)
		var sine_val: float = sin(t * freq * TAU)
		var noise_val: float = randf() * 2.0 - 1.0
		var mixed: float = (sine_val * (1.0 - noise_mix) + noise_val * noise_mix) * env * 0.8
		var sample_val: int = int(clampf(mixed, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, sample_val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_hz
	wav.data = buffer
	return wav
