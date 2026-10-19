extends Node3D
## =========================================================================
## LevelCheck  -  headless map validator (works on ANY HauntedLevel)
## =========================================================================
##     Godot_v4.7.2-stable_win64_console.exe --headless ^
##       --path "<project>" res://tests/level_check.tscn ^
##       --  res://levels/stage2_barracks.tscn
##
## A level can look completely fine and still be unplayable: a wall built from
## a line segment can accidentally seal a room shut, and nothing in the log
## will ever complain. This test walks the real geometry instead.
##
## THE MODEL
##   The level is made of LevelBlock boxes. For every 0.4 m grid cell we
##   collect the vertical slices of every box that overlaps it (inflated by the
##   player's radius), then work out the heights at which a 1.8 m tall player
##   could actually STAND in that cell:
##
##      * there must be something to stand on  (a box top exactly at that
##        height - the ground slab counts)
##      * the space from that height up to head height must be empty, so you
##        are not standing inside a wall
##
##   Then we flood fill sideways, allowing a step of up to 1.9 m - which is
##   exactly how high the player's 6.2 m/s jump carries them. That single
##   number is why a 2.4 m ledge is correctly reported as unreachable and a
##   1.6 m one is not.
##
##   It also means a ROOF is not a wall. The chapel in Stage 1 is sealed by a
##   ceiling 4.35 m up; the naive "is this box tall" test called that a wall and
##   claimed three items were unreachable. This model walks under it happily.
##
## WHAT IT PROVES
##   1. the PlayerSpawn itself is standable
##   2. every ghost, weapon, key and health kit can be walked (or jumped) to
##   3. nothing is sealed behind a locked door except what should be: if the
##      level expects a locked katana, the katana must be inside and the key
##      must be outside
##   4. no ghost is ever sealed away, and no key is behind the door it opens
##
## Exit code 0 = all good, 1 = something failed.
## =========================================================================

@export var level_path := "res://levels/stage2_barracks.tscn"

const CELL := 0.4
const PLAYER_R := 0.32     # player collision radius
const PLAYER_H := 1.8      # standing height
const MAX_STEP := 1.9      # how high the 6.2 m/s jump carries the player
const REACH_RADIUS := 3    # cells a target may sit off the walkable area

var _lines: Array[String] = []
var _failures := 0

var _lo := Vector2.ZERO
var _cols := 0
var _rows := 0
var _spans: Dictionary = {}      # cell index -> Array[Vector2(y_min, y_max)]
var _heights: Dictionary = {}    # cell index -> PackedFloat32Array of stand heights

var _level: HauntedLevel
var _start_h := 0.0
var _dump := false


func _ready() -> void:
	var user := OS.get_cmdline_user_args()
	if user.size() > 0 and String(user[0]).begins_with("res://"):
		level_path = String(user[0])
	for a in user:
		if String(a) == "--dump":
			_dump = true
	_check.call_deferred()


func _check() -> void:
	print("\n================== LEVEL CHECK ====================")
	print("level: %s" % level_path)

	var packed := load(level_path) as PackedScene
	if packed == null:
		_fail("could not load %s" % level_path)
		_finish()
		return

	_level = packed.instantiate() as HauntedLevel
	if _level == null:
		_fail("root of %s is not a HauntedLevel" % level_path)
		_finish()
		return
	add_child(_level)

	for i in 8:
		await get_tree().physics_frame

	_report_contents()

	var blocks := _collect_blocks()
	var doors := _collect_door_rects()
	_say("geometry: %d boxes, %d locked doorway(s), step limit %.1f m" % [blocks.size(), doors.size(), MAX_STEP])

	# ---- 1. doors open: everything must be reachable ----------------------
	_build_grid(blocks, [])
	var spawn := _level.get_node_or_null("PlayerSpawn") as Node3D
	if spawn == null:
		_fail("no PlayerSpawn node in %s" % level_path)
		_finish()
		return
	var seen := _flood(spawn)
	if _start_h < -900.0:
		var sc := _cell(spawn.global_position)
		var si := sc.y * _cols + sc.x
		_fail("PlayerSpawn %s is inside solid geometry - the player spawns stuck" % _v(spawn.global_position))
		_say("  cell (%d, %d) vertical slices:" % [sc.x, sc.y])
		if _spans.has(si):
			for s in _spans[si]:
				_say("    y %.2f .. %.2f" % [(s as Vector2).x, (s as Vector2).y])
		else:
			_say("    (nothing - no floor under the spawn at all)")
		_finish()
		return
	_say("player spawns standing at y = %.2f" % _start_h)
	_say("flood fill, doors open: %d walkable cells" % _count(seen))

	var unreachable: Array[String] = []
	for t in _targets():
		if not _reaches(seen, t.position):
			unreachable.append(t.label)
	if unreachable.is_empty():
		_pass("every ghost, weapon, key and kit is reachable on foot")
	else:
		for u in unreachable:
			_fail("UNREACHABLE: %s" % u)
		if _dump:
			for t in _targets():
				if _reaches(seen, t.position):
					continue
				_say("")
				_say("map around %s   (# solid, . standable but not reached, + reached, T target)" % t.label)
				_print_map(seen, t.position, 22)

	if _dump:
		_say("")
		_say("dump: every box the validator collected (world AABB)")
		var boxes := _collect_blocks()
		boxes.sort_custom(func(a: AABB, b: AABB) -> bool: return a.position.y < b.position.y)
		for box in boxes:
			_say("  x %7.2f..%7.2f   y %7.2f..%7.2f   z %7.2f..%7.2f" % [
				box.position.x, box.position.x + box.size.x,
				box.position.y, box.position.y + box.size.y,
				box.position.z, box.position.z + box.size.z])
		for n in get_tree().get_nodes_in_group("level_block"):
			var b := n as LevelBlock
			var mi := b.get_node_or_null("Mesh") as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var box := _world_aabb(mi)
			_say("  %-30s y %7.2f..%7.2f" % [String(_level.get_path_to(b)), box.position.y, box.position.y + box.size.y])
		_say("")
		_say("dump: every target and the heights you can stand at in its cell")
		for t in _targets():
			var c := _cell(t.position)
			var idx := c.y * _cols + c.x
			var hs: PackedFloat32Array = _heights.get(idx, PackedFloat32Array())
			_say("  %-42s cell(%3d,%3d) stand=%s reached=%s" % [
				t.label, c.x, c.y, str(hs), str(_reaches(seen, t.position))])
			# Which cells in the search window did the flood fill actually
			# touch? Printed as (dx,dz) -> heights, so a false PASS is easy
			# to trace back to the cell that caused it.
			for dz in range(-REACH_RADIUS, REACH_RADIUS + 1):
				for dx in range(-REACH_RADIUS, REACH_RADIUS + 1):
					var n := Vector2i(c.x + dx, c.y + dz)
					if n.x < 0 or n.y < 0 or n.x >= _cols or n.y >= _rows:
						continue
					var ni := n.y * _cols + n.x
					var touched: Array[String] = []
					var nh: PackedFloat32Array = _heights.get(ni, PackedFloat32Array())
					for lv in nh.size():
						if seen.has(ni * 100 + lv):
							touched.append("%.2f" % nh[lv])
					if not touched.is_empty():
						_say("        reached (%+d,%+d) stand in [%s]" % [dx, dz, ", ".join(touched)])

	# ---- 2. doors shut: the locked room must really be locked -------------
	if doors.is_empty():
		_say("no locked doors in this level - skipping the gating test")
		_finish()
		return

	_build_grid(blocks, doors)
	var sealed := _flood(spawn)
	_say("flood fill, doors shut: %d walkable cells (-%d)" % [_count(sealed), _count(seen) - _count(sealed)])

	var sealed_off: Array[String] = []
	var ghost_locked := false
	var key_locked := false
	var katana_locked := false
	for t in _targets():
		if _reaches(sealed, t.position):
			continue
		sealed_off.append(t.label)
		if t.kind == "ghost":
			ghost_locked = true
		if t.kind == "key":
			key_locked = true
		if t.kind == "katana":
			katana_locked = true

	_say("behind the door(s): %s" % ("nothing" if sealed_off.is_empty() else _join(sealed_off)))

	if not ghost_locked:
		_pass("no ghost is walled off - the hunt is always completable")
	else:
		_fail("a ghost is sealed where it cannot be hunted: %s" % _join(sealed_off))

	if not key_locked:
		_pass("no key is sealed behind the door it opens")
	else:
		_fail("SOFTLOCK - a key is behind the door it opens: %s" % _join(sealed_off))

	if _level.expect_locked_katana:
		if katana_locked:
			_pass("the katana is only reachable through the locked door - the key is required")
		else:
			_fail("the katana is reachable WITHOUT opening the locked door - the key is pointless")
	else:
		if katana_locked:
			_fail("the katana is sealed away but this level does not expect a locked katana")
		else:
			_say("this level does not gate a katana - gating check skipped")

	_finish()


# =========================================================================
#  CONTENTS
# =========================================================================
func _report_contents() -> void:
	var ghosts := get_tree().get_nodes_in_group("ghost")
	var by_body: Dictionary = {}
	for g in ghosts:
		var e := g as EnemyGhost
		if e == null:
			continue
		by_body[e.rig_body] = int(by_body.get(e.rig_body, 0)) + 1

	_say("")
	_say("contents:")
	_say("  %d roaming ghost(s)" % ghosts.size())
	for body in GhostDB.ORDER:
		if by_body.has(body):
			_say("    %-16s x%d   %s" % [GhostDB.ghost_name(body), int(by_body[body]), GhostDB.difficulty_tag(body)])

	if ghosts.size() < _level.expect_min_ghosts:
		_fail("only %d ghost(s) - this level expects at least %d" % [ghosts.size(), _level.expect_min_ghosts])
	else:
		_pass("%d ghost(s) roaming (expected at least %d)" % [ghosts.size(), _level.expect_min_ghosts])

	if not by_body.has(GhostRig.Body.SOLDIER_FEMALE):
		_fail("no girl soldier - the easiest ghost is missing, so the ladder has no first rung")

	var weapons := 0
	var keys := 0
	var kits := 0
	var notes := 0
	for n in _level.find_children("*", "", true, false):
		if n is WeaponPickup:
			weapons += 1
		elif n is KeyItem:
			keys += 1
		elif n is HealthKit:
			kits += 1
		elif n is ClueNote:
			notes += 1
	_say("  %d weapon(s), %d key(s), %d health kit(s), %d note(s), %d locked door(s)" % [
		weapons, keys, kits, notes, _count_locked_doors()])

	if weapons < _level.expect_min_weapons:
		_fail("only %d weapon(s) on the floor - this level expects at least %d" % [weapons, _level.expect_min_weapons])
	if kits < 1:
		_fail("no health kit anywhere - the player has no way to heal")


# =========================================================================
#  TARGETS
# =========================================================================
func _targets() -> Array:
	var out: Array = []
	for g in get_tree().get_nodes_in_group("ghost"):
		var e := g as EnemyGhost
		if e != null:
			out.append({"label": "ghost %s %s" % [e.display_name, _v(e.global_position)],
				"position": e.global_position, "kind": "ghost"})
	for n in _level.find_children("*", "", true, false):
		if n is WeaponPickup:
			var w := n as WeaponPickup
			out.append({"label": "weapon %s %s" % [w.weapon_id, _v(w.global_position)],
				"position": w.global_position, "kind": ("katana" if w.weapon_id == "katana" else "weapon")})
		elif n is KeyItem:
			var k := n as KeyItem
			out.append({"label": "key %s %s" % [k.key_id, _v(k.global_position)],
				"position": k.global_position, "kind": "key"})
		elif n is HealthKit:
			out.append({"label": "health kit %s" % _v(n.global_position),
				"position": n.global_position, "kind": "kit"})
	return out


# =========================================================================
#  GEOMETRY
# =========================================================================
## Every box in the level, as world-space AABBs.
## Axis-aligned boxes (which is nearly all of them) give one AABB. A ROTATED
## box - a ramp, say - is sliced into thin slabs along its longest axis first,
## so a slope becomes a staircase of short spans instead of one tall block.
## Without this a 22-degree ramp reads as a 2.5 m wall and the platform on top
## of it looks unreachable, which is wrong.
const ROTATED_SLICES := 8

func _collect_blocks() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("level_block"):
		var b := n as LevelBlock
		if b == null:
			continue
		var mi := b.get_node_or_null("Mesh") as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local := mi.get_aabb()
		var xf := mi.global_transform
		if _is_axis_aligned(xf):
			out.append(_world_aabb(mi))
		else:
			for slab in _slice(local, ROTATED_SLICES):
				out.append(_transform_aabb(slab, xf))
	return out


func _is_axis_aligned(xf: Transform3D) -> bool:
	for v in [xf.basis.x, xf.basis.y, xf.basis.z]:
		var av := Vector3(absf(v.x), absf(v.y), absf(v.z))
		var ok := false
		for unit in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]:
			if (av - unit).length() < 0.02:
				ok = true
		if not ok:
			return false
	return true


func _slice(local: AABB, n: int) -> Array:
	var size := local.size
	var axis := 0
	if size.y > size[axis]:
		axis = 1
	if size.z > size[axis]:
		axis = 2
	var step := size[axis] / float(n)
	var out: Array = []
	for i in n:
		var p := local.position
		var s := local.size
		match axis:
			0:
				p.x = local.position.x + step * float(i)
				s.x = step
			1:
				p.y = local.position.y + step * float(i)
				s.y = step
			2:
				p.z = local.position.z + step * float(i)
				s.z = step
		out.append(AABB(p, s))
	return out


func _transform_aabb(local: AABB, xf: Transform3D) -> AABB:
	var mn := Vector3(1e20, 1e20, 1e20)
	var mx := Vector3(-1e20, -1e20, -1e20)
	for i in 8:
		var w := xf * local.get_endpoint(i)
		mn = mn.min(w)
		mx = mx.max(w)
	return AABB(mn, mx - mn)


## Only LOCKED doors act as barriers for the gating test. A normal door can be
## opened by the player at any time, so "sealed behind a door" means nothing
## for it - Stage 1's chapel door was correctly shutting the boy soldier in,
## but the player can simply open it again.
func _collect_door_rects() -> Array:
	var out: Array = []
	for n in _level.find_children("*", "HauntedDoor", true, false):
		var d := n as HauntedDoor
		if d == null or not d.locked:
			continue
		var p := d.global_position
		# Generous square: a doorway is a couple of metres wide and the room
		# outside it is much bigger, so this reliably plugs the gap.
		out.append(Rect2(p.x - 1.6, p.z - 1.6, 3.2, 3.2))
	return out


func _count_locked_doors() -> int:
	return _collect_door_rects().size()


func _world_aabb(mi: MeshInstance3D) -> AABB:
	var local := mi.get_aabb()
	var xf := mi.global_transform
	var mn := Vector3(1e20, 1e20, 1e20)
	var mx := Vector3(-1e20, -1e20, -1e20)
	for i in 8:
		var w := xf * local.get_endpoint(i)
		mn = mn.min(w)
		mx = mx.max(w)
	return AABB(mn, mx - mn)


# =========================================================================
#  THE GRID
# =========================================================================
func _build_grid(blocks: Array, extra_rects: Array) -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var any := false
	for box in blocks:
		lo = lo.min(Vector2(box.position.x, box.position.z))
		hi = hi.max(Vector2(box.position.x + box.size.x, box.position.z + box.size.z))
		any = true
	for r in extra_rects:
		lo = lo.min(r.position)
		hi = hi.max(r.position + r.size)
		any = true
	if not any:
		lo = Vector2(-50, -50)
		hi = Vector2(50, 50)

	# Pad by the player's radius plus a margin so nothing sits on the edge.
	var pad := Vector2(6, 6)
	_lo = lo - pad
	hi = hi + pad
	_cols = int(ceil((hi.x - _lo.x) / CELL)) + 1
	_rows = int(ceil((hi.y - _lo.y) / CELL)) + 1

	_spans = {}
	for box in blocks:
		_add_span(_rect_of(box), box.position.y, box.position.y + box.size.y)
	# A doorway we are pretending is shut is a slice of wall from the floor up
	# past head height, so it blocks everything.
	for r in extra_rects:
		_add_span(r, -2.0, 6.0)

	_heights = {}
	for key in _spans.keys():
		var h := _valid_heights(_spans[key])
		if not h.is_empty():
			_heights[key] = h


func _rect_of(box: AABB) -> Rect2:
	return Rect2(box.position.x - PLAYER_R, box.position.z - PLAYER_R,
		box.size.x + PLAYER_R * 2.0, box.size.z + PLAYER_R * 2.0)


## Mark every cell whose CENTRE lies inside the rect (inflated by the player's
## radius). Testing cell centres, rather than "does the rect touch this cell",
## is what stops a doorway being closed by rounding: a 1.8 m doorway walls off
## to 1.16 m of clear space, which still contains three cell centres.
func _add_span(r: Rect2, y0: float, y1: float) -> void:
	var c0 := maxi(0, int(floor((r.position.x - _lo.x) / CELL)) - 1)
	var c1 := mini(_cols - 1, int(ceil((r.position.x + r.size.x - _lo.x) / CELL)) + 1)
	var r0 := maxi(0, int(floor((r.position.y - _lo.y) / CELL)) - 1)
	var r1 := mini(_rows - 1, int(ceil((r.position.y + r.size.y - _lo.y) / CELL)) + 1)
	var span := Vector2(y0, y1)
	var z_max := r.position.y + r.size.y
	for rr in range(r0, r1 + 1):
		var cz := _lo.y + (float(rr) + 0.5) * CELL
		if cz < r.position.y or cz > z_max:
			continue
		var row := rr * _cols
		for cc in range(c0, c1 + 1):
			var cx := _lo.x + (float(cc) + 0.5) * CELL
			if cx < r.position.x or cx > r.position.x + r.size.x:
				continue
			var idx := row + cc
			if not _spans.has(idx):
				_spans[idx] = []
			var list: Array = _spans[idx]
			list.append(span)


## Which heights a 1.8 m player can stand at, inside a cell whose vertical
## slices are `spans` (each a Vector2 of y_min .. y_max).
func _valid_heights(spans: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var candidates: Array[float] = [0.0]
	for s in spans:
		candidates.append((s as Vector2).y)

	for c in candidates:
		# Must have something under our feet.
		var supported := false
		for s in spans:
			if absf((s as Vector2).y - c) <= 0.06:
				supported = true
				break
		if not supported:
			continue
		# Must not be standing inside anything.
		var clear := true
		for s in spans:
			var v := s as Vector2
			if v.y > c + 0.06 and v.x < c + PLAYER_H:
				clear = false
				break
		if not clear:
			continue
		var dup := false
		for e in out:
			if absf(e - c) <= 0.06:
				dup = true
				break
		if not dup:
			out.append(c)
	return out


func _cell(world: Vector3) -> Vector2i:
	return Vector2i(
		clampi(int(floor((world.x - _lo.x) / CELL)), 0, _cols - 1),
		clampi(int(floor((world.z - _lo.y) / CELL)), 0, _rows - 1))


# =========================================================================
#  FLOOD FILL  -  walks sideways, and up or down by up to MAX_STEP
# =========================================================================
func _flood(from: Node3D) -> Dictionary:
	_start_h = -999.0
	var seen: Dictionary = {}
	var start := _cell(from.global_position)
	var si := start.y * _cols + start.x
	if not _heights.has(si):
		return seen

	# Start at the valid height nearest the spawn marker's own height.
	var hs: PackedFloat32Array = _heights[si]
	var best_i := 0
	for i in hs.size():
		if absf(hs[i] - from.global_position.y) < absf(hs[best_i] - from.global_position.y):
			best_i = i
	_start_h = hs[best_i]

	var queue: Array[Vector3i] = [Vector3i(start.x, start.y, best_i)]
	seen[si] = true
	var steps := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head := 0
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		var cur_h: float = (_heights[cur.y * _cols + cur.x] as PackedFloat32Array)[cur.z]
		for d in steps:
			var nc: Vector2i = Vector2i(cur.x, cur.y) + d
			if nc.x < 0 or nc.y < 0 or nc.x >= _cols or nc.y >= _rows:
				continue
			var ni := nc.y * _cols + nc.x
			if not _heights.has(ni):
				continue
			var nh: PackedFloat32Array = _heights[ni]
			for lv in nh.size():
				if absf(nh[lv] - cur_h) > MAX_STEP:
					continue
				var key := ni * 100 + lv
				if seen.has(key):
					continue
				seen[key] = true
				queue.append(Vector3i(nc.x, nc.y, lv))
			# Mark the cell as touched even if no level matched, so the
			# "reached" test below can look at whole cells.
			if not seen.has(ni):
				pass
	return seen


func _count(seen: Dictionary) -> int:
	var cells: Dictionary = {}
	for key in seen.keys():
		cells[int(key) / 100] = true
	return cells.size()


func _reached_cell(seen: Dictionary, idx: int) -> bool:
	# Levels are stored as idx * 100 + level, so walk the level slots.
	for lv in 40:
		if seen.has(idx * 100 + lv):
			return true
	return false


## True if any walkable cell within REACH_RADIUS of the point was reached.
## The radius matters: a pickup sitting on a table is not ON a walkable cell,
## but the player standing beside the table can still grab it.
func _reaches(seen: Dictionary, world: Vector3) -> bool:
	var c := _cell(world)
	for dy in range(-REACH_RADIUS, REACH_RADIUS + 1):
		for dx in range(-REACH_RADIUS, REACH_RADIUS + 1):
			var n := Vector2i(c.x + dx, c.y + dy)
			if n.x < 0 or n.y < 0 or n.x >= _cols or n.y >= _rows:
				continue
			if _reached_cell(seen, n.y * _cols + n.x):
				return true
	return false


# =========================================================================
#  REPORTING
# =========================================================================
func _v(p: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z]


func _join(items: Array) -> String:
	var parts: Array[String] = []
	for i in items:
		if i is String:
			parts.append(i)
		elif i is Dictionary:
			parts.append(String(i.get("label", "?")))
		else:
			parts.append(String(i))
	return ", ".join(parts)


func _say(text: String) -> void:
	_lines.append(text)


## A small ASCII slice of the grid, centred on a world position. The fastest
## way to see WHY a room is unreachable. Legend:
##     #  nothing to stand on at all (solid wall or no floor)
##     .  reached by the flood fill
##     0-9 the lowest height you can stand at there, if NOT reached
##        (so a wall cell under a roof shows as 4, floor cells as 0)
func _print_map(seen: Dictionary, world: Vector3, radius := 8) -> void:
	var c := _cell(world)
	for dz in range(-radius, radius + 1):
		var line := ""
		for dx in range(-radius, radius + 1):
			var n := Vector2i(c.x + dx, c.y + dz)
			if n.x < 0 or n.y < 0 or n.x >= _cols or n.y >= _rows:
				line += " "
				continue
			if dx == 0 and dz == 0:
				line += "T"
				continue
			var idx := n.y * _cols + n.x
			var hs: PackedFloat32Array = _heights.get(idx, PackedFloat32Array())
			if hs.is_empty():
				line += "#"
			elif _reached_cell(seen, idx):
				line += "."
			else:
				var lowest := 99.0
				for h in hs:
					lowest = minf(lowest, h)
				line += str(mini(9, int(floor(lowest))))
		_say("    " + line)


func _pass(text: String) -> void:
	_lines.append("  PASS  " + text)


func _fail(text: String) -> void:
	_failures += 1
	_lines.append("  FAIL  " + text)


func _finish() -> void:
	for line in _lines:
		print(line)
	print("")
	print("RESULT: %d failure(s)" % _failures)
	print("================ END LEVEL CHECK ==================\n")
	get_tree().quit(1 if _failures > 0 else 0)
