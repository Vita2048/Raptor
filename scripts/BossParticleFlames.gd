extends Node2D
## Production boss fire: hull-local particles, embers and flickering light.
## Realistic hull fire following Le Lu's "Godot 3D VFX - Fire Dynamic" recipe,
## translated to our 2D top-down stack:
##   1. custom-baked soft texture (instead of his hand-painted one),
##   2. a flame-puff particle system per breach with lifetime color ramp,
##   3. a spark/ember system per breach (his "extra details"),
##   4. a flickering glow light per breach (his lighting pass, 2D PointLight2D).
## Differences from the video (all forced by our game): CPUParticles2D instead of
## GPU/3D particles (matches ExplosionEffect's WebGL reasoning), canvas_item space,
## flames stay hull-local while embers and smoke drift in world space.
## Everything is driven by the host's existing
## source_strength()/fire_strength staging.

const TEX_SIZE := 128

static var _flame_tex: Texture2D
static var _spark_tex: Texture2D
static var _glow_tex: Texture2D

var host: Node2D
var active := false
var flame_emitters: Array[CPUParticles2D] = []
var ember_emitters: Array[CPUParticles2D] = []
var glow_lights: Array[PointLight2D] = []
var time := 0.0

static func flame_texture() -> Texture2D:
	if _flame_tex == null:
		_flame_tex = _bake_flame_tex()
	return _flame_tex

static func spark_texture() -> Texture2D:
	if _spark_tex == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in range(16):
			for x in range(16):
				var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.95, 0.85, a * a))
		_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex

static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = pow(a, 1.6)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

static func _bake_flame_tex() -> Texture2D:
	# Natural teardrop: round bulb seated low on the breach, tapering tongue
	# rising to a wispy tip. Achieved with an asymmetric falloff — stretched
	# upward above center, compressed below — plus ridged noise breakup and
	# vertical streaks. Warm root core cooling to a sienna shroud.
	var noise := FastNoiseLite.new()
	noise.seed = 20240
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var c := float(TEX_SIZE) * 0.5
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			# Teardrop mapping around a low bulb center: slim the sides,
			# elongate upward into the tongue, keep the base round and full.
			var dx := (float(x) - c) / c * 1.18
			var dy := (float(y) - c * 1.30) / c
			if dy < 0.0:
				dy *= 0.60 # long tapering rise toward the tip
			else:
				dy *= 1.30 # round seated bulb at the breach
			var r := sqrt(dx * dx + dy * dy)
			var fall := clampf(1.0 - r, 0.0, 1.0)
			fall = fall * fall * (3.0 - 2.0 * fall)
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var ridge := 1.0 - absf(n * 2.0 - 1.0)
			var a := fall * (0.30 + 0.70 * ridge)
			# Vertical tongue stretch: brighter rising streaks above the bulb.
			var tongue := noise.get_noise_2d(float(x) * 2.4, float(y) * 0.55) * 0.5 + 0.5
			var height := clampf(1.0 - float(y) / float(TEX_SIZE), 0.0, 1.0)
			var heat := clampf(a * 1.25 + tongue * 0.30 * fall * height - r * 0.35, 0.0, 1.2)
			var col := Color(0.62, 0.20, 0.05, 1.0).lerp(Color(0.96, 0.48, 0.13), smoothstep(0.05, 0.45, heat))
			col = col.lerp(Color(1.0, 0.78, 0.38), smoothstep(0.40, 0.80, heat))
			col = col.lerp(Color(1.0, 0.99, 0.93), smoothstep(0.78, 1.10, heat))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _ready() -> void:
	z_index = 1
	visible = false
	set_process(true)

func set_active(value: bool) -> void:
	active = value
	visible = value
	for e in flame_emitters + ember_emitters:
		e.emitting = value
		if not value:
			e.modulate = Color(1, 1, 1, 0)
	if not value:
		for l in glow_lights:
			l.visible = false

func deactivate() -> void:
	set_active(false)

func _make_flame_emitter() -> CPUParticles2D:
	# Hull-local space ON PURPOSE: the flame body must ride the breach like the
	# atlas ribbons do. World-space puffs + fast lateral sway is exactly what
	# smeared them into sideways balls. Flow direction and acceleration below
	# give the motion response. The original tilt is retained for comparison. Embers and smoke
	# stay world-space; those are supposed to drift off and lag behind.
	var p := CPUParticles2D.new()
	p.texture = flame_texture()
	p.amount = 16
	p.lifetime = 0.65
	p.lifetime_randomness = 0.35
	p.preprocess = 0.65
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.local_coords = true
	p.direction = Vector2(0, -1)
	p.spread = 20.0
	p.gravity = Vector2(0, -14)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 65.0
	p.damping_min = 12.0
	p.damping_max = 30.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(7, 4)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.96, 0.88, 0.95))
	grad.set_color(1, Color(0.55, 0.16, 0.04, 0.0))
	grad.add_point(0.45, Color(1.0, 0.62, 0.22, 0.8))
	p.color_ramp = grad
	p.emitting = false
	p.modulate = Color(1, 1, 1, 0)
	return p

func _make_ember_emitter() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = spark_texture()
	p.amount = 8
	p.lifetime = 0.55
	p.lifetime_randomness = 0.4
	p.explosiveness = 0.0
	p.randomness = 0.8
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 32.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 175.0
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	var grad := Gradient.new()
	grad.set_color(0, Color(2.0, 1.4, 0.6, 1.0))
	grad.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	p.color_ramp = grad
	p.emitting = false
	p.modulate = Color(1, 1, 1, 0)
	return p

func _make_glow_light() -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = glow_texture()
	l.color = Color(1.0, 0.55, 0.2)
	l.energy = 0.0
	l.texture_scale = 2.6
	l.visible = false
	return l

func _sync_emitters() -> void:
	if host == null or not is_instance_valid(host):
		return
	var sites: Array = host.get("sites")
	while flame_emitters.size() < sites.size():
		var f := _make_flame_emitter()
		var s := _make_ember_emitter()
		var l := _make_glow_light()
		add_child(f)
		add_child(s)
		add_child(l)
		flame_emitters.append(f)
		ember_emitters.append(s)
		glow_lights.append(l)
		f.emitting = active
		s.emitting = active

func _process(delta: float) -> void:
	time += delta
	if not active or host == null or not is_instance_valid(host):
		return
	_sync_emitters()
	var sites: Array = host.get("sites")
	var fire: float = host.get("fire_strength")
	var lean: float = host.get("flame_lean")
	for i in range(sites.size()):
		var strength: float = host.source_strength(i) * fire
		var f := flame_emitters[i]
		var s := ember_emitters[i]
		var l := glow_lights[i]
		# Anchor emitters just above the breach so the texture's low bulb seats
		# on the hull and the tongue rises off it.
		var anchor: Vector2 = sites[i] + Vector2(0, -26)
		f.position = anchor
		s.position = anchor
		l.position = anchor
		# Steer travel without rotating the emitter or existing particles.
		f.rotation = 0.0
		f.direction = Vector2.UP.rotated(lean * 0.35)
		f.gravity = Vector2(sin(lean) * 130.0, -14.0)
		# CPUParticles2D has no amount_ratio: gate emission per breach and fade
		# smoothly via modulate, driven by the host's existing staging.
		f.emitting = active and strength > 0.02
		f.modulate = Color(1, 1, 1, clampf(strength * 1.3, 0.0, 1.0))
		# Sparks only join once the breach is properly burning.
		var spark := clampf((strength - 0.22) / 0.6, 0.0, 1.0)
		s.emitting = active and spark > 0.02
		s.modulate = Color(1, 1, 1, spark)
		if strength > 0.02:
			l.visible = true
			var flicker := sin(time * 13.0 + float(i) * 2.1) * 0.5 + sin(time * 29.0 + float(i) * 4.3) * 0.5
			l.energy = strength * (1.15 + flicker * 0.45)
		else:
			l.visible = false
			l.energy = 0.0
