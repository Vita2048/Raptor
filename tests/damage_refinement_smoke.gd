extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(15.0).timeout.connect(func(): push_error("Damage preview timeout"); quit(2))
	root.size = Vector2i(1920, 1080)
	var backdrop := ColorRect.new()
	backdrop.color = Color("34342e")
	backdrop.size = Vector2(1920, 1080)
	root.add_child(backdrop)
	var state = root.get_node("GameState")
	state.game_active = true
	var assets = root.get_node("AssetDB")
	for i in range(2):
		var building = load("res://scripts/SceneryObject.gd").new()
		root.add_child(building)
		building.position = Vector2(570 + i * 780, 270)
		building.set_texture(assets.desert_buildings[0])
		building.set_visual_scale(Vector2.ONE * 0.34)
		building.reset_structure()
		if i == 1:
			# Fix the random outcome for this wreck-art verification.
			for candidate in range(100):
				building.destruction_random.seed = candidate
				if building.destruction_random.randf() < 0.5:
					building.destruction_random.seed = candidate
					break
			building.take_damage(building.health)
			await process_frame
			var crater = building.remains.get_node("Crater")
			var wreck = building.remains.get_node("BuildingWreck")
			assert(crater.texture == assets.crater_texture)
			assert(wreck.scale == building.sprite.scale)
		_label(Vector2(380 + i * 780, 30), "INTACT BUNKER" if i == 0 else "WRECK + ORIGINAL CRATER")
	var previous_smoke := -1.0
	var previous_fire := -1.0
	for i in range(5):
		var boss = load("res://scripts/EnemyShip.gd").new()
		root.add_child(boss)
		boss.spawn("boss3", Vector2(200 + i * 380, 795))
		boss.set_physics_process(false)
		boss.scale = Vector2.ONE * 0.58
		var ratio: float = [1.0, 0.80, 0.60, 0.35, 0.10][i]
		boss.health = int(boss.max_health * ratio)
		boss._update_boss_appearance(0.016)
		assert(boss.damage_effect.smoke_strength <= 0.0241, "Damage ramps instead of popping")
		boss._update_boss_appearance(1.0)
		assert(boss.damage_effect.smoke_strength > previous_smoke)
		assert(boss.damage_effect.fire_strength >= previous_fire)
		if i == 2:
			assert(is_equal_approx(boss.damage_effect.smoke_strength, smoothstep(0.0, 1.0, (0.90 - 0.35) / 0.85)), "60% smoke must match the previous 35% state")
			assert(is_equal_approx(boss.damage_effect.fire_strength, smoothstep(0.0, 1.0, (0.50 - 0.35) / 0.45)), "60% fire must match the previous 35% state")
		previous_smoke = boss.damage_effect.smoke_strength
		previous_fire = boss.damage_effect.fire_strength
		_label(Vector2(115 + i * 380, 565), "%d%% HEALTH" % roundi(ratio * 100))
	await create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/review")
	assert(root.get_texture().get_image().save_png("res://artifacts/review/crater-progressive-damage.png") == OK)
	print("DAMAGE_REFINEMENT_OK: original crater, aligned wreck, progressive smoke/fire, eased hits")
	quit()

func _label(at: Vector2, title: String) -> void:
	var label := Label.new()
	label.position = at
	label.text = title
	label.add_theme_font_size_override("font_size", 25)
	root.add_child(label)
