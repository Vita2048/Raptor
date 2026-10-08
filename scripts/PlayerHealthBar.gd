extends Control

var health := 100
var max_health := 100
var displayed_ratio := 1.0
var damage_trail := 1.0
var flash_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_health(value: int, maximum: int) -> void:
	if value < health:
		flash_time = 0.28
	health = maxi(value, 0)
	max_health = maxi(maximum, 1)

func _process(delta: float) -> void:
	var ratio := float(health) / max_health
	displayed_ratio = move_toward(displayed_ratio, ratio, delta * 1.8)
	flash_time = maxf(flash_time - delta, 0.0)
	if flash_time <= 0.0:
		damage_trail = move_toward(damage_trail, ratio, delta * 0.4)
	damage_trail = maxf(damage_trail, displayed_ratio)
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var accent := Color("86d8de") if float(health) / max_health > 0.3 else Color("f1a16f")
	draw_string(font, Vector2(0, 20), "SHIP ARMOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("95a9b1"))
	draw_string(font, Vector2(size.x - 85, 20), "%03d / %03d" % [health, max_health], HORIZONTAL_ALIGNMENT_RIGHT, 85, 16, Color("e8efed"))
	var slot := Rect2(0, 36, size.x, 10)
	draw_rect(slot, Color("293740"))
	draw_rect(Rect2(slot.position, Vector2(size.x * damage_trail, 10)), Color("ac7656"))
	draw_rect(Rect2(slot.position, Vector2(size.x * displayed_ratio, 10)), accent)
	for i in range(1, 10):
		var x := size.x * float(i) / 10.0
		draw_line(Vector2(x, 36), Vector2(x, 46), Color("101c25"), 3.0)
	if health <= max_health * 0.3:
		draw_string(font, Vector2(0, 65), "ARMOR CRITICAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)
