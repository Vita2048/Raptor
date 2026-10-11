extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GameState").game_active = true
	var script = load("res://scripts/EnemyShip.gd")
	for kind in ["boss", "boss2", "boss3"]:
		var boss = script.new()
		root.add_child(boss)
		boss.spawn(kind, Vector2(960, 540))
		boss.set_physics_process(false)
		var previous_fire := -1.0
		for step in range(4):
			boss.damage_effect.reset()
			boss.health = roundi(boss.max_health * [0.70, 0.50, 0.30, 0.15][step])
			boss._update_boss_appearance(1.0)
			var sources := {}
			for frame in range(180):
				boss.damage_effect._process(1.0 / 60.0)
				assert(boss.damage_effect.particles.size() <= 128)
				if frame > 120:
					for index in range(3):
						if boss.damage_effect.source_strength(index) * boss.damage_effect.fire_strength > 0.001:
							sources[index] = true
			assert(sources.size() == [1, 2, 3, 3][step], "Wrong flame sources at requested health")
			assert(boss.damage_effect.fire_strength > previous_fire, "Flames should grow stronger as armor falls")
			previous_fire = boss.damage_effect.fire_strength
		# A moving/turning/scaled hull must carry the flame base exactly with it.
		for frame in range(120):
			boss.position += Vector2(3.0, sin(float(frame) * 0.1))
			boss.rotation = sin(float(frame) * 0.04) * 0.15
			boss.damage_effect._process(1.0 / 60.0)
			var layer = boss.damage_effect.realistic_layer
			layer._process(1.0 / 60.0)
			for index in range(3):
				var emitter = layer.flame_emitters[index]
				assert(emitter.rotation == 0.0)
				assert(emitter.local_coords)
				assert(emitter.position == boss.damage_effect.sites[index] + Vector2(0, -16))
				assert(layer.core_emitters[index].local_coords)
				assert(layer.core_emitters[index].position == boss.damage_effect.sites[index] + Vector2(0, -9))
				assert(not layer.tongue_emitters[index * 2].local_coords)
				assert(not layer.tongue_emitters[index * 2 + 1].local_coords)
			for particle in boss.damage_effect.particles:
				assert(not particle.has("fire"), "Whole flames must never enter the drifting particle system")
			assert(absf(boss.damage_effect.flame_lean) <= 1.05)
		# The plume reverses direction with travel, without rotating its root away.
		boss.rotation = 0.0
		for direction in [1.0, -1.0]:
			for frame in range(90):
				boss.position.x += direction * 4.0
				boss.damage_effect._process(1.0 / 60.0)
			assert(boss.damage_effect.flame_lean * direction < -0.5)
		# Each new source eases in rather than switching on at full opacity.
		for index in range(3):
			boss.damage_effect.damage_amount = 0.25 + index * 0.20
			assert(is_equal_approx(boss.damage_effect.source_strength(index), 0.5))
		# Gameplay hull ruptures start strictly below the armor threshold.
		boss.damage_effect.reset()
		boss.health = roundi(boss.max_health * 0.25)
		boss.damage_effect._update_ruptures(2.0)
		assert(boss.damage_effect.rupture_count == 0)
		boss.health -= 1
		boss.damage_effect._update_ruptures(2.0)
		assert(boss.damage_effect.rupture_count == 1)
		boss.is_dead = true
		boss.damage_effect._update_ruptures(2.0)
		assert(boss.damage_effect.rupture_count == 1, "Dead bosses must not emit hull blasts")
		boss.on_pool_released()
		assert(not is_instance_valid(boss.damage_effect.realistic_layer))
		assert(boss.damage_effect.particles.is_empty() and boss.damage_effect.damage_amount == 0)
		assert(boss.damage_effect.hull_velocity == Vector2.ZERO)
		assert(boss.damage_effect.get_child_count() == 0, "Pooled bosses must not retain hull blasts")
		boss.queue_free()
	print("BOSS_DAMAGE_PROGRESSION_OK: all bosses, 70/50/30/15%, 1/2/3/3 flames, increasing intensity, smooth source fades, bounded sustained emission, pool reset")
	quit()
