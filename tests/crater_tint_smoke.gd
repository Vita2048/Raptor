extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(18.0).timeout.connect(func(): push_error("Crater tint timeout"); quit(2))
	root.size = Vector2i(1920, 1080)
	var assets = root.get_node("AssetDB")
	var state = root.get_node("GameState")
	state.reset()
	var remains_script = load("res://scripts/GroundRemains.gd")
	var samples: Array = []
	for level in range(1, 4):
		state.current_level = level
		var map_tex: Texture2D = assets.sector_textures[level - 1]
		var crop := AtlasTexture.new()
		crop.atlas = map_tex
		crop.region = Rect2(map_tex.get_size() * Vector2(0.18, 0.32), map_tex.get_size() * Vector2(0.20, 0.30))
		var ground := Sprite2D.new()
		ground.centered = false
		ground.position = Vector2((level - 1) * 640, 0)
		ground.texture = crop
		ground.scale = Vector2(640, 1080) / crop.get_size()
		ground.modulate = Color(0.84, 0.84, 0.83)
		root.add_child(ground)
		for wreck in [false, true]:
			var sample = remains_script.new()
			root.add_child(sample)
			sample.position = Vector2((level - 1) * 640 + 320, 750 if wreck else 300)
			sample.configure(Vector2(230, 190), assets.desert_buildings[0].get_meta("destroyed_texture") if wreck else null)
			assert(sample.crater_material.get_shader_parameter("ground_tint") == sample.CRATER_TINTS[level - 1])
			assert(sample.get_node("Crater").texture == assets.crater_texture)
			samples.append(sample)
		var label := Label.new()
		label.position = Vector2((level - 1) * 640 + 35, 30)
		label.text = ["LEVEL 1 / ORIGINAL SAND", "LEVEL 2 / CONCRETE DUST", "LEVEL 3 / SLATE RUBBLE"][level - 1]
		label.add_theme_font_size_override("font_size", 25)
		root.add_child(label)
	await create_timer(2.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/review")
	assert(root.get_texture().get_image().save_png("res://artifacts/review/crater-sector-tints.png") == OK)
	# Existing remains must follow a sector transition even after processing stops.
	state.current_level = 2
	state.level_advanced.emit(2)
	assert(samples[0].crater_material.get_shader_parameter("saturation") == 1.0)
	await create_timer(5.2).timeout
	for sample in samples:
		assert(is_equal_approx(sample.crater_material.get_shader_parameter("saturation"), 0.22))
		assert(sample.crater_material.get_shader_parameter("ground_tint").is_equal_approx(sample.CRATER_TINTS[1]))
	print("CRATER_TINTS_OK: three palettes, shared geometry, building/vehicle layers, smooth persistent-wreck transition")
	quit()
