extends SceneTree

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var assets = root.get_node("AssetDB")
	DirAccess.make_dir_recursive_absolute("res://assets/collision")
	for kind in ["boss", "boss2", "boss3"]:
		var data = load("res://scripts/BossCollisionData.gd").new()
		var img: Image = assets.ship_textures[kind].get_image()
		if img.is_compressed():
			img.decompress()
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(img, 0.08)
		var size := Vector2(img.get_size())
		for polygon in bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, size), 8.0):
			var area := 0.0
			for i in polygon.size():
				area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
			if absf(area) * 0.5 < 96.0:
				continue
			var centered := PackedVector2Array()
			for point in polygon:
				centered.append(point - size * 0.5)
			for convex in Geometry2D.decompose_polygon_in_convex(centered):
				var shape := ConvexPolygonShape2D.new()
				shape.points = convex
				data.shapes.append(shape)
		assert(not data.shapes.is_empty())
		assert(ResourceSaver.save(data, "res://assets/collision/" + kind + ".tres") == OK)
		print("BAKED ", kind, " shapes=", data.shapes.size())
	quit()

