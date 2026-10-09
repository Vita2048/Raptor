extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.5).timeout
	var state = root.get_node("GameState")
	scene.enemy_manager.set_process(false)
	scene.enemy_manager.enemy_pool.release_all()
	scene.ground_traffic.set_process(false)
	scene.background.set_process(false)
	for sector in range(1, 4):
		if sector > 1:
			state.advance_level()
			scene.background._process(2.5)
			assert(is_equal_approx(scene.background.transition_progress, 0.5))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/sector-transition-%d.png" % sector)
		scene.background._process(20.0)
		scene.background.distance = 240.0
		scene.background._update_sprite_positions()
		for entry in scene.world_spawner.scenery_entries:
			scene.world_spawner._dress_area(entry)
		var enemy = scene.enemy_manager.enemy_pool.acquire()
		enemy.spawn("interceptor", Vector2(720, 340))
		enemy.set_physics_process(false)
		var bullet = scene.enemy_manager.enemy_bullet_pool.acquire()
		bullet.launch(Vector2(980, 620), Vector2.DOWN, 1, 8, false)
		assert(bullet.z_index == 0 and bullet.sparkles.emitting)
		assert(scene.background.terrain_sector == sector)
		assert(scene.background.transition_progress == 1.0)
		for child in bullet.get_children():
			if child is CollisionShape2D:
				assert(child.shape.radius == 7.0)
		scene.player._shoot()
		await create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/visual-sector-%d.png" % sector)
		enemy.return_to_pool()
		bullet.return_to_pool()
	# Re-entering from a checkpoint must show its terrain immediately, not replay sector 1.
	state.record_checkpoint()
	state.game_active = false
	assert(reload_current_scene() == OK)
	await create_timer(0.25).timeout
	assert(current_scene.background.terrain_sector == 3)
	assert(current_scene.background.transition_progress == 1.0)
	# Verify a wrap never leaves a gap between adjacent terrain tiles.
	var bg = current_scene.background
	bg.distance = bg.loop_height - 1.0
	bg._update_sprite_positions()
	assert(is_equal_approx(bg.sprites[1].position.y - bg.sprites[0].position.y, bg.loop_height))
	bg._process(0.02)
	assert(bg.scroll_offset < 10.0)
	assert(current_scene.player.hit_material.get_shader_parameter("player_accent"))
	print("VISUAL_PASS_OK: all sectors rendered, sector textures, original hostile visuals and collision preserved")
	quit()

