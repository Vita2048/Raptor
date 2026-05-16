extends Node2D

const MAP_SCROLL_SPEED := 235.0

var flash_sprite: Sprite2D
var fireball_sprite: Sprite2D
var boss_flash_sprite: Sprite2D
var shockwave_layer: Node2D
var smoke_layer: Node2D
var large_scale := false
var size_multiplier := 1.0

func _ready() -> void:
	z_index = 90
	_build_layers()

func configure(is_large: bool) -> void:
	large_scale = is_large
	size_multiplier = 3.1 if is_large else 1.0

func burst() -> void:
	if large_scale:
		_play_boss_flash()
	_play_flash()
	_play_fireball()
	_emit_shockwave()
	_emit_smoke_delayed()
	await get_tree().create_timer(2.05 if large_scale else 1.75).timeout
	queue_free()

func _build_layers() -> void:
	flash_sprite = Sprite2D.new()
	flash_sprite.name = "InstantFlash"
	flash_sprite.centered = true
	flash_sprite.visible = false
	flash_sprite.z_index = 4
	add_child(flash_sprite)

	fireball_sprite = Sprite2D.new()
	fireball_sprite.name = "CoreFireball"
	fireball_sprite.centered = true
	fireball_sprite.visible = false
	fireball_sprite.z_index = 3
	add_child(fireball_sprite)

	boss_flash_sprite = Sprite2D.new()
	boss_flash_sprite.name = "BossFlash"
	boss_flash_sprite.centered = true
	boss_flash_sprite.visible = false
	boss_flash_sprite.z_index = 5
	add_child(boss_flash_sprite)

	shockwave_layer = Node2D.new()
	shockwave_layer.name = "ExpandingShockwave"
	shockwave_layer.z_index = 2
	add_child(shockwave_layer)

	smoke_layer = Node2D.new()
	smoke_layer.name = "LingeringSmoke"
	smoke_layer.z_index = 1
	add_child(smoke_layer)

func _play_flash() -> void:
	flash_sprite.visible = true
	flash_sprite.modulate = Color.WHITE
	var base := (0.26 if large_scale else 0.16) * size_multiplier
	var frames := AssetDB.flash_textures
	var frame_time := 0.15 / float(frames.size())
	for i in range(frames.size()):
		var t: float = float(i) / max(float(frames.size() - 1), 1.0)
		flash_sprite.texture = frames[i]
		flash_sprite.scale = Vector2.ONE * lerp(base, base * 2.15, t)
		flash_sprite.modulate.a = 1.0 - t
		await get_tree().create_timer(frame_time).timeout
	flash_sprite.visible = false

func _play_boss_flash() -> void:
	boss_flash_sprite.visible = true
	boss_flash_sprite.texture = AssetDB.flash_textures.pick_random()
	boss_flash_sprite.modulate = Color(1.0, 0.88, 0.45, 0.95)
	boss_flash_sprite.scale = Vector2.ONE * 0.85
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(boss_flash_sprite, "scale", Vector2.ONE * 2.4, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(boss_flash_sprite, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	boss_flash_sprite.visible = false

func _play_fireball() -> void:
	fireball_sprite.visible = true
	fireball_sprite.modulate = Color(1.0, 0.78, 0.48, 1.0)
	var base := (0.24 if large_scale else 0.13) * size_multiplier
	var frames := AssetDB.explosion_textures
	var frame_time := 1.0 / 20.0
	for i in range(frames.size()):
		var t: float = float(i) / max(float(frames.size() - 1), 1.0)
		fireball_sprite.texture = frames[i]
		fireball_sprite.scale = Vector2.ONE * lerp(base, base * 1.85, t)
		fireball_sprite.modulate.a = 1.0 - smoothstep(0.38, 1.0, t)
		await get_tree().create_timer(frame_time).timeout
	fireball_sprite.visible = false

func _emit_shockwave() -> void:
	var count := randi_range(24, 34) if large_scale else randi_range(10, 15)
	for i in range(count):
		var angle := randf_range(0.0, TAU)
		var emitter := _make_particle_emitter(
			"WhitePuffShard",
			AssetDB.random_particle("white_puff"),
			1,
			0.4,
			Vector2(cos(angle), sin(angle)),
			randf_range(760.0, 1180.0) if large_scale else randf_range(650.0, 980.0),
			420.0,
			0.045,
			0.115,
			Color(1.0, 0.96, 0.82, 0.9),
			Color(1.0, 1.0, 1.0, 0.0)
		)
		shockwave_layer.add_child(emitter)
		emitter.restart()

func _emit_smoke_delayed() -> void:
	await get_tree().create_timer(0.1).timeout
	var count := randi_range(32, 44) if large_scale else randi_range(15, 20)
	for i in range(count):
		var drift := Vector2(randf_range(-0.35, 0.35), -1.0).normalized()
		var emitter := _make_particle_emitter(
			"BlackSmokeTrail",
			AssetDB.random_particle("black_smoke"),
			1,
			randf_range(1.0, 1.5),
			drift,
			randf_range(145.0, 240.0) if large_scale else randf_range(105.0, 180.0),
			28.0,
			0.055,
			0.16,
			Color(0.12, 0.12, 0.12, 0.72),
			Color(0.05, 0.05, 0.05, 0.0),
			Vector2(randf_range(-210.0, 210.0), randf_range(-190.0, 190.0)) if large_scale else Vector2(randf_range(-34.0, 34.0), randf_range(-18.0, 24.0))
		)
		smoke_layer.add_child(emitter)
		emitter.restart()

func _make_particle_emitter(layer_name: String, texture: Texture2D, amount: int, particle_lifetime: float, direction: Vector2, speed: float, damping: float, scale_min: float, scale_max: float, start_color: Color, end_color: Color, offset := Vector2.ZERO) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = layer_name
	particles.position = offset
	particles.texture = texture
	particles.amount = amount
	particles.lifetime = particle_lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.65
	particles.local_coords = false
	particles.emitting = false

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 12.0
	material.initial_velocity_min = speed * 0.72
	material.initial_velocity_max = speed
	material.damping_min = damping
	material.damping_max = damping * 1.25
	material.angular_velocity_min = -260.0
	material.angular_velocity_max = 260.0
	material.scale_min = scale_min * (2.2 if large_scale else 1.0)
	material.scale_max = scale_max * (2.2 if large_scale else 1.0)
	if layer_name == "BlackSmokeTrail":
		material.gravity = Vector3(0.0, MAP_SCROLL_SPEED * 0.34, 0.0)
	else:
		material.gravity = Vector3.ZERO

	var gradient := Gradient.new()
	gradient.set_color(0, start_color)
	gradient.set_color(1, end_color)
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	particles.process_material = material
	return particles
