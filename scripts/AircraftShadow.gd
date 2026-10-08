extends Sprite2D

var source: Sprite2D

func _init() -> void:
	z_index = -10
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/shadow.gdshader")

func _process(_delta: float) -> void:
	if not is_instance_valid(source):
		return
	texture = source.texture
	scale = source.scale * 0.96
	rotation = source.rotation
	# Keep the sunlight direction fixed while the aircraft banks.
	position = Vector2(-28, 38).rotated(-get_parent().global_rotation)
