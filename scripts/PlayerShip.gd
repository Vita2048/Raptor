extends Area2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const ProjectileScript := preload("res://scripts/Projectile.gd")
const ExhaustPlumeScript := preload("res://scripts/ExhaustPlume.gd")
const VIEW_SIZE := Vector2(1920, 1080)
const MAX_BANK_ANGLE := deg_to_rad(10.0)
const BANK_RESPONSE := 10.0
const INCOMING_DAMAGE_SCALE := 0.1
const GRAZE_ARM_RADIUS := 140.0
const GRAZE_RELEASE_RADIUS := 155.0
const GRAZE_SCORE := 10

var speed := 620.0
var shoot_cooldown := 0.11
var shoot_timer := 0.0
var bullet_pool: ObjectPool
var enemy_manager: Node = null
var muzzle_offsets := [Vector2(-46, -104), Vector2(46, -104)]
var sprite: Sprite2D
var hit_material: ShaderMaterial
var hit_strength := 0.0
var previous_health := 100

# Touch controls (phones/tablets; also desktops with a touchscreen).
var is_touch := false
var force_touch := false  # headless-test hook: exercise touch paths on desktop
var touch_indicator: Sprite2D
# Fingers currently held down; the ship fires while at least one is held.
var _touches := 0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 10
	monitoring = true
	monitorable = true

	sprite = Sprite2D.new()
	sprite.texture = AssetDB.ship_textures["player"]
	sprite.scale = Vector2.ONE * 0.55
	add_child(sprite)
	var shadow := preload("res://scripts/AircraftShadow.gd").new()
	shadow.source = sprite
	add_child(shadow)
	hit_material = ShaderMaterial.new()
	hit_material.shader = preload("res://shaders/ship_hit.gdshader")
	sprite.material = hit_material
	previous_health = GameState.player_health
	GameState.player_health_changed.connect(_on_health_feedback)
	_add_exhaust(Vector2(-20, 74), 82.0, 24.0, 0.0)
	_add_exhaust(Vector2(20, 74), 82.0, 24.0, 0.0)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 58.0
	shape.shape = circle
	add_child(shape)

	bullet_pool = ObjectPool.new(_create_bullet, get_parent(), 80)
	area_entered.connect(_on_area_entered)

	is_touch = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

	if is_touch:
		touch_indicator = Sprite2D.new()
		touch_indicator.texture = load("res://assets/items/energy.png")
		touch_indicator.scale = Vector2.ONE * 0.55
		touch_indicator.modulate = Color(0.1, 0.7, 3.5, 0.0)
		touch_indicator.z_index = -1
		add_child(touch_indicator)

func _physics_process(delta: float) -> void:
	hit_strength = move_toward(hit_strength, 0.0, delta * 6.0)
	hit_material.set_shader_parameter("hit_amount", hit_strength)
	sprite.position.y = move_toward(sprite.position.y, 0.0, delta * 38.0)
	if not GameState.game_active:
		_touches = 0
		return
	_update_graze()
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += input_vector * speed * delta
	position.x = clamp(position.x, 70.0, VIEW_SIZE.x - 70.0)
	position.y = clamp(position.y, 610.0, VIEW_SIZE.y - 95.0)

	if input_vector.x != 0.0 or not is_touch:
		rotation = lerp_angle(rotation, input_vector.x * MAX_BANK_ANGLE, min(delta * BANK_RESPONSE, 1.0))

	shoot_timer = max(shoot_timer - delta, 0.0)
	var wants_to_shoot := Input.is_action_pressed("fire") or ((is_touch or force_touch) and _touches > 0)
	if wants_to_shoot and shoot_timer <= 0.0:
		_shoot()
		shoot_timer = shoot_cooldown

	# Firing halo while any finger is held down.
	if (is_touch or force_touch) and touch_indicator:
		if _touches > 0:
			var pulse := 0.45 + sin(Time.get_ticks_msec() * 0.012) * 0.2
			touch_indicator.modulate = Color(0.1, 0.8, 4.0, pulse * 0.85)
			touch_indicator.rotation += delta * 1.6
			touch_indicator.scale = Vector2.ONE * (0.62 + pulse * 0.12)
		else:
			touch_indicator.modulate.a = move_toward(touch_indicator.modulate.a, 0.0, delta * 4.0)

func _update_graze() -> void:
	# Close-dodge bonus: an enemy bullet that enters the graze shell and leaves
	# without hitting scores once. Hits never pay: pooling resets the flag.
	if enemy_manager == null or not is_instance_valid(enemy_manager):
		enemy_manager = get_parent().get_node_or_null("EnemyManager")
		if enemy_manager == null:
			return
	var pool = enemy_manager.enemy_bullet_pool
	if pool == null:
		return
	for bullet in pool.active:
		if not is_instance_valid(bullet) or bullet.from_player:
			continue
		var dist: float = bullet.global_position.distance_to(global_position)
		if dist < GRAZE_ARM_RADIUS:
			bullet.graze_armed = true
		elif bullet.graze_armed and dist > GRAZE_RELEASE_RADIUS:
			bullet.graze_armed = false
			GameState.record_graze(GRAZE_SCORE)

func _drag_to_canvas(relative: Vector2) -> Vector2:
	# Drag deltas are viewport pixels too; only the stretch scale applies.
	var s := get_viewport().get_canvas_transform().x.length()
	if s <= 0.0:
		return relative
	return relative / s

func reset_touch() -> void:
	# Called when the pause menu opens/closes: releases missed while paused
	# never arrive, so the count is re-anchored to avoid stuck firing.
	_touches = 0

func _input(event: InputEvent) -> void:
	if not (is_touch or force_touch):
		return
	if not GameState.game_active:
		_touches = 0
		return

	if event is InputEventScreenTouch:
		# The ship fires as long as any finger is held down (multi-touch safe).
		if event.pressed:
			_touches += 1
		else:
			_touches = maxi(0, _touches - 1)

	elif event is InputEventScreenDrag:
		# Swiping/dragging moves the ship smoothly relative to touch drag
		position += _drag_to_canvas(event.relative)
		position.x = clamp(position.x, 70.0, VIEW_SIZE.x - 70.0)
		position.y = clamp(position.y, 610.0, VIEW_SIZE.y - 95.0)

		# Custom drag bank rotation mapping based on touch drag direction
		var target_bank := clampf(event.relative.x * 0.18, -1.0, 1.0) * MAX_BANK_ANGLE
		rotation = lerp_angle(rotation, target_bank, 0.22)

func _shoot() -> void:
	sprite.position.y = 2.5
	VFX.audio.play_sound("shot")
	var lvl := GameState.current_level
	if lvl >= 2:
		# Level 2: triple spread shot, slightly slower but wider coverage
		var offsets: Array[Vector2] = [Vector2(-38, -100), Vector2(0, -112), Vector2(38, -100)]
		for i in range(3):
			var off: Vector2 = offsets[i]
			var muzzle_pos: Vector2 = to_global(off)
			VFX.muzzle_flash(muzzle_pos, Vector2.UP, true)
			var dir := Vector2((i - 1) * 0.26, -1.0).normalized()
			var bullet := bullet_pool.acquire() as Area2D
			bullet.launch(muzzle_pos, dir, 980.0, 16, true)
	else:
		for offset in muzzle_offsets:
			var muzzle_pos: Vector2 = to_global(offset)
			VFX.muzzle_flash(muzzle_pos, Vector2.UP, true)
			var bullet := bullet_pool.acquire() as Area2D
			bullet.launch(muzzle_pos, Vector2.UP, 1120.0, 18, true)

func _create_bullet() -> Area2D:
	var bullet := ProjectileScript.new()
	bullet.name = "PlayerProjectile"
	return bullet

func _on_health_feedback(value: int, _maximum: int) -> void:
	if value < previous_health:
		hit_strength = 0.8
		VFX.audio.play_sound("damage")
		VFX.camera_impulse.emit(3.0)
	previous_health = value

func _add_exhaust(local_position: Vector2, length: float, width: float, angle: float) -> void:
	var exhaust := ExhaustPlumeScript.new()
	exhaust.position = local_position
	exhaust.configure(length, width, angle)
	add_child(exhaust)

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("is_enemy_damage") and area.is_enemy_damage():
		var reduced_damage: int = max(1, roundi(float(area.damage) * INCOMING_DAMAGE_SCALE))
		GameState.damage_player(reduced_damage)
		if area.has_method("spawn_impact"):
			area.spawn_impact(global_position)
		if area.has_method("return_to_pool"):
			area.return_to_pool()
