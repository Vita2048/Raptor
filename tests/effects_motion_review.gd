extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	root.size = Vector2i(1280, 720)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1920, 1080)
	backdrop.color = Color("18212b")
	root.add_child(backdrop)
	root.get_node("GameState").game_active = true
	var boss = load("res://scripts/EnemyShip.gd").new()
	root.add_child(boss)
	boss.spawn("boss2", Vector2(400, 380))
	boss.set_physics_process(false)
	boss.health = int(boss.max_health * 0.15)
	boss._update_boss_appearance(1.0)
	var tween: Tween = boss.create_tween().set_loops()
	tween.tween_property(boss, "position:x", 720.0, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(boss, "position:x", 400.0, 0.9).set_trans(Tween.TRANS_SINE)
	await create_timer(0.8).timeout
	await _capture("moving-flames")
	await create_timer(0.9).timeout
	await _capture("moving-flames-return")
	var pos: Vector2 = boss.position
	boss.queue_free()
	root.get_node("VFX").boss_explosion(pos, 0.7)
	await create_timer(0.22).timeout
	await _capture("boss-ruptures")
	await create_timer(0.4).timeout
	await _capture("boss-core-blast")
	await create_timer(0.65).timeout
	await _capture("boss-blast-decay")
	await create_timer(2.0).timeout
	print("EFFECTS_MOTION_REVIEW_OK")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/review")
	assert(root.get_texture().get_image().save_png("res://artifacts/review/" + filename + ".png") == OK)
