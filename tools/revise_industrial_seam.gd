extends SceneTree
func _initialize() -> void:
	var path := "res://assets/background/industrial_riverworks.png"
	var backup := "res://artifacts/seams/industrial-before-geometry-revision.png"
	if not FileAccess.file_exists(backup):
		DirAccess.copy_absolute(path, backup)
	var src := Image.load_from_file(backup)
	var result := src.duplicate() as Image
	var patch := Image.load_from_file("res://artifacts/seams/industrial-revision-patch.png")
	patch.resize(src.get_width(), 512, Image.INTERPOLATE_LANCZOS)
	for row in range(512):
		var vertical := smoothstep(24.0, 48.0, float(mini(row, 511 - row)))
		var y := posmod(src.get_height() - 256 + row, src.get_height())
		for x in range(src.get_width()):
			var sides := maxf(1.0 - smoothstep(225.0, 265.0, float(x)), smoothstep(695.0, 735.0, float(x)))
			result.set_pixel(x, y, src.get_pixel(x, y).lerp(patch.get_pixel(x, row), vertical * sides))
	assert(result.get_region(Rect2i(265, 0, 430, src.get_height())).get_data() == src.get_region(Rect2i(265, 0, 430, src.get_height())).get_data())
	assert(result.save_png(path) == OK)
	var strip := Image.create(src.get_width(), 512, false, Image.FORMAT_RGB8)
	strip.blit_rect(result, Rect2i(0, src.get_height() - 256, src.get_width(), 256), Vector2i.ZERO)
	strip.blit_rect(result, Rect2i(0, 0, src.get_width(), 256), Vector2i(0, 256))
	strip.save_png("res://artifacts/seams/industrial-revision-after.png")
	strip.get_region(Rect2i(0, 90, 240, 360)).save_png("res://artifacts/seams/industrial-left-detail.png")
	strip.get_region(Rect2i(730, 90, 157, 360)).save_png("res://artifacts/seams/industrial-right-detail.png")
	print("INDUSTRIAL_GEOMETRY_OK: central river and bridge pixels unchanged")
	quit()
