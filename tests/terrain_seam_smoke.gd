extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(40).timeout.connect(func(): quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.5).timeout
	scene.enemy_manager.set_process(false)
	scene.enemy_manager.enemy_pool.release_all()
	scene.background.set_process(false)
	var state = root.get_node("GameState")
	for sector in [2, 3]:
		state.advance_level()
		scene.background._process(10.0)
		scene.background.distance = 540.0
		scene.background._update_sprite_positions()
		for frame in range(3):
			scene.background.distance += 20.0
			scene.background._update_sprite_positions()
			await create_timer(0.1).timeout
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://artifacts/seams/sector-%d-wrap-%d.png" % [sector, frame]) == OK)
	print("TERRAIN_SEAM_OK: both repaired maps rendered across the wrap boundary")
	quit()
