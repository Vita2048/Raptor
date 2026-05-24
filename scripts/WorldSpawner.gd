extends Node2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const SceneryObjectScript := preload("res://scripts/SceneryObject.gd")
const VIEW_SIZE := Vector2(1920, 1080)

var scenery_pool: ObjectPool
var scroll_source: Node
var image_scale := 1.0
var loop_height := 1.0
var scenery_entries: Array[Dictionary] = []

func _ready() -> void:
	z_index = -20
	scenery_pool = ObjectPool.new(_create_scenery, self, 12)
	if AssetDB.bridge_texture != null:
		image_scale = VIEW_SIZE.x / AssetDB.bridge_texture.get_width()
		loop_height = AssetDB.bridge_texture.get_height() * image_scale
	_build_fixed_scenery()

func _process(delta: float) -> void:
	_update_fixed_scenery()

func _build_fixed_scenery() -> void:
	scenery_entries.clear()
	var num_areas := AssetDB.spawn_area_defs.size()
	var area_textures: Array[Texture2D] = []
	for i in range(num_areas):
		area_textures.append(AssetDB.building_for_spawn_area(i))
	for copy_index in range(2):
		for area_index in range(num_areas):
			var texture := area_textures[area_index]
			if texture == null:
				continue
			var area = AssetDB.spawn_area_defs[area_index]
			var scenery := scenery_pool.acquire() as Area2D
			var rect: Rect2 = area["rect"]
			var rect_size := rect.size.abs() * image_scale
			var fit_x: float = rect_size.x * 0.68 / texture.get_width()
			var fit_y: float = rect_size.y * 0.68 / texture.get_height()
			var scale_value: float = clamp(min(fit_x, fit_y), 0.32, 0.92)
			if texture == AssetDB.tank_texture or texture == AssetDB.radar_texture:
				scale_value *= 0.5
			scenery.set_texture(texture)
			scenery.set_visual_scale(Vector2.ONE * scale_value)
			scenery.rotation_degrees = 0.0
			scenery.modulate = Color.WHITE
			scenery_entries.append({
				"scenery": scenery,
				"copy_index": copy_index,
				"local_pos": (rect.position + rect.size * 0.5) * image_scale
			})
	_update_fixed_scenery()

func _update_fixed_scenery() -> void:
	var scroll_offset := _current_scroll_offset()
	for entry in scenery_entries:
		var scenery := entry["scenery"] as Area2D
		var copy_index := entry["copy_index"] as int
		var local_pos := entry["local_pos"] as Vector2
		var top_y := scroll_offset - loop_height + copy_index * loop_height
		scenery.position = Vector2(local_pos.x, top_y + local_pos.y)
		scenery.visible = scenery.position.y > -360.0 and scenery.position.y < VIEW_SIZE.y + 360.0

func _current_scroll_offset() -> float:
	if scroll_source != null:
		return scroll_source.scroll_offset
	return 0.0

func _create_scenery() -> Area2D:
	var scenery := SceneryObjectScript.new()
	scenery.name = "PooledScenery"
	return scenery

func rebuild_for_level(new_level: int) -> void:
	for entry in scenery_entries:
		var sc := entry["scenery"] as Area2D
		if is_instance_valid(sc):
			scenery_pool.release(sc)
	scenery_entries.clear()
	AssetDB.switch_to_level(new_level)
	_build_fixed_scenery()
