extends Area2D

const VIEW_SIZE := Vector2(1920, 1080)
const SCROLL_SPEED := 235.0
const BOB_SPEED := 2.8
const BOB_AMP := 18.0

signal destroyed(pos: Vector2, by_shot: bool)

var sprite: Sprite2D
var collision_shape: CollisionShape2D
var time_alive := 0.0
var health := 22
var is_dead := false

func _ready() -> void:
	add_to_group("bombs")
	collision_layer = 2
	collision_mask = 5
	monitoring = true
	monitorable = true
	z_index = 60

	sprite = Sprite2D.new()
	sprite.texture = AssetDB.bomb_texture
	sprite.scale = Vector2.ONE * 0.58
	sprite.modulate = Color(1.15, 0.85, 0.7, 1.0)
	add_child(sprite)

	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 29.0
	collision_shape.shape = circle
	add_child(collision_shape)

	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if not GameState.game_active:
		queue_free()
		return
	if is_dead:
		return
	time_alive += delta
	global_position.y += SCROLL_SPEED * delta
	global_position.x += sin(time_alive * BOB_SPEED) * 8.0 * delta
	sprite.rotation = sin(time_alive * 3.4) * 0.18
	# warning pulse
	var p := 0.5 + sin(time_alive * 6.5) * 0.5
	sprite.modulate = Color(1.6 + p * 0.6, 0.6 - p * 0.2, 0.55 - p * 0.3, 1.0)
	if global_position.y > VIEW_SIZE.y + 140.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.has_method("is_player_damage") and area.is_player_damage():
		health -= area.damage
		if area.has_method("spawn_impact"):
			area.spawn_impact(global_position)
		if area.has_method("return_to_pool"):
			area.return_to_pool()
		if health <= 0:
			_die(true)
	elif area.has_method("_shoot"):
		_die(false)
		GameState.damage_player(32)

func _die(by_shot: bool) -> void:
	if is_dead:
		return
	is_dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var p := global_position
	destroyed.emit(p, by_shot)
	# explosion
	var exp := preload("res://scenes/ExplosionEffect.tscn").instantiate()
	exp.global_position = p
	exp.configure(false)
	get_parent().add_child(exp)
	exp.burst()
	queue_free()