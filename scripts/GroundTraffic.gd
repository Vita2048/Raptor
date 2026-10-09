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
		vehicle.kind = "tank" if i % 2 == 0 else "truck"
		vehicle.route = Curve2D.new()
		for point in ROUTES[i]:
			vehicle.route.add_point(point)
		vehicle.anchor_y = ROUTES[i][0].y
		add_child(vehicle)
		vehicles.append(vehicle)

func combat_enabled() -> bool:
	return GameState.game_active and not GameState.boss_active and not enemy_manager.boss_pending

func map_to_screen(point: Vector2, cycle: int) -> Vector2:
	return Vector2(point.x * background.image_scale * 1.012 - 11.52,
		point.y * background.image_scale + background.distance - cycle * background.loop_height)

func shoot(origin: Vector2, direction: Vector2, kind: String) -> void:
	if not combat_enabled():
		return
	VFX.muzzle_flash(origin, direction, false)
	enemy_manager._on_enemy_request_fire(origin, [direction], 350.0 if kind == "tank" else 410.0, 12 if kind == "tank" else 8)
