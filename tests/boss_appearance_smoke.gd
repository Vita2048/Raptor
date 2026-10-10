extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(20.0).timeout.connect(func(): push_error("Boss appearance test timed out"); quit(2))
	root.size = Vector2i(1920, 1080)
	var backdrop := ColorRect.new()
	backdrop.color = Color("18212b")
	backdrop.size = Vector2(1920, 1080)
	root.add_child(backdrop)
	var script = load("res://scripts/EnemyShip.gd")
	var state = root.get_node("GameState")
	state.game_active = true
	for row in range(3):
		var kind: String = ["boss", "boss2", "boss3"][row]
		for column in range(3):
			var boss = script.new()
			root.add_child(boss)
			boss.spawn(kind, Vector2(400 + column * 550, 195 + row * 340))
			boss.set_physics_process(false)
			boss.scale = Vector2.ONE * (0.60 if row == 2 else 0.75)
			assert(boss.boss_damage_stage == 0)
			boss.health = ceili(boss.max_health * 0.55)
			boss._update_boss_appearance(1.0)
			assert(boss.boss_damage_stage == 0)
			boss.take_damage(1)
			boss._update_boss_appearance(1.0)
			assert(boss.boss_damage_stage == 1)
			boss.health = ceili(boss.max_health * 0.25)
			boss._update_boss_appearance(1.0)
			assert(boss.boss_damage_stage == 1)
			boss.take_damage(1)
			boss._update_boss_appearance(1.0)
			assert(boss.boss_damage_stage == 2)
			boss.health = int(boss.max_health * [1.0, 0.45, 0.15][column])
			boss.boss_damage_blend = float(column)
			boss._update_boss_appearance(1.0)
			if row == 2:
				boss.volley_index = 0
				assert(boss._charging_wing_muzzles().size() == (0 if column == 0 else 2))
				boss.volley_index = 1
				assert(boss._charging_wing_muzzles().is_empty())
			boss.charge_remaining = -1.0
			var label := Label.new()
			label.text = kind + " — " + ["100%", "45%", "15%"][column]
			label.position = Vector2(330 + column * 550, 10 + row * 340)
			label.add_theme_font_size_override("font_size", 24)
			root.add_child(label)
	var pooled = script.new()
	root.add_child(pooled)
	pooled.spawn("boss3", Vector2(-1000, -1000))
	pooled.set_physics_process(false)
	pooled.health = 1
	pooled._update_boss_appearance(2.0)
	pooled.on_pool_released()
	pooled.spawn("interceptor", Vector2(-1000, -1000))
	assert(pooled.boss_damage_blend == 0.0 and pooled.boss_damage_stage == 0)
	assert(pooled.damage_effect.smoke_strength == 0.0 and pooled.damage_effect.particles.is_empty())
	for plume in pooled.exhaust_plumes:
		assert(plume.modulate == Color.WHITE)
	await create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/review")
	assert(root.get_texture().get_image().save_png("res://artifacts/review/boss-phases.png") == OK)
	print("BOSS_APPEARANCE_OK: thresholds, all hulls, wing telegraphs, smoke/fire, pool reset")
	quit()
