extends Control

@onready var toxic_label: Label = %Toxic
@onready var hp_label: Label = %Hp
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

func _process(_delta: float) -> void:
	if player and "locked_target" in player and player.locked_target and is_instance_valid(player.locked_target):
		var cam := get_viewport().get_camera_3d()
		if cam:
			var target_pos: Vector3 = player.locked_target.global_position + Vector3(0, 0.7, 0)
			if not cam.is_position_behind(target_pos):
				var screen_pos := cam.unproject_position(target_pos)
				target_reticle.visible = true
				target_reticle.position = screen_pos - Vector2(12, 12)
				return
	target_reticle.visible = false

func _ready() -> void:
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

func _on_toxicity_changed(current: float, _max_val: float) -> void:
	match GlobalLogic.get_toxicity_stage():
		GlobalLogic.ToxicityStage.SAFE:
			toxic_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.5))
		GlobalLogic.ToxicityStage.MODERATE:
			toxic_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		GlobalLogic.ToxicityStage.HIGH:
			toxic_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.1))
		GlobalLogic.ToxicityStage.OVERDOSE:
			toxic_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))

	toxic_label.text = str(roundi(current))

func _on_hp_changed(current: float, _max_val: float) -> void:
	if not GlobalLogic.is_dead:
		hp_label.text = str(roundi(current))

func _on_overdose() -> void:
	toxic_label.add_theme_color_override("font_color", Color.RED)

func _on_player_died() -> void:
	hp_label.text = "0"
	hp_label.add_theme_color_override("font_color", Color.RED)

func _on_inventory_updated() -> void:
	var m = GlobalLogic.materials
	var p = GlobalLogic.potions

	count_heal.text = str(p["healing"])
	count_strength.text = str(p["strength"])
	count_slow.text = str(p["slow"])
	count_berserk.text = str(p["berserk"])

	icon_heal.modulate.a = 1.0 if p["healing"] > 0 else 0.4
	icon_strength.modulate.a = 1.0 if p["strength"] > 0 else 0.4
	icon_slow.modulate.a = 1.0 if p["slow"] > 0 else 0.4
	icon_berserk.modulate.a = 1.0 if p["berserk"] > 0 else 0.4

	mat_slime_count.text = str(m["slime_gel"])
	mat_fire_count.text = str(m["fire_essence"])
	mat_frost_count.text = str(m["frost_wing"])

	btn_heal.disabled = not GlobalLogic.can_craft("healing")
	btn_strength.disabled = not GlobalLogic.can_craft("strength")
	btn_slow.disabled = not GlobalLogic.can_craft("slow")
	btn_berserk.disabled = not GlobalLogic.can_craft("berserk")

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

	if OS.is_debug_build():
		if event.keycode == KEY_B:
			GlobalLogic.add_material("slime_gel", 3)
			GlobalLogic.add_material("fire_essence", 3)
			GlobalLogic.add_material("frost_wing", 3)
		elif event.keycode == KEY_T:
			GlobalLogic.add_toxicity(15.0)
		elif event.keycode == KEY_R:
			GlobalLogic.reduce_toxicity(15.0)
