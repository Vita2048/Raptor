extends Node2D

const VIEW_SIZE := Vector2(1920, 1080)
const TILE_SCALE := 2.0
const SCROLL_SPEED := 235.0

var sprites: Array[Sprite2D] = []
var tile_size := Vector2.ZERO
var rows := 0
var columns := 0

func _ready() -> void:
	z_index = -100
	var texture := AssetDB.random_ground_tile()
	tile_size = texture.get_size() * TILE_SCALE
	columns = int(ceil(VIEW_SIZE.x / tile_size.x)) + 2
	rows = int(ceil(VIEW_SIZE.y / tile_size.y)) + 3
	for row in range(rows):
		for col in range(columns):
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture = AssetDB.random_ground_tile()
			sprite.scale = Vector2.ONE * TILE_SCALE
			sprite.position = Vector2((col - 1) * tile_size.x, (row - 2) * tile_size.y)
			add_child(sprite)
			sprites.append(sprite)

func _process(delta: float) -> void:
	var bottom := VIEW_SIZE.y + tile_size.y
	for sprite in sprites:
		sprite.position.y += SCROLL_SPEED * delta
		if sprite.position.y > bottom:
			sprite.position.y -= rows * tile_size.y
			sprite.texture = AssetDB.random_ground_tile()
