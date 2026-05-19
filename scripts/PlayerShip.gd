extends Area2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const ProjectileScript := preload("res://scripts/Projectile.gd")
const ExhaustPlumeScript := preload("res://scripts/ExhaustPlume.gd")
const VIEW_SIZE := Vector2(1920, 1080)
const MAX_BANK_ANGLE := deg_to_rad(10.0)
const BANK_RESPONSE := 10.0
const INCOMING_DAMAGE_SCALE := 0.1

var speed := 620.0
var shoot_cooldown := 0.11
var shoot_timer := 0.0
var bullet_pool: ObjectPool
var muzzle_offsets := [Vector2(-46, -104), Vector2(46, -104)]
var sprite: Sprite2D

# Touch/Android Controls
var is_android := false
var auto_shoot := false
var touch_indicator: Sprite2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 10
	monitoring = true
	monitorable = true

	sprite = Sprite2D.new()
	sprite.texture = AssetDB.ship_textures["player"]
	sprite.scale = Vector2.ONE * 0.55
	add_child(sprite)
	_add_exhaust(Vector2(-20, 74), 82.0, 24.0, 0.0)
	_add_exhaust(Vector2(20, 74), 82.0, 24.0, 0.0)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 58.0
	shape.shape = circle
	add_child(shape)

	bullet_pool = ObjectPool.new(_create_bullet, get_parent(), 80)
	area_entered.connect(_on_area_entered)

	is_android = OS.has_feature("android") or OS.get_name() == "Android" or DisplayServer.is_touchscreen_available()

	if is_android:
		touch_indicator = Sprite2D.new()
		touch_indicator.texture = load("res://assets/items/energy.png")
		touch_indicator.scale = Vector2.ONE * 0.55
		touch_indicator.modulate = Color(0.1, 0.7, 3.5, 0.0)
		touch_indicator.z_index = -1
		add_child(touch_indicator)

func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += input_vector * speed * delta
	position.x = clamp(position.x, 70.0, VIEW_SIZE.x - 70.0)
	position.y = clamp(position.y, 610.0, VIEW_SIZE.y - 95.0)

	if input_vector.x != 0.0 or not is_android:
		rotation = lerp_angle(rotation, input_vector.x * MAX_BANK_ANGLE, min(delta * BANK_RESPONSE, 1.0))

	shoot_timer = max(shoot_timer - delta, 0.0)
	var wants_to_shoot := Input.is_action_pressed("fire") or (is_android and auto_shoot)
	if wants_to_shoot and shoot_timer <= 0.0:
		_shoot()
		shoot_timer = shoot_cooldown

	# Update active automatic shooting halo indicator
	if is_android and touch_indicator:
		if auto_shoot:
			var pulse := 0.45 + sin(Time.get_ticks_msec() * 0.012) * 0.2
			touch_indicator.modulate = Color(0.1, 0.8, 4.0, pulse * 0.85)
			touch_indicator.rotation += delta * 1.6
			touch_indicator.scale = Vector2.ONE * (0.62 + pulse * 0.12)
		else:
			touch_indicator.modulate.a = move_toward(touch_indicator.modulate.a, 0.0, delta * 4.0)

func _input(event: InputEvent) -> void:
	if not is_android:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			var local_pos := to_local(event.position)
			# Touch tapping detection window within 95px around ship
			if local_pos.length() <= 95.0:
				auto_shoot = not auto_shoot
				_play_toggle_flash()

	elif event is InputEventScreenDrag:
		# Swiping/dragging moves the ship smoothly relative to touch drag
		position += event.relative
		position.x = clamp(position.x, 70.0, VIEW_SIZE.x - 70.0)
		position.y = clamp(position.y, 610.0, VIEW_SIZE.y - 95.0)

		# Custom drag bank rotation mapping based on touch drag direction
		var target_bank := clampf(event.relative.x * 0.18, -1.0, 1.0) * MAX_BANK_ANGLE
		rotation = lerp_angle(rotation, target_bank, 0.22)

func _play_toggle_flash() -> void:
	var flash := Sprite2D.new()
	flash.texture = sprite.texture
	flash.scale = sprite.scale
	flash.modulate = Color(2.0, 2.5, 5.0, 1.0)
	flash.z_index = 10
	add_child(flash)
	var tw := flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", sprite.scale * 1.6, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	flash.queue_free()

func _shoot() -> void:
	for offset in muzzle_offsets:
		var muzzle_pos: Vector2 = to_global(offset)
		VFX.muzzle_flash(muzzle_pos, Vector2.UP, true)
		var bullet := bullet_pool.acquire() as Area2D
		bullet.launch(muzzle_pos, Vector2.UP, 1120.0, 18, true)

func _create_bullet() -> Area2D:
	var bullet := ProjectileScript.new()
	bullet.name = "PlayerProjectile"
	return bullet

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
