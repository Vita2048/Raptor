extends Node2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const EnemyShipScript := preload("res://scripts/EnemyShip.gd")
const ProjectileScript := preload("res://scripts/Projectile.gd")
const ExplosionScene := preload("res://scenes/ExplosionEffect.tscn")
const EnergyItemScript := preload("res://scripts/EnergyItem.gd")
const BombScript := preload("res://scripts/Bomb.gd")

var player: Node2D
var enemy_pool: ObjectPool
var enemy_bullet_pool: ObjectPool
var spawn_timer := 0.0
var spawn_interval := 0.95
var boss_spawned := false
var boss_pending := false
var bomb_spawn_timer := 14.0

func _ready() -> void:
	enemy_pool = ObjectPool.new(_create_enemy, self, 22)
	enemy_bullet_pool = ObjectPool.new(_create_enemy_bullet, get_parent(), 60)
	spawn_interval = spawn_interval_for_level(GameState.current_level)
	GameState.game_over.connect(_on_game_over)
	GameState.campaign_completed.connect(_on_game_over)

static func spawn_interval_for_level(level: int) -> float:
	if level >= 3:
		return 1.05
	if level >= 2:
		return 0.95
	return 0.95

static func wave_count_for_level(level: int) -> int:
	# Sectors 2+ field ~25% fewer ships per wave (2-5, avg 3.5) than sector 1 (3-6, avg 4.5).
	if level >= 2:
		return randi_range(2, 5)
	return randi_range(3, 6)

func _process(delta: float) -> void:
	if not GameState.game_active or boss_pending:
		return
	if GameState.should_start_boss():
		_spawn_boss()
	if boss_spawned or boss_pending:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave()
		spawn_timer = spawn_interval
	# Bomb hazard random respawn (moves with background)
	bomb_spawn_timer -= delta
	if bomb_spawn_timer <= 0.0:
		_spawn_bomb()
		bomb_spawn_timer = randf_range(9.5, 23.0)

func _spawn_wave() -> void:
	var count := wave_count_for_level(GameState.current_level)
	var start_x := randf_range(180.0, 1740.0)
	for i in range(count):
		var enemy := enemy_pool.acquire() as Area2D
		var kind: String
		if GameState.current_level >= 3:
			kind = "sentinel" if i % 3 == 0 else "lancer"
		elif GameState.current_level >= 2:
			var opts := ["enemy4", "enemy5", "enemy6"]
			kind = opts[randi() % opts.size()]
		else:
			kind = "bomber" if randf() < 0.2 else ("interceptor1" if randf() < 0.35 else "interceptor")
		enemy.spawn(kind, Vector2(clampf(start_x + (i - count * 0.5) * 150.0, 160, 1760), -120.0 - i * 70.0))

func _spawn_boss() -> void:
	boss_pending = true
	enemy_pool.release_all()
	enemy_bullet_pool.release_all()
	get_tree().call_group("bombs", "queue_free")
	var hud := get_parent().get_node_or_null("HUD")
	if hud:
		hud.show_boss_warning()
	VFX.audio.play_sound("alert")
	await get_tree().create_timer(1.6).timeout
	if not GameState.game_active:
		boss_pending = false
		return
	boss_spawned = true
	boss_pending = false
	var boss := enemy_pool.acquire() as Area2D
	var bkind := "boss2" if GameState.current_level >= 2 else "boss"
	if GameState.current_level == 3:
		bkind = "boss3"
	boss.spawn(bkind, Vector2(960, -430))
	boss.begin_entrance()
	GameState.begin_boss(boss.max_health)

func _create_enemy() -> Area2D:
	var enemy := EnemyShipScript.new()
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemy.boss_destroyed.connect(_on_boss_destroyed)
	enemy.request_fire.connect(_on_enemy_request_fire)
	return enemy

func _create_enemy_bullet() -> Area2D:
	var bullet := ProjectileScript.new()
	bullet.name = "EnemyProjectile"
	return bullet

func _on_enemy_request_fire(origin: Vector2, directions: Array, speed: float, damage: int) -> void:
	if not GameState.game_active:
		return
	for direction in directions:
		var bullet := enemy_bullet_pool.acquire() as Area2D
		bullet.launch(origin, direction, speed, damage, false)

func _on_enemy_destroyed(pos: Vector2, score_value: int, was_boss: bool) -> void:
	GameState.add_score(score_value)
	GameState.record_kill("boss" if was_boss else "ship")
	if not was_boss:
		_spawn_explosion(pos)
		if randf() < 0.20:
			_spawn_energy_item.call_deferred(pos)

func _on_boss_destroyed(pos: Vector2) -> void:
	if not GameState.game_active:
		return
	var explosion_scale := 0.7
	VFX.call_deferred("boss_explosion", pos, explosion_scale)
	boss_spawned = false
	GameState.end_boss()
	if GameState.current_level < 3:
		var cleared_level := GameState.current_level
		var hud := get_parent().get_node_or_null("HUD")
		GameState.advance_level()
		if hud and hud.has_method("show_level_transition"):
			hud.call_deferred("show_level_transition", cleared_level, GameState.current_level)
		var ws := get_parent().get_node_or_null("WorldSpawner")
		if ws and ws.has_method("rebuild_for_level"):
			ws.call_deferred("rebuild_for_level", GameState.current_level)
		spawn_timer = 2.8
		spawn_interval = spawn_interval_for_level(GameState.current_level)
		enemy_bullet_pool.release_all()
	else:
		GameState.complete_campaign()

func _spawn_energy_item(pos: Vector2) -> void:
	var item := EnergyItemScript.new()
	item.top_level = true
	item.global_position = pos
	get_parent().add_child(item)

func _spawn_explosion(pos: Vector2) -> void:
	_spawn_single_explosion(pos)

func _spawn_single_explosion(pos: Vector2, scale_multiplier: float = 1.0) -> void:
	var explosion := ExplosionScene.instantiate()
	explosion.global_position = pos
	explosion.configure(false, scale_multiplier)
	get_parent().add_child(explosion)
	explosion.burst()

func _spawn_bomb() -> void:
	var bomb := BombScript.new()
	bomb.destroyed.connect(_on_bomb_destroyed)
	var x := randf_range(240.0, 1680.0)
	bomb.global_position = Vector2(x, -95.0)
	get_parent().add_child(bomb)

func _on_bomb_destroyed(pos: Vector2, by_shot: bool) -> void:
	if by_shot:
		GameState.add_score(130)
	_spawn_single_explosion(pos)

func _on_game_over() -> void:
	boss_pending = false
	enemy_pool.release_all()
	enemy_bullet_pool.release_all()
	get_parent().get_tree().call_group("bombs", "queue_free")
