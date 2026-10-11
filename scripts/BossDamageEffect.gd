extends Node2D

var sites: Array = []
var smoke_strength := 0.0
var fire_strength := 0.0
var damage_amount := 0.0
var particles: Array[Dictionary] = []
var emission_time := 0.0
var flame_time := 0.0
var flame_lean := 0.0
var previous_position := Vector2.ZERO
var has_previous_position := false
var realistic_layer: Node2D

func _ready() -> void:
	z_index = 4
	set_process(false)

func reset() -> void:
	if is_instance_valid(realistic_layer):
		realistic_layer.free()
		realistic_layer = null
	smoke_strength = 0.0
	fire_strength = 0.0
	damage_amount = 0.0
	emission_time = 0.0
	flame_time = 0.0
	flame_lean = 0.0
	has_previous_position = false
	particles.clear()
	set_process(false)
	queue_redraw()

func source_strength(index: int) -> float:
	# Fade each breach in over ten armor points: 80–70%, 60–50%, 40–30%.
	var start := 0.20 + float(index) * 0.20
	return smoothstep(start, start + 0.10, damage_amount)

func _process(delta: float) -> void:
	if fire_strength > 0.0 and not is_instance_valid(realistic_layer):
		realistic_layer = preload("res://scripts/BossParticleFlames.gd").new()
		realistic_layer.host = self
		add_child(realistic_layer)
		realistic_layer.set_active(true)
	flame_time += delta
	if has_previous_position and delta > 0.0:
		var velocity := ((global_position - previous_position) / delta).rotated(-global_rotation)
		var target := clampf(atan2(-velocity.x, 110.0 + maxf(velocity.y, -60.0)), -1.05, 1.05)
		flame_lean = lerpf(flame_lean, target, 1.0 - exp(-delta * 5.0))
	previous_position = global_position
	has_previous_position = true
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.age += delta
		p.pos += p.velocity * delta
		if p.age >= p.life:
			particles.remove_at(i)
	if smoke_strength > 0.0 and is_visible_in_tree():
		emission_time -= delta
		if emission_time <= 0.0:
			emission_time = lerpf(0.42, 0.065, smoke_strength)
			for i in range(sites.size()):
				var spread := source_strength(i)
				if spread > 0.001:
					_emit_smoke(sites[i], spread, i)
	queue_redraw()

func _emit_smoke(site: Vector2, spread: float, source: int) -> void:
	# Three full trails need room without starving the last breach.
	if particles.size() >= 128:
		return
	# Start smoke in the upper flame, including its current pulse and movement bend.
	var flame_size := flame_size(source)
	var upper_flame := Vector2(0.0, -flame_size.y * 0.58)
	site += bend_flame_point(upper_flame, flame_size, source) * smoothstep(0.0, 0.3, fire_strength)
	particles.append({"pos": to_global(site + Vector2(randf_range(-4, 4), randf_range(-3, 3))),
		"velocity": Vector2(randf_range(-8, 8), randf_range(-42, -28)),
		"age": 0.0, "life": randf_range(0.9, 1.3),
		"size": randf_range(23, 34) * lerpf(0.55, 1.2, smoke_strength),
		"source": source, "strength": smoke_strength * spread})

func _draw() -> void:
	# World-space puffs lag behind lateral movement instead of sticking to the hull.
	for p in particles:
		var t: float = p.age / p.life
		var frames: Array[Texture2D] = AssetDB.black_smoke_textures
		if frames.is_empty():
			continue
		var progression: float = t * (frames.size() - 1)
		var frame := int(progression)
		var blend := progression - frame
		var size: float = p.size * lerpf(0.7, 2.1, t)
		var fade := sin(t * PI) * float(p.strength)
		var color := Color(0.85, 0.85, 0.87, fade * 0.48)
		var anchor := Vector2(0.5, 0.5)
		var rect := Rect2(to_local(p.pos) - anchor * size, Vector2.ONE * size)
		var next_color := color
		color.a *= 1.0 - blend
		next_color.a *= blend
		draw_texture_rect(frames[frame], rect, false, color)
		draw_texture_rect(frames[mini(frame + 1, frames.size() - 1)], rect, false, next_color)

func bend_flame_point(point: Vector2, size: Vector2, index: int) -> Vector2:
	# Height-weighted curvature: the base never swivels, only the upper gas bends.
	var height := maxf(-point.y / size.y, 0.0)
	var phase := flame_time * 9.0 + index * 2.3
	var curl := sin(phase - height * 7.0) * size.x * 0.055 * height
	var bend := flame_lean * size.y * 0.85 * height * height
	var width := 1.0 + sin(phase * 0.7 - height * 5.0) * 0.065
	return Vector2(point.x * width + bend + curl, point.y)

func flame_size(index: int) -> Vector2:
	var phase := float(index) * 2.3
	var pulse := sin(flame_time * 7.3 + phase)
	var flicker := sin(flame_time * 15.7 + phase * 1.7)
	var length := lerpf(48.0, 84.0, fire_strength)
	var size := Vector2(length * 0.86 * (1.0 - pulse * 0.08), length * (1.0 + pulse * 0.16 + flicker * 0.05))
	return size
