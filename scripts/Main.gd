extends Node2D

const DebugOptions := preload("res://scripts/DebugOptions.gd")
const ScrollingBackgroundScript := preload("res://scripts/ScrollingBackground.gd")
const WorldSpawnerScript := preload("res://scripts/WorldSpawner.gd")
const PlayerShipScript := preload("res://scripts/PlayerShip.gd")
const EnemyManagerScript := preload("res://scripts/EnemyManager.gd")
const HUDScript := preload("res://scripts/HUD.gd")
const PauseMenuScript := preload("res://scripts/PauseMenu.gd")
const CaptureManagerScript := preload("res://scripts/CaptureManager.gd")
const ExplosionScene := preload("res://scenes/ExplosionEffect.tscn")

var background: Node2D
var world_spawner: Node2D
var player: Area2D
var enemy_manager: Node2D
var ground_traffic: Node2D
var hud: CanvasLayer
var pause_menu: CanvasLayer
var capture_manager: Node
var camera: Camera2D
var shake_strength := 0.0
var shake_time := 0.0

func _ready() -> void:
	randomize()
	PauseMenuScript.apply_saved_resolution()
	# Dying retries the current sector; victory, pause restart, and fresh launch start over.
	var retry_after_death := not GameState.game_active and not GameState.campaign_won
	var saved_checkpoint: int = GameState.checkpoint_level
	var retry_same_sector := retry_after_death and saved_checkpoint > 1
	GameState.reset(retry_same_sector)
	if retry_same_sector:
		GameState.restore_checkpoint()
	if DebugOptions.menu_requested() and DebugOptions.selected_level > 0:
		GameState.reset()
		while GameState.current_level < DebugOptions.selected_level:
			GameState.advance_level()
	_build_scene()
	VFX.warm_up()
	if GameState.current_level > 1 and (DebugOptions.menu_requested() or not DebugOptions.final_boss_requested()):
		world_spawner.rebuild_for_level(GameState.current_level)
	if DebugOptions.menu_requested():
		var debug_menu := preload("res://scripts/DebugMenu.gd").new()
		debug_menu.name = "DebugMenu"
		add_child(debug_menu)
		if DebugOptions.selected_level > 0 and DebugOptions.selected_boss:
			enemy_manager._spawn_boss()
	elif DebugOptions.final_boss_requested():
		_start_final_boss_debug()

func _start_final_boss_debug() -> void:
	GameState.advance_level()
	GameState.advance_level()
	world_spawner.rebuild_for_level(3)
	hud.level_label.text = "SECTOR 03 / BOSS TEST"
	# Use the real warning and entrance; don't fabricate score or previous kills.
	enemy_manager._spawn_boss()

func _build_scene() -> void:
	_add_world_environment()
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	VFX.camera_impulse.connect(_on_camera_impulse)

	background = ScrollingBackgroundScript.new()
	background.name = "ParallaxBackground"
	add_child(background)

	world_spawner = WorldSpawnerScript.new()
	world_spawner.name = "WorldSpawner"
	world_spawner.scroll_source = background
	add_child(world_spawner)
	var atmosphere := ColorRect.new()
	atmosphere.name = "GroundAtmosphere"
	atmosphere.position = Vector2(-12, -12)
	atmosphere.size = Vector2(1944, 1104)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.z_index = -5
	var atmosphere_material := ShaderMaterial.new()
	atmosphere_material.shader = preload("res://shaders/atmosphere.gdshader")
	atmosphere.material = atmosphere_material
	add_child(atmosphere)

	player = PlayerShipScript.new()
	player.name = "PlayerShip"
	player.position = Vector2(960, 820)
	add_child(player)

	enemy_manager = EnemyManagerScript.new()
	enemy_manager.name = "EnemyManager"
	enemy_manager.player = player
	add_child(enemy_manager)
	ground_traffic = preload("res://scripts/GroundTraffic.gd").new()
	ground_traffic.name = "GroundTraffic"
	ground_traffic.background = background
	ground_traffic.enemy_manager = enemy_manager
	ground_traffic.player = player
	add_child(ground_traffic)

	hud = HUDScript.new()
	hud.name = "HUD"
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)

	pause_menu = PauseMenuScript.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	capture_manager = CaptureManagerScript.new()
	capture_manager.name = "CaptureManager"
	add_child(capture_manager)

	GameState.game_over.connect(_on_game_over)
	GameState.campaign_completed.connect(_on_campaign_completed)

func _on_campaign_completed() -> void:
	player.bullet_pool.release_all()
	player.set_deferred("monitoring", false)
	player.set_deferred("monitorable", false)

func _on_camera_impulse(strength: float) -> void:
	shake_strength = minf(maxf(shake_strength, strength), 5.0)

func _process(delta: float) -> void:
	shake_time += delta
	shake_strength = move_toward(shake_strength, 0.0, delta * 18.0)
	camera.offset = Vector2(sin(shake_time * 83.0), cos(shake_time * 97.0)) * shake_strength

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
