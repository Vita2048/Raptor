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
	var boss_fire := preload("res://scripts/BossParticleFlames.gd")
	boss_fire.flame_texture()
	boss_fire.spark_texture()
	boss_fire.glow_texture()
	preload("res://scripts/EnergyItem.gd").warm_up()
	_precache_boss_hull_images()
	var anchor := Vector2(960, 700)
	var muzzle := muzzle_pool.acquire()
	muzzle.play_at(anchor, 0.0, Color(4.0, 1.8, 0.65, 1.0))
	var spark := impact_pool.acquire()
	spark.play_at(anchor, Vector2.DOWN, Color(4.0, 1.6, 0.55, 1.0))
	_spawn_warmup_explosion(anchor, false)
	_spawn_warmup_explosion(anchor, true)
	# Spread the remaining uploads over the first frames so the single-threaded
	# Web build doesn't freeze when sector-2/3 ships, white-puff variants,
	# crater/shadow/terrain shaders or boss layered flames appear mid-run.
	# Parented to the tree root (not VFX) so pool-count tests are unaffected.
	_warm_textures_and_shaders_async()

func _precache_boss_hull_images() -> void:
	# texture.get_image() does a CPU readback that stalled the first late-fight
	# rupture on Web. Cache all boss hulls once at startup; same pixels, no hitch.
	var refined := preload("res://scripts/BossRefinedDamage.gd")
	for kind in ["boss", "boss2", "boss3", "lancer", "sentinel"]:
		if not AssetDB.ship_textures.has(kind):
			continue
		var texture: Texture2D = AssetDB.ship_textures[kind]
		if texture == null or refined.hull_images.has(texture):
			continue
		# AtlasTextures (cropped bosses) cache their cropped image, same as the
		# rupture path uses.
		refined.hull_images[texture] = texture.get_image()

func _warm_textures_and_shaders_async() -> void:
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var textures := _collect_warmup_textures()
	var uploader := Node2D.new()
	uploader.name = "WebWarmupUploader"
	uploader.z_index = -500
	uploader.top_level = true
	uploader.global_position = Vector2(960, 700)
	get_tree().root.add_child(uploader)
	# Tiny, nearly invisible: still binds every texture + compiles CanvasItem
	# shaders, but no visible flash at boot.
	var batch_size := 6
	var idx := 0
	while idx < textures.size() and is_instance_valid(uploader):
		for child in uploader.get_children():
			if child.has_method("set_process"):
				child.set_process(false)
			child.queue_free()
		for i in range(batch_size):
			if idx >= textures.size():
				break
			var tex: Texture2D = textures[idx]
			idx += 1
			if tex == null:
				continue
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.scale = Vector2.ONE * 0.02
			spr.modulate = Color(1, 1, 1, 0.02)
			uploader.add_child(spr)
		await get_tree().process_frame
		if not is_instance_valid(uploader):
			return
		await get_tree().process_frame
	if is_instance_valid(uploader):
		_warm_shader_variants(uploader)
		_warm_boss_flames(uploader)
		await get_tree().process_frame
		await get_tree().process_frame
		uploader.queue_free()

func _collect_warmup_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var seen := {}
	for tex in AssetDB.background_textures:
		_push_warmup_tex(out, seen, tex)
	for tex in AssetDB.desert_textures:
		_push_warmup_tex(out, seen, tex)
	for tex in AssetDB.space_textures:
		_push_warmup_tex(out, seen, tex)
	for tex in AssetDB.sector_textures:
		_push_warmup_tex(out, seen, tex)
	if AssetDB.bridge_texture != null:
		_push_warmup_tex(out, seen, AssetDB.bridge_texture)
	for tex in AssetDB.building_textures:
		_push_warmup_tex(out, seen, tex)
	for tex in AssetDB.level2_building_textures:
		_push_warmup_tex(out, seen, tex)
	for key in AssetDB.building_textures_by_name:
		_push_warmup_tex(out, seen, AssetDB.building_textures_by_name[key])
	for tex in AssetDB.desert_buildings:
		_push_warmup_tex(out, seen, tex)
		var wreck: Texture2D = (tex as AtlasTexture).get_meta("destroyed_texture", null) if tex != null and tex.has_meta("destroyed_texture") else null
		if wreck != null:
			_push_warmup_tex(out, seen, wreck)
			if wreck is AtlasTexture and (wreck as AtlasTexture).atlas != null:
				_push_warmup_tex(out, seen, (wreck as AtlasTexture).atlas)
		if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
			_push_warmup_tex(out, seen, (tex as AtlasTexture).atlas)
	for key in AssetDB.ship_textures:
		_push_warmup_tex(out, seen, AssetDB.ship_textures[key])
		var st: Texture2D = AssetDB.ship_textures[key]
		if st is AtlasTexture and (st as AtlasTexture).atlas != null:
			_push_warmup_tex(out, seen, (st as AtlasTexture).atlas)
	for tex in AssetDB.flash_textures:
		_push_warmup_tex(out, seen, tex)
	for tex in AssetDB.explosion_textures:
		_push_warmup_tex(out, seen, tex)
	for tex in AssetDB.white_puff_textures:
		_push_warmup_tex(out, seen, tex)
	for tex in AssetDB.black_smoke_textures:
		_push_warmup_tex(out, seen, tex)
	if AssetDB.bomb_texture != null:
		_push_warmup_tex(out, seen, AssetDB.bomb_texture)
	if AssetDB.crater_texture != null:
		_push_warmup_tex(out, seen, AssetDB.crater_texture)
		if AssetDB.crater_texture is AtlasTexture and (AssetDB.crater_texture as AtlasTexture).atlas != null:
			_push_warmup_tex(out, seen, (AssetDB.crater_texture as AtlasTexture).atlas)
	for key in AssetDB.vehicle_textures:
		_push_warmup_tex(out, seen, AssetDB.vehicle_textures[key])
	_push_warmup_tex(out, seen, preload("res://scripts/EnergyItem.gd").ENERGY_TEXTURE)
	if preload("res://scripts/EnergyItem.gd").radial_light_texture != null:
		_push_warmup_tex(out, seen, preload("res://scripts/EnergyItem.gd").radial_light_texture)
	_push_warmup_tex(out, seen, preload("res://scripts/BossParticleFlames.gd").flame_texture())
	_push_warmup_tex(out, seen, preload("res://scripts/BossParticleFlames.gd").spark_texture())
	_push_warmup_tex(out, seen, preload("res://scripts/BossParticleFlames.gd").glow_texture())
	return out

func _push_warmup_tex(out: Array[Texture2D], seen: Dictionary, tex: Texture2D) -> void:
	if tex == null or seen.has(tex.get_rid()):
		return
	seen[tex.get_rid()] = true
	out.append(tex)

func _warm_shader_variants(parent: Node) -> void:
	# One draw of each custom canvas_item shader so WebGL compiles them at boot.
	# All tiny + nearly transparent; same shaders, same output, no visual change.
	var dummy_tex: Texture2D = AssetDB.flash_textures[0] if not AssetDB.flash_textures.is_empty() else null
	if dummy_tex == null:
		return
	var crater_mat := ShaderMaterial.new()
	crater_mat.shader = preload("res://shaders/crater.gdshader")
	var crater := Sprite2D.new()
	crater.texture = AssetDB.crater_texture if AssetDB.crater_texture != null else dummy_tex
	crater.material = crater_mat
	crater.scale = Vector2.ONE * 0.02
	crater.modulate = Color(1, 1, 1, 0.02)
	parent.add_child(crater)
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = preload("res://shaders/shadow.gdshader")
	var shadow := Sprite2D.new()
	shadow.texture = dummy_tex
	shadow.material = shadow_mat
	shadow.scale = Vector2.ONE * 0.02
	shadow.modulate = Color(1, 1, 1, 0.02)
	parent.add_child(shadow)
	for accent in [false, true]:
		var hit_mat := ShaderMaterial.new()
		hit_mat.shader = preload("res://shaders/ship_hit.gdshader")
		hit_mat.set_shader_parameter("player_accent", accent)
		var ship := Sprite2D.new()
		ship.texture = dummy_tex
		ship.material = hit_mat
		ship.scale = Vector2.ONE * 0.02
		ship.modulate = Color(1, 1, 1, 0.02)
		parent.add_child(ship)
	for animate in [false, true]:
		var grade := ShaderMaterial.new()
		grade.shader = preload("res://shaders/terrain.gdshader")
		grade.set_shader_parameter("animate_water", animate)
		if AssetDB.sector_textures.size() >= 2:
			grade.set_shader_parameter("current_map", AssetDB.sector_textures[0])
			grade.set_shader_parameter("next_map", AssetDB.sector_textures[1])
		var ground := Sprite2D.new()
		ground.texture = dummy_tex
		ground.material = grade
		ground.scale = Vector2.ONE * 0.02
		ground.modulate = Color(1, 1, 1, 0.02)
		parent.add_child(ground)
	var atmo_mat := ShaderMaterial.new()
	atmo_mat.shader = preload("res://shaders/atmosphere.gdshader")
	var atmo := ColorRect.new()
	atmo.material = atmo_mat
	atmo.size = Vector2(8, 8)
	atmo.position = Vector2(-4, -4)
	atmo.modulate = Color(1, 1, 1, 0.02)
	atmo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(atmo)
	# Energy-item PointLight blend path (glow) without a gameplay pickup.
	var glow_light := PointLight2D.new()
	glow_light.texture = preload("res://scripts/BossParticleFlames.gd").glow_texture()
	glow_light.energy = 0.02
	glow_light.texture_scale = 0.05
	parent.add_child(glow_light)

func _warm_boss_flames(parent: Node) -> void:
	# Build the full layered-flame stack once (flames + cores + tongues +
	# embers + lights) at minimal strength so CPUParticles/PointLight shaders
	# compile at boot instead of on the first damaged boss. Invisible.
	var host := preload("res://scripts/BossRefinedDamage.gd").new()
	host.sites = [Vector2(-20, 0), Vector2(20, 0), Vector2(0, 20)]
	host.fire_strength = 0.05
	host.smoke_strength = 0.02
	host.damage_amount = 0.3
	host.flame_lean = 0.0
	parent.add_child(host)
	var layered := preload("res://scripts/BossLayeredFlames.gd").new()
	layered.host = host
	host.add_child(layered)
	host.realistic_layer = layered
	layered.set_active(true)

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
	# Restore the wide, overlapping boss detonation and its expanding screen flash.
	_spawn_large_explosion(pos, scale_multiplier * 2.2)
	_play_boss_screen_blast(pos, scale_multiplier)
	var offsets := [
		Vector2(-210, -250), Vector2(225, -210),
		Vector2(-320, -25), Vector2(320, 20),
		Vector2(-175, 245), Vector2(185, 275)
	]
	for i in range(offsets.size()):
		_spawn_rupture_delayed(pos + offsets[i] * scale_multiplier, 0.035 + float(i) * 0.04, scale_multiplier)

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

func _spawn_rupture_delayed(pos: Vector2, delay: float, scale_multiplier: float) -> void:
	await get_tree().create_timer(delay).timeout
	var explosion := ExplosionScene.instantiate()
	explosion.top_level = true
	explosion.global_position = pos
	explosion.configure(true, scale_multiplier * 1.4)
	add_child(explosion)
	explosion.burst()

func _play_boss_screen_blast(pos: Vector2, scale_multiplier: float) -> void:
	var flash := Sprite2D.new()
	flash.name = "BossScreenBlast"
	flash.texture = AssetDB.flash_textures[0]
	flash.global_position = pos
	flash.z_index = 260
	flash.modulate = Color(5.0, 2.4, 0.9, 1.0)
	flash.scale = Vector2.ONE * 0.42 * scale_multiplier
	add_child(flash)
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 3.5 * scale_multiplier, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.42)
	tween.chain().tween_callback(flash.queue_free)
