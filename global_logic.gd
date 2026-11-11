extends Node

signal toxicity_changed(new_value: float, max_value: float)
signal toxicity_stage_changed(stage: ToxicityStage)
signal player_hp_changed(new_value: float, max_value: float)
signal player_overdosed()
signal player_died()
signal inventory_updated()
signal potion_consumed(potion_name: String)

enum ToxicityStage { SAFE, MODERATE, HIGH, OVERDOSE }

var current_floor: int = 1
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
	"berserk": 0
}

var is_strength_active: bool = false
var is_slow_active: bool = false
var is_berserk_active: bool = false

func _process(delta: float) -> void:
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
