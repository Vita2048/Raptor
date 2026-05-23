extends Node

const BACKGROUND_DIR := "res://assets/background/"
const BUILDINGS_DIR := "res://assets/buildings/"
const SHIPS_DIR := "res://assets/ships/"
const PARTICLES_DIR := "res://assets/particles/"
const ITEMS_DIR := "res://assets/items/"

var background_textures: Array[Texture2D] = []
var desert_textures: Array[Texture2D] = []
var space_textures: Array[Texture2D] = []
var bridge_texture: Texture2D
var building_textures: Array[Texture2D] = []
var building_textures_by_name := {}
var spawn_area_defs: Array = []
var ship_textures := {}
var flash_textures: Array[Texture2D] = []
var explosion_textures: Array[Texture2D] = []
var white_puff_textures: Array[Texture2D] = []
var black_smoke_textures: Array[Texture2D] = []
var bomb_texture: Texture2D
var level2_building_textures: Array[Texture2D] = []

func _ready() -> void:
	load_all()

func load_all() -> void:
	desert_textures = _load_named_series(BACKGROUND_DIR, "desert_tile", 1, 5)
	space_textures = _load_named_series(BACKGROUND_DIR, "space_tile", 1, 2)
	bridge_texture = load(BACKGROUND_DIR + "dessert_bridges.png")
	background_textures = [bridge_texture]
	building_textures_by_name = {
		"Bunker": load(BUILDINGS_DIR + "Bunker.png"),
		"Factory": load(BUILDINGS_DIR + "Factory.png"),
		"Factory1": load(BUILDINGS_DIR + "Factory1.png"),
		"Radar": load(BUILDINGS_DIR + "Radar.png")
	}
	building_textures = [
		building_textures_by_name["Factory1"],
		building_textures_by_name["Bunker"],
		building_textures_by_name["Factory"],
		building_textures_by_name["Radar"]
	]
	level2_building_textures = [
		_safe_load_tex(BUILDINGS_DIR + "FuelTanks.png"),
		_safe_load_tex(BUILDINGS_DIR + "cannon.png"),
		_safe_load_tex(BUILDINGS_DIR + "Factory2.png"),
		_safe_load_tex(BUILDINGS_DIR + "Tank.png")
	]
	spawn_area_defs = _load_spawn_areas(BACKGROUND_DIR + "spawn_areas.xml")
	ship_textures = {
		"player": load(SHIPS_DIR + "PlayerShip.png"),
		"interceptor": load(SHIPS_DIR + "EnemyInterceptor.png"),
		"interceptor1": load(SHIPS_DIR + "EnemyInterceptor1.png"),
		"bomber": load(SHIPS_DIR + "Bomber.png"),
		"boss": load(SHIPS_DIR + "BossShip.png"),
		"enemy4": _safe_load_tex(SHIPS_DIR + "Enemy4.png"),
		"enemy5": _safe_load_tex(SHIPS_DIR + "Enemy5.png"),
		"enemy6": _safe_load_tex(SHIPS_DIR + "Enemy6.png"),
		"boss2": _safe_load_tex(SHIPS_DIR + "Bosship2.png")
	}
	bomb_texture = _safe_load_tex(ITEMS_DIR + "Bomb.png")
	black_smoke_textures = _load_zero_series(PARTICLES_DIR, "blackSmoke", 0, 24)
	explosion_textures = _load_zero_series(PARTICLES_DIR, "explosion", 0, 8)
	flash_textures = _load_zero_series(PARTICLES_DIR, "flash", 0, 8)
	white_puff_textures = _load_zero_series(PARTICLES_DIR, "whitePuff", 0, 24)

func random_background() -> Texture2D:
	return background_textures.pick_random()

func random_ground_tile() -> Texture2D:
	return bridge_texture

func random_building() -> Texture2D:
	return building_textures.pick_random()

func building_for_spawn_area(index: int) -> Texture2D:
	var buildings := get_buildings_for_level()
	if buildings.is_empty():
		return null
	return buildings[index % buildings.size()]

func get_buildings_for_level() -> Array[Texture2D]:
	if GameState != null and GameState.current_level >= 2:
		return level2_building_textures
	return building_textures

func switch_to_level(level: int) -> void:
	if level >= 2:
		building_textures = level2_building_textures
	else:
		building_textures = [
			building_textures_by_name.get("Factory1"),
			building_textures_by_name.get("Bunker"),
			building_textures_by_name.get("Factory"),
			building_textures_by_name.get("Radar")
		].filter(func(t): return t != null)

func random_particle(kind: String) -> Texture2D:
	match kind:
		"flash":
			return flash_textures.pick_random()
		"explosion":
			return explosion_textures.pick_random()
		"white_puff":
			return white_puff_textures.pick_random()
		"black_smoke":
			return black_smoke_textures.pick_random()
	return explosion_textures.pick_random()

func _load_named_series(dir_path: String, prefix: String, first: int, last: int) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for i in range(first, last + 1):
		textures.append(load("%s%s%d.png" % [dir_path, prefix, i]))
	return textures

func _load_zero_series(dir_path: String, prefix: String, first: int, last: int) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for i in range(first, last + 1):
		textures.append(load("%s%s%02d.png" % [dir_path, prefix, i]))
	return textures

func _load_spawn_areas(path: String) -> Array:
	var areas: Array = []
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		return areas
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT or parser.get_node_name() != "area":
			continue
		var title := ""
		var href := ""
		var coords_text := ""
		for i in range(parser.get_attribute_count()):
			var attr_name := parser.get_attribute_name(i)
			var attr_value := parser.get_attribute_value(i)
			if attr_name == "title":
				title = attr_value
			elif attr_name == "href":
				href = attr_value
			elif attr_name == "coords":
				coords_text = attr_value
		if coords_text.is_empty():
			continue
		var points := _coords_to_points(coords_text)
		if points.size() < 2:
			continue
		# The image-map file has stray polygon points in some entries; gameplay uses
		# the first two coordinate pairs as the intended rectangular spawn area.
		points = [points[0], points[1]]
		areas.append({
			"name": title if not title.is_empty() else href,
			"points": points,
			"is_rect": true,
			"rect": _points_to_rect(points)
		})
	return areas

func _coords_to_points(coords_text: String) -> Array[Vector2]:
	var values := coords_text.split(",", false)
	var points: Array[Vector2] = []
	for i in range(0, values.size() - 1, 2):
		points.append(Vector2(float(values[i]), float(values[i + 1])))
	return points

func _points_to_rect(points: Array[Vector2]) -> Rect2:
	var min_pos := points[0]
	var max_pos := points[0]
	for point in points:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.y = min(min_pos.y, point.y)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.y = max(max_pos.y, point.y)
	return Rect2(min_pos, max_pos - min_pos)

func _safe_load_tex(path: String) -> Texture2D:
	var res := load(path)
	if res != null:
		return res
	# Fallback for unimported PNGs: load raw and make ImageTexture
	var img := Image.new()
	if img.load(path) == OK:
		var tex := ImageTexture.new()
		tex.set_image(img)
		return tex
	push_warning("Failed to load texture at " + path)
	return null
