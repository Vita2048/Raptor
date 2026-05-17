extends Area2D

var velocity := Vector2.ZERO
var damage := 10
var from_player := true
var pool
var sprite: Sprite2D
var trail: Line2D
var core_trail: Line2D
var sparkles: CPUParticles2D
var impact_sent := false

static var _shared_add_mat: CanvasItemMaterial

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7.0
	capsule.height = 28.0
	shape.shape = capsule
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.centered = true
	if not _shared_add_mat:
		_shared_add_mat = CanvasItemMaterial.new()
		_shared_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = _shared_add_mat
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
	
	core_trail = Line2D.new()
	core_trail.name = "LaserCore"
	core_trail.z_index = 120
	core_trail.width = 4.0
	core_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	core_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(core_trail)

	sparkles = CPUParticles2D.new()
	sparkles.name = "EnergySparkles"
	sparkles.z_index = 118
	sparkles.emitting = false
	sparkles.amount = 16
	sparkles.lifetime = 0.25
	sparkles.local_coords = false
	sparkles.direction = Vector2.UP
	sparkles.spread = 20.0
	sparkles.gravity = Vector2.ZERO
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	sparkles.scale_amount_curve = scale_curve
	sparkles.material = _shared_add_mat
	add_child(sparkles)
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
	core_trail.clear_points()
	sparkles.emitting = true
	if from_player:
		collision_layer = 4
		collision_mask = 2
		sprite.texture = AssetDB.random_particle("flash")
		sprite.modulate = Color(4.0, 1.35, 0.25, 1.0)
		sprite.scale = Vector2.ONE * 0.032
		
		trail.texture = null
		trail.gradient = null
		trail.default_color = Color(0.2, 2.5, 5.0, 0.8)
		trail.width = 12.0
		trail.add_point(Vector2(0.0, 6.0))
		trail.add_point(Vector2(0.0, 48.0))
		
		core_trail.texture = null
		core_trail.gradient = null
		core_trail.default_color = Color(5.0, 5.0, 5.0, 1.0)
		core_trail.width = 4.0
		core_trail.add_point(Vector2(0.0, 6.0))
		core_trail.add_point(Vector2(0.0, 42.0))
		
		sparkles.color = Color(0.2, 2.5, 5.0, 0.9)
		sparkles.amount = 16
		sparkles.initial_velocity_min = 30.0
		sparkles.initial_velocity_max = 80.0
		sparkles.scale_amount_min = 2.0
		sparkles.scale_amount_max = 5.0
	else:
		# Fancy Glowing Enemy Energy Bolt (inspired by bright glowing orbs with subtle trails)
		collision_layer = 8
		collision_mask = 1
		
		# Large, soft, intense glowing halo
		sprite.texture = AssetDB.random_particle("flash")
		sprite.modulate = Color(6.0, 0.05, 0.15, 0.9) # Intense deep red/pink glow
		sprite.scale = Vector2.ONE * 0.14
		
		trail.texture = null
		var trail_grad := Gradient.new()
		trail_grad.set_color(0, Color(4.0, 0.1, 0.1, 1.0)) # Bright red at head
		trail_grad.set_color(1, Color(1.5, 0.0, 0.0, 0.0)) # Fading red tail
		trail.gradient = trail_grad
		trail.width = 22.0
		trail.add_point(Vector2(0.0, 0.0))
		trail.add_point(Vector2(0.0, 10.0))
		trail.add_point(Vector2(0.0, 24.0))
		trail.add_point(Vector2(0.0, 42.0))
		
		core_trail.texture = null
		var core_grad := Gradient.new()
		core_grad.set_color(0, Color(4.0, 3.0, 3.0, 1.0)) # Pure white/hot pink core
		core_grad.set_color(1, Color(3.0, 1.0, 1.0, 0.0)) # Fades out quickly
		core_trail.gradient = core_grad
		core_trail.width = 10.0
		core_trail.add_point(Vector2(0.0, 0.0))
		core_trail.add_point(Vector2(0.0, 8.0))
		core_trail.add_point(Vector2(0.0, 18.0))
		
		sparkles.color = Color(5.0, 0.2, 0.3, 0.9)
		sparkles.amount = 14
		sparkles.initial_velocity_min = 15.0
		sparkles.initial_velocity_max = 50.0
		sparkles.scale_amount_min = 2.5
		sparkles.scale_amount_max = 5.0
		sparkles.lifetime = 0.22
	trail.modulate.a = 0.9
	core_trail.modulate.a = 1.0
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	# Pulsing orb scale for enemy shots
	if not from_player and sprite != null:
		var pulse := 0.058 + sin(Time.get_ticks_msec() * 0.007) * 0.009
		sprite.scale = Vector2.ONE * pulse
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
	core_trail.clear_points()
	sparkles.emitting = false

func _make_trail_width_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
