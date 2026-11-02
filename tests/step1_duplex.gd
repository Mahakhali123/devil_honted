extends Node3D
## =========================================================================
## Step 1 duplex preview  -  the Haveli of Kamla
## =========================================================================
## A two-storey, five-room home instead of one open hall:
##
##   GROUND   living hall (double height) | dining | kitchen |
##            bedroom | back hall | corridor | stair hall
##   FIRST    gallery over the living hall | upper bedroom | staircase
##   EXTRA    pooja room (god temple) | tantra room (black magic)
##   OUTSIDE  veranda, courtyard, tulsi, well, dead tree
##
## Default mode: renders a still to preview/ and quits.
## Live mode   : launch with  -- --live  to walk it yourself.
## Angle       : -- --angle=living|corridor|stairs|puja|tantra|upper|
##               upperbed|dining|kitchen|bedroom|outside
## =========================================================================

const PLAYER := preload("res://player/player.tscn")
const HUD := preload("res://ui/hud.tscn")
const DOOR := preload("res://props/door.tscn")

const UPPER_Y := 3.4
const TOP_Y := 6.6

var _player: PlayerController
var _live := false
var _mats: Dictionary = {}
var _fans: Array[Node3D] = []
var _doors: Array[HauntedDoor] = []
var _flicker: Array[OmniLight3D] = []
var _angle := ""
var _last_zone := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--angle="):
			_angle = arg.substr("--angle=".length())
	_live = "--live" in OS.get_cmdline_user_args()

	# The main menu reaches this scene through GameManager.start_level(), which
	# sets current_level_id before the scene change. That must be a playable
	# run, not the standalone screenshot mode (which quits after one frame).
	# Direct scene previews still boot with an empty current_level_id and keep
	# their old capture behaviour.
	if GameManager.current_level_id == "haveli_mansion":
		_live = true

	GameManager.current_level_id = "haveli_mansion"
	GameManager.player_is_dead = false
	GameManager.is_paused = false
	GameManager.set_game_state(GameManager.GameState.EXPLORATION)
	GameManager.set_threat(0.0)
	GameManager.set_sanity(100.0)
	GameManager.set_zone("living_hall")
	GameManager.set_objectives([
		{"id": "ingredients", "text": "Collect 3 ritual ingredients (0/3)", "done": false},
		{"id": "pooja_key", "text": "Find the Pooja Room key", "done": false},
		{"id": "havan", "text": "Perform the Havan at the temple", "done": false},
		{"id": "kamla", "text": "Do not let Kamla find you", "done": false},
	])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_build_environment()
	_build_house()
	if "--dumpdoor" in OS.get_cmdline_user_args():
		await _dump_entrance()
		get_tree().quit()
		return
	_spawn_player()
	add_child(HUD.instantiate())

	await get_tree().process_frame
	if _live:
		_start_live()
		return
	GameManager.show_message(
		"The Haveli is awake.\nFive rooms. A temple. A room that should stay locked.\nE opens doors.",
		2.0
	)
	_run_preview()


func _dump_entrance() -> void:
	for i in 10:
		await get_tree().process_frame
	var zone := AABB(Vector3(-2.8, 0.0, 4.5), Vector3(5.6, 4.2, 4.2))
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		if not box.intersects(zone):
			continue
		var col := Color.MAGENTA
		var ov := mi.material_override
		if ov is StandardMaterial3D:
			col = (ov as StandardMaterial3D).albedo_color
		print("MESH ", mi.get_path(), " pos=", mi.global_position,
			" aabb=", box, " size=", mi.mesh.get_aabb().size, " col=", col)
	for d in _doors:
		if d.global_position.z < 4.5:
			continue
		print("DOOR pos=", d.global_position, " open=", d.is_open,
			" yaw=", d.rotation_degrees.y, " pivot=",
			d.get_node("Pivot").rotation_degrees, " scale=", d.scale)


func _start_live() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.show_message(
		"THE HAVELI OF KAMLA\n" +
		"WASD walk   SHIFT sprint   CTRL crouch   E open doors   F torch\n" +
		"Climb the stairs. The pooja room is at the back. Do not enter the red room.",
		10.0
	)


func _process(delta: float) -> void:
	for fan in _fans:
		if is_instance_valid(fan):
			fan.rotation.y += delta * 0.8
	var t := Time.get_ticks_msec() / 1000.0
	for light in _flicker:
		if is_instance_valid(light):
			var base := float(light.get_meta("base", 0.7))
			var phase := float(light.get_meta("phase", 0.0))
			var f := 0.72 + 0.20 * sin(t * 11.0 + phase) + 0.08 * sin(t * 29.0 + phase * 2.0)
			light.light_energy = base * clampf(f, 0.35, 1.08)
	_update_zone()


func _update_zone() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p := _player.global_position
	var z := "living_hall"
	if p.z > 7.05:
		z = "courtyard" if p.z > 9.70 else "veranda"
	elif p.y > 3.0:
		z = "upper_bedroom" if p.z > 2.0 else "upper_gallery"
	elif p.z < -2.0:
		if absf(p.x) < 1.1:
			z = "corridor"
		elif p.x < -1.0:
			z = "black_magic_room"
		else:
			z = "pooja_room"
	elif p.z < 2.0:
		if p.x < -3.0:
			z = "kitchen"
		elif p.x > 3.0:
			z = "stair_hall"
		else:
			z = "back_hall"
	elif p.x < -3.0:
		z = "dining_room"
	elif p.x > 3.0:
		z = "bedroom_ground"
	if z != _last_zone:
		_last_zone = z
		GameManager.set_zone(z)


# =========================================================================
#  WORLD
# =========================================================================
func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.018, 0.045, 1.0)
	sky_mat.sky_horizon_color = Color(0.070, 0.080, 0.130, 1.0)
	sky_mat.ground_bottom_color = Color(0.010, 0.010, 0.015, 1.0)
	sky_mat.ground_horizon_color = Color(0.040, 0.045, 0.060, 1.0)
	sky_mat.sun_angle_max = 8.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.24, 0.22, 0.27, 1.0)
	env.ambient_light_energy = 0.31
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.035, 0.040, 0.065, 1.0)
	env.fog_density = 0.018
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 2.6
	env.ssao_power = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.10
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52.0, 28.0, 0.0)
	moon.light_color = Color(0.36, 0.46, 0.78)
	moon.light_energy = 0.38
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.shadow_bias = 0.04
	add_child(moon)

	# Cool spoiler light across the courtyard and the front facade.
	var spot := SpotLight3D.new()
	spot.position = Vector3(6.0, 13.5, 18.0)
	spot.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	spot.light_color = Color(0.46, 0.56, 0.86)
	spot.light_energy = 3.4
	spot.spot_range = 46.0
	spot.spot_angle = 52.0
	spot.spot_attenuation = 0.9
	spot.shadow_enabled = true
	spot.shadow_bias = 0.05
	add_child(spot)


func _make_materials() -> void:
	_mats["plaster"] = _mat(Color(0.33, 0.28, 0.23), 0.95)
	_mats["plaster_dark"] = _mat(Color(0.21, 0.18, 0.16), 0.98)
	_mats["lime"] = _mat(Color(0.45, 0.41, 0.34), 0.92)
	_mats["wood_dark"] = _mat(Color(0.115, 0.070, 0.040), 0.85)
	_mats["wood"] = _mat(Color(0.25, 0.15, 0.08), 0.82)
	_mats["wood_light"] = _mat(Color(0.38, 0.24, 0.13), 0.75)
	_mats["floor_a"] = _mat(Color(0.19, 0.11, 0.055), 0.72)
	_mats["floor_b"] = _mat(Color(0.24, 0.15, 0.08), 0.72)
	_mats["floor_c"] = _mat(Color(0.16, 0.09, 0.05), 0.72)
	_mats["stone_a"] = _mat(Color(0.22, 0.21, 0.19), 0.95)
	_mats["stone_b"] = _mat(Color(0.28, 0.26, 0.23), 0.95)
	_mats["marble"] = _mat(Color(0.59, 0.55, 0.47), 0.50)
	_mats["brass"] = _metal(Color(0.72, 0.53, 0.20))
	_mats["copper"] = _metal(Color(0.53, 0.27, 0.13))
	_mats["iron"] = _metal(Color(0.14, 0.14, 0.16))
	_mats["clay"] = _mat(Color(0.40, 0.18, 0.10), 0.95)
	_mats["soil"] = _mat(Color(0.09, 0.06, 0.04), 1.0)
	_mats["green"] = _mat(Color(0.10, 0.26, 0.08), 0.90)
	_mats["cloth_red"] = _mat(Color(0.32, 0.045, 0.04), 1.0)
	_mats["cloth_cream"] = _mat(Color(0.62, 0.54, 0.39), 1.0)
	_mats["rug"] = _mat(Color(0.26, 0.035, 0.035), 1.0)
	_mats["rug_inner"] = _mat(Color(0.47, 0.34, 0.14), 1.0)
	_mats["dark"] = _mat(Color(0.025, 0.020, 0.018), 1.0)
	_mats["soot"] = _mat(Color(0.055, 0.045, 0.040), 1.0)
	_mats["bone"] = _mat(Color(0.71, 0.66, 0.53), 0.85)
	_mats["blood"] = _mat(Color(0.16, 0.008, 0.008), 1.0)
	_mats["meat"] = _mat(Color(0.29, 0.035, 0.030), 0.72)
	_mats["skin"] = _mat(Color(0.56, 0.43, 0.35), 0.78)
	_mats["tantra"] = _mat(Color(0.10, 0.025, 0.025), 1.0)
	_mats["marigold"] = _mat(Color(0.95, 0.50, 0.05), 0.80)
	_mats["marigold2"] = _mat(Color(0.82, 0.27, 0.02), 0.80)
	_mats["flame"] = _emissive(Color(1.0, 0.64, 0.20), 3.4)
	_mats["window_glow"] = _emissive(Color(0.60, 0.40, 0.18), 0.50)
	_mats["moon"] = _emissive(Color(0.34, 0.48, 0.92), 1.3)
	_mats["moon_glow"] = _emissive(Color(0.78, 0.85, 1.0), 1.8)
	_mats["star"] = _emissive(Color(0.85, 0.90, 1.0), 1.2)
	_mats["sigil"] = _emissive(Color(0.95, 0.06, 0.03), 1.2)


func _build_house() -> void:
	_make_materials()
	_build_shell()
	_build_floors()
	_build_stairs()
	_build_doors()
	_build_living()
	_build_dining()
	_build_kitchen()
	_build_bedroom_ground()
	_build_back_hall()
	_build_corridor()
	_build_stair_hall()
	_build_pooja()
	_build_tantra()
	_build_upper_gallery()
	_build_bedroom_upper()
	_build_exterior()
	if "--noftext" not in OS.get_cmdline_user_args():
		_build_floor_signatures()


# =========================================================================
#  SHELL
# =========================================================================
func _build_shell() -> void:
	var plaster: Material = _mats["plaster"]
	var dark: Material = _mats["wood_dark"]

	# Ground slab.
	_solid(Vector3(0.0, -0.15, 0.0), Vector3(16.3, 0.3, 14.3), _mats["floor_a"])

	# ---- outer ground walls -------------------------------------------
	_wall_z(-7.0, -8.0, 8.0, 0.0, 3.4, plaster, 0.25)
	_wall_x(-8.0, -7.0, 7.0, 0.0, 3.4, plaster, 0.25)
	_wall_x(8.0, -7.0, 7.0, 0.0, 3.4, plaster, 0.25)
	# Front wall split around the 3.6 m main doorway.
	_wall_z(7.0, -8.0, -1.8, 0.0, 3.4, plaster, 0.25)
	_wall_z(7.0, 1.8, 8.0, 0.0, 3.4, plaster, 0.25)
	_wall_z(7.0, -1.8, 1.8, 2.7, 0.7, plaster, 0.25)

	# ---- ground interior walls ---------------------------------------
	# Living hall north wall, with the 2.4 m arch into the back hall.
	_wall_z(2.0, -3.0, -1.2, 0.0, 3.4, plaster)
	_wall_z(2.0, 1.2, 3.0, 0.0, 3.4, plaster)
	_wall_z(2.0, -1.2, 1.2, 2.4, 1.0, plaster)

	# Living west wall -> dining, door gap z 4.2..5.2.
	_wall_x(-3.0, 2.0, 4.2, 0.0, 3.4, plaster)
	_wall_x(-3.0, 5.2, 7.0, 0.0, 3.4, plaster)
	_wall_x(-3.0, 4.2, 5.2, 2.1, 1.3, plaster)

	# Living east wall -> bedroom, door gap z 4.2..5.2.
	_wall_x(3.0, 2.0, 4.2, 0.0, 3.4, plaster)
	_wall_x(3.0, 5.2, 7.0, 0.0, 3.4, plaster)
	_wall_x(3.0, 4.2, 5.2, 2.1, 1.3, plaster)

	# Dining / kitchen wall at z = 2, door gap x -6.2..-5.2.
	_wall_z(2.0, -8.0, -6.2, 0.0, 3.4, plaster)
	_wall_z(2.0, -5.2, -3.0, 0.0, 3.4, plaster)
	_wall_z(2.0, -6.2, -5.2, 2.1, 1.3, plaster)

	# Kitchen east wall -> back hall, door gap z -0.5..0.5.
	_wall_x(-3.0, -2.0, -0.5, 0.0, 3.4, plaster)
	_wall_x(-3.0, 0.5, 2.0, 0.0, 3.4, plaster)
	_wall_x(-3.0, -0.5, 0.5, 2.1, 1.3, plaster)

	# Back rooms' front wall at z = -2, corridor gap x -1..1.
	_wall_z(-2.0, -8.0, -1.0, 0.0, 3.4, plaster)
	_wall_z(-2.0, 1.0, 8.0, 0.0, 3.4, plaster)

	# Corridor side walls, doors at z -4.6..-3.6.
	_wall_x(-1.0, -7.0, -4.6, 0.0, 3.4, plaster)
	_wall_x(-1.0, -3.6, -2.0, 0.0, 3.4, plaster)
	_wall_x(-1.0, -4.6, -3.6, 2.1, 1.3, plaster)
	_wall_x(1.0, -7.0, -4.6, 0.0, 3.4, plaster)
	_wall_x(1.0, -3.6, -2.0, 0.0, 3.4, plaster)
	_wall_x(1.0, -4.6, -3.6, 2.1, 1.3, plaster)

	# Stair hall west wall: 3 m arch from the back hall.
	_wall_x(3.0, -2.0, -1.5, 0.0, 3.4, plaster)
	_wall_x(3.0, 1.5, 2.0, 0.0, 3.4, plaster)
	_wall_x(3.0, -1.5, 1.5, 2.5, 0.9, plaster)

	# Stair hall / ground bedroom shared wall.
	_wall_z(2.0, 3.0, 8.0, 0.0, 3.4, plaster)

	# ---- first floor walls -------------------------------------------
	# Living hall west + east, above the single-storey wings and bedroom.
	_wall_x(-3.0, 2.0, 7.0, UPPER_Y, 3.2, plaster, 0.25)
	_wall_x(3.0, 2.0, 7.0, UPPER_Y, 3.2, plaster)
	# Upper gallery shell.
	_wall_z(-4.0, -3.0, 8.0, UPPER_Y, 3.2, plaster, 0.25)
	_wall_x(-3.0, -4.0, 2.0, UPPER_Y, 3.2, plaster, 0.25)
	_wall_x(8.0, -4.0, 2.0, UPPER_Y, 3.2, plaster, 0.25)
	# Upper bedroom shell.
	_wall_x(8.0, 2.0, 7.0, UPPER_Y, 3.2, plaster, 0.25)
	_wall_z(7.0, -3.0, 8.0, UPPER_Y, 3.2, plaster, 0.25)
	# Upper bedroom north wall with a 1 m door at x 4..5.
	_wall_z(2.0, 3.0, 4.0, UPPER_Y, 3.2, plaster)
	_wall_z(2.0, 5.0, 8.0, UPPER_Y, 3.2, plaster)
	_wall_z(2.0, 4.0, 5.0, 5.5, 1.1, plaster)

	# ---- roofs --------------------------------------------------------
	# Main two-storey roof.
	_solid(Vector3(2.5, TOP_Y + 0.15, 1.5), Vector3(11.4, 0.3, 11.4), dark)
	# Left wing roof and rear roof (single storey).
	_solid(Vector3(-5.5, 3.525, 0.0), Vector3(5.4, 0.25, 14.4), dark)
	_solid(Vector3(2.5, 3.525, -5.5), Vector3(11.4, 0.25, 3.4), dark)

	# Main roof parapet.
	_wall_z(7.0, -3.0, 8.0, TOP_Y + 0.3, 0.55, plaster)
	_wall_z(-4.0, -3.0, 8.0, TOP_Y + 0.3, 0.55, plaster)
	_wall_x(-3.0, -4.0, 7.0, TOP_Y + 0.3, 0.55, plaster)
	_wall_x(8.0, -4.0, 7.0, TOP_Y + 0.3, 0.55, plaster)
	# Single-storey roof parapets.
	_wall_z(7.0, -8.0, -3.0, 3.65, 0.50, plaster)
	_wall_z(-7.0, -8.0, 8.0, 3.65, 0.50, plaster)
	_wall_x(-8.0, -7.0, 7.0, 3.65, 0.50, plaster)
	_wall_x(8.0, -7.0, -4.0, 3.65, 0.50, plaster)

	# ---- trims --------------------------------------------------------
	# Skirting in the main ground rooms.
	_skirting_z(2.02, -3.0, 3.0, 0.02)
	_skirting_z(6.98, -8.0, 8.0, 0.02)
	_skirting_x(-3.02, 2.0, 7.0, 0.02)
	_skirting_x(3.02, 2.0, 7.0, 0.02)

	# Ceiling beams over the double-height living hall.
	for bz in [2.6, 3.5, 4.4, 5.3, 6.2]:
		_deco(Vector3(0.0, TOP_Y - 0.18, bz), Vector3(6.0, 0.22, 0.20), dark)
	_deco(Vector3(0.0, TOP_Y - 0.16, 4.4), Vector3(0.22, 0.22, 5.0), dark)

	# Gallery railing over the living hall.
	_railing_z(2.0, -3.0, 3.0)
	# Stairwell railing on the upper floor.
	_railing_x(6.2, -2.0, 1.3)
	_railing_x(7.4, -2.0, 1.3)
	_railing_z(1.3, 6.2, 7.4)
	# Newel posts at the stair top.
	_newel(Vector3(6.2, UPPER_Y, -2.0))
	_newel(Vector3(7.4, UPPER_Y, -2.0))
	_newel(Vector3(6.2, UPPER_Y, 1.3))
	_newel(Vector3(7.4, UPPER_Y, 1.3))


func _build_floors() -> void:
	var a: Material = _mats["floor_b"]
	var b: Material = _mats["floor_a"]
	var c: Material = _mats["floor_c"]

	# Ground floor boards / stone.
	_wood_floor(Rect2(-3.0, 2.0, 6.0, 5.0), a, b)
	_wood_floor(Rect2(-8.0, 2.0, 5.0, 5.0), b, c)
	_wood_floor(Rect2(-8.0, -2.0, 5.0, 4.0), a, c)
	_wood_floor(Rect2(3.0, 2.0, 5.0, 5.0), b, a)
	_tile_floor(Rect2(-3.0, -2.0, 6.0, 4.0), _mats["stone_a"], _mats["stone_b"])
	_tile_floor(Rect2(-1.0, -7.0, 2.0, 5.0), _mats["stone_a"], _mats["stone_b"], 0.012, 0.65)
	_tile_floor(Rect2(3.0, -2.0, 5.0, 4.0), _mats["stone_a"], _mats["stone_b"])
	# Pooja marble, tantra black stone.
	_tile_floor(Rect2(1.0, -7.0, 7.0, 5.0), _mats["marble"], _mats["marble"], 0.012, 0.9)
	_tile_floor(Rect2(-8.0, -7.0, 7.0, 5.0), _mats["soot"], _mats["tantra"], 0.012, 0.85)

	# First floor slabs (top at UPPER_Y).
	_solid(Vector3(1.6, UPPER_Y - 0.1, 0.0), Vector3(9.2, 0.2, 4.0), _mats["wood"])
	_solid(Vector3(2.5, UPPER_Y - 0.1, -3.0), Vector3(11.0, 0.2, 2.0), _mats["wood"])
	_solid(Vector3(7.7, UPPER_Y - 0.1, -0.35), Vector3(0.6, 0.2, 3.3), _mats["wood"])
	_solid(Vector3(6.8, UPPER_Y - 0.1, 1.65), Vector3(1.2, 0.2, 0.7), _mats["wood"])
	_solid(Vector3(5.5, UPPER_Y - 0.1, 4.5), Vector3(5.0, 0.2, 5.0), _mats["wood"])

	# Upper floor boards.
	_wood_floor(Rect2(-3.0, -2.0, 9.2, 4.0), a, b, UPPER_Y + 0.012)
	_wood_floor(Rect2(-3.0, -4.0, 11.0, 2.0), b, c, UPPER_Y + 0.012)
	_wood_floor(Rect2(3.0, 2.0, 5.0, 5.0), a, b, UPPER_Y + 0.012)

	# Stair nosing.
	_deco(Vector3(6.8, UPPER_Y - 0.04, -2.0), Vector3(1.2, 0.08, 0.12), _mats["wood_light"])


func _build_stairs() -> void:
	# A straight, steep old-house stair. The ramp is the collision; the
	# visible treads are decorative boxes sitting on top of it.
	var rise := UPPER_Y
	var run := 3.3
	var z_bottom := 1.3
	var z_top := -2.0
	var angle := rad_to_deg(atan(rise / run))
	var length := sqrt(rise * rise + run * run)
	var wood: Material = _mats["wood"]
	var dark: Material = _mats["wood_dark"]
	var light: Material = _mats["wood_light"]

	_solid_rot(Vector3(6.8, rise * 0.5, (z_bottom + z_top) * 0.5),
		Vector3(1.2, 0.18, length), dark, Vector3(angle, 0.0, 0.0))

	var steps := 17
	var step_run := run / float(steps)
	for i in steps:
		var z := z_bottom - (float(i) + 0.5) * step_run
		var y := (float(i) + 0.5) * (rise / float(steps))
		_deco(Vector3(6.8, y, z), Vector3(1.2, rise / float(steps), step_run + 0.02), wood)
		_deco(Vector3(6.8, y + rise / float(steps) * 0.5 + 0.01, z + step_run * 0.45),
			Vector3(1.2, 0.03, 0.04), light)

	# Stringers.
	for sx in [6.16, 7.44]:
		_deco(Vector3(sx, rise * 0.5 + 0.03, (z_bottom + z_top) * 0.5),
			Vector3(0.08, 0.32, length), dark).rotation_degrees.x = angle

	# Handrail on the open side.
	_deco(Vector3(6.12, rise * 0.5 + 0.95, (z_bottom + z_top) * 0.5),
		Vector3(0.06, 0.06, length), light).rotation_degrees.x = angle
	for pz in [z_bottom + 0.05, z_top - 0.05]:
		_cyl(Vector3(6.12, 0.55, pz), 0.045, 1.10, dark)
	_cyl(Vector3(6.12, UPPER_Y + 0.55, z_top - 0.05), 0.045, 1.10, dark)


func _build_doors() -> void:
	# Main entrance: two full-size leaves, open in the still previews.
	var left := DOOR.instantiate() as HauntedDoor
	left.position = Vector3(-1.8, 0.0, 7.0)
	left.open_angle = -150.0
	left.collision_layer = 257
	left.is_open = not _live
	add_child(left)
	_doors.append(left)
	_blood_sign(left, "A GAME BY")

	var right := DOOR.instantiate() as HauntedDoor
	right.position = Vector3(1.8, 0.0, 7.0)
	right.rotation_degrees.y = 180.0
	right.open_angle = 150.0
	right.collision_layer = 257
	right.is_open = not _live
	add_child(right)
	_doors.append(right)
	_blood_sign(right, "NISHANTH")

	# Architrave and torans.
	var wl: Material = _mats["wood_light"]
	var wd: Material = _mats["wood_dark"]
	_deco(Vector3(-1.9, 1.55, 6.94), Vector3(0.14, 3.1, 0.14), wl)
	_deco(Vector3(1.9, 1.55, 6.94), Vector3(0.14, 3.1, 0.14), wl)
	_deco(Vector3(0.0, 3.04, 6.94), Vector3(4.0, 0.16, 0.14), wl)
	_deco(Vector3(0.0, 2.78, 6.88), Vector3(3.7, 0.07, 0.10), _mats["brass"])
	_garland(Vector3(0.0, 2.66, 6.86), 3.2, 0.25)
	_garland(Vector3(0.0, 2.64, 7.14), 3.2, 0.26)
	_deco(Vector3(0.0, 3.04, 7.14), Vector3(4.0, 0.14, 0.12), wl)
	_sconce(Vector3(-3.55, 2.02, 7.16), 0.75)
	_sconce(Vector3(3.55, 2.02, 7.16), 0.75)
	# Main-door threshold.
	_deco(Vector3(0.0, 0.015, 7.0), Vector3(3.6, 0.03, 0.36), wd)

	# Interior doors. The still previews leave room doors open; the corridor
	# doors stay shut because the darkness behind them is the point.
	_interior_door(Vector3(-3.0, 0.0, 5.2), 90.0, not _live)
	_interior_door(Vector3(3.0, 0.0, 4.2), -90.0, not _live)
	_interior_door(Vector3(-6.2, 0.0, 2.0), 0.0, not _live)
	_interior_door(Vector3(-3.0, 0.0, 0.5), 90.0, not _live)
	_interior_door(Vector3(-1.0, 0.0, -3.6), 90.0, false)
	_interior_door(Vector3(1.0, 0.0, -4.6), -90.0, false)
	_interior_door(Vector3(4.0, UPPER_Y, 2.0), 0.0, not _live)


# =========================================================================
#  BUILDING HELPERS
# =========================================================================
func _solid(pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body


func _solid_rot(pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3) -> StaticBody3D:
	var body := _solid(pos, size, mat)
	body.rotation_degrees = rot_deg
	return body


func _wall_x(x: float, z0: float, z1: float, y0: float, h: float,
		mat: Material = null, thick := 0.2) -> StaticBody3D:
	var m: Material = mat if mat != null else _mats["plaster"]
	return _solid(Vector3(x, y0 + h * 0.5, (z0 + z1) * 0.5),
		Vector3(thick, h, absf(z1 - z0)), m)


func _wall_z(z: float, x0: float, x1: float, y0: float, h: float,
		mat: Material = null, thick := 0.2) -> StaticBody3D:
	var m: Material = mat if mat != null else _mats["plaster"]
	return _solid(Vector3((x0 + x1) * 0.5, y0 + h * 0.5, z),
		Vector3(absf(x1 - x0), h, thick), m)


func _skirting_z(z: float, x0: float, x1: float, y: float) -> void:
	_deco(Vector3((x0 + x1) * 0.5, y + 0.10, z), Vector3(absf(x1 - x0), 0.20, 0.04), _mats["wood_dark"])


func _skirting_x(x: float, z0: float, z1: float, y: float) -> void:
	_deco(Vector3(x, y + 0.10, (z0 + z1) * 0.5), Vector3(0.04, 0.20, absf(z1 - z0)), _mats["wood_dark"])


func _blood_sign(door: HauntedDoor, text: String) -> void:
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = text
		label.font = ThemeDB.fallback_font
		label.font_size = 64
		label.pixel_size = 0.0042
		label.modulate = Color(0.46, 0.030, 0.018)
		label.outline_size = 12
		label.outline_modulate = Color(0.10, 0.0, 0.0)
		label.shaded = false
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector3(0.9, 1.55, side * 0.095)
		label.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
		door.get_node("Pivot").add_child(label)


func _interior_door(hinge: Vector3, yaw_deg: float, open: bool) -> void:
	var frame := Node3D.new()
	frame.position = hinge
	frame.rotation_degrees.y = yaw_deg
	add_child(frame)
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	_deco(Vector3(-0.02, 1.05, 0.0), Vector3(0.10, 2.10, 0.30), wd, frame)
	_deco(Vector3(1.02, 1.05, 0.0), Vector3(0.10, 2.10, 0.30), wd, frame)
	_deco(Vector3(0.50, 2.15, 0.0), Vector3(1.16, 0.10, 0.30), wl, frame)
	_deco(Vector3(0.50, 0.02, 0.0), Vector3(1.00, 0.04, 0.32), _mats["wood"], frame)

	var d := DOOR.instantiate() as HauntedDoor
	d.position = hinge
	d.rotation_degrees.y = yaw_deg
	d.scale = Vector3(0.5, 0.77, 1.0)
	d.collision_layer = 257
	d.open_angle = -95.0
	d.is_open = open
	add_child(d)
	_doors.append(d)


func _railing_z(z: float, x0: float, x1: float) -> void:
	var y := UPPER_Y
	_deco(Vector3((x0 + x1) * 0.5, y + 1.00, z), Vector3(absf(x1 - x0), 0.08, 0.10), _mats["wood_light"])
	_deco(Vector3((x0 + x1) * 0.5, y + 0.16, z), Vector3(absf(x1 - x0), 0.06, 0.08), _mats["wood_dark"])
	var x := x0
	while x <= x1:
		_deco(Vector3(x, y + 0.55, z), Vector3(0.045, 0.85, 0.045), _mats["wood_dark"])
		x += 0.5
	_newel(Vector3(x0, y, z))
	_newel(Vector3(x1, y, z))


func _railing_x(x: float, z0: float, z1: float) -> void:
	var y := UPPER_Y
	_deco(Vector3(x, y + 1.00, (z0 + z1) * 0.5), Vector3(0.10, 0.08, absf(z1 - z0)), _mats["wood_light"])
	_deco(Vector3(x, y + 0.16, (z0 + z1) * 0.5), Vector3(0.08, 0.06, absf(z1 - z0)), _mats["wood_dark"])
	var z := z0
	while z <= z1:
		_deco(Vector3(x, y + 0.55, z), Vector3(0.045, 0.85, 0.045), _mats["wood_dark"])
		z += 0.5


func _newel(pos: Vector3) -> void:
	_cyl(pos + Vector3(0.0, 0.55, 0.0), 0.075, 1.10, _mats["wood_dark"])
	_sphere(pos + Vector3(0.0, 1.12, 0.0), 0.09, _mats["brass"])


func _deco(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if parent != null:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi


func _cyl(pos: Vector3, radius: float, height: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if parent != null:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi


func _sphere(pos: Vector3, radius: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if parent != null:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi


func _torus(pos: Vector3, inner: float, outer: float, mat: Material,
		parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if parent != null:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _metal(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.85
	m.roughness = 0.35
	return m


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _wood_floor(rect: Rect2, a: Material, b: Material, y := 0.012) -> void:
	var x := rect.position.x
	var i := 0
	while x < rect.position.x + rect.size.x:
		var w := minf(0.28, rect.position.x + rect.size.x - x)
		_deco(Vector3(x + w * 0.5, y, rect.position.y + rect.size.y * 0.5),
			Vector3(w - 0.008, 0.01, rect.size.y), a if i % 2 == 0 else b)
		x += w
		i += 1


func _tile_floor(rect: Rect2, a: Material, b: Material, y := 0.012, tile := 0.8) -> void:
	var gx := rect.position.x
	var ix := 0
	while gx < rect.position.x + rect.size.x:
		var gz := rect.position.y
		var iz := 0
		while gz < rect.position.y + rect.size.y:
			_deco(Vector3(gx + tile * 0.5, y, gz + tile * 0.5),
				Vector3(tile - 0.03, 0.01, tile - 0.03), a if (ix + iz) % 2 == 0 else b)
			gz += tile
			iz += 1
		gx += tile
		ix += 1


# =========================================================================
#  FURNITURE HELPERS
# =========================================================================
func _blocker(pos: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.y = yaw
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body


func _lamp_light(pos: Vector3, energy: float,
		color := Color(1.0, 0.62, 0.30), range_m := 5.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.35
	l.shadow_enabled = false
	l.set_meta("base", energy)
	l.set_meta("phase", float(_flicker.size()) * 1.7)
	_flicker.append(l)
	add_child(l)
	return l


func _sconce(pos: Vector3, energy: float, dir := Vector3(0.0, 0.0, 1.0)) -> void:
	var wd: Material = _mats["iron"]
	_deco(pos, Vector3(0.07, 0.28, 0.06), wd)
	var cup := _cyl(pos + dir * 0.12 + Vector3(0.0, 0.02, 0.0), 0.075, 0.06,
		_mats["brass"])
	cup.rotation_degrees.x = 90.0
	_sphere(pos + dir * 0.16 + Vector3(0.0, 0.10, 0.0), 0.035, _mats["flame"])
	_lamp_light(pos + dir * 0.32 + Vector3(0.0, 0.06, 0.0), energy,
		Color(1.0, 0.60, 0.28), 4.2)


func _lantern(top: Vector3, drop: float, energy: float, range_m := 5.5) -> void:
	var wd: Material = _mats["iron"]
	var brass: Material = _mats["brass"]
	_cyl(top + Vector3(0.0, -drop * 0.5, 0.0), 0.012, drop, wd)
	_deco(top + Vector3(0.0, -drop, 0.0), Vector3(0.20, 0.035, 0.20), brass)
	_deco(top + Vector3(0.0, -drop - 0.26, 0.0), Vector3(0.20, 0.035, 0.20), brass)
	for cx in [-0.09, 0.09]:
		for cz in [-0.09, 0.09]:
			_deco(top + Vector3(cx, -drop - 0.135, cz), Vector3(0.02, 0.24, 0.02), wd)
	_sphere(top + Vector3(0.0, -drop - 0.15, 0.0), 0.055, _mats["flame"])
	_lamp_light(top + Vector3(0.0, -drop - 0.18, 0.0), energy,
		Color(1.0, 0.64, 0.32), range_m)


func _garland(pos: Vector3, width: float, drop: float, yaw := 0.0) -> void:
	var n := maxi(6, int(width / 0.13))
	var a: Material = _mats["marigold"]
	var b: Material = _mats["marigold2"]
	for i in n:
		var t := float(i) / float(n - 1)
		var local := Vector3((t - 0.5) * width, -sin(t * PI) * drop, 0.0)
		var off := local.rotated(Vector3.UP, deg_to_rad(yaw))
		_sphere(pos + off, 0.055, a if i % 2 == 0 else b)


func _rug(pos: Vector3, size: Vector2, mat: Material, border: Material) -> void:
	_deco(pos + Vector3(0.0, 0.008, 0.0), Vector3(size.x, 0.016, size.y), border)
	_deco(pos + Vector3(0.0, 0.018, 0.0), Vector3(size.x - 0.26, 0.016, size.y - 0.26), mat)


func _chair(pos: Vector3, yaw: float, mat: Material = null) -> void:
	var m: Material = mat if mat != null else _mats["wood"]
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	_deco(Vector3(0.0, 0.45, 0.0), Vector3(0.46, 0.06, 0.44), m, n)
	_deco(Vector3(0.0, 0.76, -0.20), Vector3(0.46, 0.56, 0.05), m, n)
	_deco(Vector3(0.0, 0.66, -0.19), Vector3(0.34, 0.20, 0.03),
		_mats["wood_light"], n)
	for lx in [-0.19, 0.19]:
		for lz in [-0.18, 0.18]:
			_deco(Vector3(lx, 0.21, lz), Vector3(0.05, 0.42, 0.05), m, n)
	_blocker(pos + Vector3(0.0, 0.45, 0.0), Vector3(0.52, 0.9, 0.5), yaw)


func _table(pos: Vector3, size: Vector2, height: float, mat: Material = null) -> void:
	var m: Material = mat if mat != null else _mats["wood"]
	_deco(pos + Vector3(0.0, height, 0.0), Vector3(size.x, 0.07, size.y), m)
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			_deco(pos + Vector3(lx * (size.x * 0.5 - 0.09),
				(height - 0.04) * 0.5, lz * (size.y * 0.5 - 0.09)),
				Vector3(0.07, height - 0.04, 0.07), m)
	_blocker(pos + Vector3(0.0, height * 0.5, 0.0),
		Vector3(size.x, height, size.y))


func _cupboard(pos: Vector3, yaw: float, w: float, h: float, d: float,
		mat: Material = null) -> void:
	var m: Material = mat if mat != null else _mats["wood_dark"]
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	_deco(Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), m, n)
	_deco(Vector3(0.0, h + 0.04, 0.0), Vector3(w + 0.10, 0.08, d + 0.08), m, n)
	_deco(Vector3(0.0, 0.06, 0.0), Vector3(w + 0.04, 0.12, d + 0.04),
		_mats["wood"], n)
	for s in [-1.0, 1.0]:
		_deco(Vector3(s * w * 0.245, h * 0.52, d * 0.5 + 0.012),
			Vector3(w * 0.46, h * 0.84, 0.035), _mats["wood"], n)
		_deco(Vector3(s * w * 0.245, h * 0.52, d * 0.5 + 0.035),
			Vector3(w * 0.40, h * 0.72, 0.018), m, n)
		_sphere(Vector3(s * 0.05, h * 0.52, d * 0.5 + 0.06), 0.028,
			_mats["brass"], n)
	_blocker(pos + Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), yaw)


func _diwan(pos: Vector3, yaw: float, length: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var wd: Material = _mats["wood_dark"]
	_deco(Vector3(0.0, 0.20, 0.0), Vector3(0.98, 0.28, length), wd, n)
	_deco(Vector3(0.0, 0.40, 0.0), Vector3(0.92, 0.14, length - 0.10),
		_mats["cloth_cream"], n)
	_deco(Vector3(0.0, 0.52, -length * 0.5 + 0.03),
		Vector3(0.98, 0.55, 0.09), wd, n)
	for i in 3:
		var z := -length * 0.28 + float(i) * length * 0.28
		_deco(Vector3(-0.30, 0.55, z), Vector3(0.28, 0.20, 0.34),
			_mats["cloth_red"], n)
	var bolster := _cyl(Vector3(0.26, 0.55, -length * 0.28), 0.10, 0.52,
		_mats["cloth_cream"], n)
	bolster.rotation_degrees.z = 90.0
	_blocker(pos + Vector3(0.0, 0.3, 0.0), Vector3(1.0, 0.6, length), yaw)


func _bed(pos: Vector3, yaw: float, w: float, l: float,
		frame_mat: Material = null) -> void:
	var m: Material = frame_mat if frame_mat != null else _mats["wood"]
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	_deco(Vector3(0.0, 0.24, 0.0), Vector3(w, 0.30, l), m, n)
	_deco(Vector3(0.0, 0.44, 0.0), Vector3(w - 0.10, 0.16, l - 0.10),
		_mats["cloth_cream"], n)
	_deco(Vector3(0.0, 0.535, 0.12 * l), Vector3(w - 0.16, 0.03, l * 0.52),
		_mats["cloth_red"], n)
	_deco(Vector3(0.0, 0.56, -l * 0.5 + 0.32), Vector3(w * 0.58, 0.11, 0.34),
		_mats["cloth_cream"], n)
	var bol := _cyl(Vector3(0.0, 0.58, -l * 0.5 + 0.62), 0.085, w * 0.55,
		_mats["cloth_cream"], n)
	bol.rotation_degrees.z = 90.0
	_deco(Vector3(0.0, 0.82, -l * 0.5 - 0.03), Vector3(w + 0.12, 1.14, 0.08),
		m, n)
	_deco(Vector3(-w * 0.5 - 0.03, 0.30, -l * 0.5 + 0.10),
		Vector3(0.08, 0.36, 0.16), m, n)
	_deco(Vector3(w * 0.5 + 0.03, 0.30, -l * 0.5 + 0.10),
		Vector3(0.08, 0.36, 0.16), m, n)
	_blocker(pos + Vector3(0.0, 0.45, 0.0), Vector3(w + 0.08, 0.9, l), yaw)


func _mirror(pos: Vector3, yaw: float, w: float, h: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	_deco(Vector3(0.0, 0.0, 0.03), Vector3(w + 0.10, h + 0.10, 0.05),
		_mats["wood_dark"], n)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.20, 0.23, 0.26)
	glass.metallic = 1.0
	glass.roughness = 0.06
	_deco(Vector3(0.0, 0.0, 0.06), Vector3(w, h, 0.02), glass, n)


func _portrait(pos: Vector3, yaw: float, w: float, h: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	_deco(Vector3(0.0, 0.0, 0.03), Vector3(w + 0.09, h + 0.09, 0.06),
		_mats["wood_light"], n)
	_deco(Vector3(0.0, 0.0, 0.065), Vector3(w, h, 0.02),
		_mats["soot"], n)
	var face := _sphere(Vector3(0.0, -0.02, 0.078), 0.13, _mats["bone"], n)
	face.scale = Vector3(0.78, 1.05, 0.20)
	for ex in [-0.045, 0.045]:
		var eye := _sphere(Vector3(ex, 0.01, 0.094), 0.018, _mats["dark"], n)
		eye.scale = Vector3(1.0, 1.0, 0.4)


## The framed photograph of Nishanth above the tantra altar.
func _memorial_portrait(pos: Vector3, w: float, h: float, yaw := 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var gold: Material = _mats["brass"]
	var wd: Material = _mats["wood_dark"]

	# Carved frame: dark wood carcass, gold lip, inner shadow line.
	_deco(Vector3(0.0, 0.0, 0.015), Vector3(w + 0.30, h + 0.30, 0.07), wd, n)
	_deco(Vector3(0.0, 0.0, 0.055), Vector3(w + 0.19, h + 0.19, 0.05), gold, n)
	_deco(Vector3(0.0, 0.0, 0.085), Vector3(w + 0.05, h + 0.05, 0.03), wd, n)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var boss := _sphere(Vector3(sx * (w * 0.5 + 0.105),
				sy * (h * 0.5 + 0.105), 0.095), 0.052, gold, n)
			boss.scale = Vector3(1.0, 1.0, 0.55)

	# The photograph itself, faintly self-lit so it reads in the red dark.
	var tex := load("res://assets/textures/nishanth.jpg") as Texture2D
	if tex != null:
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = tex
		pm.roughness = 0.58
		pm.emission_enabled = true
		pm.emission = Color(1.0, 1.0, 1.0)
		pm.emission_texture = tex
		pm.emission_energy_multiplier = 0.05
		var photo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(w, h)
		photo.mesh = quad
		photo.material_override = pm
		photo.position = Vector3(0.0, 0.0, 0.106)
		n.add_child(photo)

	# Small brass picture light over the top edge.
	_deco(Vector3(0.0, h * 0.5 + 0.24, 0.16), Vector3(0.56, 0.055, 0.10), gold, n)
	for sx in [-0.21, 0.21]:
		_deco(Vector3(sx, h * 0.5 + 0.17, 0.13), Vector3(0.035, 0.15, 0.035), gold, n)
	_lamp_light(n.to_global(Vector3(0.0, h * 0.5 + 0.22, 0.42)), 0.10,
		Color(1.0, 0.96, 0.90), 1.6)

	# Engraved plaque below the frame.
	var py := -h * 0.5 - 0.34
	_deco(Vector3(0.0, py, 0.05), Vector3(1.16, 0.30, 0.055), gold, n)
	_deco(Vector3(0.0, py, 0.080), Vector3(1.10, 0.24, 0.02), _mats["soot"], n)
	var name_label := Label3D.new()
	name_label.text = "NISHANTH"
	name_label.font = ThemeDB.fallback_font
	name_label.font_size = 58
	name_label.pixel_size = 0.0022
	name_label.modulate = Color(0.88, 0.76, 0.44)
	name_label.outline_size = 0
	name_label.shaded = false
	name_label.double_sided = false
	name_label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector3(0.0, py + 0.050, 0.098)
	n.add_child(name_label)
	var title_label := Label3D.new()
	title_label.text = "THE ONE WHO KILLED THE GHOST"
	title_label.font = ThemeDB.fallback_font
	title_label.font_size = 28
	title_label.pixel_size = 0.0022
	title_label.modulate = Color(0.74, 0.63, 0.37)
	title_label.outline_size = 0
	title_label.shaded = false
	title_label.double_sided = false
	title_label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.position = Vector3(0.0, py - 0.068, 0.098)
	n.add_child(title_label)


## A lavish, carved-and-gilded frame for one of the ghost photographs.
## All five reference images are used: four full pictures and the ten
## portraits cropped out of the fifth image. Pass the file name without
## the extension; see assets/textures/ghost_photos/.
func _rich_photo_frame(pos: Vector3, yaw: float, w: float, h: float,
		tex_name: String, caption := "", crest := true, light := false) -> Node3D:
	var n := Node3D.new()
	n.name = "Portrait_" + tex_name
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var wood: Material = _mats["wood_dark"]
	var wood2: Material = _mats["wood"]
	var gold: Material = _mats["brass"]
	var copper: Material = _mats["copper"]
	var soot: Material = _mats["soot"]

	# Cabinet-maker's carcass: dark backing, stepped gilt moldings, black reveal.
	_deco(Vector3(0.0, 0.0, 0.015), Vector3(w + 0.36, h + 0.36, 0.07), wood, n)
	_deco(Vector3(0.0, 0.0, 0.055), Vector3(w + 0.27, h + 0.27, 0.05), wood2, n)
	_deco(Vector3(0.0, 0.0, 0.083), Vector3(w + 0.155, h + 0.155, 0.035), gold, n)
	_deco(Vector3(0.0, 0.0, 0.103), Vector3(w + 0.06, h + 0.06, 0.025), soot, n)

	# Fluted pilasters down both sides, with capitals and bases.
	for sx in [-1.0, 1.0]:
		var px: float = sx * (w * 0.5 + 0.185)
		_deco(Vector3(px, 0.0, 0.102), Vector3(0.085, h + 0.12, 0.06), gold, n)
		_deco(Vector3(px, 0.0, 0.134), Vector3(0.045, h + 0.02, 0.018), soot, n)
		for sy in [-1.0, 1.0]:
			_deco(Vector3(px, sy * (h * 0.5 + 0.045), 0.128),
				Vector3(0.145, 0.085, 0.075), gold, n)
			_sphere(Vector3(px, sy * (h * 0.5 + 0.195), 0.128), 0.042, gold, n)

	# Carved corner bosses and leaf rosettes.
	for sx2 in [-1.0, 1.0]:
		for sy2 in [-1.0, 1.0]:
			var cx: float = sx2 * (w * 0.5 + 0.145)
			var cy2: float = sy2 * (h * 0.5 + 0.145)
			var boss := _sphere(Vector3(cx, cy2, 0.135), 0.062, gold, n)
			boss.scale = Vector3(1.0, 1.0, 0.45)
			for k in 4:
				var a := TAU * float(k) / 4.0 + PI * 0.25
				_sphere(Vector3(cx + cos(a) * 0.075, cy2 + sin(a) * 0.075, 0.123),
					0.026, copper, n)

	# Crest: a little carved sunburst and brass finials.
	if crest:
		var cy3: float = h * 0.5 + 0.20
		_deco(Vector3(0.0, cy3 + 0.04, 0.105), Vector3(0.30, 0.075, 0.060), gold, n)
		for i in 5:
			var fx: float = -0.15 + float(i) * 0.075
			var lift: float = 0.055 if i == 2 else (0.028 if (i == 1 or i == 3) else 0.0)
			var spike := _cyl(Vector3(fx, cy3 + 0.14 + lift, 0.108),
				0.014, 0.20 + lift, gold, n)
			spike.rotation_degrees.z = -20.0 + float(i) * 10.0
			_sphere(Vector3(fx, cy3 + 0.245 + lift, 0.108), 0.026, copper, n)

	# The photograph, floated behind a faint pane of old glass.
	var tex := load("res://assets/textures/ghost_photos/%s.jpg" % tex_name) as Texture2D
	if tex != null:
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = tex
		pm.roughness = 0.55
		pm.emission_enabled = true
		pm.emission = Color(0.92, 0.86, 0.74)
		pm.emission_texture = tex
		pm.emission_energy_multiplier = 0.07
		pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var photo := MeshInstance3D.new()
		photo.name = "Photograph"
		var quad := QuadMesh.new()
		quad.size = Vector2(w, h)
		photo.mesh = quad
		photo.material_override = pm
		photo.position = Vector3(0.0, 0.0, 0.122)
		n.add_child(photo)
	else:
		_deco(Vector3(0.0, 0.0, 0.122), Vector3(w, h, 0.01), _mats["soot"], n)

	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.64, 0.78, 1.0, 0.055)
	glass.metallic = 0.35
	glass.roughness = 0.05
	_deco(Vector3(0.0, 0.0, 0.128), Vector3(w, h, 0.006), glass, n)

	# Engraved brass plaque under the frame.
	if caption != "":
		var py: float = -h * 0.5 - 0.285
		var plate_w: float = minf(w + 0.20, 0.98)
		_deco(Vector3(0.0, py, 0.055), Vector3(plate_w, 0.165, 0.035), gold, n)
		_deco(Vector3(0.0, py, 0.076), Vector3(plate_w - 0.055, 0.120, 0.016), soot, n)
		var label := Label3D.new()
		label.text = caption
		label.font = ThemeDB.fallback_font
		label.font_size = 34
		label.pixel_size = 0.00155
		label.modulate = Color(0.90, 0.78, 0.48)
		label.outline_size = 0
		label.shaded = false
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector3(0.0, py, 0.090)
		n.add_child(label)

	# Small brass picture light.
	if light:
		_deco(Vector3(0.0, h * 0.5 + 0.33, 0.17),
			Vector3(minf(w * 0.8, 0.62), 0.042, 0.065), gold, n)
		_deco(Vector3(0.0, h * 0.5 + 0.285, 0.185),
			Vector3(minf(w * 0.6, 0.44), 0.024, 0.028),
			_emissive(Color(1.0, 0.78, 0.42), 2.2), n)
		_lamp_light(n.to_global(Vector3(0.0, h * 0.5 + 0.30, 0.46)), 0.05,
			Color(1.0, 0.84, 0.62), 1.5)
	return n


func _wall_clock(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	_deco(Vector3(0.0, 0.0, 0.04), Vector3(0.50, 0.58, 0.08),
		_mats["wood_dark"], n)
	var face := _cyl(Vector3(0.0, 0.0, 0.095), 0.21, 0.03, _mats["cloth_cream"], n)
	face.rotation_degrees.x = 90.0
	_deco(Vector3(0.0, 0.06, 0.115), Vector3(0.02, 0.13, 0.01),
		_mats["dark"], n)
	_deco(Vector3(0.04, -0.01, 0.115), Vector3(0.09, 0.018, 0.01),
		_mats["dark"], n)


func _window(pos: Vector3, yaw: float, w: float, h: float, glow := true) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	_deco(Vector3(0.0, 0.0, 0.05), Vector3(w + 0.16, h + 0.16, 0.08),
		_mats["wood_dark"], n)
	var pane: Material = _mats["window_glow"] if glow else _mats["dark"]
	_deco(Vector3(0.0, 0.0, 0.085), Vector3(w, h, 0.02), pane, n)
	_deco(Vector3(0.0, 0.0, 0.10), Vector3(0.045, h, 0.03), _mats["iron"], n)
	_deco(Vector3(0.0, 0.0, 0.10), Vector3(w, 0.045, 0.03), _mats["iron"], n)


func _chhajja(x: float, y: float, z: float, w: float) -> void:
	_deco(Vector3(x, y, z + 0.18), Vector3(w + 0.35, 0.12, 0.55),
		_mats["stone_b"])
	for sx in [-1.0, 1.0]:
		_deco(Vector3(x + sx * (w * 0.5 - 0.05), y - 0.20, z + 0.16),
			Vector3(0.12, 0.34, 0.30), _mats["stone_a"])


func _diya(pos: Vector3, scale := 1.0) -> void:
	_cyl(pos, 0.085 * scale, 0.045 * scale, _mats["clay"])
	_sphere(pos + Vector3(0.0, 0.06 * scale, 0.0), 0.035 * scale,
		_mats["flame"])


func _idol(pos: Vector3, scale := 1.0, mat: Material = null) -> void:
	var m: Material = mat if mat != null else _mats["brass"]
	_deco(pos + Vector3(0.0, 0.08 * scale, 0.0),
		Vector3(0.42 * scale, 0.16 * scale, 0.34 * scale), _mats["marble"])
	_cyl(pos + Vector3(0.0, 0.42 * scale, 0.0), 0.16 * scale, 0.54 * scale, m)
	_sphere(pos + Vector3(0.0, 0.76 * scale, 0.0), 0.12 * scale, m)
	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.015
	crown_mesh.bottom_radius = 0.11 * scale
	crown_mesh.height = 0.20 * scale
	crown.mesh = crown_mesh
	crown.material_override = m
	crown.position = pos + Vector3(0.0, 0.92 * scale, 0.0)
	add_child(crown)
	for s in [-1.0, 1.0]:
		var arm := _cyl(pos + Vector3(s * 0.19 * scale, 0.48 * scale, 0.02),
			0.035 * scale, 0.44 * scale, m)
		arm.rotation_degrees.z = s * 22.0


func _candle(pos: Vector3, height: float) -> void:
	_cyl(pos + Vector3(0.0, height * 0.5, 0.0), 0.028, height,
		_mats["cloth_cream"])
	_sphere(pos + Vector3(0.0, height + 0.03, 0.0), 0.022, _mats["flame"])


func _skull(pos: Vector3, scale := 1.0) -> void:
	var b: Material = _mats["bone"]
	_sphere(pos + Vector3(0.0, 0.10 * scale, 0.0), 0.11 * scale, b)
	_deco(pos + Vector3(0.0, 0.015 * scale, 0.035 * scale),
		Vector3(0.13 * scale, 0.07 * scale, 0.12 * scale), b)
	for ex in [-0.045, 0.045]:
		_sphere(pos + Vector3(ex * scale, 0.11 * scale, 0.085 * scale),
			0.023 * scale, _mats["dark"])


func _pot(pos: Vector3, radius: float, height: float, mat: Material = null) -> void:
	var m: Material = mat if mat != null else _mats["clay"]
	_cyl(pos + Vector3(0.0, height * 0.5, 0.0), radius, height, m)
	_cyl(pos + Vector3(0.0, height - 0.015, 0.0), radius * 0.72,
		0.05, _mats["dark"])


func _trunk(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var wd: Material = _mats["wood_dark"]
	_deco(Vector3(0.0, 0.24, 0.0), Vector3(1.0, 0.48, 0.55), wd, n)
	_deco(Vector3(0.0, 0.50, -0.10), Vector3(1.0, 0.10, 0.40), _mats["wood"], n)
	for bx in [-0.32, 0.32]:
		_deco(Vector3(bx, 0.26, 0.0), Vector3(0.07, 0.50, 0.58),
			_mats["iron"], n)
	_sphere(Vector3(0.0, 0.40, 0.29), 0.04, _mats["brass"], n)
	_blocker(pos + Vector3(0.0, 0.25, 0.0), Vector3(1.0, 0.5, 0.56), yaw)


func _tulsi(pos: Vector3) -> void:
	_deco(pos + Vector3(0.0, 0.20, 0.0), Vector3(0.62, 0.40, 0.62),
		_mats["stone_b"])
	_cyl(pos + Vector3(0.0, 0.58, 0.0), 0.20, 0.34, _mats["clay"])
	_cyl(pos + Vector3(0.0, 0.88, 0.0), 0.045, 0.34, _mats["wood"])
	for i in 5:
		var a := TAU * float(i) / 5.0
		var leaf := _sphere(pos + Vector3(cos(a) * 0.18, 0.98 + float(i % 2) * 0.06,
			sin(a) * 0.18), 0.13, _mats["green"])
		leaf.scale = Vector3(1.0, 0.55, 1.0)
	_deco(Vector3(pos.x, pos.y + 1.32, pos.z), Vector3(0.06, 0.42, 0.06),
		_mats["brass"])
	_lamp_light(pos + Vector3(0.0, 1.45, 0.0), 0.45,
		Color(1.0, 0.72, 0.36), 3.0)


# =========================================================================
#  ROOMS  -  ground floor
# =========================================================================
func _build_living() -> void:
	_rug(Vector3(-0.45, 0.02, 4.45), Vector2(4.3, 3.2), _mats["rug"],
		_mats["rug_inner"])
	_diwan(Vector3(-2.35, 0.0, 4.55), 0.0, 2.4)
	_table(Vector3(-0.55, 0.0, 4.45), Vector2(1.15, 0.65), 0.42)
	_chair(Vector3(1.45, 0.0, 5.45), -90.0)
	_table(Vector3(2.35, 0.0, 4.15), Vector2(0.55, 0.55), 0.62)
	_diya(Vector3(2.35, 0.66, 4.15), 1.2)
	_cupboard(Vector3(2.64, 0.0, 2.85), -90.0, 1.15, 2.05, 0.55)
	# The family wall: three very different ages of the same haunted bloodline.
	_rich_photo_frame(Vector3(2.86, 2.10, 6.42), -90.0, 1.14, 0.64,
		"royal_couple_sepia", "THE ROYAL COUPLE", true, true)
	_rich_photo_frame(Vector3(-2.86, 2.12, 3.02), 90.0, 0.62, 0.83,
		"girl_ghost_green_portrait", "THE GIRL IN THE MIST", true, true)
	_rich_photo_frame(Vector3(1.78, 2.15, 2.06), 0.0, 0.56, 0.72,
		"01_royal_couple_king_queen", "KING & QUEEN", true, false)
	_wall_clock(Vector3(-2.86, 2.25, 6.15), 90.0)
	_sconce(Vector3(-2.15, 2.15, 2.15), 0.70)
	_sconce(Vector3(2.15, 2.15, 2.15), 0.70)
	_garland(Vector3(0.0, 3.12, 2.15), 2.7, 0.30)
	_lantern(Vector3(0.0, 6.38, 4.45), 2.05, 1.20, 8.5)
	# Low shelf of family photographs near the arch.
	_table(Vector3(-2.35, 0.0, 2.34), Vector2(0.85, 0.35), 0.80)
	for i in 3:
		_deco(Vector3(-2.62 + float(i) * 0.28, 0.94, 2.34),
			Vector3(0.20, 0.24, 0.03), _mats["soot"])
		_deco(Vector3(-2.62 + float(i) * 0.28, 0.94, 2.36),
			Vector3(0.22, 0.26, 0.02), _mats["wood_light"])


func _build_dining() -> void:
	_rug(Vector3(-5.55, 0.02, 4.45), Vector2(3.4, 3.6), _mats["rug_inner"],
		_mats["rug"])
	_table(Vector3(-5.55, 0.0, 4.45), Vector2(1.15, 2.25), 0.80)
	for z in [3.55, 4.45, 5.35]:
		_chair(Vector3(-6.55, 0.0, z), 90.0)
		_chair(Vector3(-4.55, 0.0, z), -90.0)
	for z in [3.55, 4.45, 5.35]:
		for x in [-5.92, -5.18]:
			_cyl(Vector3(x, 0.83, z), 0.13, 0.025, _mats["cloth_cream"])
	_cupboard(Vector3(-7.58, 0.0, 3.35), 90.0, 1.85, 1.10, 0.52)
	_deco(Vector3(-7.40, 1.19, 3.35), Vector3(0.30, 0.18, 0.18),
		_mats["brass"])
	_candle(Vector3(-7.35, 1.10, 3.05), 0.22)
	_candle(Vector3(-7.35, 1.10, 3.65), 0.18)
	_lantern(Vector3(-5.55, 3.20, 4.45), 1.05, 1.00, 6.0)
	_rich_photo_frame(Vector3(-5.55, 2.24, 6.86), 180.0, 1.22, 0.68,
		"royal_couple_stylized", "THE LAST SUPPER", true, true)
	_rich_photo_frame(Vector3(-7.35, 2.08, 2.06), 0.0, 0.56, 0.72,
		"04_queen_ghost_solo", "THE QUEEN", true, false)
	_rich_photo_frame(Vector3(-6.55, 2.08, 2.06), 0.0, 0.56, 0.72,
		"05_couple_ghost_haveli", "THE HAVELI COUPLE", true, false)
	_dining_gore()
	_window(Vector3(-7.96, 2.10, 5.55), 90.0, 1.20, 1.20)
	_tulsi_placeholder()
	_sconce(Vector3(-3.14, 2.20, 6.20), 0.55, Vector3(-1.0, 0.0, 0.0))


func _tulsi_placeholder() -> void:
	# A brass water pot in the dining corner.
	_pot(Vector3(-7.35, 0.0, 6.35), 0.22, 0.42, _mats["brass"])
	_deco(Vector3(-7.35, 0.45, 6.35), Vector3(0.34, 0.10, 0.34),
		_mats["copper"])


## The dinner the family never finished: meat, blood, and the guest of honour.
func _dining_gore() -> void:
	var blood: Material = _mats["blood"]
	var meat: Material = _mats["meat"]
	var bone: Material = _mats["bone"]
	var plate: Material = _mats["cloth_cream"]
	var dark: Material = _mats["dark"]
	var table_y := 0.80

	# Six plates, each with a raw joint and a pool of blood.
	for z in [3.55, 4.45, 5.35]:
		for x in [-5.92, -5.18]:
			_cyl(Vector3(x, table_y + 0.035, z), 0.155, 0.022, plate)
			_cyl(Vector3(x, table_y + 0.050, z), 0.112, 0.007, blood)
			var chunk := _sphere(Vector3(x, table_y + 0.095, z), 0.075, meat)
			chunk.scale = Vector3(1.25, 0.55, 0.90)
			_sphere(Vector3(x + 0.035, table_y + 0.115, z - 0.030),
				0.044, meat)

	# Central platter: blood pool, a severed head, and a meat haunch.
	var c := Vector3(-5.55, table_y + 0.045, 4.45)
	_cyl(c, 0.42, 0.030, plate)
	_cyl(c + Vector3(0.0, 0.018, 0.0), 0.355, 0.012, blood)
	var haunch := _sphere(Vector3(-5.93, table_y + 0.13, 4.08),
		0.105, meat)
	haunch.scale = Vector3(1.35, 0.65, 0.95)
	var bone_handle := _cyl(Vector3(-6.04, table_y + 0.10, 4.02),
		0.032, 0.22, bone)
	bone_handle.rotation_degrees.z = 68.0

	# The head faces east, straight at anyone walking in from the hall.
	var head := Node3D.new()
	head.position = c + Vector3(0.0, 0.20, 0.0)
	head.rotation_degrees.y = 90.0
	add_child(head)
	var skin: Material = _mats["skin"]
	var skull := _sphere(Vector3(0.0, 0.0, 0.0), 0.17, skin, head)
	skull.scale = Vector3(0.92, 1.05, 0.94)
	var hair := _sphere(Vector3(0.0, 0.11, -0.060), 0.181, dark, head)
	hair.scale = Vector3(1.0, 0.78, 0.96)
	_deco(Vector3(0.0, -0.125, 0.055), Vector3(0.16, 0.10, 0.15), skin, head)
	for ex in [-0.055, 0.055]:
		_sphere(Vector3(ex, 0.035, 0.145), 0.027, dark, head)
		_sphere(Vector3(ex, 0.035, 0.158), 0.009,
			_emissive(Color(0.95, 0.72, 0.35), 2.0), head)
	_deco(Vector3(0.0, 0.010, 0.172), Vector3(0.045, 0.060, 0.05), skin, head)
	_deco(Vector3(0.0, -0.060, 0.160), Vector3(0.09, 0.018, 0.020), blood, head)
	_sphere(Vector3(0.030, -0.030, 0.152), 0.014, _mats["blood"], head)
	_cyl(Vector3(0.0, -0.165, 0.020), 0.070, 0.10, blood, head)

	# A knife left standing in the cloth, and blood running off the table edge.
	var knife := _deco(Vector3(-5.18, table_y + 0.075, 4.92),
		Vector3(0.34, 0.014, 0.048), _mats["iron"])
	knife.rotation_degrees.y = 22.0
	_deco(Vector3(-5.02, table_y + 0.075, 4.86), Vector3(0.10, 0.030, 0.060),
		_mats["wood_dark"])
	for i in 3:
		var drip := _deco(Vector3(-5.72 + float(i) * 0.17, 0.56, 5.575),
			Vector3(0.018, 0.40 + 0.10 * float(i % 2), 0.018), blood)
		drip.rotation_degrees.x = 0.0


func _build_kitchen() -> void:
	var wd: Material = _mats["wood_dark"]
	# Long work counter against the west wall.
	_deco(Vector3(-7.62, 0.44, 0.15), Vector3(0.66, 0.88, 2.00), wd)
	_deco(Vector3(-7.62, 0.90, 0.15), Vector3(0.74, 0.07, 2.08),
		_mats["stone_b"])
	_blocker(Vector3(-7.62, 0.45, 0.15), Vector3(0.70, 0.92, 2.05))
	for z in [-0.50, 0.15, 0.80]:
		_deco(Vector3(-7.28, 0.45, z), Vector3(0.02, 0.66, 0.78),
			_mats["wood"])
		_sphere(Vector3(-7.25, 0.52, z + 0.30), 0.025, _mats["brass"])
	# Sink cut into the counter.
	_deco(Vector3(-7.62, 0.86, 0.55), Vector3(0.48, 0.06, 0.62),
		_mats["dark"])
	_cyl(Vector3(-7.55, 1.02, 0.55), 0.025, 0.22, _mats["brass"])
	# Chulha with chimney.
	_deco(Vector3(-7.30, 0.36, -1.55), Vector3(0.95, 0.72, 0.82),
		_mats["clay"])
	_deco(Vector3(-7.30, 0.74, -1.55), Vector3(0.86, 0.08, 0.72),
		_mats["soot"])
	_deco(Vector3(-7.30, 0.78, -1.55), Vector3(0.42, 0.04, 0.32),
		_mats["dark"])
	_cyl(Vector3(-7.62, 2.05, -1.55), 0.16, 2.70, _mats["soot"])
	_pot(Vector3(-7.30, 0.80, -1.55), 0.24, 0.26, _mats["copper"])
	# Shelf of pots on the north wall.
	_deco(Vector3(-5.20, 1.55, -1.86), Vector3(2.35, 0.06, 0.28),
		_mats["wood"])
	for i in 4:
		_pot(Vector3(-6.10 + float(i) * 0.58, 1.58, -1.86),
			0.12 + 0.02 * float(i % 2), 0.20 + 0.04 * float(i % 3))
	# Hanging utensils.
	for i in 4:
		_cyl(Vector3(-6.30 + float(i) * 0.42, 2.10, 1.86), 0.11, 0.04,
			_mats["iron"])
		_deco(Vector3(-6.30 + float(i) * 0.42, 2.22, 1.87),
			Vector3(0.02, 0.22, 0.02), _mats["iron"])
	# Grain sacks and water pots in the corner.
	for i in 2:
		var sack := _sphere(Vector3(-3.65 + float(i) * 0.55, 0.28, 1.35),
			0.26, _mats["cloth_cream"])
		sack.scale = Vector3(0.85, 1.15, 0.85)
		_deco(Vector3(-3.65 + float(i) * 0.55, 0.54, 1.35),
			Vector3(0.20, 0.06, 0.20), _mats["soil"])
	_pot(Vector3(-3.55, 0.0, -1.55), 0.28, 0.50, _mats["clay"])
	_pot(Vector3(-4.15, 0.0, -1.50), 0.20, 0.38, _mats["clay"])
	_window(Vector3(-7.96, 2.25, 0.55), 90.0, 0.90, 0.80)
	_lantern(Vector3(-5.35, 3.25, -0.20), 0.60, 0.90, 5.0)
	_rich_photo_frame(Vector3(-3.04, 2.22, -1.30), -90.0, 0.56, 0.72,
		"09_couple_ghost_civilian", "THE FAMILY", true, false)
	_sconce(Vector3(-3.14, 2.05, -0.72), 0.55, Vector3(-1.0, 0.0, 0.0))
	_garland(Vector3(-5.20, 2.72, -1.94), 1.2, 0.16)


# =========================================================================
#  RITUAL / OCCULT HELPERS
# =========================================================================
func _line_xz(a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var d := b - a
	var flat := Vector2(d.x, d.z)
	if flat.length() < 0.001:
		return
	var mi := _deco((a + b) * 0.5, Vector3(flat.length(), 0.012, width), mat)
	mi.rotation_degrees.y = -rad_to_deg(atan2(d.z, d.x))


func _floor_sigil(center: Vector3, radius: float) -> void:
	var red: Material = _mats["sigil"]
	_torus(center, radius - 0.055, radius, red)
	_torus(center, radius * 0.34 - 0.035, radius * 0.34, red)
	for i in 5:
		var a0 := -PI * 0.5 + TAU * float(i) / 5.0
		var a1 := -PI * 0.5 + TAU * float((i + 2) % 5) / 5.0
		var p0 := center + Vector3(cos(a0) * radius * 0.92, 0.0,
			sin(a0) * radius * 0.92)
		var p1 := center + Vector3(cos(a1) * radius * 0.92, 0.0,
			sin(a1) * radius * 0.92)
		_line_xz(p0, p1, 0.035, red)


func _wall_sigil(pos: Vector3, radius: float) -> void:
	var red: Material = _mats["sigil"]
	var ring := _torus(pos, radius - 0.045, radius, red)
	ring.rotation_degrees.x = 90.0
	for i in 5:
		var a0 := -PI * 0.5 + TAU * float(i) / 5.0
		var a1 := -PI * 0.5 + TAU * float((i + 2) % 5) / 5.0
		var p0 := pos + Vector3(cos(a0) * radius * 0.92,
			sin(a0) * radius * 0.92, 0.0)
		var p1 := pos + Vector3(cos(a1) * radius * 0.92,
			sin(a1) * radius * 0.92, 0.0)
		var d := p1 - p0
		var bar := _deco((p0 + p1) * 0.5,
			Vector3(Vector2(d.x, d.y).length(), 0.03, 0.03), red)
		bar.rotation_degrees.z = rad_to_deg(atan2(d.y, d.x))


func _bell(top: Vector3, drop: float, scale := 1.0) -> void:
	var brass: Material = _mats["brass"]
	_cyl(top + Vector3(0.0, -drop * 0.5, 0.0), 0.010, drop, _mats["iron"])
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035 * scale
	mesh.bottom_radius = 0.115 * scale
	mesh.height = 0.20 * scale
	mi.mesh = mesh
	mi.material_override = brass
	mi.position = top + Vector3(0.0, -drop - 0.10 * scale, 0.0)
	add_child(mi)
	_sphere(top + Vector3(0.0, -drop - 0.22 * scale, 0.0),
		0.028 * scale, _mats["iron"])


func _puja_lamp(top: Vector3, drop: float) -> void:
	var brass: Material = _mats["brass"]
	_cyl(top + Vector3(0.0, -drop * 0.55, 0.0), 0.012, drop * 1.1, brass)
	var tiers := [0.30, 0.21, 0.13]
	for i in 3:
		var y := top.y - drop + float(i) * 0.16
		_cyl(Vector3(top.x, y, top.z), float(tiers[i]), 0.025, brass)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var p := Vector3(top.x + cos(a) * 0.26, top.y - drop + 0.03,
			top.z + sin(a) * 0.26)
		_sphere(p, 0.028, _mats["flame"])
	_lamp_light(Vector3(top.x, top.y - drop - 0.10, top.z), 1.35,
		Color(1.0, 0.66, 0.30), 7.5)


func _cage(top: Vector3, drop: float) -> void:
	var iron: Material = _mats["iron"]
	_cyl(top + Vector3(0.0, -drop * 0.5, 0.0), 0.014, drop, iron)
	var cy := top.y - drop - 0.45
	for i in 8:
		var a := TAU * float(i) / 8.0
		_deco(Vector3(top.x + cos(a) * 0.28, cy, top.z + sin(a) * 0.28),
			Vector3(0.022, 0.9, 0.022), iron)
	for ty in [cy + 0.45, cy - 0.45]:
		var ring := _torus(Vector3(top.x, ty, top.z), 0.24, 0.28, iron)
		ring.scale = Vector3(1.0, 1.0, 1.0)
	_skull(Vector3(top.x, cy - 0.44, top.z), 0.9)


func _jar(pos: Vector3, scale := 1.0) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.22, 0.30, 0.26)
	glass.metallic = 0.25
	glass.roughness = 0.12
	_cyl(pos + Vector3(0.0, 0.14 * scale, 0.0), 0.10 * scale,
		0.28 * scale, glass)
	_cyl(pos + Vector3(0.0, 0.05 * scale, 0.0), 0.07 * scale,
		0.10 * scale, _mats["blood"])
	_sphere(pos + Vector3(0.0, 0.21 * scale, 0.0), 0.045 * scale,
		_mats["bone"])


func _doll(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var cloth := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.035
	cone.bottom_radius = 0.15
	cone.height = 0.32
	cloth.mesh = cone
	cloth.material_override = _mats["cloth_red"]
	cloth.position = Vector3(0.0, 0.16, 0.0)
	n.add_child(cloth)
	_sphere(Vector3(0.0, 0.38, 0.0), 0.095, _mats["bone"], n)
	var hair := _sphere(Vector3(0.0, 0.41, -0.02), 0.10, _mats["dark"], n)
	hair.scale = Vector3(1.0, 0.9, 0.9)
	for ex in [-0.035, 0.035]:
		_sphere(Vector3(ex, 0.39, 0.085), 0.012, _mats["dark"], n)
	for s in [-1.0, 1.0]:
		var arm := _cyl(Vector3(s * 0.09, 0.24, 0.0), 0.018, 0.16,
			_mats["cloth_red"], n)
		arm.rotation_degrees.z = s * 38.0


func _chain_wall(pos: Vector3) -> void:
	var iron: Material = _mats["iron"]
	for i in 5:
		var link := _torus(pos + Vector3(0.0, -float(i) * 0.16, 0.0),
			0.055, 0.08, iron)
		link.rotation_degrees.y = 90.0 if i % 2 == 0 else 0.0
	_deco(pos + Vector3(0.0, 0.02, 0.0), Vector3(0.12, 0.05, 0.12), iron)


# =========================================================================
#  ROOMS  -  ground floor, back of house
# =========================================================================
func _build_bedroom_ground() -> void:
	_bed(Vector3(6.75, 0.0, 4.55), -90.0, 1.65, 2.05)
	_doll(Vector3(6.25, 0.58, 4.15))
	_cupboard(Vector3(3.95, 0.0, 6.62), 180.0, 1.30, 2.05, 0.55)
	_table(Vector3(6.45, 0.0, 6.22), Vector2(1.05, 0.42), 0.76)
	_mirror(Vector3(6.45, 1.72, 6.87), 180.0, 0.85, 0.95)
	_table(Vector3(7.45, 0.0, 3.05), Vector2(0.48, 0.48), 0.56)
	_diya(Vector3(7.45, 0.60, 3.05), 1.0)
	_trunk(Vector3(4.15, 0.0, 3.05), 0.0)
	_window(Vector3(7.96, 2.18, 2.80), -90.0, 0.95, 1.05)
	_rich_photo_frame(Vector3(5.45, 2.08, 2.06), 0.0, 0.54, 0.68,
		"06_girl_ghost_haunting", "THE ELDEST DAUGHTER", true, false)
	_rich_photo_frame(Vector3(6.55, 2.08, 2.06), 0.0, 0.54, 0.68,
		"07_girl_ghost_closeup", "SHE NEVER BLINKED", true, false)
	_sconce(Vector3(3.14, 2.00, 3.35), 0.55, Vector3(1.0, 0.0, 0.0))
	_lantern(Vector3(5.50, 3.28, 4.45), 0.62, 0.85, 5.2)
	_rug(Vector3(5.30, 0.02, 4.55), Vector2(2.6, 2.8),
		_mats["rug"], _mats["rug_inner"])
	# A child's height marks scratched into the door frame.
	for i in 5:
		_deco(Vector3(3.12, 0.45 + float(i) * 0.22, 5.30),
			Vector3(0.02, 0.015, 0.10 + float(i) * 0.03), _mats["soot"])


func _build_back_hall() -> void:
	_cupboard(Vector3(-2.57, 0.0, 0.95), 90.0, 1.10, 2.15, 0.54)
	# Niche for the house deity on the solid stretch beside the corridor.
	_deco(Vector3(1.42, 1.72, -1.86), Vector3(0.62, 0.78, 0.22),
		_mats["wood_dark"])
	_deco(Vector3(1.42, 1.36, -1.78), Vector3(0.52, 0.06, 0.22),
		_mats["wood"])
	_idol(Vector3(1.42, 1.40, -1.80), 0.38)
	_diya(Vector3(1.64, 1.42, -1.76), 0.8)
	_table(Vector3(2.42, 0.0, -1.62), Vector2(0.90, 0.42), 0.82)
	_mirror(Vector3(2.42, 1.72, -1.88), 0.0, 0.62, 0.78)
	_pot(Vector3(2.80, 0.86, -1.60), 0.10, 0.18, _mats["brass"])
	_lantern(Vector3(0.0, 3.30, 0.10), 0.55, 0.95, 5.5)
	_sconce(Vector3(-2.86, 2.10, -1.25), 0.55, Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(-1.95, 2.10, -1.86), 0.50)
	_rug(Vector3(0.0, 0.02, -0.85), Vector2(1.7, 2.2),
		_mats["rug_inner"], _mats["rug"])


func _build_corridor() -> void:
	_rug(Vector3(0.0, 0.02, -4.35), Vector2(0.85, 4.5),
		_mats["rug"], _mats["rug_inner"])
	# A procession of the dead down the narrow passage.
	_rich_photo_frame(Vector3(-0.90, 1.92, -5.25), 90.0, 0.50, 0.62,
		"10_girl_ghost_weeping", "THE WEEPING GIRL", true, true)
	_rich_photo_frame(Vector3(0.90, 2.02, -2.55), -90.0, 0.50, 0.62,
		"08_girl_ghost_angry", "THE ANGRY ONE", true, true)
	_rich_photo_frame(Vector3(0.90, 2.02, -6.15), -90.0, 0.50, 0.62,
		"02_royal_couple_vibrant", "THE VIBRANT COURT", true, true)
	_sconce(Vector3(-0.86, 2.10, -3.10), 0.50, Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(0.86, 2.10, -5.30), 0.45, Vector3(-1.0, 0.0, 0.0))
	# Dead-end niche.
	_deco(Vector3(0.0, 1.55, -6.86), Vector3(0.95, 1.30, 0.10),
		_mats["wood_dark"])
	_deco(Vector3(0.0, 0.98, -6.70), Vector3(0.78, 0.06, 0.24),
		_mats["wood"])
	_diya(Vector3(0.0, 1.01, -6.70), 1.1)
	_deco(Vector3(0.0, 1.55, -6.80), Vector3(0.55, 0.85, 0.02),
		_mats["soot"])
	_garland(Vector3(0.0, 2.32, -6.68), 0.85, 0.18)
	# A chair that has been dragged into the dead end.
	_chair(Vector3(0.52, 0.0, -6.05), 160.0)
	_doll(Vector3(0.52, 0.46, -6.05))


func _build_stair_hall() -> void:
	_table(Vector3(4.20, 0.0, -1.67), Vector2(1.20, 0.42), 0.84)
	_mirror(Vector3(4.20, 1.72, -1.88), 0.0, 0.78, 0.98)
	_candle(Vector3(3.78, 0.88, -1.67), 0.20)
	_candle(Vector3(4.62, 0.88, -1.67), 0.16)
	_cupboard(Vector3(4.10, 0.0, 1.60), 180.0, 1.00, 1.90, 0.50)
	_sconce(Vector3(5.35, 2.00, 1.86), 0.50, Vector3(0.0, 0.0, -1.0))
	_lantern(Vector3(4.55, 3.28, 0.15), 0.72, 0.90, 5.2)
	# Under-stair nook.
	_deco(Vector3(7.72, 0.45, 1.64), Vector3(0.42, 0.06, 0.42),
		_mats["wood"])
	for lx in [-0.16, 0.16]:
		for lz in [-0.16, 0.16]:
			_deco(Vector3(7.72 + lx, 0.22, 1.64 + lz),
				Vector3(0.04, 0.44, 0.04), _mats["wood_dark"])
	_doll(Vector3(7.72, 0.48, 1.64))
	_garland(Vector3(4.55, 3.10, 0.15), 1.0, 0.14)


func _build_pooja() -> void:
	var marble: Material = _mats["marble"]
	var brass: Material = _mats["brass"]
	var wd: Material = _mats["wood_dark"]

	# Carved backdrop and arch.
	_deco(Vector3(4.50, 1.58, -6.87), Vector3(4.30, 3.10, 0.10), wd)
	for x in [2.50, 6.50]:
		_deco(Vector3(x, 1.58, -6.78), Vector3(0.20, 3.10, 0.20),
			_mats["wood_light"])
	_deco(Vector3(4.50, 3.10, -6.78), Vector3(4.20, 0.18, 0.22),
		_mats["wood_light"])
	_deco(Vector3(4.50, 2.92, -6.70), Vector3(3.90, 0.08, 0.10), brass)

	# Marble altar and steps.
	_solid(Vector3(4.50, 0.18, -6.35), Vector3(3.60, 0.36, 1.20), marble)
	_solid(Vector3(4.50, 0.09, -5.60), Vector3(3.80, 0.18, 0.34), marble)
	_solid(Vector3(4.50, 0.045, -5.38), Vector3(4.00, 0.09, 0.26), marble)
	_deco(Vector3(4.50, 0.365, -6.35), Vector3(3.40, 0.03, 1.05),
		_mats["cloth_red"])

	# Deities.
	_idol(Vector3(3.45, 0.38, -6.30), 1.15)
	_idol(Vector3(4.50, 0.38, -6.32), 1.30, _mats["dark"])
	_idol(Vector3(5.55, 0.38, -6.30), 1.15)
	_garland(Vector3(4.50, 2.58, -6.72), 3.60, 0.42)
	_garland(Vector3(3.45, 1.52, -6.14), 0.75, 0.16)
	_garland(Vector3(5.55, 1.52, -6.14), 0.75, 0.16)

	# Offerings.
	_diya(Vector3(3.05, 0.40, -5.95), 1.4)
	_diya(Vector3(4.50, 0.40, -5.92), 1.6)
	_diya(Vector3(5.95, 0.40, -5.95), 1.4)
	_pot(Vector3(2.92, 0.38, -6.60), 0.17, 0.32, brass)
	_sphere(Vector3(2.92, 0.75, -6.60), 0.10, _mats["green"])
	_pot(Vector3(6.08, 0.38, -6.60), 0.17, 0.32, brass)
	_sphere(Vector3(6.08, 0.75, -6.60), 0.10, _mats["green"])
	# Incense stand.
	_cyl(Vector3(2.55, 0.24, -5.15), 0.13, 0.48, brass)
	_deco(Vector3(2.55, 0.52, -5.15), Vector3(0.30, 0.04, 0.30), brass)
	for i in 3:
		_cyl(Vector3(2.46 + float(i) * 0.09, 0.72, -5.15),
			0.006, 0.38, _mats["wood"])
		_sphere(Vector3(2.46 + float(i) * 0.09, 0.92, -5.15),
			0.010, _mats["flame"])
	# Brass bells.
	_bell(Vector3(2.78, 3.34, -5.45), 0.58, 1.0)
	_bell(Vector3(6.22, 3.34, -5.45), 0.58, 1.0)
	_bell(Vector3(4.50, 3.34, -4.10), 0.50, 0.85)
	_puja_lamp(Vector3(4.50, 3.34, -4.55), 0.90)

	# Prayer mats and rangoli.
	for x in [3.85, 5.15]:
		_deco(Vector3(x, 0.03, -4.55), Vector3(0.72, 0.05, 1.05),
			_mats["cloth_cream"])
		_deco(Vector3(x, 0.06, -4.55), Vector3(0.62, 0.02, 0.95),
			_mats["cloth_red"])
	var rangoli := _torus(Vector3(4.50, 0.035, -3.45), 0.46, 0.56,
		_mats["marigold"])
	rangoli.scale = Vector3(1.0, 1.0, 1.0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var petal := _sphere(Vector3(4.50 + cos(a) * 0.34, 0.045,
			-3.45 + sin(a) * 0.34), 0.075, _mats["marigold2"])
		petal.scale = Vector3(1.0, 0.25, 1.0)
	# Side cupboard with brass ware.
	_cupboard(Vector3(7.52, 0.0, -5.55), -90.0, 1.20, 1.80, 0.44,
		_mats["wood"])
	_pot(Vector3(7.55, 1.82, -5.90), 0.09, 0.16, brass)
	_pot(Vector3(7.55, 1.82, -5.55), 0.07, 0.13, brass)
	_window(Vector3(7.96, 2.55, -3.10), -90.0, 0.55, 0.55, false)
	_sconce(Vector3(1.14, 2.20, -6.20), 0.55, Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(1.14, 2.20, -2.75), 0.50, Vector3(1.0, 0.0, 0.0))
	_garland(Vector3(1.12, 2.62, -4.10), 1.0, 0.18, 90.0)


func _build_tantra() -> void:
	var dark: Material = _mats["dark"]
	var soot: Material = _mats["soot"]
	var red: Material = _mats["cloth_red"]
	var iron: Material = _mats["iron"]

	# Drapes and painted wall sigil.
	for i in 3:
		_deco(Vector3(-5.80 + float(i) * 1.30, 1.45, -6.82),
			Vector3(0.95, 2.90, 0.06), red)
	_deco(Vector3(-4.50, 3.02, -6.80), Vector3(3.90, 0.16, 0.14), dark)
	# The black magician watches over the altar. This is the big feature
	# portrait of the room: Nishanth as the man who mastered the craft.
	_rich_photo_frame(Vector3(-4.50, 2.14, -6.79), 0.0, 0.88, 1.575,
		"black_magician", "THE BLACK MAGICIAN", true, true)
	# Nishanth's framed photograph on the side of the ritual wall.
	_memorial_portrait(Vector3(-6.85, 2.30, -6.66), 0.84, 1.4933)
	_rich_photo_frame(Vector3(-1.04, 2.20, -6.45), -90.0, 0.56, 0.72,
		"03_king_ghost_solo", "THE KING WHO STAYED", true, false)
	for i in 6:
		var hp := _sphere(Vector3(-5.90 + float(i) * 0.55, 1.55 +
			sin(float(i) * 2.1) * 0.35, -6.72), 0.11, _mats["blood"])
		hp.scale = Vector3(0.75, 1.1, 0.18)
	for i in 4:
		var smear := _deco(Vector3(-5.60 + float(i) * 0.72, 1.05,
			-6.73), Vector3(0.05, 0.55 + float(i % 2) * 0.25, 0.02), _mats["blood"])
		smear.rotation_degrees.z = -12.0 + float(i) * 8.0

	# Black altar.
	_solid(Vector3(-4.50, 0.42, -6.20), Vector3(3.00, 0.84, 1.05), soot)
	_deco(Vector3(-4.50, 0.85, -6.20), Vector3(3.10, 0.04, 1.12), _mats["tantra"])
	_deco(Vector3(-4.50, 0.84, -6.20), Vector3(2.90, 0.03, 0.95), red)
	for x in [-5.45, -4.98, -4.05, -3.58]:
		_skull(Vector3(x, 0.87, -6.12), 1.0)
	_candle(Vector3(-5.85, 0.87, -6.30), 0.32)
	_candle(Vector3(-3.15, 0.87, -6.30), 0.26)
	# Grimoire.
	var book := Node3D.new()
	book.position = Vector3(-4.50, 0.90, -6.35)
	book.rotation_degrees.y = 18.0
	add_child(book)
	_deco(Vector3(0.0, 0.035, 0.0), Vector3(0.42, 0.07, 0.30),
		_mats["tantra"], book)
	_deco(Vector3(0.0, 0.075, 0.0), Vector3(0.38, 0.02, 0.26),
		_mats["cloth_cream"], book)
	# Athame.
	_deco(Vector3(-2.95, 0.92, -6.05), Vector3(0.42, 0.02, 0.045),
		_mats["iron"])
	_deco(Vector3(-2.70, 0.92, -6.05), Vector3(0.16, 0.035, 0.07),
		_mats["bone"])

	# Floor sigil and candle ring.
	_floor_sigil(Vector3(-4.50, 0.035, -4.55), 1.50)
	for i in 8:
		var a := PI * 0.125 + TAU * float(i) / 8.0
		var p := Vector3(-4.50 + cos(a) * 1.78, 0.0,
			-4.55 + sin(a) * 1.78)
		_cyl(p + Vector3(0.0, 0.10, 0.0), 0.032, 0.20,
			_mats["cloth_cream"])
		_sphere(p + Vector3(0.0, 0.23, 0.0), 0.026, _mats["flame"])

	# Cauldron.
	_cyl(Vector3(-2.15, 0.26, -5.25), 0.34, 0.52, iron)
	_torus(Vector3(-2.15, 0.52, -5.25), 0.30, 0.38, iron)
	var brew := _cyl(Vector3(-2.15, 0.54, -5.25), 0.29, 0.03,
		_emissive(Color(0.18, 0.85, 0.28), 1.4))
	brew.material_override = _emissive(Color(0.18, 0.85, 0.28), 1.4)
	for i in 3:
		var a2 := TAU * float(i) / 3.0
		_sphere(Vector3(-2.15 + cos(a2) * 0.46, 0.03,
			-5.25 + sin(a2) * 0.46), 0.085, _mats["flame"])
	_lamp_light(Vector3(-2.15, 0.80, -5.25), 0.55,
		Color(0.35, 0.95, 0.45), 3.5)

	# Hanging cage and chains.
	_cage(Vector3(-6.55, 3.34, -4.55), 1.05)
	_chain_wall(Vector3(-1.15, 2.45, -6.10))
	_chain_wall(Vector3(-7.86, 2.35, -3.10))
	_chain_wall(Vector3(-7.86, 1.90, -2.55))

	# Shelf of jars.
	_deco(Vector3(-7.72, 1.18, -4.70), Vector3(0.36, 0.06, 2.20),
		_mats["wood_dark"])
	_deco(Vector3(-7.72, 1.74, -4.70), Vector3(0.36, 0.06, 2.20),
		_mats["wood_dark"])
	for i in 4:
		_jar(Vector3(-7.70, 1.21, -5.55 + float(i) * 0.55), 1.0)
	for i in 3:
		_jar(Vector3(-7.70, 1.77, -5.30 + float(i) * 0.55), 0.8)
	# Bone pile.
	for i in 6:
		var a3 := TAU * float(i) / 6.0
		var bone := _cyl(Vector3(-6.65 + cos(a3) * 0.35, 0.05,
			-2.85 + sin(a3) * 0.30), 0.025, 0.55, _mats["bone"])
		bone.rotation_degrees.z = 90.0
		bone.rotation_degrees.y = rad_to_deg(a3)
	_skull(Vector3(-6.65, 0.03, -2.85), 1.2)
	_doll(Vector3(-2.30, 0.0, -2.35))
	_lamp_light(Vector3(-4.50, 2.15, -4.80), 1.15,
		Color(0.88, 0.10, 0.05), 8.0)
	_sconce(Vector3(-1.14, 2.10, -2.55), 0.40, Vector3(-1.0, 0.0, 0.0))


# =========================================================================
#  FURNITURE  -  upper floor and courtyard
# =========================================================================
func _bench(pos: Vector3, yaw: float, length: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var m: Material = _mats["wood"]
	_deco(Vector3(0.0, 0.46, 0.0), Vector3(0.52, 0.08, length), m, n)
	for sy in [0.62, 0.82, 1.02]:
		_deco(Vector3(0.0, sy, -0.24), Vector3(0.50, 0.14, 0.05), m, n)
	for lx in [-0.21, 0.21]:
		for lz in [-length * 0.5 + 0.10, length * 0.5 - 0.10]:
			_deco(Vector3(lx, 0.23, lz), Vector3(0.06, 0.46, 0.06), m, n)
	_blocker(pos + Vector3(0.0, 0.45, 0.0), Vector3(0.56, 0.9, length), yaw)


func _canopy(pos: Vector3, yaw: float, w: float, l: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var m: Material = _mats["wood_dark"]
	var cloth: Material = _mats["cloth_cream"]
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_deco(Vector3(sx * w * 0.5, 1.28, sz * l * 0.5),
				Vector3(0.08, 2.56, 0.08), m, n)
			_sphere(Vector3(sx * w * 0.5, 2.60, sz * l * 0.5), 0.07,
				_mats["brass"], n)
	for sz in [-1.0, 1.0]:
		_deco(Vector3(0.0, 2.56, sz * l * 0.5),
			Vector3(w + 0.10, 0.08, 0.08), m, n)
	for sx in [-1.0, 1.0]:
		_deco(Vector3(sx * w * 0.5, 2.56, 0.0),
			Vector3(0.08, 0.08, l + 0.10), m, n)
	# Dust sheets hanging at the head of the bed.
	for sx in [-1.0, 1.0]:
		_deco(Vector3(sx * (w * 0.5 - 0.14), 1.55, -l * 0.5 + 0.14),
			Vector3(0.34, 1.95, 0.03), cloth, n)
	_deco(Vector3(0.0, 2.20, -l * 0.5 + 0.10),
		Vector3(w * 0.55, 0.55, 0.03), cloth, n)


func _crib(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var m: Material = _mats["wood"]
	_deco(Vector3(0.0, 0.26, 0.0), Vector3(0.92, 0.14, 0.58), m, n)
	_deco(Vector3(0.0, 0.36, 0.0), Vector3(0.82, 0.10, 0.48),
		_mats["cloth_cream"], n)
	for sz in [-1.0, 1.0]:
		_deco(Vector3(0.0, 0.54, sz * 0.30), Vector3(0.96, 0.10, 0.05), m, n)
		_deco(Vector3(0.0, 0.76, sz * 0.30), Vector3(0.96, 0.07, 0.05), m, n)
		for i in 5:
			_deco(Vector3(-0.38 + float(i) * 0.19, 0.60, sz * 0.30),
				Vector3(0.035, 0.42, 0.035), m, n)
	for sx in [-1.0, 1.0]:
		_deco(Vector3(sx * 0.46, 0.54, 0.0), Vector3(0.05, 0.10, 0.58), m, n)
		for i in 3:
			_deco(Vector3(sx * 0.46, 0.58, -0.20 + float(i) * 0.20),
				Vector3(0.035, 0.38, 0.035), m, n)
	_deco(Vector3(0.0, 0.10, -0.20), Vector3(0.06, 0.18, 0.05), m, n)
	_deco(Vector3(0.0, 0.10, 0.20), Vector3(0.06, 0.18, 0.05), m, n)
	_doll(Vector3(0.0, 0.41, 0.0))
	_blocker(pos + Vector3(0.0, 0.4, 0.0), Vector3(0.98, 0.8, 0.66), yaw)


func _charpai(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var m: Material = _mats["wood"]
	_deco(Vector3(0.0, 0.45, 0.0), Vector3(1.90, 0.10, 0.95), m, n)
	for lx in [-0.82, 0.82]:
		for lz in [-0.36, 0.36]:
			_deco(Vector3(lx, 0.22, lz), Vector3(0.07, 0.44, 0.07), m, n)
	var rope: Material = _mats["cloth_cream"]
	for i in 9:
		_deco(Vector3(-0.80 + float(i) * 0.20, 0.51, 0.0),
			Vector3(0.018, 0.015, 0.93), rope, n)
	for i in 5:
		_deco(Vector3(0.0, 0.515, -0.38 + float(i) * 0.19),
			Vector3(1.85, 0.015, 0.018), rope, n)
	var bolster := _cyl(Vector3(-0.72, 0.58, 0.0), 0.11, 0.82,
		_mats["cloth_red"], n)
	bolster.rotation_degrees.x = 90.0
	_blocker(pos + Vector3(0.0, 0.3, 0.0), Vector3(1.95, 0.6, 1.0), yaw)


func _well(pos: Vector3) -> void:
	var stone: Material = _mats["stone_b"]
	var dark: Material = _mats["wood_dark"]
	_cyl(pos + Vector3(0.0, 0.45, 0.0), 1.05, 0.90, stone)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var block := _deco(pos + Vector3(cos(a) * 0.98, 0.94, sin(a) * 0.98),
			Vector3(0.42, 0.14, 0.30), _mats["stone_a"])
		block.rotation_degrees.y = rad_to_deg(-a)
	_cyl(pos + Vector3(0.0, 0.87, 0.0), 0.76, 0.04, _mats["dark"])
	for sx in [-1.0, 1.0]:
		_deco(pos + Vector3(sx * 1.02, 1.72, 0.0),
			Vector3(0.16, 1.70, 0.16), dark)
	_deco(pos + Vector3(0.0, 2.56, 0.0), Vector3(2.35, 0.14, 0.18), dark)
	for sx in [-1.0, 1.0]:
		var roof := _deco(pos + Vector3(sx * 0.56, 2.76, 0.0),
			Vector3(1.25, 0.07, 1.30), _mats["wood"])
		roof.rotation_degrees.z = sx * 24.0
	_cyl(pos + Vector3(0.0, 1.95, 0.0), 0.014, 1.15, _mats["iron"])
	_cyl(pos + Vector3(0.0, 1.20, 0.0), 0.15, 0.24, _mats["wood"])
	_torus(pos + Vector3(0.0, 1.33, 0.0), 0.10, 0.16, _mats["iron"])
	_blocker(pos + Vector3(0.0, 0.45, 0.0), Vector3(2.2, 0.9, 2.2))


func _dead_tree(pos: Vector3) -> void:
	var wood: Material = _mats["wood_dark"]
	var trunk := _cyl(pos + Vector3(0.0, 1.70, 0.0), 0.30, 3.40, wood)
	trunk.rotation_degrees.z = -4.0
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var root := _cyl(pos + Vector3(cos(a) * 0.35, 0.16, sin(a) * 0.35),
			0.09, 0.70, wood)
		root.rotation_degrees.z = 72.0
		root.rotation_degrees.y = rad_to_deg(a)
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.7
		var base := pos + Vector3(0.0, 2.05 + float(i % 3) * 0.42, 0.0)
		var tilt := 0.80 + float(i % 2) * 0.18
		var dir := Vector3(sin(tilt) * cos(a), cos(tilt), sin(tilt) * sin(a))
		var length := 1.45 + float(i % 3) * 0.35
		var branch := _cyl(base + dir * length * 0.5, 0.075, length, wood)
		branch.quaternion = Quaternion(Vector3.UP, dir)
		var tip := base + dir * length
		var dir2 := Vector3(cos(a + 0.8), 0.55, sin(a + 0.8)).normalized()
		var twig := _cyl(tip + dir2 * 0.45, 0.035, 0.95, wood)
		twig.quaternion = Quaternion(Vector3.UP, dir2)
	_crow(pos + Vector3(1.20, 2.95, 1.05))
	_crow(pos + Vector3(-0.85, 3.28, 0.62))
	_crow(pos + Vector3(0.20, 2.55, -1.15))


func _crow(pos: Vector3) -> void:
	var body := _sphere(pos + Vector3(0.0, 0.10, 0.0), 0.12,
		_mats["dark"])
	body.scale = Vector3(1.0, 0.9, 1.55)
	_sphere(pos + Vector3(0.0, 0.17, 0.17), 0.065, _mats["dark"])
	_deco(pos + Vector3(0.0, 0.16, 0.26), Vector3(0.035, 0.025, 0.09),
		_mats["bone"])
	_deco(pos + Vector3(0.0, 0.08, -0.20), Vector3(0.035, 0.02, 0.18),
		_mats["dark"])


func _clothesline(pos: Vector3) -> void:
	var wood: Material = _mats["wood_dark"]
	for sx in [-1.0, 1.0]:
		_cyl(pos + Vector3(sx * 3.10, 1.10, 0.0), 0.055, 2.20, wood)
		_deco(pos + Vector3(sx * 3.10, 0.04, 0.0),
			Vector3(0.35, 0.08, 0.35), _mats["stone_a"])
	var line := _cyl(pos + Vector3(0.0, 2.14, 0.0), 0.010, 6.25,
		_mats["cloth_cream"])
	line.rotation_degrees.z = 90.0
	var cloths := [
		Vector3(-1.90, 1.38, 0.0),
		Vector3(0.00, 1.30, 0.0),
		Vector3(1.90, 1.42, 0.0),
	]
	for i in 3:
		var c: Vector3 = cloths[i]
		_deco(pos + c, Vector3(1.05, 1.55, 0.025),
			_mats["cloth_cream"] if i != 1 else _mats["cloth_red"])
		_deco(pos + c + Vector3(0.0, 0.72, 0.0), Vector3(0.07, 0.05, 0.05),
			_mats["wood"])


func _cart_wheel(pos: Vector3) -> void:
	var wheel := _torus(pos, 0.56, 0.66, _mats["wood_dark"])
	wheel.rotation_degrees.y = 90.0
	for i in 8:
		var spoke := _deco(pos, Vector3(0.035, 1.18, 0.035),
			_mats["wood"])
		spoke.rotation_degrees.x = float(i) * 22.5
	var hub := _cyl(pos, 0.10, 0.22, _mats["iron"])
	hub.rotation_degrees.z = 90.0


func _yard_lamp(pos: Vector3) -> void:
	var iron: Material = _mats["iron"]
	_cyl(pos + Vector3(0.0, 1.30, 0.0), 0.055, 2.60, iron)
	_deco(pos + Vector3(0.38, 2.56, 0.0), Vector3(0.80, 0.05, 0.05), iron)
	_deco(pos + Vector3(0.0, 0.05, 0.0), Vector3(0.28, 0.10, 0.28),
		_mats["stone_a"])
	_lantern(pos + Vector3(0.72, 2.52, 0.0), 0.34, 0.85, 6.0)
	_blocker(pos + Vector3(0.0, 1.3, 0.0), Vector3(0.18, 2.6, 0.18))


func _build_upper_gallery() -> void:
	_rug(Vector3(1.05, UPPER_Y + 0.02, -0.20), Vector2(7.7, 1.35),
		_mats["rug"], _mats["rug_inner"])
	_bench(Vector3(1.55, UPPER_Y, -3.52), 0.0, 1.90)
	_table(Vector3(-1.35, UPPER_Y, -3.62), Vector2(1.15, 0.40), 0.82)
	_mirror(Vector3(-1.35, UPPER_Y + 1.72, -3.88), 0.0, 0.72, 0.92)
	_candle(Vector3(-1.62, UPPER_Y + 0.86, -3.62), 0.18)
	_pot(Vector3(-1.05, UPPER_Y + 0.86, -3.62), 0.08, 0.15,
		_mats["brass"])
	_rich_photo_frame(Vector3(1.55, UPPER_Y + 1.92, -3.89), 0.0, 1.10, 0.62,
		"royal_couple_green", "THE ROYAL COURT", true, true)
	_window(Vector3(5.60, UPPER_Y + 1.85, -3.96), 0.0, 1.15, 1.10)
	_sconce(Vector3(-2.86, UPPER_Y + 1.85, -1.10), 0.55,
		Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(7.86, UPPER_Y + 1.85, -2.90), 0.50,
		Vector3(-1.0, 0.0, 0.0))
	_lantern(Vector3(-1.25, 6.56, -1.30), 1.90, 1.00, 7.5)
	_lantern(Vector3(4.30, 6.56, -0.60), 1.95, 0.95, 7.0)
	_doll(Vector3(1.95, UPPER_Y, 1.62))
	for i in 3:
		_deco(Vector3(3.10 + float(i) * 0.24, UPPER_Y + 0.06, 0.55),
			Vector3(0.16, 0.12, 0.16),
			_mats["cloth_red"] if i % 2 == 0 else _mats["wood_light"])


func _build_bedroom_upper() -> void:
	_bed(Vector3(6.55, UPPER_Y, 4.55), -90.0, 1.60, 2.05)
	_canopy(Vector3(6.55, UPPER_Y, 4.55), -90.0, 1.60, 2.05)
	_doll(Vector3(6.00, UPPER_Y + 0.58, 4.20))
	_crib(Vector3(7.10, UPPER_Y, 6.32), 0.0)
	_table(Vector3(4.95, UPPER_Y, 6.45), Vector2(1.00, 0.42), 0.80)
	_mirror(Vector3(4.95, UPPER_Y + 1.72, 6.87), 180.0, 0.78, 0.92)
	_candle(Vector3(4.62, UPPER_Y + 0.84, 6.45), 0.18)
	_cupboard(Vector3(3.40, UPPER_Y, 5.00), 90.0, 1.10, 1.95, 0.50)
	_window(Vector3(7.96, UPPER_Y + 1.95, 6.30), -90.0, 0.95, 1.10)
	_portrait(Vector3(6.30, UPPER_Y + 1.85, 2.11), 0.0, 0.62, 0.82)
	_sconce(Vector3(3.14, UPPER_Y + 1.85, 3.05), 0.55,
		Vector3(1.0, 0.0, 0.0))
	_lantern(Vector3(5.20, 6.50, 4.10), 1.70, 0.95, 6.0)
	_rug(Vector3(5.60, UPPER_Y + 0.02, 4.65), Vector2(2.6, 2.5),
		_mats["rug_inner"], _mats["rug"])
	for i in 3:
		_deco(Vector3(4.05 + float(i) * 0.20, UPPER_Y + 0.06, 5.90),
			Vector3(0.14, 0.12, 0.14), _mats["cloth_cream"])


func _build_exterior() -> void:
	var stone: Material = _mats["stone_b"]
	var dark: Material = _mats["wood_dark"]
	var plaster: Material = _mats["plaster"]
	var plaster_dark: Material = _mats["plaster_dark"]

	# Ground and path.
	_solid(Vector3(0.0, -0.25, 8.0), Vector3(70.0, 0.40, 70.0), _mats["soil"])
	_tile_floor(Rect2(-1.10, 9.80, 2.20, 5.80), _mats["stone_a"],
		_mats["stone_b"], 0.0, 0.75)

	# Veranda.
	_solid(Vector3(0.0, -0.02, 8.35), Vector3(9.20, 0.30, 2.70), stone)
	_solid(Vector3(0.0, 0.02, 9.86), Vector3(9.40, 0.16, 0.36), stone)
	_solid(Vector3(0.0, 3.46, 8.35), Vector3(9.40, 0.24, 2.90), dark)
	_deco(Vector3(0.0, 3.42, 9.80), Vector3(9.40, 0.18, 0.14), plaster)
	for sx in [-1.0, 1.0]:
		var col := _cyl(Vector3(sx * 4.10, 1.73, 9.45), 0.16, 3.20, stone)
		col.rotation_degrees.z = 0.0
		_deco(Vector3(sx * 4.10, 0.22, 9.45), Vector3(0.52, 0.20, 0.52),
			stone)
		_deco(Vector3(sx * 4.10, 3.36, 9.45), Vector3(0.44, 0.12, 0.44),
			stone)
		_blocker(Vector3(sx * 4.10, 1.73, 9.45), Vector3(0.40, 3.2, 0.40))
	_bench(Vector3(-3.20, 0.13, 7.92), 0.0, 1.70)
	_charpai(Vector3(3.05, 0.13, 8.35), 0.0)
	_tulsi(Vector3(-1.75, 0.13, 9.05))
	_lantern(Vector3(0.0, 3.34, 8.55), 0.55, 1.45, 7.2)
	_pot(Vector3(1.90, 0.13, 9.10), 0.20, 0.36, _mats["clay"])

	# Compound wall and gate.
	for sx in [-1.0, 1.0]:
		_wall_x(sx * 11.0, 7.0, 16.0, 0.0, 2.30, plaster_dark, 0.35)
		_deco(Vector3(sx * 11.0, 2.34, 11.5), Vector3(0.48, 0.10, 9.2),
			stone)
		_wall_z(16.0, sx * 1.85, sx * 11.0, 0.0, 2.30, plaster_dark, 0.35)
		_deco(Vector3(sx * 6.4, 2.34, 16.0), Vector3(9.2, 0.10, 0.46),
			stone)
	for sx in [-1.0, 1.0]:
		_deco(Vector3(sx * 1.88, 1.30, 16.0), Vector3(0.52, 2.60, 0.52),
			stone)
		_deco(Vector3(sx * 1.88, 2.66, 16.0), Vector3(0.66, 0.16, 0.66),
			stone)
		_sphere(Vector3(sx * 1.88, 2.82, 16.0), 0.16, _mats["brass"])
	for i in 11:
		var x := -1.50 + float(i) * 0.30
		_cyl(Vector3(x, 1.05, 16.0), 0.032, 1.95, _mats["iron"])
		_sphere(Vector3(x, 2.06, 16.0), 0.045, _mats["iron"])
	for y in [0.30, 1.05, 1.80]:
		_deco(Vector3(0.0, y, 16.0), Vector3(3.20, 0.07, 0.09),
			_mats["iron"])
	_torus(Vector3(0.0, 1.42, 16.0), 0.24, 0.30, _mats["iron"])
	_lantern(Vector3(2.18, 2.45, 15.72), 0.45, 0.85, 5.5)

	# Well, tree, clothesline, cart wheel.
	_well(Vector3(5.50, 0.0, 12.20))
	_dead_tree(Vector3(-6.40, 0.0, 11.60))
	_clothesline(Vector3(-7.00, 0.0, 14.25))
	_cart_wheel(Vector3(-10.35, 0.78, 10.20))
	_yard_lamp(Vector3(-9.10, 0.0, 13.05))
	for i in 3:
		_pot(Vector3(-9.20 + float(i) * 0.55, 0.0, 8.60),
			0.18 + 0.03 * float(i % 2), 0.34 + 0.04 * float(i % 3))

	# Front elevation: windows, awnings and stone bands.
	_window(Vector3(-6.45, 1.55, 7.14), 0.0, 1.00, 1.35, false)
	_window(Vector3(-4.70, 1.55, 7.14), 0.0, 1.00, 1.35, false)
	_chhajja(-6.45, 2.42, 7.14, 1.00)
	_chhajja(-4.70, 2.42, 7.14, 1.00)
	_window(Vector3(5.20, 1.55, 7.14), 0.0, 0.90, 1.30, false)
	_window(Vector3(6.80, 1.55, 7.14), 0.0, 0.90, 1.30, false)
	_chhajja(5.20, 2.38, 7.14, 0.90)
	_chhajja(6.80, 2.38, 7.14, 0.90)
	_window(Vector3(-2.45, 1.55, 7.14), 0.0, 0.65, 1.50, false)
	_window(Vector3(2.45, 1.55, 7.14), 0.0, 0.65, 1.50, true)
	_window(Vector3(-1.30, 5.15, 7.14), 0.0, 1.00, 1.35, true)
	_window(Vector3(1.30, 5.15, 7.14), 0.0, 1.00, 1.35, false)
	_window(Vector3(5.70, 5.15, 7.14), 0.0, 1.00, 1.35, false)
	_chhajja(-1.30, 6.00, 7.14, 1.00)
	_chhajja(1.30, 6.00, 7.14, 1.00)
	_chhajja(5.70, 6.00, 7.14, 1.00)
	_deco(Vector3(0.0, 3.50, 7.17), Vector3(16.10, 0.16, 0.16),
		plaster_dark)
	_deco(Vector3(0.0, 6.52, 7.17), Vector3(16.10, 0.12, 0.14),
		plaster_dark)
	for x in [-8.0, -3.0, 3.0, 8.0]:
		_deco(Vector3(x, 4.98, 7.17), Vector3(0.22, 3.05, 0.12),
			plaster_dark)
		_deco(Vector3(x, 1.72, 7.17), Vector3(0.22, 3.40, 0.12),
			plaster_dark)

	# Moon and stars.
	_sphere(Vector3(26.0, 42.0, -70.0), 3.4, _mats["moon_glow"])
	for i in 34:
		var az := TAU * float(i) * 0.618
		var el := deg_to_rad(14.0 + fmod(float(i) * 37.0, 58.0))
		var p := Vector3(cos(az) * cos(el) * 62.0, sin(el) * 62.0 + 10.0,
			sin(az) * cos(el) * 62.0)
		_sphere(p, 0.22 + 0.05 * float(i % 3), _mats["star"])


func _build_floor_signatures() -> void:
	# Only the two main places carry the maker's name: the approach to the
	# house and the living hall. The rest of the Haveli stays quiet.
	_floor_text("A GAME BY\nNISHANTH", Vector3(0.0, 0.055, 11.55),
		60, 0.0075, Color(0.80, 0.77, 0.66), 0.0)
	_floor_text("A GAME BY NISHANTH", Vector3(0.0, 0.055, 6.25),
		40, 0.0055, Color(0.48, 0.075, 0.055), 0.0)


func _floor_text(text: String, pos: Vector3, size: int, pixel: float,
		color: Color, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation_degrees.y = yaw
	add_child(pivot)
	var label := Label3D.new()
	label.text = text
	label.font = ThemeDB.fallback_font
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.shaded = false
	label.double_sided = true
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.rotation_degrees.x = -90.0
	pivot.add_child(label)


# =========================================================================
#  PLAYER / PREVIEW
# =========================================================================
func _spawn_player() -> void:
	_player = PLAYER.instantiate() as PlayerController
	_player.position = Vector3(0.0, 0.2, 6.0)
	match _angle:
		"living":
			_player.position = Vector3(0.70, 0.2, 6.35)
			_player.rotation_degrees.y = 55.0
		"corridor":
			_player.position = Vector3(0.0, 0.2, -2.45)
		"stairs":
			_player.position = Vector3(4.3, 0.2, 1.2)
			_player.rotation_degrees.y = -70.0
		"puja":
			_player.position = Vector3(4.5, 0.2, -2.9)
		"tantra":
			_player.position = Vector3(-4.5, 0.2, -2.9)
		"upper":
			_player.position = Vector3(0.8, UPPER_Y + 0.2, -0.9)
			_player.rotation_degrees.y = 180.0
		"upperbed":
			_player.position = Vector3(4.0, UPPER_Y + 0.2, 6.2)
			_player.rotation_degrees.y = -27.0
		"dining":
			_player.position = Vector3(-3.4, 0.2, 5.7)
			_player.rotation_degrees.y = 60.0
		"dininggore":
			_player.position = Vector3(-4.30, 0.2, 2.90)
			_player.rotation_degrees.y = 145.0
		"photos":
			_player.position = Vector3(-1.45, 0.2, 6.05)
			_player.rotation_degrees.y = -88.0
		"kitchen":
			_player.position = Vector3(-3.4, 0.2, 1.4)
			_player.rotation_degrees.y = 56.0
		"bedroom":
			_player.position = Vector3(3.4, 0.2, 4.7)
			_player.rotation_degrees.y = -90.0
		"doors":
			_player.position = Vector3(0.0, 0.2, 10.8)
			_player.rotation_degrees.y = 0.0
		"outside":
			_player.position = Vector3(-0.8, 0.2, 15.0)
			_player.rotation_degrees.y = -6.0
	if _angle == "doors":
		for d in _doors:
			if d.global_position.z > 6.5:
				d.is_open = false
	add_child(_player)
	var view := _player.get_node_or_null("HeadPivot/Camera3D/WeaponView") as Node3D
	if view != null:
		view.visible = false


func _dump_frame() -> void:
	var cam := _player.get_node_or_null("HeadPivot/Camera3D") as Camera3D
	if cam == null:
		return
	var hits: Array = []
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		if cam.is_position_behind(box.get_center()):
			continue
		if box.get_center().distance_to(cam.global_position) > 22.0:
			continue
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		var behind := false
		for i in 8:
			var corner := box.get_endpoint(i)
			if cam.is_position_behind(corner):
				behind = true
				break
			var sp := cam.unproject_position(corner)
			lo = lo.min(sp)
			hi = hi.max(sp)
		if behind:
			continue
		var area := (hi.x - lo.x) * (hi.y - lo.y)
		if area < 500.0:
			continue
		if hi.x < 350.0 or lo.x > 1000.0 or hi.y < 60.0 or lo.y > 300.0:
			continue
		var col := Color.MAGENTA
		var mat := mi.material_override
		if mat == null:
			mat = mi.get_active_material(0)
		if mat is StandardMaterial3D:
			col = (mat as StandardMaterial3D).albedo_color
		var parent_name := ""
		if mi.get_parent() != null:
			parent_name = str(mi.get_parent().name)
		hits.append([area, lo, hi, col, str(mi.get_path()),
			parent_name, box])
	hits.sort_custom(func(a, b): return a[0] > b[0])
	print("FRAME DUMP cam=", cam.global_position, " yaw=",
		cam.global_rotation_degrees.y)
	for h in hits.slice(0, 24):
		print("HIT area=", int(h[0]), " rect=", h[1], "..", h[2],
			" col=", h[3], " node=", h[4], " parent=", h[5],
			" aabb=", h[6])


func _run_preview() -> void:
	var t := 0.0
	var noise_t := 0.0
	while t < 3.2:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		noise_t += dt
		GameManager.set_threat(10.0 + t * 14.0)
		GameManager.set_sanity(100.0 - t * 12.0)
		if _player != null:
			_player.stamina = clampf(94.0 - t * 10.0, 25.0, 100.0)
		if noise_t >= 0.9:
			noise_t = 0.0
			GameEventBroker.player_noise_made.emit(5.0, _player.global_position)

	await get_tree().create_timer(0.4).timeout
	if "--dumpframe" in OS.get_cmdline_user_args():
		_dump_frame()
		get_tree().quit()
		return
	for d in _doors:
		if d.global_position.z > 6.5:
			print("SHOT DOOR ", d.name, " pivot=",
				d.get_node("Pivot").rotation_degrees, " open=", d.is_open)
	var cam := _player.get_node_or_null("HeadPivot/Camera3D") as Camera3D
	if cam != null:
		print("SHOT CAM pos=", cam.global_position, " rot=",
			cam.global_rotation_degrees, " player=", _player.global_position)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var suffix := "_" + _angle if _angle != "" else ""
	var path := ProjectSettings.globalize_path("res://preview/step1_duplex%s.png" % suffix)
	var err := img.save_png(path)
	print("DUPLEX PREVIEW: ", path, "  err=", err)
	get_tree().quit()
