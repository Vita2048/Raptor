extends Node

signal score_changed(score: int)
signal player_health_changed(health: int, max_health: int)
signal boss_started(max_health: int)
signal boss_health_changed(health: int, max_health: int)
signal game_over
signal campaign_completed
signal level_advanced(new_level: int)

const BOSS_INTERVAL := 15000

var score := 0
var player_health := 100
var player_max_health := 100
var boss_active := false
var next_boss_score := BOSS_INTERVAL
var current_level := 1
var game_active := true
var campaign_won := false
var elapsed_seconds := 0.0
var ships_destroyed := 0
var bosses_destroyed := 0
var structures_destroyed := 0
var vehicles_destroyed := 0
var shots_fired := 0
var armor_lost := 0

func reset() -> void:
	campaign_won = false
	elapsed_seconds = 0.0
	ships_destroyed = 0
	bosses_destroyed = 0
	structures_destroyed = 0
	vehicles_destroyed = 0
	shots_fired = 0
	armor_lost = 0
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
	if not game_active:
		return
	score += amount
	score_changed.emit(score)

func damage_player(amount: int) -> void:
	if not game_active:
		return
	armor_lost += mini(amount, player_health)
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
	return game_active and not boss_active and score >= next_boss_score

func begin_boss(max_health: int) -> void:
	boss_active = true
	boss_started.emit(max_health)
	boss_health_changed.emit(max_health, max_health)

func end_boss() -> void:
	boss_active = false
	next_boss_score = score + BOSS_INTERVAL
	boss_health_changed.emit(0, 1)

func advance_level() -> void:
	if current_level >= 3 or not game_active:
		return
	current_level += 1
	level_advanced.emit(current_level)

func _process(delta: float) -> void:
	if game_active:
		elapsed_seconds += delta

func record_kill(kind: String) -> void:
	if not game_active:
		return
	match kind:
		"ship": ships_destroyed += 1
		"boss": bosses_destroyed += 1
		"structure": structures_destroyed += 1
		"vehicle": vehicles_destroyed += 1

func complete_campaign() -> void:
	if not game_active or campaign_won:
		return
	campaign_won = true
	game_active = false
	boss_active = false
	campaign_completed.emit()

