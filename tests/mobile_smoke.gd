extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _make_tap(pos: Vector2) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = pos
	return ev

func _make_drag(rel: Vector2) -> InputEventScreenDrag:
	var ev := InputEventScreenDrag.new()
	ev.relative = rel
	return ev

func _run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("Mobile test timed out"); quit(2))
	# 1. Mobile-sized HUD through the headless-test hook.
	var hud = load("res://scripts/HUD.gd").new()
	hud.force_mobile = true
	root.add_child(hud)
	await physics_frame
	assert(hud.ui_scale == 1.5)
	assert(hud.armor_panel.size.is_equal_approx(Vector2(540, 141)))
	assert(hud.score_panel.size.is_equal_approx(Vector2(477, 141)))
	assert(hud.sound_button.size.is_equal_approx(Vector2(225, 63)))
	assert(hud.boss_panel.size.is_equal_approx(Vector2(630, 108)))
	assert(hud.boss_title.size.is_equal_approx(Vector2(576, 42)))
	hud._layout_corners(Vector2(1920, 1080))
	assert(hud.armor_panel.position.is_equal_approx(Vector2(24, 24)))
	assert(hud.score_panel.position.is_equal_approx(Vector2(1419, 24)))
	assert(hud.sound_button.position.is_equal_approx(Vector2(1671, 993)))
	assert(hud.boss_panel.position.is_equal_approx(Vector2(645, 24)))
	assert(is_instance_valid(hud.menu_button) and hud.menu_button.visible)
	assert(hud.menu_button.text == "MENU")
	assert(hud.menu_button.size.is_equal_approx(Vector2(180, 72)))
	assert(hud.menu_button.position.is_equal_approx(Vector2(24, 984)))
	hud._on_menu_button()  # no PauseMenu sibling here: must be a safe no-op
	hud._on_game_over()
	assert(not hud.menu_button.visible, "menu button hides with the end-of-run overlays")
	# 1b. Mobile pause dialog: bigger, centered, no key hints.
	var menu = load("res://scripts/PauseMenu.gd").new()
	menu.force_mobile = true
	root.add_child(menu)
	await physics_frame
	assert(menu.dlg == 1.25)
	assert(menu.dialog_panel.size.is_equal_approx(Vector2(825, 600)))
	var view: Vector2 = menu.get_viewport().get_visible_rect().size
	if view.x < 1.0 or view.y < 1.0:
		view = Vector2(1920, 1080)
	assert(menu.dialog_panel.position.is_equal_approx((view - menu.dialog_panel.size) * 0.5))
	assert(menu.resume_button.text == "RESUME")
	assert(menu.resolution_buttons.is_empty(), "mobile has no resolution row at all")
	assert(menu.volume_slider.size.is_equal_approx(Vector2(725, 70)), "slider is touch-sized")
	assert(menu.mute_button.position.is_equal_approx(Vector2(50, 385)))
	assert(menu.resume_button.position.is_equal_approx(Vector2(50, 475)))
	assert(menu.exit_button.position.y == menu.resume_button.position.y, "EXIT shares RESUME row")
	assert(menu.exit_button.position.is_equal_approx(Vector2(425, 475)))
	var menu_labels: Array = menu.find_children("*", "Label", true, false)
	for label in menu_labels:
		assert(not (label as Label).text.contains("ESC"), "no ESC hints on mobile")
		assert(not (label as Label).text.contains("SCREENSHOT"), "no S/R hints on mobile")
		assert(not (label as Label).text.contains("FIXED BY"), "no fixed-resolution note on mobile")
	menu.queue_free()
	# 1c. Popups center in the real viewport on mobile, not at fixed coords.
	hud._layout_corners(Vector2(1080, 2400))  # tall portrait phone
	assert(hud.result_panel.position.is_equal_approx(Vector2(45, 907.5)))
	hud.show_boss_warning()
	hud._layout_corners(Vector2(1920, 1080))
	assert(hud.approach_panel.position.is_equal_approx(Vector2(510, 462)))
	var transit: Panel = hud.show_level_transition(1, 2)
	var live: Vector2 = hud.get_viewport().get_visible_rect().size
	assert(transit.position.is_equal_approx((live - transit.size) * 0.5))
	hud._on_campaign_completed()
	await create_timer(1.8).timeout
	hud._layout_corners(Vector2(1920, 1080))
	assert(hud.victory_panel.position.is_equal_approx(Vector2(315, -15)))
	# 2. Holding a finger down fires; releasing stops. Multi-touch safe.
	var state = root.get_node("GameState")
	var ship = load("res://scripts/PlayerShip.gd").new()
	ship.force_touch = true
	ship.position = Vector2(960, 820)
	root.add_child(ship)
	await physics_frame
	var press := _make_tap(Vector2(960, 820))
	ship._input(press)
	assert(ship._touches == 1, "press counts a held finger")
	var shots_before: int = state.shots_fired
	await create_timer(0.4).timeout
	assert(state.shots_fired > shots_before, "held finger fires the ship")
	ship._input(_make_tap(Vector2(400, 300)))
	assert(ship._touches == 2, "second finger counts too")
	var release := _make_tap(Vector2(400, 300))
	release.pressed = false
	ship._input(release)
	assert(ship._touches == 1, "releasing one finger keeps firing")
	var release_all := _make_tap(Vector2(960, 820))
	release_all.pressed = false
	ship._input(release_all)
	assert(ship._touches == 0, "releasing all fingers stops firing")
	var shots_resting: int = state.shots_fired
	await create_timer(0.3).timeout
	assert(state.shots_fired == shots_resting, "no finger means no shots")
	ship._touches = 5
	ship.reset_touch()
	assert(ship._touches == 0, "pause path re-anchors a stuck count")
	# Drag steers in canvas space, through the real canvas transform.
	var xform: Transform2D = ship.get_viewport().get_canvas_transform()
	var before: Vector2 = ship.position
	var s := xform.x.length()
	ship._input(_make_drag(Vector2(60, 0)))
	assert(ship.position.is_equal_approx(before + Vector2(60, 0) / s), "drag follows the finger in canvas space")
	print("MOBILE_OK: 1.5x HUD, menu button, hold-to-fire, drag transform")
	quit()
