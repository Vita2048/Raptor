extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(40.0).timeout.connect(func(): push_error("Campaign test timed out"); quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var state = root.get_node("GameState")
	var manager = scene.enemy_manager
	manager.set_process(false)
	scene.background.set_process(false)
	await physics_frame
	var elapsed: float = state.elapsed_seconds
	paused = true
	await create_timer(0.15).timeout
	assert(state.elapsed_seconds == elapsed, "Paused time must not count")
	paused = false
	# Exercise both existing boss death signals, rather than assigning the sector.
	for kind in ["boss", "boss2"]:
		var boss = manager.enemy_pool.acquire()
		boss.spawn(kind, Vector2(960, 240))
		state.begin_boss(boss.max_health)
		boss.take_damage(99999)
		await process_frame
	assert(state.current_level == 3 and state.bosses_destroyed == 2)
	assert(state.next_boss_score == state.score + state.BOSS_INTERVAL)
	manager._spawn_wave()
	for enemy in manager.enemy_pool.active:
		assert(enemy.enemy_type in ["lancer", "sentinel"])
	manager.enemy_pool.release_all()
	for kind in ["lancer", "sentinel"]:
		var enemy = manager.enemy_pool.acquire()
		enemy.spawn(kind, Vector2(700, 450))
		enemy.set_physics_process(false)
		enemy.health = 18
		await physics_frame
		var bullet = scene.player.bullet_pool.acquire()
		bullet.launch(Vector2(700, 550), Vector2.UP, 700.0, 18, true)
		await create_timer(0.3).timeout
		assert(enemy.is_dead, "New ship must take real projectile damage")
	assert(state.ships_destroyed == 2)
	state.add_score(state.next_boss_score - state.score)
	manager.set_process(true)
	await create_timer(4.3).timeout
	assert(manager.enemy_pool.active.size() == 1)
	var final_boss = manager.enemy_pool.active[0]
	assert(final_boss.enemy_type == "boss3" and final_boss.entrance_remaining == 0.0)
	final_boss.set_physics_process(false)
	manager.enemy_bullet_pool.release_all()
	final_boss.volley_index = 2
	final_boss._fire_pattern()
	assert(manager.enemy_bullet_pool.active.size() == 3)
	final_boss.health = final_boss.max_health / 2 - 1
	final_boss._fire_pattern()
	assert(is_equal_approx(final_boss.fire_interval, 0.65))
	await _capture("sector3-boss")
	manager.enemy_bullet_pool.release_all()
	final_boss.health = 18
	var bullet = scene.player.bullet_pool.acquire()
	bullet.launch(final_boss.global_position + Vector2(0, 310), Vector2.UP, 700.0, 18, true)
	await create_timer(0.65).timeout
	assert(state.campaign_won and not state.game_active)
	assert(state.bosses_destroyed == 3 and state.current_level == 3)
	assert(manager.enemy_pool.active.is_empty() and manager.enemy_bullet_pool.active.is_empty())
	var final_score: int = state.score
	elapsed = state.elapsed_seconds
	state.add_score(500)
	await create_timer(2.0).timeout
	assert(state.score == final_score and state.elapsed_seconds == elapsed)
	assert(scene.hud.victory_overlay.visible and scene.hud.victory_stats.text.contains("2 / 3"))
	await _capture("campaign-victory")
	assert(reload_current_scene() == OK)
	await create_timer(0.2).timeout
	assert(state.current_level == 1 and not state.campaign_won and state.bosses_destroyed == 0)
	assert(state.ships_destroyed == 0 and state.shots_fired == 0)
	print("CAMPAIGN_OK: three sectors, new ship collisions, final boss entrance/patterns/damage, victory, frozen stats, pause time, restart")
	quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	assert(root.get_texture().get_image().save_png("res://artifacts/" + label + ".png") == OK)
