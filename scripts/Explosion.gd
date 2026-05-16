extends Node2D

var lifetime := 2.2

func _ready() -> void:
	if get_child_count() == 0:
		_build_particles()

func burst() -> void:
	for child in get_children():
		if child is GPUParticles2D:
			child.restart()
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _build_particles() -> void:
	_add_burst_layer("FlashBurst", AssetDB.random_particle("flash"), 36, 0.26, 620.0, 0.04, 0.34, Color(1, 0.9, 0.42, 1), Color(1, 0.15, 0.02, 0))
	_add_burst_layer("FireballBurst", AssetDB.random_particle("explosion"), 34, 0.42, 420.0, 0.08, 0.52, Color(1, 0.38, 0.08, 0.95), Color(0.45, 0.05, 0.01, 0))
	_add_burst_layer("WhitePuff", AssetDB.random_particle("white_puff"), 32, 0.92, 250.0, 0.12, 0.78, Color(0.95, 0.92, 0.82, 0.85), Color(0.8, 0.8, 0.8, 0))
	_add_burst_layer("BlackSmoke", AssetDB.random_particle("black_smoke"), 28, 1.85, 105.0, 0.2, 1.08, Color(0.1, 0.1, 0.1, 0.78), Color(0.06, 0.06, 0.06, 0))

func _add_burst_layer(layer_name: String, texture: Texture2D, amount: int, particle_lifetime: float, speed: float, scale_min: float, scale_max: float, start_color: Color, end_color: Color) -> void:
	var particles := GPUParticles2D.new()
	particles.name = layer_name
	particles.texture = texture
	particles.amount = amount
	particles.lifetime = particle_lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.85
	particles.emitting = false
	particles.local_coords = false
	particles.z_index = 80

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 16.0
	material.direction = Vector3(0, -0.1, 0)
	material.spread = 180.0
	material.initial_velocity_min = speed * 0.35
	material.initial_velocity_max = speed
	material.angular_velocity_min = -360.0
	material.angular_velocity_max = 360.0
	material.scale_min = scale_min
	material.scale_max = scale_max
	material.damping_min = 20.0
	material.damping_max = 85.0

	var gradient := Gradient.new()
	gradient.set_color(0, start_color)
	gradient.set_color(1, end_color)
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	particles.process_material = material
	add_child(particles)
