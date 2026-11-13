extends Control

@onready var toxic_bar: ProgressBar = %Toxic
@onready var hp_bar: ProgressBar = %Hp
@onready var crafting_panel: PanelContainer = %CraftingPanel
@onready var btn_heal: Button = %BtnHeal
@onready var btn_strength: Button = %BtnStrength
@onready var btn_slow: Button = %BtnSlow
@onready var btn_berserk: Button = %BtnBerserk

@onready var count_heal: Label = %CountHeal
@onready var count_strength: Label = %CountStrength
@onready var count_slow: Label = %CountSlow
@onready var count_berserk: Label = %CountBerserk

@onready var icon_heal: TextureRect = %IconHeal
@onready var icon_strength: TextureRect = %IconStrength
@onready var icon_slow: TextureRect = %IconSlow
@onready var icon_berserk: TextureRect = %IconBerserk

@onready var btn_craft_toggle: Button = %BtnCraftToggle

@onready var mat_slime_count: Label = %MatSlimeCount
@onready var mat_fire_count: Label = %MatFireCount
@onready var mat_frost_count: Label = %MatFrostCount

@onready var target_reticle: TextureRect = %TargetReticle
@onready var player: CharacterBody3D = %Players

@onready var quick_slots_bar: HBoxContainer = $QuickSlotsBar
@onready var slot_heal: PanelContainer = $QuickSlotsBar/SlotHeal
@onready var slot_strength: PanelContainer = $QuickSlotsBar/SlotStrength
@onready var slot_slow: PanelContainer = $QuickSlotsBar/SlotSlow
@onready var slot_berserk: PanelContainer = $QuickSlotsBar/SlotBerserk
@onready var toxic_overlay: ColorRect = %ToxicOverlay if has_node("%ToxicOverlay") else null

var slot_ironskin: PanelContainer = null
var count_ironskin: Label = null
var icon_ironskin: TextureRect = null
var btn_ironskin: Button = null

var toxic_mat: ShaderMaterial = null
var _prev_hp: float = 100.0
var _prev_toxic: float = 0.0

func _setup_toxic_overlay() -> void:
	if not toxic_overlay and has_node("ToxicOverlay"):
		toxic_overlay = $ToxicOverlay as ColorRect
	if toxic_overlay and toxic_overlay.material:
		toxic_mat = toxic_overlay.material as ShaderMaterial

func _process(_delta: float) -> void:
	if player and "locked_target" in player and player.locked_target and is_instance_valid(player.locked_target):
		var cam := get_viewport().get_camera_3d()
		if cam:
			var target_pos: Vector3 = player.locked_target.global_position + Vector3(0, 0.7, 0)
			if not cam.is_position_behind(target_pos):
				var screen_pos := cam.unproject_position(target_pos)
				target_reticle.visible = true
				target_reticle.self_modulate = Color(1.0, 0.8, 0.2, 0.95)
				target_reticle.position = screen_pos - Vector2(12, 12)
				return
	elif player and player.has_method("_find_soft_target"):
		var soft_target: Node3D = player._find_soft_target()
		if soft_target and is_instance_valid(soft_target):
			var cam := get_viewport().get_camera_3d()
			if cam:
				var target_pos: Vector3 = soft_target.global_position + Vector3(0, 0.6, 0)
				if not cam.is_position_behind(target_pos):
					var screen_pos := cam.unproject_position(target_pos)
					target_reticle.visible = true
					target_reticle.self_modulate = Color(0.85, 0.95, 1.0, 0.42)
					target_reticle.position = screen_pos - Vector2(12, 12)
					return
	target_reticle.visible = false

func _ready() -> void:
	_setup_toxic_overlay()
	_setup_ironskin_ui()
	GlobalLogic.toxicity_changed.connect(_on_toxicity_changed)
	GlobalLogic.player_hp_changed.connect(_on_hp_changed)
	GlobalLogic.player_overdosed.connect(_on_overdose)
	GlobalLogic.player_died.connect(_on_player_died)
	GlobalLogic.inventory_updated.connect(_on_inventory_updated)

	btn_craft_toggle.pressed.connect(toggle_crafting)
	btn_heal.pressed.connect(func(): GlobalLogic.craft_potion("healing"))
	btn_strength.pressed.connect(func(): GlobalLogic.craft_potion("strength"))
	btn_slow.pressed.connect(func(): GlobalLogic.craft_potion("slow"))
	btn_berserk.pressed.connect(func(): GlobalLogic.craft_potion("berserk"))

	_on_toxicity_changed(GlobalLogic.current_toxicity, GlobalLogic.max_toxicity)
	_on_hp_changed(GlobalLogic.current_hp, GlobalLogic.max_hp)
	_on_inventory_updated()

func _setup_ironskin_ui() -> void:
	if quick_slots_bar and slot_berserk:
		slot_ironskin = slot_berserk.duplicate()
		slot_ironskin.name = "SlotIronskin"
		slot_ironskin.visible = false
		quick_slots_bar.add_child(slot_ironskin)
		quick_slots_bar.move_child(slot_ironskin, quick_slots_bar.get_child_count() - 2)

		count_ironskin = slot_ironskin.find_child("CountBerserk", true, false)
		if count_ironskin:
			count_ironskin.name = "CountIronskin"
			count_ironskin.text = "0"

		icon_ironskin = slot_ironskin.find_child("IconBerserk", true, false)
		if icon_ironskin:
			icon_ironskin.name = "IconIronskin"
			icon_ironskin.self_modulate = Color(0.85, 0.88, 0.95, 1.0)

		var key_label: Label = slot_ironskin.find_child("Key", true, false)
		if key_label:
			key_label.text = "5"

	var recipe_list = crafting_panel.find_child("RecipeList", true, false)
	var row_berserk = crafting_panel.find_child("RowBerserk", true, false)
	if recipe_list and row_berserk:
		var row_ironskin = row_berserk.duplicate()
		row_ironskin.name = "RowIronskin"
		recipe_list.add_child(row_ironskin)

		var icon = row_ironskin.find_child("Icon", true, false)
		if icon:
			icon.self_modulate = Color(0.85, 0.88, 0.95, 1.0)

		var name_label = row_ironskin.find_child("Name", true, false)
		if name_label:
			name_label.text = "Ironskin Potion"
			name_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 1.0))

		var cost_label = row_ironskin.find_child("Cost", true, false)
		if cost_label:
			cost_label.text = "Butuh: 2 Slime Gel"

		btn_ironskin = row_ironskin.find_child("BtnBerserk", true, false)
		if btn_ironskin:
			btn_ironskin.name = "BtnIronskin"
			btn_ironskin.pressed.connect(func(): GlobalLogic.craft_potion("ironskin"))

func _on_toxicity_changed(current: float, max_val: float) -> void:
	if toxic_mat:
		var ratio := GlobalLogic.get_toxicity_ratio()
		toxic_mat.set_shader_parameter("toxicity_ratio", ratio)

	if toxic_bar:
		toxic_bar.max_value = max_val
		toxic_bar.value = current
		if current > _prev_toxic:
			var tw := create_tween()
			toxic_bar.modulate = Color(0.6, 1.8, 0.8, 1.0)
			tw.tween_property(toxic_bar, "modulate", Color.WHITE, 0.3)
	_prev_toxic = current

	match GlobalLogic.get_toxicity_stage():
		GlobalLogic.ToxicityStage.SAFE:
			toxic_bar.add_theme_color_override("font_color", Color(0.2, 0.9, 0.5))
		GlobalLogic.ToxicityStage.MODERATE:
			toxic_bar.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		GlobalLogic.ToxicityStage.HIGH:
			toxic_bar.add_theme_color_override("font_color", Color(0.95, 0.45, 0.1))
		GlobalLogic.ToxicityStage.OVERDOSE:
			toxic_bar.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))

func _on_hp_changed(current: float, max_val: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_val
		if not GlobalLogic.is_dead:
			hp_bar.value = current
			if current < _prev_hp:
				var tw := create_tween()
				hp_bar.modulate = Color(1.8, 0.4, 0.4, 1.0)
				tw.tween_property(hp_bar, "modulate", Color.WHITE, 0.25)
	_prev_hp = current

func _on_overdose() -> void:
	if toxic_bar:
		toxic_bar.add_theme_color_override("font_color", Color.RED)

func _on_player_died() -> void:
	if hp_bar:
		hp_bar.value = 0.0
		hp_bar.add_theme_color_override("font_color", Color.RED)

func _on_inventory_updated() -> void:
	var m = GlobalLogic.materials
	var p = GlobalLogic.potions

	count_heal.text = str(p.get("healing", 0))
	count_strength.text = str(p.get("strength", 0))
	count_slow.text = str(p.get("slow", 0))
	count_berserk.text = str(p.get("berserk", 0))

	slot_heal.visible = p.get("healing", 0) > 0
	slot_strength.visible = p.get("strength", 0) > 0
	slot_slow.visible = p.get("slow", 0) > 0
	slot_berserk.visible = p.get("berserk", 0) > 0

	if slot_ironskin:
		slot_ironskin.visible = p.get("ironskin", 0) > 0
		if count_ironskin:
			count_ironskin.text = str(p.get("ironskin", 0))

	var prev_slime := int(mat_slime_count.text) if mat_slime_count.text.is_valid_int() else 0
	mat_slime_count.text = str(m["slime_gel"])
	if m["slime_gel"] > prev_slime and is_inside_tree() and mat_slime_count.visible:
		var tw := mat_slime_count.create_tween()
		mat_slime_count.pivot_offset = mat_slime_count.size * 0.5
		mat_slime_count.scale = Vector2(1.35, 1.35)
		tw.tween_property(mat_slime_count, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	mat_fire_count.text = str(m["fire_essence"])
	mat_frost_count.text = str(m["frost_wing"])

	btn_heal.disabled = not GlobalLogic.can_craft("healing")
	btn_strength.disabled = not GlobalLogic.can_craft("strength")
	btn_slow.disabled = not GlobalLogic.can_craft("slow")
	btn_berserk.disabled = not GlobalLogic.can_craft("berserk")
	if btn_ironskin:
		btn_ironskin.disabled = not GlobalLogic.can_craft("ironskin")

func toggle_crafting() -> void:
	crafting_panel.visible = not crafting_panel.visible
	if crafting_panel.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_on_inventory_updated()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if crafting_panel.visible:
			toggle_crafting()
			get_viewport().set_input_as_handled()
			return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_C:
		toggle_crafting()
		return

	match event.keycode:
		KEY_1:
			GlobalLogic.consume_potion("healing")
		KEY_2:
			GlobalLogic.consume_potion("strength")
		KEY_3:
			GlobalLogic.consume_potion("slow")
		KEY_4:
			GlobalLogic.consume_potion("berserk")
		KEY_5:
			GlobalLogic.consume_potion("ironskin")

	if OS.is_debug_build():
		if event.keycode == KEY_B:
			GlobalLogic.add_material("slime_gel", 3)
			GlobalLogic.add_material("fire_essence", 3)
			GlobalLogic.add_material("frost_wing", 3)
		elif event.keycode == KEY_T:
			GlobalLogic.add_toxicity(15.0)
		elif event.keycode == KEY_R:
			GlobalLogic.reduce_toxicity(15.0)
