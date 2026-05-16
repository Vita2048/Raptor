extends CanvasLayer

var health_label: Label
var score_label: Label
var boss_bar: ProgressBar
var game_over_label: Label

func _ready() -> void:
	_build_ui()
	GameState.score_changed.connect(_on_score_changed)
	GameState.player_health_changed.connect(_on_player_health_changed)
	GameState.boss_started.connect(_on_boss_started)
	GameState.boss_health_changed.connect(_on_boss_health_changed)
	GameState.game_over.connect(_on_game_over)
	_on_score_changed(GameState.score)
	_on_player_health_changed(GameState.player_health, GameState.player_max_health)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := HBoxContainer.new()
	panel.position = Vector2(34, 28)
	panel.add_theme_constant_override("separation", 34)
	root.add_child(panel)

	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 34)
	panel.add_child(health_label)

	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 34)
	panel.add_child(score_label)

	boss_bar = ProgressBar.new()
	boss_bar.visible = false
	boss_bar.position = Vector2(560, 28)
	boss_bar.size = Vector2(820, 32)
	boss_bar.max_value = 100
	boss_bar.value = 100
	root.add_child(boss_bar)

	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.visible = false
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 96)
	game_over_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(game_over_label)

func _on_score_changed(score: int) -> void:
	score_label.text = "SCORE %07d" % score

func _on_player_health_changed(health: int, max_health: int) -> void:
	health_label.text = "ARMOR %03d" % health

func _on_boss_started(max_health: int) -> void:
	boss_bar.visible = true
	boss_bar.max_value = max_health
	boss_bar.value = max_health

func _on_boss_health_changed(health: int, max_health: int) -> void:
	boss_bar.max_value = max_health
	boss_bar.value = health
	if health <= 0:
		boss_bar.visible = false

func _on_game_over() -> void:
	game_over_label.visible = true
