extends CharacterBody3D
class_name ItemDrop3D

const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")

enum State { POP, IDLE, MAGNET_PULL, COLLECTED }

@export var item_type: String = "slime_gel"
@export var item_amount: int = 1
@export var item_color: Color = Color(0.15, 0.85, 0.45, 0.95)

@export var pop_force_y: float = 4.8
@export var pop_spread_xz: float = 1.8
@export var gravity: float = 16.0
@export var bounce_damping: float = 0.4

@export var magnet_radius: float = 7.0
@export var magnet_speed_initial: float = 6.5
@export var magnet_speed_max: float = 24.0
@export var magnet_acceleration: float = 36.0
@export var pickup_distance: float = 1.25

var current_state: State = State.POP
var pop_grace_timer: float = 0.15
var idle_timer: float = 0.0
var base_floor_y: float = 0.0
var current_magnet_speed: float = 0.0

@onready var mesh_node: MeshInstance3D = $MeshNode if has_node("MeshNode") else null
@onready var inner_mesh: MeshInstance3D = $MeshNode/InnerMesh if has_node("MeshNode/InnerMesh") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var pickup_audio: AudioStreamPlayer = $PickupAudio if has_node("PickupAudio") else null

var drop_material: StandardMaterial3D = null
var player_ref: Node3D = null
var _pickup_stream: AudioStreamWAV = null

func _ready() -> void:
	add_to_group("item_drops")
	_setup_nodes()
	_setup_pickup_audio()
	set_drop_color(item_color)

	# Initial launch impulse
	velocity = Vector3(
		randf_range(-pop_spread_xz, pop_spread_xz),
		pop_force_y,
		randf_range(-pop_spread_xz, pop_spread_xz)
	)

func _setup_nodes() -> void:
	if not mesh_node and has_node("MeshNode"):
		mesh_node = $MeshNode as MeshInstance3D
	if not inner_mesh and has_node("MeshNode/InnerMesh"):
		inner_mesh = $MeshNode/InnerMesh as MeshInstance3D
	if not collision_shape and has_node("CollisionShape3D"):
		collision_shape = $CollisionShape3D as CollisionShape3D

	if mesh_node:
		var base_mat: Material = mesh_node.material_override
		if not base_mat and mesh_node.mesh:
			base_mat = mesh_node.mesh.material
		if base_mat and base_mat is StandardMaterial3D:
			drop_material = base_mat.duplicate() as StandardMaterial3D
			mesh_node.material_override = drop_material
		elif not drop_material:
			drop_material = StandardMaterial3D.new()
			drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			drop_material.roughness = 0.15
			drop_material.emission_enabled = true
			mesh_node.material_override = drop_material

func set_drop_color(new_color: Color) -> void:
	item_color = new_color
	if drop_material:
		drop_material.albedo_color = item_color
		drop_material.emission = item_color.darkened(0.15)
		drop_material.emission_energy_multiplier = 0.9

func _setup_pickup_audio() -> void:
	if not pickup_audio and has_node("PickupAudio"):
		pickup_audio = $PickupAudio as AudioStreamPlayer

	var sample_hz := 22050.0
	var dur := 0.22
	var total_samples := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / sample_hz
		var freq := 880.0 if t < 0.09 else 1320.0
		var note_t := t if t < 0.09 else (t - 0.09)
		var env := exp(-note_t * 18.0)
		var val := int((sin(t * freq * TAU) + 0.3 * sin(t * freq * 2.0 * TAU)) * env * 0.45 * 32767.0)
		buffer.encode_s16(i * 2, val)

	_pickup_stream = AudioStreamWAV.new()
	_pickup_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_pickup_stream.mix_rate = int(sample_hz)
	_pickup_stream.data = buffer

	if pickup_audio:
		pickup_audio.stream = _pickup_stream

func _physics_process(delta: float) -> void:
	if current_state == State.COLLECTED:
		return

	if not player_ref or not is_instance_valid(player_ref):
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as Node3D

	var target_pos: Vector3 = global_position
	var dist_to_player: float = 999.0
	if player_ref and is_instance_valid(player_ref):
		target_pos = player_ref.global_position + Vector3(0.0, 0.9, 0.0)
		dist_to_player = global_position.distance_to(target_pos)

		# Immediate absorption if inside pickup perimeter in ANY state!
		if dist_to_player <= pickup_distance:
			_collect()
			return

	match current_state:
		State.POP:
			pop_grace_timer -= delta
			velocity.y -= gravity * delta
			mesh_node.rotate_x(delta * 6.0)
			mesh_node.rotate_y(delta * 4.0)

			# If player is in magnet range and grace period elapsed, start pulling immediately
			if dist_to_player < magnet_radius and pop_grace_timer <= 0.0:
				_start_magnet_pull()
				return

			move_and_slide()

			if is_on_floor():
				if pop_grace_timer <= 0.0 or abs(velocity.y) < 1.0:
					current_state = State.IDLE
					velocity = Vector3.ZERO
					base_floor_y = global_position.y
					mesh_node.rotation = Vector3.ZERO
				else:
					velocity.y = -velocity.y * bounce_damping
					velocity.x *= 0.5
					velocity.z *= 0.5

		State.IDLE:
			idle_timer += delta
			# Gentle bobbing and spinning
			mesh_node.position.y = sin(idle_timer * 3.5) * 0.07
			mesh_node.rotate_y(delta * 2.2)

			if dist_to_player < magnet_radius:
				_start_magnet_pull()

		State.MAGNET_PULL:
			if not player_ref or not is_instance_valid(player_ref):
				current_state = State.IDLE
				collision_layer = 1
				collision_mask = 1
				return

			var to_player: Vector3 = target_pos - global_position
			var dist := to_player.length()

			if dist <= pickup_distance:
				_collect()
				return

			# Accelerate toward player
			current_magnet_speed = minf(magnet_speed_max, current_magnet_speed + magnet_acceleration * delta)
			var move_dir := to_player.normalized()
			velocity = move_dir * current_magnet_speed

			# Look at player & aerodynamic drop stretch
			var look_target := global_position + move_dir
			if not global_position.is_equal_approx(look_target):
				look_at(look_target, Vector3.UP)
			mesh_node.scale = Vector3(0.75, 0.75, 1.4)

			# Direct smooth glide towards player with zero obstacle friction
			global_position += velocity * delta

func _start_magnet_pull() -> void:
	current_state = State.MAGNET_PULL
	current_magnet_speed = magnet_speed_initial
	mesh_node.position.y = 0.0
	# Turn off collision so droplet glides freely without snagging on player's collider
	collision_layer = 0
	collision_mask = 0

func _collect() -> void:
	current_state = State.COLLECTED
	var global = get_node_or_null("/root/GlobalLogic")
	if global:
		global.add_material(item_type, item_amount)
	_play_pickup_chime()
	_spawn_floating_toast()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mesh_node, "scale", Vector3(1.6, 1.6, 1.6), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(drop_material, "albedo_color:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)

func _play_pickup_chime() -> void:
	if pickup_audio:
		if not pickup_audio.stream and _pickup_stream:
			pickup_audio.stream = _pickup_stream
		# Reparent ke root agar tidak terpotong saat item_drop di-queue_free
		pickup_audio.reparent(get_tree().root)
		pickup_audio.play()
		pickup_audio.finished.connect(pickup_audio.queue_free)

func _spawn_floating_toast() -> void:
	if not FLOATING_TEXT_SCENE:
		return
	var label = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	if not label:
		return
	get_tree().root.add_child(label)
	label.global_position = global_position + Vector3(0.0, 0.3, 0.0)
	label.pop("+%d Slime Gel" % item_amount, item_color.lightened(0.3), 28, 0.85, 0.55)
