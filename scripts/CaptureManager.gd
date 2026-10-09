extends Node
## Desktop-only capture controls.
## S takes a PNG screenshot at native viewport resolution.
## R toggles 30fps recording (JPG sequence + manifest, plus a background MP4
## encode when ffmpeg is on PATH).
## Created from Main; keeps working while paused (PROCESS_MODE_ALWAYS).
##
## Performance design: the game thread only does the viewport readback (a few
## ms). JPEG encoding and file writes run on a worker thread, so gameplay stays
## fluent while recording. Frames are only dropped if the worker falls far
## behind (counted in dropped_frames and the manifest).

const CAPTURE_FPS := 30.0
const CAPTURE_INTERVAL := 1.0 / CAPTURE_FPS
const JPEG_QUALITY := 0.85
const MAX_FRAMES := 5400  # 3 minutes at 30fps, bounds disk usage
# Recording resolution scale: 1.0 keeps full native resolution, 0.5 records at
# half width/height (quarter pixels, much cheaper) if the machine struggles.
const RECORD_SCALE := 1.0
# Backstop so a stalled worker cannot grow memory without bound.
const MAX_QUEUE := 60
# Projected playfield: the REC indicator shares the HUD corner margin from it.
const PROJECTED_SIZE := Vector2(1920, 1080)
const CORNER := 16.0
const REC_RED := Color("ff5a5a")
const WHITE := Color("e8efed")

static func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

var ui_scale := 1.0

var overlay: CanvasLayer
var rec_label: Label
var toast_label: Label
var _toast_tween: Tween

var is_recording := false
var recorded_frames := 0
var dropped_frames := 0
# Set to false in tests so no background ffmpeg process outlives the run.
var auto_mux := true

var _session_dir := ""
var _session_size := Vector2i.ZERO
var _capture_accum := 0.0
var _capture_pending := false
var _record_elapsed := 0.0
var _rec_tick := 0.0
var _taking_shot := false
var _pushed := 0
var _saving := false

var _worker := Thread.new()
var _mutex := Mutex.new()
var _sem := Semaphore.new()
var _queue: Array = []
var _thread_exit := false
# ffmpeg probe cache: 0 = unknown, 1 = available, 2 = missing.
var _ffmpeg_state := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_mobile():
		ui_scale = 1.5
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	_build_overlay()
	get_tree().root.size_changed.connect(_refresh_rec_position)
	_refresh_rec_position()
	_worker.start(_worker_loop)

func _exit_tree() -> void:
	# Scene reload or quit mid-recording: stop the worker, keep what we have.
	_mutex.lock()
	_thread_exit = true
	dropped_frames += _queue.size()
	_queue.clear()
	_mutex.unlock()
	_sem.post()
	_worker.wait_to_finish()
	is_recording = false
	if _session_dir == "" or not DirAccess.dir_exists_absolute(_session_dir):
		return
	if _pushed > 0:
		_write_manifest()
		if auto_mux:
			_try_mux_mp4()

func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_S or key_event.physical_keycode == KEY_S:
		get_viewport().set_input_as_handled()
		take_screenshot()
	elif key_event.keycode == KEY_R or key_event.physical_keycode == KEY_R:
		get_viewport().set_input_as_handled()
		toggle_recording()

func _process(delta: float) -> void:
	if not is_recording:
		return
	if get_tree().paused:
		return
	_record_elapsed += delta
	_rec_tick += delta
	if _rec_tick >= 0.25:
		_rec_tick = 0.0
		_refresh_rec_label()
	_capture_accum += delta
	if _capture_accum < CAPTURE_INTERVAL:
		return
	if _capture_accum > CAPTURE_INTERVAL * 4.0:
		# Big hitch: resync instead of burst-capturing stale frames.
		_mutex.lock()
		dropped_frames += int(_capture_accum / CAPTURE_INTERVAL) - 1
		_mutex.unlock()
		_capture_accum = 0.0
		return
	_capture_accum -= CAPTURE_INTERVAL
	_capture_pending = true

func _on_frame_post_draw() -> void:
	# Viewport readback is only valid at the frame boundary. This is the only
	# recording work on the game thread: a fast copy, encoding happens async.
	if not _capture_pending:
		return
	_capture_pending = false
	if not is_recording or get_tree().paused:
		return
	if _pushed >= MAX_FRAMES:
		stop_recording()
		_toast("Recording auto-stopped at 3 min limit  " + _session_dir)
		return
	var img := _capture_image()
	_mutex.lock()
	if img == null:
		dropped_frames += 1
	elif _queue.size() >= MAX_QUEUE:
		dropped_frames += 1
	else:
		_queue.push_back({"idx": _pushed, "img": img})
		_pushed += 1
		_sem.post()
	_mutex.unlock()

func _worker_loop() -> void:
	while true:
		_sem.wait()
		_mutex.lock()
		if _thread_exit:
			_mutex.unlock()
			break
		if _queue.is_empty():
			var done := _saving
			_saving = false
			_mutex.unlock()
			if done:
				call_deferred("_on_session_finalized")
			continue
		var job: Dictionary = _queue.pop_front()
		_mutex.unlock()
		_save_job(job)

func _save_job(job: Dictionary) -> void:
	var img: Image = job["img"]
	if RECORD_SCALE < 1.0:
		var w := maxi(1, int(img.get_width() * RECORD_SCALE))
		var h := maxi(1, int(img.get_height() * RECORD_SCALE))
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var path: String = "%s/frame_%05d.jpg" % [_session_dir, int(job["idx"])]
	var ok := img.save_jpg(path, JPEG_QUALITY) == OK
	_mutex.lock()
	if ok:
		recorded_frames += 1
	else:
		dropped_frames += 1
	_mutex.unlock()

func toggle_recording() -> void:
	if is_recording:
		stop_recording()
	else:
		start_recording()

func start_recording(bypass_platform_check := false) -> void:
	# bypass_platform_check is a headless-test hook; gameplay always checks.
	if is_recording:
		return
	if _saving:
		_toast("Finishing previous recording, try in a moment")
		return
	if not bypass_platform_check and not _platform_ok():
		_toast("Recording is only available on Desktop")
		return
	_session_dir = "user://recordings/REC_" + _timestamp()
	# Two sessions started within the same second (or a live user session
	# colliding with a test run) must never share a folder.
	var suffix := 1
	while DirAccess.dir_exists_absolute(_session_dir) and not _dir_is_empty(_session_dir):
		suffix += 1
		_session_dir = "user://recordings/REC_" + _timestamp() + "_%d" % suffix
	if DirAccess.make_dir_recursive_absolute(_session_dir) != OK:
		_toast("Recording failed: cannot create folder")
		_session_dir = ""
		return
	var vp := get_viewport()
	var view_size := Vector2.ZERO
	if vp != null:
		view_size = vp.get_visible_rect().size
	_session_size = Vector2i(view_size * RECORD_SCALE)
	recorded_frames = 0
	dropped_frames = 0
	_pushed = 0
	_record_elapsed = 0.0
	_capture_accum = 0.0
	_capture_pending = false
	_rec_tick = 0.0
	is_recording = true
	rec_label.visible = true
	_refresh_rec_label()
	VFX.audio.play_sound("charge")
	_toast("Recording  30fps native  " + _session_dir)

func stop_recording() -> void:
	if not is_recording:
		return
	is_recording = false
	_capture_pending = false
	if is_instance_valid(rec_label):
		rec_label.visible = false
	_mutex.lock()
	var pushed: int = _pushed
	_mutex.unlock()
	if pushed <= 0:
		_toast("Recording stopped, no frames captured")
		return
	_mutex.lock()
	_saving = true
	var queued: int = _queue.size()
	_mutex.unlock()
	_sem.post()
	VFX.audio.play_sound("impact")
	_toast("Recording stopped, saving %d frames in background…" % queued)

func _on_session_finalized() -> void:
	# Runs on the main thread once the worker drained the stopped session.
	_write_manifest()
	VFX.audio.play_sound("impact")
	var msg := "Video saved  %d frames  %s" % [recorded_frames, _session_dir]
	if auto_mux:
		if _ffmpeg_available():
			if _try_mux_mp4():
				msg += "  (MP4 encoding started)"
		else:
			msg += "  (MP4 skipped: ffmpeg not found)"
	_toast(msg)

func take_screenshot() -> void:
	if _taking_shot:
		return
	_taking_shot = true
	overlay.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _capture_image()
	overlay.visible = true
	_taking_shot = false
	if img == null:
		_toast("Screenshot unavailable on this platform")
		return
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/screenshot_" + _timestamp() + ".png"
	if img.save_png(path) == OK:
		VFX.audio.play_sound("impact")
		_toast("Screenshot saved  " + path)
	else:
		_toast("Screenshot failed to save")

func _platform_ok() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios"):
		return false
	return true

func _capture_image() -> Image:
	if not _platform_ok():
		return null
	var vp := get_viewport()
	if vp == null:
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty() or img.get_width() <= 0 or img.get_height() <= 0:
		return null
	return img

func _dir_is_empty(dir: String) -> bool:
	var access := DirAccess.open(dir)
	if access == null:
		return true
	return access.get_files().is_empty() and access.get_directories().is_empty()

func _timestamp() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d-%02d-%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]]

func _write_manifest() -> void:
	if _session_dir == "":
		return
	var f := FileAccess.open(_session_dir + "/manifest.txt", FileAccess.WRITE)
	if f == null:
		return
	f.store_line("# Raptor Shadow Run capture manifest")
	f.store_line("fps=30")
	f.store_line("scale=%.2f" % RECORD_SCALE)
	f.store_line("seconds=%.1f" % _record_elapsed)
	f.store_line("size=%dx%d" % [_session_size.x, _session_size.y])
	f.store_line("frames=%d" % recorded_frames)
	f.store_line("dropped=%d" % dropped_frames)
	f.store_line("pattern=frame_%05d.jpg")
	if _ffmpeg_available():
		f.store_line("mp4=auto-encoded on stop when ffmpeg is on PATH")
	else:
		f.store_line("mp4=skipped, ffmpeg not found on PATH (install it, then rerun the command below)")
	f.store_line("ffmpeg -framerate 30 -i frame_%05d.jpg -c:v libx264 -pix_fmt yuv420p -crf 20 recording.mp4")
	f.close()

func _ffmpeg_binary() -> String:
	return "ffmpeg.exe" if OS.has_feature("windows") else "ffmpeg"

func _ffmpeg_available() -> bool:
	if _ffmpeg_state == 0:
		var probe_out: Array = []
		OS.execute(_ffmpeg_binary(), ["-version"], probe_out, true, false)
		_ffmpeg_state = 1 if not probe_out.is_empty() else 2
	return _ffmpeg_state == 1

func _try_mux_mp4() -> bool:
	if recorded_frames <= 0 or _session_dir == "":
		return false
	if not _ffmpeg_available():
		return false
	var src := ProjectSettings.globalize_path(_session_dir)
	var args := PackedStringArray(["-y", "-framerate", "30", "-i",
		src.path_join("frame_%05d.jpg"), "-c:v", "libx264",
		"-pix_fmt", "yuv420p", "-crf", "20", src.path_join("recording.mp4")])
	return OS.create_process(_ffmpeg_binary(), args, false) > 0

func _refresh_rec_label() -> void:
	var total := int(_record_elapsed)
	_mutex.lock()
	var frames := recorded_frames
	_mutex.unlock()
	rec_label.text = "● REC %02d:%02d  30fps  %df" % [total / 60, total % 60, frames]

func _refresh_rec_position() -> void:
	# Bottom-left corner of the projected game rectangle, like the other HUDs.
	# On mobile the settings gear owns that corner, so REC sits above it.
	var view := PROJECTED_SIZE
	var vp := get_viewport()
	if vp != null:
		var visible := vp.get_visible_rect().size
		if visible.x >= 1.0 and visible.y >= 1.0:
			view = visible
	var margin := CORNER * ui_scale
	var lift := (72.0 + 10.0) * ui_scale if is_mobile() else 0.0
	var rect_size := Vector2(minf(PROJECTED_SIZE.x, view.x), minf(PROJECTED_SIZE.y, view.y))
	var rect_pos := (view - rect_size) * 0.5
	rec_label.position = Vector2(
		rect_pos.x + margin,
		rect_pos.y + rect_size.y - margin - rec_label.size.y - lift)

func _toast(text: String) -> void:
	if toast_label == null or not is_instance_valid(toast_label):
		return
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = toast_label.create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.name = "CaptureOverlay"
	overlay.layer = 30
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	rec_label = _make_label(root, Vector2(16, 1030), Vector2(520, 34) * ui_scale, "", int(22 * ui_scale), REC_RED)
	rec_label.visible = false
	toast_label = _make_label(root, Vector2(460, 930), Vector2(1000, 34) * ui_scale, "", int(20 * ui_scale), WHITE)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0

func _make_label(parent: Control, at: Vector2, size: Vector2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = size
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label
