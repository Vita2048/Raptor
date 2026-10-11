extends Node2D
## Run scenes/BossEffectsLab.tscn with F6 to preview the actual game effects.

const KINDS := ["boss", "boss2", "boss3"]
var boss: Node2D
var damage_slider: HSlider
var boss_picker: OptionButton
var move_toggle: CheckButton
var movement_speed: HSlider
var damage_label: Label
var status_label: Label
var explode_button: Button
var reset_button: Button
var time := 0.0
var exploding := false
var background: ColorRect

func _ready() -> void:
	_build_ui()
	_spawn_boss()

func _build_ui() -> void:
	background = ColorRect.new()
	background.color = Color("101d29")
	background.size = Vector2(3000, 2000)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -100
	add_child(background)
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(1410, 40)
	panel.size = Vector2(470, 1000)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203242")
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	_label(box, "BOSS EFFECTS LAB", 30)
	_label(box, "Live game effects • top-down view", 20)
	boss_picker = OptionButton.new()
	for title in ["Boss 1 — Cyan cruiser", "Boss 2 — Crimson assault", "Boss 3 — Heavy command"]:
		boss_picker.add_item(title)
	boss_picker.custom_minimum_size.y = 54
	boss_picker.add_theme_font_size_override("font_size", 22)
	box.add_child(boss_picker)
	boss_picker.item_selected.connect(func(_index: int): _spawn_boss())
	damage_label = _label(box, "", 26)
	damage_slider = HSlider.new()
	damage_slider.min_value = 0
	damage_slider.max_value = 100
	damage_slider.step = 1
	damage_slider.value = 85
	damage_slider.custom_minimum_size.y = 44
	box.add_child(damage_slider)
	damage_slider.value_changed.connect(_set_damage)
	_label(box, "0% = intact   /   100% = fully damaged", 18)
	var presets := HBoxContainer.new()
	box.add_child(presets)
	for armor in [70, 50, 30, 15]:
		var button := Button.new()
		button.text = "%d%% HP" % armor
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		presets.add_child(button)
		button.pressed.connect(func(): damage_slider.value = 100 - armor)
	move_toggle = CheckButton.new()
	move_toggle.text = "Move ship"
	move_toggle.button_pressed = true
	move_toggle.add_theme_font_size_override("font_size", 22)
	box.add_child(move_toggle)
	var speed_label := _label(box, "Movement speed · 1.0×", 20)
	movement_speed = HSlider.new()
	movement_speed.min_value = 0.25
	movement_speed.max_value = 2.0
	movement_speed.step = 0.05
	movement_speed.value = 1.0
	movement_speed.custom_minimum_size.y = 36
	box.add_child(movement_speed)
	movement_speed.value_changed.connect(func(value: float): speed_label.text = "Movement speed · %.2f×" % value)
	var backdrop_toggle := CheckButton.new()
	backdrop_toggle.text = "Light background"
	backdrop_toggle.add_theme_font_size_override("font_size", 22)
	box.add_child(backdrop_toggle)
	backdrop_toggle.toggled.connect(func(light: bool): background.color = Color("bba88d") if light else Color("101d29"))
	explode_button = Button.new()
	explode_button.text = "TEST FINAL EXPLOSION"
	explode_button.custom_minimum_size.y = 64
	explode_button.add_theme_font_size_override("font_size", 22)
	box.add_child(explode_button)
	explode_button.pressed.connect(test_explosion)
	reset_button = Button.new()
	reset_button.text = "Restore ship"
	reset_button.custom_minimum_size.y = 52
	reset_button.add_theme_font_size_override("font_size", 22)
	box.add_child(reset_button)
	reset_button.pressed.connect(_spawn_boss)
	status_label = _label(box, "", 20)
	_label(box, "Damage changes ease in gradually.\nThe ship returns after its explosion.\n\nNo weapons or enemies in this scene.", 19)
	var title := Label.new()
	title.text = "HULL DAMAGE / EXPLOSION PREVIEW"
	title.position = Vector2(70, 45)
	title.add_theme_font_size_override("font_size", 26)
	ui.add_child(title)

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _spawn_boss() -> void:
	if exploding:
		return
	if is_instance_valid(boss):
		boss.free()
	boss = preload("res://scripts/EnemyShip.gd").new()
	add_child(boss)
	boss.spawn(KINDS[boss_picker.selected], Vector2(700, 555))
	boss.set_physics_process(false)
	boss.set_deferred("monitoring", false)
	boss.set_deferred("monitorable", false)
	time = 0.0
	_set_damage(damage_slider.value)

func _set_damage(value: float) -> void:
	damage_label.text = "Damage %d%%  ·  Armor %d%%" % [value, 100 - value]
	if is_instance_valid(boss):
		# Preview full damage without invoking combat/death or awarding score.
		boss.health = roundi(boss.max_health * (1.0 - value / 100.0))

func _process(delta: float) -> void:
	if not is_instance_valid(boss) or exploding:
		return
	if move_toggle.button_pressed:
		time += delta * movement_speed.value
		boss.position = Vector2(700 + sin(time * 0.85) * 240, 555 + sin(time * 1.3) * 35)
	boss._update_boss_appearance(delta)
	var sources := 0
	for index in range(3):
		if boss.damage_effect.source_strength(index) * boss.damage_effect.fire_strength > 0.001:
			sources += 1
	status_label.text = "%d active hull fire%s" % [sources, "" if sources == 1 else "s"]

func test_explosion() -> void:
	if exploding or not is_instance_valid(boss):
		return
	exploding = true
	explode_button.disabled = true
	reset_button.disabled = true
	boss_picker.disabled = true
	status_label.text = "Boss detonation…"
	var pos: Vector2 = boss.global_position
	boss.hide()
	boss.damage_effect.reset()
	# Same entry point and scale used by EnemyManager in the game.
	VFX.boss_explosion(pos, 0.7)
	await get_tree().create_timer(3.2).timeout
	exploding = false
	explode_button.disabled = false
	reset_button.disabled = false
	boss_picker.disabled = false
	_spawn_boss()
