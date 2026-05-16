extends Node2D

const ScrollingBackgroundScript := preload("res://scripts/ScrollingBackground.gd")
const WorldSpawnerScript := preload("res://scripts/WorldSpawner.gd")
const PlayerShipScript := preload("res://scripts/PlayerShip.gd")
const EnemyManagerScript := preload("res://scripts/EnemyManager.gd")
const HUDScript := preload("res://scripts/HUD.gd")

var background: Node2D
var world_spawner: Node2D
var player: Area2D
var enemy_manager: Node2D
var hud: CanvasLayer

func _ready() -> void:
	randomize()
	GameState.reset()
	_build_scene()

func _build_scene() -> void:
	background = ScrollingBackgroundScript.new()
	background.name = "ParallaxBackground"
	add_child(background)

	world_spawner = WorldSpawnerScript.new()
	world_spawner.name = "WorldSpawner"
	add_child(world_spawner)

	player = PlayerShipScript.new()
	player.name = "PlayerShip"
	player.position = Vector2(960, 820)
	add_child(player)

	enemy_manager = EnemyManagerScript.new()
	enemy_manager.name = "EnemyManager"
	enemy_manager.player = player
	add_child(enemy_manager)

	hud = HUDScript.new()
	hud.name = "HUD"
	add_child(hud)
