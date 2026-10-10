extends Node2D

var sites: Array = []
var smoke_strength := 0.0
var fire_strength := 0.0
var particles: Array[Dictionary] = []
var emission_time := 0.0

func _ready() -> void:
	z_index = 4
	set_process(false)

func reset() -> void:
	smoke_strength = 0.0
	fire_strength = 0.0
	emission_time = 0.0
	particles.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
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
				# The second damaged area fades in instead of switching on abruptly.
				var spread := 1.0 if i == 0 else smoothstep(0.20, 0.80, smoke_strength)
				if spread > 0.001:
					_emit(sites[i], false, spread)
					if fire_strength > 0.0:
						_emit(sites[i], true, spread)
	if not particles.is_empty() or smoke_strength == 0.0:
		queue_redraw()

func _emit(site: Vector2, fire: bool, spread: float) -> void:
	if particles.size() >= 64:
		return
	particles.append({"pos": to_global(site + Vector2(randf_range(-4, 4), randf_range(-3, 3))),
		"velocity": Vector2(randf_range(-15, 15), randf_range(-65, -40)),
		"age": 0.0, "life": randf_range(0.32, 0.55) if fire else randf_range(1.1, 1.7),
		"size": randf_range(19, 29) * lerpf(0.5, 1.3, fire_strength) if fire else randf_range(23, 34) * lerpf(0.55, 1.2, smoke_strength),
		"fire": fire, "strength": (fire_strength if fire else smoke_strength) * spread})

func _draw() -> void:
	# World-space puffs lag behind lateral movement instead of sticking to the hull.
	for p in particles:
		var t: float = p.age / p.life
		var frames: Array[Texture2D] = AssetDB.explosion_textures if p.fire else AssetDB.black_smoke_textures
		if frames.is_empty():
			continue
		var frame := mini(int(t * frames.size()), frames.size() - 1)
		var size: float = p.size * (lerpf(0.6, 1.15, t) if p.fire else lerpf(0.7, 2.1, t))
		var fade := sin(t * PI) * float(p.strength)
		var color := Color(1.0, 0.82, 0.58, fade * 0.9) if p.fire else Color(0.58, 0.59, 0.61, fade * 0.62)
		draw_texture_rect(frames[frame], Rect2(to_local(p.pos) - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, color)
