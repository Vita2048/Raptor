extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2))
	var scene = load("res://scenes/ExplosionEffect.tscn")
	var blast = scene.instantiate()
	root.add_child(blast)
	blast.configure(false)
	blast.set_process(false)
	blast._play_fireball()
	# Equal elapsed time must give equal playback at different render rates.
	for step in range(30):
		blast._process(1.0 / 60.0)
	var texture = blast.fireball_sprite.texture
	var opacity: float = blast.fireball_sprite.modulate.a
	var size: Vector2 = blast.fireball_sprite.scale
	blast._play_fireball()
	for step in range(15):
		blast._process(1.0 / 30.0)
	assert(blast.fireball_sprite.texture == texture)
	assert(is_equal_approx(blast.fireball_sprite.modulate.a, opacity))
	assert(blast.fireball_sprite.scale.is_equal_approx(size))
	assert(blast.fireball_next.modulate.a > 0 and opacity > 0, "Adjacent frames should overlap")
	blast._process(0.56)
	assert(not blast.fireball_sprite.visible and not blast.fireball_next.visible)
	blast.queue_free()
	var vfx = root.get_node("VFX")
	var baseline: int = vfx.get_child_count()
	vfx.boss_explosion(Vector2(960, 540))
	await create_timer(0.35).timeout
	var large := 0
	for child in vfx.get_children():
		if child.get_script() == load("res://scripts/ExplosionEffect.gd"):
			assert(child.large_scale, "Boss finale must use large blasts")
			large += 1
	assert(large == 7, "Boss finale must restore the wide seven-blast detonation")
	assert(vfx.has_node("BossScreenBlast"), "Boss finale needs its expanding flash")
	await create_timer(2.8).timeout
	assert(vfx.get_child_count() == baseline, "Every finale effect must clean up")
	print("EXPLOSION_TIMING_OK: regular 30/60fps playback unchanged, giant boss finale, cleanup")
	quit()
