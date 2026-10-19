@tool
extends Node3D
class_name GhostRig
## =========================================================================
## GhostRig  -  procedurally built, joint-rigged ghost characters
## =========================================================================
## This is the Godot version of the four reference-sheet ghosts. It builds a
## real node hierarchy with joints you can drive:
##
##     root
##      └ hips            (whole body bob / crouch)
##         ├ legL ─ shinL ─ foot        knee bend
##         ├ legR ─ shinR ─ foot
##         └ torso        (waist twist)
##            ├ chest     (lean forward / back)
##            │   ├ armL ─ foreL ─ hand   shoulder + elbow
##            │   ├ armR ─ foreR ─ hand
##            │   └ neck ─ head          (look, nod)
##            └ pelvis mesh
##
## Because it is a @tool script you can SEE the ghost in the editor while you
## place it. Set "body" in the Inspector to swap between the four ghosts.
##
## Poses (the same four on the reference sheets):
##     "idle" | "walk" | "attack" | "summon"
##
## Performance: each ghost is roughly 40-80 MeshInstance3D nodes. That is fine
## for a handful of ghosts; Stage 11 will bake them into fewer draw calls.
## =========================================================================

enum Body { GHOST_KING, GHOST_QUEEN, SOLDIER_MALE, SOLDIER_FEMALE }

@export var body: Body = Body.GHOST_KING:
	set(value):
		body = value
		if is_inside_tree():
			_rebuild()

## 0 = use the natural height for this body type.
@export var height := 0.0:
	set(value):
		height = value
		if is_inside_tree():
			_rebuild()

## How solid the ghost looks. Lower = more see-through.
@export_range(0.15, 1.0, 0.01) var spectral_alpha := 0.92:
	set(value):
		spectral_alpha = value
		_apply_alpha_to_all()

@export_range(0.0, 1.0, 0.01) var glow_strength := 1.0

# --- animation state ------------------------------------------------------
var pose := "idle"
var anim_speed := 1.0
var anim_phase := 0.0

var parts: Dictionary = {}
var k := 1.0
var _t := 0.0
var _glow_lights: Array[OmniLight3D] = []

const BASE_HEIGHT := 1.8
const DEFAULT_HEIGHTS := {
	Body.GHOST_KING: 2.45,
	Body.GHOST_QUEEN: 1.86,
	Body.SOLDIER_MALE: 1.85,
	Body.SOLDIER_FEMALE: 1.72,
}


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta * anim_speed
	_apply_pose(pose)


## Call this from the enemy AI every frame if you want a fixed time value.
func animate(pose_name: String, t: float) -> void:
	pose = pose_name
	_t = t
	_apply_pose(pose_name)


func get_part(name: String) -> Node3D:
	return parts.get(name, self) as Node3D


# =========================================================================
#  BUILD
# =========================================================================
func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	parts.clear()
	_glow_lights.clear()

	var h: float = height if height > 0.01 else float(DEFAULT_HEIGHTS.get(body, BASE_HEIGHT))
	k = h / BASE_HEIGHT

	_build_skeleton()
	match body:
		Body.GHOST_KING:
			_build_ghost_king()
		Body.GHOST_QUEEN:
			_build_ghost_queen()
		Body.SOLDIER_MALE:
			_build_soldier_male()
		Body.SOLDIER_FEMALE:
			_build_soldier_female()
	_apply_pose("idle")


func _build_skeleton() -> void:
	parts["hips"] = _pivot(self, Vector3(0.0, 0.92 * k, 0.0))

	var hips: Node3D = parts["hips"]
	parts["legL"] = _pivot(hips, Vector3(-0.105 * k, 0.0, 0.0))
	parts["legR"] = _pivot(hips, Vector3(0.105 * k, 0.0, 0.0))
	for side in ["legL", "legR"]:
		var leg: Node3D = parts[side]
		var shin_name := "shinL" if side == "legL" else "shinR"
		parts[shin_name] = _pivot(leg, Vector3(0.0, -0.46 * k, 0.0))

	parts["torso"] = _pivot(hips, Vector3.ZERO)
	var torso: Node3D = parts["torso"]
	parts["chest"] = _pivot(torso, Vector3(0.0, 0.26 * k, 0.0))
	var chest: Node3D = parts["chest"]

	parts["armL"] = _pivot(chest, Vector3(-0.205 * k, 0.24 * k, 0.0))
	parts["armR"] = _pivot(chest, Vector3(0.205 * k, 0.24 * k, 0.0))
	for side in ["armL", "armR"]:
		var arm: Node3D = parts[side]
		var fore_name := "foreL" if side == "armL" else "foreR"
		parts[fore_name] = _pivot(arm, Vector3(0.0, -0.30 * k, 0.0))

	parts["neck"] = _pivot(chest, Vector3(0.0, 0.30 * k, 0.0))
	parts["head"] = _pivot(parts["neck"], Vector3(0.0, 0.10 * k, 0.0))


# =========================================================================
#  POSE ANIMATION  (identical maths to the browser Character Studio)
# =========================================================================
func _apply_pose(mode: String) -> void:
	if parts.is_empty():
		return
	var hips: Node3D = parts["hips"]
	var torso: Node3D = parts["torso"]
	var chest: Node3D = parts["chest"]
	var head: Node3D = parts["head"]
	var armL: Node3D = parts["armL"]
	var armR: Node3D = parts["armR"]
	var foreL: Node3D = parts["foreL"]
	var foreR: Node3D = parts["foreR"]
	var legL: Node3D = parts["legL"]
	var legR: Node3D = parts["legR"]
	var shinL: Node3D = parts["shinL"]
	var shinR: Node3D = parts["shinR"]

	var t := _t + anim_phase
	var s := sin(t * 4.4 + anim_phase)
	var s2 := sin(t * 4.4 + anim_phase + PI)
	var bob := absf(cos(t * 4.4 + anim_phase)) * 0.03 * k

	# --- reset every frame so poses never accumulate --------------------
	hips.position.y = 0.92 * k + bob
	hips.rotation = Vector3.ZERO
	torso.rotation = Vector3.ZERO
	chest.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	armL.rotation = Vector3(0.0, 0.0, 0.10)
	armR.rotation = Vector3(0.0, 0.0, -0.10)
	foreL.rotation = Vector3.ZERO
	foreR.rotation = Vector3.ZERO
	legL.rotation = Vector3.ZERO
	legR.rotation = Vector3.ZERO
	shinL.rotation = Vector3.ZERO
	shinR.rotation = Vector3.ZERO

	match mode:
		"idle":
			chest.rotation.x = 0.03 + sin(t * 1.25) * 0.014
			head.rotation.y = sin(t * 0.55) * 0.10
			armL.rotation.x = sin(t * 1.25) * 0.05
			armR.rotation.x = sin(t * 1.25 + 0.7) * 0.05
			foreL.rotation.x = 0.16
			foreR.rotation.x = 0.16

		"walk":
			legL.rotation.x = s * 0.62
			shinL.rotation.x = maxf(0.0, -s) * 0.75
			legR.rotation.x = s2 * 0.62
			shinR.rotation.x = maxf(0.0, -s2) * 0.75
			armL.rotation.x = s2 * 0.50
			armR.rotation.x = s * 0.50
			foreL.rotation.x = 0.25
			foreR.rotation.x = 0.25
			torso.rotation.y = s * 0.09
			chest.rotation.x = 0.06
			head.rotation.y = -s * 0.06

		"attack":
			var swing := (sin(t * 2.6) + 1.0) * 0.5
			chest.rotation.x = -0.30 + swing * 0.55
			torso.rotation.y = -0.25 + swing * 0.45
			armR.rotation.x = -1.5 + swing * 3.0
			armR.rotation.z = -0.4 + swing * 0.55
			foreR.rotation.x = 1.1 - swing * 1.0
			armL.rotation.x = -0.5 + swing * 0.4
			armL.rotation.z = 0.5
			foreL.rotation.x = 0.9
			legL.rotation.x = 0.30 - swing * 0.35
			legR.rotation.x = -0.30 + swing * 0.30
			shinR.rotation.x = 0.35
			head.rotation.x = -0.12 + swing * 0.20

		"summon":
			var lift := (sin(t * 1.6) + 1.0) * 0.5
			chest.rotation.x = -0.22 - lift * 0.16
			head.rotation.x = -0.42
			armL.rotation.z = 1.35 + lift * 0.25
			armR.rotation.z = -1.35 - lift * 0.25
			armL.rotation.x = -0.35
			armR.rotation.x = -0.35
			foreL.rotation.x = -0.30
			foreR.rotation.x = -0.30
			legL.rotation.x = -0.06
			legR.rotation.x = 0.06
			hips.position.y = 0.92 * k + 0.05 * k + lift * 0.05 * k

	# --- ghostly idle shimmer lights ------------------------------------
	var flick := 0.75 + 0.25 * sin(t * 3.1)
	for l in _glow_lights:
		if is_instance_valid(l):
			l.light_energy = l.get_meta("base_energy", 1.0) * flick * glow_strength


# =========================================================================
#  MATERIAL HELPERS
# =========================================================================
func _m(color: Color, rough := 0.9, metal := 0.0,
		emit_col := Color(0, 0, 0), emit_e := 1.0,
		alpha := 1.0, unshaded := false, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.set_meta("base_alpha", alpha)
	m.albedo_color = Color(color.r, color.g, color.b, alpha * spectral_alpha)
	m.roughness = rough
	m.metallic = metal
	if emit_col != Color(0, 0, 0):
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit_e
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha * spectral_alpha < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _ghost_glow(color: Color) -> StandardMaterial3D:
	return _m(color, 0.4, 0.0, color, 2.0, 1.0, true)


func _apply_alpha_to_all() -> void:
	if not is_inside_tree():
		return
	for n in _all_mesh_instances(self):
		var mi := n as MeshInstance3D
		var mat := mi.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			var s := mat as StandardMaterial3D
			var base := float(s.get_meta("base_alpha", 1.0))
			var a := clampf(base * spectral_alpha, 0.0, 1.0)
			s.albedo_color.a = a
			if a < 0.999:
				s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				s.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED


func _all_mesh_instances(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


# =========================================================================
#  GEOMETRY HELPERS
# =========================================================================
func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _place(parent: Node3D, node: MeshInstance3D, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	node.position = pos
	node.rotation = rot
	node.scale = scl
	parent.add_child(node)
	return node


func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	if mat != null:
		m.set_surface_override_material(0, mat)
	return m


func _box(parent: Node3D, size: Vector3, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _place(parent, _mi(bm, mat), pos, rot)


func _cyl(parent: Node3D, rt: float, rb: float, h: float, mat: Material,
		pos := Vector3.ZERO, rot := Vector3.ZERO, seg := 14) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return _place(parent, _mi(cm, mat), pos, rot)


func _cone(parent: Node3D, rb: float, h: float, mat: Material,
		pos := Vector3.ZERO, rot := Vector3.ZERO, seg := 8) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return _place(parent, _mi(cm, mat), pos, rot)


func _sphere(parent: Node3D, r: float, mat: Material,
		pos := Vector3.ZERO, scl := Vector3.ONE, seg := 16) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(4, seg / 2)
	return _place(parent, _mi(sm, mat), pos, Vector3.ZERO, scl)


func _half_sphere(parent: Node3D, r: float, mat: Material,
		pos := Vector3.ZERO, seg := 18) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = 8
	sm.is_hemisphere = true
	return _place(parent, _mi(sm, mat), pos)


func _torus(parent: Node3D, r: float, thick: float, mat: Material,
		pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(0.001, r - thick)
	tm.outer_radius = r + thick
	tm.rings = 20
	tm.ring_segments = 6
	return _place(parent, _mi(tm, mat), pos, rot)


func _capsule(parent: Node3D, radius: float, h: float, mat: Material,
		pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(h, radius * 2.0 + 0.01)
	cm.radial_segments = 12
	cm.rings = 4
	return _place(parent, _mi(cm, mat), pos, rot)


func _limb(parent: Node3D, length: float, radius: float, mat: Material) -> void:
	# A limb hangs DOWN from its pivot, exactly like an arm or a leg.
	_capsule(parent, radius, length, mat, Vector3(0.0, -length * 0.5, 0.0))


func _glow_light(parent: Node3D, color: Color, energy: float, rng: float, pos := Vector3.ZERO) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	l.set_meta("base_energy", energy)
	parent.add_child(l)
	_glow_lights.append(l)


# =========================================================================
#  1.  GHOST KING   (tall undead king, gold crown, crimson robe, sword)
# =========================================================================
func _build_ghost_king() -> void:
	var hips: Node3D = parts["hips"]
	var torso: Node3D = parts["torso"]
	var chest: Node3D = parts["chest"]
	var head: Node3D = parts["head"]

	var robe := _m(Color(0.29, 0.06, 0.08), 0.95, 0.0, Color(0.13, 0.0, 0.01), 0.6, 1.0, false, true)
	var robe_dark := _m(Color(0.08, 0.06, 0.06), 1.0)
	var gold := _m(Color(0.85, 0.68, 0.22), 0.25, 0.9)
	var flesh := _m(Color(0.58, 0.64, 0.65), 1.0)
	var hair := _m(Color(0.80, 0.83, 0.85), 1.0)
	var eye := _ghost_glow(Color(0.75, 0.95, 1.0))
	var gem := _m(Color(0.56, 0.06, 0.09), 0.2, 0.4, Color(0.23, 0.01, 0.02), 1.4)
	var blade := _m(Color(0.87, 0.91, 0.93), 0.18, 0.95, Color(0.11, 0.28, 0.31), 1.0)
	var aura := _m(Color(0.22, 0.78, 0.84), 0.6, 0.0, Color(0.09, 0.5, 0.55), 1.2, 0.13, true, true)

	# --- torso ----------------------------------------------------------
	_cyl(chest, 0.20 * k, 0.175 * k, 0.32 * k, robe_dark, Vector3.ZERO)
	_cyl(chest, 0.085 * k, 0.085 * k, 0.02 * k, gold, Vector3(0.0, 0.10 * k, 0.17 * k), Vector3(PI * 0.5, 0, 0))
	_sphere(chest, 0.045 * k, flesh, Vector3(0.0, 0.10 * k, 0.185 * k), Vector3.ONE, 10)
	_torus(chest, 0.13 * k, 0.008 * k, gold, Vector3(0.0, 0.22 * k, 0.10 * k), Vector3(PI * 0.38, 0, 0))

	# --- floor length robe + gold trim + tattered hem -------------------
	_cyl(hips, 0.20 * k, 0.62 * k, 1.55 * k, robe, Vector3(0.0, -0.60 * k, 0.0), Vector3.ZERO, 20)
	_torus(hips, 0.60 * k, 0.016 * k, gold, Vector3(0.0, -1.34 * k, 0.0), Vector3(PI * 0.5, 0, 0))
	for i in 14:
		var a := (float(i) / 14.0) * TAU
		var r := 0.60 * k
		_box(hips, Vector3(0.09 * k, 0.30 * k, 0.02 * k), robe_dark if i % 3 == 0 else robe,
			Vector3(cos(a) * r, -1.48 * k, sin(a) * r), Vector3(0, -a, 0))
	# cloak on the back
	_cyl(chest, 0.30 * k, 0.70 * k, 1.35 * k, robe, Vector3(0.0, -0.55 * k, -0.08 * k), Vector3.ZERO, 16)

	# --- head -----------------------------------------------------------
	_sphere(head, 0.115 * k, flesh, Vector3.ZERO, Vector3(1.0, 1.18, 1.05), 20)
	_box(head, Vector3(0.19 * k, 0.03 * k, 0.10 * k), flesh, Vector3(0.0, 0.03 * k, 0.07 * k))
	_cone(head, 0.11 * k, 0.26 * k, hair, Vector3(0.0, -0.16 * k, 0.03 * k), Vector3(PI, 0, 0), 10)
	for i in 7:
		var a := -1.3 + (float(i) / 6.0) * 2.6
		_box(head, Vector3(0.045 * k, 0.42 * k, 0.05 * k), hair,
			Vector3(sin(a) * 0.11 * k, -0.16 * k, -cos(a) * 0.10 * k), Vector3(0, 0, sin(a) * 0.25))
	_sphere(head, 0.026 * k, eye, Vector3(-0.045 * k, 0.005 * k, 0.10 * k), Vector3.ONE, 10)
	_sphere(head, 0.026 * k, eye, Vector3(0.045 * k, 0.005 * k, 0.10 * k), Vector3.ONE, 10)
	_glow_light(head, Color(0.56, 0.91, 1.0), 1.6, 2.2 * k, Vector3(0.0, 0.01 * k, 0.14 * k))

	# --- crown ----------------------------------------------------------
	var crown := _pivot(head, Vector3(0.0, 0.10 * k, 0.0))
	_cyl(crown, 0.115 * k, 0.115 * k, 0.055 * k, gold, Vector3.ZERO, Vector3.ZERO, 16)
	for i in 9:
		var a := (float(i) / 9.0) * TAU
		var hh: float = 0.16 if i == 0 else (0.09 if i % 2 == 1 else 0.12)
		_cone(crown, 0.022 * k, hh * k, gold,
			Vector3(cos(a) * 0.108 * k, hh * k * 0.5, sin(a) * 0.108 * k), Vector3.ZERO, 6)
	_sphere(crown, 0.024 * k, gem, Vector3(0.0, 0.005 * k, 0.115 * k), Vector3.ONE, 10)

	# --- robe-covered limbs ----------------------------------------------
	for side in ["armL", "armR"]:
		_limb(parts[side], 0.30 * k, 0.058 * k, robe_dark)
	for side in ["foreL", "foreR"]:
		_limb(parts[side], 0.27 * k, 0.048 * k, robe_dark)
	for side in ["legL", "legR"]:
		_limb(parts[side], 0.46 * k, 0.080 * k, robe_dark)
	for side in ["shinL", "shinR"]:
		_limb(parts[side], 0.44 * k, 0.066 * k, robe_dark)

	# --- clawed hands ---------------------------------------------------
	for side in ["foreL", "foreR"]:
		var fore: Node3D = parts[side]
		_sphere(fore, 0.05 * k, flesh, Vector3(0.0, -0.29 * k, 0.0), Vector3(1.0, 0.75, 1.2), 8)
		for i in 4:
			_cone(fore, 0.012 * k, 0.075 * k, flesh,
				Vector3(-0.03 * k + i * 0.02 * k, -0.34 * k, 0.01 * k), Vector3(PI, 0, 0), 5)

	# --- broadsword in the right hand -----------------------------------
	var sword := _pivot(parts["foreR"], Vector3(0.0, -0.28 * k, 0.0))
	sword.rotation = Vector3(-0.15, 0.0, 0.15)
	_box(sword, Vector3(0.055 * k, 0.95 * k, 0.012 * k), blade, Vector3(0.0, 0.50 * k, 0.0))
	_box(sword, Vector3(0.014 * k, 0.95 * k, 0.014 * k), eye, Vector3(0.0, 0.50 * k, 0.0))
	_box(sword, Vector3(0.20 * k, 0.03 * k, 0.035 * k), gold, Vector3(0.0, 0.03 * k, 0.0))
	_cyl(sword, 0.017 * k, 0.017 * k, 0.16 * k, robe_dark, Vector3(0.0, -0.06 * k, 0.0), Vector3.ZERO, 8)
	_sphere(sword, 0.026 * k, gold, Vector3(0.0, -0.145 * k, 0.0), Vector3.ONE, 8)
	parts["sword"] = sword

	# --- spectral aura ---------------------------------------------------
	_cone(hips, 0.62 * k, 1.0 * k, aura, Vector3(0.0, -0.42 * k, 0.0), Vector3.ZERO, 22)
	_glow_light(hips, Color(0.18, 0.73, 0.80), 2.2, 4.5 * k, Vector3(0.0, -0.1, 0.0))
	_glow_light(chest, Color(0.18, 0.62, 0.75), 0.9, 3.0 * k, Vector3(0.0, 0.4, -0.5))


# =========================================================================
#  2.  GHOST QUEEN   (red saree, gold border, long black hair)
# =========================================================================
func _build_ghost_queen() -> void:
	var hips: Node3D = parts["hips"]
	var torso: Node3D = parts["torso"]
	var chest: Node3D = parts["chest"]
	var head: Node3D = parts["head"]

	var saree := _m(Color(0.61, 0.06, 0.09), 0.92, 0.0, Color(0.13, 0.0, 0.01), 0.7, 1.0, false, true)
	var gold := _m(Color(0.77, 0.63, 0.23), 0.28, 0.9)
	var skin := _m(Color(0.85, 0.76, 0.74), 0.95)
	var hair := _m(Color(0.04, 0.04, 0.05), 0.75)
	var eye := _ghost_glow(Color(1.0, 0.96, 0.88))
	var tear := _m(Color(0.24, 0.0, 0.02), 0.5)
	var aura := _m(Color(1.0, 0.17, 0.23), 0.6, 0.0, Color(0.5, 0.03, 0.05), 1.0, 0.12, true, true)

	# --- torso / blouse --------------------------------------------------
	_cyl(chest, 0.145 * k, 0.125 * k, 0.30 * k, saree)
	# pallu draped over the left shoulder
	var pallu := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.34 * k, 1.05 * k)
	pallu.mesh = pm
	pallu.set_surface_override_material(0, saree)
	_place(chest, pallu, Vector3(-0.12 * k, -0.28 * k, -0.10 * k), Vector3(0.12, 0.35, 0.18))
	var border := MeshInstance3D.new()
	var bm := PlaneMesh.new()
	bm.size = Vector2(0.045 * k, 1.05 * k)
	border.mesh = bm
	border.set_surface_override_material(0, gold)
	_place(chest, border, Vector3(-0.28 * k, -0.28 * k, -0.06 * k), Vector3(0.12, 0.35, 0.18))

	# --- saree skirt -----------------------------------------------------
	_cyl(hips, 0.19 * k, 0.36 * k, 1.05 * k, saree, Vector3(0.0, -0.42 * k, 0.0), Vector3.ZERO, 18)
	_torus(hips, 0.355 * k, 0.014 * k, gold, Vector3(0.0, -0.92 * k, 0.0), Vector3(PI * 0.5, 0, 0))
	for i in 20:
		var a := (float(i) / 20.0) * TAU
		var r := 0.355 * k
		_cone(hips, 0.035 * k, (0.16 + float(i % 3) * 0.09) * k, saree,
			Vector3(cos(a) * r, -1.00 * k, sin(a) * r), Vector3(PI, 0, 0), 4)
	for i in 5:
		var a2 := -0.5 + float(i) * 0.2
		_box(hips, Vector3(0.05 * k, 0.95 * k, 0.02 * k), saree,
			Vector3(sin(a2) * 0.30 * k, -0.45 * k, cos(a2) * 0.30 * k), Vector3(0, -a2, 0))

	# --- bare midriff + waist chain --------------------------------------
	_cyl(torso, 0.115 * k, 0.135 * k, 0.22 * k, skin, Vector3(0.0, -0.13 * k, 0.0))
	_torus(torso, 0.16 * k, 0.012 * k, gold, Vector3(0.0, -0.22 * k, 0.0), Vector3(PI * 0.5, 0, 0))

	# --- arms, claws, bangles --------------------------------------------
	for side in ["armL", "armR"]:
		_limb(parts[side], 0.30 * k, 0.055 * k, skin)
	for side in ["foreL", "foreR"]:
		var fore: Node3D = parts[side]
		_limb(fore, 0.27 * k, 0.046 * k, skin)
		_sphere(fore, 0.042 * k, skin, Vector3(0.0, -0.27 * k, 0.0), Vector3(1.0, 0.8, 1.25), 10)
		for i in 5:
			_cone(fore, 0.010 * k, 0.10 * k, tear,
				Vector3(-0.032 * k + i * 0.016 * k, -0.345 * k, 0.012 * k), Vector3(PI, 0, 0), 5)
		for i in 4:
			_torus(fore, 0.038 * k, 0.007 * k, gold,
				Vector3(0.0, -0.24 * k - i * 0.022 * k, 0.0), Vector3(PI * 0.5, 0, 0))

	# --- head -------------------------------------------------------------
	_sphere(head, 0.105 * k, skin, Vector3.ZERO, Vector3(0.98, 1.22, 1.02), 20)
	_sphere(head, 0.012 * k, tear, Vector3(0.0, 0.055 * k, 0.10 * k), Vector3.ONE, 8)
	_sphere(head, 0.024 * k, eye, Vector3(-0.042 * k, 0.012 * k, 0.092 * k), Vector3.ONE, 12)
	_sphere(head, 0.024 * k, eye, Vector3(0.042 * k, 0.012 * k, 0.092 * k), Vector3.ONE, 12)
	for sx in [-1.0, 1.0]:
		for i in 3:
			_box(head, Vector3(0.016 * k, (0.10 + float(i) * 0.05) * k, 0.012 * k), tear,
				Vector3(sx * 0.045 * k, -0.01 * k - i * 0.035 * k, 0.090 * k - i * 0.004 * k))
		_torus(head, 0.022 * k, 0.006 * k, gold, Vector3(sx * 0.105 * k, -0.02 * k, 0.0), Vector3(0, PI * 0.5, 0))
	_glow_light(head, Color(1.0, 0.86, 0.68), 0.9, 2.0 * k, Vector3(0.0, 0.01 * k, 0.14 * k))

	# --- long messy black hair --------------------------------------------
	_sphere(head, 0.118 * k, hair, Vector3(0.0, 0.012 * k, 0.0), Vector3(1.02, 1.1, 1.06), 18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 22:
		var a := (float(i) / 22.0) * TAU
		var len := 0.55 * k + rng.randf() * 0.75 * k
		var r := 0.108 * k
		_box(head, Vector3(0.032 * k, len, 0.045 * k), hair,
			Vector3(sin(a) * r, -0.06 * k - len * 0.5, -cos(a) * r),
			Vector3(cos(a) * 0.14, 0.0, sin(a) * 0.22))
	for sx2 in [-1.0, 1.0]:
		_box(head, Vector3(0.03 * k, 0.42 * k, 0.03 * k), hair,
			Vector3(sx2 * 0.092 * k, -0.20 * k, 0.055 * k), Vector3(0, 0, sx2 * 0.10))

	# --- bare feet --------------------------------------------------------
	for side in ["shinL", "shinR"]:
		var shin: Node3D = parts[side]
		_limb(shin, 0.44 * k, 0.062 * k, skin)
		_box(shin, Vector3(0.075 * k, 0.035 * k, 0.19 * k), skin, Vector3(0.0, -0.45 * k, 0.055 * k))

	# --- thighs too ------------------------------------------------------
	for side2 in ["legL", "legR"]:
		_limb(parts[side2], 0.46 * k, 0.076 * k, skin)

	# --- red aura ---------------------------------------------------------
	_cone(hips, 0.42 * k, 0.9 * k, aura, Vector3(0.0, -0.40 * k, 0.0), Vector3.ZERO, 20)
	_glow_light(hips, Color(0.85, 0.07, 0.12), 1.4, 3.6 * k, Vector3(0.0, -0.1, 0.0))


# =========================================================================
#  3.  MALE SOLDIER GHOST  (helmet, bandages, webbing, rifle)
# =========================================================================
func _build_soldier_male() -> void:
	_build_soldier_common(true)


# =========================================================================
#  4.  FEMALE SOLDIER GHOST  (fully bandaged, long black hair)
# =========================================================================
func _build_soldier_female() -> void:
	_build_soldier_common(false)


func _build_soldier_common(male: bool) -> void:
	var hips: Node3D = parts["hips"]
	var torso: Node3D = parts["torso"]
	var chest: Node3D = parts["chest"]
	var head: Node3D = parts["head"]

	var bandage := _m(Color(0.75, 0.69, 0.60), 1.0)
	var bandage_blood := _m(Color(0.43, 0.32, 0.28), 1.0)
	var uniform := _m(Color(0.36, 0.35, 0.24), 1.0)
	var uniform_dark := _m(Color(0.26, 0.26, 0.18), 1.0)
	var gear := _m(Color(0.42, 0.40, 0.27), 1.0)
	var helmet := _m(Color(0.30, 0.32, 0.20), 0.85)
	var boot := _m(Color(0.17, 0.14, 0.11), 1.0)
	var gun_metal := _m(Color(0.23, 0.20, 0.16), 0.45, 0.75)
	var gun_wood := _m(Color(0.33, 0.20, 0.11), 0.9)
	var e_glow := _ghost_glow(Color(0.85, 0.72, 1.0))
	var hair := _m(Color(0.04, 0.04, 0.06), 0.85)

	if male:
		_torso_male(chest, torso, uniform, uniform_dark, bandage, bandage_blood, gear)
		_limbs_male(bandage, bandage_blood, uniform, boot)
		_head_male(head, bandage, bandage_blood, helmet, uniform_dark, e_glow)
		_rifle(parts["foreR"], gun_metal, gun_wood)
	else:
		_torso_female(torso, chest, bandage, bandage_blood)
		_limbs_female(bandage, bandage_blood)
		_head_female(head, bandage, bandage_blood, e_glow, hair)

	# --- cold haunt aura -------------------------------------------------
	var aura_col := Color(0.55, 0.45, 0.78) if male else Color(0.37, 0.50, 0.66)
	var aura := _m(aura_col, 0.6, 0.0, aura_col, 1.0, 0.10, true, true)
	_cone(hips, 0.40 * k, 0.85 * k, aura, Vector3(0.0, -0.38 * k, 0.0), Vector3.ZERO, 18)
	_glow_light(hips, aura_col, 0.5, 2.6 * k, Vector3(0.0, -0.1, 0.0))


func _wrap_bandages(pivot: Node3D, radius: float, count: int,
		bandage: Material, bandage_blood: Material,
		from := -0.05, step := 0.062, blood_every := 3) -> void:
	for i in count:
		_torus(pivot, radius, 0.011 * k, bandage_blood if i % blood_every == blood_every - 1 else bandage,
			Vector3(0.0, from * k - float(i) * step * k, 0.0),
			Vector3(PI * 0.5 + 0.10 * (1.0 if i % 2 == 1 else -1.0), 0.0, 0.0))


func _torso_male(chest: Node3D, torso: Node3D, uniform: Material, uniform_dark: Material,
		bandage: Material, bandage_blood: Material, gear: Material) -> void:
	_cyl(chest, 0.185 * k, 0.175 * k, 0.32 * k, uniform)
	for i in 9:
		var a := -1.4 + (float(i) / 8.0) * 2.8
		_box(chest, Vector3(0.07 * k, (0.12 + float(i % 3) * 0.07) * k, 0.02 * k), uniform_dark,
			Vector3(sin(a) * 0.19 * k, -0.16 * k, cos(a) * 0.18 * k), Vector3(0, -a, 0))
	for i in 4:
		_torus(chest, 0.175 * k, 0.014 * k, bandage,
			Vector3(0.0, -0.10 * k + float(i) * 0.075 * k, 0.0),
			Vector3(PI * 0.5, 0, 0.14 * (1.0 if i % 2 == 1 else -1.0)))
	var patch := _sphere(chest, 0.05 * k, bandage_blood, Vector3(-0.06 * k, 0.05 * k, 0.17 * k), Vector3(1.4, 1.0, 0.35), 8)
	patch.name = "BloodPatch"
	_cyl(torso, 0.20 * k, 0.20 * k, 0.05 * k, gear, Vector3(0.0, -0.16 * k, 0.0), Vector3.ZERO, 16)
	for sx in [-1.0, 1.0]:
		_box(torso, Vector3(0.075 * k, 0.085 * k, 0.045 * k), gear, Vector3(sx * 0.11 * k, -0.19 * k, 0.16 * k))
		_box(chest, Vector3(0.05 * k, 0.30 * k, 0.015 * k), gear,
			Vector3(sx * 0.10 * k, 0.06 * k, 0.175 * k), Vector3(0, 0, sx * 0.12))
	_box(chest, Vector3(0.24 * k, 0.28 * k, 0.14 * k), uniform_dark, Vector3(0.0, 0.02 * k, -0.20 * k))


func _limbs_male(bandage: Material, bandage_blood: Material, uniform: Material, boot: Material) -> void:
	for side in ["armL", "armR"]:
		_limb(parts[side], 0.30 * k, 0.058 * k, uniform)
	for side in ["foreL", "foreR"]:
		_limb(parts[side], 0.27 * k, 0.048 * k, bandage)
	for side in ["legL", "legR"]:
		_limb(parts[side], 0.46 * k, 0.082 * k, bandage)
	for side in ["shinL", "shinR"]:
		_limb(parts[side], 0.44 * k, 0.066 * k, bandage)
	_wrap_bandages(parts["armL"], 0.062 * k, 4, bandage, bandage_blood)
	_wrap_bandages(parts["armR"], 0.062 * k, 4, bandage, bandage_blood)
	_wrap_bandages(parts["foreL"], 0.052 * k, 4, bandage, bandage_blood)
	_wrap_bandages(parts["foreR"], 0.052 * k, 4, bandage, bandage_blood)
	_wrap_bandages(parts["legL"], 0.088 * k, 5, bandage, bandage_blood)
	_wrap_bandages(parts["legR"], 0.088 * k, 5, bandage, bandage_blood)
	_wrap_bandages(parts["shinL"], 0.072 * k, 4, bandage, bandage_blood)
	_wrap_bandages(parts["shinR"], 0.072 * k, 4, bandage, bandage_blood)
	for side in ["shinL", "shinR"]:
		_box(parts[side], Vector3(0.10 * k, 0.10 * k, 0.21 * k), boot, Vector3(0.0, -0.44 * k, 0.035 * k))


func _head_male(head: Node3D, bandage: Material, bandage_blood: Material,
		helmet: Material, uniform_dark: Material, e_glow: Material) -> void:
	_sphere(head, 0.105 * k, bandage, Vector3.ZERO, Vector3(1.0, 1.18, 1.0), 18)
	for i in 6:
		_torus(head, 0.105 * k, 0.013 * k, bandage_blood if i == 3 else bandage,
			Vector3(0.0, 0.07 * k - float(i) * 0.032 * k, 0.0),
			Vector3(PI * 0.5, 0, 0.20 * (1.0 if i % 2 == 1 else -1.0)))
	_sphere(head, 0.019 * k, e_glow, Vector3(-0.038 * k, 0.028 * k, 0.098 * k), Vector3.ONE, 10)
	_glow_light(head, Color(0.73, 0.55, 1.0), 0.5, 1.4 * k, Vector3(-0.04 * k, 0.03 * k, 0.12 * k))
	_half_sphere(head, 0.125 * k, helmet, Vector3(0.0, 0.045 * k, 0.0))
	_cyl(head, 0.128 * k, 0.132 * k, 0.018 * k, helmet, Vector3(0.0, 0.012 * k, 0.0), Vector3.ZERO, 18)
	for i in 7:
		var a := (float(i) / 7.0) * TAU
		_torus(head, 0.125 * k, 0.004 * k, uniform_dark, Vector3(0.0, 0.06 * k, 0.0), Vector3(0, a, 0))
	_torus(head, 0.105 * k, 0.008 * k, uniform_dark, Vector3(0.0, -0.01 * k, 0.0), Vector3(0, PI * 0.5, 0))


func _rifle(fore: Node3D, metal: Material, wood: Material) -> void:
	var rifle := _pivot(fore, Vector3(0.0, -0.27 * k, 0.03 * k))
	rifle.rotation = Vector3(0.10, 0.0, 0.08)
	_box(rifle, Vector3(0.028 * k, 0.028 * k, 1.02 * k), wood, Vector3(0.0, 0.0, 0.05 * k))
	_cyl(rifle, 0.010 * k, 0.011 * k, 0.52 * k, metal, Vector3(0.0, 0.0, 0.80 * k), Vector3(PI * 0.5, 0, 0), 10)
	_box(rifle, Vector3(0.026 * k, 0.05 * k, 0.20 * k), metal, Vector3(0.0, -0.02 * k, 0.30 * k))
	_cyl(rifle, 0.010 * k, 0.010 * k, 0.07 * k, metal, Vector3(0.03 * k, 0.01 * k, 0.18 * k), Vector3(0, 0, PI * 0.5), 8)
	parts["rifle"] = rifle


func _torso_female(torso: Node3D, chest: Node3D, bandage: Material, bandage_blood: Material) -> void:
	_cyl(chest, 0.150 * k, 0.140 * k, 0.31 * k, bandage)
	_wrap_bandages(chest, 0.150 * k, 5, bandage, bandage_blood, 0.14, 0.062, 4)
	var patches := [
		Vector3(-0.08, 0.10, 0.14), Vector3(0.05, -0.02, 0.15),
		Vector3(0.02, 0.16, -0.14), Vector3(-0.10, -0.08, 0.12)]
	var scales := [1.6, 1.2, 1.4, 1.0]
	for i in patches.size():
		_sphere(chest, 0.035 * k, bandage_blood, patches[i] * k, Vector3(scales[i], scales[i] * 0.7, 0.35), 8)
	_box(chest, Vector3(0.05 * k, 0.36 * k, 0.012 * k), bandage,
		Vector3(0.13 * k, -0.20 * k, 0.08 * k), Vector3(0, 0, 0.25))
	_cyl(torso, 0.145 * k, 0.155 * k, 0.20 * k, bandage)
	_cyl(parts["hips"], 0.155 * k, 0.26 * k, 0.62 * k, bandage, Vector3(0.0, -0.36 * k, 0.0), Vector3.ZERO, 16)
	for i in 16:
		var a := (float(i) / 16.0) * TAU
		var r := 0.26 * k
		_cone(parts["hips"], 0.03 * k, (0.10 + float(i % 3) * 0.07) * k, bandage_blood,
			Vector3(cos(a) * r, -0.70 * k, sin(a) * r), Vector3(PI, 0, 0), 4)


func _limbs_female(bandage: Material, bandage_blood: Material) -> void:
	for side in ["armL", "armR"]:
		_limb(parts[side], 0.30 * k, 0.052 * k, bandage)
	for side in ["foreL", "foreR"]:
		_limb(parts[side], 0.27 * k, 0.044 * k, bandage)
	for side in ["legL", "legR"]:
		_limb(parts[side], 0.46 * k, 0.078 * k, bandage)
	for side in ["shinL", "shinR"]:
		_limb(parts[side], 0.44 * k, 0.062 * k, bandage)
	_wrap_bandages(parts["armL"], 0.058 * k, 4, bandage, bandage_blood, -0.05, 0.062, 4)
	_wrap_bandages(parts["armR"], 0.058 * k, 4, bandage, bandage_blood, -0.05, 0.062, 4)
	_wrap_bandages(parts["foreL"], 0.048 * k, 4, bandage, bandage_blood, -0.05, 0.062, 4)
	_wrap_bandages(parts["foreR"], 0.048 * k, 4, bandage, bandage_blood, -0.05, 0.062, 4)
	_wrap_bandages(parts["legL"], 0.082 * k, 5, bandage, bandage_blood, -0.05, 0.062, 4)
	_wrap_bandages(parts["legR"], 0.082 * k, 5, bandage, bandage_blood, -0.05, 0.062, 4)
	_wrap_bandages(parts["shinL"], 0.066 * k, 4, bandage, bandage_blood, -0.02, 0.06, 4)
	_wrap_bandages(parts["shinR"], 0.066 * k, 4, bandage, bandage_blood, -0.02, 0.06, 4)
	var blood := bandage_blood
	for side in ["foreL", "foreR"]:
		var fore: Node3D = parts[side]
		_sphere(fore, 0.040 * k, bandage, Vector3(0.0, -0.26 * k, 0.0), Vector3(1.0, 0.8, 1.2), 10)
		for i in 5:
			_cone(fore, 0.009 * k, 0.085 * k, blood,
				Vector3(-0.028 * k + i * 0.014 * k, -0.325 * k, 0.010 * k), Vector3(PI, 0, 0), 5)
	for side in ["shinL", "shinR"]:
		var shin: Node3D = parts[side]
		_box(shin, Vector3(0.075 * k, 0.05 * k, 0.175 * k), bandage, Vector3(0.0, -0.45 * k, 0.045 * k))
		for i in 3:
			_sphere(shin, 0.014 * k, bandage, Vector3(-0.022 * k + i * 0.022 * k, -0.47 * k, 0.135 * k), Vector3.ONE, 6)


func _head_female(head: Node3D, bandage: Material, bandage_blood: Material,
		e_glow: Material, hair: Material) -> void:
	_sphere(head, 0.100 * k, bandage, Vector3.ZERO, Vector3(1.0, 1.20, 1.0), 18)
	for i in 8:
		_torus(head, 0.100 * k, 0.012 * k, bandage_blood if i == 4 else bandage,
			Vector3(0.0, 0.08 * k - float(i) * 0.028 * k, 0.0),
			Vector3(PI * 0.5, 0, 0.17 * (1.0 if i % 2 == 1 else -1.0)))
	_sphere(head, 0.020 * k, e_glow, Vector3(-0.036 * k, 0.022 * k, 0.094 * k), Vector3.ONE, 12)
	_glow_light(head, Color(0.81, 0.85, 0.88), 0.45, 1.2 * k, Vector3(-0.04 * k, 0.02 * k, 0.12 * k))
	_sphere(head, 0.108 * k, hair, Vector3(0.0, 0.02 * k, 0.0), Vector3(1.02, 1.08, 1.05), 18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 26:
		var a := (float(i) / 26.0) * TAU
		var len := 0.62 * k + rng.randf() * 0.62 * k
		var r := 0.104 * k
		_box(head, Vector3(0.028 * k, len, 0.038 * k), hair,
			Vector3(sin(a) * r, -0.05 * k - len * 0.5, -cos(a) * r),
			Vector3(0, 0, sin(a) * 0.16))
