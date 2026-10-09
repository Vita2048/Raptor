extends Node2D

var age := 0.0
var radius := 80.0
var debris: Array[Vector2] = []

func configure(dimensions: Vector2) -> void:
	radius = maxf(dimensions.x, dimensions.y) * 0.5
	var crater := Sprite2D.new()
	crater.texture = AssetDB.crater_texture
	crater.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	crater.scale = dimensions * 1.22 / crater.texture.get_size()
	crater.modulate = Color(0.9, 0.85, 0.76)
	add_child(crater)
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
		draw_arc(Vector2.ZERO, radius * (0.25 + t * 1.3), 0, TAU, 64, Color(0.78, 0.61, 0.4, (1.0 - t) * 0.32), 9.0 * (1.0 - t), true)
	for i in range(debris.size()):
		var target := debris[i]
		var t := minf(age / 0.5, 1.0)
		var pos := target * (1.0 - pow(1.0 - t, 3.0))
		draw_rect(Rect2(pos, Vector2(3, 2)), Color(0.16, 0.13, 0.1, 0.8))
		if age < 2.2:
			draw_circle(pos, 1.8, Color(1.8, 0.6, 0.12, (1.0 - age / 2.2) * 0.7))
