extends Area2D

const VIEW_SIZE := Vector2(1920, 1080)
const ARMOR_RESTORE := 25
const FLOAT_SPEED := 1.8
const FLOAT_AMPLITUDE := 14.0
const DESCENT_SPEED := 95.0
const GLOW_CYCLE := 2.2

var sprite: Sprite2D
var glow_sprite: Sprite2D
var collision_shape: CollisionShape2D
var light: PointLight2D
var spawn_y: float = 0.0
var time_alive: float = 0.0
var picked_up: bool = false

func _ready() -> void:
	collision_layer = 4   # item layer
	collision_mask = 1    # detect player (layer 1)
	monitoring = true
	monitorable = false
	z_index = 80

	# --- glow backdrop sprite (larger, blurred look via colour) ---
	glow_sprite = Sprite2D.new()
	glow_sprite.texture = load("res://assets/items/energy.png")
	glow_sprite.scale = Vector2.ONE * 0.68
	glow_sprite.modulate = Color(0.25, 0.75, 3.5, 0.38)
	glow_sprite.z_index = -1
	add_child(glow_sprite)

	# --- main sprite ---
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/items/energy.png")
	sprite.scale = Vector2.ONE * 0.44
	sprite.modulate = Color(0.7, 2.0, 4.0, 1.0)
	add_child(sprite)

	# --- point light for real glow ---
	light = PointLight2D.new()
	light.texture = _make_radial_gradient_texture(128)
	light.energy = 1.85
	light.color = Color(0.18, 0.55, 1.0)
	light.texture_scale = 3.2
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)

	# --- collision ---
	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	collision_shape.shape = circle
	add_child(collision_shape)

	area_entered.connect(_on_area_entered)
	spawn_y = global_position.y

func _process(delta: float) -> void:
	if picked_up:
		return
	time_alive += delta

	# Float down slowly with sine wave side-bob
	global_position.y += DESCENT_SPEED * delta
	global_position.x += sin(time_alive * FLOAT_SPEED * 0.7) * 22.0 * delta

	# Vertical sine oscillation (bob up/down around descent path)
	sprite.position.y = sin(time_alive * FLOAT_SPEED) * FLOAT_AMPLITUDE
	glow_sprite.position.y = sprite.position.y

	# Pulse glow
	var pulse := 0.55 + sin(time_alive * (TAU / GLOW_CYCLE)) * 0.45
	light.energy = 1.2 + pulse * 1.4
	glow_sprite.modulate.a = 0.22 + pulse * 0.32
	sprite.modulate = Color(0.55 + pulse * 0.4, 1.6 + pulse * 0.8, 3.5 + pulse * 0.8, 1.0)

	# Gentle rotation
	sprite.rotation += delta * 1.1
	glow_sprite.rotation -= delta * 0.6

	# Self-destroy if it scrolls off screen
	if global_position.y > VIEW_SIZE.y + 120.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if picked_up:
		return
	# Player has method _shoot (used elsewhere as the player identity check)
	if area.has_method("_shoot"):
		_do_pickup(area)

func _do_pickup(player: Area2D) -> void:
	picked_up = true
	set_deferred("monitoring", false)

	# Restore armour
	GameState.heal_player(ARMOR_RESTORE)

	# Pickup flash burst
	_play_pickup_burst(player.global_position)
	queue_free()

func _play_pickup_burst(pos: Vector2) -> void:
	# Expanding ring of blue light
	var ring := Sprite2D.new()
	ring.texture = sprite.texture
	ring.top_level = true
	ring.global_position = pos
	ring.scale = Vector2.ONE * 0.44
	ring.modulate = Color(0.4, 1.4, 4.5, 1.0)
	ring.z_index = 200
	get_parent().add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	ring.queue_free()

# Build a simple white radial gradient texture for the PointLight2D
func _make_radial_gradient_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x, y).distance_to(centre) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.6)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
