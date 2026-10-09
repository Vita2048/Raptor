extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check_corners(hud, view: Vector2, rect_pos: Vector2, rect_size: Vector2) -> void:
	hud._layout_corners(view)
	assert(hud.armor_panel.position.is_equal_approx(rect_pos + Vector2(16, 16)))
	assert(hud.score_panel.position.is_equal_approx(Vector2(
		rect_pos.x + rect_size.x - 16.0 - 318.0, rect_pos.y + 16.0)))
	assert(hud.sound_button.position.is_equal_approx(Vector2(
		rect_pos.x + rect_size.x - 16.0 - 150.0, rect_pos.y + rect_size.y - 16.0 - 42.0)))
	assert(hud.boss_panel.position.is_equal_approx(Vector2(
		rect_pos.x + (rect_size.x - 600.0) * 0.5, rect_pos.y + 16.0)))

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("HUD layout test timed out"); quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var hud = scene.hud
	# Native 16:9: projected rect is the full viewport.
	_check_corners(hud, Vector2(1920, 1080), Vector2.ZERO, Vector2(1920, 1080))
	# Ultrawide: margins measured from the centered 1920-wide playfield.
	_check_corners(hud, Vector2(2560, 1080), Vector2(320, 0), Vector2(1920, 1080))
	# Narrower than design: projected rect clamps to the viewport itself.
	_check_corners(hud, Vector2(1280, 800), Vector2.ZERO, Vector2(1280, 800))
	# Desktop popups keep their fixed design coordinates.
	assert(hud.result_panel.position.is_equal_approx(Vector2(630, 324)))
	hud.show_boss_warning()
	assert(hud.approach_panel.position.is_equal_approx(Vector2(660, 160)))
	# Live path follows the real viewport size without errors.
	hud._refresh_layout()
	print("HUD_LAYOUT_OK: margins measured from the projected game rectangle")
	quit()
