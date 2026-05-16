extends Area2D

signal destroyed(position: Vector2, score_value: int, was_boss: bool)
signal request_fire(origin: Vector2, directions: Array, speed: float, damage: int)

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
var is_boss := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	sprite = Sprite2D.new()
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	shape.shape = circle
	add_child(shape)

func set_pool(value) -> void:
	pool = value

func spawn(kind: String, start_position: Vector2) -> void:
	enemy_type = kind
	is_boss = kind == "boss"
	global_position = start_position
	base_x = start_position.x
	phase = randf_range(0.0, TAU)
	monitoring = true
	monitorable = true
	match kind:
		"bomber":
			sprite.texture = AssetDB.ship_textures["bomber"]
			sprite.scale = Vector2.ONE * 0.85
			health = 85
			speed = 160.0
			score_value = 700
			amplitude = 70.0
			fire_interval = 1.25
		"boss":
			sprite.texture = AssetDB.ship_textures["boss"]
			sprite.scale = Vector2.ONE * 0.32
			health = 1200
			speed = 0.0
			score_value = 6000
			amplitude = 150.0
			fire_interval = 0.7
		_:
			sprite.texture = AssetDB.ship_textures["interceptor"]
			sprite.scale = Vector2.ONE * 0.9
			health = 42
			speed = 310.0
			score_value = 300
			amplitude = 115.0
			fire_interval = 1.8
	max_health = health
	fire_timer = randf_range(0.4, fire_interval)

func _physics_process(delta: float) -> void:
	if is_boss:
		var target := Vector2(base_x + sin(Time.get_ticks_msec() * 0.0014) * amplitude, 150.0)
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
		for angle in [-64.0, -42.0, -22.0, 0.0, 22.0, 42.0, 64.0]:
			directions.append(Vector2.DOWN.rotated(deg_to_rad(angle)))
		request_fire.emit(global_position + Vector2(0, 150), directions, 430.0, 12)
	elif enemy_type == "bomber":
		request_fire.emit(global_position + Vector2(0, 64), [Vector2.DOWN, Vector2(0.25, 1.0), Vector2(-0.25, 1.0)], 390.0, 12)
	else:
		request_fire.emit(global_position + Vector2(0, 48), [Vector2.DOWN], 470.0, 10)

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("is_player_damage") and area.is_player_damage():
		health -= area.damage
		if area.has_method("return_to_pool"):
			area.return_to_pool()
		if is_boss:
			GameState.boss_health_changed.emit(max(health, 0), max_health)
		if health <= 0:
			var death_position := global_position
			var death_score := score_value
			var death_was_boss := is_boss
			destroyed.emit(death_position, death_score, death_was_boss)
			return_to_pool()

func return_to_pool() -> void:
	if pool != null:
		pool.release(self)

func on_pool_released() -> void:
	monitoring = false
	monitorable = false
