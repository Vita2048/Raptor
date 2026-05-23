extends Node2D

const VIEW_SIZE := Vector2(1920, 1080)
const TILE_SIZE := 64
const SCROLL_SPEED := 235.0
const MAP_HEIGHT_TILES := 128

const SOURCE_GROUND := 1
const SOURCE_WATER := 2
const SOURCE_OBJECTS := 3

const GRASS_TILES: Array[Vector2i] = [
	Vector2i(4, 2),
	Vector2i(3, 6)
]
const SOFT_GROUND_TILES: Array[Vector2i] = [
	Vector2i(4, 2)
]
const STONE_TILES: Array[Vector2i] = [
	Vector2i(3, 4),
	Vector2i(4, 4)
]
const WATER_TILES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1)
]
const OBJECT_TILES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(3, 0),
	Vector2i(4, 0),
	Vector2i(5, 0),
	Vector2i(6, 0),
	Vector2i(3, 1),
	Vector2i(4, 1),
	Vector2i(5, 1),
	Vector2i(6, 1)
]

const SHORE_LEFT := Vector2i(6, 4)

@export var base_seed := 4127

var scroll_offset := 0.0
var image_scale := 1.0
var loop_height := 1.0
var level_seed := 1

var map_width_tiles := 32
var map_height_tiles := MAP_HEIGHT_TILES
var tile_set: TileSet
var chunks: Array[Node2D] = []
var terrain_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var object_noise: FastNoiseLite

func _ready() -> void:
	z_index = -100
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	map_width_tiles = int(ceil(VIEW_SIZE.x / float(TILE_SIZE))) + 4
	map_height_tiles = MAP_HEIGHT_TILES
	loop_height = float(map_height_tiles * TILE_SIZE)
	tile_set = _create_grassland_tile_set()
	rebuild_for_level(GameState.current_level if GameState != null else 1)

func _process(delta: float) -> void:
	scroll_offset = fposmod(scroll_offset + SCROLL_SPEED * delta, loop_height)
	_update_chunk_positions()

func rebuild_for_level(new_level: int) -> void:
	level_seed = _seed_for_level(new_level)
	_create_noises(level_seed)
	_clear_chunks()

	var template := _create_chunk()
	chunks.append(template)
	add_child(template)

	for i in range(1, 3):
		var copy := template.duplicate()
		copy.name = "LoopedGrasslandChunk%d" % i
		chunks.append(copy)
		add_child(copy)

	_update_chunk_positions()

func set_generation_seed(seed_value: int, level := 1) -> void:
	base_seed = seed_value
	rebuild_for_level(level)

func _create_chunk() -> Node2D:
	var chunk := Node2D.new()
	chunk.name = "LoopedGrasslandChunk0"
	chunk.position.x = (VIEW_SIZE.x - float(map_width_tiles * TILE_SIZE)) * 0.5

	var base := _new_layer("GrasslandTerrain", 0)
	var water := _new_layer("WaterAndShallows", 1)
	var shore := _new_layer("SoftRiverBanks", 2)
	var objects := _new_layer("TreesRocksFlowers", 3)
	chunk.add_child(base)
	chunk.add_child(water)
	chunk.add_child(shore)
	chunk.add_child(objects)

	_generate_loopable_landscape(base, water, shore, objects)
	return chunk

func _new_layer(layer_name: String, layer_z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = layer_z
	layer.rendering_quadrant_size = 32
	layer.collision_enabled = false
	layer.navigation_enabled = false
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return layer

func _generate_loopable_landscape(base: TileMapLayer, water: TileMapLayer, shore: TileMapLayer, objects: TileMapLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	var river_offset := int(rng.randi_range(-3, 3))
	var seam_river_center := int(round(float(map_width_tiles) * 0.52 + float(river_offset)))
	var seam_river_half_width := 3

	for y in range(map_height_tiles):
		var seam_band := y < 4 or y >= map_height_tiles - 4
		var phase := TAU * float(y) / float(map_height_tiles)
		var river_center := int(round(float(map_width_tiles) * 0.52 + float(river_offset) + sin(phase * 2.0 + 0.7) * 4.2 + sin(phase * 5.0 + 1.9) * 1.7))
		var river_half_width := 3 + int(round((sin(phase * 3.0 + 2.1) + 1.0) * 0.55))
		if seam_band:
			river_center = seam_river_center
			river_half_width = seam_river_half_width
		var left_bank: int = river_center - river_half_width
		var right_bank: int = river_center + river_half_width

		for x in range(map_width_tiles):
			var cell := Vector2i(x, y)
			_paint_ground_variation(base, cell, phase, 999, river_half_width, seam_band)
			var dist_to_river: int = absi(x - river_center)
			if dist_to_river <= river_half_width:
				var water_coord: Vector2i = WATER_TILES[x % WATER_TILES.size()]
				if not seam_band:
					water_coord = WATER_TILES[(x + y) % WATER_TILES.size()]
				water.set_cell(cell, SOURCE_WATER, water_coord)
				if x == left_bank:
					shore.set_cell(cell, SOURCE_GROUND, SHORE_LEFT)
				elif x == right_bank:
					shore.set_cell(cell, SOURCE_GROUND, SHORE_LEFT, TileSetAtlasSource.TRANSFORM_FLIP_H)
				continue

			_paint_ground_variation(base, cell, phase, dist_to_river, river_half_width, seam_band)
			_paint_objects(objects, cell, rng, phase, dist_to_river, river_half_width, seam_band)

func _paint_ground_variation(base: TileMapLayer, cell: Vector2i, phase: float, dist_to_river: int, river_half_width: int, seam_band: bool) -> void:
	if seam_band:
		base.set_cell(cell, SOURCE_GROUND, GRASS_TILES[0])
		return
	var n := _looped_noise(detail_noise, float(cell.x) * 0.22, phase)
	if dist_to_river == river_half_width + 1:
		base.set_cell(cell, SOURCE_GROUND, SOFT_GROUND_TILES[posmod(cell.x + cell.y, SOFT_GROUND_TILES.size())])
	elif n > 0.62:
		base.set_cell(cell, SOURCE_GROUND, GRASS_TILES[posmod(cell.x * 3 + cell.y, GRASS_TILES.size())])
	elif n < -0.58:
		base.set_cell(cell, SOURCE_GROUND, STONE_TILES[posmod(cell.x + cell.y * 2, STONE_TILES.size())])
	else:
		base.set_cell(cell, SOURCE_GROUND, GRASS_TILES[0])

func _paint_objects(objects: TileMapLayer, cell: Vector2i, rng: RandomNumberGenerator, phase: float, dist_to_river: int, river_half_width: int, seam_band: bool) -> void:
	if seam_band:
		return
	if cell.x <= 1 or cell.x >= map_width_tiles - 2:
		return
	if dist_to_river <= river_half_width + 2:
		return

	var grove := _looped_noise(object_noise, float(cell.x) * 0.31 - 18.0, phase)
	if grove < 0.47:
		return
	if rng.randf() > 0.34:
		return

	var object_coord: Vector2i = OBJECT_TILES[rng.randi_range(0, OBJECT_TILES.size() - 1)]
	objects.set_cell(cell, SOURCE_OBJECTS, object_coord)

func _update_chunk_positions() -> void:
	var first_y := scroll_offset - loop_height
	for i in range(chunks.size()):
		chunks[i].position.y = first_y + float(i) * loop_height

func _clear_chunks() -> void:
	for chunk in chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	chunks.clear()

func _create_noises(seed_value: int) -> void:
	terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = seed_value
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_noise.frequency = 0.035
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_gain = 0.48

	detail_noise = FastNoiseLite.new()
	detail_noise.seed = seed_value + 92821
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.09
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 3
	detail_noise.fractal_gain = 0.52

	object_noise = FastNoiseLite.new()
	object_noise.seed = seed_value + 3319
	object_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	object_noise.frequency = 0.06
	object_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	object_noise.fractal_octaves = 3

func _looped_noise(noise: FastNoiseLite, x: float, phase: float) -> float:
	var radius := 24.0
	return noise.get_noise_3d(x, cos(phase) * radius, sin(phase) * radius)

func _seed_for_level(level: int) -> int:
	return base_seed + max(1, level) * 104729

func _create_grassland_tile_set() -> TileSet:
	var result := TileSet.new()
	result.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	result.add_terrain_set()
	result.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	result.add_terrain(0)
	result.set_terrain_name(0, 0, "Grassland")
	result.set_terrain_color(0, 0, Color(0.53, 0.78, 0.42))

	var ground_coords: Array[Vector2i] = []
	ground_coords.append_array(GRASS_TILES)
	ground_coords.append_array(SOFT_GROUND_TILES)
	ground_coords.append_array(STONE_TILES)
	ground_coords.append(SHORE_LEFT)
	_add_atlas_source(result, SOURCE_GROUND, "res://assets/tile_set1/ground_tiles.png", ground_coords, true)
	_add_atlas_source(result, SOURCE_WATER, "res://assets/tile_set1/graphics-tiles-waterflow.png", WATER_TILES, false)
	_add_atlas_source(result, SOURCE_OBJECTS, "res://assets/tile_set1/object- layer.png", OBJECT_TILES, false)
	return result

func _add_atlas_source(target: TileSet, source_id: int, path: String, coords: Array[Vector2i], terrain_enabled: bool) -> void:
	var texture := _load_tile_texture(path)
	if texture == null:
		push_warning("Missing TileSet texture: " + path)
		return

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var created := {}
	for coord in coords:
		if not created.has(coord):
			source.create_tile(coord)
			created[coord] = true
	target.add_source(source, source_id)

	if terrain_enabled:
		for coord in GRASS_TILES:
			var data := source.get_tile_data(coord, 0)
			data.terrain_set = 0
			data.terrain = 0
			for neighbor in _all_terrain_neighbors():
				data.set_terrain_peering_bit(neighbor, 0)

func _load_tile_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _all_terrain_neighbors() -> Array:
	return [
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_TOP_SIDE,
		TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE,
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
	]
