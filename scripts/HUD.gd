extends CanvasLayer

const CYAN := Color("86d8de")
const INK := Color("101c25")
const WHITE := Color("e8efed")
const MUTED := Color("95a9b1")
const AMBER := Color("efb26e")
const PlayerHealthBarScript := preload("res://scripts/PlayerHealthBar.gd")
# Single shared corner margin for the armor / score / sound HUDs.
const CORNER_MARGIN := Vector2(16, 16)

static func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

var ui_scale := 1.0
var corner_margin := CORNER_MARGIN
var force_mobile := false  # headless-test hook: build mobile-sized UI on desktop
# Design playfield the camera projects; margins are measured from this
# centered rectangle, not from raw viewport edges (which grow with expand).
const DESIGN_SIZE := Vector2(1920, 1080)

var health_bar: Control
var armor_panel: Panel
var score_panel: Panel
var score_label: Label
var level_label: Label
var boss_bar: ProgressBar
var boss_panel: Panel
var boss_title: Label
var victory_overlay: Control
var victory_stats: Label
var game_over_overlay: Control
var result_panel: Panel
var result_label: Label
var victory_panel: Panel
var play_again_button: Button
var sound_button: Button
var menu_button: Button
var root: Control
var approach_panel: Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if force_mobile or is_mobile():
		ui_scale = 1.5
		corner_margin = CORNER_MARGIN * ui_scale
	_build_ui()
	root.resized.connect(_refresh_layout)
	_refresh_layout()
	GameState.score_changed.connect(_on_score_changed)
	GameState.player_health_changed.connect(_on_player_health_changed)
	GameState.boss_started.connect(_on_boss_started)
	GameState.boss_health_changed.connect(_on_boss_health_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.campaign_completed.connect(_on_campaign_completed)
	GameState.level_advanced.connect(_on_level_advanced)
	if VFX != null and VFX.get("audio") != null:
		var audio: Node = VFX.get("audio")
		if audio.has_signal("muted_changed") and not audio.muted_changed.is_connected(_on_audio_muted_changed):
			audio.muted_changed.connect(_on_audio_muted_changed)
		if audio.has_signal("volume_changed") and not audio.volume_changed.is_connected(_on_audio_volume_changed):
			audio.volume_changed.connect(_on_audio_volume_changed)
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
	panel.position = at * ui_scale
	panel.size = dimensions * ui_scale
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.065, 0.085, 0.90)))
	parent.add_child(panel)
	return panel

# Corner anchors keep the HUDs glued to the viewport corners (with the shared
# CORNER_MARGIN) at any window size/aspect instead of drifting on wide screens.
func _refresh_layout() -> void:
	var view := root.size
	if view.x < 1.0 or view.y < 1.0:
		view = DESIGN_SIZE
	_layout_corners(view)

# Positions the persistent HUDs inside the projected game rectangle: the design
# playfield centered in the viewport and clamped to it. With expand aspect the
# raw viewport can be larger than the playfield, so margins are measured from
# this rectangle rather than from viewport edges.
func _layout_corners(view: Vector2) -> void:
	var rect_size := Vector2(minf(DESIGN_SIZE.x, view.x), minf(DESIGN_SIZE.y, view.y))
	var rect_pos := (view - rect_size) * 0.5
	armor_panel.position = rect_pos + corner_margin
	score_panel.position = Vector2(
		rect_pos.x + rect_size.x - corner_margin.x - score_panel.size.x,
		rect_pos.y + corner_margin.y)
	sound_button.position = Vector2(
		rect_pos.x + rect_size.x - corner_margin.x - sound_button.size.x,
		rect_pos.y + rect_size.y - corner_margin.y - sound_button.size.y)
	boss_panel.position = Vector2(
		rect_pos.x + (rect_size.x - boss_panel.size.x) * 0.5,
		rect_pos.y + corner_margin.y)
	if is_instance_valid(menu_button):
		menu_button.position = Vector2(
			rect_pos.x + corner_margin.x,
			rect_pos.y + rect_size.y - corner_margin.y - menu_button.size.y)
	# Transient dialogs keep centered in the real viewport on mobile.
	if is_instance_valid(result_panel):
		_center_dialog_in_view(result_panel, view)
	if is_instance_valid(victory_panel):
		_center_dialog_in_view(victory_panel, view)
	if is_instance_valid(approach_panel):
		_center_dialog_in_view(approach_panel, view)

# Mobile viewports differ from the design canvas (e.g. tall portrait screens),
# so centered popups are measured from the real viewport, not fixed coords.
func _center_dialog_in_view(panel: Control, view := Vector2(-1, -1)) -> void:
	if not (force_mobile or is_mobile()):
		return
	if view.x < 1.0 or view.y < 1.0:
		view = DESIGN_SIZE
		var vp := get_viewport()
		if vp != null:
			var visible := vp.get_visible_rect().size
			if visible.x >= 1.0 and visible.y >= 1.0:
				view = visible
	panel.position = (view - panel.size) * 0.5

func _label(parent: Node, at: Vector2, dimensions: Vector2, caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at * ui_scale
	label.size = dimensions * ui_scale
	label.text = caption
	label.add_theme_font_size_override("font_size", int(font_size * ui_scale))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, at: Vector2, dimensions: Vector2, caption: String) -> Button:
	var button := Button.new()
	button.position = at * ui_scale
	button.size = dimensions * ui_scale
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", int(20 * ui_scale))
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

	armor_panel = _panel(root, CORNER_MARGIN, Vector2(360, 94))
	armor_panel.name = "ArmorPanel"
	health_bar = PlayerHealthBarScript.new()
	health_bar.ui = ui_scale
	health_bar.position = Vector2(18, 12)
	health_bar.size = Vector2(324, 70)
	armor_panel.add_child(health_bar)

	score_panel = _panel(root, Vector2(1570, 28), Vector2(318, 94))
	score_panel.name = "ScorePanel"
	_label(score_panel, Vector2(18, 10), Vector2(100, 22), "SCORE", 16, MUTED)
	level_label = _label(score_panel, Vector2(140, 10), Vector2(160, 22), "", 16, CYAN)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label = _label(score_panel, Vector2(18, 34), Vector2(282, 46), "", 32, WHITE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Narrower on mobile so the centered boss bar clears the enlarged corner HUDs.
	var boss_w := 420.0 if (force_mobile or is_mobile()) else 600.0
	boss_panel = _panel(root, Vector2(660, 28), Vector2(boss_w, 72))
	boss_title = _label(boss_panel, Vector2(18, 8), Vector2(boss_w - 36, 28), "HEAVY CONTACT  /  BOSS ARMOR", 17, AMBER)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(18, 44) * ui_scale
	boss_bar.size = Vector2(boss_w - 36, 8) * ui_scale
	boss_bar.show_percentage = false
	boss_bar.add_theme_font_size_override("font_size", 1)
	boss_bar.add_theme_stylebox_override("background", _style(Color("27313a"), Color("27313a")))
	boss_bar.add_theme_stylebox_override("fill", _style(AMBER, AMBER))
	boss_panel.add_child(boss_bar)
	boss_bar.size = Vector2(boss_w - 36, 8) * ui_scale
	boss_panel.hide()

	if force_mobile or is_mobile():
		# Same builder (and look) as the sound button and other HUDs.
		menu_button = _button(root, Vector2.ZERO, Vector2(120, 48), "MENU")
		menu_button.name = "MenuButton"
		menu_button.focus_mode = Control.FOCUS_NONE
		menu_button.pressed.connect(_on_menu_button)

	sound_button = _button(root, Vector2(1738, 1008), Vector2(150, 42), "")
	sound_button.focus_mode = Control.FOCUS_NONE
	_update_sound_label()
	sound_button.pressed.connect(func():
		VFX.audio.set_muted(not VFX.audio.muted)
	)

	game_over_overlay = Control.new()
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(game_over_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.8)
	game_over_overlay.add_child(shade)
	result_panel = _panel(game_over_overlay, Vector2(630, 324), Vector2(660, 390))
	_center_dialog_in_view(result_panel)
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
	if VFX == null or VFX.get("audio") == null or sound_button == null:
		return
	var audio: Node = VFX.get("audio")
	var is_muted := bool(audio.get("muted"))
	var vol := float(audio.get("volume"))
	if is_muted or vol <= 0.001:
		sound_button.text = "SOUND  OFF"
	else:
		sound_button.text = "SOUND  %d%%" % int(round(vol * 100.0))

func _on_audio_muted_changed(_is_muted: bool) -> void:
	_update_sound_label()

func _on_audio_volume_changed(_volume: float) -> void:
	_update_sound_label()

func _on_score_changed(score: int) -> void:
	score_label.text = "%07d" % score

func _on_player_health_changed(health: int, max_health: int) -> void:
	health_bar.set_health(health, max_health)

func _on_boss_started(max_health: int) -> void:
	boss_title.text = "COMMAND SHIP  /  FINAL ENGAGEMENT" if GameState.current_level == 3 else "HEAVY CONTACT  /  BOSS ARMOR"
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
	if is_instance_valid(approach_panel):
		approach_panel.queue_free()
	boss_panel.hide()
	_hide_menu_button()
	result_label.text = "SECTOR %02d     /     SCORE %07d" % [GameState.current_level, GameState.score]
	if GameState.checkpoint_level > 1:
		play_again_button.text = "RETRY SECTOR %02d" % GameState.checkpoint_level
	else:
		play_again_button.text = "FLY AGAIN"
	game_over_overlay.show()
	game_over_overlay.modulate.a = 0.0
	create_tween().tween_property(game_over_overlay, "modulate:a", 1.0, 0.4)
	play_again_button.grab_focus()

func _on_menu_button() -> void:
	# Mobile menu entry point (desktop uses ESC); PauseMenu is a Main sibling.
	var menu := get_parent().get_node_or_null("PauseMenu")
	if menu != null and menu.has_method("set_open") and GameState.game_active:
		menu.set_open(true)

func _hide_menu_button() -> void:
	if is_instance_valid(menu_button):
		menu_button.hide()

func show_level_transition(from_level: int, to_level: int) -> Panel:
	var panel := _panel(root, Vector2(660, 200), Vector2(600, 110))
	_center_dialog_in_view(panel)
	var label := _label(panel, Vector2(24, 18), Vector2(552, 74), "SECTOR %02d CLEARED\n%s" % [from_level, AssetDB.SECTOR_NAMES[clampi(to_level - 1, 0, 2)]], 25, WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)
	return panel

func show_boss_warning() -> void:
	if is_instance_valid(approach_panel):
		approach_panel.queue_free()
	approach_panel = _panel(root, Vector2(660, 160), Vector2(600, 104))
	_center_dialog_in_view(approach_panel)
	var title := _label(approach_panel, Vector2(24, 16), Vector2(552, 32), "FINAL COMMAND SHIP INBOUND" if GameState.current_level == 3 else "HEAVY CONTACT INBOUND", 25, AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detail := _label(approach_panel, Vector2(24, 57), Vector2(552, 25), "CLEAR THE APPROACH  /  PREPARE TO ENGAGE", 16, MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	approach_panel.modulate.a = 0.0
	var tween := approach_panel.create_tween()
	tween.tween_property(approach_panel, "modulate:a", 1.0, 0.22)
	tween.tween_interval(2.2)
	tween.tween_property(approach_panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(approach_panel.queue_free)

func _on_campaign_completed() -> void:
	boss_panel.hide()
	_hide_menu_button()
	if is_instance_valid(approach_panel):
		approach_panel.queue_free()
	# Let the final destruction play before revealing the debrief.
	await get_tree().create_timer(1.4).timeout
	victory_overlay = Control.new()
	victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(victory_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.84)
	victory_overlay.add_child(shade)
	victory_panel = _panel(victory_overlay, Vector2(530, 170), Vector2(860, 740))
	_center_dialog_in_view(victory_panel)
	var panel := victory_panel
	var eyebrow := _label(panel, Vector2(40, 30), Vector2(780, 30), "RAPTOR  /  ALL SECTORS SECURED", 18, CYAN)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(panel, Vector2(40, 78), Vector2(780, 75), "MISSION ACCOMPLISHED", 48, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var congratulations := _label(panel, Vector2(40, 164), Vector2(780, 58), "Congratulations, pilot.\nThe command ship is down. Your mission is complete.", 23, CYAN)
	congratulations.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var labels := "FINAL SCORE\nFLIGHT TIME\nENEMY SHIPS / BOSSES\nSTRUCTURES / VEHICLES\nSHOTS FIRED\nARMOR REMAINING"
	var names := _label(panel, Vector2(64, 272), Vector2(470, 300), labels, 23, MUTED)
	names.add_theme_constant_override("line_spacing", 15)
	var seconds := int(GameState.elapsed_seconds)
	var values := "%07d\n%02d:%02d\n%d / %d\n%d / %d\n%d\n%d / %d" % [GameState.score, seconds / 60, seconds % 60, GameState.ships_destroyed, GameState.bosses_destroyed, GameState.structures_destroyed, GameState.vehicles_destroyed, GameState.shots_fired, GameState.player_health, GameState.player_max_health]
	victory_stats = _label(panel, Vector2(540, 272), Vector2(256, 300), values, 23, WHITE)
	victory_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	victory_stats.add_theme_constant_override("line_spacing", 15)
	var replay := _button(panel, Vector2(280, 634), Vector2(300, 62), "FLY AGAIN")
	replay.pressed.connect(func(): get_tree().reload_current_scene())
	victory_overlay.modulate.a = 0.0
	create_tween().tween_property(victory_overlay, "modulate:a", 1.0, 0.55)
	replay.grab_focus()
