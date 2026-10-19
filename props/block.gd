@tool
extends StaticBody3D
class_name LevelBlock
## =========================================================================
## LevelBlock  -  the reusable "grey box" you build levels out of.
## =========================================================================
## Drag props/block.tscn into a scene, then in the Inspector change:
##     size      -> the box size (X, Y, Z)  - updates mesh AND collision
##     material  -> optional look
## Because the script is a "@tool" script you see the change instantly in
## the editor, and the collision box always matches the visual box.
## =========================================================================

@export var size: Vector3:
	get:
		return _size
	set(value):
		_size = Vector3(maxf(value.x, 0.05), maxf(value.y, 0.05), maxf(value.z, 0.05))
		_apply()

@export var material: StandardMaterial3D:
	get:
		return _material
	set(value):
		_material = value
		_apply()

var _size := Vector3(4.0, 3.0, 4.0)
var _material: StandardMaterial3D


func _ready() -> void:
	_apply()
	# The HUD minimap harvests the layout from every LevelBlock in the scene,
	# so levels never have to describe their own map.
	if not Engine.is_editor_hint():
		add_to_group("level_block")


func _apply() -> void:
	var m := get_node_or_null("Mesh") as MeshInstance3D
	if m != null:
		if m.mesh is BoxMesh:
			(m.mesh as BoxMesh).size = _size
		m.material_override = _material
	var c := get_node_or_null("Collision") as CollisionShape3D
	if c != null and c.shape is BoxShape3D:
		(c.shape as BoxShape3D).size = _size
