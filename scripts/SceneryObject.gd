extends Area2D

var sprite: Sprite2D
var shadow: Sprite2D
var shape: CollisionShape2D
var footprint := Vector2(100, 100)

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
	# Feathered dust around the foundations ties the sprite to the canyon floor.
	for layer in range(5):
		var points := PackedVector2Array()
		var extent := footprint * (0.53 + float(layer) * 0.016)
		for i in range(40):
			var angle := TAU * float(i) / 40.0
			var irregular := 1.0 + sin(angle * 7.0 + 0.8) * 0.035
			points.append(Vector2(cos(angle), sin(angle)) * extent * irregular)
		draw_colored_polygon(points, Color(0.49, 0.34, 0.21, 0.035))

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("is_player_damage") and area.is_player_damage():
		if area.has_method("spawn_impact"):
			area.spawn_impact(global_position)
		if area.has_method("return_to_pool"):
			area.return_to_pool()

func on_pool_acquired() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func on_pool_released() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
