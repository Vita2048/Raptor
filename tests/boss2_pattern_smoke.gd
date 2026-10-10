extends SceneTree

var volleys: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _record(origin: Vector2, directions: Array, speed: float, damage: int) -> void:
	volleys.append({"origin": origin, "directions": directions.duplicate(), "speed": speed, "damage": damage})

func _run() -> void:
	create_timer(20.0).timeout.connect(func(): push_error("Boss 2 pattern timeout"); quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var manager = scene.enemy_manager
	manager.set_process(false)
	scene.ground_traffic.set_process(false)
	scene.player.set_physics_process(false)
	var boss = manager.enemy_pool.acquire()
	boss.spawn("boss2", Vector2(960, 280))
	boss.set_physics_process(false)
	boss.request_fire.connect(_record)
	assert(boss.max_health == 5200 and boss.fire_interval == 0.01)
	for furious in [false, true]:
		boss.health = 2000 if furious else boss.max_health
		boss.volley_index = 0
		for step in range(6):
			scene.player.position = Vector2(1200, 900)
			boss._begin_boss_charge()
			assert(is_equal_approx(boss.charge_duration, 0.30 if furious else 0.38))
			var locked: Vector2 = boss.boss2_locked_aim
			scene.player.position = Vector2(450, 900)
			boss._fire_pattern()
			var shot: Dictionary = volleys.back()
			assert(shot.damage == 22 and shot.speed == (590.0 if furious else 540.0))
			if step % 2 == 0:
				assert(shot.directions.size() == 6)
				var gap: float = [-32.0, 32.0, 0.0][step / 2]
				for direction in shot.directions:
					assert(absf(rad_to_deg(Vector2.DOWN.angle_to(direction)) - gap) > 16.01)
			else:
				assert(shot.directions.size() == (5 if furious else 3))
				assert(shot.directions[shot.directions.size() / 2].is_equal_approx(locked), "Aim must not track the player after charge")
			assert(is_equal_approx(boss._boss_volley_recovery(), 0.65 if step == 5 else 0.01))
			manager.enemy_bullet_pool.release_all()
	# Exercise real charge + recovery scheduling at 60 Hz.
	boss.spawn("boss2", Vector2(960, 280))
	boss.set_physics_process(false)
	boss.fire_timer = 0.0
	volleys.clear()
	for frame in range(195):
		boss._physics_process(1.0 / 60.0)
	assert(volleys.size() == 6, "Six volleys followed by a recovery window, not 100 volleys/sec")
	manager.enemy_bullet_pool.release_all()
	boss.spawn("boss", Vector2(960, 280))
	assert(boss.max_health == 3800 and is_equal_approx(boss._boss_charge_time(), 0.42))
	boss.spawn("boss3", Vector2(960, 280))
	assert(is_equal_approx(boss._boss_charge_time(), 0.55))
	assert(is_equal_approx(boss.fire_interval, 0.35))
	boss.spawn("boss2", Vector2(960, 280))
	assert(boss.volley_index == 0 and boss.boss2_locked_aim == Vector2.DOWN)
	boss._fire_pattern()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/review")
	root.get_texture().get_image().save_png("res://artifacts/review/boss2-shifting-fan.png")
	print("BOSS2_PATTERN_OK: six-step cycle, shifting escape lanes, locked aim, half-health phase, recovery, real cadence, HP and Boss 3 preserved, reuse")
	quit()
