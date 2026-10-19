extends HauntedLevel
## =========================================================================
## Stage2Barracks  -  THE HAUNTED MILITARY BARRACKS
## =========================================================================
## The first real MAP: a walled compound you explore on foot, with all four
## ghosts roaming it. Difficulty rises the deeper you go.
##
##                      NORTH  (-Z)
##    +------------------+------------------+
##    |   CHAPEL         |   PARADE GROUND  |   GENERATOR
##    |   Ghost QUEEN    |   Ghost KING     |   Boy soldier
##    |   (hard)         |   (hardest)      |   (easy)
##    +--------+---------+--------+---------+
##             |   north corridor |                 z = -16
##    +--------+---------+--------+---------+
##    |  ARMOURY         |  corridor  | CELLAR  |
##    |  (LOCKED,        |            | spirit  |
##    |   katana)        |            | trap    |
##    +--------+---------+--------+---------+
##    |  DORMITORY       |  corridor  | MESS HALL
##    |  armoury KEY     |            | frying pan
##    |  Girl soldier    |            | Boy soldier
##    +--------+---------+--------+---------+
##             |    ENTRY YARD    |                z = +10
##             |   (you spawn)    |
##             +--------+---------+                z = +24
##                      GATE  (opens when the hunt is done)
##
## Everything is built from a list of floors, walls and spawns, so you can
## move a room by editing one line.
## =========================================================================

# --- materials -------------------------------------------------------------
var _concrete: StandardMaterial3D
var _brick: StandardMaterial3D
var _wood: StandardMaterial3D
var _metal: StandardMaterial3D
var _rust: StandardMaterial3D
var _dirt: StandardMaterial3D

# --- room extents (used by both the geometry and the spawns) --------------
const COMPOUND := Rect2(-30.0, -36.0, 60.0, 60.0)   # x, z, w, h  (h = z depth)
const CORRIDOR_HALF := 4.0
const YARD_Z := 10.0
const MID_Z := 0.0
const NORTH_Z := -16.0


func _level_started() -> void:
	expect_min_ghosts = 6
	expect_min_weapons = 4
	expect_locked_katana = true
	GameManager.set_objective("Search the barracks - find something to fight with")
	GameManager.key_collected.connect(_on_key_collected)
	GameManager.weapons_changed.connect(_on_weapons_changed)
	GameManager.show_message(
		"THE HAUNTED BARRACKS\n\nSix spirits walk these halls.\nSearch the rooms. Arm yourself. They will find you first.",
		7.0)


func on_all_ghosts_banished() -> void:
	GameManager.set_objective("The barracks are cleansed. The gate has opened")
	GameManager.show_message(
		"Every spirit in the barracks has been banished.\n\nSTAGE 2 COMPLETE.\nScore: %d\nNext: Stage 3 - baked navigation and smarter hunting." % GameManager.score,
		10.0)


func _on_key_collected(key_id: String, _label: String) -> void:
	if key_id == "armoury_key":
		GameManager.set_objective("Unlock the armoury and take the katana")


func _on_weapons_changed(list: Array, _index: int) -> void:
	if list.has("katana"):
		GameManager.set_objective("Hunt down the remaining spirits")
	elif list.has("wooden_bat") or list.has("frying_pan"):
		GameManager.set_objective("Find the armoury key in the dormitory")


# =========================================================================
#  BUILD
# =========================================================================
func _build_level() -> void:
	_make_materials()
	_make_ground()
	_make_outer_walls()
	_make_entry_yard()
	_make_dormitory()
	_make_mess_hall()
	_make_armoury()
	_make_cellar()
	_make_parade_ground()
	_make_chapel()
	_make_generator_room()
	_make_lights()
	_make_notes()
	_place_ghosts()


func _make_materials() -> void:
	_concrete = _mat(Color(0.30, 0.30, 0.30), 0.95)
	_brick = _mat(Color(0.30, 0.19, 0.16), 1.0)
	_wood = _mat(Color(0.35, 0.25, 0.15), 0.95)
	_metal = _mat(Color(0.26, 0.27, 0.28), 0.45, 0.75)
	_rust = _mat(Color(0.33, 0.20, 0.12), 0.95)
	_dirt = _mat(Color(0.24, 0.22, 0.18), 1.0)


func _mat(color: Color, rough := 0.9, metal := 0.0, emission := Color(0, 0, 0), energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission != Color(0, 0, 0):
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


## One big slab so you can never fall through a crack between rooms.
func _make_ground() -> void:
	add_block(Vector3(0.0, -0.3, -6.0), Vector3(64.0, 0.6, 68.0), _dirt, "GroundSlab")


func _make_outer_walls() -> void:
	add_wall(Vector2(-30, 24), Vector2(-30, -36), 4.5, 0.5, _brick)      # west
	add_wall(Vector2(30, 24), Vector2(30, -36), 4.5, 0.5, _brick)        # east
	add_wall(Vector2(-30, -36), Vector2(30, -36), 4.5, 0.5, _brick)      # north
	add_wall_with_gap(Vector2(-30, 24), Vector2(30, 24), 4.0, 4.5, 0.5, _brick)  # south + gate


func _make_entry_yard() -> void:
	# The yard is bounded on the north by two walls with a corridor between.
	add_wall_with_gap(Vector2(-30, YARD_Z), Vector2(-CORRIDOR_HALF, YARD_Z), 4.0, 4.0, 0.4, _concrete)
	add_wall_with_gap(Vector2(CORRIDOR_HALF, YARD_Z), Vector2(30, YARD_Z), 4.0, 4.0, 0.4, _concrete)

	# Sandbags and crates for cover.
	for i in 5:
		add_block(Vector3(-20.0 + float(i) * 1.1, 0.4, 18.0), Vector3(1.0, 0.8, 1.0), _dirt, "Sandbag")
	for i in 4:
		add_block(Vector3(12.0, 0.5 + float(i) * 0.9, 16.0), Vector3(1.6, 0.9, 1.6), _wood, "Crate")
	add_block(Vector3(0.0, 1.6, 22.0), Vector3(6.0, 3.2, 0.6), _metal, "GateFrame")

	# A watchtower you can climb for a look at the yard.
	add_block(Vector3(-24.0, 3.0, 14.0), Vector3(5.0, 6.0, 5.0), _metal, "Watchtower")
	add_block(Vector3(-19.5, 1.5, 16.5), Vector3(4.0, 0.4, 2.0), _wood, "TowerRamp")

	# A weapon within arm's reach of the spawn, so nobody has to fist-fight
	# a ghost on their first minute in the level.
	spawn_weapon("wooden_bat", Vector3(6.0, 0.9, 17.0))


func _make_dormitory() -> void:
	# West room, z from MID_Z (0) up to YARD_Z (10).
	# North wall is SOLID: the only ways in are the yard gap and the corridor
	# door, so the dormitory never becomes a back door into the armoury.
	add_wall(Vector2(-30, MID_Z), Vector2(-CORRIDOR_HALF, MID_Z), 4.0, 0.4, _concrete)
	add_wall_with_gap(Vector2(-CORRIDOR_HALF, YARD_Z), Vector2(-CORRIDOR_HALF, MID_Z), 2.6, 4.0, 0.4, _concrete)

	# Eight bunk beds: two low blocks and a mattress slab each.
	for i in 4:
		var x := -26.0 + float(i) * 6.0
		add_block(Vector3(x, 0.35, 2.4), Vector3(3.4, 0.7, 1.0), _metal, "BunkFrame")
		add_block(Vector3(x, 0.95, 2.4), Vector3(3.2, 0.25, 0.9), _dirt, "Mattress")
		add_block(Vector3(x, 0.35, 6.4), Vector3(3.4, 0.7, 1.0), _metal, "BunkFrame")
		add_block(Vector3(x, 0.95, 6.4), Vector3(3.2, 0.25, 0.9), _dirt, "Mattress")
	# Lockers along the back wall.
	for i in 8:
		add_block(Vector3(-29.0, 1.0, 8.2 - float(i) * 0.9), Vector3(0.8, 2.0, 0.8), _metal, "Locker")

	# The armoury key sits on the middle bunk, in plain sight but watched.
	spawn_key("armoury_key", "Rusted Armoury Key", Vector3(-20.0, 1.35, 2.4))
	spawn_health_kit(Vector3(-26.0, 0.0, 8.6), 35.0)


func _make_mess_hall() -> void:
	add_wall_with_gap(Vector2(CORRIDOR_HALF, MID_Z), Vector2(30, MID_Z), 3.0, 4.0, 0.4, _concrete)
	add_wall_with_gap(Vector2(CORRIDOR_HALF, YARD_Z), Vector2(CORRIDOR_HALF, MID_Z), 2.6, 4.0, 0.4, _concrete)

	# Long tables with benches.
	for i in 3:
		var z := 1.8 + float(i) * 3.2
		add_block(Vector3(14.0, 0.75, z), Vector3(12.0, 0.2, 1.3), _wood, "TableTop")
		add_block(Vector3(14.0, 0.38, z), Vector3(11.0, 0.7, 0.5), _wood, "TableLegs")
		add_block(Vector3(14.0, 0.4, z - 1.2), Vector3(11.0, 0.15, 0.45), _wood, "Bench")
		add_block(Vector3(14.0, 0.4, z + 1.2), Vector3(11.0, 0.15, 0.45), _wood, "Bench")
	# Kitchen counter and a serving hatch.
	add_block(Vector3(28.0, 0.9, 5.0), Vector3(3.0, 1.8, 10.0), _metal, "Counter")
	add_block(Vector3(24.0, 1.0, 9.0), Vector3(1.2, 2.0, 1.2), _rust, "Stove")

	spawn_weapon("frying_pan", Vector3(14.0, 1.0, 3.4))
	spawn_health_kit(Vector3(18.0, 0.0, 8.4), 35.0)


func _make_armoury() -> void:
	# West block, z from NORTH_Z (-16) to MID_Z (0). LOCKED behind ONE door.
	# Both the north wall and the corridor wall must be sealed except for the
	# single locked doorway at z = -8, otherwise the key is pointless.
	add_wall(Vector2(-30, NORTH_Z), Vector2(-CORRIDOR_HALF, NORTH_Z), 4.0, 0.5, _brick)
	add_wall_with_gap(Vector2(-CORRIDOR_HALF, MID_Z), Vector2(-CORRIDOR_HALF, NORTH_Z), 2.8, 4.0, 0.4, _concrete)

	# Weapon racks and crates.
	for i in 5:
		add_block(Vector3(-27.0, 1.1, -3.0 - float(i) * 2.2), Vector3(0.4, 2.2, 1.6), _rust, "Rack")
	for i in 4:
		add_block(Vector3(-20.0 + float(i) * 3.2, 0.6, -13.0), Vector3(1.8, 1.2, 1.8), _wood, "AmmoCrate")
	add_block(Vector3(-11.0, 1.3, -8.0), Vector3(1.0, 2.6, 6.0), _metal, "Safe")

	# The katana. This is the reward for finding the key.
	spawn_weapon("katana", Vector3(-22.0, 1.2, -8.0))

	# The locked door is in the corridor wall at z = -8.
	add_door(Vector3(-CORRIDOR_HALF, 0.0, -8.0), 90.0, "armoury_key", "Rusted Armoury Key")


func _make_cellar() -> void:
	# East block, mirror of the armoury. Open, but darker. Sealed to the north.
	add_wall(Vector2(CORRIDOR_HALF, NORTH_Z), Vector2(30, NORTH_Z), 4.0, 0.5, _brick)
	add_wall_with_gap(Vector2(CORRIDOR_HALF, MID_Z), Vector2(CORRIDOR_HALF, NORTH_Z), 2.8, 4.0, 0.4, _concrete)

	for i in 6:
		var z := -2.0 - float(i) * 2.3
		add_block(Vector3(6.0, 0.6, z), Vector3(3.0, 1.2, 1.4), _wood, "Shelf")
		add_block(Vector3(20.0, 0.6, z), Vector3(3.0, 1.2, 1.4), _wood, "Shelf")
	add_block(Vector3(26.0, 1.0, -12.0), Vector3(2.0, 2.0, 2.0), _rust, "Boiler")

	spawn_weapon("spirit_trap", Vector3(16.0, 1.0, -8.0))
	spawn_health_kit(Vector3(25.0, 0.0, -3.0), 35.0)


func _make_parade_ground() -> void:
	# The big open hall north of the corridor: the King's arena.
	add_block(Vector3(0.0, 0.02, -26.0), Vector3(36.0, 0.04, 20.0), _concrete, "ParadeFloor")

	# A raised dais in the middle so the fight has verticality.
	add_block(Vector3(0.0, 0.6, -28.0), Vector3(12.0, 1.2, 8.0), _concrete, "Dais")
	add_block(Vector3(0.0, 0.35, -22.0), Vector3(4.0, 0.7, 4.0), _concrete, "DaisStep")

	# Broken pillars, for cover and for the look of the place.
	for i in 6:
		var a := -1.0 + float(i) * 0.4
		add_block(Vector3(a * 14.0, 3.0, -20.5), Vector3(1.4, 6.0, 1.4), _brick, "Pillar")
		add_block(Vector3(a * 14.0, 3.0, -34.0), Vector3(1.4, 6.0, 1.4), _brick, "Pillar")

	# Fallen banners, a memorial stone.
	add_block(Vector3(-10.0, 1.6, -30.0), Vector3(2.4, 3.2, 0.5), _metal, "Memorial")
	spawn_note(Vector3(-10.0, 2.2, -29.6),
		"THE LAST STAND\n\nWe held the parade ground for nine hours.\nThen the drums stopped, and the ones we buried stood back up.\n\nThey still salute before they strike.",
		"barracks_parade", "")


func _make_chapel() -> void:
	# North-west quiet room. The Queen holds court here.
	# One doorway only, on the east wall, at z = -30.
	add_wall_with_gap(Vector2(-18, -36), Vector2(-18, -24), 3.2, 4.5, 0.5, _brick)
	add_wall(Vector2(-30, -24), Vector2(-18, -24), 4.5, 0.5, _brick)

	# Pews either side of a central aisle, facing an altar.
	# Chapel interior runs x = -30 .. -18, so:
	#   left pews   x -29 .. -25
	#   aisle       x -25 .. -22   <- the Queen walks this
	#   right pews  x -22 .. -19
	for i in 4:
		var z := -28.0 - float(i) * 1.6
		add_block(Vector3(-27.0, 0.4, z), Vector3(4.0, 0.18, 0.5), _wood, "Pew")
		add_block(Vector3(-20.5, 0.4, z), Vector3(3.0, 0.18, 0.5), _wood, "Pew")
	add_block(Vector3(-24.0, 0.5, -34.0), Vector3(6.0, 1.0, 1.6), _concrete, "Altar")

	spawn_weapon("ghost_lantern", Vector3(-24.0, 1.25, -34.0))
	spawn_note(Vector3(-25.5, 0.8, -26.0),
		"THE QUEEN\n\nShe wears red to hide the blood.\nHer tears fall upwards. Do not look at her eyes for long - she counts the seconds you do.\n\nThe lantern on the altar makes the hidden visible.",
		"barracks_chapel", "")


func _make_generator_room() -> void:
	# North-east machine room. One doorway only, on the west wall, at z = -30.
	add_wall_with_gap(Vector2(18, -36), Vector2(18, -24), 3.2, 4.5, 0.5, _brick)
	add_wall(Vector2(30, -24), Vector2(18, -24), 4.5, 0.5, _brick)

	add_block(Vector3(24.0, 1.4, -32.0), Vector3(6.0, 2.8, 3.0), _rust, "Generator")
	add_block(Vector3(24.0, 3.4, -32.0), Vector3(2.0, 1.2, 2.0), _metal, "GeneratorHead")
	for i in 3:
		add_block(Vector3(20.0 + float(i) * 4.5, 0.9, -26.0), Vector3(1.2, 1.8, 1.2), _metal, "Transformer")

	spawn_health_kit(Vector3(27.0, 0.0, -34.0), 35.0)
	spawn_note(Vector3(22.0, 0.8, -34.0),
		"THE GENERATOR KEEPS DYING\n\nEvery time we restart it, the lights come back a little dimmer.\nI counted sixty-one restarts. Tonight I am not going to bother.\n\nSomeone please break the rifles.",
		"barracks_generator", "")


func _make_lights() -> void:
	# Corridor: a line of failing strip lights.
	for i in 7:
		var z := 8.0 - float(i) * 3.6
		spawn_light(Vector3(0.0, 3.4, z), Color(1.0, 0.90, 0.72), 1.15, 7.0)
	# Yard and rooms: dimmer, colder.
	spawn_light(Vector3(0.0, 3.6, 17.0), Color(0.78, 0.84, 1.0), 0.9, 9.0)
	spawn_light(Vector3(-18.0, 3.2, 5.0), Color(1.0, 0.88, 0.70), 0.8, 8.0)
	spawn_light(Vector3(16.0, 3.2, 5.0), Color(1.0, 0.88, 0.70), 0.8, 8.0)
	spawn_light(Vector3(-22.0, 3.2, -8.0), Color(0.72, 0.80, 1.0), 0.55, 9.0)
	spawn_light(Vector3(18.0, 3.2, -8.0), Color(0.70, 0.78, 0.95), 0.55, 9.0)
	# The chapel gets a red glow. Of course it does.
	spawn_glow(Vector3(-24.0, 2.6, -33.0), Color(1.0, 0.22, 0.24), 1.5, 8.0)
	spawn_glow(Vector3(-18.0, 2.6, -30.0), Color(0.85, 0.12, 0.16), 0.9, 6.0)
	# The parade ground, lit from the dais.
	spawn_glow(Vector3(0.0, 2.2, -28.0), Color(0.30, 0.85, 0.92), 2.0, 14.0)
	spawn_light(Vector3(0.0, 6.0, -20.0), Color(0.85, 0.90, 1.0), 0.7, 16.0)


func _make_notes() -> void:
	spawn_note(Vector3(2.0, 0.8, 20.0),
		"STANDING ORDERS\n\n1. Nobody leaves the compound after dark.\n2. Nobody answers a voice that calls their own name.\n3. If you see a soldier with no face, run.\n\nSomeone has crossed out rule 2 and written: THEY LEARNED OUR NAMES.",
		"barracks_gate", "Find a weapon - the dormitory is west of the yard")


func _place_ghosts() -> void:
	# --- EASIEST: the girl soldiers, two of them, in the near rooms --------
	spawn_ghost(GhostRig.Body.SOLDIER_FEMALE, Vector3(-18.0, 0.4, 5.0), "barracks_girl_dorm", 7.0, false, 180.0)
	spawn_ghost(GhostRig.Body.SOLDIER_FEMALE, Vector3(18.0, 0.4, 3.0), "barracks_girl_mess", 7.0, false, 180.0)

	# --- EASY: the boy soldiers, patrolling the yard and the machines ------
	spawn_ghost(GhostRig.Body.SOLDIER_MALE, Vector3(-8.0, 0.4, 18.0), "barracks_boy_yard", 10.0, false, 0.0)
	spawn_ghost(GhostRig.Body.SOLDIER_MALE, Vector3(24.0, 0.4, -29.0), "barracks_boy_generator", 6.0, false, 180.0)

	# --- HARD: the Queen, waiting in the red chapel aisle ------------------
	spawn_ghost(GhostRig.Body.GHOST_QUEEN, Vector3(-23.5, 0.4, -30.0), "barracks_queen", 6.0, false, 0.0)

	# --- HARDEST: the King, standing on the dais --------------------------
	spawn_ghost(GhostRig.Body.GHOST_KING, Vector3(0.0, 1.6, -30.0), "barracks_king", 12.0, false, 180.0)
