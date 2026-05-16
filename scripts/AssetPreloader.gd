extends Node

const BACKGROUND_DIR := "res://assets/background/"
const BUILDINGS_DIR := "res://assets/buildings/"
const SHIPS_DIR := "res://assets/ships/"
const PARTICLES_DIR := "res://assets/particles/"

var background_textures: Array[Texture2D] = []
var desert_textures: Array[Texture2D] = []
var space_textures: Array[Texture2D] = []
var building_textures: Array[Texture2D] = []
var ship_textures := {}
var flash_textures: Array[Texture2D] = []
var explosion_textures: Array[Texture2D] = []
var white_puff_textures: Array[Texture2D] = []
var black_smoke_textures: Array[Texture2D] = []

func _ready() -> void:
	load_all()

func load_all() -> void:
	desert_textures = _load_named_series(BACKGROUND_DIR, "desert_tile", 1, 5)
	space_textures = _load_named_series(BACKGROUND_DIR, "space_tile", 1, 2)
	background_textures = desert_textures + space_textures
	building_textures = [
		load(BUILDINGS_DIR + "Bunker.png"),
		load(BUILDINGS_DIR + "Factory.png"),
		load(BUILDINGS_DIR + "Factory1.png")
	]
	ship_textures = {
		"player": load(SHIPS_DIR + "PlayerShip.png"),
		"interceptor": load(SHIPS_DIR + "EnemyInterceptor.png"),
		"bomber": load(SHIPS_DIR + "Bomber.png"),
		"boss": load(SHIPS_DIR + "BossShip.png")
	}
	black_smoke_textures = _load_zero_series(PARTICLES_DIR, "blackSmoke", 0, 24)
	explosion_textures = _load_zero_series(PARTICLES_DIR, "explosion", 0, 8)
	flash_textures = _load_zero_series(PARTICLES_DIR, "flash", 0, 8)
	white_puff_textures = _load_zero_series(PARTICLES_DIR, "whitePuff", 0, 24)

func random_background() -> Texture2D:
	return background_textures.pick_random()

func random_ground_tile() -> Texture2D:
	return desert_textures.pick_random()

func random_building() -> Texture2D:
	return building_textures.pick_random()

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
