extends Node2D

const Vehicle := preload("res://scripts/GroundVehicle.gd")
var background: Node2D
var enemy_manager: Node2D
var player: Area2D
var vehicles: Array[Area2D] = []

# Pixel coordinates on dessert_bridges.png (1024 x 2048).
# Bridge routes stay between the two banks, clear of the structure spawn rectangles.
const ROUTES := [
	[Vector2(350, 252), Vector2(500, 252), Vector2(675, 252)],
	[Vector2(680, 772), Vector2(510, 772), Vector2(350, 772)],
	[Vector2(905, 35), Vector2(914, 125), Vector2(940, 228), Vector2(931, 302), Vector2(897, 380)],
	[Vector2(151, 1120), Vector2(122, 1200), Vector2(127, 1280), Vector2(165, 1350), Vector2(192, 1430)]
]

func _ready() -> void:
	z_index = -12
	for i in range(ROUTES.size()):
		var vehicle := Vehicle.new()
		vehicle.traffic = self
		vehicle.traffic_route_index = i
		vehicle.kind = "tank" if i % 2 == 0 else "truck"
		vehicle.route = Curve2D.new()
		for point in ROUTES[i]:
			vehicle.route.add_point(point)
		vehicle.anchor_y = ROUTES[i][0].y
		add_child(vehicle)
		vehicles.append(vehicle)

func combat_enabled() -> bool:
	return GameState.game_active and not GameState.boss_active and not enemy_manager.boss_pending

func map_to_screen(point: Vector2, cycle: int, route_index := -1) -> Vector2:
	var y: float = point.y * background.image_scale + background.distance - cycle * background.loop_height
	# New terrain moves the outer service roads inward. Follow the same advancing
	# blend as the terrain, preserving each vehicle's route progress and wreck state.
	var arrival := smoothstep(y / 1080.0 - 0.18, y / 1080.0 + 0.18, background.transition_progress * 1.4 - 0.2)
	var old_offset := _road_offset(background.previous_sector, route_index)
	var new_offset := _road_offset(background.terrain_sector, route_index)
	var x := point.x + lerpf(old_offset, new_offset, arrival)
	return Vector2(x * background.image_scale * 1.012 - 11.52, y)

func _road_offset(sector: int, route_index: int) -> float:
	if sector < 2:
		return 0.0
	if route_index == 2:
		return -90.0
	if route_index == 3:
		return 65.0
	return 0.0

func shoot(origin: Vector2, direction: Vector2, kind: String) -> void:
	if not combat_enabled():
		return
	VFX.muzzle_flash(origin, direction, false)
	enemy_manager._on_enemy_request_fire(origin, [direction], 350.0 if kind == "tank" else 410.0, 12 if kind == "tank" else 8)
