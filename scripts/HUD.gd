extends CanvasLayer

const PlayerHealthBarScript := preload("res://scripts/PlayerHealthBar.gd")

var health_bar: Control
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

	health_bar = PlayerHealthBarScript.new()
	health_bar.position = Vector2(36, 22)
	health_bar.size = Vector2(560, 58)
	root.add_child(health_bar)

	score_label = Label.new()
	score_label.position = Vector2(1530, 24)
	score_label.size = Vector2(350, 50)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color(0.9, 2.4, 3.5, 1.0))
	score_label.add_theme_constant_override("outline_size", 4)
	score_label.add_theme_color_override("font_outline_color", Color(0.1, 0.25, 0.45, 0.9))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(score_label)

	boss_bar = ProgressBar.new()
	boss_bar.visible = false
	boss_bar.position = Vector2(650, 30)
	boss_bar.size = Vector2(620, 30)
	boss_bar.max_value = 100
	boss_bar.value = 100
	boss_bar.add_theme_stylebox_override("fill", StyleBoxFlat.new())
	boss_bar.add_theme_stylebox_override("bg", StyleBoxFlat.new())
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
	health_bar.set_health(health, max_health)

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
