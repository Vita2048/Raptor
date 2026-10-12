extends Node2D

const MAP_SCROLL_SPEED := 235.0

var flash_sprite: Sprite2D
var fireball_sprite: Sprite2D
var fireball_next: Sprite2D
var boss_flash_sprite: Sprite2D
var shockwave_layer: Node2D
var smoke_layer: Node2D
var shock_emitter: CPUParticles2D
var smoke_emitter: CPUParticles2D
var large_scale := false
var size_multiplier := 1.0
var fireball_age := -1.0
var pool = null

# Shared ramps: identical colors to the previous per-blast Gradients, but
# allocated once so mid-combat explosions don't allocate + trigger GC on Web.
static var _shock_gradient: Gradient = null
static var _smoke_gradient: Gradient = null

static func get_shock_gradient() -> Gradient:
	if _shock_gradient == null:
		_shock_gradient = Gradient.new()
		_shock_gradient.set_color(0, Color(1.0, 0.86, 0.65, 0.5))
		_shock_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return _shock_gradient

static func get_smoke_gradient() -> Gradient:
	if _smoke_gradient == null:
		_smoke_gradient = Gradient.new()
		_smoke_gradient.set_color(0, Color(0.65, 0.65, 0.67, 0.72))
		_smoke_gradient.set_color(1, Color(0.40, 0.40, 0.42, 0.0))
	return _smoke_gradient

func _ready() -> void:
	z_index = 90
	_build_layers()

func configure(is_large: bool, multiplier: float = 1.0) -> void:
	large_scale = is_large
	size_multiplier = (1.06 if is_large else 1.0) * multiplier

func burst(quiet := false) -> void:
	# quiet prebuffers visuals at startup without sound or screen shake.
	if not quiet:
		VFX.audio.play_sound("heavy" if large_scale else "explosion")
		VFX.camera_impulse.emit(5.0 if large_scale else 1.3)
	if large_scale:
		_play_boss_flash()
	_play_flash()
	_play_fireball()
	_emit_shockwave()
	_emit_smoke_delayed()
	await get_tree().create_timer(2.65 if large_scale else 2.0).timeout
	if pool != null:
		pool.release(self)
	else:
		queue_free()

func set_pool(value) -> void:
	pool = value

func on_pool_acquired() -> void:
	visible = true
	fireball_age = -1.0
	if is_instance_valid(flash_sprite):
		flash_sprite.visible = false
	if is_instance_valid(fireball_sprite):
		fireball_sprite.visible = false
	if is_instance_valid(fireball_next):
		fireball_next.visible = false
	if is_instance_valid(boss_flash_sprite):
		boss_flash_sprite.visible = false
	if is_instance_valid(shock_emitter):
		shock_emitter.emitting = false
	if is_instance_valid(smoke_emitter):
		smoke_emitter.emitting = false

func on_pool_released() -> void:
	visible = false
	fireball_age = -1.0
	if is_instance_valid(shock_emitter):
		shock_emitter.emitting = false
	if is_instance_valid(smoke_emitter):
		smoke_emitter.emitting = false

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
	fireball_next = Sprite2D.new()
	fireball_next.name = "CoreFireballBlend"
	fireball_next.visible = false
	fireball_next.z_index = 3
	add_child(fireball_next)

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

	# Persistent batched emitters: created once per blast so mid-combat bursts
	# only retune + restart instead of allocating nodes + Gradients on Web.
	shock_emitter = _new_persistent_emitter("WhitePuffShard", get_shock_gradient())
	shockwave_layer.add_child(shock_emitter)
	smoke_emitter = _new_persistent_emitter("BlackSmokeTrail", get_smoke_gradient())
	smoke_layer.add_child(smoke_emitter)

func _new_persistent_emitter(layer_name: String, ramp: Gradient) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = layer_name
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.65
	particles.local_coords = false
	particles.emitting = false
	particles.spread = 28.0 if layer_name == "BlackSmokeTrail" else 180.0
	particles.color_ramp = ramp
	if layer_name == "BlackSmokeTrail":
		particles.gravity = Vector2(0.0, MAP_SCROLL_SPEED * 0.34)
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(18, 14)
	else:
		particles.gravity = Vector2.ZERO
	return particles

func _play_flash() -> void:
	flash_sprite.visible = true
	flash_sprite.modulate = Color.WHITE
	var base := (0.182 if large_scale else 0.16) * size_multiplier
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
	boss_flash_sprite.modulate = Color(1.0, 0.88, 0.65, 0.55)
	boss_flash_sprite.scale = Vector2.ONE * 0.24 * size_multiplier
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(boss_flash_sprite, "scale", Vector2.ONE * 0.7 * size_multiplier, 0.20).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(boss_flash_sprite, "modulate:a", 0.0, 0.20)
	await tween.finished
	boss_flash_sprite.visible = false

func _play_fireball() -> void:
	fireball_age = 0.0
	fireball_sprite.visible = true
	fireball_next.visible = true
	_update_fireball()

func _process(delta: float) -> void:
	if fireball_age >= 0.0:
		fireball_age += delta
		_update_fireball()

func _update_fireball() -> void:
	var duration := 1.35 if large_scale else 1.05
	var t := clampf(fireball_age / duration, 0.0, 1.0)
	if t >= 1.0:
		fireball_sprite.visible = false
		fireball_next.visible = false
		fireball_age = -1.0
		return
	var base := (0.168 if large_scale else 0.13) * size_multiplier
	var frames := AssetDB.explosion_textures
	# Preserve the old on-screen size with the new atlas cell resolution.
	base *= 600.0 / frames[0].get_width()
	# Rapid ignition, then spend most of the lifetime on expansion and cooling.
	var phase := pow(t, 0.72) * float(frames.size() - 1)
	var frame := int(phase)
	var blend := smoothstep(0.0, 1.0, phase - frame)
	var opacity := 1.0 - smoothstep(0.65, 1.0, t)
	fireball_sprite.texture = frames[frame]
	fireball_next.texture = frames[mini(frame + 1, frames.size() - 1)]
	fireball_sprite.scale = Vector2.ONE * base * lerpf(0.85, 1.85, 1.0 - pow(1.0 - t, 2.5))
	fireball_next.scale = fireball_sprite.scale
	fireball_sprite.modulate = Color(1, 1, 1, opacity * (1.0 - blend))
	fireball_next.modulate = Color(1, 1, 1, opacity * blend)

func _emit_shockwave() -> void:
	var count := randi_range(12, 18) if large_scale else randi_range(10, 15)
	var angle := randf_range(0.0, TAU)
	_configure_emitter(
		shock_emitter,
		"WhitePuffShard",
		AssetDB.random_particle("white_puff"),
		count,
		0.4,
		Vector2(cos(angle), sin(angle)),
		(randf_range(380.0, 560.0) if large_scale else randf_range(320.0, 480.0)) * size_multiplier,
		420.0,
		0.045,
		0.065
	)
	shock_emitter.restart()

func _emit_smoke_delayed() -> void:
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self) or not is_instance_valid(smoke_emitter):
		return
	var count := randi_range(16, 22) if large_scale else randi_range(15, 20)
	var drift := Vector2(randf_range(-0.35, 0.35), -1.0).normalized()
	_configure_emitter(
		smoke_emitter,
		"BlackSmokeTrail",
		AssetDB.random_particle("black_smoke"),
		count,
		(2.2 if large_scale else 1.6),
		drift,
		(randf_range(45.0, 75.0) if large_scale else randf_range(35.0, 60.0)) * size_multiplier,
		28.0,
		0.055,
		0.16
	)
	smoke_emitter.restart()

func _configure_emitter(emitter: CPUParticles2D, layer_name: String, texture: Texture2D, amount: int, particle_lifetime: float, direction: Vector2, speed: float, damping: float, scale_min: float, scale_max: float) -> void:
	# Same visuals as before; only retunes the persistent emitter.
	emitter.texture = texture
	emitter.amount = amount
	emitter.lifetime = particle_lifetime
	emitter.direction = direction
	emitter.spread = 28.0 if layer_name == "BlackSmokeTrail" else 180.0
	emitter.initial_velocity_min = speed * 0.72
	emitter.initial_velocity_max = speed
	emitter.damping_min = damping
	emitter.damping_max = damping * 1.25
	emitter.angular_velocity_min = -18.0 if layer_name == "BlackSmokeTrail" else -180.0
	emitter.angular_velocity_max = 18.0 if layer_name == "BlackSmokeTrail" else 180.0
	emitter.scale_amount_min = scale_min * (1.08 if large_scale else 1.0) * size_multiplier
	emitter.scale_amount_max = scale_max * (1.08 if large_scale else 1.0) * size_multiplier
	emitter.color_ramp = get_smoke_gradient() if layer_name == "BlackSmokeTrail" else get_shock_gradient()
	if layer_name == "BlackSmokeTrail":
		# New smoke cells are smaller than the former ~373px textures.
		emitter.scale_amount_min *= 373.0 / texture.get_width()
		emitter.scale_amount_max *= 373.0 / texture.get_width()
		emitter.gravity = Vector2(0.0, MAP_SCROLL_SPEED * 0.34)
		emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		emitter.emission_rect_extents = Vector2(32, 24) * size_multiplier if large_scale else Vector2(18, 14) * size_multiplier
	else:
		emitter.gravity = Vector2.ZERO
		emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT

func _make_particle_emitter(layer_name: String, texture: Texture2D, amount: int, particle_lifetime: float, direction: Vector2, speed: float, damping: float, scale_min: float, scale_max: float, start_color: Color, end_color: Color, offset := Vector2.ZERO) -> CPUParticles2D:
	# Two batched CPU emitters avoid dozens of GPU systems/material uploads per blast,
	# especially costly on single-threaded WebGL builds.
	var particles := CPUParticles2D.new()
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

	var material := particles
	material.direction = direction
	material.spread = 28.0 if layer_name == "BlackSmokeTrail" else 180.0
	material.initial_velocity_min = speed * 0.72
	material.initial_velocity_max = speed
	material.damping_min = damping
	material.damping_max = damping * 1.25
	material.angular_velocity_min = -18.0 if layer_name == "BlackSmokeTrail" else -180.0
	material.angular_velocity_max = 18.0 if layer_name == "BlackSmokeTrail" else 180.0
	material.scale_amount_min = scale_min * (1.08 if large_scale else 1.0) * size_multiplier
	material.scale_amount_max = scale_max * (1.08 if large_scale else 1.0) * size_multiplier
	if layer_name == "BlackSmokeTrail":
		# New smoke cells are smaller than the former ~373px textures.
		material.scale_amount_min *= 373.0 / texture.get_width()
		material.scale_amount_max *= 373.0 / texture.get_width()
		material.gravity = Vector2(0.0, MAP_SCROLL_SPEED * 0.34)
		material.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		material.emission_rect_extents = Vector2(32, 24) * size_multiplier if large_scale else Vector2(18, 14) * size_multiplier
	else:
		material.gravity = Vector2.ZERO

	var gradient := Gradient.new()
	gradient.set_color(0, start_color)
	gradient.set_color(1, end_color)
	# Reuse shared ramps when colors match the standard blast palette to avoid
	# per-explosion allocations; fall back to a fresh ramp only for custom colors.
	if layer_name == "BlackSmokeTrail":
		material.color_ramp = get_smoke_gradient()
	else:
		material.color_ramp = get_shock_gradient()
	return particles
