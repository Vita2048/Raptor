extends Node

signal volume_changed(volume: float)
signal muted_changed(is_muted: bool)

const RATE := 22050
const SETTINGS_PATH := "user://settings.cfg"
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_played: Dictionary = {}
var muted := false
var volume := 0.8
var random := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	random.seed = 73519
	for kind in ["shot", "enemy", "impact", "explosion", "heavy", "damage", "alert", "charge"]:
		sounds[kind] = _synthesize(kind)
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		voices.append(voice)
	_load_settings()

func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	if muted:
		for voice in voices:
			voice.stop()
	muted_changed.emit(muted)
	_save_settings()

func toggle_muted() -> void:
	set_muted(not muted)

func set_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(volume, clamped):
		return
	volume = clamped
	# Unmute automatically when user raises volume from 0 via slider.
	if volume > 0.001 and muted:
		muted = false
		muted_changed.emit(muted)
	volume_changed.emit(volume)
	_save_settings()

func get_volume_db(base_db: float) -> float:
	if muted or volume <= 0.001:
		return -80.0
	return base_db + linear_to_db(maxf(volume, 0.001))

func play_sound(kind: String) -> void:
	if muted or volume <= 0.001 or not sounds.has(kind):
		return
	var now := Time.get_ticks_msec()
	var gap := 180 if kind in ["heavy", "damage"] else 65
	if now - int(last_played.get(kind, -1000)) < gap:
		return
	last_played[kind] = now
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds[kind]
			var base_db := -15.0 if kind in ["shot", "enemy", "impact"] else -10.0
			voice.volume_db = get_volume_db(base_db)
			voice.pitch_scale = random.randf_range(0.94, 1.06)
			voice.play()
			return

func play_preview() -> void:
	# Bypasses throttle so volume slider feedback is instant (works while paused).
	if muted or volume <= 0.001 or not sounds.has("explosion"):
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds["explosion"]
			voice.volume_db = get_volume_db(-10.0)
			voice.pitch_scale = 1.0
			voice.play()
			return
	# All busy: steal first voice for preview.
	var fallback: AudioStreamPlayer = voices[0]
	fallback.stream = sounds["explosion"]
	fallback.volume_db = get_volume_db(-10.0)
	fallback.pitch_scale = 1.0
	fallback.play()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other sections (e.g. display) intact
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", muted))

# Original, deterministic PCM effects, generated once and reused by a bounded voice pool.
func _synthesize(kind: String) -> AudioStreamWAV:
	var duration := 0.13
	if kind == "explosion": duration = 0.65
	if kind == "heavy": duration = 1.1
	if kind == "damage": duration = 0.24
	if kind == "alert": duration = 0.8
	if kind == "charge": duration = 0.5
	var count := int(duration * RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var phase := 0.0
	var low_noise := 0.0
	for i in range(count):
		var t := float(i) / RATE
		var progress := t / duration
		var noise := random.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.16)
		var frequency := 160.0
		var sample := 0.0
		match kind:
			"alert":
				phase += TAU * 440.0 / RATE
				sample = sin(phase) * 0.4 * pow(sin(progress * PI * 3.0), 2.0)
			"charge":
				phase += TAU * lerpf(180.0, 720.0, progress) / RATE
				sample = sin(phase) * 0.4 * progress
			"shot", "enemy":
				frequency = lerpf(740.0 if kind == "shot" else 360.0, 95.0, sqrt(progress))
				phase += TAU * frequency / RATE
				sample = sin(phase) * 0.52 + noise * 0.2 * exp(-t * 75.0)
			"impact", "damage":
				phase += TAU * lerpf(260.0, 65.0, progress) / RATE
				sample = noise * 0.32 + sin(phase) * 0.3 + low_noise * 0.3
			_:
				phase += TAU * lerpf(90.0, 32.0, sqrt(progress)) / RATE
				sample = low_noise * 1.8 + sin(phase) * 0.35 + noise * 0.18 * exp(-t * 16.0)
		var envelope := minf(t / 0.003, 1.0) * exp(-progress * 5.0) * (1.0 - progress)
		pcm.encode_s16(i * 2, int(clampf(sample * envelope, -0.95, 0.95) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = pcm
	return stream
