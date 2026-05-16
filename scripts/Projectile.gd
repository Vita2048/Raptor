extends Area2D

var velocity := Vector2.ZERO
var damage := 10
var from_player := true
var pool
var sprite: Sprite2D
var trail: GPUParticles2D

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7.0
	capsule.height = 28.0
	shape.shape = capsule
	add_child(shape)

	sprite = Sprite2D.new()
	add_child(sprite)
	monitoring = false
	monitorable = false

func set_pool(value) -> void:
	pool = value

func launch(start_pos: Vector2, direction: Vector2, speed: float, hit_damage: int, player_owned: bool) -> void:
	global_position = start_pos
	velocity = direction.normalized() * speed
	damage = hit_damage
	from_player = player_owned
	rotation = velocity.angle() + PI * 0.5
	if from_player:
		collision_layer = 4
		collision_mask = 2
		sprite.texture = AssetDB.random_particle("flash")
		sprite.modulate = Color(0.4, 0.95, 1.0, 0.95)
		sprite.scale = Vector2.ONE * 0.055
	else:
		collision_layer = 8
		collision_mask = 1
		sprite.texture = AssetDB.random_particle("explosion")
		sprite.modulate = Color(1.0, 0.32, 0.12, 0.94)
		sprite.scale = Vector2.ONE * 0.042
	monitoring = true
	monitorable = true

func _physics_process(delta: float) -> void:
	position += velocity * delta
	if position.y < -120.0 or position.y > 1220.0 or position.x < -120.0 or position.x > 2040.0:
		return_to_pool()

func is_player_damage() -> bool:
	return from_player

func is_enemy_damage() -> bool:
	return not from_player

func return_to_pool() -> void:
	if pool != null:
		pool.release(self)

func on_pool_released() -> void:
	monitoring = false
	monitorable = false
	velocity = Vector2.ZERO
