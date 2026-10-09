extends Area2D

var sprite: Sprite2D
var shadow: Sprite2D
var shape: CollisionShape2D
var footprint := Vector2(100, 100)
var health := 90
var max_health := 90
var destroyed := false
var remains: Node2D
var hit_time := 0.0
var damage_indicator := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	monitoring = true
	monitorable = true
	shadow = Sprite2D.new()
	shadow.position = Vector2(-8, 13)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://shaders/shadow.gdshader")
	shadow.material = shadow_material
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var grade := ShaderMaterial.new()
	grade.shader = preload("res://shaders/terrain.gdshader")
	sprite.material = grade
	sprite.modulate = Color(0.94, 0.91, 0.85)
	add_child(sprite)
	shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	add_child(shape)
	area_entered.connect(_on_area_entered)

func set_texture(value: Texture2D) -> void:
	sprite.texture = value
	_update_shape()

func set_visual_scale(value: Vector2) -> void:
	sprite.scale = value
	_update_shape()

func _update_shape() -> void:
	if sprite == null or sprite.texture == null:
		return
	footprint = sprite.texture.get_size() * sprite.scale
	shadow.texture = sprite.texture
	shadow.scale = sprite.scale
	(shape.shape as RectangleShape2D).size = footprint * 0.7
	queue_redraw()

func _draw() -> void:
	if destroyed:
		return
	# Feathered dust around the foundations ties the sprite to the canyon floor.
	for layer in range(5):
		var points := PackedVector2Array()
		var extent := footprint * (0.53 + float(layer) * 0.016)
		for i in range(40):
			var angle := TAU * float(i) / 40.0
			var irregular := 1.0 + sin(angle * 7.0 + 0.8) * 0.035
			points.append(Vector2(cos(angle), sin(angle)) * extent * irregular)
		draw_colored_polygon(points, Color(0.49, 0.34, 0.21, 0.035))
	if damage_indicator > 0.0 and health < max_health:
		var at := Vector2(-24, footprint.y * 0.5 + 10)
		draw_rect(Rect2(at, Vector2(48, 3)), Color(0.08, 0.1, 0.11, 0.8))
		draw_rect(Rect2(at, Vector2(48.0 * health / max_health, 3)), Color(0.94, 0.67, 0.37, 0.9))

func _on_area_entered(area: Area2D) -> void:
	if destroyed or not GameState.game_active:
		return
	if area.visible and area.has_method("is_player_damage") and area.is_player_damage():
		var damage: int = area.damage
		if area.has_method("spawn_impact"):
			area.spawn_impact(global_position)
		if area.has_method("return_to_pool"):
			area.return_to_pool()
		take_damage(damage)

func reset_structure() -> void:
	if is_instance_valid(remains):
		remove_child(remains)
		remains.queue_free()
	max_health = int(sprite.texture.get_meta("health", 90))
	health = max_health
	destroyed = false
	hit_time = 0.0
	damage_indicator = 0.0
	sprite.show()
	shadow.show()
	sprite.modulate = Color(0.94, 0.91, 0.85)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	queue_redraw()

func _process(delta: float) -> void:
	if damage_indicator > 0.0:
		damage_indicator = maxf(damage_indicator - delta, 0.0)
		queue_redraw()
	if hit_time > 0.0:
		hit_time = maxf(hit_time - delta, 0.0)
		sprite.modulate = Color(0.94, 0.91, 0.85).lerp(Color(1.8, 1.5, 1.1), hit_time / 0.12)

func take_damage(amount: int) -> void:
	if destroyed or not GameState.game_active:
		return
	health = maxi(health - amount, 0)
	hit_time = 0.12
	damage_indicator = 1.5
	if health > 0:
		return
	destroyed = true
	sprite.hide()
	shadow.hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	GameState.add_score(int(sprite.texture.get_meta("score", 350)))
	GameState.record_kill("structure")
	queue_redraw()
	call_deferred("_create_remains")

func _create_remains() -> void:
	if not destroyed:
		return
	remains = preload("res://scripts/GroundRemains.gd").new()
	add_child(remains)
	remains.configure(footprint)

func on_pool_acquired() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func on_pool_released() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
