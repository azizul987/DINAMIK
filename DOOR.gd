class_name DungeonDoor
extends MeshInstance3D

signal door_opened()
signal door_closed()

@export_group("Door Settings")
@export var open_height: float = 3.5
@export var open_duration: float = 1.5
@export var open_on_tutorial_complete: bool = true
@export var open_on_tutorial_step: int = 3

var is_open: bool = false
var closed_position: Vector3 = Vector3.ZERO
var opened_position: Vector3 = Vector3.ZERO
var _tween: Tween = null

@onready var door_audio: AudioStreamPlayer3D = $DoorAudio if has_node("DoorAudio") else null

func _ready() -> void:
	closed_position = position
	opened_position = closed_position + Vector3(0.0, open_height, 0.0)

	if GlobalLogic:
		if not GlobalLogic.tutorial_completed.is_connected(_on_tutorial_completed):
			GlobalLogic.tutorial_completed.connect(_on_tutorial_completed)
		if not GlobalLogic.tutorial_step_changed.is_connected(_on_tutorial_step_changed):
			GlobalLogic.tutorial_step_changed.connect(_on_tutorial_step_changed)

func open_door(speed_scale: float = 1.0) -> void:
	if is_open:
		return
	is_open = true

	if _tween and _tween.is_valid():
		_tween.kill()

	_play_door_sfx()
	_trigger_camera_rumble()

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

func _trigger_camera_rumble() -> void:
	var cam_pivot := get_tree().root.find_child("CameraPivot", true, false)
	if cam_pivot and cam_pivot.has_method("add_trauma"):
		cam_pivot.add_trauma(0.25)

func _play_door_sfx() -> void:
	if not door_audio:
		return

	var sample_hz: float = 22050.0
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

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	door_audio.stream = wav
	door_audio.play()

func _on_tutorial_completed() -> void:
	if open_on_tutorial_complete:
		open_door()

func _on_tutorial_step_changed(step: int) -> void:
	if open_on_tutorial_step >= 0 and step >= open_on_tutorial_step:
		open_door()
