extends Area2D

var sprite: Sprite2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	monitoring = true
	monitorable = true

	sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 120)
	shape.shape = rect
	add_child(shape)
	area_entered.connect(_on_area_entered)

func set_texture(value: Texture2D) -> void:
	sprite.texture = value
	_update_shape()

func set_visual_scale(value: Vector2) -> void:
	sprite.scale = value
	_update_shape()

func _update_shape() -> void:
	if sprite == null or sprite.texture == null or get_child_count() < 2:
		return
	var shape := get_child(1) as CollisionShape2D
	var rect := shape.shape as RectangleShape2D
	rect.size = sprite.texture.get_size() * sprite.scale * 0.72

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("is_player_damage") and area.is_player_damage():
		if area.has_method("spawn_impact"):
			area.spawn_impact(global_position)
		if area.has_method("return_to_pool"):
			area.return_to_pool()

func on_pool_acquired() -> void:
	monitoring = true
	monitorable = true

func on_pool_released() -> void:
	monitoring = false
	monitorable = false
