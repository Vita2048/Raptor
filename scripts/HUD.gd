extends CanvasLayer

const CYAN := Color("86d8de")
const INK := Color("101c25")
const WHITE := Color("e8efed")
const MUTED := Color("95a9b1")
const AMBER := Color("efb26e")
const PlayerHealthBarScript := preload("res://scripts/PlayerHealthBar.gd")

var health_bar: Control
var score_label: Label
var level_label: Label
var boss_bar: ProgressBar
var boss_panel: Panel
var game_over_overlay: Control
var result_label: Label
var play_again_button: Button
var sound_button: Button
var root: Control

func _ready() -> void:
	_build_ui()
	GameState.score_changed.connect(_on_score_changed)
	GameState.player_health_changed.connect(_on_player_health_changed)
	GameState.boss_started.connect(_on_boss_started)
	GameState.boss_health_changed.connect(_on_boss_health_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.level_advanced.connect(_on_level_advanced)
	_on_score_changed(GameState.score)
	_on_player_health_changed(GameState.player_health, GameState.player_max_health)
	_on_level_advanced(GameState.current_level)

func _style(color: Color, border: Color = Color("344953")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(5)
	return style

func _panel(parent: Node, at: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.065, 0.085, 0.90)))
	parent.add_child(panel)
	return panel

func _label(parent: Node, at: Vector2, dimensions: Vector2, caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, at: Vector2, dimensions: Vector2, caption: String) -> Button:
	var button := Button.new()
	button.position = at
	button.size = dimensions
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", _style(INK))
	button.add_theme_stylebox_override("hover", _style(Color("203d49"), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("305461"), CYAN))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), CYAN))
	parent.add_child(button)
	return button

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var armor_panel := _panel(root, Vector2(32, 28), Vector2(360, 94))
	health_bar = PlayerHealthBarScript.new()
	health_bar.position = Vector2(18, 12)
	health_bar.size = Vector2(324, 70)
	armor_panel.add_child(health_bar)

	var score_panel := _panel(root, Vector2(1570, 28), Vector2(318, 94))
	_label(score_panel, Vector2(18, 10), Vector2(100, 22), "SCORE", 16, MUTED)
	level_label = _label(score_panel, Vector2(140, 10), Vector2(160, 22), "", 16, CYAN)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label = _label(score_panel, Vector2(18, 34), Vector2(282, 46), "", 32, WHITE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	boss_panel = _panel(root, Vector2(660, 28), Vector2(600, 72))
	var boss_title := _label(boss_panel, Vector2(18, 8), Vector2(564, 28), "HEAVY CONTACT  /  BOSS ARMOR", 17, AMBER)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(18, 44)
	boss_bar.size = Vector2(564, 8)
	boss_bar.show_percentage = false
	boss_bar.add_theme_font_size_override("font_size", 1)
	boss_bar.add_theme_stylebox_override("background", _style(Color("27313a"), Color("27313a")))
	boss_bar.add_theme_stylebox_override("fill", _style(AMBER, AMBER))
	boss_panel.add_child(boss_bar)
	boss_bar.size = Vector2(564, 8)
	boss_panel.hide()

	sound_button = _button(root, Vector2(1738, 1008), Vector2(150, 42), "")
	sound_button.focus_mode = Control.FOCUS_NONE
	_update_sound_label()
	sound_button.pressed.connect(func():
		VFX.audio.set_muted(not VFX.audio.muted)
		_update_sound_label()
	)

	game_over_overlay = Control.new()
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(game_over_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.8)
	game_over_overlay.add_child(shade)
	var result_panel := _panel(game_over_overlay, Vector2(630, 324), Vector2(660, 390))
	var eyebrow := _label(result_panel, Vector2(30, 32), Vector2(600, 30), "RAPTOR  /  SHADOW RUN", 18, CYAN)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(result_panel, Vector2(30, 80), Vector2(600, 74), "MISSION LOST", 54, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label = _label(result_panel, Vector2(30, 180), Vector2(600, 45), "", 23, MUTED)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_again_button = _button(result_panel, Vector2(180, 280), Vector2(300, 62), "FLY AGAIN")
	play_again_button.pressed.connect(func(): get_tree().reload_current_scene())
	game_over_overlay.hide()

func _update_sound_label() -> void:
	sound_button.text = "SOUND  OFF" if VFX.audio.muted else "SOUND  ON"

func _on_score_changed(score: int) -> void:
	score_label.text = "%07d" % score

func _on_player_health_changed(health: int, max_health: int) -> void:
	health_bar.set_health(health, max_health)

func _on_boss_started(max_health: int) -> void:
	boss_panel.show()
	boss_bar.max_value = max_health
	boss_bar.value = max_health

func _on_boss_health_changed(health: int, max_health: int) -> void:
	boss_bar.max_value = max_health
	boss_bar.value = health
	if health <= 0:
		boss_panel.hide()

func _on_level_advanced(level: int) -> void:
	level_label.text = "SECTOR  %02d" % level

func _on_game_over() -> void:
	boss_panel.hide()
	result_label.text = "SECTOR %02d     /     SCORE %07d" % [GameState.current_level, GameState.score]
	game_over_overlay.show()
	game_over_overlay.modulate.a = 0.0
	create_tween().tween_property(game_over_overlay, "modulate:a", 1.0, 0.4)
	play_again_button.grab_focus()

func show_level_transition(from_level: int, to_level: int) -> void:
	var panel := _panel(root, Vector2(660, 200), Vector2(600, 110))
	var label := _label(panel, Vector2(24, 18), Vector2(552, 74), "SECTOR %02d CLEARED\nENTERING SECTOR %02d" % [from_level, to_level], 25, WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)
