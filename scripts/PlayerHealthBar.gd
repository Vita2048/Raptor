extends Control

var health: int = 100
var max_health: int = 100
var flash_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 58)

func set_health(value: int, maximum: int) -> void:
	var previous: int = health
	health = max(value, 0)
	max_health = max(maximum, 1)
	if health < previous:
		flash_time = 0.32
	queue_redraw()

func _process(delta: float) -> void:
	if flash_time > 0.0:
		flash_time = max(flash_time - delta, 0.0)
		queue_redraw()

func _draw() -> void:
	var bar_rect: Rect2 = Rect2(Vector2.ZERO, size)
	var inner_rect: Rect2 = bar_rect.grow(-7.0)
	var slot_rect: Rect2 = inner_rect.grow(-5.0)
	var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
	var pulse: float = 0.5 + sin(Time.get_ticks_msec() * 0.018) * 0.5

	draw_rect(bar_rect, Color(0.0, 0.02, 0.06, 0.62), true)
	draw_rect(inner_rect, Color(0.03, 0.12, 0.2, 0.78), true)
	draw_rect(inner_rect, Color(0.36, 1.0, 1.5, 0.55), false, 2.0)
	draw_line(Vector2(inner_rect.position.x, inner_rect.position.y + 2.0), Vector2(inner_rect.end.x, inner_rect.position.y + 2.0), Color(0.82, 2.2, 3.4, 0.6), 2.0)

	var fill_width: float = slot_rect.size.x * ratio
	var filled_rect: Rect2 = Rect2(slot_rect.position, Vector2(fill_width, slot_rect.size.y))
	var fill_color: Color = Color(0.1, 1.05, 1.9, 0.92)
	if ratio < 0.35:
		fill_color = Color(2.3, 0.34 + pulse * 0.35, 0.18, 0.96)
	elif ratio < 0.62:
		fill_color = Color(2.0, 1.35, 0.26, 0.94)
	draw_rect(filled_rect, fill_color, true)
	draw_rect(Rect2(slot_rect.position, Vector2(fill_width, slot_rect.size.y * 0.38)), Color(1.0, 2.6, 3.6, 0.28), true)

	var segments: int = 20
	var gap: float = 4.0
	var segment_width: float = (slot_rect.size.x - gap * float(segments - 1)) / float(segments)
	for i in range(segments):
		var x: float = slot_rect.position.x + float(i) * (segment_width + gap)
		var segment: Rect2 = Rect2(Vector2(x, slot_rect.position.y), Vector2(segment_width, slot_rect.size.y))
		draw_rect(segment, Color(0.75, 1.7, 2.6, 0.15), false, 1.0)
		if float(i + 1) / float(segments) <= ratio:
			draw_line(Vector2(x + segment_width, slot_rect.position.y + 4.0), Vector2(x + segment_width, slot_rect.end.y - 4.0), Color(1.0, 3.0, 4.5, 0.22), 2.0)

	if flash_time > 0.0:
		draw_rect(inner_rect, Color(1.0, 2.4, 3.6, flash_time * 1.25), true)

	var font: Font = ThemeDB.fallback_font
	var label: String = "SHIP ARMOR"
	var value: String = "%03d / %03d" % [health, max_health]
	draw_string(font, Vector2(18, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(0.72, 1.7, 2.3, 0.92))
	draw_string(font, Vector2(size.x - 164, 42), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, Color(0.88, 2.3, 3.3, 0.96))
