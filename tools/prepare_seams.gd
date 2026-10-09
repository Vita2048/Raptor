extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/seams")
	for name in ["industrial_riverworks", "command_fortress"]:
		var src := Image.load_from_file("res://assets/background/" + name + ".png")
		var strip := Image.create(src.get_width(), 512, false, Image.FORMAT_RGB8)
		strip.blit_rect(src, Rect2i(0, src.get_height() - 256, src.get_width(), 256), Vector2i.ZERO)
		strip.blit_rect(src, Rect2i(0, 0, src.get_width(), 256), Vector2i(0, 256))
		strip.save_png("res://artifacts/seams/" + name + "-before.png")
	quit()
