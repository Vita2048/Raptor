extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(25.0).timeout.connect(func(): push_error("Boss debug test timed out"); quit(2))
	var options = load("res://scripts/DebugOptions.gd")
	assert(options.matches([], "?debug=final-boss"))
	assert(options.matches([], "?other=1&debug=final%2Dboss"))
	assert(not options.matches([], "?debug=false"))
	assert(not options.matches([], ""))
	assert(options.final_boss_requested(), "Run with -- --debug-final-boss")
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var state = root.get_node("GameState")
	var manager = scene.enemy_manager
	assert(state.current_level == 3 and manager.boss_pending and state.score == 0)
	assert(state.bosses_destroyed == 0)
	await create_timer(4.2).timeout
	assert(manager.enemy_pool.active.size() == 1)
	var boss = manager.enemy_pool.active[0]
	assert(boss.enemy_type == "boss3" and boss.max_health == 7000)
	assert(boss.entrance_remaining == 0.0)
	boss.set_physics_process(false)
	manager.enemy_bullet_pool.release_all()
	boss.volley_index = 1
	scene.player.position = Vector2(1400, 900)
	boss._fire_pattern()
	assert(manager.enemy_bullet_pool.active.size() == 5)
	var aimed = manager.enemy_bullet_pool.active[2]
	var expected: Vector2 = (scene.player.position - aimed.position).normalized()
	assert(aimed.velocity.normalized().dot(expected) > 0.999)
	assert(aimed.damage == 80)
	manager.enemy_bullet_pool.release_all()
	boss.health = 5000
	boss.volley_index = 0
	boss._fire_pattern()
	assert(manager.enemy_bullet_pool.active.size() == 12, "Two wing shots plus ten fan shots")
	assert(boss.fire_interval == 0.22)
	manager.enemy_bullet_pool.release_all()
	boss.health = 2000
	boss._fire_pattern()
	assert(boss.fire_interval == 0.12)
	manager.enemy_bullet_pool.release_all()
	var bullet = manager.enemy_bullet_pool.acquire()
	bullet.launch(scene.player.position - Vector2(0, 100), Vector2.DOWN, 510.0, 80, false)
	await create_timer(0.2).timeout
	assert(state.player_health == 92, "Final boss projectile should remove eight armor")
	assert(reload_current_scene() == OK)
	await create_timer(0.2).timeout
	assert(state.current_level == 3 and current_scene.enemy_manager.boss_pending)
	print("FINAL_BOSS_OK: URL/CLI parsing, direct entrance, phase patterns, aimed fire, effective damage, debug replay")
	quit()
