extends Node2D

const VIEW_SIZE := Vector2(1920, 1080)
const SCROLL_SPEED := 235.0

var sprites: Array[Sprite2D] = []
var scroll_offset := 0.0
var image_scale := 1.0
var loop_height := 1.0
var distance := 0.0
var terrain_sector := 1
var transition_progress := 1.0
var previous_sector := 1
var sector_light := Color(0.94, 0.95, 0.97)
const SECTOR_LIGHTS := [Color(0.94, 0.95, 0.97), Color(0.86, 0.92, 0.99), Color(0.80, 0.84, 0.94)]

func _ready() -> void:
	z_index = -100
	sector_light = SECTOR_LIGHTS[clampi(GameState.current_level - 1, 0, 2)]
	RenderingServer.global_shader_parameter_set("sector_light", sector_light)
	terrain_sector = clampi(GameState.current_level, 1, 3)
	previous_sector = terrain_sector
	var texture := AssetDB.bridge_texture
	image_scale = VIEW_SIZE.x / texture.get_width()
	loop_height = texture.get_height() * image_scale
	for i in range(3):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.scale = Vector2(image_scale * 1.012, image_scale)
		var grade := ShaderMaterial.new()
		grade.shader = preload("res://shaders/terrain.gdshader")
		grade.set_shader_parameter("animate_water", true)
		grade.set_shader_parameter("current_map", AssetDB.sector_textures[terrain_sector - 1])
		grade.set_shader_parameter("next_map", AssetDB.sector_textures[terrain_sector - 1])
		grade.set_shader_parameter("transition_progress", 1.0)
		sprite.material = grade
		add_child(sprite)
		sprites.append(sprite)
	_update_sprite_positions()

func _process(delta: float) -> void:
	if terrain_sector != GameState.current_level:
		previous_sector = terrain_sector
		terrain_sector = clampi(GameState.current_level, 1, 3)
		transition_progress = 0.0
		for sprite in sprites:
			sprite.material.set_shader_parameter("current_map", AssetDB.sector_textures[previous_sector - 1])
			sprite.material.set_shader_parameter("next_map", AssetDB.sector_textures[terrain_sector - 1])
	transition_progress = minf(1.0, transition_progress + delta / 5.0)
	for sprite in sprites:
		sprite.material.set_shader_parameter("transition_progress", transition_progress)
	sector_light = sector_light.lerp(SECTOR_LIGHTS[clampi(GameState.current_level - 1, 0, 2)], 1.0 - exp(-delta * 0.65))
	RenderingServer.global_shader_parameter_set("sector_light", sector_light)
	if GameState.campaign_won:
		return
	distance += SCROLL_SPEED * delta
	_update_sprite_positions()

func _update_sprite_positions() -> void:
	scroll_offset = fposmod(distance, loop_height)
	if sprites.size() < 2:
		return
	var first_y := scroll_offset - loop_height
	for i in range(sprites.size()):
		sprites[i].position = Vector2(-VIEW_SIZE.x * 0.006, first_y + float(i) * loop_height)
