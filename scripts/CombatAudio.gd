extends Node

const RATE := 22050
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_played: Dictionary = {}
var muted := false
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.seed = 73519
	for kind in ["shot", "enemy", "impact", "explosion", "heavy", "damage", "alert", "charge"]:
		sounds[kind] = _synthesize(kind)
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for voice in voices:
			voice.stop()

func play_sound(kind: String) -> void:
	if muted or not sounds.has(kind):
		return
	var now := Time.get_ticks_msec()
	var gap := 180 if kind in ["heavy", "damage"] else 65
	if now - int(last_played.get(kind, -1000)) < gap:
		return
	last_played[kind] = now
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds[kind]
			voice.volume_db = -15.0 if kind in ["shot", "enemy", "impact"] else -10.0
			voice.pitch_scale = random.randf_range(0.94, 1.06)
			voice.play()
			return

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
