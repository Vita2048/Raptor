extends "res://scripts/BossParticleFlames.gd"
## Layered boss fire: attached cores, trailing tongues, fuel surges and hull light.

var turbulence := FastNoiseLite.new()
var core_emitters: Array[CPUParticles2D] = []
var tongue_emitters: Array[CPUParticles2D] = []

func _ready() -> void:
	super._ready()
	turbulence.seed = 8137
	turbulence.frequency = 1.0

func heat(index: int) -> float:
	# Smooth, non-periodic fuel surges; each breach has its own noise slice.
	var fuel := turbulence.get_noise_2d(time * 0.85, float(index) * 31.0 + 137.0)
	var surge := smoothstep(-0.1, 0.5, fuel)
	return 0.96 + 0.12 * turbulence.get_noise_2d(time * 2.8, float(index) * 13.0) + surge * 0.45

func set_active(value: bool) -> void:
	super.set_active(value)
	for emitter in core_emitters + tongue_emitters:
		emitter.emitting = value
		if not value:
			emitter.modulate.a = 0.0

func _sync_emitters() -> void:
	super._sync_emitters()
	while core_emitters.size() < flame_emitters.size():
		var core := _make_flame_emitter()
		core.amount = 18
		core.lifetime = 0.25
		core.preprocess = 0.25
		core.emission_rect_extents = Vector2(5, 2)
		core.spread = 14.0
		core.scale_amount_min = 0.20
		core.scale_amount_max = 0.32
		core.z_index = 1
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.25, 1.12, 0.8, 0.9))
		ramp.add_point(0.4, Color(1.15, 0.9, 0.45, 0.8))
		ramp.set_color(1, Color(1, 0.5, 0.15, 0))
		core.color_ramp = ramp
		add_child(core)
		core_emitters.append(core)
		# Two independent streams split off from the same anchored breach.
		for side in range(2):
			var tongue := _make_flame_emitter()
			tongue.amount = 12
			tongue.lifetime = 0.58
			tongue.preprocess = 0.58
			# Only the short-lived tips detach; the body and core stay seated
			# on the hull. Already emitted tips can lag naturally through turns.
			tongue.local_coords = false
			tongue.spread = 12.0
			tongue.emission_rect_extents = Vector2(3, 2)
			tongue.scale_amount_min = 0.19
			tongue.scale_amount_max = 0.34
			tongue.damping_min = 6.0
			tongue.damping_max = 16.0
			var outer_ramp := Gradient.new()
			outer_ramp.set_color(0, Color(1, 0.7, 0.32, 0.6))
			outer_ramp.add_point(0.35, Color(1, 0.5, 0.16, 0.75))
			outer_ramp.set_color(1, Color(0.65, 0.19, 0.04, 0))
			tongue.color_ramp = outer_ramp
			add_child(tongue)
			tongue_emitters.append(tongue)

func flow(index: int) -> Vector2:
	var lean: float = host.flame_lean
	var curl := turbulence.get_noise_2d(time * 1.9, float(index) * 17.0 + 80.0)
	return Vector2.UP.rotated(lean * 0.45 + curl * 0.3)

func acceleration(index: int) -> Vector2:
	var curl := turbulence.get_noise_2d(time * 2.3, float(index) * 19.0 + 40.0)
	return Vector2(sin(host.flame_lean) * 110.0 + curl * 42.0, -24.0)

func _make_flame_emitter() -> CPUParticles2D:
	var p := super._make_flame_emitter()
	p.amount = 30
	p.lifetime = 0.48
	p.preprocess = 0.48
	p.scale_amount_min = 0.34
	p.scale_amount_max = 0.60
	p.emission_rect_extents = Vector2(6, 3)
	p.initial_velocity_min = 42.0
	p.initial_velocity_max = 78.0
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.85))
	scale_curve.add_point(Vector2(0.22, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.70))
	scale_curve.add_point(Vector2(1, 0.12))
	p.scale_amount_curve = scale_curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.95, 0.8, 0.95))
	ramp.add_point(0.25, Color(1, 0.78, 0.42, 0.88))
	ramp.add_point(0.65, Color(0.95, 0.4, 0.12, 0.52))
	ramp.set_color(1, Color(0.45, 0.18, 0.08, 0))
	p.color_ramp = ramp
	return p

func _process(delta: float) -> void:
	super._process(delta)
	if not active or not is_instance_valid(host):
		return
	for i in range(flame_emitters.size()):
		var intensity := heat(i)
		var strength: float = host.source_strength(i) * host.fire_strength
		var flame := flame_emitters[i]
		flame.position = host.sites[i] + Vector2(0, -16)
		flame.direction = flow(i)
		flame.gravity = acceleration(i)
		flame.modulate.a = clampf(strength * intensity * 1.2, 0.0, 1.0)
		flame.initial_velocity_min = 42.0 * intensity
		flame.initial_velocity_max = 78.0 * intensity
		# Scale newborn particles, not the emitter: existing fire never snaps
		# larger or rotates when a new surge begins.
		flame.scale_amount_min = 0.34 * lerpf(1.0, intensity, 0.5)
		flame.scale_amount_max = 0.60 * lerpf(1.0, intensity, 0.5)
		var core := core_emitters[i]
		core.position = host.sites[i] + Vector2(0, -9)
		core.direction = flame.direction
		core.gravity = flame.gravity * 0.5
		core.initial_velocity_min = 16.0 * intensity
		core.initial_velocity_max = 32.0 * intensity
		core.emitting = flame.emitting
		core.modulate.a = clampf(strength * intensity, 0.0, 1.0)
		for side in range(2):
			var tongue := tongue_emitters[i * 2 + side]
			var sign_x := float(side * 2 - 1)
			var curl := turbulence.get_noise_2d(time * 3.1, float(i * 2 + side) * 23.0 + 210.0)
			var tongue_heat := intensity * (0.95 + curl * 0.35)
			tongue.position = flame.position + Vector2(sign_x * 4.0, -2)
			tongue.direction = flame.direction.rotated(sign_x * 0.18 + curl * 0.45)
			tongue.gravity = flame.gravity + Vector2(curl * 75.0, -12)
			var inherited: Vector2 = host.hull_velocity.rotated(-global_rotation) * 0.70
			var travel := tongue.direction * 76.0 * tongue_heat + inherited
			tongue.direction = travel.normalized()
			tongue.initial_velocity_min = travel.length() * 0.80
			tongue.initial_velocity_max = travel.length() * 1.20
			tongue.emitting = flame.emitting
			tongue.modulate.a = clampf(strength * (0.8 + curl * 0.3), 0.0, 1.0)
		glow_lights[i].position = host.sites[i]
		var flicker := turbulence.get_noise_2d(time * 9.0, float(i) * 29.0 + 320.0)
		glow_lights[i].texture_scale = 1.45 + intensity * 0.18
		glow_lights[i].energy = strength * intensity * (1.25 + flicker * 0.16)
		glow_lights[i].color = Color(1.0, 0.46, 0.13).lerp(Color(1.0, 0.66, 0.27), clampf((intensity - 0.9) * 1.6, 0.0, 1.0))
		ember_emitters[i].position = flame.position
		ember_emitters[i].direction = flame.direction
