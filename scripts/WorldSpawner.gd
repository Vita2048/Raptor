extends Node2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const SceneryObjectScript := preload("res://scripts/SceneryObject.gd")
const VIEW_SIZE := Vector2(1920, 1080)
const WRAP_MARGIN := 360.0

var scenery_pool: ObjectPool
var scroll_source: Node
var image_scale := 1.0
var loop_height := 1.0
var scenery_entries: Array[Dictionary] = []
var random := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = -20
	random.randomize()
	scenery_pool = ObjectPool.new(_create_scenery, self, 8)
	image_scale = VIEW_SIZE.x / AssetDB.bridge_texture.get_width()
	loop_height = AssetDB.bridge_texture.get_height() * image_scale
	_build_fixed_scenery()

func _process(_delta: float) -> void:
	_update_fixed_scenery()

func _build_fixed_scenery() -> void:
	for area in AssetDB.spawn_area_defs:
		var rect: Rect2 = area["rect"]
		var scenery := scenery_pool.acquire() as Area2D
		var entry := {"scenery": scenery, "rect": rect,
			"local_pos": rect.get_center() * image_scale, "cycle": -1}
		scenery_entries.append(entry)
	_update_fixed_scenery()

func _dress_area(entry: Dictionary) -> void:
	var scenery = entry["scenery"]
	var candidates := AssetDB.get_buildings_for_level().duplicate()
	if candidates.size() > 1:
		candidates.erase(scenery.sprite.texture)
	var texture: Texture2D = candidates[random.randi_range(0, candidates.size() - 1)]
	var rect: Rect2 = entry["rect"]
	var available := rect.size.abs() * image_scale
	# Fit the full alpha bounds; never force small areas up to a minimum scale.
	var visual_scale := minf(available.x * 0.76 / texture.get_width(), available.y * 0.76 / texture.get_height())
	scenery.set_texture(texture)
	scenery.set_visual_scale(Vector2.ONE * visual_scale)
	scenery.rotation = 0.0
	scenery.reset_structure()

func _update_fixed_scenery() -> void:
	var distance: float = scroll_source.distance if scroll_source != null else 0.0
	for entry in scenery_entries:
		var scenery = entry["scenery"]
		var local_pos: Vector2 = entry["local_pos"]
		var unwrapped := local_pos.y + distance + WRAP_MARGIN
		var cycle := floori(unwrapped / loop_height)
		if cycle != entry["cycle"]:
			_dress_area(entry)
			entry["cycle"] = cycle
		var y := fposmod(unwrapped, loop_height) - WRAP_MARGIN
		scenery.position = Vector2(local_pos.x, y)
		scenery.visible = y > -WRAP_MARGIN and y < VIEW_SIZE.y + WRAP_MARGIN

func _create_scenery() -> Area2D:
	return SceneryObjectScript.new()

func rebuild_for_level(new_level: int) -> void:
	AssetDB.switch_to_level(new_level)
	# Preserve damage and craters on the visible terrain through sector transitions.
	if scenery_entries.is_empty():
		_build_fixed_scenery()
