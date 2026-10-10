extends Area2D

signal destroyed(position: Vector2, score_value: int, was_boss: bool)
signal boss_destroyed(position: Vector2)
signal request_fire(origin: Vector2, directions: Array, speed: float, damage: int)

const ExhaustPlumeScript := preload("res://scripts/ExhaustPlume.gd")
const VIEW_SIZE := Vector2(1920, 1080)
const BOSS_COLLISIONS := {
	"boss": preload("res://assets/collision/boss.tres"),
	"boss2": preload("res://assets/collision/boss2.tres"),
	"boss3": preload("res://assets/collision/boss3.tres")
}

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
var hit_material: ShaderMaterial
var hit_strength := 0.0
var boss_damage_stage := 0
var boss_damage_blend := 0.0
var damage_effect: Node2D
var collision_shape: CollisionShape2D
var silhouette_collision_polygons: Array[CollisionShape2D] = []
var is_boss := false
var is_dead := false
var volley_index := 0
var entrance_remaining := 0.0
var charge_remaining := -1.0
var charge_visual: Node2D
const ENTRANCE_TIME := 2.4
const CHARGE_TIME := 0.55
var exhaust_plumes: Array[Node2D] = []

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	sprite = Sprite2D.new()
	add_child(sprite)
	charge_visual = Node2D.new()
	charge_visual.z_index = 5
	charge_visual.draw.connect(_draw_charge)
	add_child(charge_visual)
	damage_effect = preload("res://scripts/BossDamageEffect.gd").new()
	add_child(damage_effect)
	var shadow := preload("res://scripts/AircraftShadow.gd").new()
	shadow.source = sprite
	add_child(shadow)
	hit_material = ShaderMaterial.new()
	hit_material.shader = preload("res://shaders/ship_hit.gdshader")
	sprite.material = hit_material
	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	collision_shape.shape = circle
	add_child(collision_shape)

func set_pool(value) -> void:
	pool = value

func spawn(kind: String, start_position: Vector2) -> void:
	enemy_type = kind
	is_boss = kind in ["boss", "boss2", "boss3"]
	volley_index = 0
	is_dead = false
	entrance_remaining = 0.0
	charge_remaining = -1.0
	charge_visual.queue_redraw()
	hit_strength = 0.0
	hit_material.set_shader_parameter("hit_amount", 0.0)
	global_position = start_position
	base_x = start_position.x
	phase = randf_range(0.0, TAU)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	match kind:
		"lancer", "sentinel", "boss3":
			sprite.texture = AssetDB.ship_textures[kind]
			var width := 150.0 if kind == "lancer" else (195.0 if kind == "sentinel" else 530.0)
			sprite.scale = Vector2.ONE * width / sprite.texture.get_width()
			if is_boss:
				_configure_silhouette_collision(180.0)
			else:
				_configure_circle_collision(35.0 if kind == "lancer" else 55.0)
			var dimensions := sprite.texture.get_size() * sprite.scale
			var nozzles: Array = []
			var offsets: Array = [-0.12, -0.04, 0.04, 0.12] if is_boss else ([-0.06, 0.06] if kind == "lancer" else [-0.16, 0.16])
			for offset in offsets:
				nozzles.append({"position": Vector2(width * float(offset), -dimensions.y * 0.49), "length": 100.0 if is_boss else 44.0, "width": 20.0 if is_boss else 12.0})
			_configure_exhausts(nozzles)
			health = 10800 if is_boss else (72 if kind == "lancer" else 140)
			speed = 0.0 if is_boss else (360.0 if kind == "lancer" else 175.0)
			score_value = 12000 if is_boss else (690 if kind == "lancer" else 1080)
			amplitude = 360.0 if is_boss else (140.0 if kind == "lancer" else 65.0)
			fire_interval = 0.35 if is_boss else (0.9 if kind == "lancer" else 1.4)
		"bomber":
			sprite.texture = AssetDB.ship_textures["bomber"]
			sprite.scale = Vector2.ONE * 0.85
			_configure_circle_collision(48.0)
			_configure_exhausts([
				{"position": Vector2(-21, -52), "length": 52.0, "width": 17.0},
				{"position": Vector2(21, -52), "length": 52.0, "width": 17.0}
			])
			health = 110
			speed = 185.0
			score_value = 700
			amplitude = 70.0
			fire_interval = 1.0
		"boss":
			sprite.texture = AssetDB.ship_textures["boss"]
			sprite.scale = Vector2.ONE * 0.32
			_configure_silhouette_collision(160.0)
			_configure_exhausts([
				{"position": Vector2(0, -168), "length": 108.0, "width": 30.0},
				{"position": Vector2(-44, -182), "length": 118.0, "width": 34.0},
				{"position": Vector2(44, -182), "length": 118.0, "width": 34.0},
				
			])
			health = 3800
			speed = 0.0
			score_value = 6000
			amplitude = 210.0
			fire_interval = 0.01
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
			health = 58
			speed = 325.0
			score_value = 320
			amplitude = 105.0
			fire_interval = 1.3
		"enemy4":
			sprite.texture = AssetDB.ship_textures["enemy4"]
			sprite.scale = Vector2.ONE * 0.82
			_configure_circle_collision(44.0)
			# Accurate from analysis: twin engines near top-center of png
			_configure_exhausts([
				{"position": Vector2(-5, -50), "length": 48.0, "width": 13.0},
				{"position": Vector2(8, -50), "length": 48.0, "width": 13.0}
			])
			health = 88
			speed = 285.0
			score_value = 500
			amplitude = 88.0
			fire_interval = 0.75
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
			health = 110
			speed = 225.0
			score_value = 660
			amplitude = 140.0
			fire_interval = 1.0
		"enemy6":
			sprite.texture = AssetDB.ship_textures["enemy6"]
			sprite.scale = Vector2.ONE * 0.71
			_configure_circle_collision(36.0)
			# Accurate: engines clustered at very top of tall sprite
			_configure_exhausts([
				{"position": Vector2(-6, -71), "length": 52.0, "width": 12.0},
				{"position": Vector2(8, -72), "length": 52.0, "width": 12.0}
			])
			health = 75
			speed = 370.0
			score_value = 520
			amplitude = 70.0
			fire_interval = 0.65
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
			health = 5200
			speed = 0.0
			score_value = 8200
			amplitude = 165.0
			fire_interval = 0.01
		_:
			sprite.texture = AssetDB.ship_textures["interceptor"]
			sprite.scale = Vector2.ONE * 0.9
			_configure_circle_collision(38.0)
			_configure_exhausts([
				{"position": Vector2(-36, -45), "length": 42.0, "width": 14.0},
				{"position": Vector2(36, -45), "length": 42.0, "width": 14.0}
			])
			health = 55
			speed = 335.0
			score_value = 300
			amplitude = 115.0
			fire_interval = 1.4
	_configure_boss_appearance()
	max_health = health
	fire_timer = randf_range(0.4, fire_interval)

func _physics_process(delta: float) -> void:
	_update_boss_appearance(delta)
	hit_strength = move_toward(hit_strength, 0.0, delta * 9.0)
	hit_material.set_shader_parameter("hit_amount", hit_strength)
	if entrance_remaining > 0.0:
		entrance_remaining = maxf(entrance_remaining - delta, 0.0)
		var progress := 1.0 - entrance_remaining / ENTRANCE_TIME
		position = Vector2(base_x, lerpf(-430.0, 280.0, smoothstep(0.0, 1.0, progress)))
		if entrance_remaining <= 0.0:
			set_deferred("monitoring", true)
			set_deferred("monitorable", true)
			fire_timer = 0.6
		return
	if is_boss:
		var target := Vector2(base_x + sin(Time.get_ticks_msec() * 0.0014) * amplitude, 280.0)
		if enemy_type == "boss3":
			var phase_speed := 2.0 + (1.0 - float(health) / max_health) * 0.7
			phase += delta * phase_speed
			target = Vector2(base_x + sin(phase) * amplitude, 280.0 + sin(phase * 0.5) * 35.0)
		position = position.lerp(target, 1.9 * delta)
	else:
		position.y += speed * delta
		position.x = base_x + sin(position.y * 0.011 + phase) * amplitude
		if position.y > VIEW_SIZE.y + 160.0:
			return_to_pool()
	if is_boss and charge_remaining >= 0.0:
		charge_remaining -= delta
		charge_visual.queue_redraw()
		if charge_remaining <= 0.0:
			charge_remaining = -1.0
			_fire_pattern()
			fire_timer = fire_interval
		return
	fire_timer -= delta
	if fire_timer <= 0.0:
		if is_boss:
			charge_remaining = CHARGE_TIME
			VFX.audio.play_sound("charge")
		else:
			_fire_pattern()
			fire_timer = fire_interval

func begin_entrance() -> void:
	entrance_remaining = ENTRANCE_TIME
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func _draw_charge() -> void:
	if not is_boss or charge_remaining < 0.0:
		return
	var amount := clampf(1.0 - charge_remaining / CHARGE_TIME, 0.0, 1.0)
	var muzzle := _muzzle_position()
	var color := Color(1.0, 0.68, 0.32, 0.35 + amount * 0.55)
	charge_visual.draw_arc(muzzle, lerpf(38.0, 14.0, amount), 0, TAU, 40, color, 2.0, true)
	charge_visual.draw_circle(muzzle, 4.0 + amount * 6.0, color)
	for wing in _charging_wing_muzzles():
		charge_visual.draw_arc(wing, lerpf(23.0, 7.0, amount), 0, TAU, 24, color, 1.5, true)
		charge_visual.draw_circle(wing, 2.0 + amount * 4.0, color)

func _fire_pattern() -> void:
	if enemy_type == "boss3":
		var origin := global_position + _muzzle_position()
		var directions: Array = []
		var furious := health < max_health * 0.55
		var critical := health < max_health * 0.25
		if volley_index % 2 == 1:
			var player: Node2D = get_parent().player
			var aim: Vector2 = (player.global_position - origin).normalized() if player else Vector2.DOWN
			for angle in [-24.0, -12.0, 0.0, 12.0, 24.0]:
				directions.append(aim.rotated(deg_to_rad(angle)))
		else:
			# Alternating fans leave a moving, readable gap; avoid a solid bullet wall.
			var gap := -24.0 if volley_index % 4 == 0 else 24.0
			for angle in [-72.0, -60.0, -48.0, -36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 36.0, 48.0, 60.0, 72.0]:
				if absf(angle - gap) > 12.0:
					directions.append(Vector2.DOWN.rotated(deg_to_rad(angle)))
		# Wing cannons add slower aimed pressure between the central volleys.
		if furious and volley_index % 2 == 0:
			var player: Node2D = get_parent().player
			for side in [-1.0, 1.0]:
				var wing_origin := global_position + Vector2(side * 165.0, 95.0)
				var aim: Vector2 = (player.global_position - wing_origin).normalized() if player else Vector2.DOWN
				VFX.muzzle_flash(wing_origin, aim, false)
				request_fire.emit(wing_origin, [aim], 360.0, 70)
		volley_index += 1
		fire_interval = 0.12 if critical else (0.22 if furious else 0.35)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		# PlayerShip applies its 0.1 incoming damage scale: these hit for 8 armor.
		request_fire.emit(origin, directions, 610.0 if critical else (560.0 if furious else 510.0), 25)
		return
	if enemy_type in ["lancer", "sentinel"]:
		var origin := global_position + _muzzle_position()
		var directions: Array = []
		if enemy_type == "lancer":
			var player: Node2D = get_parent().player
			directions = [(player.global_position - origin).normalized() if player else Vector2.DOWN]
		else:
			for angle in [-32.0, -16.0, 0.0, 16.0, 32.0]:
				directions.append(Vector2.DOWN.rotated(deg_to_rad(angle)))
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, directions, 500.0 if enemy_type == "lancer" else 350.0, 14)
		return
	if is_boss:
		var directions: Array = []
		var origin: Vector2
		var speed := 560.0
		var dmg := 20
		if enemy_type == "boss2":
			# Level2 boss: denser pattern but with a clear central safe gap (~30 degrees)
			# so the player has a place to dodge and hide between the volleys
			for angle in [-82.0, -62.0, -42.0, -25.0, -15.0, 15.0, 25.0, 42.0, 62.0, 82.0]:
				directions.append(Vector2.DOWN.rotated(deg_to_rad(angle)))
			origin = global_position + Vector2(0, 160)
			speed = 620.0
			dmg = 22
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
		request_fire.emit(origin, [Vector2.DOWN, Vector2(0.25, 1.0), Vector2(-0.25, 1.0)], 420.0, 14)
	elif enemy_type == "interceptor1":
		# Twin-spread shot: two slightly angled bolts for a more aggressive feel
		var origin := global_position + Vector2(0, 30)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2(-0.12, 1.0).normalized(), Vector2(0.12, 1.0).normalized()], 480.0, 13)
	elif enemy_type == "enemy4":
		# aggressive forward triple
		var origin := global_position + Vector2(0, 52)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2(-0.18, 1.0).normalized(), Vector2.DOWN, Vector2(0.18, 1.0).normalized()], 560.0, 14)
	elif enemy_type == "enemy5":
		# wide spread + slow heavy
		var origin := global_position + Vector2(0, 58)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2(-0.38, 1.0).normalized(), Vector2(-0.12, 1.0).normalized(), Vector2(0.12, 1.0).normalized(), Vector2(0.38, 1.0).normalized()], 370.0, 18)
	elif enemy_type == "enemy6":
		# rapid narrow double
		var origin := global_position + Vector2(0, 70)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2(-0.07, 1.0).normalized(), Vector2(0.07, 1.0).normalized()], 690.0, 13)
	else:
		var origin := global_position + Vector2(0, 48)
		VFX.muzzle_flash(origin, Vector2.DOWN, false)
		request_fire.emit(origin, [Vector2.DOWN], 500.0, 12)

func _muzzle_position() -> Vector2:
	if enemy_type in ["boss3", "lancer", "sentinel"]:
		return Vector2(0, sprite.texture.get_height() * sprite.scale.y * 0.42)
	return Vector2(0, 160 if enemy_type == "boss2" else 150)

func _on_area_entered(area: Area2D) -> void:
	if is_dead or entrance_remaining > 0.0 or not GameState.game_active or not area.visible:
		return
	# Direct ship-to-ship collision: enemy rams the player
	if area.has_method("_shoot"):
		var ram_damage := 40 if is_boss else 25
		GameState.damage_player(ram_damage)
		VFX.impact_spark(global_position, Vector2(0, 220), false)
		take_damage(150 if is_boss else health)
		return
	if area.has_method("is_player_damage") and area.is_player_damage():
		var damage: int = area.damage
		var impact_pos := area.global_position
		if area.has_method("spawn_impact"):
			area.spawn_impact(impact_pos)
		if area.has_method("return_to_pool"):
			area.return_to_pool()
		take_damage(damage)

func take_damage(amount: int) -> void:
	if is_dead or entrance_remaining > 0.0 or not GameState.game_active:
		return
	health = maxi(health - amount, 0)
	hit_strength = 0.65
	if is_boss:
		boss_damage_stage = _damage_stage()
		GameState.boss_health_changed.emit(health, max_health)
	if health <= 0:
		is_dead = true
		var death_position := global_position
		var death_was_boss := is_boss
		destroyed.emit(death_position, score_value, death_was_boss)
		if death_was_boss:
			boss_destroyed.emit(death_position)
		return_to_pool()

func return_to_pool() -> void:
	if pool != null:
		pool.release(self)

func on_pool_released() -> void:
	boss_damage_stage = 0
	boss_damage_blend = 0.0
	damage_effect.reset()
	charge_remaining = -1.0
	charge_visual.queue_redraw()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func _configure_circle_collision(radius: float) -> void:
	_clear_silhouette_collision()
	collision_shape.disabled = false
	(collision_shape.shape as CircleShape2D).radius = radius

func _configure_silhouette_collision(fallback_radius: float) -> void:
	_clear_silhouette_collision()
	(collision_shape.shape as CircleShape2D).radius = fallback_radius
	collision_shape.disabled = true
	var data: Resource = BOSS_COLLISIONS[enemy_type]
	for shape in data.shapes:
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.scale = sprite.scale
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

# Shared with the attack thresholds; visual changes never alter combat stats.
func _damage_stage() -> int:
	if not is_boss:
		return 0
	return 2 if health < max_health * 0.25 else (1 if health < max_health * 0.55 else 0)

func _charging_wing_muzzles() -> Array[Vector2]:
	if enemy_type == "boss3" and health < max_health * 0.55 and volley_index % 2 == 0:
		return [Vector2(-165, 95), Vector2(165, 95)]
	return []

func _configure_boss_appearance() -> void:
	boss_damage_stage = 0
	boss_damage_blend = 0.0
	damage_effect.reset()
	var sites := [Vector2(0.22, 0.12), Vector2(0.69, 0.31)]
	if enemy_type == "boss2":
		sites = [Vector2(0.32, 0.12), Vector2(0.66, 0.43)]
	elif enemy_type == "boss3":
		sites = [Vector2(0.38, 0.16), Vector2(0.69, 0.37)]
	var dimensions := sprite.texture.get_size() * sprite.scale
	damage_effect.sites = [(sites[0] - Vector2(0.5, 0.5)) * dimensions, (sites[1] - Vector2(0.5, 0.5)) * dimensions]

func _update_boss_appearance(delta: float) -> void:
	if not is_boss:
		return
	boss_damage_stage = _damage_stage()
	boss_damage_blend = move_toward(boss_damage_blend, float(boss_damage_stage), delta * 1.8)
	# Remap health so 60% has the former 35% appearance, with room to worsen.
	var ratio := pow(clampf(float(health) / max_health, 0.0, 1.0), 2.0551477366)
	# Health controls density, size and opacity continuously; ease heavy hits in.
	var smoke_target := smoothstep(0.0, 1.0, clampf((0.90 - ratio) / 0.85, 0.0, 1.0))
	var fire_target := smoothstep(0.0, 1.0, clampf((0.50 - ratio) / 0.45, 0.0, 1.0))
	damage_effect.smoke_strength = move_toward(damage_effect.smoke_strength, smoke_target, delta * 1.5)
	damage_effect.fire_strength = move_toward(damage_effect.fire_strength, fire_target, delta * 1.2)
	damage_effect.set_process(damage_effect.smoke_strength > 0.0 or not damage_effect.particles.is_empty())
