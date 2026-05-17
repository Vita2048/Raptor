extends Node2D

const ObjectPool := preload("res://scripts/ObjectPool.gd")
const MuzzleFlashScript := preload("res://scripts/MuzzleFlash.gd")
const ImpactSparkScript := preload("res://scripts/ImpactSpark.gd")
const ExplosionScene := preload("res://scenes/ExplosionEffect.tscn")

var muzzle_pool: ObjectPool
var impact_pool: ObjectPool

func _ready() -> void:
	z_index = 200
	muzzle_pool = ObjectPool.new(_create_muzzle_flash, self, 32)
	impact_pool = ObjectPool.new(_create_impact_spark, self, 48)

func muzzle_flash(pos: Vector2, direction: Vector2, player_owned: bool) -> void:
	var flash := muzzle_pool.acquire()
	var tint := Color(4.0, 1.8, 0.65, 1.0) if player_owned else Color(4.0, 0.55, 0.25, 1.0)
	flash.play_at(pos, direction.angle() + PI * 0.5, tint)

func impact_spark(pos: Vector2, velocity: Vector2, player_owned: bool) -> void:
	var spark := impact_pool.acquire()
	var tint := Color(4.0, 1.6, 0.55, 1.0) if player_owned else Color(4.0, 0.35, 0.2, 1.0)
	spark.play_at(pos, velocity, tint)

func boss_explosion(pos: Vector2) -> void:
	_spawn_large_explosion(pos)
	_play_boss_screen_blast(pos)
	var offsets := [
		Vector2(-210, -250),
		Vector2(225, -210),
		Vector2(-320, -25),
		Vector2(320, 20),
		Vector2(-175, 245),
		Vector2(185, 275),
		Vector2(0, -390),
		Vector2(0, 400)
	]
	for i in range(offsets.size()):
		_spawn_large_explosion_delayed(pos + offsets[i], 0.035 + i * 0.04)

func _create_muzzle_flash() -> Sprite2D:
	var flash := MuzzleFlashScript.new()
	flash.name = "PooledMuzzleFlash"
	return flash

func _create_impact_spark() -> GPUParticles2D:
	var spark := ImpactSparkScript.new()
	spark.name = "PooledImpactSpark"
	return spark

func _spawn_large_explosion(pos: Vector2) -> void:
	var explosion := ExplosionScene.instantiate()
	explosion.top_level = true
	explosion.global_position = pos
	explosion.configure(true)
	add_child(explosion)
	explosion.burst()

func _spawn_large_explosion_delayed(pos: Vector2, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_spawn_large_explosion(pos)

func _play_boss_screen_blast(pos: Vector2) -> void:
	var flash := Sprite2D.new()
	flash.name = "BossScreenBlast"
	flash.texture = AssetDB.flash_textures.pick_random()
	flash.top_level = true
	flash.global_position = pos
	flash.centered = true
	flash.z_index = 260
	flash.modulate = Color(5.0, 2.4, 0.9, 1.0)
	flash.scale = Vector2.ONE * 0.6
	add_child(flash)
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 5.0, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.42)
	await tween.finished
	flash.queue_free()
