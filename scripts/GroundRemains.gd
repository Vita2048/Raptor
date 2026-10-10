extends Node2D

var age := 0.0
var radius := 80.0
var debris: Array[Vector2] = []
var crater_material: ShaderMaterial
var tint_tween: Tween
var dust_color := Color(0.78, 0.61, 0.4)
var debris_color := Color(0.16, 0.13, 0.1, 0.8)
const CRATER_TINTS := [Color(0.9, 0.85, 0.76), Color(0.86, 0.85, 0.81), Color(0.78, 0.79, 0.80)]
const CRATER_SATURATION := [1.0, 0.22, 0.12]
const DUST_TINTS := [Color(0.78, 0.61, 0.4), Color(0.60, 0.58, 0.53), Color(0.48, 0.51, 0.56)]

func _apply_sector_tint(level: int, gradual := true) -> void:
	var index := clampi(level - 1, 0, 2)
	if tint_tween and tint_tween.is_valid():
		tint_tween.kill()
	dust_color = DUST_TINTS[index]
	debris_color = Color(dust_color.r * 0.21, dust_color.g * 0.21, dust_color.b * 0.21, 0.8)
	if gradual:
		# Match the five-second terrain change for wrecks left on screen.
		tint_tween = create_tween().set_parallel(true)
		tint_tween.tween_property(crater_material, "shader_parameter/ground_tint", CRATER_TINTS[index], 5.0)
		tint_tween.tween_property(crater_material, "shader_parameter/saturation", CRATER_SATURATION[index], 5.0)
	else:
		crater_material.set_shader_parameter("ground_tint", CRATER_TINTS[index])
		crater_material.set_shader_parameter("saturation", CRATER_SATURATION[index])
	queue_redraw()

func configure(dimensions: Vector2, wreck_texture: Texture2D = null) -> void:
	radius = maxf(dimensions.x, dimensions.y) * 0.5
	var crater := Sprite2D.new()
	crater.name = "Crater"
	crater.texture = AssetDB.crater_texture
	crater.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Leave a broken-earth rim visible beyond the bunker corners.
	crater.scale = dimensions * (1.62 if wreck_texture != null else 1.22) / crater.texture.get_size()
	crater_material = ShaderMaterial.new()
	crater_material.shader = preload("res://shaders/crater.gdshader")
	crater.material = crater_material
	_apply_sector_tint(GameState.current_level, false)
	GameState.level_advanced.connect(_apply_sector_tint)
	add_child(crater)
	if wreck_texture != null:
		var wreck := Sprite2D.new()
		wreck.name = "BuildingWreck"
		wreck.texture = wreck_texture
		wreck.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		wreck.scale = dimensions / Vector2(wreck_texture.get_meta("intact_size", wreck_texture.get_size()))
		wreck.position = Vector2(wreck_texture.get_meta("center_offset", Vector2.ZERO)) * wreck.scale
		wreck.modulate = Color(0.94, 0.91, 0.85)
		var grade := ShaderMaterial.new()
		grade.shader = preload("res://shaders/terrain.gdshader")
		wreck.material = grade
		add_child(wreck)
	var random := RandomNumberGenerator.new()
	random.randomize()
	for i in range(14):
		debris.append(Vector2.from_angle(random.randf_range(0, TAU)) * random.randf_range(radius * 0.3, radius * 0.85))
	var blast := preload("res://scenes/ExplosionEffect.tscn").instantiate()
	blast.configure(false, clampf(radius / 65.0, 0.7, 1.5))
	add_child(blast)
	blast.burst()

func _process(delta: float) -> void:
	age += delta
	if age < 3.0:
		queue_redraw()
	else:
		queue_redraw()
		set_process(false)

func _draw() -> void:
	if age < 0.65:
		var t := age / 0.65
		draw_arc(Vector2.ZERO, radius * (0.25 + t * 1.3), 0, TAU, 64, Color(dust_color, (1.0 - t) * 0.32), 9.0 * (1.0 - t), true)
	for i in range(debris.size()):
		var target := debris[i]
		var t := minf(age / 0.5, 1.0)
		var pos := target * (1.0 - pow(1.0 - t, 3.0))
		draw_rect(Rect2(pos, Vector2(3, 2)), debris_color)
		if age < 2.2:
			draw_circle(pos, 1.8, Color(1.8, 0.6, 0.12, (1.0 - age / 2.2) * 0.7))
