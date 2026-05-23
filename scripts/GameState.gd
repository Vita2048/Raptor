extends Node

signal score_changed(score: int)
signal player_health_changed(health: int, max_health: int)
signal boss_started(max_health: int)
signal boss_health_changed(health: int, max_health: int)
signal game_over
signal level_advanced(new_level: int)

const BOSS_INTERVAL := 5000

var score := 0
var player_health := 100
var player_max_health := 100
var boss_active := false
var next_boss_score := BOSS_INTERVAL
var current_level := 1
var game_active := true

func reset() -> void:
	score = 0
	player_health = player_max_health
	boss_active = false
	game_active = true
	next_boss_score = BOSS_INTERVAL
	current_level = 1
	score_changed.emit(score)
	player_health_changed.emit(player_health, player_max_health)
	boss_health_changed.emit(0, 1)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func damage_player(amount: int) -> void:
	if not game_active:
		return
	player_health = max(player_health - amount, 0)
	player_health_changed.emit(player_health, player_max_health)
	if player_health <= 0:
		game_active = false
		game_over.emit()

func heal_player(amount: int) -> void:
	if not game_active:
		return
	player_health = min(player_health + amount, player_max_health)
	player_health_changed.emit(player_health, player_max_health)

func should_start_boss() -> bool:
	return not boss_active and score >= next_boss_score

func begin_boss(max_health: int) -> void:
	boss_active = true
	boss_started.emit(max_health)
	boss_health_changed.emit(max_health, max_health)

func end_boss() -> void:
	boss_active = false
	next_boss_score = score + BOSS_INTERVAL
	boss_health_changed.emit(0, 1)

func advance_level() -> void:
	current_level = 2
	level_advanced.emit(2)

