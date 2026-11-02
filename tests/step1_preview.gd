extends Node3D
## =========================================================================
## Step 1 preview  -  foundation systems inside a bungalow-sized Haveli
## =========================================================================
## Layout:
##   * 22 x 18 m central hall, 4.2 m ceiling, carved columns
##   * double front doors -> 4 m veranda with swing + courtyard
##   * dining wing (left), bedroom wing (right), home mandir (back)
##   * the Haveli HUD: stamina, sanity, threat, noise, TODO panel
##
## Default mode: runs ~3.7 s, saves preview/step1_room.png, then quits.
## Live mode   : launch with  -- --live  to walk around yourself.
## =========================================================================

const PLAYER := preload("res://player/player.tscn")
const HUD := preload("res://ui/hud.tscn")
const DOOR := preload("res://props/door.tscn")

const CEIL := 4.2

var _player: PlayerController
var _live := false
var _mats: Dictionary = {}
var _fans: Array[Node3D] = []
var _doors: Array[HauntedDoor] = []
var _angle := ""


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
	GameManager.set_zone("central_hall")
	GameManager.set_objectives([
		{"id": "ingredients", "text": "Collect 3 ritual ingredients (0/3)", "done": false},
		{"id": "pooja_key", "text": "Find the Pooja Room key", "done": false},
		{"id": "havan", "text": "Perform the Havan at the altar", "done": false},
		{"id": "kamla", "text": "Do not let Kamla find you", "done": false},
	])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_build_environment()
	_build_bungalow()
	_set_preview_map()
	_spawn_player()
	add_child(HUD.instantiate())

	await get_tree().process_frame
	if _live:
		_start_live()
		return
	GameManager.show_message(
		"Haveli systems online.\nTHREAT / STAMINA / SANITY / NOISE live.\nE opens the main doors.",
		4.0
	)
	_run_preview()


func _start_live() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.show_message(
		"THE HAVELI OF KAMLA\n" +
		"WASD walk   SHIFT sprint   CTRL crouch   E open doors   F torch\n" +
		"ESC pause.  The double doors are behind you.",
		9.0
	)


func _process(delta: float) -> void:
	for fan in _fans:
		if is_instance_valid(fan):
			fan.rotation.y += delta * 0.85


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.045, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.30, 0.26, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.08, 0.11, 1.0)
	env.fog_density = 0.006
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -24.0, 0.0)
	sun.light_color = Color(0.45, 0.55, 0.85)
	sun.light_energy = 0.16
	sun.shadow_enabled = false
	add_child(sun)


# =========================================================================
#  THE BUNGALOW
# =========================================================================
func _build_bungalow() -> void:
	_make_materials()
	_build_shell()
	_build_floors()
	_build_ceiling()
	_build_columns()
	_build_double_doors()
	_build_veranda()
	_build_courtyard()
	_build_almirah(Vector3(-8.6, 0.0, -8.45), 0.0)
	_build_almirah(Vector3(10.55, 0.0, -0.8), -90.0)
	_build_dining()
	_build_sideboard()
	_build_mandir()
	_build_baithak()
	_build_bedroom()
	_build_wall_decor()
	_build_lights()


func _make_materials() -> void:
	_mats["plaster"] = _mat(Color(0.47, 0.38, 0.30), 1.0)
	_mats["wood_dark"] = _mat(Color(0.17, 0.10, 0.055), 0.85)
	_mats["wood"] = _mat(Color(0.31, 0.19, 0.10), 0.80)
	_mats["wood_light"] = _mat(Color(0.44, 0.28, 0.15), 0.75)
	_mats["floor_a"] = _mat(Color(0.25, 0.15, 0.08), 0.70)
	_mats["floor_b"] = _mat(Color(0.30, 0.19, 0.10), 0.70)
	_mats["floor_c"] = _mat(Color(0.22, 0.13, 0.07), 0.70)
	_mats["stone_a"] = _mat(Color(0.29, 0.28, 0.26), 0.95)
	_mats["stone_b"] = _mat(Color(0.34, 0.32, 0.29), 0.95)
	_mats["marble"] = _mat(Color(0.70, 0.65, 0.55), 0.55)
	_mats["brass"] = _metal(Color(0.74, 0.56, 0.22))
	_mats["copper"] = _metal(Color(0.56, 0.30, 0.15))
	_mats["clay"] = _mat(Color(0.42, 0.20, 0.12), 0.95)
	_mats["soil"] = _mat(Color(0.10, 0.07, 0.05), 1.0)
	_mats["green"] = _mat(Color(0.12, 0.30, 0.10), 0.9)
	_mats["cloth_red"] = _mat(Color(0.36, 0.06, 0.05), 1.0)
	_mats["cloth_cream"] = _mat(Color(0.64, 0.57, 0.42), 1.0)
	_mats["rug"] = _mat(Color(0.30, 0.05, 0.05), 1.0)
	_mats["rug_inner"] = _mat(Color(0.52, 0.40, 0.19), 1.0)
	_mats["dark"] = _mat(Color(0.04, 0.03, 0.03), 1.0)
	_mats["marigold"] = _mat(Color(0.95, 0.52, 0.06), 0.8)
	_mats["marigold2"] = _mat(Color(0.85, 0.30, 0.03), 0.8)
	_mats["flame"] = _emissive(Color(1.0, 0.66, 0.22), 3.5)
	_mats["window_glow"] = _emissive(Color(0.62, 0.42, 0.20), 0.55)
	_mats["moon"] = _emissive(Color(0.38, 0.52, 0.92), 1.4)
	_mats["moon_glow"] = _emissive(Color(0.80, 0.86, 1.0), 1.8)


func _build_shell() -> void:
	var plaster: Material = _mats["plaster"]
	var skirting: Material = _mats["wood_dark"]
	var rail: Material = _mats["wood"]
	var cornice: Material = _mats["wood_light"]

	_solid(Vector3(0.0, -0.15, 0.0), Vector3(22.3, 0.3, 18.3), _mats["floor_a"])
	_solid(Vector3(0.0, CEIL * 0.5, -9.15), Vector3(22.3, CEIL, 0.3), plaster)
	_solid(Vector3(-11.15, CEIL * 0.5, 0.0), Vector3(0.3, CEIL, 18.3), plaster)
	_solid(Vector3(11.15, CEIL * 0.5, 0.0), Vector3(0.3, CEIL, 18.3), plaster)
	# Front wall is split around a 3.6 m double doorway.
	_solid(Vector3(-6.475, CEIL * 0.5, 9.15), Vector3(9.35, CEIL, 0.3), plaster)
	_solid(Vector3(6.475, CEIL * 0.5, 9.15), Vector3(9.35, CEIL, 0.3), plaster)
	_solid(Vector3(0.0, 3.5, 9.15), Vector3(3.6, 1.4, 0.3), plaster)
	_solid(Vector3(0.0, CEIL + 0.15, 0.0), Vector3(22.3, 0.3, 18.3), _mats["wood_dark"])

	# Skirting board.
	_deco(Vector3(0.0, 0.10, -8.985), Vector3(22.0, 0.20, 0.04), skirting)
	_deco(Vector3(-10.985, 0.10, 0.0), Vector3(0.04, 0.20, 17.96), skirting)
	_deco(Vector3(10.985, 0.10, 0.0), Vector3(0.04, 0.20, 17.96), skirting)
	_deco(Vector3(-6.4, 0.10, 8.985), Vector3(9.2, 0.20, 0.04), skirting)
	_deco(Vector3(6.4, 0.10, 8.985), Vector3(9.2, 0.20, 0.04), skirting)

	# Dado rail.
	_deco(Vector3(0.0, 1.05, -8.985), Vector3(22.0, 0.07, 0.035), rail)
	_deco(Vector3(-10.985, 1.05, 0.0), Vector3(0.035, 0.07, 17.96), rail)
	_deco(Vector3(10.985, 1.05, 0.0), Vector3(0.035, 0.07, 17.96), rail)
	_deco(Vector3(-6.4, 1.05, 8.985), Vector3(9.2, 0.07, 0.035), rail)
	_deco(Vector3(6.4, 1.05, 8.985), Vector3(9.2, 0.07, 0.035), rail)

	# Cornice under the ceiling.
	_deco(Vector3(0.0, CEIL - 0.14, -8.97), Vector3(22.0, 0.16, 0.08), cornice)
	_deco(Vector3(-10.97, CEIL - 0.14, 0.0), Vector3(0.08, 0.16, 17.9), cornice)
	_deco(Vector3(10.97, CEIL - 0.14, 0.0), Vector3(0.08, 0.16, 17.9), cornice)

	# Two tall front windows, lit warmly from the veranda.
	for wx in [-6.6, 6.6]:
		_deco(Vector3(wx, 2.35, 8.965), Vector3(2.8, 1.7, 0.06), _mats["window_glow"])
		_deco(Vector3(wx, 1.46, 8.94), Vector3(3.0, 0.10, 0.10), _mats["wood_dark"])
		_deco(Vector3(wx, 3.24, 8.94), Vector3(3.0, 0.10, 0.10), _mats["wood_dark"])
		_deco(Vector3(wx - 1.47, 2.35, 8.94), Vector3(0.10, 1.8, 0.10), _mats["wood_dark"])
		_deco(Vector3(wx + 1.47, 2.35, 8.94), Vector3(0.10, 1.8, 0.10), _mats["wood_dark"])
		_deco(Vector3(wx, 2.35, 8.93), Vector3(0.07, 1.7, 0.07), _mats["wood_dark"])
		_deco(Vector3(wx, 2.35, 8.93), Vector3(2.75, 0.07, 0.07), _mats["wood_dark"])
		# The same window on the outside face of the front wall.
		_deco(Vector3(wx, 2.35, 9.325), Vector3(2.8, 1.7, 0.05), _mats["window_glow"])
		_deco(Vector3(wx, 1.46, 9.35), Vector3(3.0, 0.10, 0.10), _mats["wood_dark"])
		_deco(Vector3(wx, 3.24, 9.35), Vector3(3.0, 0.10, 0.10), _mats["wood_dark"])
		_deco(Vector3(wx - 1.47, 2.35, 9.35), Vector3(0.10, 1.8, 0.10), _mats["wood_dark"])
		_deco(Vector3(wx + 1.47, 2.35, 9.35), Vector3(0.10, 1.8, 0.10), _mats["wood_dark"])
		_deco(Vector3(wx, 2.35, 9.36), Vector3(0.07, 1.7, 0.07), _mats["wood_dark"])
		_deco(Vector3(wx, 2.35, 9.36), Vector3(2.75, 0.07, 0.07), _mats["wood_dark"])

	# Moon window over the bed (right wall) and a second one in the dining wing.
	_deco(Vector3(10.965, 2.7, -4.6), Vector3(0.06, 1.9, 2.6), _mats["moon"])
	_deco(Vector3(10.94, 1.72, -4.6), Vector3(0.10, 0.10, 2.8), _mats["wood_dark"])
	_deco(Vector3(10.94, 3.68, -4.6), Vector3(0.10, 0.10, 2.8), _mats["wood_dark"])
	_deco(Vector3(10.94, 2.7, -5.92), Vector3(0.10, 1.9, 0.10), _mats["wood_dark"])
	_deco(Vector3(10.94, 2.7, -3.28), Vector3(0.10, 1.9, 0.10), _mats["wood_dark"])
	_deco(Vector3(10.93, 2.7, -4.6), Vector3(0.07, 1.9, 0.07), _mats["wood_dark"])
	_deco(Vector3(10.93, 2.7, -4.6), Vector3(0.07, 0.07, 2.55), _mats["wood_dark"])

	_deco(Vector3(-10.965, 2.7, -5.5), Vector3(0.06, 1.9, 2.2), _mats["moon"])
	_deco(Vector3(-10.94, 1.72, -5.5), Vector3(0.10, 0.10, 2.4), _mats["wood_dark"])
	_deco(Vector3(-10.94, 3.68, -5.5), Vector3(0.10, 0.10, 2.4), _mats["wood_dark"])
	_deco(Vector3(-10.94, 2.7, -6.58), Vector3(0.10, 1.9, 0.10), _mats["wood_dark"])
	_deco(Vector3(-10.94, 2.7, -4.42), Vector3(0.10, 1.9, 0.10), _mats["wood_dark"])
	_deco(Vector3(-10.93, 2.7, -5.5), Vector3(0.07, 1.9, 0.07), _mats["wood_dark"])
	_deco(Vector3(-10.93, 2.7, -5.5), Vector3(0.07, 0.07, 2.15), _mats["wood_dark"])


func _build_floors() -> void:
	var shades := [_mats["floor_a"], _mats["floor_b"], _mats["floor_c"]]
	var x := -10.76
	var i := 0
	while x <= 10.76:
		_deco(Vector3(x, 0.006, 0.0), Vector3(0.46, 0.012, 17.96), shades[i % 3])
		x += 0.48
		i += 1

	# Veranda stone.
	_solid(Vector3(0.0, -0.15, 11.25), Vector3(23.0, 0.3, 4.4), _mats["stone_a"])
	var tones := [_mats["stone_a"], _mats["stone_b"]]
	for gx in range(-5, 6):
		for gz in range(0, 3):
			_deco(Vector3(gx * 2.2, 0.005, 9.7 + gz * 1.25),
				Vector3(2.15, 0.01, 1.2), tones[(gx + gz) % 2])

	# Courtyard stone.
	_solid(Vector3(0.0, -0.15, 15.55), Vector3(23.0, 0.3, 4.5), _mats["stone_a"])
	for gx in range(-5, 6):
		for gz in range(0, 3):
			_deco(Vector3(gx * 2.2, 0.005, 13.9 + gz * 1.25),
				Vector3(2.15, 0.01, 1.2), tones[(gx + gz + 1) % 2])


func _build_ceiling() -> void:
	for z in [-6.8, -4.0, -1.2, 1.6, 4.4, 7.2]:
		_deco(Vector3(0.0, CEIL - 0.12, z), Vector3(21.9, 0.2, 0.26), _mats["wood_dark"])

	# Veranda ceiling slab and beams.
	_solid(Vector3(0.0, 3.9, 11.25), Vector3(23.0, 0.3, 4.4), _mats["wood_dark"])
	for z in [9.7, 11.4, 13.1]:
		_deco(Vector3(0.0, 3.58, z), Vector3(22.8, 0.22, 0.24), _mats["wood_dark"])


func _build_columns() -> void:
	for cx in [-6.0, 6.0]:
		for cz in [-4.5, 4.5]:
			_pillar(cx, cz, 4.0)
	for cz in [-4.5, 4.5]:
		_deco(Vector3(0.0, 3.92, cz), Vector3(12.8, 0.3, 0.34), _mats["wood_dark"])
		_deco(Vector3(0.0, 3.76, cz), Vector3(12.8, 0.05, 0.4), _mats["brass"])


func _pillar(x: float, z: float, height: float) -> void:
	var mat: Material = _mats["wood_dark"]
	_solid(Vector3(x, height * 0.5, z), Vector3(0.42, height, 0.42), mat)
	_deco(Vector3(x, 0.18, z), Vector3(0.82, 0.36, 0.82), _mats["wood_light"])
	_deco(Vector3(x, height - 0.15, z), Vector3(0.80, 0.30, 0.80), _mats["wood_light"])
	_deco(Vector3(x, 0.56, z), Vector3(0.50, 0.07, 0.50), _mats["brass"])
	_deco(Vector3(x, height - 0.55, z), Vector3(0.50, 0.07, 0.50), _mats["brass"])


func _build_double_doors() -> void:
	var wl: Material = _mats["wood_light"]
	var wd: Material = _mats["wood_dark"]

	_deco(Vector3(-1.9, 1.5, 8.96), Vector3(0.14, 3.0, 0.14), wl)
	_deco(Vector3(1.9, 1.5, 8.96), Vector3(0.14, 3.0, 0.14), wl)
	_deco(Vector3(0.0, 2.98, 8.96), Vector3(4.0, 0.16, 0.16), wl)
	for sx in [-1.55, 1.55]:
		_deco(Vector3(sx, 2.79, 8.96), Vector3(0.12, 0.36, 0.12), wd)
	_deco(Vector3(0.0, 2.72, 8.90), Vector3(3.7, 0.07, 0.12), _mats["brass"])

	var left := DOOR.instantiate() as HauntedDoor
	left.position = Vector3(-1.8, 0.0, 8.97)
	left.open_angle = -95.0
	add_child(left)
	_doors.append(left)

	var right := DOOR.instantiate() as HauntedDoor
	right.position = Vector3(1.8, 0.0, 8.97)
	right.rotation_degrees.y = 180.0
	right.open_angle = -95.0
	add_child(right)
	_doors.append(right)

	_garland(Vector3(0.0, 2.62, 8.84), 3.2, 0.24)

	# Courtyard-side entrance: toran over the doors and two brass sconces.
	_garland(Vector3(0.0, 2.60, 9.42), 3.2, 0.26)
	_deco(Vector3(0.0, 3.02, 9.40), Vector3(4.0, 0.12, 0.12), wl)
	_sconce(Vector3(-2.45, 2.05, 9.40), 0.75)
	_sconce(Vector3(2.45, 2.05, 9.40), 0.75)


func _build_veranda() -> void:
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	var plaster: Material = _mats["plaster"]

	# Enclosed sides, open front.
	for sx in [-11.5, 11.5]:
		_solid(Vector3(sx, 1.875, 11.25), Vector3(0.3, 3.75, 4.4), plaster)

	for px in [-10.5, -5.5, 5.5, 10.5]:
		_pillar(px, 13.0, 3.75)
	_deco(Vector3(0.0, 3.58, 13.0), Vector3(22.0, 0.3, 0.4), wd)

	# Low parapet with a central gap for the steps.
	var segments := [
		[-8.0, 5.0], [-4.05, 2.9], [4.05, 2.9], [8.0, 5.0],
	]
	for seg in segments:
		var cx: float = float(seg[0])
		var w: float = float(seg[1])
		_solid(Vector3(cx, 0.43, 13.05), Vector3(w, 0.86, 0.24), _mats["plaster"])
		_deco(Vector3(cx, 0.90, 13.05), Vector3(w + 0.12, 0.10, 0.32), wl)

	# Veranda swing.
	_swing(-7.5, 11.0)

	# Lanterns under the veranda ceiling.
	_lantern(Vector3(-6.0, 2.85, 12.2), 0.9)
	_lantern(Vector3(6.0, 2.85, 12.2), 0.9)

	# Potted plants at the mouth of the veranda.
	_plant(Vector3(-10.2, 0.0, 12.4), 1.2)
	_plant(Vector3(10.2, 0.0, 12.4), 1.2)


func _build_courtyard() -> void:
	var wall: Material = _mats["plaster"]
	# Compound boundary with a central gate.
	_solid(Vector3(-6.5, 0.9, 17.8), Vector3(9.0, 1.8, 0.3), wall)
	_solid(Vector3(6.5, 0.9, 17.8), Vector3(9.0, 1.8, 0.3), wall)
	_solid(Vector3(0.0, 1.15, 17.8), Vector3(4.6, 0.3, 0.4), _mats["wood_dark"])
	for gx in [-2.2, 2.2]:
		_solid(Vector3(gx, 1.2, 17.8), Vector3(0.5, 2.4, 0.5), _mats["plaster"])
		_deco(Vector3(gx, 2.45, 17.8), Vector3(0.7, 0.12, 0.7), _mats["wood_light"])
	_solid(Vector3(-11.5, 0.9, 15.55), Vector3(0.3, 1.8, 4.5), wall)
	_solid(Vector3(11.5, 0.9, 15.55), Vector3(0.3, 1.8, 4.5), wall)

	_tulsi(Vector3(0.0, 0.0, 15.4))
	_plant(Vector3(-8.6, 0.0, 16.4), 1.1)
	_plant(Vector3(8.6, 0.0, 16.4), 1.1)

	# Moon hanging over the courtyard.
	_sphere(Vector3(15.0, 13.0, 27.0), 2.2, _mats["moon_glow"])

	var moon := OmniLight3D.new()
	moon.position = Vector3(0.0, 5.5, 14.8)
	moon.light_color = Color(0.48, 0.62, 1.0)
	moon.light_energy = 1.35
	moon.omni_range = 18.0
	add_child(moon)


func _build_almirah(origin: Vector3, yaw_deg: float) -> void:
	var w := 2.4
	var h := 2.2
	var d := 0.72
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	var inset: Material = _mats["wood"]
	var brass: Material = _mats["brass"]

	var rotated := absf(sin(deg_to_rad(yaw_deg))) > 0.5
	var csize := Vector3(d, h, w) if rotated else Vector3(w, h, d)
	_solid(origin + Vector3(0.0, h * 0.5, 0.0), csize, wd)

	var pivot := Node3D.new()
	pivot.position = origin
	pivot.rotation_degrees.y = yaw_deg
	add_child(pivot)

	_deco(Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), wd, pivot)
	_deco(Vector3(0.0, h + 0.05, 0.0), Vector3(w + 0.14, 0.10, d + 0.10), wl, pivot)
	_deco(Vector3(0.0, 0.09, 0.0), Vector3(w + 0.06, 0.18, d + 0.06), wl, pivot)

	var door_w := w * 0.5 - 0.08
	for dx in [-w * 0.25, w * 0.25]:
		_deco(Vector3(dx, h * 0.5, d * 0.5 + 0.02), Vector3(door_w, h - 0.3, 0.06), wl, pivot)
		_deco(Vector3(dx, h * 0.5, d * 0.5 + 0.05), Vector3(door_w - 0.18, h - 0.5, 0.02), inset, pivot)
	for dx in [-0.10, 0.10]:
		var handle := _cyl(Vector3(dx, 1.15, d * 0.5 + 0.10), 0.032, 0.10, brass, pivot)
		handle.rotation_degrees.x = 90.0
	_deco(Vector3(0.0, 1.04, d * 0.5 + 0.09), Vector3(0.12, 0.18, 0.03), brass, pivot)


func _build_dining() -> void:
	var tx := -7.0
	var tz := -1.0
	var top: Material = _mats["wood_light"]
	var wd: Material = _mats["wood_dark"]
	var brass: Material = _mats["brass"]

	_solid(Vector3(tx, 0.78, tz), Vector3(3.4, 0.10, 1.3), top)
	for sx in [-1.55, 1.55]:
		for sz in [-0.5, 0.5]:
			_deco(Vector3(tx + sx, 0.365, tz + sz), Vector3(0.11, 0.73, 0.11), wd)

	_deco(Vector3(tx, 0.835, tz), Vector3(1.0, 0.01, 1.32), _mats["cloth_red"])
	for dx in [-1.1, -0.38, 0.38, 1.1]:
		_cyl(Vector3(tx + dx, 0.85, tz - 0.28), 0.15, 0.03, brass)
		_cyl(Vector3(tx + dx, 0.85, tz + 0.28), 0.15, 0.03, brass)
	_cyl(Vector3(tx, 0.90, tz), 0.18, 0.13, _mats["copper"])
	_diya(Vector3(tx + 1.5, 0.84, tz - 0.4), 0.4)

	_chair(Vector3(tx - 1.0, 0.0, tz - 1.2), 180.0)
	_chair(Vector3(tx + 1.0, 0.0, tz - 1.2), 180.0)
	_chair(Vector3(tx - 1.0, 0.0, tz + 1.2), 0.0)
	_chair(Vector3(tx + 1.0, 0.0, tz + 1.2), 0.0)
	_chair(Vector3(tx - 2.4, 0.0, tz), -90.0)
	_chair(Vector3(tx + 2.4, 0.0, tz), 90.0)


func _build_sideboard() -> void:
	var x := -10.55
	var z := -1.0
	var body: Material = _mats["wood"]
	var top: Material = _mats["wood_light"]
	var wd: Material = _mats["wood_dark"]
	var brass: Material = _mats["brass"]

	_solid(Vector3(x, 0.45, z), Vector3(0.52, 0.90, 3.2), body)
	_deco(Vector3(x, 0.92, z), Vector3(0.60, 0.06, 3.3), top)
	for dz in [-1.1, 0.0, 1.1]:
		_deco(Vector3(x + 0.265, 0.52, z + dz), Vector3(0.02, 0.46, 0.86), wd)
		var knob := _cyl(Vector3(x + 0.29, 0.52, z + dz), 0.03, 0.06, brass)
		knob.rotation_degrees.z = 90.0

	_cyl(Vector3(x, 1.07, z - 1.0), 0.18, 0.36, _mats["copper"])
	_cyl(Vector3(x, 1.03, z - 0.1), 0.13, 0.26, brass)
	_cyl(Vector3(x, 1.12, z + 1.0), 0.20, 0.44, _mats["copper"])
	_diya(Vector3(x + 0.05, 0.96, z + 0.5), 0.35)

	# Shelf above the sideboard with jars.
	_deco(Vector3(-10.86, 1.56, z), Vector3(0.24, 0.06, 2.4), top)
	for dz in [-0.9, 0.6]:
		_deco(Vector3(-10.95, 1.45, z + dz), Vector3(0.12, 0.18, 0.08), wd)
	_cyl(Vector3(-10.84, 1.73, z - 0.72), 0.09, 0.28, _mats["copper"])
	_cyl(Vector3(-10.84, 1.68, z - 0.28), 0.07, 0.20, brass)
	_cyl(Vector3(-10.84, 1.74, z + 0.18), 0.08, 0.26, _mats["copper"])


func _build_mandir() -> void:
	var wl: Material = _mats["wood_light"]
	var wd: Material = _mats["wood"]
	var dark: Material = _mats["dark"]
	var brass: Material = _mats["brass"]
	var marble: Material = _mats["marble"]

	_solid(Vector3(0.0, 0.15, -8.25), Vector3(4.0, 0.30, 1.4), marble)
	_deco(Vector3(0.0, 0.05, -7.55), Vector3(3.4, 0.10, 0.5), marble)

	_deco(Vector3(0.0, 0.55, -8.55), Vector3(2.9, 0.5, 0.55), wl)
	_deco(Vector3(0.0, 2.0, -8.55), Vector3(2.8, 2.6, 0.5), wl)
	_deco(Vector3(0.0, 2.0, -8.29), Vector3(2.2, 1.7, 0.04), dark)
	_deco(Vector3(0.0, 3.32, -8.52), Vector3(3.1, 0.12, 0.6), wd)
	for dx in [-1.25, 1.25]:
		_deco(Vector3(dx, 2.0, -8.32), Vector3(0.14, 2.5, 0.14), wd)

	_deco(Vector3(0.0, 0.95, -8.25), Vector3(0.9, 0.5, 0.5), wd)
	_cyl(Vector3(0.0, 1.35, -8.20), 0.17, 0.45, brass)
	_sphere(Vector3(0.0, 1.67, -8.20), 0.14, brass)
	_deco(Vector3(0.0, 1.86, -8.20), Vector3(0.34, 0.08, 0.34), _mats["flame"])

	_diya(Vector3(-1.2, 0.35, -7.95), 0.45)
	_diya(Vector3(1.2, 0.35, -7.95), 0.45)
	_garland(Vector3(0.0, 2.66, -8.27), 2.4, 0.28)

	_standing_lamp(-2.45, -7.35)
	_standing_lamp(2.45, -7.35)


func _build_baithak() -> void:
	var wd: Material = _mats["wood_dark"]
	var top: Material = _mats["wood_light"]

	_deco(Vector3(0.0, 0.02, 3.0), Vector3(8.0, 0.02, 5.0), _mats["rug"])
	_deco(Vector3(0.0, 0.032, 3.0), Vector3(7.2, 0.012, 4.2), _mats["rug_inner"])
	_deco(Vector3(0.0, 0.042, 3.0), Vector3(5.0, 0.010, 2.6), _mats["rug"])

	_sofa(Vector3(-3.1, 0.0, 3.0), -90.0)
	_sofa(Vector3(3.1, 0.0, 3.0), 90.0)

	_solid(Vector3(0.0, 0.34, 3.0), Vector3(1.9, 0.12, 1.0), top)
	for sx in [-0.8, 0.8]:
		for sz in [-0.36, 0.36]:
			_deco(Vector3(sx, 0.14, 3.0 + sz), Vector3(0.10, 0.28, 0.10), wd)
	_deco(Vector3(0.0, 0.42, 3.0), Vector3(1.2, 0.02, 0.6), _mats["cloth_red"])
	_hookah(Vector3(0.0, 0.42, 2.62))

	var cushions := [Vector3(-1.8, 0.10, 4.45), Vector3(1.8, 0.10, 4.45)]
	for p in cushions:
		_cyl(p, 0.34, 0.18, _mats["cloth_cream"])
		_cyl(p + Vector3(0.0, 0.10, 0.0), 0.28, 0.05, _mats["cloth_red"])


func _build_bedroom() -> void:
	var wd: Material = _mats["wood"]
	var cream: Material = _mats["cloth_cream"]
	var red: Material = _mats["cloth_red"]
	var bx := 7.8
	var bz := -4.6

	for sx in [-0.82, 0.82]:
		for sz in [-1.5, 1.5]:
			_deco(Vector3(bx + sx, 0.26, bz + sz), Vector3(0.12, 0.52, 0.12), wd)
	_deco(Vector3(bx - 0.82, 0.54, bz), Vector3(0.10, 0.12, 3.2), wd)
	_deco(Vector3(bx + 0.82, 0.54, bz), Vector3(0.10, 0.12, 3.2), wd)
	_deco(Vector3(bx, 0.54, bz - 1.6), Vector3(1.75, 0.12, 0.10), wd)
	_deco(Vector3(bx, 0.54, bz + 1.6), Vector3(1.75, 0.12, 0.10), wd)

	_solid(Vector3(bx, 0.585, bz), Vector3(1.62, 0.09, 3.0), cream)
	_deco(Vector3(bx, 0.66, bz + 1.1), Vector3(1.5, 0.14, 0.8), red)
	_deco(Vector3(bx - 0.36, 0.66, bz - 1.3), Vector3(0.62, 0.16, 0.36), cream)
	_deco(Vector3(bx + 0.36, 0.66, bz - 1.3), Vector3(0.62, 0.16, 0.36), cream)

	_solid(Vector3(9.9, 0.30, bz), Vector3(0.6, 0.6, 0.6), _mats["wood"])
	_deco(Vector3(9.9, 0.62, bz), Vector3(0.66, 0.05, 0.66), _mats["wood_light"])
	_diya(Vector3(9.9, 0.66, bz), 0.35)

	_build_trunk(Vector3(5.9, 0.0, -3.6))


func _build_trunk(pos: Vector3) -> void:
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	var brass: Material = _mats["brass"]
	_solid(pos + Vector3(0.0, 0.27, 0.0), Vector3(1.1, 0.54, 0.66), wd)
	_deco(pos + Vector3(0.0, 0.57, 0.0), Vector3(1.14, 0.12, 0.70), wl)
	for dx in [-0.34, 0.34]:
		_deco(pos + Vector3(dx, 0.40, 0.0), Vector3(0.07, 0.56, 0.70), brass)
	_deco(pos + Vector3(0.0, 0.42, 0.35), Vector3(0.16, 0.18, 0.04), brass)


func _build_wall_decor() -> void:
	var brass: Material = _mats["brass"]
	var painting: Material = _mat(Color(0.19, 0.08, 0.05), 1.0)
	var highlight: Material = _mat(Color(0.55, 0.40, 0.20), 1.0)

	# Pictures above the sideboard (left wall).
	for fz in [-1.75, -0.25]:
		_deco(Vector3(-10.96, 2.55, fz), Vector3(0.04, 0.90, 0.70), brass)
		_deco(Vector3(-10.93, 2.55, fz), Vector3(0.02, 0.76, 0.56), painting)
		_deco(Vector3(-10.92, 2.55, fz), Vector3(0.01, 0.34, 0.24), highlight)

	# Large frame above the bedroom almirah (right wall).
	_deco(Vector3(10.96, 3.05, -0.8), Vector3(0.04, 0.90, 1.5), brass)
	_deco(Vector3(10.93, 3.05, -0.8), Vector3(0.02, 0.76, 1.36), painting)
	_deco(Vector3(10.92, 3.05, -0.8), Vector3(0.01, 0.36, 0.64), highlight)

	# Clock and a photo on the back wall.
	_build_clock(Vector3(-4.8, 3.05, -8.96))
	_deco(Vector3(4.8, 3.05, -8.965), Vector3(1.1, 0.74, 0.04), brass)
	_deco(Vector3(4.8, 3.05, -8.935), Vector3(0.94, 0.58, 0.02), painting)
	_deco(Vector3(4.8, 3.05, -8.925), Vector3(0.38, 0.28, 0.01), highlight)


func _build_clock(pos: Vector3) -> void:
	var face := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.34
	cm.height = 0.04
	cm.radial_segments = 28
	face.mesh = cm
	face.material_override = _mats["cloth_cream"]
	face.rotation_degrees.x = 90.0
	face.position = pos
	add_child(face)

	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.32
	tm.outer_radius = 0.38
	rim.mesh = tm
	rim.material_override = _mats["brass"]
	rim.rotation_degrees.x = 90.0
	rim.position = pos + Vector3(0.0, 0.0, -0.015)
	add_child(rim)

	_deco(pos + Vector3(0.0, 0.07, 0.035), Vector3(0.020, 0.17, 0.01), _mats["dark"])
	_deco(pos + Vector3(0.06, 0.01, 0.035), Vector3(0.13, 0.020, 0.01), _mats["dark"])


func _build_lights() -> void:
	_chandelier(Vector3(0.0, 3.05, 3.0), 0.85, 3.0, true)
	_chandelier(Vector3(-7.0, 3.0, -1.0), 0.45, 1.8, false)
	_chandelier(Vector3(0.0, 3.0, -7.25), 0.30, 0.9, false)

	var bed_moon := OmniLight3D.new()
	bed_moon.position = Vector3(10.2, 2.7, -4.6)
	bed_moon.light_color = Color(0.48, 0.62, 1.0)
	bed_moon.light_energy = 1.5
	bed_moon.omni_range = 9.0
	add_child(bed_moon)

	var dining_moon := OmniLight3D.new()
	dining_moon.position = Vector3(-10.2, 2.7, -5.5)
	dining_moon.light_color = Color(0.48, 0.62, 1.0)
	dining_moon.light_energy = 1.1
	dining_moon.omni_range = 7.0
	add_child(dining_moon)

	_sconce(Vector3(-10.9, 2.45, 6.0), 0.7)
	_sconce(Vector3(10.9, 2.45, -6.5), 0.7)

	for fan_pos in [Vector3(7.8, 3.62, -4.6), Vector3(-7.0, 3.62, 5.8)]:
		_build_fan(fan_pos)


func _chandelier(pos: Vector3, ring_radius: float, energy: float, shadows: bool) -> void:
	_cyl(pos + Vector3(0.0, 0.55, 0.0), 0.02, 1.1, _mats["dark"])
	_cyl(pos + Vector3(0.0, 0.02, 0.0), 0.08, 0.24, _mats["brass"])

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(ring_radius - 0.035, 0.05)
	tm.outer_radius = ring_radius + 0.035
	ring.mesh = tm
	ring.material_override = _mats["brass"]
	ring.position = pos
	add_child(ring)

	for i in 6:
		var a := TAU * float(i) / 6.0
		_sphere(pos + Vector3(cos(a) * ring_radius, -0.05, sin(a) * ring_radius), 0.055, _mats["flame"])

	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.0, -0.12, 0.0)
	l.light_color = Color(1.0, 0.70, 0.40)
	l.light_energy = energy
	l.omni_range = 17.0
	l.shadow_enabled = shadows
	add_child(l)


func _lantern(pos: Vector3, energy: float) -> void:
	_cyl(pos + Vector3(0.0, 0.5, 0.0), 0.015, 1.0, _mats["dark"])
	_deco(pos, Vector3(0.24, 0.32, 0.24), _mats["brass"])
	_sphere(pos + Vector3(0.0, -0.02, 0.0), 0.09, _mats["flame"])
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.0, -0.10, 0.0)
	l.light_color = Color(1.0, 0.64, 0.32)
	l.light_energy = energy
	l.omni_range = 7.0
	add_child(l)


func _sconce(pos: Vector3, energy: float) -> void:
	_deco(pos, Vector3(0.12, 0.22, 0.12), _mats["brass"])
	_cyl(pos + Vector3(0.0, 0.15, 0.0), 0.05, 0.08, _mats["flame"])
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.0, 0.22, 0.0)
	l.light_color = Color(1.0, 0.62, 0.30)
	l.light_energy = energy
	l.omni_range = 6.0
	add_child(l)


func _build_fan(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_fans.append(root)
	_cyl(pos + Vector3(0.0, 0.30, 0.0), 0.018, 0.40, _mats["dark"])
	_cyl(pos + Vector3(0.0, 0.04, 0.0), 0.11, 0.16, _mats["brass"])
	for i in 3:
		var pivot := Node3D.new()
		pivot.rotation_degrees.y = 120.0 * float(i)
		root.add_child(pivot)
		_deco(Vector3(0.58, 0.0, 0.0), Vector3(0.98, 0.025, 0.17), _mats["wood_light"], pivot)
		_deco(Vector3(0.58, 0.013, 0.0), Vector3(0.92, 0.010, 0.08), _mats["wood_dark"], pivot)


func _chair(origin: Vector3, yaw_deg: float) -> void:
	var pivot := Node3D.new()
	pivot.position = origin
	pivot.rotation_degrees.y = yaw_deg
	add_child(pivot)
	var wd: Material = _mats["wood"]
	var seat: Material = _mats["wood_light"]
	_deco(Vector3(0.0, 0.46, 0.0), Vector3(0.52, 0.07, 0.52), seat, pivot)
	_deco(Vector3(0.0, 0.79, 0.24), Vector3(0.52, 0.60, 0.07), wd, pivot)
	for sx in [-0.21, 0.21]:
		for sz in [-0.21, 0.21]:
			_deco(Vector3(sx, 0.23, sz), Vector3(0.06, 0.46, 0.06), wd, pivot)


func _sofa(origin: Vector3, yaw_deg: float) -> void:
	var pivot := Node3D.new()
	pivot.position = origin
	pivot.rotation_degrees.y = yaw_deg
	add_child(pivot)
	var wd: Material = _mats["wood_dark"]
	var fabric: Material = _mats["cloth_red"]
	var cream: Material = _mats["cloth_cream"]

	var rotated := absf(sin(deg_to_rad(yaw_deg))) > 0.5
	var csize := Vector3(0.95, 0.6, 3.2) if rotated else Vector3(3.2, 0.6, 0.95)
	_solid(origin + Vector3(0.0, 0.30, 0.0), csize, wd)

	_deco(Vector3(0.0, 0.25, 0.0), Vector3(3.2, 0.40, 0.95), fabric, pivot)
	_deco(Vector3(0.0, 0.62, 0.38), Vector3(3.2, 0.55, 0.16), fabric, pivot)
	for sx in [-1.5, 1.5]:
		_deco(Vector3(sx, 0.45, 0.0), Vector3(0.18, 0.45, 0.95), wd, pivot)
	for sx in [-0.8, 0.8]:
		_deco(Vector3(sx, 0.47, -0.05), Vector3(1.4, 0.12, 0.75), cream, pivot)
		_deco(Vector3(sx, 0.74, 0.33), Vector3(1.2, 0.35, 0.12), cream, pivot)


func _hookah(pos: Vector3) -> void:
	_sphere(pos + Vector3(0.0, 0.16, 0.0), 0.16, _mats["brass"])
	_cyl(pos + Vector3(0.0, 0.36, 0.0), 0.025, 0.30, _mats["brass"])
	_cyl(pos + Vector3(0.0, 0.53, 0.0), 0.06, 0.06, _mats["copper"])


func _swing(x: float, z: float) -> void:
	for dx in [-0.85, 0.85]:
		_cyl(Vector3(x + dx, 2.2, z), 0.012, 3.0, _mats["dark"])
	_deco(Vector3(x, 0.72, z), Vector3(1.9, 0.10, 0.62), _mats["wood_light"])
	_deco(Vector3(x, 1.15, z + 0.27), Vector3(1.9, 0.80, 0.08), _mats["wood_light"])
	_deco(Vector3(x, 0.80, z), Vector3(1.7, 0.10, 0.50), _mats["cloth_cream"])
	_deco(Vector3(x, 0.92, z + 0.24), Vector3(1.3, 0.35, 0.12), _mats["cloth_red"])


func _plant(pos: Vector3, scale: float) -> void:
	_cyl(pos + Vector3(0.0, 0.28 * scale, 0.0), 0.32 * scale, 0.56 * scale, _mats["clay"])
	_cyl(pos + Vector3(0.0, 0.57 * scale, 0.0), 0.28 * scale, 0.04 * scale, _mats["soil"])
	for i in 3:
		var a := TAU * float(i) / 3.0
		_sphere(pos + Vector3(cos(a) * 0.16 * scale, 0.85 * scale, sin(a) * 0.16 * scale),
			0.28 * scale, _mats["green"])
	_sphere(pos + Vector3(0.0, 1.02 * scale, 0.0), 0.26 * scale, _mats["green"])


func _tulsi(pos: Vector3) -> void:
	_solid(pos + Vector3(0.0, 0.40, 0.0), Vector3(1.2, 0.8, 1.2), _mats["marble"])
	_deco(pos + Vector3(0.0, 0.81, 0.0), Vector3(0.96, 0.04, 0.96), _mats["soil"])
	for i in 4:
		var a := TAU * float(i) / 4.0
		_sphere(pos + Vector3(cos(a) * 0.22, 1.08, sin(a) * 0.22), 0.36, _mats["green"])
	_sphere(pos + Vector3(0.0, 1.35, 0.0), 0.42, _mats["green"])
	_diya(pos + Vector3(0.0, 0.84, 0.5), 0.25)


func _standing_lamp(x: float, z: float) -> void:
	_cyl(Vector3(x, 0.09, z), 0.20, 0.18, _mats["brass"])
	_cyl(Vector3(x, 0.85, z), 0.035, 1.5, _mats["brass"])
	_deco(Vector3(x, 1.62, z), Vector3(0.28, 0.08, 0.28), _mats["brass"])
	_sphere(Vector3(x, 1.72, z), 0.07, _mats["flame"])


func _garland(center: Vector3, width: float, drop: float) -> void:
	var parent := Node3D.new()
	parent.position = center
	add_child(parent)
	var n := 11
	for i in n:
		var t := float(i) / float(n - 1)
		var p := Vector3(lerpf(-width * 0.5, width * 0.5, t), -sin(t * PI) * drop, 0.0)
		var mat: Material = _mats["marigold"] if i % 2 == 0 else _mats["marigold2"]
		_sphere(p, 0.05, mat, parent)


func _diya(pos: Vector3, energy: float) -> void:
	_cyl(pos, 0.07, 0.05, _mats["brass"])
	_sphere(pos + Vector3(0.0, 0.055, 0.0), 0.028, _mats["flame"])
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.0, 0.13, 0.0)
	l.light_color = Color(1.0, 0.60, 0.22)
	l.light_energy = energy
	l.omni_range = 2.8
	add_child(l)


# --- small building helpers ----------------------------------------------
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


func _spawn_player() -> void:
	_player = PLAYER.instantiate() as PlayerController
	_player.position = Vector3(0.0, 0.2, 7.4)
	# Optional camera angles for the still previews.
	match _angle:
		"outside":
			_player.position = Vector3(3.0, 0.2, 16.4)
			_player.rotation_degrees.y = 22.0
		"veranda":
			_player.position = Vector3(2.6, 0.2, 12.4)
			_player.rotation_degrees.y = -8.0
		"bedroom":
			_player.position = Vector3(4.6, 0.2, 1.9)
			_player.rotation_degrees.y = -58.0
		"dining":
			_player.position = Vector3(-2.1, 0.2, -4.4)
			_player.rotation_degrees.y = 112.0
	if _angle == "outside" or _angle == "veranda":
		for d in _doors:
			d.is_open = true
	add_child(_player)
	# Hide the first-person weapon for a clean systems preview.
	var view := _player.get_node_or_null("HeadPivot/Camera3D/WeaponView") as Node3D
	if view != null:
		view.visible = false


func _set_preview_map() -> void:
	var blocks: Array = []
	# Floor plate: makes the minimap read as a floor plan instead of a black box.
	blocks.append({"rect": Rect2(-11.0, -9.0, 22.0, 18.0), "height": 0.05})
	blocks.append({"rect": Rect2(-11.5, -9.3, 23.0, 0.4), "height": 4.2})
	blocks.append({"rect": Rect2(-11.5, 8.9, 9.7, 0.4), "height": 4.2})
	blocks.append({"rect": Rect2(1.8, 8.9, 9.7, 0.4), "height": 4.2})
	blocks.append({"rect": Rect2(-11.5, -9.3, 0.4, 18.6), "height": 4.2})
	blocks.append({"rect": Rect2(10.9, -9.3, 0.4, 18.6), "height": 4.2})
	GameManager.set_map(blocks, Rect2(-11.8, -9.6, 23.6, 19.2))


func _run_preview() -> void:
	var t := 0.0
	var noise_t := 0.0
	while t < 3.2:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		noise_t += dt
		GameManager.set_threat(12.0 + t * 16.0)
		GameManager.set_sanity(100.0 - t * 13.0)
		if _player != null:
			_player.stamina = clampf(92.0 - t * 9.0, 20.0, 100.0)
		if noise_t >= 0.9:
			noise_t = 0.0
			GameEventBroker.player_noise_made.emit(5.0, _player.global_position)

	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var suffix := "_" + _angle if _angle != "" else ""
	var path := ProjectSettings.globalize_path("res://preview/step1_bungalow%s.png" % suffix)
	var err := img.save_png(path)
	print("STEP1 PREVIEW: ", path, "  err=", err)
	get_tree().quit()
