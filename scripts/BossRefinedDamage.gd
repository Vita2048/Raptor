extends "res://scripts/BossDamageEffect.gd"
## Boss damage staging with coupled layered fire, cooling smoke and hull ruptures.

var hull_velocity := Vector2.ZERO
var ruptures_enabled := true
var rupture_delay := 0.8
var rupture_count := 0
static var hull_images: Dictionary = {}

func reset() -> void:
	hull_velocity = Vector2.ZERO
	rupture_delay = 0.8
	rupture_count = 0
	for child in get_children():
		if child.has_meta("hull_rupture"):
			child.free()
	super.reset()

func _process(delta: float) -> void:
	if fire_strength > 0.0 and not is_instance_valid(realistic_layer):
		realistic_layer = preload("res://scripts/BossLayeredFlames.gd").new()
		realistic_layer.host = self
		add_child(realistic_layer)
		realistic_layer.set_active(true)
	if has_previous_position and delta > 0.0:
		var measured := (global_position - previous_position) / delta
		hull_velocity = hull_velocity.lerp(measured, 1.0 - exp(-delta * 12.0))
	for puff in particles:
		# Cooling gas slows and rolls outward after it leaves the flame.
		var roll := sin(float(puff.age) * 3.5 + float(puff.get("phase", 0.0)))
		puff.velocity = puff.velocity.lerp(Vector2(roll * 10.0, -24), 1.0 - exp(-delta * 1.8))
	super._process(delta)
	_update_ruptures(delta)

func _update_ruptures(delta: float) -> void:
	var ship := get_parent()
	if not ruptures_enabled or not is_visible_in_tree() or ship == null or not ship.get("is_boss") or ship.get("is_dead") or ship.health >= ship.max_health * 0.25:
		rupture_delay = 0.65
		return
	rupture_delay -= delta
	if rupture_delay > 0.0:
		return
	rupture_delay = randf_range(0.65, 1.4)
	var existing := 0
	for child in get_children():
		if child.has_meta("hull_rupture"):
			existing += 1
	if existing >= 3:
		return
	var sprite: Sprite2D = ship.sprite
	var texture: Texture2D = sprite.texture
	if texture == null:
		return
	if not hull_images.has(texture):
		hull_images[texture] = texture.get_image()
	var image: Image = hull_images[texture]
	for attempt in range(40):
		var pixel := Vector2i(randi_range(0, image.get_width() - 1), randi_range(0, image.get_height() - 1))
		if image.get_pixelv(pixel).a < 0.75:
			continue
		var point := Vector2(pixel) - texture.get_size() * 0.5
		var burst = preload("res://scenes/ExplosionEffect.tscn").instantiate()
		burst.set_meta("hull_rupture", true)
		burst.position = to_local(sprite.to_global(point))
		burst.configure(false, randf_range(0.24, 0.38))
		add_child(burst)
		burst.burst(true)
		rupture_count += 1
		break

func _emit_smoke(site: Vector2, spread: float, source: int) -> void:
	if not is_instance_valid(realistic_layer):
		super._emit_smoke(site, spread, source)
		return
	if particles.size() >= 128:
		return
	var direction: Vector2 = realistic_layer.flow(source)
	var acceleration: Vector2 = realistic_layer.acceleration(source)
	var heat: float = realistic_layer.heat(source)
	# Approximate the cooling end of the same particle trajectory.
	var cooling_age := 0.42
	var local_velocity := hull_velocity.rotated(-global_rotation)
	var offset := Vector2(0, -16) + direction * 70.0 * heat * cooling_age + acceleration * cooling_age * cooling_age * 0.5
	# Match the partial velocity inheritance of the detached upper tongues.
	offset -= (local_velocity * cooling_age * 0.30).limit_length(30.0)
	var velocity := (direction * 70.0 * heat + acceleration * cooling_age).rotated(global_rotation)
	particles.append({"pos": to_global(site + offset + Vector2(randf_range(-3, 3), randf_range(-2, 2))),
		"velocity": velocity + hull_velocity * 0.70,
		"age": 0.0, "life": randf_range(1.3, 1.8),
		"size": randf_range(20, 29) * lerpf(0.55, 1.2, smoke_strength),
		"phase": randf_range(0.0, TAU), "rotation": randf_range(-PI, PI),
		"source": source, "strength": smoke_strength * spread * heat})

func _draw() -> void:
	var frames: Array[Texture2D] = AssetDB.black_smoke_textures
	if frames.is_empty():
		return
	for puff in particles:
		var t: float = clampf(puff.age / puff.life, 0.0, 1.0)
		var progression := t * float(frames.size() - 1)
		var frame := int(progression)
		var blend := progression - float(frame)
		var size: float = puff.size * lerpf(0.65, 2.5, ease(t, 0.75))
		# Warm soot appears softly at the cooling tip, turns charcoal, then
		# thins into cooler grey. No opaque puff popping out of the fire base.
		var color := Color(0.48, 0.30, 0.19).lerp(Color(0.36, 0.35, 0.34), smoothstep(0.0, 0.22, t))
		color = color.lerp(Color(0.70, 0.71, 0.73), smoothstep(0.25, 1.0, t))
		color.a = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.35, 1.0, t)) * float(puff.strength) * 0.55
		var rotation_angle: float = puff.get("rotation", 0.0) + sin(float(puff.get("phase", 0.0))) * t * 0.35
		draw_set_transform(to_local(puff.pos), rotation_angle - global_rotation)
		var rect := Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size)
		var next_color := color
		color.a *= 1.0 - blend
		next_color.a *= blend
		draw_texture_rect(frames[frame], rect, false, color)
		draw_texture_rect(frames[mini(frame + 1, frames.size() - 1)], rect, false, next_color)
	draw_set_transform(Vector2.ZERO)
