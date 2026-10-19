extends Node3D
class_name HauntedLevel
## =========================================================================
## HauntedLevel  -  shared behaviour for every stage
## =========================================================================
## Every level script does `extends HauntedLevel` instead of `extends Node3D`
## and gets all of this for free:
##
##   * the player is snapped to the Marker3D named "PlayerSpawn"
##   * the HUD minimap is built automatically from every LevelBlock in the
##     scene - you never draw a map by hand
##   * every EnemyGhost in the scene is registered, and a TODO entry is added
##     to the right-hand panel: "Banish the Girl Soldier - EASIEST"
##   * the tasks tick themselves off as the ghosts die
##   * `on_all_ghosts_banished()` is called when the last one is gone
##
## Subclasses override:
##   level_title          the name shown above the minimap
##   next_level_id        where to go after this stage ("" = nowhere yet)
##   _level_started()     put your intro text / objectives here
##   on_all_ghosts_banished()   unlock the exit, open a door, whatever
## =========================================================================

## Shows above the minimap in the HUD.
@export var level_title := "Unknown Place"
## Optional: the level id to load when this stage is done.
@export var next_level_id := ""
## Optional: prints a one-line difficulty ladder when the level starts.
@export var announce_hunt := true

## --- what tests/level_check.gd holds this level to -----------------------
## A level declares its own expectations so the validator stays generic.
## Stage 1 is a three-ghost tutorial; Stage 2 is the six-ghost hunt map.
@export var expect_min_ghosts := 3
@export var expect_min_weapons := 2
## True only if this level hides its katana behind a locked door.
@export var expect_locked_katana := false

const WALL_MIN_HEIGHT := 2.2
const MAP_MARGIN := 2.0
const BLOCK_SCENE := preload("res://props/block.tscn")
const GHOST_SCENE := preload("res://enemies/enemy_ghost.tscn")
const WEAPON_SCENE := preload("res://props/weapon_pickup.tscn")
const KEY_SCENE := preload("res://props/key_item.tscn")
const KIT_SCENE := preload("res://props/health_kit.tscn")
const NOTE_SCENE := preload("res://props/note.tscn")
const DOOR_SCENE := preload("res://props/door.tscn")

var _spawn: Marker3D
var _player: PlayerController
var _hunt_complete := false
var _built_root: Node3D


func _ready() -> void:
	_spawn = get_node_or_null("PlayerSpawn") as Marker3D
	_player = get_node_or_null("Player") as PlayerController
	if _spawn != null and _player != null:
		_player.global_transform = _spawn.global_transform

	_build_level()
	_harvest_map()
	_register_ghosts()

	GameManager.ghost_banished.connect(_on_ghost_banished)

	_level_started()
	if announce_hunt:
		_announce_hunt()


## Override in your level to build geometry / spawn things from code.
## Runs BEFORE the minimap is harvested, so anything you add shows up on it.
func _build_level() -> void:
	pass


## Override in your level.
func _level_started() -> void:
	pass


## Override in your level: the last ghost is gone.
func on_all_ghosts_banished() -> void:
	pass


# =========================================================================
#  MAP  -  harvested from LevelBlock nodes
# =========================================================================
func _harvest_map() -> void:
	var blocks: Array = []
	var bounds := Rect2()
	var first := true

	for n in get_tree().get_nodes_in_group("level_block"):
		var b := n as LevelBlock
		if b == null:
			continue
		var s: Vector3 = b.size
		# Ignore small decoration blocks - they just make the map muddy.
		if s.x < 1.0 and s.z < 1.0:
			continue
		var c := b.global_position
		var rect := Rect2(c.x - s.x * 0.5, c.z - s.z * 0.5, s.x, s.z)
		blocks.append({"rect": rect, "height": s.y})
		if first:
			bounds = rect
			first = false
		else:
			bounds = bounds.merge(rect)

	if first:
		return
	bounds = bounds.grow(MAP_MARGIN)
	GameManager.set_map(blocks, bounds)


# =========================================================================
#  GHOSTS  -  registered as tasks for the right-hand panel
# =========================================================================
func _register_ghosts() -> void:
	var ghosts: Array[EnemyGhost] = []
	for n in get_tree().get_nodes_in_group("ghost"):
		var g := n as EnemyGhost
		if g != null:
			ghosts.append(g)

	# Easiest first, so the task list reads as a difficulty ladder.
	ghosts.sort_custom(func(a: EnemyGhost, b: EnemyGhost) -> bool:
		return GhostDB.order_index(a.rig_body) < GhostDB.order_index(b.rig_body))

	GameManager.register_ghost_targets(ghosts.size())

	var tasks: Array = []
	for g in ghosts:
		if g.quest_id == "":
			continue
		tasks.append({
			"id": g.quest_id,
			"text": "Banish the %s  -  %s" % [g.display_name, GhostDB.difficulty_tag(g.rig_body)],
			"done": false,
		})
	if not tasks.is_empty():
		GameManager.set_objectives(tasks)


func _announce_hunt() -> void:
	var total := get_tree().get_nodes_in_group("ghost").size()
	if total <= 0:
		return
	GameManager.show_message(
		"%d spirits are awake in this place.\nThey are hunting you too - kill them before they kill you." % total,
		6.0)


func _on_ghost_banished(_ghost_name: String, remaining: int, _quest_id: String) -> void:
	if remaining <= 0 and not _hunt_complete:
		_hunt_complete = true
		on_all_ghosts_banished()
		_advance_to_next_stage()


## When the last spirit falls and this level names a `next_level_id`, give the
## player a few seconds to read the victory message and then load that stage.
##
## Without this, clearing Stage 1 was a DEAD END: the menu only ever started
## stage1_village, so the Queen and the King - who live in Stage 2 - could
## never be reached at all.
func _advance_to_next_stage() -> void:
	if next_level_id == "":
		return
	if not GameManager.LEVELS.has(next_level_id):
		push_warning("Level '%s' names next_level_id '%s', which is not in GameManager.LEVELS." % [name, next_level_id])
		return
	# process_always = false, so this does not tick while the game is paused.
	await get_tree().create_timer(7.0, false).timeout
	if not is_inside_tree():
		return  # the player bailed out to the menu while we were waiting
	if GameManager.is_paused or GameManager.player_is_dead:
		return
	GameManager.start_level(next_level_id)


# =========================================================================
#  HELPERS FOR SUBCLASSES
# =========================================================================
## Finds a node by name anywhere under the level. Handy for level scripts.
func find_node_named(node_name: String) -> Node:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == node_name:
			return n
		for c in n.get_children():
			stack.append(c)
	return null


## Opens (or simply deletes) every HauntedDoor whose required_key matches.
func unlock_doors_with_key(key_id: String) -> void:
	for d in find_children("*", "HauntedDoor", true, false):
		var door := d as HauntedDoor
		if door != null and door.locked and door.required_key == key_id:
			door.unlock(key_id)


func player() -> PlayerController:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	return _player


# =========================================================================
#  BUILDERS  -  so a level is a readable list of instructions, not 200 nodes
# =========================================================================
func build_root() -> Node3D:
	if _built_root == null or not is_instance_valid(_built_root):
		_built_root = get_node_or_null("Built") as Node3D
		if _built_root == null:
			_built_root = Node3D.new()
			_built_root.name = "Built"
			add_child(_built_root)
	return _built_root


## A solid grey box. `centre` is the middle of the box in world space.
func add_block(centre: Vector3, size: Vector3, mat: StandardMaterial3D = null, hint := "Block") -> LevelBlock:
	var b := BLOCK_SCENE.instantiate() as LevelBlock
	b.name = hint
	build_root().add_child(b)
	b.global_position = centre
	b.size = size
	if mat != null:
		b.material = mat
	return b


## A flat slab of walkable floor, centred on (x, z), `area` metres across.
func add_floor(x: float, z: float, area: Vector2, mat: StandardMaterial3D = null, y := -0.25, thickness := 0.5) -> LevelBlock:
	return add_block(Vector3(x, y, z), Vector3(area.x, thickness, area.y), mat, "Floor")


## A wall built from a 2D line: from (x1, z1) to (x2, z2). Much easier to
## read in a level script than a rotated box transform.
func add_wall(from: Vector2, to: Vector2, height := 4.0, thickness := 0.4, mat: StandardMaterial3D = null) -> LevelBlock:
	var d := to - from
	var length := d.length()
	if length < 0.05:
		return null
	var mid := (from + to) * 0.5
	var b := add_block(Vector3(mid.x, height * 0.5, mid.y), Vector3(length, height, thickness), mat, "Wall")
	# Point the box's local +X along the wall direction.
	b.rotation.y = atan2(-d.y, d.x)
	return b


## A doorway gap helper: leaves a gap of `gap` metres in the middle of a wall.
func add_wall_with_gap(from: Vector2, to: Vector2, gap := 2.2, height := 4.0, thickness := 0.4, mat: StandardMaterial3D = null) -> void:
	var d := to - from
	var length := d.length()
	if length <= gap + 0.2:
		return
	var dir := d / length
	var half := gap * 0.5
	var a_end := from + dir * (length * 0.5 - half)
	var b_start := from + dir * (length * 0.5 + half)
	add_wall(from, a_end, height, thickness, mat)
	add_wall(b_start, to, height, thickness, mat)


## IMPORTANT RULE FOR ALL THE SPAWNERS BELOW:
## Every prop reads its @export values inside _ready() (to build its mesh, pick
## its stats, tint its glow...). So we always fill the exports in FIRST and add
## the node to the tree SECOND. Do it the other way round and the prop is built
## from its defaults. The one exception is `global_position`, which needs the
## node to be inside the tree, so positions are set last (the build root itself
## sits at the origin, so `position` and `global_position` agree anyway).
func add_door(pos: Vector3, rot_y_deg: float, key_id := "", label := "") -> HauntedDoor:
	var d := DOOR_SCENE.instantiate() as HauntedDoor
	d.name = "Door"
	d.position = pos
	d.rotation.y = deg_to_rad(rot_y_deg)
	if key_id != "":
		d.locked = true
		d.required_key = key_id
		d.locked_message = "Locked. It needs the %s." % label
	build_root().add_child(d)
	return d


func spawn_ghost(body_type: int, pos: Vector3, quest_id := "", roam := 9.0, dormant := false, face_y := 0.0) -> EnemyGhost:
	var g := GHOST_SCENE.instantiate() as EnemyGhost
	g.name = quest_id if quest_id != "" else GhostDB.ghost_name(body_type)
	g.rig_body = body_type
	g.quest_id = quest_id
	g.roam_radius = roam
	g.start_dormant = dormant
	g.position = pos
	g.rotation.y = deg_to_rad(face_y)
	build_root().add_child(g)
	return g


func spawn_weapon(weapon_id: String, pos: Vector3) -> WeaponPickup:
	var w := WEAPON_SCENE.instantiate() as WeaponPickup
	w.name = "Weapon_" + weapon_id
	w.weapon_id = weapon_id
	w.position = pos
	build_root().add_child(w)
	return w


func spawn_key(key_id: String, label: String, pos: Vector3) -> KeyItem:
	var k := KEY_SCENE.instantiate() as KeyItem
	k.name = "Key_" + key_id
	k.key_id = key_id
	k.key_label = label
	k.position = pos
	build_root().add_child(k)
	return k


func spawn_health_kit(pos: Vector3, amount := 35.0) -> HealthKit:
	var h := KIT_SCENE.instantiate() as HealthKit
	h.name = "HealthKit"
	h.heal_amount = amount
	h.position = pos
	build_root().add_child(h)
	return h


func spawn_note(pos: Vector3, text: String, clue_id := "", objective := "") -> ClueNote:
	var n := NOTE_SCENE.instantiate() as ClueNote
	n.name = "Note"
	n.text = text
	if clue_id != "":
		n.clue_id = clue_id
	if objective != "":
		n.objective_after = objective
	n.position = pos
	build_root().add_child(n)
	return n


## A ceiling light that breathes and occasionally blacks out.
## The script must be attached BEFORE add_child, otherwise its _ready() never
## runs and the flicker would sit at its default energy forever.
func spawn_light(pos: Vector3, colour := Color(1.0, 0.86, 0.62), energy := 1.3, reach := 6.5, flickering := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "Light"
	if flickering:
		l.set_script(load("res://props/flicker_light.gd"))
		l.set("base_energy", energy)
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	l.position = pos
	build_root().add_child(l)
	return l


## A dim pool of light with no flicker - good for marking an exit or a clue.
func spawn_glow(pos: Vector3, colour: Color, energy := 0.9, reach := 5.0) -> OmniLight3D:
	return spawn_light(pos, colour, energy, reach, false)
