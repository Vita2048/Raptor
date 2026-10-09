extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	return event

func _check_manifest(cap) -> void:
	# The worker finalizes asynchronously: poll briefly for the manifest.
	var manifest_path: String = cap._session_dir + "/manifest.txt"
	for i in range(100):
		if FileAccess.file_exists(manifest_path):
			break
		await create_timer(0.1).timeout
	assert(FileAccess.file_exists(manifest_path), "manifest must exist")
	var manifest := FileAccess.get_file_as_string(manifest_path)
	assert(manifest.contains("fps=30"))
	assert(manifest.contains("frames=") and manifest.contains("dropped="))

func _cleanup_session(cap) -> void:
	var dir: String = cap._session_dir
	var access := DirAccess.open(dir)
	if access != null:
		for file in access.get_files():
			DirAccess.remove_absolute(dir + "/" + file)
	DirAccess.remove_absolute(dir)

func _run() -> void:
	create_timer(40.0).timeout.connect(func(): push_error("Capture test timed out"); quit(2))
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var cap = scene.get_node("CaptureManager")
	assert(cap != null and not cap.is_recording)
	cap.auto_mux = false
	assert(cap.overlay.visible and not cap.rec_label.visible)
	# S must always respond with a toast, never a crash.
	cap._unhandled_key_input(_press(KEY_S))
	await create_timer(0.5).timeout
	assert(not cap.is_recording)
	assert(cap.toast_label.text != "")
	# R starts a real 30fps cycle where a display exists...
	cap._unhandled_key_input(_press(KEY_R))
	await create_timer(0.3).timeout
	if cap.is_recording:
		assert(cap.rec_label.visible)
		await create_timer(0.8).timeout
		assert(cap.recorded_frames + cap.dropped_frames > 0, "frames must flow at 30fps")
		assert(cap.recorded_frames + cap.dropped_frames < 150, "attempts must match ~1s of 30fps")
		cap._unhandled_key_input(_press(KEY_R))
		await create_timer(0.3).timeout
		assert(not cap.is_recording and not cap.rec_label.visible)
		await _check_manifest(cap)
		_cleanup_session(cap)
	else:
		# ...and degrades gracefully where capture is unsupported.
		assert(cap.toast_label.text != "")
		cap.start_recording(true)
		assert(cap.is_recording)
		await create_timer(0.6).timeout
		cap.stop_recording()
		assert(not cap.is_recording)
		await _check_manifest(cap)
		_cleanup_session(cap)
	print("CAPTURE_OK: S/R keys, 30fps cycle, manifest, graceful fallback")
	quit()
