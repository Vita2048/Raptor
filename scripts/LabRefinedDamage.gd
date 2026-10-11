extends "res://scripts/BossDamageEffect.gd"
## Production staging, with experimental fire-to-smoke coupling in the lab.

var hull_velocity := Vector2.ZERO

func _process(delta: float) -> void:
	if fire_strength > 0.0 and not is_instance_valid(realistic_layer):
		realistic_layer = preload("res://scripts/LabRefinedFlames.gd").new()
		realistic_layer.host = self
		add_child(realistic_layer)
		realistic_layer.set_active(true)
	if has_previous_position and delta > 0.0:
		hull_velocity = (global_position - previous_position) / delta
	for puff in particles:
		# Smoke initially inherits flow, then slows into the existing smoke drift.
		puff.velocity = puff.velocity.lerp(Vector2(0, -32), 1.0 - exp(-delta * 2.2))
	super._process(delta)

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
	var cooling_age := 0.38
	var offset := Vector2(0, -16) + direction * 60.0 * heat * cooling_age + acceleration * cooling_age * cooling_age * 0.5
	var velocity := (direction * 60.0 * heat + acceleration * cooling_age).rotated(global_rotation)
	particles.append({"pos": to_global(site + offset + Vector2(randf_range(-3, 3), randf_range(-2, 2))),
		"velocity": velocity + hull_velocity * 0.25,
		"age": 0.0, "life": randf_range(0.9, 1.3),
		"size": randf_range(20, 29) * lerpf(0.55, 1.2, smoke_strength),
		"source": source, "strength": smoke_strength * spread * heat})
