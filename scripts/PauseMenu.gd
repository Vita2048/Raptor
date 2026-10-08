extends CanvasLayer
## ESC pause menu with sound volume customization.
## Created from Main; works while tree is paused (PROCESS_MODE_ALWAYS).

const CYAN := Color("86d8de")
const INK := Color("101c25")
const WHITE := Color("e8efed")
const MUTED := Color("95a9b1")
const AMBER := Color("efb26e")

var root: Control
var volume_slider: HSlider
var volume_value_label: Label
var mute_button: Button
var resume_button: Button
var is_open := false
var _updating_slider := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build_ui()
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
	if root:
		root.visible = is_open
	if pause_tree:
		get_tree().paused = is_open
	if is_open:
		_refresh_from_audio()
		if resume_button:
			resume_button.grab_focus()

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

func _panel(parent: Node, at: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.065, 0.085, 0.96)))
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
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.72)
	root.add_child(shade)

	var panel := _panel(root, Vector2(630, 290), Vector2(660, 470))
	var eyebrow := _label(panel, Vector2(30, 28), Vector2(600, 30), "RAPTOR  /  OPTIONS   —   ESC TO RESUME", 18, CYAN)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(panel, Vector2(30, 66), Vector2(600, 70), "PAUSED", 54, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(panel, Vector2(40, 168), Vector2(300, 28), "SOUND VOLUME", 18, MUTED)
	volume_value_label = _label(panel, Vector2(500, 168), Vector2(120, 28), "80%", 18, WHITE)
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	volume_slider = HSlider.new()
	volume_slider.position = Vector2(40, 206)
	volume_slider.size = Vector2(580, 32)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = 80.0
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(volume_slider)
	volume_slider.value_changed.connect(_on_slider_changed)
	volume_slider.drag_ended.connect(_on_slider_drag_ended)

	var hint := _label(panel, Vector2(40, 244), Vector2(580, 24), "Drag slider to adjust volume. Setting is saved.", 15, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	mute_button = _button(panel, Vector2(40, 288), Vector2(280, 56), "SOUND  ON")
	mute_button.pressed.connect(_on_mute_pressed)
	var restart_button := _button(panel, Vector2(340, 288), Vector2(280, 56), "RESTART")
	restart_button.pressed.connect(_on_restart_pressed)

	resume_button = _button(panel, Vector2(40, 364), Vector2(280, 62), "RESUME  (ESC)")
	resume_button.pressed.connect(func(): set_open(false))
	var exit_button := _button(panel, Vector2(340, 364), Vector2(280, 62), "EXIT")
	exit_button.pressed.connect(_on_exit_pressed)

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
