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

func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += input_vector * speed * delta
	position.x = clamp(position.x, 70.0, VIEW_SIZE.x - 70.0)
	position.y = clamp(position.y, 610.0, VIEW_SIZE.y - 95.0)
	rotation = lerp_angle(rotation, input_vector.x * MAX_BANK_ANGLE, min(delta * BANK_RESPONSE, 1.0))
	shoot_timer = max(shoot_timer - delta, 0.0)
	if Input.is_action_pressed("fire") and shoot_timer <= 0.0:
		_shoot()
		shoot_timer = shoot_cooldown

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
