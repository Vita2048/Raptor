extends Sprite2D

var pool

func _ready() -> void:
	centered = true
	z_index = 120
	visible = false

func set_pool(value) -> void:
	pool = value

func play_at(pos: Vector2, angle: float, tint: Color) -> void:
	global_position = pos
	rotation = angle
	texture = AssetDB.flash_textures[randi_range(0, min(4, AssetDB.flash_textures.size() - 1))]
	modulate = tint
	scale = Vector2.ONE * 0.055
	visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 0.138, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.05)
	await tween.finished
	if pool != null:
		pool.release(self)

func on_pool_released() -> void:
	modulate = Color.WHITE
	visible = false
