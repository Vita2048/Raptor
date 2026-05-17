extends Area2D

signal destroyed(position: Vector2, score_value: int, was_boss: bool)
signal boss_destroyed(position: Vector2)
signal request_fire(origin: Vector2, directions: Array, speed: float, damage: int)

const ExhaustPlumeScript := preload("res://scripts/ExhaustPlume.gd")
const VIEW_SIZE := Vector2(1920, 1080)

var enemy_type := "interceptor"
var health := 40
var max_health := 40
var speed := 210.0
var score_value := 250
var amplitude := 0.0
var phase := 0.0
var base_x := 0.0
var fire_timer := 1.5
var fire_interval := 1.6
var pool
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var is_boss := false
var is_dead := false
var exhaust_plumes: Array[Node2D] = []

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	sprite = Sprite2D.new()
	add_child(sprite)
	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	collision_shape.shape = circle
	add_child(collision_shape)

func set_pool(value) -> void:
	pool = value

func spawn(kind: String, start_position: Vector2) -> void:
	enemy_type = kind
	is_boss = kind == "boss"
	is_dead = false
	global_position = start_position
	base_x = start_position.x
	phase = randf_range(0.0, TAU)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	match kind:
		"bomber":
			sprite.texture = AssetDB.ship_textures["bomber"]
			sprite.scale = Vector2.ONE * 0.85
			(collision_shape.shape as CircleShape2D).radius = 48.0
			_configure_exhausts([
				{"position": Vector2(-21, -52), "length": 52.0, "width": 17.0},
				{"position": Vector2(21, -52), "length": 52.0, "width": 17.0}
			])
			health = 85
			speed = 160.0
			score_value = 700
			amplitude = 70.0
			fire_interval = 1.25
		"boss":
			sprite.texture = AssetDB.ship_textures["boss"]
			sprite.scale = Vector2.ONE * 0.32
			(collision_shape.shape as CircleShape2D).radius = 160.0
			_configure_exhausts([
				{"position": Vector2(0, -168), "length": 108.0, "width": 30.0},
				{"position": Vector2(-44, -182), "length": 118.0, "width": 34.0},
				{"position": Vector2(44, -182), "length": 118.0, "width": 34.0},
				
			])
			health = 4520
			speed = 0.0
			score_value = 6000
			amplitude = 180.0
			fire_interval = 0.35
		_:
			sprite.texture = AssetDB.ship_textures["interceptor"]
			sprite.scale = Vector2.ONE * 0.9
			(collision_shape.shape as CircleShape2D).radius = 38.0
			_configure_exhausts([
				{"position": Vector2(-36, -45), "length": 42.0, "width": 14.0},
				{"position": Vector2(36, -45), "length": 42.0, "width": 14.0}
			])
			health = 42
			speed = 310.0
			score_value = 300
			amplitude = 115.0
			fire_interval = 1.8
	max_health = health
	fire_timer = randf_range(0.4, fire_interval)

func _physics_process(delta: float) -> void:
	if is_boss:
		var target := Vector2(base_x + sin(Time.get_ticks_msec() * 0.0014) * amplitude, 280.0)
		position = position.lerp(target, 1.9 * delta)
	else:
		position.y += speed * delta
		position.x = base_x + sin(position.y * 0.011 + phase) * amplitude
		if position.y > VIEW_SIZE.y + 160.0:
			return_to_pool()
	fire_timer -= delta
	if fire_timer <= 0.0:
		_fire_pattern()
		fire_timer = fire_interval

func _fire_pattern() -> void:
	if is_boss:
		var directions: Array = []
		# Firing pattern leaves a clear 30-degree gap (-15 to 15) in the middle for the player to hide in!
		for angle in [-75.0, -60.0, -45.0, -30.0, -15.0, 15.0, 30.0, 45.0, 60.0, 75.0]:
			directions.append(Vector2.DOWN.rotated(deg_to_rad(angle)))
		var origin := global_position + Vector2(0, 150)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, directions, 520.0, 15)
	elif enemy_type == "bomber":
		var origin := global_position + Vector2(0, 64)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2.DOWN, Vector2(0.25, 1.0), Vector2(-0.25, 1.0)], 390.0, 12)
	else:
		var origin := global_position + Vector2(0, 48)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2.DOWN], 470.0, 10)

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.has_method("is_player_damage") and area.is_player_damage():
		health -= area.damage
		if area.has_method("spawn_impact"):
			area.spawn_impact(area.global_position)
		if area.has_method("return_to_pool"):
			area.return_to_pool()
		if is_boss:
			GameState.boss_health_changed.emit(max(health, 0), max_health)
		if health <= 0:
			is_dead = true
			var death_position := global_position
			var death_score := score_value
			var death_was_boss := is_boss
			destroyed.emit(death_position, death_score, death_was_boss)
			if death_was_boss:
				boss_destroyed.emit(death_position)
			return_to_pool()

func return_to_pool() -> void:
	if pool != null:
		pool.release(self)

func on_pool_released() -> void:
	monitoring = false
	monitorable = false

func _configure_exhausts(configs: Array) -> void:
	while exhaust_plumes.size() < configs.size():
		var exhaust := ExhaustPlumeScript.new()
		add_child(exhaust)
		exhaust_plumes.append(exhaust)
	for i in range(exhaust_plumes.size()):
		var exhaust := exhaust_plumes[i]
		exhaust.visible = i < configs.size()
		if i >= configs.size():
			continue
		var config: Dictionary = configs[i]
		exhaust.position = config["position"]
		exhaust.configure(config["length"], config["width"], PI)
