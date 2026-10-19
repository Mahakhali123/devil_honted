extends Control
class_name Minimap
## =========================================================================
## Minimap  -  a top-down map of the level with everything that matters on it
## =========================================================================
## Attached to the "Minimap" Control inside ui/hud.tscn.
##
## It draws:
##   * the level layout, harvested automatically from every LevelBlock
##     (floors are light, walls are dark)
##   * the player, as a green arrow that points where you are looking
##   * EVERY LIVING GHOST, always, even through walls - each one is a big
##     labelled dot so you can always answer "where is it?":
##       G  green = girl soldier     (easiest)
##       B  blue  = boy soldier      (easy)
##       Q  pink  = the Ghost Queen  (hard)
##       K  gold  = the Ghost King   (hardest)
##     The letter in the middle says WHICH ghost it is, the coloured ring
##     around it is how badly you have wounded it, and it pulses bright red
##     the moment it starts hunting you.
##   * pickups you have not collected yet
##
## The level hands it the geometry through GameManager.set_map(), so you never
## have to draw a map by hand - lay out blocks and it appears.
## =========================================================================

const WALL_THRESHOLD := 2.2      ## blocks taller than this draw as walls
const PADDING := 6.0

## Ghost dot sizes, in screen pixels. Big enough to spot instantly on a map
## that might be covering 90 m of level.
const GHOST_HALO := 10.0
const GHOST_DOT := 7.4
const GHOST_RING := 11.0
const GHOST_FONT := 11

var _blink := 0.0
var _player: PlayerController


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.map_changed.connect(_on_map_changed)


func _on_map_changed() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_blink += delta
	# Cheap enough to redraw every frame, and it keeps the dots smooth.
	queue_redraw()


## Colour that tells you how dangerous a ghost is, at a glance.
static func difficulty_color(body_type: int) -> Color:
	match body_type:
		GhostRig.Body.GHOST_KING:
			return Color(1.0, 0.85, 0.24)
		GhostRig.Body.GHOST_QUEEN:
			return Color(0.85, 0.16, 0.50)
		GhostRig.Body.SOLDIER_MALE:
			return Color(0.55, 0.76, 1.0)
		_:
			return Color(0.55, 0.95, 0.62)


## The letter drawn in the middle of a ghost's dot on the map.
static func ghost_tag(body_type: int) -> String:
	match body_type:
		GhostRig.Body.GHOST_KING:
			return "K"
		GhostRig.Body.GHOST_QUEEN:
			return "Q"
		GhostRig.Body.SOLDIER_MALE:
			return "B"
		_:
			return "G"


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Color(0.035, 0.035, 0.05, 0.86), true)

	var bounds := GameManager.map_bounds
	if bounds.size.x <= 0.01 or bounds.size.y <= 0.01:
		draw_rect(box, Color(0.5, 0.46, 0.4, 0.95), false, 1.0)
		return

	var avail := size - Vector2(PADDING, PADDING) * 2.0
	if avail.x <= 1.0 or avail.y <= 1.0:
		return
	var s := minf(avail.x / bounds.size.x, avail.y / bounds.size.y)
	var origin := Vector2(PADDING, PADDING) + (avail - bounds.size * s) * 0.5

	# --- 1. floors first, then walls on top -----------------------------
	for pass_index in 2:
		for entry in GameManager.map_blocks:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var r: Rect2 = entry.get("rect", Rect2())
			var h := float(entry.get("height", 0.5))
			var is_wall := h >= WALL_THRESHOLD
			if (pass_index == 0) == is_wall:
				continue
			var rr := _rect_to_map(r, s, origin, bounds)
			if rr.size.x < 0.6:
				rr.size.x = 0.6
			if rr.size.y < 0.6:
				rr.size.y = 0.6
			draw_rect(rr, Color(0.34, 0.31, 0.27, 0.96) if is_wall else Color(0.66, 0.6, 0.49, 0.58), true)

	# --- 2. pickups ------------------------------------------------------
	for n in get_tree().get_nodes_in_group("pickup"):
		var item := n as Node3D
		if item == null or not item.is_inside_tree():
			continue
		if item is Interactable and not (item as Interactable).visible:
			continue
		var pp := _node_to_map(item, s, origin, bounds)
		draw_circle(pp, 2.0, Color(0.95, 0.83, 0.35, 0.85))

	# --- 3. ghosts -------------------------------------------------------
	# The whole point of the map: you can always see where every ghost is,
	# through walls, and which one it is.
	for n in get_tree().get_nodes_in_group("ghost"):
		var g := n as EnemyGhost
		if g == null or not g.is_alive():
			continue
		var gp := _node_to_map(g, s, origin, bounds)
		var hunting := g.state == EnemyGhost.State.CHASE or g.state == EnemyGhost.State.ATTACK
		var alerted := g.state == EnemyGhost.State.ALERT
		var diff := difficulty_color(g.rig_body)

		# Dark halo first, so the dot never disappears into the floor colour.
		draw_circle(gp, GHOST_HALO, Color(0.0, 0.0, 0.0, 0.6))
		if hunting:
			var pulse := GHOST_HALO + 5.0 * (0.5 + 0.5 * sin(_blink * 7.0))
			draw_circle(gp, pulse, Color(1.0, 0.18, 0.12, 0.28))

		var col := diff
		if hunting:
			col = Color(1.0, 0.25, 0.18)
		elif alerted:
			col = diff.lerp(Color(1.0, 0.78, 0.32), 0.5)

		draw_circle(gp, GHOST_DOT, col)
		draw_arc(gp, GHOST_DOT, 0.0, TAU, 26, Color(0.03, 0.03, 0.04, 0.95), 1.8, true)
		# The letter sits in the middle of the dot: centred by drawing into a
		# box 44 px wide starting 22 px to the left.
		draw_string(ThemeDB.fallback_font, gp + Vector2(-22.0, 4.0), ghost_tag(g.rig_body),
			HORIZONTAL_ALIGNMENT_CENTER, 44.0, GHOST_FONT, Color(0.04, 0.04, 0.05))

		# Damage ring: how close this one is to being banished.
		var hurt := 1.0 - clampf(g.health / maxf(g.max_health, 0.001), 0.0, 1.0)
		if hurt > 0.02:
			draw_arc(gp, GHOST_RING, -PI * 0.5, -PI * 0.5 + TAU * hurt, 26,
				Color(1.0, 0.35, 0.28, 0.95), 2.0, true)

	# --- 4. the player ---------------------------------------------------
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player != null:
		var mp := _node_to_map(_player, s, origin, bounds)
		var fwd := -_player.global_transform.basis.z
		var d := Vector2(fwd.x, fwd.z)
		if d.length_squared() < 0.0001:
			d = Vector2(0.0, 1.0)
		d = d.normalized()
		var side := Vector2(-d.y, d.x)
		var tri := PackedVector2Array([
			mp + d * 7.5,
			mp - d * 4.5 + side * 4.5,
			mp - d * 4.5 - side * 4.5,
		])
		draw_colored_polygon(tri, Color(0.60, 1.0, 0.68))
		draw_circle(mp, 6.0, Color(0.35, 0.95, 0.5, 0.22))

	draw_rect(box, Color(0.62, 0.56, 0.46, 0.95), false, 1.0)


func _rect_to_map(r: Rect2, s: float, origin: Vector2, bounds: Rect2) -> Rect2:
	var a := _point_to_map(r.position.x, r.position.y, s, origin, bounds)
	var b := _point_to_map(r.position.x + r.size.x, r.position.y + r.size.y, s, origin, bounds)
	return Rect2(a, b - a).abs()


func _point_to_map(wx: float, wz: float, s: float, origin: Vector2, bounds: Rect2) -> Vector2:
	# World X -> map X, world Z -> map Y. Godot's +Z is "south", and screen Y
	# grows downward, so the map ends up north-up without extra flipping.
	return origin + Vector2(wx - bounds.position.x, wz - bounds.position.y) * s


func _node_to_map(n: Node3D, s: float, origin: Vector2, bounds: Rect2) -> Vector2:
	return _point_to_map(n.global_position.x, n.global_position.z, s, origin, bounds)
