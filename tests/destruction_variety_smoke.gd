extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(40.0).timeout.connect(func(): push_error("Destruction variety timeout"); quit(2))
	var state = root.get_node("GameState")
	state.reset()
	var assets = root.get_node("AssetDB")
	for texture in assets.desert_buildings:
		var building = load("res://scripts/SceneryObject.gd").new()
		root.add_child(building)
		building.set_texture(texture)
		building.set_visual_scale(Vector2.ONE * 0.2)
		for keep_wreck in [true, false]:
			building.reset_structure()
			# Exercise each real random branch without probabilistic test failures.
			for candidate in range(100):
				building.destruction_random.seed = candidate
				if (building.destruction_random.randf() < 0.5) == keep_wreck:
					building.destruction_random.seed = candidate
					break
			var random_before: int = building.destruction_random.state
			building.take_damage(1)
			assert(building.destruction_random.state == random_before)
			building.take_damage(building.health)
			await process_frame
			assert(building.remains.has_node("Crater"))
			assert(building.remains.has_node("BuildingWreck") == keep_wreck)
			var blast = building.remains.get_node("DestructionBlast")
			var base := clampf(maxf(building.footprint.x, building.footprint.y) * 0.5 / 65.0, 0.7, 1.5)
			assert(is_equal_approx(blast.size_multiplier, base * (1.0 if keep_wreck else 1.3)))
			var random_after: int = building.destruction_random.state
			var score_after: int = state.score
			building.take_damage(9999)
			assert(building.destruction_random.state == random_after and state.score == score_after)
			await create_timer(2.2).timeout
		building.reset_structure()
		assert(not building.destroyed and building.sprite.visible)
		building.queue_free()
	await process_frame
	print("DESTRUCTION_VARIETY_OK: both outcomes for five buildings, 30% larger crater-only blast, single roll/score, reuse")
	quit()
