extends CanvasLayer
## ESC pause menu with sound volume customization.
## Created from Main; works while tree is paused (PROCESS_MODE_ALWAYS).

const CYAN := Color("86d8de")
const INK := Color("101c25")
const WHITE := Color("e8efed")
const MUTED := Color("95a9b1")
const AMBER := Color("efb26e")

const SETTINGS_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]

static func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

var root: Control
var dialog_panel: Panel
var dlg := 1.0
var force_mobile := false  # headless-test hook: build mobile-sized dialog
var volume_slider: HSlider
var volume_value_label: Label
var mute_button: Button
var resume_button: Button
var exit_button: Button
var resolution_buttons: Array[Button] = []
var is_open := false
var _updating_slider := false

static func resolution_supported() -> bool:
	# Window sizing only makes sense on desktop. On Web the canvas is owned by
	# the browser, on mobile the window is the fullscreen device screen.
	if OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios"):
		return false
	return true

static func resolution_to_string(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]

static func parse_resolution(text: String) -> Vector2i:
	var parts := text.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

static func saved_resolution() -> Vector2i:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return Vector2i(-1, -1)
	return parse_resolution(str(cfg.get_value("display", "resolution", "")))

static func apply_resolution(size: Vector2i, save := true) -> void:
	if not resolution_supported():
		return
	if size.x <= 0 or size.y <= 0:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var screen_size := DisplayServer.screen_get_size()
	DisplayServer.window_set_position((screen_size - size) / 2)
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)  # keep other sections (e.g. audio) intact
		cfg.set_value("display", "resolution", resolution_to_string(size))
		cfg.save(SETTINGS_PATH)

static func apply_saved_resolution() -> void:
	# No saved choice: respect the project/window settings, change nothing.
	var size := saved_resolution()
	if size.x > 0 and size.y > 0:
		apply_resolution(size, false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	if force_mobile or is_mobile():
		dlg = 1.25
	_build_ui()
	root.resized.connect(_center_dialog)
	_center_dialog()
	set_open(false, false)
	_connect_audio_signals()

func _unhandled_input(event: InputEvent) -> void:
	var is_esc := false
	if event.is_action_pressed("ui_cancel"):
		is_esc = true
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			is_esc = true
	if not is_esc:
		return
	# Don't hijack ESC on game-over screen; let player use FLY AGAIN button.
	if GameState != null and not GameState.game_active:
		return
	if event is InputEventKey or event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()
	toggle()

func toggle() -> void:
	set_open(not is_open)

func set_open(value: bool, pause_tree := true) -> void:
	is_open = value
	_reset_ship_touch()
	if root:
		root.visible = is_open
	if pause_tree:
		get_tree().paused = is_open
	if is_open:
		_refresh_from_audio()
		_refresh_resolution_buttons()
		if resume_button:
			resume_button.grab_focus()

func _reset_ship_touch() -> void:
	# Releases missed while paused never arrive; re-anchor so firing can't stick.
	var ship := get_parent().get_node_or_null("PlayerShip")
	if ship != null and ship.has_method("reset_touch"):
		ship.reset_touch()

func _connect_audio_signals() -> void:
	if VFX == null or VFX.get("audio") == null:
		return
	var audio: Node = VFX.get("audio")
	if audio.has_signal("volume_changed") and not audio.volume_changed.is_connected(_on_audio_volume_changed):
		audio.volume_changed.connect(_on_audio_volume_changed)
	if audio.has_signal("muted_changed") and not audio.muted_changed.is_connected(_on_audio_muted_changed):
		audio.muted_changed.connect(_on_audio_muted_changed)

func _refresh_from_audio() -> void:
	if VFX == null or VFX.get("audio") == null:
		return
	var audio: Node = VFX.get("audio")
	_updating_slider = true
	volume_slider.value = float(audio.get("volume")) * 100.0
	_updating_slider = false
	_update_volume_label(float(audio.get("volume")))
	_update_mute_label(bool(audio.get("muted")))

# ── UI builders (match HUD.gd style) ─────────────────────────────────

func _style(color: Color, border: Color = Color("344953")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(5)
	return style

func _center_dialog() -> void:
	# Mobile: keep the enlarged dialog centered on any viewport. Desktop keeps
	# its classic fixed spot.
	if dialog_panel == null or not (force_mobile or is_mobile()):
		return
	var view := Vector2(1920, 1080)
	var vp := get_viewport()
	if vp != null:
		var visible := vp.get_visible_rect().size
		if visible.x >= 1.0 and visible.y >= 1.0:
			view = visible
	dialog_panel.position = (view - dialog_panel.size) * 0.5

func _panel(parent: Node, at: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = at * dlg
	panel.size = dimensions * dlg
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.065, 0.085, 0.96)))
	parent.add_child(panel)
	return panel

func _label(parent: Node, at: Vector2, dimensions: Vector2, caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at * dlg
	label.size = dimensions * dlg
	label.text = caption
	label.add_theme_font_size_override("font_size", int(font_size * dlg))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, at: Vector2, dimensions: Vector2, caption: String) -> Button:
	var button := Button.new()
	button.position = at * dlg
	button.size = dimensions * dlg
	button.text = caption
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", int(20 * dlg))
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
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.72)
	root.add_child(shade)

	var mobile := force_mobile or is_mobile()
	var panel := _panel(root, Vector2(630, 240), Vector2(660, 480 if mobile else 560))
	dialog_panel = panel
	var eyebrow := _label(panel, Vector2(30, 28), Vector2(600, 30),
		"RAPTOR  /  OPTIONS" if mobile else "RAPTOR  /  OPTIONS   —   ESC TO RESUME", 18, CYAN)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(panel, Vector2(30, 66), Vector2(600, 70), "PAUSED", 54, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(panel, Vector2(40, 168), Vector2(300, 28), "SOUND VOLUME", 18, MUTED)
	volume_value_label = _label(panel, Vector2(500, 168), Vector2(120, 28), "80%", 18, WHITE)
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	volume_slider = HSlider.new()
	volume_slider.position = Vector2(40, 206) * dlg
	volume_slider.size = Vector2(580, 56 if mobile else 32) * dlg
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = 80.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(volume_slider)
	volume_slider.value_changed.connect(_on_slider_changed)
	volume_slider.drag_ended.connect(_on_slider_drag_ended)



	if not mobile:
		if resolution_supported():
			_label(panel, Vector2(40, 280), Vector2(580, 28), "RESOLUTION", 18, MUTED)
			for i in range(RESOLUTIONS.size()):
				var choice: Vector2i = RESOLUTIONS[i]
				var res_button := _button(panel, Vector2(40 + i * 200, 312), Vector2(180, 52),
					resolution_to_string(choice))
				var index := i
				res_button.pressed.connect(func(): _on_resolution_pressed(index))
				resolution_buttons.append(res_button)
			_refresh_resolution_buttons()
		else:
			var fixed_note := _label(panel, Vector2(40, 280), Vector2(580, 28), "RESOLUTION: FIXED BY DEVICE / BROWSER", 18, MUTED)
			fixed_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


	mute_button = _button(panel, Vector2(40, 308 if mobile else 380), Vector2(280, 56), "SOUND  ON")
	mute_button.pressed.connect(_on_mute_pressed)
	var restart_button := _button(panel, Vector2(340, 308 if mobile else 380), Vector2(280, 56), "RESTART")
	restart_button.pressed.connect(_on_restart_pressed)

	resume_button = _button(panel, Vector2(40, 380 if mobile else 458), Vector2(280, 62),
		"RESUME" if mobile else "RESUME  (ESC)")
	resume_button.pressed.connect(func(): set_open(false))
	exit_button = _button(panel, Vector2(340, 380 if mobile else 458), Vector2(280, 62), "EXIT")
	exit_button.pressed.connect(_on_exit_pressed)
	if not mobile:
		var capture_hint := _label(panel, Vector2(40, 524), Vector2(580, 26), "S SCREENSHOT  ·  R RECORD 30FPS+AUDIO  (DESKTOP)", 15, MUTED)
		capture_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ── Handlers ─────────────────────────────────────────────────────────

func _on_slider_changed(value: float) -> void:
	if _updating_slider:
		return
	if VFX == null or VFX.get("audio") == null:
		return
	VFX.audio.set_volume(value / 100.0)
	_update_volume_label(value / 100.0)

func _on_slider_drag_ended(value_changed: bool) -> void:
	if value_changed and VFX != null and VFX.get("audio") != null:
		VFX.audio.play_preview()

func _on_mute_pressed() -> void:
	if VFX == null or VFX.get("audio") == null:
		return
	VFX.audio.toggle_muted()
	_refresh_from_audio()

func _on_resolution_pressed(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	apply_resolution(RESOLUTIONS[index])
	_refresh_resolution_buttons()

func _refresh_resolution_buttons() -> void:
	var current := DisplayServer.window_get_size()
	for i in range(resolution_buttons.size()):
		var choice: Vector2i = RESOLUTIONS[i]
		resolution_buttons[i].text = ("✓ " if choice == current else "") + resolution_to_string(choice)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	is_open = false
	get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	get_tree().paused = false
	is_open = false
	get_tree().quit()

func _on_audio_volume_changed(volume: float) -> void:
	_update_volume_label(volume)
	if not is_equal_approx(volume_slider.value, volume * 100.0):
		_updating_slider = true
		volume_slider.value = volume * 100.0
		_updating_slider = false

func _on_audio_muted_changed(is_muted: bool) -> void:
	_update_mute_label(is_muted)

func _update_volume_label(volume: float) -> void:
	if volume_value_label:
		volume_value_label.text = "%d%%" % int(round(volume * 100.0))

func _update_mute_label(is_muted: bool) -> void:
	if mute_button:
		mute_button.text = "SOUND  OFF" if is_muted else "SOUND  ON"
