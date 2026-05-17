extends GPUParticles2D

var pool
var ring: Sprite2D

func _ready() -> void:
	z_index = 125
	amount = 8
	one_shot = true
	explosiveness = 1.0
	randomness = 0.5
	lifetime = 0.25
	local_coords = false
	emitting = false
	texture = AssetDB.random_particle("flash")
	
	ring = Sprite2D.new()
	var pm := CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = pm
	ring.visible = false
	add_child(ring)

func set_pool(value) -> void:
	pool = value

func play_at(pos: Vector2, bullet_velocity: Vector2, tint: Color) -> void:
	global_position = pos
	texture = AssetDB.random_particle("flash")
	amount = randi_range(8, 12)
	lifetime = 0.25
	visible = true
	
	ring.texture = AssetDB.random_particle("flash")
	ring.modulate = tint
	ring.scale = Vector2.ONE * 0.05
	ring.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 0.15, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func(): ring.visible = false)
	var direction := -bullet_velocity.normalized()
	if direction.length_squared() == 0.0:
		direction = Vector2.UP

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = 34.0
	material.initial_velocity_min = 520.0
	material.initial_velocity_max = 880.0
	material.damping_min = 520.0
	material.damping_max = 760.0
	material.scale_min = 0.01
	material.scale_max = 0.025
	material.angular_velocity_min = -420.0
	material.angular_velocity_max = 420.0
	material.gravity = Vector3.ZERO

	var gradient := Gradient.new()
	gradient.set_color(0, tint)
	gradient.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture
	process_material = material
	restart()
	await get_tree().create_timer(0.25).timeout
	if pool != null:
		pool.release(self)

func on_pool_released() -> void:
	emitting = false
	visible = false
