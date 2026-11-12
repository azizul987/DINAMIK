class_name SlimeEnemy
extends CharacterBody3D

const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")

signal defeated()
signal damaged(amount: float)

enum State {
	IDLE,
	PREPARE_HOP,
	HOPPING,
	LANDING,
	DEAD
}

@export_group("Stats")
@export var max_health: float = 30.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var respawn_time: float = 3.0

@export_group("AI Ranges")
@export var patrol_radius: float = 6.0
@export var detection_radius: float = 9.0
@export var lose_interest_radius: float = 13.0
@export var attack_radius: float = 1.8

@export_group("Hop Physics")
@export var patrol_hop_speed: float = 2.4
@export var chase_hop_speed: float = 4.2
@export var hop_force: float = 4.5
@export var attack_hop_force: float = 5.2
@export var gravity: float = 18.0
@export var turn_speed: float = 8.0

@export_group("Combat & Knockback")
@export var contact_knockback_force: float = 11.0
@export var contact_knockback_lift: float = 0.45
@export var contact_bounce_recoil: float = 2.5
@export var hit_stun_duration: float = 0.5
@export var proximity_damage_range: float = 1.15

@export_group("AI Timers")
@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 2.0
@export var prep_hop_time_patrol: float = 0.3
@export var prep_hop_time_chase: float = 0.2
@export var landing_time_patrol: float = 0.45
@export var landing_time_chase: float = 0.25

var current_health: float = 30.0
var is_dead: bool = false
var current_state: State = State.IDLE
var spawn_position: Vector3 = Vector3.ZERO
var target_destination: Vector3 = Vector3.ZERO
var is_chasing: bool = false
var idle_timer: float = 0.0
var state_timer: float = 0.0
var attack_timer: float = 0.0
var player_ref: Node3D = null

const SLIME_PALETTE: Array[Color] = [
	Color(0.2, 0.88, 0.35), # Emerald Acid
	Color(0.25, 0.75, 0.95), # Frost Glaze
	Color(0.95, 0.45, 0.15), # Magma Flame
	Color(0.75, 0.25, 0.85), # Miasma Poison
	Color(0.95, 0.82, 0.2),  # Golden Ichor
]

const ITEM_DROP_SCENE: PackedScene = preload("res://item_drop.tscn")

var slime_base_color: Color = Color(0.2, 0.88, 0.35)
var base_material: StandardMaterial3D = null

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var splat_particles: CPUParticles3D = $SplatParticles if has_node("SplatParticles") else null
@onready var hp_viewport: SubViewport = $HpViewport if has_node("HpViewport") else null
@onready var hp_sprite: Sprite3D = $HpSprite if has_node("HpSprite") else null
@onready var hp_bar: ProgressBar = $HpViewport/HpBar if has_node("HpViewport/HpBar") else null
@onready var hp_lag_bar: ProgressBar = $HpViewport/HpLagBar if has_node("HpViewport/HpLagBar") else null

var hp_fill_style: StyleBoxFlat = null
var hp_lag_fill_style: StyleBoxFlat = null
var _hp_lag_tween: Tween = null
var flash_material: StandardMaterial3D = null
var _flash_tween: Tween = null

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	current_health = max_health
	idle_timer = randf_range(min_idle_time, max_idle_time)
	_setup_health_bar()
	_setup_flash_material()
	_setup_splat_particles()
	_apply_random_slime_color()

func _apply_random_slime_color() -> void:
	slime_base_color = SLIME_PALETTE.pick_random()
	base_material = StandardMaterial3D.new()
	base_material.albedo_color = Color(slime_base_color.r, slime_base_color.g, slime_base_color.b, 0.9)
	base_material.roughness = 0.15
	base_material.emission_enabled = true
	base_material.emission = slime_base_color * 0.7
	base_material.emission_energy_multiplier = 0.5
	mesh.set_surface_override_material(0, base_material)

	if splat_particles and splat_particles.mesh and splat_particles.mesh.material:
		var p_mat := splat_particles.mesh.material as StandardMaterial3D
		if p_mat:
			p_mat.albedo_color = slime_base_color

	if hp_fill_style:
		hp_fill_style.bg_color = slime_base_color

func _setup_splat_particles() -> void:
	if not splat_particles and has_node("SplatParticles"):
		splat_particles = $SplatParticles as CPUParticles3D

func _setup_flash_material() -> void:
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

func _setup_health_bar() -> void:
	if not hp_viewport and has_node("HpViewport"):
		hp_viewport = $HpViewport as SubViewport
	if not hp_sprite and has_node("HpSprite"):
		hp_sprite = $HpSprite as Sprite3D
	if not hp_bar and has_node("HpViewport/HpBar"):
		hp_bar = $HpViewport/HpBar as ProgressBar
	if not hp_lag_bar and has_node("HpViewport/HpLagBar"):
		hp_lag_bar = $HpViewport/HpLagBar as ProgressBar

	if hp_sprite and hp_viewport and not hp_sprite.texture:
		hp_sprite.texture = hp_viewport.get_texture()

	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
		var style = hp_bar.get_theme_stylebox("fill")
		if style and style is StyleBoxFlat:
			hp_fill_style = style.duplicate() as StyleBoxFlat
			hp_bar.add_theme_stylebox_override("fill", hp_fill_style)

	if hp_lag_bar:
		hp_lag_bar.max_value = max_health
		hp_lag_bar.value = current_health
		var style = hp_lag_bar.get_theme_stylebox("fill")
		if style and style is StyleBoxFlat:
			hp_lag_fill_style = style.duplicate() as StyleBoxFlat
			hp_lag_bar.add_theme_stylebox_override("fill", hp_lag_fill_style)

func _physics_process(delta: float) -> void:
	if is_dead:
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	_update_player_detection()

	if not is_on_floor():
		velocity.y -= gravity * delta

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

			if is_chasing and is_instance_valid(player_ref):
				var to_player := player_ref.global_position - global_position
				to_player.y = 0.0
				if to_player.length_squared() > 0.01:
					var target_yaw := atan2(to_player.x, to_player.z)
					rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

				state_timer -= delta
				if state_timer <= 0.0:
					_start_prepare_hop(true)
			else:
				idle_timer -= delta
				if idle_timer <= 0.0:
					_pick_patrol_destination()
					_start_prepare_hop(false)

		State.PREPARE_HOP:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

			var target_pos: Vector3 = player_ref.global_position if (is_chasing and is_instance_valid(player_ref)) else target_destination
			var to_target: Vector3 = target_pos - global_position
			to_target.y = 0.0
			if to_target.length_squared() > 0.01:
				var target_yaw := atan2(to_target.x, to_target.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

			state_timer -= delta
			if state_timer <= 0.0:
				_launch_hop()

		State.HOPPING:
			_check_contact_damage()
			if is_on_floor() and velocity.y <= 0.0:
				_land_hop()

		State.LANDING:
			velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
			_check_contact_damage()

			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.IDLE
				state_timer = 0.0
				idle_timer = randf_range(0.3, 0.6) if is_chasing else randf_range(min_idle_time, max_idle_time)

	move_and_slide()

func _update_player_detection() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node3D

	if not player_ref or not is_instance_valid(player_ref) or GlobalLogic.is_dead:
		is_chasing = false
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if is_chasing:
		if dist > lose_interest_radius:
			is_chasing = false
	else:
		if dist <= detection_radius:
			is_chasing = true

func _start_prepare_hop(chasing: bool) -> void:
	current_state = State.PREPARE_HOP
	var prep_time := prep_hop_time_chase if chasing else prep_hop_time_patrol
	state_timer = prep_time

	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.25, 0.65, 1.25), prep_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _launch_hop() -> void:
	current_state = State.HOPPING

	var target_pos: Vector3 = player_ref.global_position if (is_chasing and is_instance_valid(player_ref)) else target_destination
	var to_target: Vector3 = target_pos - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	var dir := to_target.normalized() if dist > 0.01 else -global_transform.basis.z

	if dist > 0.01:
		rotation.y = atan2(dir.x, dir.z)

	var is_attack_hop := is_chasing and dist <= attack_radius * 1.5
	var jump_v := attack_hop_force if is_attack_hop else hop_force
	var speed := chase_hop_speed if is_chasing else patrol_hop_speed
	if is_attack_hop:
		speed *= 1.15

	velocity.y = jump_v
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(0.85, 1.35, 0.85), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _land_hop() -> void:
	current_state = State.LANDING
	var recovery_time := landing_time_chase if is_chasing else landing_time_patrol
	state_timer = recovery_time

	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.35, 0.6, 1.35), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3.ONE, recovery_time - 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _check_contact_damage() -> void:
	if attack_timer > 0.0:
		return

	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider() as Node3D
		if collider and collider.is_in_group("player"):
			_deal_damage_to_player(collider)
			return

	if is_instance_valid(player_ref) and not GlobalLogic.is_dead:
		if global_position.distance_to(player_ref.global_position) < proximity_damage_range:
			_deal_damage_to_player(player_ref)

func _deal_damage_to_player(target: Node3D) -> void:
	if not target or not is_instance_valid(target) or attack_timer > 0.0:
		return
	attack_timer = attack_cooldown
	var knockback_dir: Vector3 = (target.global_position - global_position).normalized()
	knockback_dir.y = contact_knockback_lift
	knockback_dir = knockback_dir.normalized()

	if target.has_method("take_damage"):
		target.take_damage(attack_damage, knockback_dir * contact_knockback_force)

	if current_state != State.HOPPING:
		velocity.x = -knockback_dir.x * contact_bounce_recoil
		velocity.z = -knockback_dir.z * contact_bounce_recoil

func _pick_patrol_destination() -> void:
	var angle := randf() * TAU
	var dist := randf_range(1.5, patrol_radius)
	target_destination = spawn_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

func _trigger_hit_flash() -> void:
	if not mesh or not flash_material:
		return
	if _flash_tween:
		_flash_tween.kill()

	flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh.material_override = flash_material

	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.08)
	_flash_tween.tween_property(flash_material, "albedo_color:a", 0.0, 0.08)
	_flash_tween.tween_callback(func():
		if is_instance_valid(mesh):
			mesh.material_override = null
			flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	)

func _spawn_damage_number(amount: float) -> void:
	if not is_inside_tree() or not FLOATING_TEXT_SCENE:
		return

	var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
	if not label:
		return

	var display_text := str(roundi(amount))
	var text_color := Color(1.0, 1.0, 1.0, 1.0)
	var f_size := 36
	var rise_height := 0.65

	if amount >= 40.0:
		display_text = str(roundi(amount)) + "!"
		text_color = Color(1.0, 0.22, 0.25, 1.0)
		f_size = 52
		rise_height = 0.9
	elif amount >= 25.0:
		display_text = str(roundi(amount))
		text_color = Color(1.0, 0.78, 0.15, 1.0)
		f_size = 44
		rise_height = 0.75

	var spawn_pos := global_position + Vector3(randf_range(-0.25, 0.25), 0.9, randf_range(-0.25, 0.25))
	var parent_node := get_parent()
	if not parent_node:
		parent_node = get_tree().current_scene
	if not parent_node:
		return

	parent_node.add_child(label)
	label.global_position = spawn_pos
	label.pop(display_text, text_color, f_size, rise_height, 0.45)

func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, _is_sharp: bool = false) -> void:
	if is_dead:
		return

	current_health = maxf(0.0, current_health - amount)
	if knockback.length_squared() > 0.01:
		velocity = knockback
		current_state = State.HOPPING
		state_timer = 0.3
		attack_timer = hit_stun_duration
	is_chasing = true
	damaged.emit(amount)

	_trigger_hit_flash()
	_spawn_damage_number(amount)

	if splat_particles:
		splat_particles.restart()
		splat_particles.emitting = true

	var tween := create_tween()
	mesh.scale = Vector3(1.3, 0.7, 1.3)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if hp_bar:
		var bar_tween := create_tween()
		bar_tween.tween_property(hp_bar, "value", current_health, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if hp_fill_style:
			var health_ratio := current_health / max_health
			if health_ratio < 0.3:
				hp_fill_style.bg_color = Color(0.9, 0.2, 0.2)
			elif health_ratio < 0.6:
				hp_fill_style.bg_color = Color(0.95, 0.7, 0.15)
			else:
				hp_fill_style.bg_color = slime_base_color

	if hp_lag_bar:
		if _hp_lag_tween:
			_hp_lag_tween.kill()
		_hp_lag_tween = create_tween()
		_hp_lag_tween.tween_interval(0.20)
		_hp_lag_tween.tween_property(hp_lag_bar, "value", current_health, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if current_health <= 0.0:
		die()

func die() -> void:
	is_dead = true
	current_state = State.DEAD
	defeated.emit()

	if mesh:
		mesh.material_override = null

	if hp_sprite:
		hp_sprite.visible = false

	_spawn_item_drop()

	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	collision_shape.disabled = true

	await get_tree().create_timer(respawn_time).timeout
	respawn()

func _spawn_item_drop() -> void:
	if not ITEM_DROP_SCENE:
		return
	var drop = ITEM_DROP_SCENE.instantiate() as ItemDrop3D
	if not drop:
		return
	var parent_scene = get_parent()
	if not parent_scene:
		parent_scene = get_tree().current_scene
	if parent_scene:
		parent_scene.add_child(drop)
		drop.global_position = global_position + Vector3(0.0, 0.4, 0.0)
		drop.set_drop_color(slime_base_color)

func respawn() -> void:
	global_position = spawn_position
	current_health = max_health
	is_dead = false
	is_chasing = false
	current_state = State.IDLE
	idle_timer = randf_range(1.0, 2.0)
	visible = true
	collision_shape.disabled = false
	mesh.scale = Vector3.ONE
	mesh.material_override = null
	velocity = Vector3.ZERO

	if hp_sprite:
		hp_sprite.visible = true
	if hp_bar:
		hp_bar.value = max_health
	if hp_lag_bar:
		hp_lag_bar.value = max_health
	_apply_random_slime_color()
