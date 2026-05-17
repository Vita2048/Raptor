extends Area2D

var velocity := Vector2.ZERO
var damage := 10
var from_player := true
var pool
var sprite: Sprite2D
var trail: Line2D
var impact_sent := false

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7.0
	capsule.height = 28.0
	shape.shape = capsule
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.centered = true
	var sprite_material := CanvasItemMaterial.new()
	sprite_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = sprite_material
	add_child(sprite)

	trail = Line2D.new()
	trail.name = "MotionBlurTrail"
	trail.z_index = 119
	trail.width = 8.0
	trail.width_curve = _make_trail_width_curve()
	trail.default_color = Color(4.0, 1.2, 0.25, 0.42)
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2(0.0, 34.0))
	add_child(trail)
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
	impact_sent = false
	trail.clear_points()
	if from_player:
		collision_layer = 4
		collision_mask = 2
		sprite.texture = AssetDB.random_particle("flash")
		sprite.modulate = Color(4.0, 1.35, 0.25, 1.0)
		sprite.scale = Vector2.ONE * 0.032
		trail.default_color = Color(4.0, 1.25, 0.2, 0.45)
		trail.width = 7.5
		trail.add_point(Vector2(0.0, 6.0))
		trail.add_point(Vector2(0.0, 38.0))
	else:
		collision_layer = 8
		collision_mask = 1
		sprite.texture = AssetDB.random_particle("explosion")
		sprite.modulate = Color(4.0, 0.45, 0.14, 1.0)
		sprite.scale = Vector2.ONE * 0.026
		trail.default_color = Color(4.0, 0.35, 0.12, 0.4)
		trail.width = 6.5
		trail.add_point(Vector2(0.0, 5.0))
		trail.add_point(Vector2(0.0, 30.0))
	trail.modulate.a = 0.78
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

func spawn_impact(pos: Vector2 = global_position) -> void:
	if impact_sent:
		return
	impact_sent = true
	VFX.impact_spark(pos, velocity, from_player)

func on_pool_released() -> void:
	monitoring = false
	monitorable = false
	velocity = Vector2.ZERO
	impact_sent = false
	trail.clear_points()

func _make_trail_width_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
