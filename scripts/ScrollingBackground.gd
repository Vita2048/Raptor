extends Node2D

const VIEW_SIZE := Vector2(1920, 1080)
const SCROLL_SPEED := 235.0

var sprites: Array[Sprite2D] = []
var scroll_offset := 0.0
var image_scale := 1.0
var loop_height := 1.0

func _ready() -> void:
	z_index = -100
	var texture := AssetDB.bridge_texture
	image_scale = VIEW_SIZE.x / texture.get_width()
	loop_height = texture.get_height() * image_scale
	for i in range(2):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture
		sprite.scale = Vector2.ONE * image_scale
		add_child(sprite)
		sprites.append(sprite)
	_update_sprite_positions()

func _process(delta: float) -> void:
	scroll_offset = fposmod(scroll_offset + SCROLL_SPEED * delta, loop_height)
	_update_sprite_positions()

func _update_sprite_positions() -> void:
	if sprites.size() < 2:
		return
	var first_y := scroll_offset - loop_height
	sprites[0].position = Vector2.ZERO + Vector2(0.0, first_y)
	sprites[1].position = Vector2.ZERO + Vector2(0.0, first_y + loop_height)
