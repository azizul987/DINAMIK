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

enum ToxicityStage { SAFE, MODERATE, HIGH, OVERDOSE }

var current_floor: int = 1
var is_tutorial_active: bool = true
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
	"frost_wing": 0
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

var lpf_effect: AudioEffectLowPassFilter = null
var tinnitus_player: AudioStreamPlayer = null
var heartbeat_player: AudioStreamPlayer = null
var heartbeat_timer: float = 0.0

func _ready() -> void:
	_setup_toxicity_audio()

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
		"healing": return materials["slime_gel"] >= 1
		"strength": return materials["fire_essence"] >= 1
		"slow": return materials["frost_wing"] >= 1
		"berserk": return materials["slime_gel"] >= 1 and materials["fire_essence"] >= 1
		"ironskin": return materials["slime_gel"] >= 2
	return false

func craft_potion(potion_name: String) -> bool:
	if not can_craft(potion_name):
		return false

	match potion_name:
		"healing":
			materials["slime_gel"] -= 1
			potions["healing"] += 1
		"strength":
			materials["fire_essence"] -= 1
			potions["strength"] += 1
		"slow":
			materials["frost_wing"] -= 1
			potions["slow"] += 1
		"berserk":
			materials["slime_gel"] -= 1
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
	current_tutorial_step = 4
	tutorial_completed.emit()
