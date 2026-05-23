extends CanvasLayer

const PlayerHealthBarScript := preload("res://scripts/PlayerHealthBar.gd")

var health_bar: Control
var score_label: Label
var boss_bar: ProgressBar
var boss_title: Label
var level_label: Label

# Game Over overlay nodes
var game_over_overlay: Control
var game_over_label: Label
var play_again_button: Button
var go_subtitle: Label

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
	_update_level_label()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ── Health bar ──────────────────────────────────────────────────
	health_bar = PlayerHealthBarScript.new()
	health_bar.position = Vector2(36, 22)
	health_bar.size = Vector2(560, 58)
	root.add_child(health_bar)

	# ── Score ───────────────────────────────────────────────────────
	score_label = Label.new()
	score_label.position = Vector2(1530, 24)
	score_label.size = Vector2(350, 50)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color(0.9, 2.4, 3.5, 1.0))
	score_label.add_theme_constant_override("outline_size", 4)
	score_label.add_theme_color_override("font_outline_color", Color(0.1, 0.25, 0.45, 0.9))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(score_label)

	# ── Level indicator (top center) ─────────────────────────────────
	level_label = Label.new()
	level_label.position = Vector2(1530, 76)
	level_label.size = Vector2(350, 38)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_font_size_override("font_size", 24)
	level_label.add_theme_color_override("font_color", Color(0.6, 2.2, 3.8, 1.0))
	level_label.add_theme_constant_override("outline_size", 3)
	level_label.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.3, 0.85))
	root.add_child(level_label)

	boss_title = Label.new()
	boss_title.visible = false
	boss_title.text = "BOSS ARMOR"
	boss_title.position = Vector2(650, 18)
	boss_title.size = Vector2(620, 22)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_title.add_theme_font_size_override("font_size", 18)
	boss_title.add_theme_color_override("font_color", Color(3.2, 1.3, 0.55, 1.0))
	boss_title.add_theme_constant_override("outline_size", 3)
	boss_title.add_theme_color_override("font_outline_color", Color(0.22, 0.02, 0.02, 0.9))
	root.add_child(boss_title)

	# ── Boss bar ─────────────────────────────────────────────────────
	boss_bar = ProgressBar.new()
	boss_bar.visible = false
	boss_bar.position = Vector2(650, 42)
	boss_bar.size = Vector2(620, 24)
	boss_bar.max_value = 100
	boss_bar.value = 100
	boss_bar.show_percentage = false

	var boss_bg := StyleBoxFlat.new()
	boss_bg.bg_color = Color(0.09, 0.02, 0.035, 0.82)
	boss_bg.border_width_top = 2
	boss_bg.border_width_bottom = 2
	boss_bg.border_width_left = 2
	boss_bg.border_width_right = 2
	boss_bg.border_color = Color(2.4, 0.55, 0.25, 0.9)
	boss_bg.corner_radius_top_left = 4
	boss_bg.corner_radius_top_right = 4
	boss_bg.corner_radius_bottom_left = 4
	boss_bg.corner_radius_bottom_right = 4
	boss_bg.shadow_color = Color(1.0, 0.12, 0.04, 0.45)
	boss_bg.shadow_size = 12
	boss_bar.add_theme_stylebox_override("background", boss_bg)

	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color(4.0, 0.35, 0.18, 0.95)
	boss_fill.border_width_top = 1
	boss_fill.border_width_bottom = 1
	boss_fill.border_width_left = 1
	boss_fill.border_width_right = 1
	boss_fill.border_color = Color(5.0, 2.0, 0.55, 0.95)
	boss_fill.corner_radius_top_left = 3
	boss_fill.corner_radius_top_right = 3
	boss_fill.corner_radius_bottom_left = 3
	boss_fill.corner_radius_bottom_right = 3
	boss_bar.add_theme_stylebox_override("fill", boss_fill)
	root.add_child(boss_bar)

	# ── Game Over overlay ─────────────────────────────────────────────
	game_over_overlay = Control.new()
	game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_overlay.visible = false
	root.add_child(game_over_overlay)

	# Dark vignette background panel
	var bg_panel := ColorRect.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_panel.color = Color(0.0, 0.02, 0.07, 0.82)
	game_over_overlay.add_child(bg_panel)

	# Decorative scanline overlay (thin horizontal lines)
	var scanline := ColorRect.new()
	scanline.set_anchors_preset(Control.PRESET_FULL_RECT)
	scanline.color = Color(0.0, 0.35, 0.8, 0.04)
	game_over_overlay.add_child(scanline)

	# GAME OVER label
	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.position = Vector2(0, 280)
	game_over_label.size = Vector2(1920, 200)
	game_over_label.add_theme_font_size_override("font_size", 128)
	game_over_label.add_theme_color_override("font_color", Color(3.2, 0.4, 0.35, 1.0))
	game_over_label.add_theme_constant_override("outline_size", 8)
	game_over_label.add_theme_color_override("font_outline_color", Color(0.6, 0.04, 0.04, 0.85))
	game_over_overlay.add_child(game_over_label)

	# Subtitle
	go_subtitle = Label.new()
	go_subtitle.text = "YOUR SHIP HAS BEEN DESTROYED"
	go_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_subtitle.position = Vector2(0, 440)
	go_subtitle.size = Vector2(1920, 60)
	go_subtitle.add_theme_font_size_override("font_size", 36)
	go_subtitle.add_theme_color_override("font_color", Color(0.65, 1.6, 2.8, 0.9))
	go_subtitle.add_theme_constant_override("outline_size", 4)
	go_subtitle.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.25, 0.8))
	game_over_overlay.add_child(go_subtitle)

	# Play Again button
	play_again_button = Button.new()
	play_again_button.text = "▶  PLAY AGAIN"
	play_again_button.position = Vector2(760, 560)
	play_again_button.size = Vector2(400, 76)
	play_again_button.add_theme_font_size_override("font_size", 34)

	# Style: normal
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.04, 0.18, 0.42, 0.92)
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_color = Color(0.3, 0.8, 2.0, 0.85)
	btn_normal.corner_radius_top_left = 8
	btn_normal.corner_radius_top_right = 8
	btn_normal.corner_radius_bottom_left = 8
	btn_normal.corner_radius_bottom_right = 8
	btn_normal.shadow_color = Color(0.15, 0.55, 1.5, 0.55)
	btn_normal.shadow_size = 12
	play_again_button.add_theme_stylebox_override("normal", btn_normal)

	# Style: hover
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.08, 0.32, 0.78, 0.98)
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_color = Color(0.5, 1.2, 3.0, 1.0)
	btn_hover.corner_radius_top_left = 8
	btn_hover.corner_radius_top_right = 8
	btn_hover.corner_radius_bottom_left = 8
	btn_hover.corner_radius_bottom_right = 8
	btn_hover.shadow_color = Color(0.2, 0.7, 2.0, 0.7)
	btn_hover.shadow_size = 18
	play_again_button.add_theme_stylebox_override("hover", btn_hover)

	# Style: pressed
	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.12, 0.45, 1.0, 1.0)
	btn_pressed.border_color = Color(0.8, 1.8, 4.0, 1.0)
	btn_pressed.border_width_top = 3
	btn_pressed.border_width_bottom = 3
	btn_pressed.border_width_left = 3
	btn_pressed.border_width_right = 3
	btn_pressed.corner_radius_top_left = 8
	btn_pressed.corner_radius_top_right = 8
	btn_pressed.corner_radius_bottom_left = 8
	btn_pressed.corner_radius_bottom_right = 8
	play_again_button.add_theme_stylebox_override("pressed", btn_pressed)

	play_again_button.add_theme_color_override("font_color", Color(0.85, 2.0, 4.0, 1.0))
	play_again_button.add_theme_color_override("font_hover_color", Color(1.0, 2.5, 4.5, 1.0))
	play_again_button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))

	play_again_button.pressed.connect(_on_play_again_pressed)
	game_over_overlay.add_child(play_again_button)

# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_score_changed(score: int) -> void:
	score_label.text = "SCORE %07d" % score

func _on_player_health_changed(health: int, max_health: int) -> void:
	health_bar.set_health(health, max_health)

func _on_boss_started(max_health: int) -> void:
	boss_title.visible = true
	boss_bar.visible = true
	boss_bar.max_value = max_health
	boss_bar.value = max_health

func _on_boss_health_changed(health: int, max_health: int) -> void:
	boss_bar.max_value = max_health
	boss_bar.value = health
	if health <= 0:
		boss_title.visible = false
		boss_bar.visible = false

func _update_level_label() -> void:
	if level_label:
		level_label.text = "LEVEL %d" % GameState.current_level

func _on_level_advanced(_lvl: int) -> void:
	_update_level_label()

func _on_game_over() -> void:
	# Show overlay with animated entrance
	game_over_overlay.visible = true
	game_over_label.modulate = Color(1, 1, 1, 0)
	go_subtitle.modulate = Color(1, 1, 1, 0)
	play_again_button.modulate = Color(1, 1, 1, 0)
	play_again_button.scale = Vector2(0.85, 0.85)
	play_again_button.pivot_offset = Vector2(200, 38)

	var tw := create_tween()
	tw.set_parallel(false)
	# Fade in GAME OVER text with a slight scale pop
	game_over_label.scale = Vector2(1.18, 1.18)
	game_over_label.pivot_offset = Vector2(960, 100)
	tw.tween_property(game_over_label, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(game_over_label, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(go_subtitle, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.18)
	tw.tween_property(play_again_button, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(play_again_button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_play_again_pressed() -> void:
	get_tree().reload_current_scene()

func show_level_transition(from_level: int, to_level: int) -> void:
	# Big dramatic "LEVEL N CLEARED" then "LEVEL M" announcement
	var tl := Label.new()
	tl.name = "LevelTransitionLabel"
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.position = Vector2(0, 380)
	tl.size = Vector2(1920, 220)
	tl.add_theme_font_size_override("font_size", 68)
	tl.add_theme_color_override("font_color", Color(1.1, 2.8, 4.5, 1.0))
	tl.add_theme_constant_override("outline_size", 7)
	tl.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.28, 0.92))
	add_child(tl)

	tl.modulate = Color(1, 1, 1, 0.0)
	tl.text = "LEVEL %d  CLEARED" % from_level
	tl.scale = Vector2(0.55, 0.55)
	tl.pivot_offset = Vector2(960, 80)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(tl, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(tl, "scale", Vector2(1.08, 1.08), 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.15)
	tw.tween_property(tl, "modulate:a", 0.0, 0.32)
	tw.tween_property(tl, "scale", Vector2(1.45, 1.45), 0.32)
	await tw.finished

	if is_instance_valid(tl):
		tl.text = "LEVEL %d" % to_level
		tl.modulate = Color(0.8, 3.5, 1.8, 0.0)
		tl.scale = Vector2(0.45, 0.45)
		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(tl, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUART)
		tw2.tween_property(tl, "scale", Vector2(1.0, 1.0), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw2.finished
		await get_tree().create_timer(0.85).timeout
		if is_instance_valid(tl):
			var tw3 := create_tween()
			tw3.tween_property(tl, "modulate:a", 0.0, 0.4)
			await tw3.finished
			if is_instance_valid(tl):
				tl.queue_free()

	_update_level_label()
