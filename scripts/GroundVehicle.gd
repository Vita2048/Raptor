extends Area2D

var traffic: Node2D
var route: Curve2D
var kind := "tank"
var anchor_y := 0.0
var cycle := -999
var progress := 0.0
var direction := 1.0
var map_position := Vector2.ZERO
var sprite: Sprite2D
var shadow: Sprite2D
var shape: CollisionShape2D
var gun: Node2D
var health := 72
var destroyed := false
var remains: Node2D
var fire_timer := 2.0
var charge := -1.0
var aim := Vector2.DOWN
var hit_time := 0.0
var footprint := Vector2(40, 70)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	shadow = Sprite2D.new()
	shadow.texture = AssetDB.vehicle_textures[kind]
	shadow.position = Vector2(-4, 6)
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = preload("res://shaders/shadow.gdshader")
	shadow.material = shadow_mat
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = AssetDB.vehicle_textures[kind]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * (74.0 if kind == "tank" else 66.0) / sprite.texture.get_height()
	sprite.modulate = Color(0.91, 0.88, 0.8)
	shadow.scale = sprite.scale
	footprint = sprite.texture.get_size() * sprite.scale
	add_child(sprite)
	shape = CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = footprint.x * 0.37
	capsule.height = footprint.y * 0.76
	shape.shape = capsule
	add_child(shape)
	gun = Node2D.new()
	gun.draw.connect(_draw_gun)
	add_child(gun)
	area_entered.connect(_on_area_entered)
	_update_position(0.0)

func _physics_process(delta: float) -> void:
	_update_position(delta)
	if destroyed or not visible:
		return
	hit_time = maxf(hit_time - delta, 0.0)
	sprite.modulate = Color(0.91, 0.88, 0.8).lerp(Color(1.9, 1.5, 1.0), hit_time / 0.12)
	if not traffic.combat_enabled():
		charge = -1.0
		fire_timer = maxf(fire_timer, 1.2)
		gun.queue_redraw()
		return
	# Never fire from outside the playfield or after passing the player.
	if position.y < 90 or position.y > 920 or global_position.distance_to(traffic.player.global_position) > 1050:
		charge = -1.0
		gun.queue_redraw()
		return
	if charge >= 0:
		charge -= delta
		if charge <= 0:
			traffic.shoot(global_position + aim * 20.0, aim, kind)
			charge = -1.0
			fire_timer = 2.8 if kind == "tank" else 3.4
	else:
		fire_timer -= delta
		if fire_timer <= 0:
			aim = (traffic.player.global_position - global_position).normalized()
			charge = 0.65
	gun.queue_redraw()

func _update_position(delta: float) -> void:
	var next_cycle := floori((anchor_y * traffic.background.image_scale + traffic.background.distance + 600.0) / traffic.background.loop_height)
	if next_cycle != cycle:
		cycle = next_cycle
		_reset_vehicle()
	if not destroyed and position.y > -160 and position.y < 1240 and GameState.game_active:
		progress = clampf(progress + direction * delta * (24.0 if kind == "tank" else 35.0), 0, route.get_baked_length())
		if progress >= route.get_baked_length(): direction = -1.0
		if progress <= 0: direction = 1.0
		map_position = route.sample_baked(progress)
		var ahead := route.sample_baked(clampf(progress + direction * 2.0, 0, route.get_baked_length()))
		var tangent := ahead - map_position
		if tangent.length_squared() > 0.01:
			sprite.rotation = lerp_angle(sprite.rotation, tangent.angle() + PI * 0.5, minf(delta * 6.0, 1.0))
			shape.rotation = sprite.rotation
			shadow.rotation = sprite.rotation
	position = traffic.map_to_screen(map_position, cycle)
	visible = position.y > -180 and position.y < 1280

func _reset_vehicle() -> void:
	if is_instance_valid(remains):
		remove_child(remains)
		remains.queue_free()
	destroyed = false
	health = 72 if kind == "tank" else 42
	progress = 0.0
	direction = 1.0
	map_position = route.sample_baked(0)
	sprite.rotation = (route.sample_baked(2) - map_position).angle() + PI * 0.5
	shadow.rotation = sprite.rotation
	shape.rotation = sprite.rotation
	charge = -1.0
	hit_time = 0.0
	fire_timer = 2.0
	sprite.show()
	shadow.show()
	gun.show()
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func _draw_gun() -> void:
	if destroyed:
		return
	if charge >= 0:
		var p := 1.0 - charge / 0.65
		gun.draw_arc(aim * 20.0, 14.0 - p * 7.0, 0, TAU, 24, Color(1.0, 0.64, 0.2, 0.8), 2, true)
		gun.draw_line(Vector2.ZERO, aim * 20.0, Color(0.2, 0.19, 0.16), 4, true)

func _on_area_entered(area: Area2D) -> void:
	if destroyed or not visible or not GameState.game_active:
		return
	if area.visible and area.has_method("is_player_damage") and area.is_player_damage():
		var amount: int = area.damage
		area.spawn_impact(global_position)
		area.return_to_pool()
		take_damage(amount)

func take_damage(amount: int) -> void:
	if destroyed or not GameState.game_active:
		return
	health = maxi(health - amount, 0)
	hit_time = 0.12
	if health > 0:
		return
	destroyed = true
	sprite.hide()
	shadow.hide()
	gun.hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	GameState.add_score(450 if kind == "tank" else 250)
	call_deferred("_create_remains")

func _create_remains() -> void:
	if not destroyed:
		return
	remains = preload("res://scripts/GroundRemains.gd").new()
	add_child(remains)
	remains.configure(Vector2(68, 60))
