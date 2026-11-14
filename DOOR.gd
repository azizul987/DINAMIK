class_name DungeonDoor
extends MeshInstance3D

signal door_opened()
signal door_closed()
signal potion_unlocked(potion_name: String)

enum OpenMode {
	MISSION = 0,
	POTION_ATTACK = 1,
	ANY_ATTACK = 2,
	HYBRID = 3,
	MANUAL = 4
}

enum RequiredPotion {
	STRENGTH = 0,
	BERSERK = 1,
	IRONSKIN = 2,
	SLOW = 3,
	HEALING = 4,
	ANY = 5
}

const FLOATING_TEXT_SCENE: PackedScene = preload("res://floating_text.tscn")

@export_group("Door Mode")
@export var open_mode: OpenMode = OpenMode.MISSION
@export var required_potion: RequiredPotion = RequiredPotion.STRENGTH
@export var hits_required: int = 1
@export var consume_buff_on_open: bool = false

@export_group("Mission Settings")
@export var open_on_tutorial_complete: bool = true
@export var open_on_tutorial_step: int = 3

@export_group("Movement & Audio")
@export var open_height: float = 3.5
@export var open_duration: float = 1.5

var is_open: bool = false
var current_hits: int = 0
var closed_position: Vector3 = Vector3.ZERO
var opened_position: Vector3 = Vector3.ZERO
var _tween: Tween = null
var _shake_tween: Tween = null

static var _cached_door_sfx: AudioStreamWAV = null
static var _cached_clank_sfx: AudioStreamWAV = null
static var _cached_unseal_sfx: AudioStreamWAV = null

@onready var door_audio: AudioStreamPlayer3D = $DoorAudio if has_node("DoorAudio") else null
@onready var seal_light: OmniLight3D = $SealLight if has_node("SealLight") else null

func _ready() -> void:
	closed_position = position
	opened_position = closed_position + Vector3(0.0, open_height, 0.0)

	_ensure_cached_resources()
	_setup_visual_seal()

	if GlobalLogic:
		if not GlobalLogic.tutorial_completed.is_connected(_on_tutorial_completed):
			GlobalLogic.tutorial_completed.connect(_on_tutorial_completed)
		if not GlobalLogic.tutorial_step_changed.is_connected(_on_tutorial_step_changed):
			GlobalLogic.tutorial_step_changed.connect(_on_tutorial_step_changed)

func _setup_visual_seal() -> void:
	if seal_light:
		if open_mode == OpenMode.POTION_ATTACK or open_mode == OpenMode.HYBRID:
			seal_light.visible = true
			seal_light.light_color = get_required_potion_color()
			seal_light.light_energy = 1.2
			seal_light.shadow_enabled = false
		else:
			seal_light.visible = false

## Menerima damage dari tebasan pemain untuk memproses pembukaan pintu berbasis ramuan atau serangan fisik.
func take_damage(_amount: float, _knockback: Vector3 = Vector3.ZERO, _is_sharp: bool = false) -> void:
	if is_open:
		return

	match open_mode:
		OpenMode.MISSION:
			_play_clank_sfx()
			_trigger_hit_shake()
			_spawn_floating_text("TERKUNCI! Buka via Misi", Color(0.85, 0.85, 0.85, 0.9), 26)

		OpenMode.MANUAL:
			_play_clank_sfx()
			_trigger_hit_shake()
			_spawn_floating_text("TERKUNCI", Color(0.7, 0.7, 0.7, 0.9), 26)

		OpenMode.ANY_ATTACK:
			current_hits += 1
			if current_hits >= hits_required:
				_play_unseal_sfx()
				_trigger_unseal_feedback()
				_spawn_floating_text("PINTU HANCUR!", Color(1.0, 0.85, 0.3, 1.0), 34)
				open_door()
			else:
				_play_clank_sfx()
				_trigger_hit_shake()
				_spawn_floating_text("RETAK: %d/%d" % [current_hits, hits_required], Color(1.0, 0.9, 0.5, 0.9), 28)

		OpenMode.POTION_ATTACK, OpenMode.HYBRID:
			if _check_potion_condition():
				current_hits += 1
				if current_hits >= hits_required:
					var p_color := get_required_potion_color()
					var p_name := get_required_potion_name()
					potion_unlocked.emit(p_name)
					if consume_buff_on_open and GlobalLogic:
						GlobalLogic.clear_potion_buff(p_name)
					_play_unseal_sfx()
					_trigger_unseal_feedback()
					_spawn_floating_text("SEGEL PECAH! (%s)" % p_name.to_upper(), p_color, 34)
					open_door()
				else:
					_play_clank_sfx()
					_trigger_hit_shake()
					_spawn_floating_text("SEGEL RETAK: %d/%d" % [current_hits, hits_required], get_required_potion_color(), 28)
			else:
				_play_clank_sfx()
				_trigger_hit_shake()
				var req_name := get_required_potion_name()
				_spawn_floating_text("TERKUNCI! Butuh Ramuan %s" % req_name, get_required_potion_color(), 28)

func open_door(speed_scale: float = 1.0) -> void:
	if is_open:
		return
	is_open = true

	if _tween and _tween.is_valid():
		_tween.kill()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	_play_door_sfx()
	_trigger_camera_rumble()

	if seal_light:
		var tw := create_tween()
		tw.tween_property(seal_light, "light_energy", 0.0, 0.6)

	var duration: float = maxf(0.1, open_duration / maxf(0.1, speed_scale))
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "position", opened_position, duration)
	_tween.chain().tween_callback(func() -> void:
		door_opened.emit()
	)

func close_door(speed_scale: float = 1.0) -> void:
	if not is_open:
		return
	is_open = false

	if _tween and _tween.is_valid():
		_tween.kill()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	_play_door_sfx()
	_trigger_camera_rumble()

	var duration: float = maxf(0.1, open_duration / maxf(0.1, speed_scale))
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "position", closed_position, duration)
	_tween.chain().tween_callback(func() -> void:
		door_closed.emit()
	)

func toggle_door() -> void:
	if is_open:
		close_door()
	else:
		open_door()

func get_required_potion_name() -> String:
	match required_potion:
		RequiredPotion.STRENGTH: return "Strength"
		RequiredPotion.BERSERK: return "Berserk"
		RequiredPotion.IRONSKIN: return "Ironskin"
		RequiredPotion.SLOW: return "Slow"
		RequiredPotion.HEALING: return "Healing"
		RequiredPotion.ANY: return "Ramuan Apapun"
	return "Strength"

func get_required_potion_color() -> Color:
	match required_potion:
		RequiredPotion.STRENGTH: return Color(1.0, 0.72, 0.15, 1.0)
		RequiredPotion.BERSERK: return Color(1.0, 0.22, 0.25, 1.0)
		RequiredPotion.IRONSKIN: return Color(0.85, 0.92, 1.0, 1.0)
		RequiredPotion.SLOW: return Color(0.3, 0.82, 1.0, 1.0)
		RequiredPotion.HEALING: return Color(0.3, 1.0, 0.5, 1.0)
		RequiredPotion.ANY: return Color(0.85, 0.5, 1.0, 1.0)
	return Color.WHITE

func _check_potion_condition() -> bool:
	if not GlobalLogic:
		return false
	match required_potion:
		RequiredPotion.STRENGTH:
			return GlobalLogic.is_potion_active("strength")
		RequiredPotion.BERSERK:
			return GlobalLogic.is_potion_active("berserk")
		RequiredPotion.IRONSKIN:
			return GlobalLogic.is_potion_active("ironskin")
		RequiredPotion.SLOW:
			return GlobalLogic.is_potion_active("slow")
		RequiredPotion.HEALING:
			return GlobalLogic.is_potion_active("healing")
		RequiredPotion.ANY:
			return GlobalLogic.is_potion_active("any")
	return false

func _trigger_hit_shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var cam_pivot := get_tree().root.find_child("CameraPivot", true, false)
	if cam_pivot and cam_pivot.has_method("add_trauma"):
		cam_pivot.add_trauma(0.12)

	_shake_tween = create_tween()
	var shake_offset := Vector3(randf_range(-0.06, 0.06), 0.0, randf_range(-0.06, 0.06))
	_shake_tween.tween_property(self, "position", closed_position + shake_offset, 0.04)
	_shake_tween.tween_property(self, "position", closed_position, 0.06)

func _trigger_unseal_feedback() -> void:
	var cam_pivot := get_tree().root.find_child("CameraPivot", true, false)
	if cam_pivot:
		if cam_pivot.has_method("add_trauma"):
			cam_pivot.add_trauma(0.45)
		if cam_pivot.has_method("fov_punch"):
			cam_pivot.fov_punch(2.0)

	if seal_light:
		var tw := create_tween()
		tw.tween_property(seal_light, "light_energy", 3.2, 0.1)
		tw.tween_property(seal_light, "light_energy", 0.0, 0.45)

func _spawn_floating_text(display_text: String, text_color: Color, f_size: int = 28) -> void:
	if not FLOATING_TEXT_SCENE or not is_inside_tree():
		return
	var label := FLOATING_TEXT_SCENE.instantiate() as FloatingText
	if not label:
		return
	var target_parent: Node = get_parent() if get_parent() else get_tree().root
	if target_parent.is_node_ready():
		target_parent.add_child(label)
		var spawn_pos := global_position + Vector3(0.0, 1.6, 0.0)
		label.global_position = spawn_pos
		label.pop(display_text, text_color, f_size, 0.85, 0.6)
	else:
		target_parent.call_deferred("add_child", label)
		label.set_deferred("global_position", global_position + Vector3(0.0, 1.6, 0.0))
		label.call_deferred("pop", display_text, text_color, f_size, 0.85, 0.6)

func _trigger_camera_rumble() -> void:
	var cam_pivot := get_tree().root.find_child("CameraPivot", true, false)
	if cam_pivot and cam_pivot.has_method("add_trauma"):
		cam_pivot.add_trauma(0.25)

static func _ensure_cached_resources() -> void:
	if _cached_door_sfx and _cached_clank_sfx and _cached_unseal_sfx:
		return

	var sample_hz: float = 22050.0

	# 1. Door moving stone rumble
	if not _cached_door_sfx:
		var duration: float = 0.75
		var total_samples: int = int(sample_hz * duration)
		var buffer := PackedByteArray()
		buffer.resize(total_samples * 2)

		for i in range(total_samples):
			var t: float = float(i) / sample_hz
			var env: float = 1.0 - (t / duration)
			var rumble: float = sin(t * 85.0 * TAU) * 0.45
			var grind: float = sin(t * 170.0 * TAU + sin(t * 22.0 * TAU) * 2.0) * 0.25
			var val: int = int((rumble + grind) * env * 0.8 * 32767.0)
			buffer.encode_s16(i * 2, val)

		_cached_door_sfx = AudioStreamWAV.new()
		_cached_door_sfx.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_door_sfx.mix_rate = int(sample_hz)
		_cached_door_sfx.data = buffer

	# 2. Clank / deflected strike sound
	if not _cached_clank_sfx:
		var dur_clank: float = 0.22
		var samples_clank: int = int(sample_hz * dur_clank)
		var buf_clank := PackedByteArray()
		buf_clank.resize(samples_clank * 2)

		for i in range(samples_clank):
			var t: float = float(i) / sample_hz
			var env: float = exp(-t * 22.0)
			var osc: float = sin(t * 880.0 * TAU) * 0.5 + sin(t * 1420.0 * TAU) * 0.35 + (randf_range(-0.15, 0.15)) * 0.15
			var val: int = int(osc * env * 0.75 * 32767.0)
			buf_clank.encode_s16(i * 2, val)

		_cached_clank_sfx = AudioStreamWAV.new()
		_cached_clank_sfx.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_clank_sfx.mix_rate = int(sample_hz)
		_cached_clank_sfx.data = buf_clank

	# 3. Unseal / barrier shatter sound
	if not _cached_unseal_sfx:
		var dur_unseal: float = 0.48
		var samples_unseal: int = int(sample_hz * dur_unseal)
		var buf_unseal := PackedByteArray()
		buf_unseal.resize(samples_unseal * 2)

		for i in range(samples_unseal):
			var t: float = float(i) / sample_hz
			var env: float = exp(-t * 8.0)
			var freq_sweep: float = lerpf(1250.0, 320.0, t / dur_unseal)
			var boom: float = sin(t * 68.0 * TAU) * 0.6
			var chime: float = sin(t * freq_sweep * TAU) * 0.4
			var val: int = int((boom + chime) * env * 0.85 * 32767.0)
			buf_unseal.encode_s16(i * 2, val)

		_cached_unseal_sfx = AudioStreamWAV.new()
		_cached_unseal_sfx.format = AudioStreamWAV.FORMAT_16_BITS
		_cached_unseal_sfx.mix_rate = int(sample_hz)
		_cached_unseal_sfx.data = buf_unseal

func _play_door_sfx() -> void:
	if not door_audio or not _cached_door_sfx:
		return
	door_audio.stream = _cached_door_sfx
	door_audio.play()

func _play_clank_sfx() -> void:
	if not door_audio or not _cached_clank_sfx:
		return
	door_audio.stream = _cached_clank_sfx
	door_audio.play()

func _play_unseal_sfx() -> void:
	if not door_audio or not _cached_unseal_sfx:
		return
	door_audio.stream = _cached_unseal_sfx
	door_audio.play()

func _on_tutorial_completed() -> void:
	if (open_mode == OpenMode.MISSION or open_mode == OpenMode.HYBRID) and open_on_tutorial_complete:
		open_door()

func _on_tutorial_step_changed(step: int) -> void:
	if (open_mode == OpenMode.MISSION or open_mode == OpenMode.HYBRID) and open_on_tutorial_step >= 0 and step >= open_on_tutorial_step:
		open_door()
