extends Node3D
## =========================================================================
## Step 1 palace preview  -  the Haveli of Kamla
## =========================================================================
## A palace-scale bungalow. Every room is a real separate room, and every
## room is large enough to move, fight and hide in.
##
##   GROUND   living hall (double height) | dining | kitchen |
##            ground bedroom | back hall | corridor | stair hall
##   FIRST    gallery over the back hall | upper bedroom | grand stair
##   EXTRA    pooja room (god temple) | tantra room (black magic)
##   OUTSIDE  palace portico, courtyard, well, dead tree, gate
##
## Default mode: renders a still to preview/ and quits.
## Live mode   : launch with  -- --live  to walk it yourself.
## Angle       : -- --angle=living|corridor|stairs|puja|tantra|upper|
##               upperbed|dining|kitchen|bedroom|outside|doors
## =========================================================================

const PLAYER := preload("res://player/player.tscn")
const HUD := preload("res://ui/hud.tscn")
const DOOR := preload("res://props/door.tscn")

# ---- the palace footprint ------------------------------------------------
const XW := -13.0          # west outer wall
const XE := 13.0           # east outer wall
const ZB := -11.0          # back outer wall
const ZF := 11.0           # front outer wall
const GROUND_H := 4.2      # ground-floor ceiling
const UPPER_Y := 4.2       # first-floor level
const UPPER_H := 3.6
const TOP_Y := 7.8         # main roof

# ---- interior room lines ------------------------------------------------
const LXW := -5.0          # living hall west
const LXE := 5.0           # living hall east
const LZN := 2.0           # living hall north / back-hall front
const BACK_Z := -4.0       # corridor / pooja / tantra front wall
const CORR_X := 1.75       # corridor half-width

var _player: PlayerController
var _live := false
var _mats: Dictionary = {}
var _fans: Array[Node3D] = []
var _doors: Array[HauntedDoor] = []
var _flicker: Array[OmniLight3D] = []
var _angle := ""
var _last_zone := ""
var _returning_home := false
var _outside_time := 0.0

const HOME_POS := Vector3(0.0, 0.25, 9.6)
const OUTSIDE_LIMIT := 18.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--angle="):
			_angle = arg.substr("--angle=".length())
	_live = "--live" in OS.get_cmdline_user_args()

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
	_spawn_player()
	add_child(HUD.instantiate())

	await get_tree().process_frame
	if _live:
		_start_live()
		return
	GameManager.show_message(
		"The Haveli is awake.\nA palace of locked rooms. A temple. A room that should stay sealed.\nE opens doors.",
		2.0
	)
	_run_preview()


func _start_live() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.show_message(
		"THE HAVELI OF KAMLA\n" +
		"WASD walk   SHIFT sprint   CTRL crouch   E open doors   F torch\n" +
		"Climb the grand stair. The pooja room is at the back. Do not enter the red room.",
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
	if _live and not _returning_home:
		_check_escape(delta)


func _check_escape(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p := _player.global_position
	var far := p.z > 22.5 or p.z < -16.0 or absf(p.x) > 20.5
	if p.z > 12.2:
		_outside_time += delta
	else:
		_outside_time = 0.0
	if not far and _outside_time < OUTSIDE_LIMIT:
		return
	_return_home()


func _return_home() -> void:
	_returning_home = true
	_outside_time = 0.0
	await GameManager.fade_to(1.0, 0.55)
	if _player != null and is_instance_valid(_player):
		_player.global_position = HOME_POS
		_player.velocity = Vector3.ZERO
		_player.rotation_degrees.y = 0.0
	await get_tree().create_timer(0.35).timeout
	await GameManager.fade_to(0.0, 0.75)
	GameManager.show_message("YOU CAN NOT ESCAPE FROM THIS WORLD.", 6.0)
	_returning_home = false


func _update_zone() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p := _player.global_position
	var z := "living_hall"
	if p.z > 11.0:
		z = "courtyard" if p.z > 14.0 else "veranda"
	elif p.y > UPPER_Y - 0.4:
		z = "upper_bedroom" if p.z > 2.0 else "upper_gallery"
	elif p.z < BACK_Z:
		if absf(p.x) < CORR_X:
			z = "corridor"
		elif p.x < -CORR_X:
			z = "black_magic_room"
		else:
			z = "pooja_room"
	elif p.z < LZN:
		if p.x < LXW:
			z = "kitchen"
		elif p.x > LXE:
			z = "stair_hall"
		else:
			z = "back_hall"
	elif p.x < LXW:
		z = "dining_room"
	elif p.x > LXE:
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
	env.fog_density = 0.013
	env.ssao_enabled = true
	env.ssao_radius = 1.3
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
	moon.directional_shadow_max_distance = 95.0
	moon.shadow_bias = 0.04
	add_child(moon)

	# Cool spoiler light across the courtyard and the front facade.
	var spot := SpotLight3D.new()
	spot.position = Vector3(12.0, 20.0, 26.0)
	spot.rotation_degrees = Vector3(-48.0, 28.0, 0.0)
	spot.light_color = Color(0.46, 0.56, 0.86)
	spot.light_energy = 3.8
	spot.spot_range = 65.0
	spot.spot_angle = 54.0
	spot.spot_attenuation = 0.9
	spot.shadow_enabled = true
	spot.shadow_bias = 0.05
	add_child(spot)

	# A second cold wash on the west wing so the palace reads from the side.
	var side := SpotLight3D.new()
	side.position = Vector3(-26.0, 16.0, 20.0)
	side.rotation_degrees = Vector3(-42.0, -42.0, 0.0)
	side.light_color = Color(0.38, 0.48, 0.78)
	side.light_energy = 2.2
	side.spot_range = 55.0
	side.spot_angle = 48.0
	side.shadow_enabled = false
	add_child(side)


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
	_mats["cloth_white"] = _mat(Color(0.70, 0.66, 0.56), 0.95)
	_mats["rug"] = _mat(Color(0.26, 0.035, 0.035), 1.0)
	_mats["rug_inner"] = _mat(Color(0.47, 0.34, 0.14), 1.0)
	_mats["dark"] = _mat(Color(0.025, 0.020, 0.018), 1.0)
	_mats["soot"] = _mat(Color(0.055, 0.045, 0.040), 1.0)
	_mats["bone"] = _mat(Color(0.71, 0.66, 0.53), 0.85)
	_mats["blood"] = _mat(Color(0.16, 0.008, 0.008), 1.0)
	_mats["blood_wet"] = _mat(Color(0.24, 0.004, 0.004), 0.28)
	_mats["flesh"] = _mat(Color(0.46, 0.11, 0.09), 0.72)
	_mats["meat"] = _mat(Color(0.29, 0.025, 0.025), 0.55)
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
	_solid(Vector3(0.0, -0.15, 0.0), Vector3(26.6, 0.3, 22.6), _mats["floor_a"])

	# ---- outer ground walls -------------------------------------------
	_wall_z(ZB, XW, XE, 0.0, GROUND_H, plaster, 0.40)
	_wall_x(XW, ZB, ZF, 0.0, GROUND_H, plaster, 0.40)
	_wall_x(XE, ZB, ZF, 0.0, GROUND_H, plaster, 0.40)
	# Front wall split around the 4.4 m palace doorway.
	_wall_z(ZF, XW, -2.2, 0.0, GROUND_H, plaster, 0.40)
	_wall_z(ZF, 2.2, XE, 0.0, GROUND_H, plaster, 0.40)
	_wall_z(ZF, -2.2, 2.2, 3.6, 0.6, plaster, 0.40)

	# ---- ground interior walls ---------------------------------------
	# Living hall north wall, with the 3.4 m arch into the back hall.
	_wall_z(LZN, LXW, -1.7, 0.0, GROUND_H, plaster)
	_wall_z(LZN, 1.7, LXE, 0.0, GROUND_H, plaster)
	_wall_z(LZN, -1.7, 1.7, 3.3, 0.9, plaster)

	# Living west wall -> dining, 1.8 m double door at z 4.9..6.7.
	_wall_x(LXW, LZN, 4.9, 0.0, GROUND_H, plaster)
	_wall_x(LXW, 6.7, ZF, 0.0, GROUND_H, plaster)
	_wall_x(LXW, 4.9, 6.7, 2.7, 1.5, plaster)

	# Living east wall -> ground bedroom, 1.8 m double door at z 4.9..6.7.
	_wall_x(LXE, LZN, 4.9, 0.0, GROUND_H, plaster)
	_wall_x(LXE, 6.7, ZF, 0.0, GROUND_H, plaster)
	_wall_x(LXE, 4.9, 6.7, 2.7, 1.5, plaster)

	# Dining / kitchen wall at z = 2, door x -9.9..-8.5.
	_wall_z(LZN, XW, -9.9, 0.0, GROUND_H, plaster)
	_wall_z(LZN, -8.5, LXW, 0.0, GROUND_H, plaster)
	_wall_z(LZN, -9.9, -8.5, 2.1, 2.1, plaster)

	# Kitchen east wall -> back hall, door z -1.2..0.0.
	_wall_x(LXW, BACK_Z, -1.2, 0.0, GROUND_H, plaster)
	_wall_x(LXW, 0.0, LZN, 0.0, GROUND_H, plaster)
	_wall_x(LXW, -1.2, 0.0, 2.1, 2.1, plaster)

	# Back rooms' front wall at z = -4, corridor gap x -1.75..1.75.
	_wall_z(BACK_Z, XW, -CORR_X, 0.0, GROUND_H, plaster)
	_wall_z(BACK_Z, CORR_X, XE, 0.0, GROUND_H, plaster)

	# Corridor side walls, doors at z -7.8..-6.6.
	_wall_x(-CORR_X, ZB, -7.8, 0.0, GROUND_H, plaster)
	_wall_x(-CORR_X, -6.6, BACK_Z, 0.0, GROUND_H, plaster)
	_wall_x(-CORR_X, -7.8, -6.6, 2.1, 2.1, plaster)
	_wall_x(CORR_X, ZB, -7.8, 0.0, GROUND_H, plaster)
	_wall_x(CORR_X, -6.6, BACK_Z, 0.0, GROUND_H, plaster)
	_wall_x(CORR_X, -7.8, -6.6, 2.1, 2.1, plaster)

	# Stair hall west wall: 3.2 m arch from the back hall.
	_wall_x(LXE, BACK_Z, -1.6, 0.0, GROUND_H, plaster)
	_wall_x(LXE, 1.6, LZN, 0.0, GROUND_H, plaster)
	_wall_x(LXE, -1.6, 1.6, 3.4, 0.8, plaster)

	# Stair hall / ground bedroom shared wall.
	_wall_z(LZN, LXE, XE, 0.0, GROUND_H, plaster)

	# ---- first floor walls -------------------------------------------
	_wall_z(BACK_Z, LXW, XE, UPPER_Y, UPPER_H, plaster, 0.30)
	_wall_x(LXW, BACK_Z, LZN, UPPER_Y, UPPER_H, plaster, 0.30)
	_wall_x(XE, BACK_Z, LZN, UPPER_Y, UPPER_H, plaster, 0.30)
	# Upper bedroom shell.
	_wall_x(LXE, LZN, ZF, UPPER_Y, UPPER_H, plaster, 0.30)
	_wall_x(XE, LZN, ZF, UPPER_Y, UPPER_H, plaster, 0.30)
	_wall_z(ZF, LXW, XE, UPPER_Y, UPPER_H, plaster, 0.30)
	# Upper bedroom north wall with a 1.2 m door at x 5.7..6.9.
	_wall_z(LZN, LXE, 5.7, UPPER_Y, UPPER_H, plaster)
	_wall_z(LZN, 6.9, XE, UPPER_Y, UPPER_H, plaster)
	_wall_z(LZN, 5.7, 6.9, UPPER_Y + 2.2, UPPER_H - 2.2, plaster)
	# Double-height living hall west wall.
	_wall_x(LXW, LZN, ZF, UPPER_Y, TOP_Y - UPPER_Y, plaster, 0.30)

	# ---- roofs --------------------------------------------------------
	# Main two-storey block over living, stair hall and upper bedroom.
	_solid(Vector3(4.0, TOP_Y + 0.15, 3.5), Vector3(18.8, 0.30, 15.8), dark)
	# West wing (dining + kitchen), single storey.
	_solid(Vector3(-9.0, 4.45, 3.5), Vector3(8.6, 0.25, 15.8), dark)
	# Back block (pooja + tantra + corridor), single storey.
	_solid(Vector3(0.0, 4.45, -7.5), Vector3(26.6, 0.25, 7.6), dark)

	# Main roof parapets and crenellations.
	for z in [ZF, BACK_Z]:
		_wall_z(z, LXW, XE, TOP_Y + 0.30, 0.70, plaster)
		_wall_z(z, LXW, XE, TOP_Y + 1.10, 0.30, plaster, 0.44)
	for x in [LXW, XE]:
		_wall_x(x, BACK_Z, ZF, TOP_Y + 0.30, 0.70, plaster)
		_wall_x(x, BACK_Z, ZF, TOP_Y + 1.10, 0.30, plaster, 0.44)
	_crenel_z(ZF + 0.02, LXW, XE, TOP_Y + 0.30)
	_crenel_z(BACK_Z - 0.02, LXW, XE, TOP_Y + 0.30)
	_crenel_x(LXW - 0.02, BACK_Z, ZF, TOP_Y + 0.30)
	_crenel_x(XE + 0.02, BACK_Z, ZF, TOP_Y + 0.30)

	# Single-storey parapets.
	_wall_z(ZF, XW, LXW, 4.70, 0.62, plaster)
	_wall_z(ZB, XW, XE, 4.70, 0.62, plaster)
	_wall_x(XW, ZB, ZF, 4.70, 0.62, plaster)
	_wall_x(XE, ZB, BACK_Z, 4.70, 0.62, plaster)
	_wall_x(XE, BACK_Z, LZN, UPPER_Y, UPPER_H, plaster, 0.30)
	_crenel_z(ZF + 0.02, XW, LXW, 4.70)
	_crenel_z(ZB - 0.02, XW, XE, 4.70)
	_crenel_x(XW - 0.02, ZB, ZF, 4.70)
	_crenel_x(XE + 0.02, ZB, BACK_Z, 4.70)

	# ---- trims --------------------------------------------------------
	_skirting_z(LZN + 0.02, LXW, LXE, 0.02)
	_skirting_z(ZF - 0.02, XW, XE, 0.02)
	_skirting_x(LXW - 0.02, LZN, ZF, 0.02)
	_skirting_x(LXE + 0.02, LZN, ZF, 0.02)
	_skirting_z(BACK_Z + 0.02, XW, XE, 0.02)

	# Ceiling beams over the double-height living hall.
	for bz in [3.2, 4.8, 6.4, 8.0, 9.6]:
		_deco(Vector3(0.0, TOP_Y - 0.18, bz), Vector3(10.0, 0.24, 0.22), dark)
	_deco(Vector3(0.0, TOP_Y - 0.16, 6.5), Vector3(0.22, 0.24, 8.8), dark)

	# Gallery railing over the living hall.
	_railing_z(LZN, LXW, LXE)
	# Stairwell railing on the upper floor.
	_railing_z(1.5, 8.0, 12.6)
	_railing_x(12.6, -1.5, 1.5)
	_railing_x(8.0, 0.0, 1.5)
	_newel(Vector3(8.0, UPPER_Y, 0.0))
	_newel(Vector3(8.0, UPPER_Y, 1.5))
	_newel(Vector3(12.6, UPPER_Y, -1.5))
	_newel(Vector3(12.6, UPPER_Y, 1.5))
	# Landing railings.
	_deco(Vector3(12.6, 3.05, 0.0), Vector3(0.10, 0.08, 3.0),
		_mats["wood_light"])
	for z in [-1.3, -0.4, 0.5, 1.3]:
		_cyl(Vector3(12.6, 2.55, z), 0.035, 1.0, dark)
	_deco(Vector3(12.45, 2.55, 1.5), Vector3(0.34, 1.0, 0.08), dark)
	_deco(Vector3(12.45, 2.55, -1.5), Vector3(0.34, 1.0, 0.08), dark)
	# Two turned columns under the mid landing.
	for z in [-1.25, 1.25]:
		_cyl(Vector3(12.35, 1.05, z), 0.16, 2.10, plaster)
		_deco(Vector3(12.35, 0.10, z), Vector3(0.44, 0.20, 0.44),
			_mats["stone_b"])
		_deco(Vector3(12.35, 2.02, z), Vector3(0.40, 0.12, 0.40),
			_mats["stone_b"])


func _build_floors() -> void:
	var a: Material = _mats["floor_b"]
	var b: Material = _mats["floor_a"]
	var c: Material = _mats["floor_c"]

	# Ground floor boards / stone.
	_wood_floor(Rect2(LXW, LZN, 10.0, 9.0), a, b)
	_wood_floor(Rect2(XW, LZN, 8.0, 9.0), b, c)
	_tile_floor(Rect2(XW, BACK_Z, 8.0, 6.0), _mats["stone_a"], _mats["stone_b"])
	_wood_floor(Rect2(LXE, LZN, 8.0, 9.0), b, a)
	_tile_floor(Rect2(LXW, BACK_Z, 10.0, 6.0), _mats["stone_a"], _mats["stone_b"])
	_tile_floor(Rect2(-CORR_X, ZB, CORR_X * 2.0, 7.0),
		_mats["stone_a"], _mats["stone_b"], 0.012, 0.65)
	_tile_floor(Rect2(LXE, BACK_Z, 8.0, 6.0), _mats["stone_a"], _mats["stone_b"])
	# Pooja marble, tantra black stone.
	_tile_floor(Rect2(CORR_X, ZB, XE - CORR_X, 7.0),
		_mats["marble"], _mats["marble"], 0.012, 0.9)
	_tile_floor(Rect2(XW, ZB, -CORR_X - XW, 7.0),
		_mats["soot"], _mats["tantra"], 0.012, 0.85)

	# First floor slabs (top at UPPER_Y), leaving the stairwell open.
	_solid(Vector3(1.5, UPPER_Y - 0.10, -1.0), Vector3(13.0, 0.20, 6.0),
		_mats["wood"])
	_solid(Vector3(10.5, UPPER_Y - 0.10, -2.75), Vector3(5.0, 0.20, 2.5),
		_mats["wood"])
	_solid(Vector3(10.5, UPPER_Y - 0.10, 1.75), Vector3(5.0, 0.20, 0.5),
		_mats["wood"])
	_solid(Vector3(12.8, UPPER_Y - 0.10, 0.0), Vector3(0.4, 0.20, 3.0),
		_mats["wood"])
	_solid(Vector3(9.0, UPPER_Y - 0.10, 6.5), Vector3(8.0, 0.20, 9.0),
		_mats["wood"])
	# Mid landing of the switchback stair.
	_solid(Vector3(11.9, 2.0, 0.0), Vector3(1.8, 0.20, 3.0),
		_mats["wood"])

	# Upper floor boards.
	_wood_floor(Rect2(LXW, BACK_Z, 13.0, 6.0), a, b, UPPER_Y + 0.012)
	_wood_floor(Rect2(8.0, -4.0, 5.0, 2.5), b, c, UPPER_Y + 0.012)
	_wood_floor(Rect2(8.0, 1.5, 5.0, 0.5), b, c, UPPER_Y + 0.012)
	_wood_floor(Rect2(LXE, LZN, 8.0, 9.0), a, b, UPPER_Y + 0.012)

	# Stair nosing.
	_deco(Vector3(8.0, UPPER_Y - 0.04, -0.65), Vector3(0.12, 0.08, 1.2),
		_mats["wood_light"])


func _build_stairs() -> void:
	# Grand switchback stair. Two 12-step flights, 2.1 m per flight,
	# 3.0 m run per flight = 35 degrees, comfortably walkable. The bottom
	# landing is 3 m deep, so there is real space before the first step.
	_stair_flight(Vector3(8.0, 0.0, 0.75), 3.0, 2.1, 12, 1.20)
	_stair_flight(Vector3(11.0, 2.1, -0.65), -3.0, 2.1, 12, 1.20)

	# Landing nosing and top nosing.
	_deco(Vector3(11.0, 2.09, 0.0), Vector3(0.08, 0.04, 3.0),
		_mats["wood_light"])
	_deco(Vector3(8.0, UPPER_Y + 0.01, -0.65), Vector3(0.08, 0.04, 1.2),
		_mats["wood_light"])


func _stair_flight(start: Vector3, run: float, rise: float,
		steps: int, width: float) -> void:
	var dir := signf(run)
	var step_run := absf(run) / float(steps)
	var step_rise := rise / float(steps)
	var length := sqrt(run * run + rise * rise)
	var ang := rad_to_deg(atan2(rise, absf(run))) * dir
	var wood: Material = _mats["wood"]
	var dark: Material = _mats["wood_dark"]
	var light: Material = _mats["wood_light"]
	var mid := start + Vector3(run * 0.5, rise * 0.5, 0.0)

	# Hidden ramp collision under the visible treads.
	_solid_rot(mid + Vector3(0.0, -0.10, 0.0),
		Vector3(length, 0.20, width), dark, Vector3(0.0, 0.0, ang))

	# Visible solid treads.
	for i in steps:
		var cx := start.x + dir * (float(i) + 0.5) * step_run
		var top := start.y + step_rise * float(i + 1)
		var h := step_rise * float(i + 1)
		_deco(Vector3(cx, start.y + h * 0.5, start.z),
			Vector3(step_run + 0.015, h, width), wood)
		_deco(Vector3(cx + dir * step_run * 0.5, top + 0.014, start.z),
			Vector3(0.035, 0.03, width), light)

	# Stringers and handrails on both sides.
	for sz in [-1.0, 1.0]:
		var z := start.z + sz * width * 0.5
		var stringer := _deco(mid + Vector3(0.0, -0.02, sz * width * 0.5),
			Vector3(length, 0.34, 0.08), dark)
		stringer.rotation_degrees.z = ang
		var rail := _deco(mid + Vector3(0.0, 0.94, sz * width * 0.5),
			Vector3(length, 0.07, 0.07), light)
		rail.rotation_degrees.z = ang
		var posts := maxi(4, int(absf(run) / 0.45))
		for i in posts + 1:
			var t := float(i) / float(posts)
			var px := start.x + run * t
			var py := start.y + rise * t
			_cyl(Vector3(px, py + 0.46, z), 0.022, 0.92, dark)
	# Newel posts at the foot and head.
	_newel(Vector3(start.x, start.y, start.z + width * 0.5))
	_newel(Vector3(start.x, start.y, start.z - width * 0.5))


func _build_doors() -> void:
	# Main entrance: two wide leaves, the maker's name split across them.
	var left := DOOR.instantiate() as HauntedDoor
	left.position = Vector3(-2.2, 0.0, ZF)
	left.scale = Vector3(1.2222, 1.0, 1.0)
	left.open_angle = -150.0
	left.collision_layer = 257
	left.is_open = not _live
	add_child(left)
	_doors.append(left)
	_blood_sign(left, "A GAME BY")

	var right := DOOR.instantiate() as HauntedDoor
	right.position = Vector3(2.2, 0.0, ZF)
	right.rotation_degrees.y = 180.0
	right.scale = Vector3(1.2222, 1.0, 1.0)
	right.open_angle = 150.0
	right.collision_layer = 257
	right.is_open = not _live
	add_child(right)
	_doors.append(right)
	_blood_sign(right, "NISHANTH")

	# Architrave, transom and torans.
	var wl: Material = _mats["wood_light"]
	var wd: Material = _mats["wood_dark"]
	_deco(Vector3(-2.28, 1.80, ZF - 0.06), Vector3(0.18, 3.60, 0.18), wl)
	_deco(Vector3(2.28, 1.80, ZF - 0.06), Vector3(0.18, 3.60, 0.18), wl)
	_deco(Vector3(0.0, 3.62, ZF - 0.06), Vector3(4.74, 0.18, 0.18), wl)
	_deco(Vector3(0.0, 3.28, ZF - 0.12), Vector3(4.30, 0.08, 0.10), _mats["brass"])
	_deco(Vector3(0.0, 3.22, ZF - 0.08), Vector3(4.30, 0.80, 0.10), _mats["dark"])
	for i in 9:
		_deco(Vector3(-1.92 + float(i) * 0.48, 3.22, ZF - 0.02),
			Vector3(0.035, 0.78, 0.05), wl)
	_garland(Vector3(0.0, 3.10, ZF - 0.14), 4.1, 0.30)
	_garland(Vector3(0.0, 3.08, ZF + 0.14), 4.1, 0.31)
	_deco(Vector3(0.0, 3.62, ZF + 0.14), Vector3(4.74, 0.16, 0.14), wl)
	_sconce(Vector3(-4.65, 2.30, ZF + 0.16), 0.80)
	_sconce(Vector3(4.65, 2.30, ZF + 0.16), 0.80)
	# Threshold.
	_deco(Vector3(0.0, 0.015, ZF), Vector3(4.40, 0.03, 0.50), wd)

	# Interior doors. Previews open most of them; live play leaves the back
	# rooms shut.
	_interior_door(Vector3(LXW, 0.0, 6.7), 90.0, not _live, 1.8)
	_interior_door(Vector3(LXE, 0.0, 4.9), -90.0, not _live, 1.8)
	_interior_door(Vector3(-9.9, 0.0, LZN), 0.0, not _live, 1.4)
	_interior_door(Vector3(LXW, 0.0, 0.0), 90.0, not _live, 1.2)
	_interior_door(Vector3(-CORR_X, 0.0, -6.6), 90.0, false, 1.2)
	_interior_door(Vector3(CORR_X, 0.0, -7.8), -90.0, false, 1.2)
	_interior_door(Vector3(5.7, UPPER_Y, LZN), 0.0, not _live, 1.2)


# __APPEND__
