extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	var lab = load("res://scenes/BossEffectsLab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	var state = root.get_node("GameState")
	var score: int = state.score
	assert(lab.effect_picker.selected == 1)
	assert(lab.boss.damage_effect.get_script() == load("res://scripts/LabRefinedDamage.gd"))
	lab.effect_picker.select(0)
	lab.effect_picker.item_selected.emit(0)
	assert(lab.boss.damage_effect.get_script() == load("res://scripts/BossDamageEffect.gd"))
	lab.effect_picker.select(1)
	lab.effect_picker.item_selected.emit(1)
	var rupture_start: int = lab.rupture_count
	lab.damage_slider.value = 75
	lab._update_ruptures(2.0)
	assert(lab.rupture_count == rupture_start, "No ruptures at exactly 25% armor")
	lab.damage_slider.value = 76
	lab._update_ruptures(2.0)
	assert(lab.rupture_count == rupture_start + 1, "Ruptures start below 25% armor")
	for i in range(8):
		lab._update_ruptures(2.0)
	assert(lab.rupture_count == rupture_start + 3, "Concurrent hull blasts must remain bounded")
	lab.rupture_toggle.button_pressed = false
	lab._update_ruptures(2.0)
	assert(lab.rupture_count == rupture_start + 3)
	lab.rupture_toggle.button_pressed = true
	lab._spawn_boss()
	# Normal game ships do not opt into this experiment.
	var gameplay_ship = load("res://scripts/EnemyShip.gd").new()
	root.add_child(gameplay_ship)
	assert(gameplay_ship.damage_effect.get_script() == load("res://scripts/BossDamageEffect.gd"))
	gameplay_ship.free()
	assert(lab.move_toggle.button_pressed, "Movement should be visible immediately")
	lab.move_toggle.button_pressed = false
	var stopped: Vector2 = lab.boss.position
	lab._process(0.5)
	assert(lab.boss.position == stopped)
	lab.move_toggle.button_pressed = true
	lab.movement_speed.value = 2.0
	var previous_time: float = lab.time
	lab._process(0.25)
	assert(is_equal_approx(lab.time - previous_time, 0.5))
	lab.movement_speed.value = 1.0
	for kind in range(3):
		lab.boss_picker.select(kind)
		lab.boss_picker.item_selected.emit(kind)
		assert(lab.boss.enemy_type == ["boss", "boss2", "boss3"][kind])
		for damage in [0, 30, 50, 70, 85, 100]:
			lab.damage_slider.value = damage
			lab._process(1.0)
			assert(lab.boss.health == roundi(lab.boss.max_health * (1.0 - damage / 100.0)))
			assert(not lab.boss.is_dead)
		lab.move_toggle.button_pressed = true
		var before: Vector2 = lab.boss.position
		lab._process(0.3)
		assert(lab.boss.position.distance_to(before) > 0)
	lab.damage_slider.value = 85
	lab.boss_picker.select(1)
	lab.boss_picker.item_selected.emit(1)
	await create_timer(1.0).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/review")
		root.get_texture().get_image().save_png("res://artifacts/review/boss-effects-lab.png")
	lab.explode_button.pressed.emit()
	assert(lab.exploding and not lab.boss.visible and lab.explode_button.disabled)
	await create_timer(0.24).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/review/boss-effects-lab-explosion.png")
	await create_timer(3.2).timeout
	assert(not lab.exploding and lab.boss.visible and not lab.explode_button.disabled)
	assert(state.score == score and state.bosses_destroyed == 0)
	print("BOSS_EFFECTS_LAB_OK: boss selection, damage slider, movement, explosion replay, no gameplay side effects")
	quit()
