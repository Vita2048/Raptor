extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Resolution test timed out"); quit(2))
	var menu_script = load("res://scripts/PauseMenu.gd")
	assert(menu_script.parse_resolution("1280x720") == Vector2i(1280, 720))
	assert(menu_script.parse_resolution("nope") == Vector2i(-1, -1))
	assert(menu_script.resolution_to_string(Vector2i(1600, 900)) == "1600x900")
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	assert(scene.pause_menu.resolution_buttons.size() == 3)
	# Apply persists and takes effect; restore the default afterwards.
	menu_script.apply_resolution(Vector2i(1280, 720))
	assert(DisplayServer.window_get_size() == Vector2i(1280, 720))
	assert(menu_script.saved_resolution() == Vector2i(1280, 720))
	scene.pause_menu._refresh_resolution_buttons()
	assert(scene.pause_menu.resolution_buttons[2].text.begins_with("✓"))
	menu_script.apply_resolution(Vector2i(1920, 1080))
	assert(DisplayServer.window_get_size() == Vector2i(1920, 1080))
	assert(menu_script.saved_resolution() == Vector2i(1920, 1080))
	print("RESOLUTION_OK: parse, apply, persist, highlight, restore")
	quit()
