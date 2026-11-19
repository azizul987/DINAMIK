extends Control

const ALCHEMY_SPARK_SCENE: PackedScene = preload("res://alchemy_spark_burst.tscn")
const ALCHEMY_TOAST_SCENE: PackedScene = preload("res://alchemy_toast.tscn")
const END_SCREEN_SCENE: PackedScene = preload("res://end_screen.tscn")

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

@onready var potion_audio: AudioStreamPlayer = %PotionAudio if has_node("%PotionAudio") else null
@onready var potion_flash_overlay: ColorRect = %PotionFlashOverlay if has_node("%PotionFlashOverlay") else null
@onready var toast_container: Control = %ToastContainer if has_node("%ToastContainer") else null

@onready var row_heal: PanelContainer = crafting_panel.find_child("RowHeal", true, false) as PanelContainer if crafting_panel else null
@onready var row_strength: PanelContainer = crafting_panel.find_child("RowStrength", true, false) as PanelContainer if crafting_panel else null
@onready var row_slow: PanelContainer = crafting_panel.find_child("RowSlow", true, false) as PanelContainer if crafting_panel else null
@onready var row_berserk: PanelContainer = crafting_panel.find_child("RowBerserk", true, false) as PanelContainer if crafting_panel else null
var row_ironskin: PanelContainer = null

static var _cached_craft_wav: AudioStreamWAV = null
static var _cached_drink_wav: AudioStreamWAV = null
static var _cached_fail_wav: AudioStreamWAV = null

var slot_ironskin: PanelContainer = null
var count_ironskin: Label = null
var icon_ironskin: TextureRect = null
var btn_ironskin: Button = null

var slot_nightvision: PanelContainer = null
var count_nightvision: Label = null
var icon_nightvision: TextureRect = null
var btn_nightvision: Button = null
var row_nightvision: PanelContainer = null

var toxic_mat: ShaderMaterial = null
var _prev_hp: float = 100.0
var _prev_toxic: float = 0.0
var _end_screen: CanvasLayer = null

@onready var boss_bar_container: PanelContainer = %BossBarContainer if has_node("%BossBarContainer") else null
@onready var boss_title: Label = %BossTitle if has_node("%BossTitle") else null
@onready var boss_pips: HBoxContainer = %BossPips if has_node("%BossPips") else null
@onready var pip1: Label = %Pip1 if has_node("%Pip1") else null
@onready var pip2: Label = %Pip2 if has_node("%Pip2") else null
@onready var pip3: Label = %Pip3 if has_node("%Pip3") else null
@onready var boss_under_bar: ProgressBar = %BossUnderBar if has_node("%BossUnderBar") else null
@onready var boss_lag_bar: ProgressBar = %BossLagBar if has_node("%BossLagBar") else null
@onready var boss_hp_bar: ProgressBar = %BossHpBar if has_node("%BossHpBar") else null

var _boss_lag_tween: Tween = null
var _boss_flash_tween: Tween = null
var _current_boss_layer: int = 1
var _boss_fill_style: StyleBoxFlat = null
var _boss_under_style: StyleBoxFlat = null

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
	target_reticle.visible = false

func _ready() -> void:
	_setup_toxic_overlay()
	_setup_ironskin_ui()
	_setup_nightvision_ui()
	GlobalLogic.toxicity_changed.connect(_on_toxicity_changed)
	GlobalLogic.player_hp_changed.connect(_on_hp_changed)
	GlobalLogic.player_overdosed.connect(_on_overdose)
	GlobalLogic.player_died.connect(_on_player_died)
	GlobalLogic.inventory_updated.connect(_on_inventory_updated)

	btn_craft_toggle.pressed.connect(toggle_crafting)
	btn_craft_toggle.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_heal.pressed.connect(func(): _on_craft_button_pressed("healing", btn_heal, row_heal))
	btn_heal.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_strength.pressed.connect(func(): _on_craft_button_pressed("strength", btn_strength, row_strength))
	btn_strength.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_slow.pressed.connect(func(): _on_craft_button_pressed("slow", btn_slow, row_slow))
	btn_slow.mouse_entered.connect(GlobalLogic.play_ui_hover)
	btn_berserk.pressed.connect(func(): _on_craft_button_pressed("berserk", btn_berserk, row_berserk))
	btn_berserk.mouse_entered.connect(GlobalLogic.play_ui_hover)
	GlobalLogic.potion_consumed.connect(_on_potion_consumed_juice)
	GlobalLogic.boss_engaged.connect(_on_boss_engaged)
	GlobalLogic.boss_hp_updated.connect(_on_boss_hp_updated)
	GlobalLogic.boss_defeated_event.connect(_on_boss_defeated)
	GlobalLogic.game_won.connect(_on_game_won)
	GlobalLogic.player_death_animation_finished.connect(_on_player_death_animation_finished)

	_on_toxicity_changed(GlobalLogic.current_toxicity, GlobalLogic.max_toxicity)
	_on_hp_changed(GlobalLogic.current_hp, GlobalLogic.max_hp)
	_on_inventory_updated()

	if GlobalLogic.is_boss_active:
		_on_boss_engaged(GlobalLogic.boss_name_active, GlobalLogic.boss_max_hp_active, GlobalLogic.boss_current_hp_active)
	else:
		GlobalLogic.play_bgm(GlobalLogic.BGM_DUNGEON_PATH, "dungeon", 2.0, -8.0)

	_setup_objective_bar_listener()

func _setup_objective_bar_listener() -> void:
	var objective_bar := find_child("ObjectiveBar", true, false)
	if not objective_bar:
		return

	# Validasi: ObjectiveBar HANYA boleh aktif jika ada TutorialController di scene (main.tscn)
	# dan tutorial belum diselesaikan. Di Level 1, Level 2, Safe Room, otomatis disembunyikan.
	var has_tutorial: bool = has_node("../../../TutorialController") or (get_tree() and get_tree().root.find_child("TutorialController", true, false) != null)

	if not has_tutorial or GlobalLogic.is_tutorial_completed or not GlobalLogic.is_tutorial_active:
		objective_bar.visible = false
		return

	objective_bar.visible = true
	GlobalLogic.tutorial_completed.connect(func():
		if is_instance_valid(objective_bar):
			var tw := create_tween()
			tw.tween_property(objective_bar, "modulate:a", 0.0, 0.4)
			tw.chain().tween_callback(objective_bar.hide)
	)

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
			btn_ironskin.pressed.connect(func(): _on_craft_button_pressed("ironskin", btn_ironskin, row_ironskin))
			btn_ironskin.mouse_entered.connect(GlobalLogic.play_ui_hover)

func _setup_nightvision_ui() -> void:
	if quick_slots_bar and slot_berserk:
		slot_nightvision = slot_berserk.duplicate()
		slot_nightvision.name = "SlotNightvision"
		slot_nightvision.visible = false
		quick_slots_bar.add_child(slot_nightvision)
		quick_slots_bar.move_child(slot_nightvision, quick_slots_bar.get_child_count() - 2)

		count_nightvision = slot_nightvision.find_child("CountBerserk", true, false)
		if count_nightvision:
			count_nightvision.name = "CountNightvision"
			count_nightvision.text = "0"

		icon_nightvision = slot_nightvision.find_child("IconBerserk", true, false)
		if icon_nightvision:
			icon_nightvision.name = "IconNightvision"
			icon_nightvision.self_modulate = Color(0.7, 1.0, 0.4, 1.0)

		var key_label: Label = slot_nightvision.find_child("Key", true, false)
		if key_label:
			key_label.text = "6"

	var recipe_list = crafting_panel.find_child("RecipeList", true, false)
	var row_berserk_src = crafting_panel.find_child("RowBerserk", true, false)
	if recipe_list and row_berserk_src:
		row_nightvision = row_berserk_src.duplicate()
		row_nightvision.name = "RowNightvision"
		recipe_list.add_child(row_nightvision)

		var icon = row_nightvision.find_child("Icon", true, false)
		if icon:
			icon.self_modulate = Color(0.7, 1.0, 0.4, 1.0)

		var name_label = row_nightvision.find_child("Name", true, false)
		if name_label:
			name_label.text = "Night Vision Potion"
			name_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.4, 1.0))

		var cost_label = row_nightvision.find_child("Cost", true, false)
		if cost_label:
			cost_label.text = "Butuh: 1 Frost Wing + 1 Slime Gel"

		btn_nightvision = row_nightvision.find_child("BtnBerserk", true, false)
		if btn_nightvision:
			btn_nightvision.name = "BtnNightvision"
			btn_nightvision.pressed.connect(func(): _on_craft_button_pressed("nightvision", btn_nightvision, row_nightvision))
			btn_nightvision.mouse_entered.connect(GlobalLogic.play_ui_hover)

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
	# Fallback pengaman jika tidak ada animasi kematian yang terpancar
	var fallback_timer := get_tree().create_timer(4.5)
	fallback_timer.timeout.connect(func():
		if GlobalLogic.is_dead and not (_end_screen and _end_screen.get("_is_shown")):
			_show_end_screen("Kamu Mati", Color(0.92, 0.18, 0.22, 1.0), "")
	)

func _on_player_death_animation_finished() -> void:
	_show_end_screen("Kamu Mati", Color(0.92, 0.18, 0.22, 1.0), "")

func _on_game_won() -> void:
	_show_end_screen("Kamu Menang", Color(0.95, 0.82, 0.22, 1.0), "Kamu berhasil keluar dari dungeon!")

## Menampilkan layar akhir (mati / menang).
func _show_end_screen(title_text: String, color: Color, subtitle_text: String = "") -> void:
	if not _end_screen:
		if not END_SCREEN_SCENE:
			return
		_end_screen = END_SCREEN_SCENE.instantiate() as CanvasLayer
		if _end_screen:
			add_child(_end_screen)
	if _end_screen and _end_screen.has_method("show_end"):
		_end_screen.show_end(title_text, color, subtitle_text)

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

	if slot_nightvision:
		slot_nightvision.visible = p.get("nightvision", 0) > 0
		if count_nightvision:
			count_nightvision.text = str(p.get("nightvision", 0))

	var prev_slime := int(mat_slime_count.text) if mat_slime_count.text.is_valid_int() else 0
	mat_slime_count.text = str(m["slime_gel"])
	if m["slime_gel"] > prev_slime and is_inside_tree() and mat_slime_count.visible:
		var tw := mat_slime_count.create_tween()
		mat_slime_count.pivot_offset = mat_slime_count.size * 0.5
		mat_slime_count.scale = Vector2(1.35, 1.35)
		tw.tween_property(mat_slime_count, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	mat_fire_count.text = str(m.get("goblin_ear", 0) + m.get("fire_essence", 0))
	mat_frost_count.text = str(m["frost_wing"])

	btn_heal.disabled = not GlobalLogic.can_craft("healing")
	btn_strength.disabled = not GlobalLogic.can_craft("strength")
	btn_slow.disabled = not GlobalLogic.can_craft("slow")
	btn_berserk.disabled = not GlobalLogic.can_craft("berserk")
	if btn_ironskin:
		btn_ironskin.disabled = not GlobalLogic.can_craft("ironskin")
	if btn_nightvision:
		btn_nightvision.disabled = not GlobalLogic.can_craft("nightvision")

func toggle_crafting() -> void:
	crafting_panel.visible = not crafting_panel.visible
	GlobalLogic.play_ui_switch()
	if crafting_panel.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		crafting_panel.pivot_offset = crafting_panel.size * 0.5
		crafting_panel.scale = Vector2(0.85, 0.85)
		var tw := crafting_panel.create_tween()
		tw.tween_property(crafting_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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

	if event.keycode == KEY_C or event.keycode == KEY_TAB:
		toggle_crafting()
		get_viewport().set_input_as_handled()
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
		KEY_6:
			GlobalLogic.consume_potion("nightvision")

	if OS.is_debug_build():
		if event.keycode == KEY_B:
			GlobalLogic.add_material("slime_gel", 3)
			GlobalLogic.add_material("fire_essence", 3)
			GlobalLogic.add_material("frost_wing", 3)
		elif event.keycode == KEY_T:
			GlobalLogic.add_toxicity(15.0)
		elif event.keycode == KEY_R:
			GlobalLogic.reduce_toxicity(15.0)

func _on_craft_button_pressed(potion_name: String, btn: Button, row: Control) -> void:
	if not btn:
		return
	if GlobalLogic.can_craft(potion_name):
		GlobalLogic.craft_potion(potion_name)
		_play_potion_sfx("craft")

		# 1. Button squash & stretch with overshoot
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2(1.28, 0.72)
		var tw_btn := btn.create_tween()
		tw_btn.tween_property(btn, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# 2. Row flash in signature potion color & icon pop
		var tint: Color = _get_potion_color(potion_name)
		if row:
			row.modulate = tint * 1.5
			var tw_row := row.create_tween()
			tw_row.tween_property(row, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			var row_icon := row.find_child("Icon", true, false) as Control
			if row_icon:
				row_icon.pivot_offset = row_icon.size * 0.5
				row_icon.scale = Vector2(1.5, 1.5)
				row_icon.rotation = deg_to_rad(-16.0)
				var tw_icon := row_icon.create_tween()
				tw_icon.set_parallel(true)
				tw_icon.tween_property(row_icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tw_icon.tween_property(row_icon, "rotation", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# 3. Particle burst of alchemical sparks
		_spawn_alchemy_spark_burst(btn.global_position + (btn.size * 0.5), tint)

		# 4. Floating juicy Toast
		_show_alchemy_toast(potion_name, tint)

		# 5. QuickSlot bar celebration bounce & glow
		var slot := _get_potion_slot(potion_name)
		_juice_slot_crafted(slot, tint)

		# 6. Micro camera shake
		if player and "camera_pivot" in player and player.camera_pivot and player.camera_pivot.has_method("add_trauma"):
			player.camera_pivot.add_trauma(0.08)
	else:
		_play_potion_sfx("fail")
		# 7. Button wobble / shake on insufficient materials
		var orig_pos_x := btn.position.x
		var tw_fail := btn.create_tween()
		tw_fail.tween_property(btn, "position:x", orig_pos_x - 7.0, 0.04)
		tw_fail.tween_property(btn, "position:x", orig_pos_x + 7.0, 0.04)
		tw_fail.tween_property(btn, "position:x", orig_pos_x - 3.5, 0.04)
		tw_fail.tween_property(btn, "position:x", orig_pos_x, 0.04)

func _get_potion_color(potion_name: String) -> Color:
	match potion_name:
		"healing":
			return Color(0.25, 1.0, 0.5, 1.0)
		"strength":
			return Color(1.0, 0.75, 0.2, 1.0)
		"slow":
			return Color(0.3, 0.85, 1.0, 1.0)
		"berserk":
			return Color(1.0, 0.25, 0.35, 1.0)
		"ironskin":
			return Color(0.85, 0.92, 1.0, 1.0)
		"nightvision":
			return Color(0.7, 1.0, 0.4, 1.0)
	return Color.WHITE

func _get_potion_slot(potion_name: String) -> Control:
	match potion_name:
		"healing": return slot_heal
		"strength": return slot_strength
		"slow": return slot_slow
		"berserk": return slot_berserk
		"ironskin": return slot_ironskin
		"nightvision": return slot_nightvision
	return null

func _juice_slot_crafted(slot: Control, tint: Color) -> void:
	if not slot or not slot.is_inside_tree():
		return
	slot.visible = true
	slot.pivot_offset = slot.size * 0.5
	slot.scale = Vector2(1.45, 1.45)
	slot.modulate = tint * 1.5
	var tw := slot.create_tween()
	tw.set_parallel(true)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _juice_slot_consumed(slot: Control, tint: Color) -> void:
	if not slot or not slot.is_inside_tree():
		return
	slot.pivot_offset = slot.size * 0.5
	slot.scale = Vector2(0.72, 0.72)
	slot.modulate = tint * 1.8
	var tw := slot.create_tween()
	tw.set_parallel(true)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot, "modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _pulse_potion_vignette(tint: Color) -> void:
	if not potion_flash_overlay:
		return
	potion_flash_overlay.visible = true
	potion_flash_overlay.color = Color(tint.r, tint.g, tint.b, 0.35)
	var tw := potion_flash_overlay.create_tween()
	tw.tween_property(potion_flash_overlay, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(potion_flash_overlay):
			potion_flash_overlay.visible = false
	)

func _spawn_alchemy_spark_burst(pos: Vector2, tint: Color) -> void:
	if not ALCHEMY_SPARK_SCENE:
		return
	var spark := ALCHEMY_SPARK_SCENE.instantiate()
	if not spark:
		return
	add_child(spark)
	if spark.has_method("pop"):
		spark.pop(pos, tint)

func _show_alchemy_toast(potion_name: String, tint: Color) -> void:
	if not ALCHEMY_TOAST_SCENE or not toast_container:
		return
	var toast := ALCHEMY_TOAST_SCENE.instantiate()
	if not toast:
		return
	toast_container.add_child(toast)
	var screen_size := get_viewport_rect().size
	var start_pos := Vector2(screen_size.x * 0.5 - 90.0, screen_size.y * 0.5 - 215.0)
	if toast.has_method("pop"):
		toast.pop(potion_name, tint, start_pos)

func _on_game_autosaved() -> void:
	pass

func _on_potion_consumed_juice(potion_name: String) -> void:
	_play_potion_sfx("drink")
	var tint := _get_potion_color(potion_name)
	_pulse_potion_vignette(tint)
	var slot := _get_potion_slot(potion_name)
	_juice_slot_consumed(slot, tint)

	if player and "camera_pivot" in player and player.camera_pivot:
		var cam = player.camera_pivot
		match potion_name:
			"healing":
				if cam.has_method("fov_punch"):
					cam.fov_punch(-1.8, 0.22)
			"strength":
				if cam.has_method("add_trauma"):
					cam.add_trauma(0.18)
				if cam.has_method("fov_punch"):
					cam.fov_punch(2.4, 0.18)
			"slow":
				if cam.has_method("fov_punch"):
					cam.fov_punch(1.6, 0.25)
			"berserk":
				if cam.has_method("add_trauma"):
					cam.add_trauma(0.38)
				if cam.has_method("fov_punch"):
					cam.fov_punch(3.8, 0.25)
			"ironskin":
				if cam.has_method("add_trauma"):
					cam.add_trauma(0.20)
			"nightvision":
				if cam.has_method("fov_punch"):
					cam.fov_punch(2.0, 0.3)

func _play_potion_sfx(type: String) -> void:
	if not potion_audio:
		return
	match type:
		"craft":
			if not _cached_craft_wav:
				_cached_craft_wav = _generate_craft_wav()
			potion_audio.stream = _cached_craft_wav
			potion_audio.pitch_scale = randf_range(0.96, 1.04)
		"drink":
			if not _cached_drink_wav:
				_cached_drink_wav = _generate_drink_wav()
			potion_audio.stream = _cached_drink_wav
			potion_audio.pitch_scale = randf_range(0.96, 1.04)
		"fail":
			if not _cached_fail_wav:
				_cached_fail_wav = _generate_fail_wav()
			potion_audio.stream = _cached_fail_wav
			potion_audio.pitch_scale = randf_range(0.92, 1.08)
	potion_audio.play()

static func _generate_craft_wav() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.38
	var total := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total * 2)

	for i in range(total):
		var t := float(i) / sample_hz
		var t_glass := maxf(0.0, t - 0.04)
		var glass_env := exp(-t_glass * 28.0) if t >= 0.04 else 0.0
		var glass := (sin(t_glass * 2400.0 * TAU) * 0.5 + sin(t_glass * 3600.0 * TAU) * 0.3) * glass_env
		var bubble_env := exp(-t * 8.0) * (1.0 - exp(-t * 60.0))
		var bubble_freq := 320.0 + sin(t * 45.0 * TAU) * 140.0
		var bubble := sin(t * bubble_freq * TAU) * bubble_env * 0.4
		var fizz := (randf() * 2.0 - 1.0) * exp(-t * 12.0) * 0.15
		var t_chime := maxf(0.0, t - 0.10)
		var chime_env := exp(-t_chime * 10.0) if t >= 0.10 else 0.0
		var chime_freq := lerpf(880.0, 1760.0, clampf(t_chime / 0.25, 0.0, 1.0))
		var chime := sin(t_chime * chime_freq * TAU) * chime_env * 0.35

		var sample := int(clampf((glass * 0.5 + bubble + fizz + chime) * 0.75, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	return wav

static func _generate_drink_wav() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.44
	var total := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total * 2)

	for i in range(total):
		var t := float(i) / sample_hz
		# 1. Cork pop (0.00s - 0.05s)
		var cork_env := exp(-t * 45.0)
		var cork_freq := lerpf(220.0, 680.0, clampf(t / 0.04, 0.0, 1.0))
		var cork := sin(t * cork_freq * TAU) * cork_env * 0.65

		# 2. Liquid gulp / swallow (0.07s - 0.22s)
		var t_gulp := maxf(0.0, t - 0.07)
		var gulp_env := exp(-t_gulp * 16.0) if t >= 0.07 else 0.0
		var gulp_freq := lerpf(260.0, 120.0, clampf(t_gulp / 0.16, 0.0, 1.0))
		var gulp := sin(t_gulp * gulp_freq * TAU) * gulp_env * 0.55

		# 3. Magic buff shimmer chime (0.18s - 0.44s)
		var t_chime := maxf(0.0, t - 0.18)
		var chime_env := exp(-t_chime * 9.0) if t >= 0.18 else 0.0
		var chime1 := sin(t_chime * 1174.66 * TAU) * 0.35
		var chime2 := sin(t_chime * 1760.00 * TAU) * 0.25
		var chime3 := sin(t_chime * 2349.32 * TAU) * 0.18
		var chime := (chime1 + chime2 + chime3) * chime_env

		var sample := int(clampf((cork + gulp + chime) * 0.85, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	return wav

static func _generate_fail_wav() -> AudioStreamWAV:
	var sample_hz := 22050.0
	var dur := 0.14
	var total := int(sample_hz * dur)
	var buffer := PackedByteArray()
	buffer.resize(total * 2)

	for i in range(total):
		var t := float(i) / sample_hz
		var env := exp(-t * 35.0)
		var val := int((sin(t * 120.0 * TAU) * 0.7 + (randf() * 2.0 - 1.0) * 0.2) * env * 0.45 * 32767.0)
		buffer.encode_s16(i * 2, val)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_hz)
	wav.data = buffer
	return wav

func _on_boss_engaged(b_name: String, _m_hp: float, c_hp: float) -> void:
	if not boss_bar_container:
		return
	if boss_title:
		boss_title.text = b_name

	_current_boss_layer = 1
	_ensure_boss_styles()
	_update_boss_layer_visuals(c_hp, false)

	boss_bar_container.visible = true
	boss_bar_container.modulate.a = 0.0
	boss_bar_container.position.y = -20.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(boss_bar_container, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(boss_bar_container, "position:y", 16.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_boss_hp_updated(c_hp: float, _m_hp: float) -> void:
	if not boss_bar_container:
		return
	if not boss_bar_container.visible:
		boss_bar_container.visible = true
		boss_bar_container.modulate.a = 1.0
	_update_boss_layer_visuals(c_hp, true)

func _on_boss_defeated() -> void:
	if boss_bar_container:
		_set_pip_states(false, false, false)

		var tw := create_tween()
		tw.tween_interval(0.4)
		tw.tween_property(boss_bar_container, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			boss_bar_container.visible = false
		)

	await get_tree().create_timer(1.2).timeout
	_show_end_screen("Kamu Menang", Color(0.95, 0.82, 0.22, 1.0), "Arcmage Malakor telah tumbang!")

func _ensure_boss_styles() -> void:
	if not boss_hp_bar or not boss_under_bar:
		return
	if not _boss_fill_style:
		var fill_sb = boss_hp_bar.get_theme_stylebox("fill")
		if fill_sb is StyleBoxFlat:
			_boss_fill_style = fill_sb.duplicate() as StyleBoxFlat
			boss_hp_bar.add_theme_stylebox_override("fill", _boss_fill_style)

	if not _boss_under_style:
		var under_sb = boss_under_bar.get_theme_stylebox("fill")
		if under_sb is StyleBoxFlat:
			_boss_under_style = under_sb.duplicate() as StyleBoxFlat
			boss_under_bar.add_theme_stylebox_override("fill", _boss_under_style)

func _update_boss_layer_visuals(c_hp: float, animate_lag: bool) -> void:
	_ensure_boss_styles()
	var layer_val: float = 60.0
	var new_layer: int = 1
	var active_color: Color = Color(0.68, 0.32, 0.95, 1.0) # Violet Amethyst
	var under_color: Color = Color(0.06, 0.72, 0.85, 1.0) # Glacial Cyan

	if c_hp > 120.0:
		new_layer = 1
		layer_val = clampf(c_hp - 120.0, 0.0, 60.0)
		active_color = Color(0.68, 0.32, 0.95, 1.0)
		under_color = Color(0.06, 0.72, 0.85, 1.0)
		_set_pip_states(true, true, true)
	elif c_hp > 60.0:
		new_layer = 2
		layer_val = clampf(c_hp - 60.0, 0.0, 60.0)
		active_color = Color(0.06, 0.72, 0.85, 1.0)
		under_color = Color(0.92, 0.22, 0.32, 1.0)
		_set_pip_states(false, true, true)
	elif c_hp > 0.0:
		new_layer = 3
		layer_val = clampf(c_hp, 0.0, 60.0)
		active_color = Color(0.92, 0.22, 0.32, 1.0)
		under_color = Color(0.12, 0.14, 0.18, 1.0)
		_set_pip_states(false, false, true)
	else:
		new_layer = 3
		layer_val = 0.0
		active_color = Color(0.92, 0.22, 0.32, 1.0)
		under_color = Color(0.12, 0.14, 0.18, 1.0)
		_set_pip_states(false, false, false)

	if new_layer != _current_boss_layer:
		_trigger_layer_break(new_layer)
		_current_boss_layer = new_layer

	if _boss_fill_style:
		_boss_fill_style.bg_color = active_color
	if _boss_under_style:
		_boss_under_style.bg_color = under_color

	if boss_hp_bar:
		boss_hp_bar.value = layer_val

	if boss_lag_bar:
		if not animate_lag:
			boss_lag_bar.value = layer_val
		else:
			if _boss_lag_tween and _boss_lag_tween.is_valid():
				_boss_lag_tween.kill()
			_boss_lag_tween = create_tween()
			_boss_lag_tween.tween_interval(0.22)
			_boss_lag_tween.tween_property(boss_lag_bar, "value", layer_val, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_pip_states(p1_active: bool, p2_active: bool, p3_active: bool) -> void:
	if pip1:
		pip1.text = "◆" if p1_active else "◇"
		pip1.modulate = Color(0.68, 0.32, 0.95, 1.0) if p1_active else Color(0.4, 0.45, 0.55, 0.45)
	if pip2:
		pip2.text = "◆" if p2_active else "◇"
		pip2.modulate = Color(0.06, 0.72, 0.85, 1.0) if p2_active else Color(0.4, 0.45, 0.55, 0.45)
	if pip3:
		pip3.text = "◆" if p3_active else "◇"
		pip3.modulate = Color(0.92, 0.22, 0.32, 1.0) if p3_active else Color(0.4, 0.45, 0.55, 0.45)

func _trigger_layer_break(new_layer: int) -> void:
	if not boss_bar_container:
		return
	if _boss_flash_tween and _boss_flash_tween.is_valid():
		_boss_flash_tween.kill()

	_boss_flash_tween = create_tween()
	boss_bar_container.self_modulate = Color(2.0, 2.0, 2.0, 1.0)
	_boss_flash_tween.tween_property(boss_bar_container, "self_modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var broken_pip: Label = pip1 if new_layer == 2 else pip2
	if broken_pip:
		var p_tw := create_tween()
		p_tw.tween_property(broken_pip, "scale", Vector2(1.5, 1.5), 0.1)
		p_tw.tween_property(broken_pip, "scale", Vector2.ONE, 0.18)
