extends Node2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const VIEW_SIZE := Vector2(1920, 1080)
const SCROLL_SPEED := 235.0

var scenery_pool: ObjectPool
var scroll_offset := 0.0
var image_scale := 1.0
var loop_height := 1.0
var spawned_entries := {}
var slot_rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = -20
	slot_rng.randomize()
	scenery_pool = ObjectPool.new(_create_scenery, self, 12)
	if AssetDB.bridge_texture != null:
		image_scale = VIEW_SIZE.x / AssetDB.bridge_texture.get_width()
		loop_height = AssetDB.bridge_texture.get_height() * image_scale
	_refresh_spawned_scenery()

func _process(delta: float) -> void:
	scroll_offset = fposmod(scroll_offset + SCROLL_SPEED * delta, loop_height)
	_refresh_spawned_scenery()

func _refresh_spawned_scenery() -> void:
	var live_keys := {}
	for copy_index in range(2):
		var top_y := scroll_offset - loop_height + copy_index * loop_height
		for area_index in range(AssetDB.spawn_area_defs.size()):
			var area = AssetDB.spawn_area_defs[area_index]
			var rect: Rect2 = area["rect"]
			var key := "%d:%d" % [copy_index, area_index]
			var center := (rect.position + rect.size * 0.5) * image_scale
			var screen_pos := Vector2(center.x, top_y + center.y)
			if screen_pos.y < -260.0 or screen_pos.y > VIEW_SIZE.y + 260.0:
				continue
			live_keys[key] = true
			if not spawned_entries.has(key):
				_spawn_area_asset(key, area_index, rect)
			_update_area_asset(key, top_y)

	for key in spawned_entries.keys():
		if live_keys.has(key):
			continue
		var entry: Dictionary = spawned_entries[key]
		var sprite := entry["sprite"] as Sprite2D
		scenery_pool.release(sprite)
		spawned_entries.erase(key)

func _spawn_area_asset(key: String, area_index: int, rect: Rect2) -> void:
	var sprite := scenery_pool.acquire() as Sprite2D
	sprite.texture = AssetDB.building_for_spawn_area(area_index)
	sprite.rotation_degrees = 0.0
	sprite.modulate = Color.WHITE
	var rect_min := rect.position * image_scale
	var rect_size := rect.size * image_scale
	var local_pos := Vector2(
		slot_rng.randf_range(rect_min.x + rect_size.x * 0.28, rect_min.x + rect_size.x * 0.72),
		slot_rng.randf_range(rect_min.y + rect_size.y * 0.28, rect_min.y + rect_size.y * 0.72)
	)
	var target_width: float = min(rect_size.x * 0.58, sprite.texture.get_width() * 1.25)
	var scale_value: float = clamp(target_width / sprite.texture.get_width(), 0.58, 1.35)
	sprite.scale = Vector2.ONE * scale_value
	spawned_entries[key] = {
		"sprite": sprite,
		"local_pos": local_pos
	}

func _update_area_asset(key: String, top_y: float) -> void:
	var entry: Dictionary = spawned_entries[key]
	var sprite := entry["sprite"] as Sprite2D
	var local_pos := entry["local_pos"] as Vector2
	sprite.position = Vector2(local_pos.x, top_y + local_pos.y)

func _create_scenery() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture = AssetDB.random_building()
	return sprite
