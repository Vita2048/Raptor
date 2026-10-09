extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("Ground combat test timed out"); quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var state := root.get_node("GameState")
	var assets := root.get_node("AssetDB")
	scene.background.set_process(false)
	scene.enemy_manager.set_process(false)
	await physics_frame
	assert(assets.desert_buildings.size() == 5)
	var building = scene.world_spawner.scenery_entries[0].scenery
	# Test an actual projectile collision for every old and new building type.
	for texture in assets.desert_buildings:
		building.set_texture(texture)
		building.set_visual_scale(Vector2.ONE * 170.0 / texture.get_width())
		building.reset_structure()
		await physics_frame
		var initial_health: int = building.health
		_fire_at(scene, building.global_position + Vector2(0, building.footprint.y * 0.5 + 26))
		await create_timer(0.25).timeout
		assert(building.health < initial_health, "Player projectiles must damage every building type")
		var old_score: int = state.score
		building.take_damage(9999)
		building.take_damage(9999)
		await process_frame
		await physics_frame
		assert(building.destroyed and not building.monitorable and not building.sprite.visible)
		assert(is_instance_valid(building.remains))
		assert(state.score == old_score + int(texture.get_meta("score", 350)), "Destruction must score once")
	# Damage persists through a sector change and scrolls with the ground.
	var crater_pos: Vector2 = building.remains.global_position
	scene.world_spawner.rebuild_for_level(2)
	assert(building.destroyed)
	scene.background.distance += 25.0
	scene.background.scroll_offset = fposmod(scene.background.distance, scene.background.loop_height)
	scene.world_spawner._update_fixed_scenery()
	assert(is_equal_approx(building.remains.global_position.y, crater_pos.y + 25.0))
	scene.background._update_sprite_positions()
	# Vehicles move along their route independently of background scrolling.
	var vehicle = scene.ground_traffic.vehicles[0]
	var previous_progress: float = vehicle.progress
	await create_timer(0.3).timeout
	assert(vehicle.progress > previous_progress)
	scene.enemy_manager.enemy_bullet_pool.release_all()
	vehicle.fire_timer = 0.0
	await create_timer(0.15).timeout
	assert(vehicle.charge > 0.0)
	await create_timer(0.65).timeout
	assert(not scene.enemy_manager.enemy_bullet_pool.active.is_empty(), "Vehicle must fire")
	# A pending boss cancels the telegraph and prevents ground fire.
	scene.enemy_manager.enemy_bullet_pool.release_all()
	scene.enemy_manager.boss_pending = true
	vehicle.charge = 0.1
	await create_timer(0.3).timeout
	assert(scene.enemy_manager.enemy_bullet_pool.active.is_empty())
	scene.enemy_manager.boss_pending = false
	var vehicle_health: int = vehicle.health
	_fire_at(scene, vehicle.global_position + Vector2(0, 60))
	await create_timer(0.25).timeout
	assert(vehicle.health < vehicle_health, "Vehicle must take projectile damage")
	vehicle.take_damage(9999)
	await process_frame
	await physics_frame
	assert(vehicle.destroyed and not vehicle.monitorable and is_instance_valid(vehicle.remains))
	var stopped_progress: float = vehicle.progress
	await create_timer(0.3).timeout
	assert(vehicle.progress == stopped_progress)
	await _capture("ground-destruction")
	# Respawn only on the next terrain traversal, with no old crater or health state.
	scene.background.distance += scene.background.loop_height
	scene.world_spawner._update_fixed_scenery()
	await physics_frame
	await physics_frame
	assert(not building.destroyed and building.health == building.max_health and building.monitorable)
	assert(not vehicle.destroyed and vehicle.health == 72 and vehicle.monitorable)
	assert(not is_instance_valid(building.remains) and not is_instance_valid(vehicle.remains))
	# Place new types in two existing spawn areas for the verification image.
	for i in range(2):
		var item = scene.world_spawner.scenery_entries[i].scenery
		item.set_texture(assets.desert_buildings[i + 3])
		item.set_visual_scale(Vector2.ONE * 170.0 / item.sprite.texture.get_width())
		item.reset_structure()
	await _capture("ground-new-buildings")
	# Bring the second bridge into view and verify the armed truck independently.
	var truck = scene.ground_traffic.vehicles[1]
	scene.background.distance = scene.background.loop_height - truck.anchor_y * scene.background.image_scale + 420.0
	scene.background.scroll_offset = fposmod(scene.background.distance, scene.background.loop_height)
	scene.background._update_sprite_positions()
	await physics_frame
	await physics_frame
	assert(truck.visible and not truck.destroyed)
	var truck_progress: float = truck.progress
	await create_timer(0.25).timeout
	assert(truck.progress > truck_progress)
	scene.enemy_manager.enemy_bullet_pool.release_all()
	truck.fire_timer = 0.0
	await create_timer(0.8).timeout
	assert(not scene.enemy_manager.enemy_bullet_pool.active.is_empty())
	var truck_health: int = truck.health
	_fire_at(scene, truck.global_position + Vector2(0, 60))
	await create_timer(0.25).timeout
	assert(truck.health < truck_health)
	truck.take_damage(9999)
	await process_frame
	await physics_frame
	assert(truck.destroyed and not truck.monitorable and is_instance_valid(truck.remains))
	state.damage_player(9999)
	scene.enemy_manager.enemy_bullet_pool.release_all()
	await create_timer(1.0).timeout
	assert(scene.enemy_manager.enemy_bullet_pool.active.is_empty())
	assert(reload_current_scene() == OK)
	await create_timer(0.3).timeout
	assert(current_scene.ground_traffic.vehicles.size() == 4)
	print("GROUND_COMBAT_OK: all five structures, real projectile damage, single score, craters, scroll, sector persistence, respawn, vehicle paths/fire/damage, boss suppression, restart")
	quit()

func _fire_at(scene: Node, origin: Vector2) -> void:
	var bullet = scene.player.bullet_pool.acquire()
	bullet.launch(origin, Vector2.UP, 700.0, 18, true)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	assert(root.get_texture().get_image().save_png("res://artifacts/" + label + ".png") == OK)
