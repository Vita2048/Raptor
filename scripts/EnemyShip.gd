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
var silhouette_collision_polygons: Array[CollisionPolygon2D] = []
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
	is_boss = kind == "boss" or kind == "boss2"
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
			_configure_circle_collision(48.0)
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
			_configure_silhouette_collision(160.0)
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
		"interceptor1":
			sprite.texture = AssetDB.ship_textures["interceptor1"]
			# Texture is 642x609 — scale to match the ~123px display size of other interceptors
			sprite.scale = Vector2.ONE * 0.19
			_configure_circle_collision(30.0)
			# Exhaust nozzles are at the top of the sprite (y≈4 in image coords).
			# Pixel offset from image center (321,304): left=(-97,-300), right=(96,-300)
			# Multiplied by scale 0.19 → local coords below
			_configure_exhausts([
				{"position": Vector2(-18, -57), "length": 40.0, "width": 13.0},
				{"position": Vector2(18, -57), "length": 40.0, "width": 13.0}
			])
			health = 44
			speed = 295.0
			score_value = 320
			amplitude = 105.0
			fire_interval = 1.65
		"enemy4":
			sprite.texture = AssetDB.ship_textures["enemy4"]
			sprite.scale = Vector2.ONE * 0.82
			_configure_circle_collision(44.0)
			# Accurate from analysis: twin engines near top-center of png
			_configure_exhausts([
				{"position": Vector2(-5, -50), "length": 48.0, "width": 13.0},
				{"position": Vector2(8, -50), "length": 48.0, "width": 13.0}
			])
			health = 58
			speed = 255.0
			score_value = 390
			amplitude = 88.0
			fire_interval = 1.05
		"enemy5":
			sprite.texture = AssetDB.ship_textures["enemy5"]
			sprite.scale = Vector2.ONE * 0.78
			_configure_circle_collision(40.0)
			# Accurate: main engines at upper region, twin + center
			_configure_exhausts([
				{"position": Vector2(-17, -60), "length": 55.0, "width": 12.0},
				{"position": Vector2(-2, -64), "length": 62.0, "width": 15.0},
				{"position": Vector2(14, -60), "length": 55.0, "width": 12.0}
			])
			health = 72
			speed = 195.0
			score_value = 520
			amplitude = 140.0
			fire_interval = 1.45
		"enemy6":
			sprite.texture = AssetDB.ship_textures["enemy6"]
			sprite.scale = Vector2.ONE * 0.71
			_configure_circle_collision(36.0)
			# Accurate: engines clustered at very top of tall sprite
			_configure_exhausts([
				{"position": Vector2(-6, -71), "length": 52.0, "width": 12.0},
				{"position": Vector2(8, -72), "length": 52.0, "width": 12.0}
			])
			health = 48
			speed = 340.0
			score_value = 410
			amplitude = 70.0
			fire_interval = 0.95
		"boss2":
			sprite.texture = AssetDB.ship_textures["boss2"]
			sprite.scale = Vector2.ONE * 0.5655
			_configure_silhouette_collision(303.0)
			# Accurate engine positions from sprite analysis (Bosship2 401x547, engines near top of png)
			# Level-2 boss is 50% larger than its previous visual size.
			_configure_exhausts([
				{"position": Vector2(-28.5, -112.5), "length": 168.0, "width": 36.0},
				{"position": Vector2(-6.0, -108.0), "length": 150.0, "width": 25.5},
				{"position": Vector2(9.0, -108.0), "length": 150.0, "width": 25.5},
				{"position": Vector2(51.0, -112.5), "length": 168.0, "width": 36.0}
			])
			health = 5650
			speed = 0.0
			score_value = 8200
			amplitude = 145.0
			fire_interval = 0.29
		_:
			sprite.texture = AssetDB.ship_textures["interceptor"]
			sprite.scale = Vector2.ONE * 0.9
			_configure_circle_collision(38.0)
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
		var origin: Vector2
		var speed := 520.0
		var dmg := 15
		if enemy_type == "boss2":
			# Level2 boss: denser pattern but with a clear central safe gap (~30 degrees)
			# so the player has a place to dodge and hide between the volleys
			for angle in [-82.0, -62.0, -42.0, -25.0, -15.0, 15.0, 25.0, 42.0, 62.0, 82.0]:
				directions.append(Vector2.DOWN.rotated(deg_to_rad(angle)))
			origin = global_position + Vector2(0, 160)
			speed = 580.0
			dmg = 17
			VFX.muzzle_flash(origin, Vector2.DOWN, false)
			request_fire.emit(origin, directions, speed, dmg)
		else:
			# Firing pattern leaves a clear 30-degree gap (-15 to 15) in the middle for the player to hide in!
			for angle in [-75.0, -60.0, -45.0, -30.0, -15.0, 15.0, 30.0, 45.0, 60.0, 75.0]:
				directions.append(Vector2.DOWN.rotated(deg_to_rad(angle)))
			origin = global_position + Vector2(0, 150)
			VFX.muzzle_flash(origin, Vector2.DOWN, false)
			request_fire.emit(origin, directions, speed, dmg)
	elif enemy_type == "bomber":
		var origin := global_position + Vector2(0, 64)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2.DOWN, Vector2(0.25, 1.0), Vector2(-0.25, 1.0)], 390.0, 12)
	elif enemy_type == "interceptor1":
		# Twin-spread shot: two slightly angled bolts for a more aggressive feel
		var origin := global_position + Vector2(0, 30)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2(-0.12, 1.0).normalized(), Vector2(0.12, 1.0).normalized()], 450.0, 11)
	elif enemy_type == "enemy4":
		# aggressive forward triple
		var origin := global_position + Vector2(0, 52)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2(-0.18, 1.0).normalized(), Vector2.DOWN, Vector2(0.18, 1.0).normalized()], 510.0, 9)
	elif enemy_type == "enemy5":
		# wide spread + slow heavy
		var origin := global_position + Vector2(0, 58)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2(-0.38, 1.0).normalized(), Vector2(-0.12, 1.0).normalized(), Vector2(0.12, 1.0).normalized(), Vector2(0.38, 1.0).normalized()], 320.0, 14)
	elif enemy_type == "enemy6":
		# rapid narrow double
		var origin := global_position + Vector2(0, 70)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2(-0.07, 1.0).normalized(), Vector2(0.07, 1.0).normalized()], 620.0, 8)
	else:
		var origin := global_position + Vector2(0, 48)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2.DOWN], 470.0, 10)

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	# Direct ship-to-ship collision: enemy rams the player
	if area.has_method("_shoot"):
		is_dead = true
		var ram_damage := 40 if is_boss else 25
		GameState.damage_player(ram_damage)
		VFX.impact_spark(global_position, Vector2(0, 220), false)
		var death_position := global_position
		var death_score := score_value
		destroyed.emit(death_position, death_score, false)
		if is_boss:
			boss_destroyed.emit(death_position)
		return_to_pool()
		return
	if area.has_method("is_player_damage") and area.is_player_damage():
		health -= area.damage
		var impact_pos := area.global_position
		if is_boss and area.has_method("velocity"):
			impact_pos = _get_visual_impact_point(impact_pos, area.velocity)
		if area.has_method("spawn_impact"):
			area.spawn_impact(impact_pos)
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

func _configure_circle_collision(radius: float) -> void:
	_clear_silhouette_collision()
	collision_shape.disabled = false
	(collision_shape.shape as CircleShape2D).radius = radius

func _configure_silhouette_collision(fallback_radius: float) -> void:
	_clear_silhouette_collision()
	(collision_shape.shape as CircleShape2D).radius = fallback_radius
	collision_shape.disabled = true
	if sprite == null or sprite.texture == null:
		collision_shape.disabled = false
		return

	var img: Image = sprite.texture.get_image()
	if img == null:
		collision_shape.disabled = false
		return
	if img.is_compressed():
		img.decompress()

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(img, 0.08)
	var tex_size := Vector2(img.get_width(), img.get_height())
	var polygons := bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, tex_size), 2.0)
	for polygon in polygons:
		if _polygon_area(polygon) < 96.0:
			continue
		var collider := CollisionPolygon2D.new()
		var scaled_polygon := PackedVector2Array()
		for point in polygon:
			scaled_polygon.append((point - tex_size * 0.5) * sprite.scale)
		collider.polygon = scaled_polygon
		add_child(collider)
		silhouette_collision_polygons.append(collider)

	if silhouette_collision_polygons.is_empty():
		collision_shape.disabled = false

func _clear_silhouette_collision() -> void:
	for collider in silhouette_collision_polygons:
		if is_instance_valid(collider):
			collider.disabled = true
			collider.queue_free()
	silhouette_collision_polygons.clear()

func _polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var area := 0.0
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		area += a.x * b.y - b.x * a.y
	return abs(area) * 0.5

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

# Returns the point where the bullet visually touches the actual painted silhouette of the ship.
# Uses ray marching + alpha sampling on the sprite texture so explosions appear exactly on the ship, not in transparent areas.
func _get_visual_impact_point(bullet_pos: Vector2, bullet_vel: Vector2) -> Vector2:
	if sprite == null or sprite.texture == null:
		return bullet_pos

	var dir := bullet_vel.normalized()
	if dir.length_squared() < 0.0001:
		return bullet_pos

	var img: Image = sprite.texture.get_image()
	if img == null:
		return bullet_pos

	# Make sure we can read pixels (convert if compressed)
	if img.is_compressed():
		img.decompress()

	var tex_size := Vector2(img.get_width(), img.get_height())
	var world_scale: float = max(abs(sprite.global_scale.x), abs(sprite.global_scale.y))

	# Step roughly every 4-5 texture pixels, expressed in world units.
	var step: float = max(1.5, 4.5 * max(world_scale, 0.01))
	var max_dist: float = tex_size.length() * max(world_scale, 0.01) + 80.0
	var pos := bullet_pos
	var traveled := 0.0

	while traveled < max_dist:
		var local := sprite.to_local(pos) + tex_size * 0.5

		if local.x < 0 or local.y < 0 or local.x >= tex_size.x or local.y >= tex_size.y:
			# Still outside the texture bounds — keep marching
			pos += dir * step
			traveled += step
			continue

		# Sample alpha at this pixel
		var px := int(clamp(local.x, 0, tex_size.x - 1))
		var py := int(clamp(local.y, 0, tex_size.y - 1))
		var alpha := img.get_pixel(px, py).a

		if alpha > 0.08:   # threshold for "solid" ship pixel
			return pos

		pos += dir * step
		traveled += step

	# Fallback to original position if we never found opaque pixel (shouldn't happen)
	return bullet_pos
