extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Warmup test timed out"); quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var vfx = root.get_node("VFX")
	var state = root.get_node("GameState")
	# Freeze spawners so gameplay cannot borrow pool items mid-test.
	scene.enemy_manager.set_process(false)
	scene.background.set_process(false)
	await physics_frame
	assert(vfx._warmed, "Main must trigger effect warm-up on boot")
	# Let the quiet bursts finish: muzzle/spark return to pools, explosions free.
	await create_timer(3.0).timeout
	assert(vfx.muzzle_pool.inactive.size() == 32, "warmup muzzle must recycle")
	assert(vfx.impact_pool.inactive.size() == 48, "warmup spark must recycle")
	assert(vfx.get_child_count() == 1 + 32 + 48, "warmup explosions must free themselves")
	assert(state.score == 0 and state.bosses_destroyed == 0, "warmup must not touch run state")
	print("WARMUP_OK: quiet effects prebuffered, pools recycled, state untouched")
	quit()
