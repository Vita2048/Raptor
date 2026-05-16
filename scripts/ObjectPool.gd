extends RefCounted
class_name ObjectPool

var factory: Callable
var inactive: Array = []
var active: Array = []
var parent: Node

func _init(factory_callable: Callable = Callable(), pool_parent: Node = null, initial_size: int = 0) -> void:
	factory = factory_callable
	parent = pool_parent
	for i in range(initial_size):
		var node = _create_node()
		release(node)

func acquire() -> Node:
	var node: Node
	if inactive.is_empty():
		node = _create_node()
	else:
		node = inactive.pop_back()
	active.append(node)
	node.visible = true
	node.set_process(true)
	node.set_physics_process(true)
	if node.has_method("on_pool_acquired"):
		node.on_pool_acquired()
	return node

func release(node: Node) -> void:
	if node == null:
		return
	active.erase(node)
	if not inactive.has(node):
		inactive.append(node)
	node.visible = false
	node.set_process(false)
	node.set_physics_process(false)
	if node is CollisionObject2D:
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)
	if node.has_method("on_pool_released"):
		node.on_pool_released()

func release_all() -> void:
	for node in active.duplicate():
		release(node)

func _create_node() -> Node:
	var node = factory.call()
	if parent != null and node.get_parent() == null:
		parent.add_child(node)
	node.visible = false
	node.set_process(false)
	node.set_physics_process(false)
	if node.has_method("set_pool"):
		node.set_pool(self)
	return node
