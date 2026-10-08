extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var state := root.get_node("GameState")
	var vfx := root.get_node("VFX")
	await create_timer(0.5).timeout
	for kind in vfx.audio.sounds:
		var stream: AudioStreamWAV = vfx.audio.sounds[kind]
		assert(stream.data.size() > 0)
		var peak := 0
		for i in range(0, stream.data.size(), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(i)))
		assert(peak > 100 and peak < 32767, "Invalid PCM signal: " + kind)
	vfx.audio.play_sound("shot")
	vfx.audio.set_muted(true)
	for voice in vfx.audio.voices:
		assert(not voice.playing)
	vfx.audio.set_muted(false)
	scene.player._shoot()
	state.damage_player(18)
	assert(scene.player.hit_strength > 0.0)
	await create_timer(0.2).timeout
	await _capture("gameplay")
	state.add_score(state.BOSS_INTERVAL)
	await create_timer(2.0).timeout
	assert(scene.hud.boss_panel.visible)
	var boss = scene.enemy_manager.enemy_pool.active[0]
	boss.hit_strength = 0.65
	scene.player._shoot()
	await _capture("boss")
	# Pool reuse must clear the previous aircraft's damage flash.
	boss.return_to_pool()
	var recycled = scene.enemy_manager.enemy_pool.acquire()
	recycled.spawn("interceptor", Vector2(700, 240))
	assert(recycled.hit_strength == 0.0)
	state.damage_player(1000)
	await create_timer(0.7).timeout
	assert(scene.hud.game_over_overlay.visible)
	await _capture("results")
	assert(reload_current_scene() == OK)
	await create_timer(0.3).timeout
	assert(state.game_active and state.player_health == state.player_max_health)
	assert(not current_scene.hud.game_over_overlay.visible)
	assert(vfx.camera_impulse.get_connections().size() == 1)
	print("PRESENTATION_SMOKE_OK: PCM, mute, damage feedback, boss HUD, pool reset, results, restart")
	quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var picture := root.get_texture().get_image()
	assert(picture.save_png("res://artifacts/" + label + ".png") == OK)
