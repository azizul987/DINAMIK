extends Node

signal toxicity_changed(new_value: float, max_value: float)
signal toxicity_stage_changed(stage: ToxicityStage)
signal player_hp_changed(new_value: float, max_value: float)
signal player_overdosed()
signal player_died()
signal inventory_updated()
signal potion_consumed(potion_name: String)
signal tutorial_step_changed(step: int)
signal tutorial_completed()
signal boss_engaged(boss_name: String, max_hp: float, current_hp: float)
signal boss_hp_updated(current_hp: float, max_hp: float)
signal boss_defeated_event()

enum ToxicityStage { SAFE, MODERATE, HIGH, OVERDOSE }

var current_floor: int = 1
var is_tutorial_active: bool = true
var is_tutorial_completed: bool = false
var current_tutorial_step: int = 0
var max_hp: float = 100.0
var current_hp: float = 100.0

var tolerance_level: int = 1
var max_toxicity: float = 100.0
var current_toxicity: float = 0.0

var is_dead: bool = false

var materials := {
	"slime_gel": 0,
	"fire_essence": 0,
	"frost_wing": 0,
	"goblin_ear": 0
}

var potions := {
	"healing": 0,
	"strength": 0,
	"slow": 0,
	"berserk": 0,
	"ironskin": 0
}

var is_strength_active: bool = false
var is_slow_active: bool = false
var is_berserk_active: bool = false
var is_ironskin_active: bool = false
var ironskin_timer: float = 0.0
var last_consumed_potion: String = ""
var last_potion_timestamp: float = 0.0

var is_boss_active: bool = false
var boss_name_active: String = ""
var boss_max_hp_active: float = 0.0
var boss_current_hp_active: float = 0.0

var lpf_effect: AudioEffectLowPassFilter = null
var tinnitus_player: AudioStreamPlayer = null
var heartbeat_player: AudioStreamPlayer = null
var heartbeat_timer: float = 0.0

# BGM & SFX System
const BGM_DUNGEON_PATH := "res://resources/audio/music/dungeon_ambient.ogg"
const BGM_BOSS_PATH := "res://resources/audio/music/combat_boss.ogg"
const BGM_ENCOUNTER_PATH := "res://resources/audio/music/combat_encounter.ogg"

const SFX_UI_CLICK_PATH := "res://resources/audio/sfx/ui_click.wav"
const SFX_UI_HOVER_PATH := "res://resources/audio/sfx/ui_hover.wav"
const SFX_UI_SWITCH_PATH := "res://resources/audio/sfx/ui_switch.wav"

var bgm_player_a: AudioStreamPlayer = null
var bgm_player_b: AudioStreamPlayer = null
var _active_bgm_channel: int = 0
var _bgm_fade_tween: Tween = null
var current_bgm_track_id: String = ""
var _base_bgm_volume_db: float = -8.0
var _is_bgm_ducked: bool = false

var ui_click_player: AudioStreamPlayer = null
var ui_hover_player: AudioStreamPlayer = null
var ui_switch_player: AudioStreamPlayer = null

static var _cached_ui_click_stream: AudioStream = null
static var _cached_ui_hover_stream: AudioStream = null
static var _cached_ui_switch_stream: AudioStream = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_toxicity_audio()
	_setup_bgm_system()
	_setup_ui_audio()

func _setup_bgm_system() -> void:
	bgm_player_a = AudioStreamPlayer.new()
	bgm_player_a.name = "BGMPlayerA"
	bgm_player_a.bus = "Master"
	bgm_player_a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm_player_a)

	bgm_player_b = AudioStreamPlayer.new()
	bgm_player_b.name = "BGMPlayerB"
	bgm_player_b.bus = "Master"
	bgm_player_b.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm_player_b)

	boss_engaged.connect(_on_boss_engaged_bgm)
	boss_defeated_event.connect(_on_boss_defeated_bgm)

func _setup_ui_audio() -> void:
	ui_click_player = AudioStreamPlayer.new()
	ui_click_player.name = "UIClickPlayer"
	ui_click_player.bus = "Master"
	ui_click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_click_player)

	ui_hover_player = AudioStreamPlayer.new()
	ui_hover_player.name = "UIHoverPlayer"
	ui_hover_player.bus = "Master"
	ui_hover_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_hover_player)

	ui_switch_player = AudioStreamPlayer.new()
	ui_switch_player.name = "UISwitchPlayer"
	ui_switch_player.bus = "Master"
	ui_switch_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_switch_player)

	if FileAccess.file_exists(SFX_UI_CLICK_PATH):
		_cached_ui_click_stream = load(SFX_UI_CLICK_PATH)
		ui_click_player.stream = _cached_ui_click_stream
	if FileAccess.file_exists(SFX_UI_HOVER_PATH):
		_cached_ui_hover_stream = load(SFX_UI_HOVER_PATH)
		ui_hover_player.stream = _cached_ui_hover_stream
	if FileAccess.file_exists(SFX_UI_SWITCH_PATH):
		_cached_ui_switch_stream = load(SFX_UI_SWITCH_PATH)
		ui_switch_player.stream = _cached_ui_switch_stream

func play_bgm(stream_path: String, track_id: String = "", fade_duration: float = 1.4, target_volume_db: float = -8.0) -> void:
	if current_bgm_track_id == track_id and not track_id.is_empty():
		return

	if not FileAccess.file_exists(stream_path):
		return

	var stream = load(stream_path) as AudioStream
	if stream == null:
		return

	current_bgm_track_id = track_id
	_base_bgm_volume_db = target_volume_db
	_is_bgm_ducked = false
	var outgoing_player = bgm_player_a if _active_bgm_channel == 0 else bgm_player_b
	_active_bgm_channel = 1 if _active_bgm_channel == 0 else 0
	var incoming_player = bgm_player_a if _active_bgm_channel == 0 else bgm_player_b

	incoming_player.stream = stream
	incoming_player.volume_db = -60.0
	incoming_player.play()

	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()

	_bgm_fade_tween = create_tween().set_parallel(true)
	if outgoing_player and outgoing_player.playing:
		_bgm_fade_tween.tween_property(outgoing_player, "volume_db", -60.0, fade_duration).set_trans(Tween.TRANS_SINE)
	_bgm_fade_tween.tween_property(incoming_player, "volume_db", target_volume_db, fade_duration).set_trans(Tween.TRANS_SINE)
	if outgoing_player and outgoing_player.playing:
		_bgm_fade_tween.chain().tween_callback(outgoing_player.stop)

func duck_bgm(duck: bool, fade_duration: float = 0.25) -> void:
	if _is_bgm_ducked == duck:
		return
	_is_bgm_ducked = duck
	var active_player = bgm_player_a if _active_bgm_channel == 0 else bgm_player_b
	if not active_player or not active_player.playing:
		return
	var target_vol = _base_bgm_volume_db - (8.0 if duck else 0.0)
	var tw = create_tween()
	tw.tween_property(active_player, "volume_db", target_vol, fade_duration).set_trans(Tween.TRANS_SINE)

func stop_bgm(fade_duration: float = 1.2) -> void:
	current_bgm_track_id = ""
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_bgm_fade_tween = create_tween().set_parallel(true)
	var players_to_stop: Array[AudioStreamPlayer] = []
	if bgm_player_a and bgm_player_a.playing:
		_bgm_fade_tween.tween_property(bgm_player_a, "volume_db", -60.0, fade_duration).set_trans(Tween.TRANS_SINE)
		players_to_stop.append(bgm_player_a)
	if bgm_player_b and bgm_player_b.playing:
		_bgm_fade_tween.tween_property(bgm_player_b, "volume_db", -60.0, fade_duration).set_trans(Tween.TRANS_SINE)
		players_to_stop.append(bgm_player_b)
	if not players_to_stop.is_empty():
		_bgm_fade_tween.chain().tween_callback(func():
			for p in players_to_stop:
				if is_instance_valid(p):
					p.stop()
		)

func _on_boss_engaged_bgm(_name: String, _max_hp: float, _curr_hp: float) -> void:
	play_bgm(BGM_BOSS_PATH, "boss", 1.2, -6.0)

func _on_boss_defeated_bgm() -> void:
	play_bgm(BGM_DUNGEON_PATH, "dungeon", 2.2, -8.0)

func play_ui_click(pitch_jitter: float = 0.05) -> void:
	if ui_click_player and ui_click_player.stream:
		ui_click_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
		ui_click_player.play()

func play_ui_hover(pitch_jitter: float = 0.04) -> void:
	if ui_hover_player and ui_hover_player.stream:
		ui_hover_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
		ui_hover_player.play()

func play_ui_switch(pitch_jitter: float = 0.03) -> void:
	if ui_switch_player and ui_switch_player.stream:
		ui_switch_player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
		ui_switch_player.play()

func _setup_toxicity_audio() -> void:
	lpf_effect = AudioEffectLowPassFilter.new()
	lpf_effect.cutoff_hz = 20500.0
	lpf_effect.resonance = 0.5
	AudioServer.add_bus_effect(0, lpf_effect)

	tinnitus_player = AudioStreamPlayer.new()
	tinnitus_player.bus = "Master"
	var sample_hz := 22050.0
	var duration := 1.0
	var num_samples := int(sample_hz * duration)
	var buffer := PackedByteArray()
	buffer.resize(num_samples * 2)
	var freq := 3800.0
	for i in range(num_samples):
		var t := float(i) / sample_hz
		var sample_val := int(sin(t * freq * TAU) * 0.22 * 32767.0)
		buffer.encode_s16(i * 2, sample_val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	wav.data = buffer
	tinnitus_player.stream = wav
	tinnitus_player.volume_db = -80.0
	add_child(tinnitus_player)
	tinnitus_player.play()

	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.bus = "Master"
	var hb_hz := 22050.0
	var hb_samples := int(hb_hz * 0.18)
	var hb_buffer := PackedByteArray()
	hb_buffer.resize(hb_samples * 2)
	for i in range(hb_samples):
		var t := float(i) / hb_hz
		var env := exp(-t * 24.0)
		var val := int(sin(t * 55.0 * TAU) * env * 0.75 * 32767.0)
		hb_buffer.encode_s16(i * 2, val)

	var hb_wav := AudioStreamWAV.new()
	hb_wav.format = AudioStreamWAV.FORMAT_16_BITS
	hb_wav.mix_rate = int(hb_hz)
	hb_wav.data = hb_buffer
	heartbeat_player.stream = hb_wav
	add_child(heartbeat_player)

func _process(delta: float) -> void:
	var ratio := get_toxicity_ratio()

	if lpf_effect:
		if ratio > 0.75:
			var factor := clampf((ratio - 0.75) / 0.25, 0.0, 1.0)
			var target_cutoff := lerpf(2200.0, 650.0, factor)
			lpf_effect.cutoff_hz = lerpf(lpf_effect.cutoff_hz, target_cutoff, 10.0 * delta)

			if tinnitus_player:
				var target_tinnitus_db := lerpf(-38.0, -14.0, factor)
				tinnitus_player.volume_db = lerpf(tinnitus_player.volume_db, target_tinnitus_db, 6.0 * delta)

			if heartbeat_player and not is_dead:
				heartbeat_timer -= delta
				if heartbeat_timer <= 0.0:
					var beat_interval := lerpf(0.95, 0.38, factor)
					heartbeat_timer = beat_interval
					heartbeat_player.play()
		else:
			lpf_effect.cutoff_hz = lerpf(lpf_effect.cutoff_hz, 20500.0, 8.0 * delta)
			if tinnitus_player:
				tinnitus_player.volume_db = lerpf(tinnitus_player.volume_db, -80.0, 8.0 * delta)

	if is_dead:
		return

	var stage := get_toxicity_stage()
	match stage:
		ToxicityStage.MODERATE:
			modify_hp(-2.0 * delta)
		ToxicityStage.HIGH:
			modify_hp(-5.0 * delta)
		ToxicityStage.OVERDOSE:
			modify_hp(-15.0 * delta)

	if is_berserk_active:
		modify_hp(-2.5 * delta)

	if is_ironskin_active:
		ironskin_timer -= delta
		if ironskin_timer <= 0.0:
			is_ironskin_active = false

func get_toxicity_ratio() -> float:
	return current_toxicity / max_toxicity if max_toxicity > 0 else 0.0

func get_toxicity_stage() -> ToxicityStage:
	var ratio := get_toxicity_ratio()
	if ratio >= 1.0:
		return ToxicityStage.OVERDOSE
	elif ratio > 0.70:
		return ToxicityStage.HIGH
	elif ratio > 0.30:
		return ToxicityStage.MODERATE
	return ToxicityStage.SAFE

func add_toxicity(amount: float) -> void:
	var old_stage := get_toxicity_stage()
	current_toxicity = clampf(current_toxicity + amount, 0.0, max_toxicity)
	toxicity_changed.emit(current_toxicity, max_toxicity)
	
	var new_stage := get_toxicity_stage()
	if old_stage != new_stage:
		toxicity_stage_changed.emit(new_stage)
		
	if new_stage == ToxicityStage.OVERDOSE:
		player_overdosed.emit()

func reduce_toxicity(amount: float) -> void:
	var old_stage := get_toxicity_stage()
	current_toxicity = clampf(current_toxicity - amount, 0.0, max_toxicity)
	toxicity_changed.emit(current_toxicity, max_toxicity)
	
	var new_stage := get_toxicity_stage()
	if old_stage != new_stage:
		toxicity_stage_changed.emit(new_stage)

func modify_hp(amount: float) -> void:
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	player_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0 and not is_dead:
		is_dead = true
		player_died.emit()

func upgrade_tolerance() -> void:
	tolerance_level += 1
	max_toxicity += 25.0
	toxicity_changed.emit(current_toxicity, max_toxicity)

func reset_safe_zone() -> void:
	is_dead = false
	is_berserk_active = false
	is_strength_active = false
	is_slow_active = false
	is_ironskin_active = false
	ironskin_timer = 0.0
	last_consumed_potion = ""
	last_potion_timestamp = 0.0
	current_hp = max_hp
	current_toxicity = 0.0
	player_hp_changed.emit(current_hp, max_hp)
	toxicity_changed.emit(current_toxicity, max_toxicity)
	toxicity_stage_changed.emit(ToxicityStage.SAFE)

func add_material(item_name: String, amount: int = 1) -> void:
	if materials.has(item_name):
		materials[item_name] += amount
		inventory_updated.emit()

func can_craft(potion_name: String) -> bool:
	match potion_name:
		"healing": return materials.get("slime_gel", 0) >= 1
		"strength": return materials.get("goblin_ear", 0) >= 1 or materials.get("fire_essence", 0) >= 1
		"slow": return materials.get("frost_wing", 0) >= 1
		"berserk": return materials.get("slime_gel", 0) >= 1 and (materials.get("goblin_ear", 0) >= 1 or materials.get("fire_essence", 0) >= 1)
		"ironskin": return materials.get("slime_gel", 0) >= 2
	return false

func craft_potion(potion_name: String) -> bool:
	if not can_craft(potion_name):
		return false

	match potion_name:
		"healing":
			materials["slime_gel"] -= 1
			potions["healing"] += 1
		"strength":
			if materials.get("goblin_ear", 0) >= 1:
				materials["goblin_ear"] -= 1
			else:
				materials["fire_essence"] -= 1
			potions["strength"] += 1
		"slow":
			materials["frost_wing"] -= 1
			potions["slow"] += 1
		"berserk":
			materials["slime_gel"] -= 1
			if materials.get("goblin_ear", 0) >= 1:
				materials["goblin_ear"] -= 1
			else:
				materials["fire_essence"] -= 1
			potions["berserk"] += 1
		"ironskin":
			materials["slime_gel"] -= 2
			potions["ironskin"] += 1

	inventory_updated.emit()
	return true

func consume_potion(potion_name: String) -> bool:
	if potions.get(potion_name, 0) <= 0 or is_dead:
		return false

	potions[potion_name] -= 1
	last_consumed_potion = potion_name
	last_potion_timestamp = Time.get_ticks_msec() / 1000.0
	match potion_name:
		"healing":
			modify_hp(35.0)
			add_toxicity(15.0)
		"strength":
			is_strength_active = true
			add_toxicity(20.0)
		"slow":
			is_slow_active = true
			add_toxicity(15.0)
		"berserk":
			is_berserk_active = true
			add_toxicity(35.0)
		"ironskin":
			is_ironskin_active = true
			ironskin_timer = 15.0
			add_toxicity(20.0)

	potion_consumed.emit(potion_name)
	inventory_updated.emit()
	return true

## Memeriksa apakah efek ramuan tertentu sedang aktif pada tubuh karakter.
func is_potion_active(potion_name: String) -> bool:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	match potion_name.to_lower():
		"strength":
			return is_strength_active
		"berserk":
			return is_berserk_active
		"slow":
			return is_slow_active
		"ironskin":
			return is_ironskin_active
		"healing":
			return last_consumed_potion == "healing" and (current_time - last_potion_timestamp) < 10.0
		"any":
			return is_strength_active or is_berserk_active or is_slow_active or is_ironskin_active or (current_time - last_potion_timestamp) < 10.0
	return false

## Menghapus status efek aktif dari ramuan tertentu.
func clear_potion_buff(potion_name: String) -> void:
	match potion_name.to_lower():
		"strength":
			is_strength_active = false
		"berserk":
			is_berserk_active = false
		"slow":
			is_slow_active = false
		"ironskin":
			is_ironskin_active = false
			ironskin_timer = 0.0
		"any":
			is_strength_active = false
			is_berserk_active = false
			is_slow_active = false
			is_ironskin_active = false
			ironskin_timer = 0.0

var _hit_stop_id: int = 0

func hit_stop(duration: float = 0.05, slow: float = 0.05) -> void:
	_hit_stop_id += 1
	var current_id := _hit_stop_id
	Engine.time_scale = slow
	await get_tree().create_timer(duration, true, false, true).timeout
	if current_id == _hit_stop_id:
		Engine.time_scale = 1.0

func set_tutorial_step(step: int) -> void:
	current_tutorial_step = step
	tutorial_step_changed.emit(step)

func complete_tutorial() -> void:
	is_tutorial_active = false
	is_tutorial_completed = true
	current_tutorial_step = 8
	tutorial_completed.emit()

func reset_game_state() -> void:
	is_dead = false
	is_berserk_active = false
	is_strength_active = false
	is_slow_active = false
	is_ironskin_active = false
	ironskin_timer = 0.0
	last_consumed_potion = ""
	last_potion_timestamp = 0.0
	current_hp = max_hp
	current_toxicity = 0.0
	tolerance_level = 1
	max_toxicity = 100.0
	current_tutorial_step = 0
	is_tutorial_active = true
	is_tutorial_completed = false
	materials = {
		"slime_gel": 0,
		"fire_essence": 0,
		"frost_wing": 0,
		"goblin_ear": 0
	}
	potions = {
		"healing": 0,
		"strength": 0,
		"slow": 0,
		"berserk": 0,
		"ironskin": 0
	}
	is_boss_active = false
	boss_name_active = ""
	boss_max_hp_active = 0.0
	boss_current_hp_active = 0.0
	if lpf_effect:
		lpf_effect.cutoff_hz = 20500.0
	if tinnitus_player:
		tinnitus_player.volume_db = -80.0
	player_hp_changed.emit(current_hp, max_hp)
	toxicity_changed.emit(current_toxicity, max_toxicity)
	toxicity_stage_changed.emit(ToxicityStage.SAFE)
	inventory_updated.emit()

func trigger_boss_engaged(b_name: String, m_hp: float, c_hp: float) -> void:
	is_boss_active = true
	boss_name_active = b_name
	boss_max_hp_active = m_hp
	boss_current_hp_active = c_hp
	boss_engaged.emit(b_name, m_hp, c_hp)

func update_boss_hp(c_hp: float, m_hp: float) -> void:
	boss_current_hp_active = c_hp
	boss_max_hp_active = m_hp
	boss_hp_updated.emit(c_hp, m_hp)

func trigger_boss_defeated() -> void:
	is_boss_active = false
	boss_defeated_event.emit()
