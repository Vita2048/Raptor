extends Node2D

const BackgroundGeneratorScript := preload("res://scripts/BackgroundGenerator.gd")
const WorldSpawnerScript := preload("res://scripts/WorldSpawner.gd")
const PlayerShipScript := preload("res://scripts/PlayerShip.gd")
const EnemyManagerScript := preload("res://scripts/EnemyManager.gd")
const HUDScript := preload("res://scripts/HUD.gd")
const ExplosionScene := preload("res://scenes/ExplosionEffect.tscn")

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
	_add_world_environment()

	background = get_node_or_null("ProceduralBackground") as Node2D
	if background == null:
		background = BackgroundGeneratorScript.new()
		background.name = "ProceduralBackground"
		add_child(background)

	world_spawner = WorldSpawnerScript.new()
	world_spawner.name = "WorldSpawner"
	world_spawner.scroll_source = background
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

	GameState.game_over.connect(_on_game_over)
	GameState.level_advanced.connect(_on_level_advanced)

func _on_game_over() -> void:
	# Explode the player ship then hide it
	if is_instance_valid(player):
		var death_pos := player.global_position
		# Spawn large explosion at player position
		var explosion := ExplosionScene.instantiate()
		explosion.top_level = true
		explosion.global_position = death_pos
		explosion.configure(true)
		add_child(explosion)
		explosion.burst()
		# A second delayed smaller burst for drama
		await get_tree().create_timer(0.18).timeout
		if is_instance_valid(self):
			var explosion2 := ExplosionScene.instantiate()
			explosion2.top_level = true
			explosion2.global_position = death_pos + Vector2(randf_range(-60, 60), randf_range(-60, 60))
			explosion2.configure(false)
			add_child(explosion2)
			explosion2.burst()
		# Hide ship
		if is_instance_valid(player):
			player.visible = false
			player.set_deferred("monitoring", false)
			player.set_deferred("monitorable", false)

func _on_level_advanced(new_level: int) -> void:
	if background != null and background.has_method("rebuild_for_level"):
		background.call_deferred("rebuild_for_level", new_level)

func _add_world_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "BloomWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_strength = 0.85
	environment.glow_bloom = 0.18
	environment.glow_hdr_threshold = 1.05
	environment.glow_hdr_scale = 1.35
	world_environment.environment = environment
	add_child(world_environment)
