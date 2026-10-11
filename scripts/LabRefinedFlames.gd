extends "res://scripts/BossParticleFlames.gd"
## Experimental renderer used only by BossEffectsLab.

var turbulence := FastNoiseLite.new()

func _ready() -> void:
	super._ready()
	turbulence.seed = 8137
	turbulence.frequency = 1.0

func heat(index: int) -> float:
	return 0.88 + 0.22 * turbulence.get_noise_2d(time * 2.8, float(index) * 13.0)

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
		glow_lights[i].position = host.sites[i]
		glow_lights[i].texture_scale = 2.1
		glow_lights[i].energy = strength * intensity * 1.1
		ember_emitters[i].position = flame.position
		ember_emitters[i].direction = flame.direction
