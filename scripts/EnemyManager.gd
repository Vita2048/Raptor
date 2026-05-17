extends Node2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const EnemyShipScript := preload("res://scripts/EnemyShip.gd")
const ProjectileScript := preload("res://scripts/Projectile.gd")
const ExplosionScene := preload("res://scenes/ExplosionEffect.tscn")

var player: Node2D
var enemy_pool: ObjectPool
var enemy_bullet_pool: ObjectPool
var spawn_timer := 0.0
var spawn_interval := 1.15
var boss_spawned := false

func _ready() -> void:
	enemy_pool = ObjectPool.new(_create_enemy, self, 22)
	enemy_bullet_pool = ObjectPool.new(_create_enemy_bullet, get_parent(), 120)
	GameState.game_over.connect(_on_game_over)

func _process(delta: float) -> void:
	if GameState.should_start_boss():
		_spawn_boss()
	if boss_spawned:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave()
		spawn_timer = spawn_interval

func _spawn_wave() -> void:
	var count := randi_range(2, 5)
	var start_x := randf_range(180.0, 1740.0)
	for i in range(count):
		var enemy := enemy_pool.acquire() as Area2D
		var kind := "bomber" if randf() < 0.25 else "interceptor"
		enemy.spawn(kind, Vector2(start_x + (i - count * 0.5) * 150.0, -120.0 - i * 70.0))

func _spawn_boss() -> void:
	boss_spawned = true
	enemy_pool.release_all()
	var boss := enemy_pool.acquire() as Area2D
	boss.spawn("boss", Vector2(960, -180))
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
	for direction in directions:
		var bullet := enemy_bullet_pool.acquire() as Area2D
		bullet.launch(origin, direction, speed, damage, false)

func _on_enemy_destroyed(pos: Vector2, score_value: int, was_boss: bool) -> void:
	GameState.add_score(score_value)
	_spawn_explosion(pos, was_boss)

func _on_boss_destroyed(pos: Vector2) -> void:
	VFX.call_deferred("boss_explosion", pos)
	boss_spawned = false
	GameState.end_boss()

func _spawn_explosion(pos: Vector2, large: bool = false) -> void:
	if large:
		_spawn_boss_explosion(pos)
		return
	_spawn_single_explosion(pos, false)

func _spawn_single_explosion(pos: Vector2, large: bool = false) -> void:
	var explosion := ExplosionScene.instantiate()
	explosion.global_position = pos
	explosion.configure(large)
	get_parent().add_child(explosion)
	explosion.burst()

func _spawn_boss_explosion(pos: Vector2) -> void:
	_spawn_single_explosion(pos, true)
	var offsets := [
		Vector2(-160, -190),
		Vector2(170, -160),
		Vector2(-250, 20),
		Vector2(250, 35),
		Vector2(-115, 205),
		Vector2(130, 230),
		Vector2(0, -310),
		Vector2(0, 330)
	]
	for i in range(offsets.size()):
		_spawn_delayed_boss_explosion(pos + offsets[i], 0.04 + i * 0.045)

func _spawn_delayed_boss_explosion(pos: Vector2, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(self):
		_spawn_single_explosion(pos, true)

func _on_game_over() -> void:
	enemy_pool.release_all()
	enemy_bullet_pool.release_all()
