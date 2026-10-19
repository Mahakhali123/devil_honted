extends Node3D
class_name WeaponView
## =========================================================================
## WeaponView  -  the thing you see in your hands
## =========================================================================
## Lives under the player's camera. It builds a simple but readable mesh for
## whichever weapon is equipped and animates the swing.
##
##   * WeaponView.build_weapon_mesh(id)  is a STATIC helper - props use it too
##   * set_weapon(id)                    swaps the mesh
##   * play_swing(duration)              starts the swing animation
##   * motion                            the player sets this 0..1 so the
##                                       weapon sways while you walk
##
## All four weapon shapes are made of boxes / cylinders, so there are still
## zero binary model files in the project. Stage 9 swaps these for real GLB
## models with one line change.
## =========================================================================

## Swing keyframes: t = 0..1 through the swing.
const SWING_KEYS := [
	{"t": 0.00, "rot": Vector3(-8.0, 14.0, -8.0), "pos": Vector3(0.30, -0.28, -0.44)},
	{"t": 0.24, "rot": Vector3(22.0, 6.0, 28.0), "pos": Vector3(0.33, -0.22, -0.38)},
	{"t": 0.46, "rot": Vector3(-38.0, -5.0, -32.0), "pos": Vector3(0.12, -0.33, -0.62)},
	{"t": 0.72, "rot": Vector3(-12.0, 9.0, -6.0), "pos": Vector3(0.27, -0.29, -0.47)},
	{"t": 1.00, "rot": Vector3(-8.0, 14.0, -8.0), "pos": Vector3(0.30, -0.28, -0.44)},
]

var weapon_id := "fists"
## 0 = standing still, 1 = sprinting. Drives the sway.
var motion := 0.0

var _pivot: Node3D
var _model: Node3D
var _t := 0.0
var _swing_t := -1.0
var _swing_dur := 0.45


func _ready() -> void:
	# The viewmodel renders on top of the world but must never eat a physics
	# collision, so nothing here gets a collider.
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_rebuild()
	_apply_curve(0.0)


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_t += delta

	if _swing_t >= 0.0:
		_swing_t += delta
		var p := clampf(_swing_t / maxf(_swing_dur, 0.01), 0.0, 1.0)
		_apply_curve(p)
		if p >= 1.0:
			_swing_t = -1.0
	else:
		_apply_curve(0.0)

	# Sway / breathing that gets stronger the faster you move.
	var m := clampf(motion, 0.0, 1.5)
	var sx := sin(_t * 3.4) * 0.010 * (0.35 + m)
	var sy := sin(_t * 7.1) * 0.013 * m
	_pivot.position.x += sx
	_pivot.position.y += sy
	_pivot.rotation.z += sx * 1.4
	_pivot.rotation.x += sy * 0.9


func set_weapon(id: String) -> void:
	weapon_id = id
	_rebuild()


func play_swing(duration := 0.45) -> void:
	_swing_dur = maxf(duration, 0.12)
	_swing_t = 0.0


func _rebuild() -> void:
	if _pivot == null:
		return
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = build_weapon_mesh(weapon_id)
	if _model == null:
		return
	_model.name = "Model"
	_pivot.add_child(_model)


func _apply_curve(p: float) -> void:
	var prev: Dictionary = SWING_KEYS[0]
	var next: Dictionary = SWING_KEYS[SWING_KEYS.size() - 1]
	for i in SWING_KEYS.size() - 1:
		var a: Dictionary = SWING_KEYS[i]
		var b: Dictionary = SWING_KEYS[i + 1]
		if p >= float(a["t"]) and p <= float(b["t"]):
			prev = a
			next = b
			break
	var span := maxf(float(next["t"]) - float(prev["t"]), 0.0001)
	var k := clampf((p - float(prev["t"])) / span, 0.0, 1.0)
	var rot_a: Vector3 = prev["rot"]
	var rot_b: Vector3 = next["rot"]
	var pos_a: Vector3 = prev["pos"]
	var pos_b: Vector3 = next["pos"]
	_pivot.rotation = Vector3(
		deg_to_rad(lerpf(rot_a.x, rot_b.x, k)),
		deg_to_rad(lerpf(rot_a.y, rot_b.y, k)),
		deg_to_rad(lerpf(rot_a.z, rot_b.z, k)))
	_pivot.position = pos_a.lerp(pos_b, k)


# =========================================================================
#  STATIC MESH FACTORY  (used by the viewmodel AND by weapon pickups)
# =========================================================================
static func build_weapon_mesh(id: String) -> Node3D:
	var data := WeaponDB.get_weapon(id)
	var shape := String(data.get("shape", "fists"))
	var color: Color = data.get("color", Color(0.7, 0.7, 0.7))

	var root := Node3D.new()

	match shape:
		"bat":
			_mk(root, _cyl(0.022, 0.18, _mat(color.darkened(0.35), Color(0, 0, 0), 0.0, 0.85), Vector3(0.0, 0.0, 0.06)))
			_mk(root, _cyl(0.034, 0.46, _mat(color, Color(0, 0, 0), 0.0, 0.8), Vector3(0.0, 0.0, -0.26), 0.052))
			_mk(root, _cyl(0.052, 0.05, _mat(color.darkened(0.15), Color(0, 0, 0), 0.0, 0.75), Vector3(0.0, 0.0, -0.48)))
			for i in 3:
				_mk(root, _torus(0.024, 0.005, _mat(Color(0.25, 0.25, 0.25), Color(0, 0, 0), 0.0, 0.4, 0.7),
					Vector3(0.0, 0.0, 0.10 - float(i) * 0.035)))
		"pan":
			_mk(root, _cyl(0.145, 0.028, _mat(color, Color(0.05, 0.05, 0.05), 0.15, 0.35, 0.85),
				Vector3(0.0, 0.0, -0.40)))
			_mk(root, _cyl(0.115, 0.030, _mat(Color(0.14, 0.12, 0.12), Color(0, 0, 0), 0.0, 0.6), Vector3(0.0, 0.012, -0.40)))
			_mk(root, _box(Vector3(0.032, 0.026, 0.30), _mat(color.darkened(0.2), Color(0, 0, 0), 0.0, 0.5, 0.6), Vector3(0.0, 0.0, -0.14)))
			_mk(root, _sphere(0.019, _mat(Color(0.6, 0.55, 0.5), Color(0, 0, 0), 0.0, 0.4, 0.8), Vector3(0.0, 0.0, 0.02)))
		"katana":
			_mk(root, _box(Vector3(0.012, 0.034, 0.84), _mat(color, Color(0.16, 0.26, 0.32), 0.35, 0.14, 0.95), Vector3(0.0, 0.012, -0.50)))
			_mk(root, _box(Vector3(0.006, 0.009, 0.84), _mat(color, Color(0.55, 0.85, 1.0), 1.6, 0.1), Vector3(0.0, -0.014, -0.50)))
			_mk(root, _box(Vector3(0.105, 0.011, 0.034), _mat(Color(0.22, 0.20, 0.16), Color(0, 0, 0), 0.0, 0.35, 0.8), Vector3(0.0, 0.0, -0.07)))
			_mk(root, _cyl(0.017, 0.22, _mat(Color(0.09, 0.08, 0.09), Color(0, 0, 0), 0.0, 0.9), Vector3(0.0, 0.0, 0.05)))
			for i in 5:
				_mk(root, _torus(0.019, 0.0035, _mat(Color(0.10, 0.10, 0.12), Color(0, 0, 0), 0.0, 0.95),
					Vector3(0.0, 0.0, 0.14 - float(i) * 0.045)))
		"lantern":
			_mk(root, _cyl(0.075, 0.018, _mat(Color(0.18, 0.16, 0.13), Color(0, 0, 0), 0.0, 0.5, 0.6), Vector3(0.0, 0.0, -0.10)))
			_mk(root, _cyl(0.075, 0.018, _mat(Color(0.18, 0.16, 0.13), Color(0, 0, 0), 0.0, 0.5, 0.6), Vector3(0.0, 0.0, -0.34)))
			for i in 4:
				var a := (float(i) / 4.0) * TAU + PI * 0.25
				_mk(root, _box(Vector3(0.010, 0.010, 0.24), _mat(Color(0.20, 0.18, 0.15), Color(0, 0, 0), 0.0, 0.5, 0.6),
					Vector3(cos(a) * 0.068, sin(a) * 0.068, -0.22)))
			var flame := _sphere(0.048, _mat(Color(0.55, 0.82, 1.0), Color(0.35, 0.72, 1.0), 2.6, 0.3), Vector3(0.0, 0.0, -0.22))
			flame.name = "Flame"
			_mk(root, flame)
			_mk(root, _torus(0.062, 0.006, _mat(Color(0.24, 0.22, 0.18), Color(0, 0, 0), 0.0, 0.4, 0.7), Vector3(0.0, 0.0, -0.10)))
			var lamp := OmniLight3D.new()
			lamp.name = "LampLight"
			lamp.light_color = Color(0.52, 0.80, 1.0)
			lamp.light_energy = 1.4
			lamp.omni_range = 7.0
			lamp.position = Vector3(0.0, 0.0, -0.22)
			root.add_child(lamp)
		"trap":
			_mk(root, _box(Vector3(0.11, 0.11, 0.11), _mat(Color(0.11, 0.12, 0.13), Color(0.05, 0.10, 0.10), 0.4, 0.4, 0.7), Vector3(0.0, 0.0, -0.22)))
			for i in 4:
				var a2 := (float(i) / 4.0) * TAU
				_mk(root, _box(Vector3(0.012, 0.012, 0.115), _mat(color, color, 2.2, 0.2),
					Vector3(cos(a2) * 0.050, sin(a2) * 0.050, -0.22)))
			var core := _sphere(0.038, _mat(color, color, 2.4, 0.2), Vector3(0.0, 0.0, -0.22))
			core.name = "Core"
			_mk(root, core)
			_mk(root, _box(Vector3(0.026, 0.026, 0.16), _mat(Color(0.15, 0.15, 0.16), Color(0, 0, 0), 0.0, 0.5, 0.6), Vector3(0.0, 0.0, -0.02)))
		_:
			# fists
			_mk(root, _box(Vector3(0.075, 0.085, 0.13), _mat(color, Color(0, 0, 0), 0.0, 0.9), Vector3(-0.075, 0.01, -0.09)))
			_mk(root, _box(Vector3(0.075, 0.085, 0.13), _mat(color, Color(0, 0, 0), 0.0, 0.9), Vector3(0.055, -0.02, -0.12)))
			_mk(root, _box(Vector3(0.062, 0.075, 0.16), _mat(color.darkened(0.2), Color(0, 0, 0), 0.0, 0.9), Vector3(0.045, -0.02, 0.03)))

	return root


static func _mk(root: Node3D, node: MeshInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)


static func _mat(color: Color, emission := Color(0, 0, 0), energy := 1.0, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission != Color(0, 0, 0):
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


static func _box(size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	mi.rotation = rot
	return mi


## rot is applied for you: the cylinder's long axis is rotated onto -Z,
## because every weapon in this game points away from the camera.
static func _cyl(radius: float, length: float, mat: Material, pos: Vector3, top_radius := -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 12
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	return mi


static func _sphere(radius: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	return mi


static func _torus(radius: float, thick: float, mat: Material, pos: Vector3, extra_x_rot := 0.0) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(0.0005, radius - thick)
	tm.outer_radius = radius + thick
	tm.rings = 12
	tm.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	mi.rotation = Vector3(PI * 0.5 + extra_x_rot, 0.0, 0.0)
	return mi
