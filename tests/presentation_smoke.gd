extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(40.0).timeout.connect(func(): push_error("Presentation test timed out"); quit(2))
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
	var assets := root.get_node("AssetDB")
	assert(assets.desert_buildings.size() == 3)
	for texture in assets.desert_buildings:
		assert(texture.atlas.get_image().get_pixel(0, 0).a < 0.01, "Building background must be transparent")
	var spawner = scene.world_spawner
	assert(spawner.scenery_entries.size() == assets.spawn_area_defs.size())
	var first_entry: Dictionary = spawner.scenery_entries[0]
	var old_texture: Texture2D = first_entry.scenery.sprite.texture
	var old_y: float = first_entry.scenery.position.y
	scene.background.distance += 20.0
	spawner._update_fixed_scenery()
	assert(first_entry.scenery.sprite.texture == old_texture)
	assert(is_equal_approx(first_entry.scenery.position.y, old_y + 20.0))
	scene.background.distance += spawner.loop_height
	spawner._update_fixed_scenery()
	assert(first_entry.scenery.sprite.texture != old_texture)
	for entry in spawner.scenery_entries:
		var available: Vector2 = entry.rect.size * spawner.image_scale
		var footprint: Vector2 = entry.scenery.footprint
		assert(footprint.x <= available.x * 0.77 and footprint.y <= available.y * 0.77)
	scene.enemy_manager.spawn_timer = 0.0
	state.add_score(state.BOSS_INTERVAL)
	await create_timer(0.3).timeout
	assert(scene.enemy_manager.boss_pending)
	assert(scene.enemy_manager.enemy_pool.active.is_empty())
	assert(scene.enemy_manager.enemy_bullet_pool.active.is_empty())
	await _capture("boss-warning")
	await create_timer(1.5).timeout
	assert(scene.hud.boss_panel.visible)
	var boss = scene.enemy_manager.enemy_pool.active[0]
	assert(boss.entrance_remaining > 0.0 and not boss.monitorable)
	assert(scene.enemy_manager.enemy_bullet_pool.active.is_empty())
	await create_timer(2.5).timeout
	assert(boss.entrance_remaining == 0.0 and boss.monitorable)
	boss.fire_timer = 0.0
	await create_timer(0.15).timeout
	assert(boss.charge_remaining > 0.0)
	await _capture("boss-charge")
	await create_timer(0.5).timeout
	assert(not scene.enemy_manager.enemy_bullet_pool.active.is_empty())
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
	state.add_score(state.BOSS_INTERVAL)
	await create_timer(0.2).timeout
	state.damage_player(1000)
	await create_timer(1.8).timeout
	assert(current_scene.enemy_manager.enemy_pool.active.is_empty(), "Boss must not spawn after death during warning")
	assert(reload_current_scene() == OK)
	await create_timer(0.2).timeout
	state.advance_level()
	state.add_score(state.BOSS_INTERVAL)
	await create_timer(4.3).timeout
	var second_boss = current_scene.enemy_manager.enemy_pool.active[0]
	assert(second_boss.enemy_type == "boss2" and second_boss.entrance_remaining == 0.0)
	print("PRESENTATION_SMOKE_OK: transparent buildings, area fit, offscreen variation, boss warning, entrance, charge, cancellation, both bosses, PCM, mute, feedback, restart")
	quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var picture := root.get_texture().get_image()
	assert(picture.save_png("res://artifacts/" + label + ".png") == OK)
