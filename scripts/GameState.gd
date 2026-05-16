extends Node

signal score_changed(score: int)
signal player_health_changed(health: int, max_health: int)
signal boss_started(max_health: int)
signal boss_health_changed(health: int, max_health: int)
signal game_over

const BOSS_SCORE_THRESHOLD := 5000

var score := 0
var player_health := 100
var player_max_health := 100
var boss_active := false

func reset() -> void:
	score = 0
	player_health = player_max_health
	boss_active = false
	score_changed.emit(score)
	player_health_changed.emit(player_health, player_max_health)
	boss_health_changed.emit(0, 1)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func damage_player(amount: int) -> void:
	player_health = max(player_health - amount, 0)
	player_health_changed.emit(player_health, player_max_health)
	if player_health <= 0:
		game_over.emit()

func should_start_boss() -> bool:
	return not boss_active and score >= BOSS_SCORE_THRESHOLD

func begin_boss(max_health: int) -> void:
	boss_active = true
	boss_started.emit(max_health)
	boss_health_changed.emit(max_health, max_health)
