extends Node2D

var plume_length := 90.0
var plume_width := 30.0
var flicker_phase := 0.0
var pulse_speed := 16.0

func _ready() -> void:
	z_index = -8
	var add_material := CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add_material
	flicker_phase = randf_range(0.0, TAU)

func configure(length: float, width: float, angle: float) -> void:
	plume_length = length
	plume_width = width
	rotation = angle

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001 + flicker_phase
	var flicker := 0.86 + sin(t * pulse_speed) * 0.12 + sin(t * 31.0) * 0.06
	var length := plume_length * flicker
	var width := plume_width * (1.0 + sin(t * 22.0) * 0.08)

	var outer := PackedVector2Array([
		Vector2(-width * 0.34, 0.0),
		Vector2(-width * 0.58, length * 0.24),
		Vector2(-width * 0.32, length * 0.64),
		Vector2(-width * 0.08, length),
		Vector2(0.0, length * 1.12),
		Vector2(width * 0.08, length),
		Vector2(width * 0.32, length * 0.64),
		Vector2(width * 0.58, length * 0.24),
		Vector2(width * 0.34, 0.0)
	])
	draw_polygon(outer, PackedColorArray([
		Color(0.1, 0.5, 2.6, 0.0),
		Color(0.0, 0.85, 3.0, 0.24),
		Color(0.0, 0.45, 2.7, 0.18),
		Color(0.0, 0.25, 1.9, 0.05),
		Color(0.0, 0.18, 1.4, 0.0),
		Color(0.0, 0.25, 1.9, 0.05),
		Color(0.0, 0.45, 2.7, 0.18),
		Color(0.0, 0.85, 3.0, 0.24),
		Color(0.1, 0.5, 2.6, 0.0)
	]))

	var inner_width := width * 0.42
	var inner_length := length * 0.72
	var inner := PackedVector2Array([
		Vector2(-inner_width * 0.44, 0.0),
		Vector2(-inner_width * 0.34, inner_length * 0.36),
		Vector2(0.0, inner_length),
		Vector2(inner_width * 0.34, inner_length * 0.36),
		Vector2(inner_width * 0.44, 0.0)
	])
	draw_polygon(inner, PackedColorArray([
		Color(0.55, 2.4, 4.2, 0.75),
		Color(0.2, 1.6, 4.0, 0.58),
		Color(0.05, 0.9, 3.6, 0.0),
		Color(0.2, 1.6, 4.0, 0.58),
		Color(0.55, 2.4, 4.2, 0.75)
	]))

	draw_circle(Vector2.ZERO, width * 0.34, Color(0.6, 2.5, 4.8, 0.45))
	draw_circle(Vector2.ZERO, width * 0.16, Color(1.4, 3.2, 5.0, 0.95))

	for i in range(3):
		var offset := (float(i) - 1.0) * width * 0.2 + sin(t * (12.0 + i * 3.0)) * width * 0.06
		var streak_length := length * (0.34 + i * 0.12)
		draw_line(
			Vector2(offset, width * 0.18),
			Vector2(offset * 0.35, streak_length),
			Color(0.24, 1.5, 4.0, 0.32),
			max(2.0, width * 0.055),
			true
		)
