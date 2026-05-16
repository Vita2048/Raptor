extends Node2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const VIEW_SIZE := Vector2(1920, 1080)
const SCROLL_SPEED := 235.0
const CHUNK_HEIGHT := 270.0
const GRID_COLUMNS := 6

var scenery_pool: ObjectPool
var next_chunk_y := -CHUNK_HEIGHT

func _ready() -> void:
	z_index = -20
	scenery_pool = ObjectPool.new(_create_scenery, self, 24)
	for i in range(7):
		_spawn_chunk(next_chunk_y + i * CHUNK_HEIGHT)
	next_chunk_y += 7 * CHUNK_HEIGHT

func _process(delta: float) -> void:
	for node in scenery_pool.active.duplicate():
		node.position.y += SCROLL_SPEED * delta
		if node.position.y > VIEW_SIZE.y + 220.0:
			scenery_pool.release(node)
	var highest := _highest_active_y()
	while highest > -CHUNK_HEIGHT:
		_spawn_chunk(highest - CHUNK_HEIGHT)
		highest -= CHUNK_HEIGHT

func _spawn_chunk(y_pos: float) -> void:
	var lanes := range(GRID_COLUMNS)
	var count := randi_range(1, 3)
	for i in range(count):
		if lanes.is_empty():
			return
		var lane_index := randi_range(0, lanes.size() - 1)
		var lane = lanes[lane_index]
		lanes.remove_at(lane_index)
		if randf() < 0.42:
			continue
		var sprite := scenery_pool.acquire() as Sprite2D
		sprite.texture = AssetDB.random_building()
		sprite.scale = Vector2.ONE * randf_range(0.82, 1.12)
		sprite.rotation_degrees = randf_range(-4.0, 4.0)
		var cell_width := VIEW_SIZE.x / GRID_COLUMNS
		sprite.position = Vector2(cell_width * lane + cell_width * 0.5 + randf_range(-70.0, 70.0), y_pos + randf_range(45.0, CHUNK_HEIGHT - 45.0))

func _highest_active_y() -> float:
	var top := VIEW_SIZE.y
	for node in scenery_pool.active:
		top = min(top, node.position.y)
	return top

func _create_scenery() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture = AssetDB.random_building()
	return sprite
