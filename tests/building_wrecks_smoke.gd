extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(20.0).timeout.connect(func(): push_error("Building wreck test timeout"); quit(2))
	root.size = Vector2i(1920, 1080)
	var backdrop := ColorRect.new()
	backdrop.color = Color("34342e")
	backdrop.size = Vector2(1920, 1080)
	root.add_child(backdrop)
	var state = root.get_node("GameState")
	state.reset()
	var assets = root.get_node("AssetDB")
	var structures: Array = []
	for i in range(assets.desert_buildings.size()):
		var tex: AtlasTexture = assets.desert_buildings[i]
		assert(tex.has_meta("destroyed_texture"), "Each gameplay building needs its own wreck")
		var wreck_tex: AtlasTexture = tex.get_meta("destroyed_texture")
		assert(wreck_tex.get_meta("intact_size") == tex.get_size())
		assert(wreck_tex.atlas.get_size() == tex.atlas.get_size())
		assert(wreck_tex.atlas.get_image().get_pixel(0, 0).a < 0.01)
		for destroyed in [false, true]:
			var building = load("res://scripts/SceneryObject.gd").new()
			root.add_child(building)
			building.position = Vector2(-900, -900) if i == 0 else Vector2(240 + (i - 1) * 480, 745 if destroyed else 265)
			building.set_texture(tex)
			building.set_visual_scale(Vector2.ONE * minf(265.0 / tex.get_width(), 250.0 / tex.get_height()))
			building.reset_structure()
			if destroyed:
				building.take_damage(building.health)
				await process_frame
				var crater: Sprite2D = building.remains.get_node("Crater")
				var wreck: Sprite2D = building.remains.get_node("BuildingWreck")
				assert(crater.texture == assets.crater_texture and wreck.texture == wreck_tex)
				assert(wreck.scale == building.sprite.scale)
				var score: int = state.score
				building.take_damage(1000)
				assert(state.score == score, "Wreck cannot award duplicate score")
				structures.append(building)
		if i > 0:
			_label(Vector2(65 + (i - 1) * 480, 50), ["FACTORY", "RADAR STATION", "HANGAR", "FUEL DEPOT"][i - 1])
	_label(Vector2(55, 490), "DESTROYED / ORIGINAL CRATER")
	await create_timer(2.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/review")
	assert(root.get_texture().get_image().save_png("res://artifacts/review/building-wrecks.png") == OK)
	for building in structures:
		building.reset_structure()
		assert(not building.destroyed and building.sprite.visible)
		assert(building.health == building.max_health)
		assert(building.remains.get_parent() == null)
	print("BUILDING_WRECKS_OK: five matching wrecks, transparent assets, crater layers, alignment, score and reuse")
	quit()

func _label(at: Vector2, title: String) -> void:
	var label := Label.new()
	label.position = at
	label.text = title
	label.add_theme_font_size_override("font_size", 25)
	root.add_child(label)
