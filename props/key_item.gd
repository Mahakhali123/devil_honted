extends Interactable
class_name KeyItem
## =========================================================================
## KeyItem  -  a collectible key
## =========================================================================
## Attached to props/key_item.tscn (which is just a body + glow; the key
## shape is built in code so the scene stays readable).
##
## Set `key_id` in the level, then set the SAME string on a door's
## `required_key` and the door unlocks the moment you pick the key up.
## =========================================================================

@export var key_id := "armoury_key"
@export var key_label := "Rusted Armoury Key"
@export var key_color := Color(0.90, 0.76, 0.32)


func _ready() -> void:
	super._ready()
	add_to_group("pickup")
	float_and_spin = true
	_build()


func get_interact_text() -> String:
	return "Pick up  %s" % key_label


func _on_interact(_player: Node) -> void:
	GameManager.collect_key(key_id, key_label)
	ProcAudio.play_pickup()
	GameManager.show_message("Picked up %s." % key_label, 2.6)
	hide_and_disable()


# =========================================================================
#  PROCEDURAL KEY SHAPE
# =========================================================================
func _build() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return
	for c in model.get_children():
		c.queue_free()

	var gold := _mat(key_color, Color(0.42, 0.31, 0.07), 1.1, 0.3, 0.9)
	var dark := _mat(key_color.darkened(0.35), Color(0, 0, 0), 0.0, 0.45, 0.85)

	# Ring (the bit you hold)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.048
	torus.outer_radius = 0.078
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.set_surface_override_material(0, gold)
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	ring.position = Vector3(0.0, 0.11, 0.0)
	model.add_child(ring)

	# Shaft
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.017
	cyl.bottom_radius = 0.017
	cyl.height = 0.24
	cyl.radial_segments = 10
	shaft.mesh = cyl
	shaft.set_surface_override_material(0, gold)
	shaft.position = Vector3(0.0, -0.06, 0.0)
	model.add_child(shaft)

	# Teeth
	for i in 3:
		var tooth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.052, 0.022, 0.020)
		tooth.mesh = bm
		tooth.set_surface_override_material(0, dark)
		tooth.position = Vector3(0.030, -0.10 - float(i) * 0.048, 0.0)
		model.add_child(tooth)


func _mat(color: Color, emission: Color, energy: float, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission != Color(0, 0, 0):
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m
