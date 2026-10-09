extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Checkpoint test timed out"); quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var state = root.get_node("GameState")
	await physics_frame
	# Simulate clearing sector 1: score then advance (records checkpoint).
	state.add_score(16000)
	state.advance_level()
	assert(state.current_level == 2)
	assert(state.checkpoint_level == 2 and state.checkpoint_score == 16000)
	# Die in sector 2.
	state.damage_player(9999)
	await create_timer(0.6).timeout
	assert(not state.game_active and not state.campaign_won)
	assert(scene.hud.play_again_button.text == "RETRY SECTOR 02")
	# FLY AGAIN must retry the same sector with checkpoint score.
	assert(reload_current_scene() == OK)
	await create_timer(0.4).timeout
	assert(state.current_level == 2, "Death must retry sector 2, got %d" % state.current_level)
	assert(state.score == 16000)
	assert(state.game_active and state.player_health == state.player_max_health)
	assert(current_scene.hud.level_label.text.contains("02"))
	# A reload while alive (pause RESTART path) must start over from sector 1.
	assert(reload_current_scene() == OK)
	await create_timer(0.4).timeout
	assert(state.current_level == 1 and state.score == 0)
	print("CHECKPOINT_OK: death retries same sector, alive reload restarts run")
	quit()
