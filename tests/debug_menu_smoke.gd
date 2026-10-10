extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(45.0).timeout.connect(func(): push_error("Debug menu timeout"); quit(2))
	var options = load("res://scripts/DebugOptions.gd")
	assert(options.menu_requested())
	options.selected_level = 0
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	assert(paused and scene.get_node("DebugMenu").is_open)
	DirAccess.make_dir_recursive_absolute("res://artifacts/review")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/review/debug-menu.png")
	var state = root.get_node("GameState")
	for boss_mode in [false, true]:
		for level in range(1, 4):
			current_scene.get_node("DebugMenu").select_destination(level, boss_mode)
			await create_timer(0.3).timeout
			assert(not paused and state.current_level == level and state.score == 0)
			assert(state.checkpoint_level == level)
			var manager = current_scene.enemy_manager
			assert(manager.boss_pending == boss_mode)
			if boss_mode:
				await create_timer(4.0).timeout
				var boss = manager.enemy_pool.active[0]
				assert(boss.enemy_type == ["boss", "boss2", "boss3"][level - 1])
				boss.take_damage(int(boss.max_health * 0.85))
				await create_timer(0.7).timeout
				assert(boss.damage_effect.smoke_strength > 0.9)
				assert(boss.damage_effect.fire_strength > 0.7)
				assert(boss.damage_effect.particles.size() > 0 and boss.damage_effect.particles.size() <= 64)
				boss.return_to_pool()
				assert(boss.damage_effect.particles.is_empty())
	var building = load("res://scripts/SceneryObject.gd").new()
	current_scene.add_child(building)
	var tex: Texture2D = root.get_node("AssetDB").desert_buildings[0]
	building.set_texture(tex)
	building.set_visual_scale(Vector2.ONE * 0.25)
	building.reset_structure()
	building.take_damage(building.health)
	await process_frame
	assert(building.destroyed and is_instance_valid(building.remains))
	var crater: Sprite2D = building.remains.get_node("Crater")
	assert(crater.texture == root.get_node("AssetDB").crater_texture)
	assert((crater.texture.get_size() * crater.scale).x > building.footprint.x * 1.5)
	var wreck: Sprite2D = building.remains.get_node("BuildingWreck")
	assert(wreck.texture == tex.get_meta("destroyed_texture"))
	assert(wreck.scale.is_equal_approx(building.sprite.scale))
	building.reset_structure()
	assert(not building.destroyed and building.sprite.visible)
	assert(building.sprite.texture == tex)
	current_scene.get_node("DebugMenu").set_open(true)
	assert(paused)
	current_scene.get_node("DebugMenu").set_open(false)
	assert(not paused)
	print("DEBUG_MENU_OK: six destinations, warning/entrance, checkpoints, pause/resume, smoke/fire, pool reset, bunker wreck/reset")
	quit()
