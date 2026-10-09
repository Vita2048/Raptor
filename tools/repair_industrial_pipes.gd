extends SceneTree
func _initialize() -> void:
	var path := "res://assets/background/industrial_riverworks.png"
	var backup := "res://artifacts/seams/industrial-before-river-pipes.png"
	if not FileAccess.file_exists(backup):
		DirAccess.copy_absolute(path, backup)
	var src := Image.load_from_file(backup)
	var result := src.duplicate() as Image
	var patch := Image.load_from_file("res://artifacts/seams/industrial-river-pipe-patch.png")
	patch.resize(src.get_width(), 512, Image.INTERPOLATE_LANCZOS)
	for row in range(512):
		var y := posmod(src.get_height() - 256 + row, src.get_height())
		for x in range(src.get_width()):
			var point := Vector2(x, row)
			var weight := maxf(mask(point, Rect2(280, 205, 135, 110)), mask(point, Rect2(480, 55, 175, 405)))
			if weight > 0:
				result.set_pixel(x, y, src.get_pixel(x, y).lerp(patch.get_pixel(x, row), weight))
	assert(result.get_region(Rect2i(0, 0, 280, src.get_height())).get_data() == src.get_region(Rect2i(0, 0, 280, src.get_height())).get_data())
	assert(result.get_region(Rect2i(655, 0, 232, src.get_height())).get_data() == src.get_region(Rect2i(655, 0, 232, src.get_height())).get_data())
	assert(result.save_png(path) == OK)
	var strip := Image.create(src.get_width(), 512, false, Image.FORMAT_RGB8)
	strip.blit_rect(result, Rect2i(0, src.get_height() - 256, src.get_width(), 256), Vector2i.ZERO)
	strip.blit_rect(result, Rect2i(0, 0, src.get_width(), 256), Vector2i(0, 256))
	strip.save_png("res://artifacts/seams/industrial-final-join.png")
	strip.get_region(Rect2i(280, 200, 375, 140)).save_png("res://artifacts/seams/industrial-river-pipe-detail.png")
	print("RIVER_PIPE_REPAIR_OK: rails, basin and silos remain pixel-identical")
	quit()
func mask(point: Vector2, rect: Rect2) -> float:
	var edge := minf(minf(point.x - rect.position.x, rect.end.x - point.x), minf(point.y - rect.position.y, rect.end.y - point.y))
	return smoothstep(0.0, 18.0, edge)
