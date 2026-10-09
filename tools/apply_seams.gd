extends SceneTree
# Offline assembly of image_gen's localized repairs; the untouched map stays exact.
func _initialize() -> void:
	for name in ["industrial_riverworks", "command_fortress"]:
		var path: String = "res://assets/background/" + name + ".png"
		var backup: String = "res://artifacts/seams/" + name + "-original.png"
		if not FileAccess.file_exists(backup):
			DirAccess.copy_absolute(path, backup)
		var src := Image.load_from_file(backup)
		var result := src.duplicate() as Image
		var patch := Image.load_from_file("res://artifacts/seams/" + name + "-patch.png")
		patch.resize(src.get_width(), 512, Image.INTERPOLATE_LANCZOS)
		for row in range(512):
			var weight := smoothstep(96.0, 176.0, float(mini(row, 511 - row)))
			var y := posmod(src.get_height() - 256 + row, src.get_height())
			for x in range(src.get_width()):
				result.set_pixel(x, y, src.get_pixel(x, y).lerp(patch.get_pixel(x, row), weight))
		# Only 159 rows at either end may differ; central geometry remains identical.
		assert(src.get_region(Rect2i(0, 160, src.get_width(), src.get_height() - 320)).get_data() == result.get_region(Rect2i(0, 160, src.get_width(), src.get_height() - 320)).get_data())
		assert(result.save_png(path) == OK)
		var strip := Image.create(src.get_width(), 512, false, Image.FORMAT_RGB8)
		strip.blit_rect(result, Rect2i(0, src.get_height() - 256, src.get_width(), 256), Vector2i.ZERO)
		strip.blit_rect(result, Rect2i(0, 0, src.get_width(), 256), Vector2i(0, 256))
		strip.save_png("res://artifacts/seams/" + name + "-after.png")
		var stack := Image.create(src.get_width(), src.get_height() * 3, false, Image.FORMAT_RGB8)
		for i in range(3):
			stack.blit_rect(result, Rect2i(Vector2i.ZERO, result.get_size()), Vector2i(0, i * src.get_height()))
		stack.save_png("res://artifacts/seams/" + name + "-stacked.png")
		print(name + ": repaired seam; central map unchanged")
	quit()
