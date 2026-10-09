extends Node2D

signal camera_impulse(strength: float)
var audio: Node

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const MuzzleFlashScript := preload("res://scripts/MuzzleFlash.gd")
const ImpactSparkScript := preload("res://scripts/ImpactSpark.gd")
const ExplosionScene := preload("res://scenes/ExplosionEffect.tscn")

var muzzle_pool: ObjectPool
var impact_pool: ObjectPool
var _warmed := false

func _ready() -> void:
	audio = preload("res://scripts/CombatAudio.gd").new()
	add_child(audio)
	z_index = 200
	muzzle_pool = ObjectPool.new(_create_muzzle_flash, self, 32)
	impact_pool = ObjectPool.new(_create_impact_spark, self, 48)

func warm_up() -> void:
	# Prebuffer every effect kind once (small/large explosion, muzzle, spark)
	# so WebGL compiles shaders and uploads textures at startup instead of
	# freezing on the first mid-combat explosion. Quiet: no sound or shake.
	if _warmed:
		return
	_warmed = true
	var anchor := Vector2(960, 700)
	var muzzle := muzzle_pool.acquire()
	muzzle.play_at(anchor, 0.0, Color(4.0, 1.8, 0.65, 1.0))
	var spark := impact_pool.acquire()
	spark.play_at(anchor, Vector2.DOWN, Color(4.0, 1.6, 0.55, 1.0))
	_spawn_warmup_explosion(anchor, false)
	_spawn_warmup_explosion(anchor, true)

func _spawn_warmup_explosion(pos: Vector2, is_large: bool) -> void:
	var explosion = ExplosionScene.instantiate()
	explosion.top_level = true
	explosion.global_position = pos
	explosion.configure(is_large, 0.5)
	add_child(explosion)
	explosion.burst(true)

func muzzle_flash(pos: Vector2, direction: Vector2, player_owned: bool, quiet := false) -> void:
	if not player_owned and not quiet:
		audio.play_sound("enemy")
	var flash := muzzle_pool.acquire()
	var tint := Color(4.0, 1.8, 0.65, 1.0) if player_owned else Color(4.0, 0.55, 0.25, 1.0)
	flash.play_at(pos, direction.angle() + PI * 0.5, tint)

func impact_spark(pos: Vector2, velocity: Vector2, player_owned: bool, quiet := false) -> void:
	if not quiet:
		audio.play_sound("impact")
	var spark := impact_pool.acquire()
	var tint := Color(4.0, 1.6, 0.55, 1.0) if player_owned else Color(4.0, 0.35, 0.2, 1.0)
	spark.play_at(pos, velocity, tint)

func boss_explosion(pos: Vector2, scale_multiplier: float = 1.0) -> void:
	_spawn_large_explosion(pos, scale_multiplier)
	_play_boss_screen_blast(pos, scale_multiplier)
	var offsets := [
		Vector2(-210, -250),
		Vector2(225, -210),
		Vector2(-320, -25),
		Vector2(320, 20),
		Vector2(-175, 245),
		Vector2(185, 275)
	]
	for i in range(offsets.size()):
		_spawn_large_explosion_delayed(pos + offsets[i] * scale_multiplier, 0.035 + i * 0.04, scale_multiplier)

func _create_muzzle_flash() -> Sprite2D:
	var flash := MuzzleFlashScript.new()
	flash.name = "PooledMuzzleFlash"
	return flash

func _create_impact_spark() -> GPUParticles2D:
	var spark := ImpactSparkScript.new()
	spark.name = "PooledImpactSpark"
	return spark

func _spawn_large_explosion(pos: Vector2, scale_multiplier: float = 1.0) -> void:
	var explosion := ExplosionScene.instantiate()
	explosion.top_level = true
	explosion.global_position = pos
	explosion.configure(true, scale_multiplier)
	add_child(explosion)
	explosion.burst()

func _spawn_large_explosion_delayed(pos: Vector2, delay: float, scale_multiplier: float = 1.0) -> void:
	await get_tree().create_timer(delay).timeout
	_spawn_large_explosion(pos, scale_multiplier)

func _play_boss_screen_blast(pos: Vector2, scale_multiplier: float = 1.0) -> void:
	var flash := Sprite2D.new()
	flash.name = "BossScreenBlast"
	flash.texture = AssetDB.flash_textures.pick_random()
	flash.top_level = true
	flash.global_position = pos
	flash.centered = true
	flash.z_index = 260
	flash.modulate = Color(5.0, 2.4, 0.9, 1.0)
	flash.scale = Vector2.ONE * 0.42 * scale_multiplier
	add_child(flash)
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 3.5 * scale_multiplier, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.42)
	await tween.finished
	flash.queue_free()
