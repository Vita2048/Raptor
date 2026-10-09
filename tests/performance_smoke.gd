extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.enemy_manager.set_process(false)
	await process_frame
	var timings := {}
	for kind in ["boss", "boss2", "boss3"]:
		var enemy = scene.enemy_manager.enemy_pool.acquire()
		var started := Time.get_ticks_usec()
		enemy.spawn(kind, Vector2(960, 280))
		timings[kind] = (Time.get_ticks_usec() - started) / 1000.0
		enemy.return_to_pool()
	var blast = load("res://scenes/ExplosionEffect.tscn").instantiate()
	scene.add_child(blast)
	blast.position = Vector2(960, 540)
	blast.configure(true)
	blast.burst()
	await create_timer(0.2).timeout
	var emitters: int = blast.shockwave_layer.get_child_count() + blast.smoke_layer.get_child_count()
	assert(emitters == 2, "Explosions should use two batched emitters")
	assert(blast.shockwave_layer.get_child(0) is CPUParticles2D)
	assert(blast.smoke_layer.get_child(0).amount >= 16)
	print("PERF_RESULT boss_spawn_ms=", timings, " explosion_emitters=", emitters)
	await create_timer(2.0).timeout
	quit()
