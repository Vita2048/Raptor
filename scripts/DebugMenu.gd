extends CanvasLayer

const Options := preload("res://scripts/DebugOptions.gd")
var panel: Control
var is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.065, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 22)
	center.add_child(rows)
	var title := Label.new()
	title.text = "FLIGHT TEST / SELECT DESTINATION"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	rows.add_child(grid)
	for level in range(1, 4):
		for boss in [false, true]:
			var button := Button.new()
			button.text = ("BOSS SHIP %d" if boss else "LEVEL %d") % level
			button.custom_minimum_size = Vector2(320, 84)
			button.add_theme_font_size_override("font_size", 26)
			button.pressed.connect(select_destination.bind(level, boss))
			grid.add_child(button)
	var resume := Button.new()
	resume.text = "RESUME / F2"
	resume.custom_minimum_size.y = 55
	resume.pressed.connect(func(): set_open(false))
	rows.add_child(resume)
	set_open(Options.selected_level == 0)

func set_open(value: bool) -> void:
	is_open = value
	panel.visible = value
	get_tree().paused = value
	var pause_menu = get_parent().get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.set_open(false, false)
	if value:
		panel.find_next_valid_focus().grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2 or (is_open and event.keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			set_open(not is_open)

func select_destination(level: int, boss: bool) -> void:
	Options.selected_level = clampi(level, 1, 3)
	Options.selected_boss = boss
	get_tree().paused = false
	get_tree().reload_current_scene()
