extends "res://tests/step1_duplex.gd"
## =========================================================================
## Step 1 palace  -  THE HAVELI OF KAMLA
## =========================================================================
## The cramped duplex rebuilt as a grand Indian haveli around the preserved
## 22.3 x 18.3 m central hall.
##
##   CENTRAL HALL   22.3 x 18.3 m, 13.6 m double height, four thick wooden
##                  pillars, mandir, upper balconies on the west and north.
##   DINING WING    15.55 x 18.3 m, table and gore pushed to the west edge.
##   BEDROOM WING   15.55 x 18.3 m, bed and wardrobe in the far corners.
##   REAR WALKWAY   53.4 x 4.15 m palace corridor with a red runner.
##   REAR ROOMS     kitchen | tantra | stair tower | pooja | guest room,
##                  all 12 m deep, lit and deliberately sparse.
##   UPPER FLOOR    long gallery over the rear walkway, upper bedroom over
##                  the east wing, balconies overlooking the hall.
##   GRAND STAIR    U-shaped switchback in the rear tower: 3 m bottom
##                  landing, two 5.5 m flights at 31.7 degrees.
##   OUTSIDE        full-width veranda, courtyard, well, dead tree, gate.
##
## The Black Magician portrait hangs on the stair tower's north wall,
## above the mid landing: it looks down the whole climb. The tantra room
## keeps its centred altar, wall sigil and red floor pentagram; Nishanth's
## memorial photograph stands on its side wall.
##
## Default mode: renders a still to preview/ and quits.
## Live mode   : launch with  -- --live
## Angle       : -- --angle=hall|hallwide|entrance|dining|dininggore|kitchen|
##               bedroom|bedroomantique|bedroommirror|bedroomportraits|
##               bedroomalmirah|corridor|corridore|tantra|tantraoccult|pooja|
##               poojabells|murti|ritual|stairs|upper|uppergallery|
##               upperbed|guest|outside|gate|blackmagician|photos
## =========================================================================

const PLAYER_SCENE := preload("res://player/player.tscn")
const GHOST_SCENE := preload("res://enemies/enemy_ghost.tscn")

# ---- palace plan --------------------------------------------------------
const PAL_XW := -26.7
const PAL_XE := 26.7
const PAL_ZF := 9.15
const PAL_ZB := -25.3
const HALL_XW := -11.15
const HALL_XE := 11.15
const HALL_ZB := -9.15
const HALL_ZF := 9.15
const CORR_ZB := -13.3
const REAR_MID_Z := -19.3

const LOW_H := 6.8
const HALL_H := 13.6
const GALLERY_H := 12.4
const TOWER_H := 14.6

# Rear wing partitions, west to east.
const KIT_XE := -12.7
const TANTRA_XW := -12.7
const TANTRA_XE := -3.4
const STAIR_XW := -3.4
const STAIR_XE := 3.4
const POOJA_XW := 3.4
const POOJA_XE := 12.7
const GUEST_XW := 12.7

# Stair geometry. Both flights rise 3.4 m over a 5.5 m run.
const STAIR_RISE := 3.4
const STAIR_RUN := 5.5
const STAIR_BOTTOM := -16.3
const STAIR_MID_Z := -21.8
const STAIR_MID_B := -23.8
const STAIR_TOP_Z := -18.3
const STAIR_LAND_Z := -13.3
const STAIR_INNER := 4.4

const HOME_POS := Vector3(0.0, 0.25, 7.4)
const GATE_Z := 23.6

var _returning_home := false
var _outside_timer := 0.0
var _ghost: EnemyGhost
var _preview_yaw := 0.0
var _preview_pitch := 0.0

# ---------------------------------------------------------------- temple
var _murti_normal: Node3D
var _murti_furious: Node3D
var _murti_wrath_light: OmniLight3D
var _murti_wrath := false
var _murti_check := 0.0
var _pray_cooldown := 0.0
var _cursed_items: Array[String] = []
var _ash_charges := 0
var _barriers: Array[Dictionary] = []
var _temple_bells: Array[Node3D] = []
var _bell_alarm := false
var _bell_chime := 0.0
var _bell_notice_cooldown := 0.0
var _everlasting_light: OmniLight3D
var _everlasting_flames: Array[MeshInstance3D] = []
var _diya_fuel := 210.0
var _diya_lit := true
var _diya_rest_cooldown := 0.0
var _ghee := 0
var _camphor := 0
var _withered_garlands: Array[Node3D] = []
var _fresh_garland_segments: Array[Node3D] = []
var _garlands_replaced := 0
var _fresh_garlands := 0
var _blessing_timer := 0.0
var _blessing_rate := 0.0
var _altar_point: HaveliInteractable
var _diya_point: HaveliInteractable
var _vibhuti_point: HaveliInteractable

# ---------------------------------------------------------------- tantra
var _cremation_ash := 0
var _blood_charges := 0
var _kapala_blood: Node3D
var _ash_pots: Array[Node3D] = []
var _yantras_studied: Array[String] = []
var _read_dolls: Array[String] = []
var _nimbu_root: Node3D
var _nimbu_timer := 0.0
var _nimbu_next := 0.0
var _nimbu_cooldown := 0.0
var _ash_clouds: Array[Dictionary] = []
var _minor_spirits: Array[EnemyGhost] = []
var _sanctuary_check := 0.0
var _kapala_point: HaveliInteractable
var _kapala_glow: OmniLight3D
var _ritual_insight := 0

# ---------------------------------------------------------------- bottle ritual
enum RitualPhase { IDLE, DRAWN, PLACED, BOUND, SEALED }

const RITUAL_X := -8.05
const RITUAL_Z := -19.3

var _ritual_phase := RitualPhase.IDLE
var _ritual_center := Vector3(RITUAL_X, 0.0, RITUAL_Z)
var _chalk_root: Node3D
var _chalk_glow_ring: MeshInstance3D
var _ritual_glass: StandardMaterial3D
var _ritual_bottle: Node3D
var _pedestal_bottle: Node3D
var _bottle_shards: Node3D
var _ritual_point: HaveliInteractable
var _ritual_light: OmniLight3D
var _bottle_on_pedestal := true
var _ritual_window := 0.0
var _ritual_window_max := 0.0
var _ritual_arm_delay := 0.0
var _ritual_guard := 0.0
var _ritual_pulse := 0.0
var _ritual_fail_glow := 0.0
var _ritual_hint_shown := false

# ---------------------------------------------------------------- bedroom
## The bedroom is a survival room, not decoration. Every antique either
## feeds the stamina/sanity/noise loop or hides something from the ghost.
var _bed_hide_point: HaveliInteractable
var _almirah_point: HaveliInteractable
var _mirror_point: HaveliInteractable
var _sandook_point: HaveliInteractable
var _surahi_point: HaveliInteractable
var _weeping_girl: Node3D
var _almirah_left: Node3D
var _almirah_right: Node3D
var _almirah_light: OmniLight3D
var _almirah_open_timer := 0.0
var _almirah_opens := 0
var _almirah_girl_timer := 0.0
var _almirah_notice_cd := 0.0
var _mirror_gaze_active := false
var _mirror_gaze_time := 0.0
var _mirror_vision_timer := 0.0
var _mirror_face: Node3D
var _mirror_smile := false
var _mirror_notice_cd := 0.0
var _mirror_revealed := false
var _mirror_warned := false
var _mirror_marks: Array[Node3D] = []
var _sandook_code: Array = [4, 1, 3]
var _sandook_dials: Array = [1, 1, 1]
var _sandook_sel := 0
var _sandook_active := false
var _sandook_open := false
var _sandook_lid: Node3D
var _sandook_ui_layer: CanvasLayer
var _sandook_dial_label: Label
var _sandook_hint_label: Label
var _sandook_fumble := 0.0
var _surahi_cooldown := 0.0
var _tantra_taint := 0.0
var _blur_timer := 0.0
var _blur_layer: CanvasLayer
var _blur_mat: ShaderMaterial
var _net_layer: CanvasLayer
var _net_mat: ShaderMaterial
var _net_ghost := 0.0
var _net_warning_shown := false
var _bedroom_portraits: Array[Dictionary] = []
var _portrait_warned: Dictionary = {}
var _bedroom_check := 0.0
var _nightstand_ref: Node3D


func _ready() -> void:
	_start_music()
	super._ready()
	_tune_night()
	# A death restart rebuilds the Haveli from scratch, so the ritual starts
	# fresh too. This also stops a sealed bottle leaking between runs.
	GameManager.clear_inventory_items(["empty_bottle", "sealed_bottle"])
	# The parent scene sets the old duplex tasks before it yields. Replace
	# them here so stills and the live build show the Haveli's own list.
	if not _live:
		GameManager.set_objectives(_haveli_objectives())


func _haveli_objectives() -> Array:
	return [
		{"id": "explore", "text": "Explore the Haveli", "done": false},
		{"id": "sanctuary", "text": "Find sanctuary in the pooja room", "done": false},
		{"id": "black_magician", "text": "Find the Black Magician's room", "done": false},
		{"id": "bottle_ritual", "text": "Seal Kamla in the black bottle", "done": false},
		{"id": "kamla", "text": "Do not let Kamla find you", "done": false},
	]


## Lift the shadows just enough that the palace reads on screen without
## losing the midnight mood.
func _tune_night() -> void:
	for child in get_children():
		if child is WorldEnvironment:
			var we := child as WorldEnvironment
			if we.environment != null:
				we.environment.ambient_light_energy = 0.45
				we.environment.fog_density = 0.014
				we.environment.tonemap_exposure = 1.10
		elif child is DirectionalLight3D:
			(child as DirectionalLight3D).light_energy = 0.50


## Melancholia loops quietly under the whole Haveli.
func _start_music() -> void:
	var stream := load("res://audio/music/melancholia.mp3") as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	var music := AudioStreamPlayer.new()
	music.name = "Melancholia"
	music.stream = stream
	music.volume_db = -15.0
	music.bus = "Master"
	add_child(music)
	music.play()


func _start_live() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.set_objectives(_haveli_objectives())
	GameManager.show_message(
		"THE HAVELI OF KAMLA\n" +
		"WASD walk   SHIFT run   CTRL crouch   E interact   F torch   G ash\n" +
		"Cross the hall. The pooja room waits at the back. " +
		"Something is already walking the hall.",
		10.0
	)
	if "--ghosttest" in OS.get_cmdline_user_args():
		_ghost_probe()


func _ghost_probe() -> void:
	for i in 10:
		await get_tree().create_timer(1.0).timeout
		if _ghost != null and is_instance_valid(_ghost) and _player != null:
			print("GHOSTPROBE t=", i + 1, " state=", _ghost.state,
				" pos=", _ghost.global_position, " player_hp=",
				_player.health, " dist=",
				_ghost.global_position.distance_to(_player.global_position))


func _process(delta: float) -> void:
	super._process(delta)
	_update_temple(delta)
	_update_tantra(delta)
	_update_ritual(delta)
	_update_bedroom(delta)
	if _live and not _returning_home:
		_check_escape(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _live or _player == null:
		return
	if _sandook_active:
		if event is InputEventKey:
			_on_sandook_key(event as InputEventKey)
			get_viewport().set_input_as_handled()
		return
	if _mirror_gaze_active and event.is_action_pressed("interact"):
		_end_mirror_gaze(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ash_cloud"):
		_throw_cremation_ash()
		get_viewport().set_input_as_handled()
		return
	# During the binding, E is the seal. It works while you are looking at
	# Kamla or the bottle, not only while the pedestal fills the reticle.
	if event.is_action_pressed("interact") and _ritual_phase == RitualPhase.BOUND:
		var flat_player := Vector3(_player.global_position.x, 0.0,
			_player.global_position.z)
		if flat_player.distance_to(_ritual_center) <= 4.5:
			_try_seal_now()
			get_viewport().set_input_as_handled()


func _check_escape(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p := _player.global_position
	var out := p.z > GATE_Z or p.z < PAL_ZB - 6.0 or absf(p.x) > PAL_XE + 8.0
	# The gate is the formal edge of the property. Wandering down the road
	# or slipping around the compound wall is treated the same way.
	if p.z > GATE_Z - 1.0:
		_outside_timer += delta
	else:
		_outside_timer = 0.0
	if not out and _outside_timer < 1.2:
		return
	_return_home()


func _return_home() -> void:
	_returning_home = true
	_outside_timer = 0.0
	await GameManager.fade_to(1.0, 0.6)
	if _player != null and is_instance_valid(_player):
		_player.global_position = HOME_POS
		_player.velocity = Vector3.ZERO
		_player.rotation_degrees.y = 0.0
	await get_tree().create_timer(0.35).timeout
	await GameManager.fade_to(0.0, 0.8)
	GameManager.show_message("You can not escape from this world.", 6.5)
	_returning_home = false


func _update_zone() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p := _player.global_position
	var z := "living_hall"
	if p.z > PAL_ZF + 0.2:
		z = "courtyard" if p.z > 12.4 else "veranda"
	elif p.y > LOW_H - 0.55:
		if p.z > HALL_ZB - 0.2 and p.x > HALL_XE - 0.2:
			z = "upper_bedroom"
		elif absf(p.x) < STAIR_XE + 0.4 and p.z < CORR_ZB + 0.2:
			z = "stair_tower"
		else:
			z = "upper_gallery"
	elif p.z < CORR_ZB:
		if p.x < TANTRA_XW:
			z = "kitchen"
		elif p.x < TANTRA_XE:
			z = "black_magic_room"
		elif p.x < POOJA_XW:
			z = "stair_tower"
		elif p.x < POOJA_XE:
			z = "pooja_room"
		else:
			z = "guest_room"
	elif p.z < HALL_ZB:
		z = "corridor"
	elif p.x < HALL_XW:
		z = "dining_room"
	elif p.x > HALL_XE:
		z = "bedroom_ground"
	if z != _last_zone:
		_last_zone = z
		GameManager.set_zone(z)


# =========================================================================
#  WALL HELPERS  (walls with real door/arch openings)
# =========================================================================
## Build a wall along Z with rectangular holes expressed in world x/y.
## holes: Array of Rect2(x, y, width, height).
func _wall_z_holes(z: float, x0: float, x1: float, y0: float, y1: float,
		holes: Array, mat: Material = null, thick := 0.26) -> void:
	var ys: Array[float] = [y0, y1]
	for h in holes:
		var r: Rect2 = h
		ys.append(clampf(r.position.y, y0, y1))
		ys.append(clampf(r.end.y, y0, y1))
	ys.sort()
	for i in ys.size() - 1:
		var ya := ys[i]
		var yb := ys[i + 1]
		if yb - ya < 0.002:
			continue
		var gaps: Array[Vector2] = []
		for h in holes:
			var r: Rect2 = h
			if r.position.y <= ya + 0.002 and r.end.y >= yb - 0.002:
				gaps.append(Vector2(clampf(r.position.x, x0, x1),
					clampf(r.end.x, x0, x1)))
		gaps.sort_custom(func(a, b): return a.x < b.x)
		var cursor := x0
		for g in gaps:
			if g.x > cursor + 0.002:
				_wall_z(z, cursor, g.x, ya, yb - ya, mat, thick)
			cursor = maxf(cursor, g.y)
		if cursor < x1 - 0.002:
			_wall_z(z, cursor, x1, ya, yb - ya, mat, thick)


## Build a wall along X with holes expressed in world z/y.
func _wall_x_holes(x: float, z0: float, z1: float, y0: float, y1: float,
		holes: Array, mat: Material = null, thick := 0.26) -> void:
	var ys: Array[float] = [y0, y1]
	for h in holes:
		var r: Rect2 = h
		ys.append(clampf(r.position.y, y0, y1))
		ys.append(clampf(r.end.y, y0, y1))
	ys.sort()
	for i in ys.size() - 1:
		var ya := ys[i]
		var yb := ys[i + 1]
		if yb - ya < 0.002:
			continue
		var gaps: Array[Vector2] = []
		for h in holes:
			var r: Rect2 = h
			if r.position.y <= ya + 0.002 and r.end.y >= yb - 0.002:
				gaps.append(Vector2(clampf(r.position.x, z0, z1),
					clampf(r.end.x, z0, z1)))
		gaps.sort_custom(func(a, b): return a.x < b.x)
		var cursor := z0
		for g in gaps:
			if g.x > cursor + 0.002:
				_wall_x(x, cursor, g.x, ya, yb - ya, mat, thick)
			cursor = maxf(cursor, g.y)
		if cursor < z1 - 0.002:
			_wall_x(x, cursor, z1, ya, yb - ya, mat, thick)


func _slab_floor(center: Vector3, size: Vector3, mat: Material) -> void:
	_solid(center, size, mat)


func _palace_railing_z(z: float, x0: float, x1: float, y: float) -> void:
	_deco(Vector3((x0 + x1) * 0.5, y + 1.02, z),
		Vector3(absf(x1 - x0), 0.09, 0.11), _mats["wood_light"])
	_deco(Vector3((x0 + x1) * 0.5, y + 0.20, z),
		Vector3(absf(x1 - x0), 0.07, 0.09), _mats["wood_dark"])
	var x := x0
	while x <= x1 + 0.001:
		_deco(Vector3(x, y + 0.56, z), Vector3(0.055, 0.88, 0.055),
			_mats["wood_dark"])
		x += 0.55
	_newel(Vector3(x0, y, z))
	_newel(Vector3(x1, y, z))
	_blocker(Vector3((x0 + x1) * 0.5, y + 0.62, z),
		Vector3(absf(x1 - x0), 1.2, 0.10))


func _palace_railing_x(x: float, z0: float, z1: float, y: float) -> void:
	_deco(Vector3(x, y + 1.02, (z0 + z1) * 0.5),
		Vector3(0.11, 0.09, absf(z1 - z0)), _mats["wood_light"])
	_deco(Vector3(x, y + 0.20, (z0 + z1) * 0.5),
		Vector3(0.09, 0.07, absf(z1 - z0)), _mats["wood_dark"])
	var z := z0
	while z <= z1 + 0.001:
		_deco(Vector3(x, y + 0.56, z), Vector3(0.055, 0.88, 0.055),
			_mats["wood_dark"])
		z += 0.55
	_newel(Vector3(x, y, z0))
	_newel(Vector3(x, y, z1))
	_blocker(Vector3(x, y + 0.62, (z0 + z1) * 0.5),
		Vector3(0.10, 1.2, absf(z1 - z0)))


func _palace_pillar(pos: Vector3, height: float, thickness: float) -> void:
	_solid(pos + Vector3(0.0, height * 0.5, 0.0),
		Vector3(thickness, height, thickness), _mats["wood_dark"])
	for y in [0.20, height - 0.22]:
		_deco(pos + Vector3(0.0, y, 0.0),
			Vector3(thickness + 0.42, 0.34, thickness + 0.42),
			_mats["wood_light"])
		_deco(pos + Vector3(0.0, y + 0.20, 0.0),
			Vector3(thickness + 0.24, 0.06, thickness + 0.24),
			_mats["brass"])
	for k in 3:
		var yy := height * (0.30 + float(k) * 0.17)
		_deco(pos + Vector3(0.0, yy, 0.0),
			Vector3(thickness + 0.08, 0.045, thickness + 0.08),
			_mats["wood_light"])


func _palace_chandelier(pos: Vector3, ring: float, energy: float,
		shadows := false) -> void:
	var chain_top := Vector3(pos.x, HALL_H - 0.1, pos.z)
	_cyl((chain_top + pos) * 0.5, 0.014, chain_top.y - pos.y, _mats["iron"])
	_cyl(pos + Vector3(0.0, 0.04, 0.0), 0.10, 0.28, _mats["brass"])
	var ring_mesh := _torus(pos, maxf(ring - 0.035, 0.08), ring + 0.035,
		_mats["brass"])
	ring_mesh.rotation_degrees.y = 0.0
	for i in 8:
		var a := TAU * float(i) / 8.0
		_sphere(pos + Vector3(cos(a) * ring, -0.06, sin(a) * ring),
			0.055, _mats["flame"])
	var l := _lamp_light(pos + Vector3(0.0, -0.14, 0.0), energy,
		Color(1.0, 0.66, 0.34), 16.0)
	l.shadow_enabled = shadows


# =========================================================================
#  SHELL  -  walls, roof slabs and the palace silhouette
# =========================================================================
func _build_shell() -> void:
	var plaster: Material = _mats["plaster"]
	var plaster_dark: Material = _mats["plaster_dark"]
	var dark: Material = _mats["wood_dark"]
	var stone: Material = _mats["stone_b"]

	# One continuous ground slab under the whole haveli.
	_solid(Vector3(0.0, -0.16, (PAL_ZB + PAL_ZF) * 0.5),
		Vector3(53.9, 0.32, 34.9), _mats["stone_a"])

	# ---- front elevation ------------------------------------------------
	# The hall is full height; the dining and bedroom wings are single
	# storey at the front, leaving the hall proud of them.
	_wall_z_holes(HALL_ZF, HALL_XW, HALL_XE, 0.0, HALL_H,
		[Rect2(-1.8, 0.0, 3.6, 3.0)], plaster, 0.34)
	_wall_z(PAL_ZF, PAL_XW, HALL_XW, 0.0, LOW_H, plaster, 0.34)
	_wall_z(PAL_ZF, HALL_XE, PAL_XE, 0.0, LOW_H, plaster, 0.34)

	# ---- outer side walls ----------------------------------------------
	_wall_x(PAL_XW, PAL_ZB, PAL_ZF, 0.0, LOW_H, plaster, 0.36)
	_wall_x(PAL_XE, PAL_ZB, PAL_ZF, 0.0, LOW_H, plaster, 0.36)

	# ---- rear wall ------------------------------------------------------
	_wall_z(PAL_ZB, PAL_XW, STAIR_XW, 0.0, LOW_H, plaster, 0.36)
	_wall_z(PAL_ZB, STAIR_XE, PAL_XE, 0.0, LOW_H, plaster, 0.36)
	_wall_z(PAL_ZB, STAIR_XW, STAIR_XE, 0.0, TOWER_H, plaster, 0.40)

	# ---- rear wing partitions ------------------------------------------
	_wall_x(KIT_XE, PAL_ZB, CORR_ZB, 0.0, LOW_H, plaster, 0.28)
	_wall_x(POOJA_XE, PAL_ZB, CORR_ZB, 0.0, LOW_H, plaster, 0.28)
	# The stair tower has its own full-height side walls.
	_wall_x(STAIR_XW, PAL_ZB, CORR_ZB, 0.0, TOWER_H, plaster, 0.30)
	_wall_x(STAIR_XE, PAL_ZB, CORR_ZB, 0.0, TOWER_H, plaster, 0.30)

	# Rear-wing front wall, carried up to the gallery roof. Ground-floor
	# doors sit under the long upper gallery.
	_wall_z_holes(CORR_ZB, PAL_XW, STAIR_XW, 0.0, GALLERY_H, [
		Rect2(-22.0, 0.0, 1.8, 3.0),   # kitchen
		Rect2(-10.0, 0.0, 1.8, 3.0),   # tantra
	], plaster, 0.30)
	_wall_z_holes(CORR_ZB, STAIR_XE, PAL_XE, 0.0, GALLERY_H, [
		Rect2(7.0, 0.0, 1.8, 3.0),     # pooja
		Rect2(20.0, 0.0, 1.8, 3.0),    # guest
	], plaster, 0.30)

	# Stair-tower front: a wide ground arch and the upper opening onto
	# the gallery.
	_wall_z_holes(CORR_ZB, STAIR_XW, STAIR_XE, 0.0, TOWER_H, [
		Rect2(-1.5, 0.0, 3.0, 3.0),
		Rect2(-2.4, LOW_H, 4.8, 2.6),
	], plaster, 0.30)

	# ---- hall shell -----------------------------------------------------
	# Hall back wall: two grand ground arches flank the mandir, two upper
	# openings join the north balcony to the gallery.
	_wall_z_holes(HALL_ZB, HALL_XW, HALL_XE, 0.0, HALL_H, [
		Rect2(-9.6, 0.0, 3.2, 4.6),
		Rect2(6.4, 0.0, 3.2, 4.6),
		Rect2(-10.2, LOW_H, 3.4, 2.6),
		Rect2(6.8, LOW_H, 3.4, 2.6),
	], plaster, 0.30)

	# Hall side walls. The dining and bedroom doors are 3.6 m wide and
	# 3.0 m tall double leaves.
	_wall_x_holes(HALL_XW, HALL_ZB, HALL_ZF, 0.0, HALL_H,
		[Rect2(1.6, 0.0, 3.6, 3.0)], plaster, 0.30)
	_wall_x_holes(HALL_XE, HALL_ZB, HALL_ZF, 0.0, HALL_H,
		[Rect2(1.6, 0.0, 3.6, 3.0)], plaster, 0.30)

	# Wing walls against the corridor.
	_wall_z_holes(HALL_ZB, PAL_XW, HALL_XW, 0.0, GALLERY_H,
		[Rect2(-20.6, 0.0, 1.8, 3.0)], plaster, 0.30)
	_wall_z_holes(HALL_ZB, HALL_XE, PAL_XE, 0.0, HALL_H, [
		Rect2(20.0, 0.0, 1.8, 3.0),          # ground bedroom service door
		Rect2(20.0, LOW_H, 1.8, 2.7),        # upper bedroom door
	], plaster, 0.30)

	# ---- upper floor outer walls ---------------------------------------
	# Upper bedroom above the east wing.
	_wall_z(PAL_ZF, HALL_XE, PAL_XE, LOW_H, HALL_H - LOW_H, plaster, 0.34)
	_wall_x(PAL_XE, HALL_ZB, PAL_ZF, LOW_H, HALL_H - LOW_H, plaster, 0.36)
	# Gallery side walls and the west-side wall above the dining roof.
	_wall_x(PAL_XW, CORR_ZB, HALL_ZB, LOW_H, GALLERY_H - LOW_H,
		plaster, 0.36)
	_wall_x(PAL_XE, CORR_ZB, HALL_ZB, LOW_H, GALLERY_H - LOW_H,
		plaster, 0.36)
	# Gallery south wall over the dining wing (windows, no doors).
	_deco(Vector3(-18.9, LOW_H + 0.10, HALL_ZB + 0.16),
		Vector3(15.5, 0.16, 0.16), plaster_dark)
	_deco(Vector3(-18.9, GALLERY_H - 0.12, HALL_ZB + 0.16),
		Vector3(15.5, 0.14, 0.16), plaster_dark)

	# ---- roof / floor slabs --------------------------------------------
	var wood_slab: Material = _mats["wood"]
	var roof_mat: Material = _mats["wood_dark"]
	# Single-storey roofs (also ceilings).
	_solid(Vector3(-18.925, LOW_H - 0.16, 0.0),
		Vector3(15.55, 0.32, 18.3), roof_mat)
	_solid(Vector3(-15.05, LOW_H - 0.16, REAR_MID_Z),
		Vector3(23.3, 0.32, 12.0), roof_mat)
	_solid(Vector3(15.05, LOW_H - 0.16, REAR_MID_Z),
		Vector3(23.3, 0.32, 12.0), roof_mat)
	# Floor of the upper bedroom, and the long gallery over the corridor.
	_solid(Vector3(18.925, LOW_H - 0.16, 0.0),
		Vector3(15.55, 0.32, 18.3), wood_slab)
	_solid(Vector3(0.0, LOW_H - 0.16, -11.225),
		Vector3(53.4, 0.32, 4.15), wood_slab)
	# Hall roof, upper bedroom roof, gallery roof, stair tower roof.
	_solid(Vector3(0.0, HALL_H - 0.15, 0.0),
		Vector3(22.6, 0.32, 18.6), roof_mat)
	_solid(Vector3(18.925, HALL_H - 0.15, 0.0),
		Vector3(15.55, 0.32, 18.3), roof_mat)
	_solid(Vector3(0.0, GALLERY_H - 0.15, -11.225),
		Vector3(53.4, 0.32, 4.15), roof_mat)
	_solid(Vector3(0.0, TOWER_H - 0.15, REAR_MID_Z),
		Vector3(6.8, 0.32, 12.0), roof_mat)

	# ---- balcony floors overlooking the hall ---------------------------
	_solid(Vector3(0.0, LOW_H - 0.16, -7.825),
		Vector3(22.3, 0.32, 2.65), wood_slab)
	_solid(Vector3(-9.825, LOW_H - 0.16, 1.325),
		Vector3(2.65, 0.32, 15.65), wood_slab)
	_wood_floor(Rect2(-11.15, -9.15, 22.3, 2.65),
		_mats["floor_a"], _mats["floor_b"], LOW_H + 0.012)
	_wood_floor(Rect2(-11.15, -6.5, 2.65, 15.65),
		_mats["floor_b"], _mats["floor_c"], LOW_H + 0.012)

	# Gallery railings. The west balcony joins the north balcony in the
	# open corner at x = -8.5.
	_palace_railing_z(-6.5, -8.5, 11.15, LOW_H)
	_palace_railing_x(-8.5, -6.5, 9.15, LOW_H)

	# Four thick, widely spaced pillars carry the hall. Two more slim
	# gallery posts sit tight to the balcony edges.
	_palace_pillar(Vector3(-6.6, 0.0, -6.7), HALL_H, 0.86)
	_palace_pillar(Vector3(6.6, 0.0, -6.7), HALL_H, 0.86)
	_palace_pillar(Vector3(-6.6, 0.0, 4.6), HALL_H, 0.86)
	_palace_pillar(Vector3(6.6, 0.0, 4.6), HALL_H, 0.86)
	_palace_pillar(Vector3(-8.62, 0.0, 3.6), LOW_H, 0.44)

	# Hall ceiling beams and the gallery fascia.
	for bz in [-6.6, -3.8, -1.0, 1.8, 4.6, 7.4]:
		_deco(Vector3(0.0, HALL_H - 0.40, bz),
			Vector3(22.0, 0.30, 0.26), dark)
	for bx in [-8.6, -4.3, 0.0, 4.3, 8.6]:
		_deco(Vector3(bx, HALL_H - 0.56, 0.0),
			Vector3(0.22, 0.22, 18.0), dark)
	_deco(Vector3(0.0, LOW_H - 0.30, -6.48),
		Vector3(22.3, 0.28, 0.16), dark)
	_deco(Vector3(-8.48, LOW_H - 0.30, 1.3),
		Vector3(0.16, 0.28, 15.65), dark)

	# ---- trims and cornices --------------------------------------------
	_skirting_z(HALL_ZB + 0.17, HALL_XW, HALL_XE, 0.0)
	_skirting_z(HALL_ZF - 0.17, HALL_XW, HALL_XE, 0.0)
	_skirting_x(HALL_XW + 0.17, HALL_ZB, HALL_ZF, 0.0)
	_skirting_x(HALL_XE - 0.17, HALL_ZB, HALL_ZF, 0.0)
	_deco(Vector3(0.0, LOW_H + 0.08, HALL_ZF - 0.19),
		Vector3(22.0, 0.16, 0.12), _mats["wood_light"])
	_deco(Vector3(0.0, LOW_H + 0.08, HALL_ZB + 0.19),
		Vector3(22.0, 0.16, 0.12), _mats["wood_light"])

	# Roof parapets give the silhouette a real haveli edge.
	_wall_z(PAL_ZF, HALL_XW, HALL_XE, HALL_H, 0.55, plaster_dark, 0.30)
	_wall_z(PAL_ZB, PAL_XW, PAL_XE, LOW_H, 0.50, plaster_dark, 0.30)
	_wall_x(PAL_XW, PAL_ZB, PAL_ZF, LOW_H, 0.50, plaster_dark, 0.30)
	_wall_x(PAL_XE, PAL_ZB, PAL_ZF, LOW_H, 0.50, plaster_dark, 0.30)
	_wall_x(PAL_XW, CORR_ZB, HALL_ZB, GALLERY_H, 0.55, plaster_dark, 0.26)
	_wall_x(PAL_XE, CORR_ZB, HALL_ZB, GALLERY_H, 0.55, plaster_dark, 0.26)
	_wall_z(PAL_ZB, STAIR_XW, STAIR_XE, TOWER_H, 0.62, plaster_dark, 0.30)


# =========================================================================
#  FLOORS
# =========================================================================
func _build_floors() -> void:
	var a: Material = _mats["floor_b"]
	var b: Material = _mats["floor_a"]
	var c: Material = _mats["floor_c"]

	# Ground floor, room by room. The hall keeps the original board floor.
	_wood_floor(Rect2(HALL_XW, HALL_ZB, 22.3, 18.3), a, b)
	_wood_floor(Rect2(PAL_XW, HALL_ZB, 15.55, 18.3), b, c)
	_wood_floor(Rect2(HALL_XE, HALL_ZB, 15.55, 18.3), b, a)
	_tile_floor(Rect2(PAL_XW, CORR_ZB, 53.4, 4.15),
		_mats["stone_a"], _mats["stone_b"], 0.012, 0.95)
	_tile_floor(Rect2(PAL_XW, PAL_ZB, 14.0, 12.0),
		_mats["stone_a"], _mats["stone_b"], 0.012, 0.8)
	_tile_floor(Rect2(TANTRA_XW, PAL_ZB, 9.3, 12.0),
		_mats["soot"], _mats["tantra"], 0.012, 0.72)
	_tile_floor(Rect2(STAIR_XW, PAL_ZB, 6.8, 12.0),
		_mats["stone_b"], _mats["stone_a"], 0.012, 0.75)
	_tile_floor(Rect2(POOJA_XW, PAL_ZB, 9.3, 12.0),
		_mats["marble"], _mats["marble"], 0.012, 1.0)
	_tile_floor(Rect2(GUEST_XW, PAL_ZB, 14.0, 12.0),
		_mats["stone_a"], _mats["stone_b"], 0.012, 0.8)

	# Gallery and upper bedroom boards.
	_wood_floor(Rect2(PAL_XW, CORR_ZB, 53.4, 4.15), a, b, LOW_H + 0.012)
	_wood_floor(Rect2(HALL_XE, HALL_ZB, 15.55, 18.3), a, b,
		LOW_H + 0.012)

	# Long red runners: hall processional, corridor, and upper gallery.
	_rug(Vector3(0.0, 0.022, -0.3), Vector2(3.3, 15.6),
		_mats["rug"], _mats["rug_inner"])
	_rug(Vector3(0.0, 0.022, -11.225), Vector2(2.2, 3.9),
		_mats["rug_inner"], _mats["rug"])
	_rug(Vector3(0.0, LOW_H + 0.024, -11.225), Vector2(2.0, 3.7),
		_mats["rug"], _mats["rug_inner"])
	# Palace walkway (full length) rather than a narrow domestic runner.
	_deco(Vector3(0.0, 0.024, -11.225), Vector3(49.0, 0.010, 1.9),
		_mats["rug"])
	_deco(Vector3(0.0, 0.030, -11.225), Vector3(48.6, 0.010, 1.5),
		_mats["rug_inner"])

	# Threshold strips at the great doors.
	_deco(Vector3(0.0, 0.025, HALL_ZF), Vector3(3.7, 0.05, 0.44), _mats["wood_dark"])
	_deco(Vector3(HALL_XW, 0.025, 3.4), Vector3(0.44, 0.05, 3.7), _mats["wood_dark"])
	_deco(Vector3(HALL_XE, 0.025, 3.4), Vector3(0.44, 0.05, 3.7), _mats["wood_dark"])


# =========================================================================
#  GRAND U-SHAPED STAIR
# =========================================================================
func _build_stairs() -> void:
	var rise := STAIR_RISE
	var run := STAIR_RUN
	var angle := rad_to_deg(atan(rise / run))
	var flight_len := sqrt(rise * rise + run * run)
	var half := STAIR_INNER * 0.5
	var c1 := Vector3(-half * 0.5, rise * 0.5,
		(STAIR_BOTTOM + STAIR_MID_Z) * 0.5)
	var c2 := Vector3(half * 0.5, rise + rise * 0.5,
		(STAIR_MID_B + STAIR_TOP_Z) * 0.5)

	# Collision ramps. Each flight is half the stair width so the two runs
	# sit side by side instead of stacking on top of each other. Both are
	# 31.7 degrees, comfortably under 45.
	var flight_w := half
	_solid_rot(c1 + Vector3(0.0, 0.02, 0.0),
		Vector3(flight_w, 0.20, flight_len), _mats["wood_dark"],
		Vector3(angle, 0.0, 0.0))
	_solid_rot(c2 + Vector3(0.0, 0.02, 0.0),
		Vector3(flight_w, 0.20, flight_len), _mats["wood_dark"],
		Vector3(-angle, 0.0, 0.0))

	# Bottom, mid and top landing slabs.
	_solid(Vector3(0.0, 0.15, (STAIR_LAND_Z + STAIR_BOTTOM) * 0.5),
		Vector3(6.4, 0.30, absf(STAIR_BOTTOM - STAIR_LAND_Z)),
		_mats["stone_b"])
	_solid(Vector3(0.0, 3.25, (STAIR_MID_Z + STAIR_MID_B) * 0.5),
		Vector3(6.4, 0.30, absf(STAIR_MID_B - STAIR_MID_Z)),
		_mats["wood"])
	_solid(Vector3(0.0, LOW_H - 0.15, (STAIR_TOP_Z + STAIR_LAND_Z) * 0.5),
		Vector3(6.4, 0.30, STAIR_LAND_Z - STAIR_TOP_Z), _mats["wood"])
	# Walk-forward top landing nosing and a rail on the open edge.
	_deco(Vector3(0.0, LOW_H - 0.02, STAIR_TOP_Z + 0.04),
		Vector3(6.2, 0.06, 0.12), _mats["wood_light"])

	var steps := 16
	var step_run := run / float(steps)
	var step_rise := rise / float(steps)
	var wood: Material = _mats["wood"]
	var light: Material = _mats["wood_light"]
	var dark: Material = _mats["wood_dark"]

	for i in steps:
		# First flight: south to north on the west side.
		var z1 := STAIR_BOTTOM - (float(i) + 0.5) * step_run
		var y1 := (float(i) + 0.5) * step_rise
		_deco(Vector3(-half * 0.5, y1, z1),
			Vector3(half, step_rise, step_run + 0.02), wood)
		_deco(Vector3(-half * 0.5, y1 + step_rise * 0.5 + 0.012,
			z1 + step_run * 0.42),
			Vector3(half, 0.026, 0.045), light)
		# Second flight: north to south on the east side.
		var z2 := STAIR_MID_B + (float(i) + 0.5) * step_run
		var y2 := rise + (float(i) + 0.5) * step_rise
		_deco(Vector3(half * 0.5, y2, z2),
			Vector3(half, step_rise, step_run + 0.02), wood)
		_deco(Vector3(half * 0.5, y2 + step_rise * 0.5 + 0.012,
			z2 - step_run * 0.42),
			Vector3(half, 0.026, 0.045), light)

	# Stringers and handrails.
	for sx in [-half - 0.08, -0.08, 0.08, half + 0.08]:
		var rail_y := rise * 0.5 + 1.00
		var rail_z := (STAIR_BOTTOM + STAIR_MID_Z) * 0.5
		var rail := _deco(Vector3(sx, rail_y, rail_z),
			Vector3(0.055, 0.075, flight_len), light)
		rail.rotation_degrees.x = angle
		var stringer := _deco(Vector3(sx, rise * 0.5 + 0.02,
			rail_z), Vector3(0.075, 0.30, flight_len), dark)
		stringer.rotation_degrees.x = angle
	for sx in [half + 0.08, 0.08, -0.08, -half - 0.08]:
		var rail_y2 := rise + rise * 0.5 + 1.00
		var rail_z2 := (STAIR_MID_B + STAIR_TOP_Z) * 0.5
		var rail2 := _deco(Vector3(sx, rail_y2, rail_z2),
			Vector3(0.055, 0.075, flight_len), light)
		rail2.rotation_degrees.x = -angle
		var stringer2 := _deco(Vector3(sx, rise + rise * 0.5 + 0.02,
			rail_z2), Vector3(0.075, 0.30, flight_len), dark)
		stringer2.rotation_degrees.x = -angle

	# Posts at the bottom, mid landing and top. The centre line stays open.
	for sx in [-half - 0.08, half + 0.08]:
		_cyl(Vector3(sx, rise * 0.35, STAIR_BOTTOM + 0.12),
			0.055, rise * 0.70, dark)
		_cyl(Vector3(sx, 3.40 + 0.55, STAIR_MID_Z - 0.08),
			0.055, 1.10, dark)
		_cyl(Vector3(sx, LOW_H + 0.55, STAIR_TOP_Z + 0.08),
			0.055, 1.10, dark)
		_sphere(Vector3(sx, LOW_H + 1.12, STAIR_TOP_Z + 0.08),
			0.075, _mats["brass"])

	# Central newel and a small shrine tucked under the mid landing.
	_cyl(Vector3(0.0, 1.70, STAIR_MID_Z - 0.10), 0.10, 3.40, dark)
	_sphere(Vector3(0.0, 3.45, STAIR_MID_Z - 0.10), 0.13, _mats["brass"])
	_lantern(Vector3(0.0, LOW_H - 0.9, -15.5), 1.0, 1.0, 8.0)
	_lantern(Vector3(0.0, 8.4, -16.0), 1.0, 0.9, 7.0)
	_lamp_light(Vector3(0.0, 4.7, -22.0), 0.8, Color(1.0, 0.55, 0.25), 3.5)

	# Under-stair clutter stays against the tower wall, never in the path.
	_deco(Vector3(-2.55, 0.42, -21.55), Vector3(0.85, 0.84, 1.10),
		_mats["wood_dark"])
	_deco(Vector3(-2.55, 0.87, -21.55), Vector3(0.95, 0.06, 1.18),
		_mats["wood_light"])
	_pot(Vector3(2.55, 0.0, -23.9), 0.22, 0.40, _mats["clay"])
	_pot(Vector3(2.92, 0.0, -23.6), 0.15, 0.30, _mats["clay"])


# =========================================================================
#  DOORS
# =========================================================================
func _grand_door(hinge: Vector3, yaw_deg: float, open: bool,
		open_angle := -98.0) -> void:
	var frame := Node3D.new()
	frame.position = hinge
	frame.rotation_degrees.y = yaw_deg
	add_child(frame)
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	_deco(Vector3(-0.07, 1.55, 0.0), Vector3(0.14, 3.10, 0.38), wd, frame)
	_deco(Vector3(1.87, 1.55, 0.0), Vector3(0.14, 3.10, 0.38), wd, frame)
	_deco(Vector3(0.90, 3.08, 0.0), Vector3(2.08, 0.16, 0.40), wl, frame)
	_deco(Vector3(0.90, 2.83, 0.0), Vector3(1.80, 0.30, 0.10), wd, frame)
	_deco(Vector3(0.90, 0.03, 0.0), Vector3(1.80, 0.06, 0.42), wd, frame)
	for sx in [0.08, 1.72]:
		_deco(Vector3(sx, 1.55, 0.19), Vector3(0.09, 2.9, 0.05),
			_mats["brass"], frame)

	var d := DOOR.instantiate() as HauntedDoor
	d.position = hinge
	d.rotation_degrees.y = yaw_deg
	d.open_angle = open_angle
	d.collision_layer = 257
	d.is_open = open
	add_child(d)
	_doors.append(d)


func _build_doors() -> void:
	# --- main entrance, two 1.8 m leaves --------------------------------
	var left := DOOR.instantiate() as HauntedDoor
	left.position = Vector3(-1.8, 0.0, HALL_ZF)
	left.open_angle = -150.0
	left.collision_layer = 257
	left.is_open = not _live
	add_child(left)
	_doors.append(left)
	_blood_sign(left, "A GAME BY")

	var right := DOOR.instantiate() as HauntedDoor
	right.position = Vector3(1.8, 0.0, HALL_ZF)
	right.rotation_degrees.y = 180.0
	right.open_angle = 150.0
	right.collision_layer = 257
	right.is_open = not _live
	add_child(right)
	_doors.append(right)
	_blood_sign(right, "NISHANTH")

	# Great entrance architrave and toran.
	var wl: Material = _mats["wood_light"]
	var wd: Material = _mats["wood_dark"]
	_deco(Vector3(-1.95, 1.7, HALL_ZF + 0.20), Vector3(0.22, 3.4, 0.22), wl)
	_deco(Vector3(1.95, 1.7, HALL_ZF + 0.20), Vector3(0.22, 3.4, 0.22), wl)
	_deco(Vector3(0.0, 3.45, HALL_ZF + 0.20), Vector3(4.1, 0.24, 0.22), wl)
	_deco(Vector3(0.0, 3.12, HALL_ZF + 0.14), Vector3(3.7, 0.08, 0.14),
		_mats["brass"])
	_garland(Vector3(0.0, 3.00, HALL_ZF + 0.12), 3.4, 0.30)
	_garland(Vector3(0.0, 2.98, HALL_ZF + 0.36), 3.4, 0.28)
	_sconce(Vector3(-3.55, 2.10, HALL_ZF + 0.20), 0.85)
	_sconce(Vector3(3.55, 2.10, HALL_ZF + 0.20), 0.85)

	# --- hall to dining, two leaves -------------------------------------
	_grand_door(Vector3(HALL_XW, 0.0, 1.6), -90.0, not _live, -100.0)
	_grand_door(Vector3(HALL_XW, 0.0, 5.2), 90.0, not _live, 100.0)

	# --- hall to ground bedroom, two leaves -----------------------------
	_grand_door(Vector3(HALL_XE, 0.0, 1.6), -90.0, not _live, -100.0)
	_grand_door(Vector3(HALL_XE, 0.0, 5.2), 90.0, not _live, 100.0)

	# --- room and service doors -----------------------------------------
	_grand_door(Vector3(-20.6, 0.0, HALL_ZB), 0.0, not _live)      # dining / corridor
	_grand_door(Vector3(20.0, 0.0, HALL_ZB), 0.0, not _live)       # bedroom / corridor
	_grand_door(Vector3(-22.0, 0.0, CORR_ZB), 0.0, false)          # kitchen
	_grand_door(Vector3(-10.0, 0.0, CORR_ZB), 0.0, false)          # tantra
	_grand_door(Vector3(7.0, 0.0, CORR_ZB), 0.0, false)            # pooja
	_grand_door(Vector3(20.0, 0.0, CORR_ZB), 0.0, false)           # guest
	_grand_door(Vector3(20.0, LOW_H, HALL_ZB), 0.0, not _live)     # upper bedroom

	# Stair tower entrance: an open arch, no door. The tower must stay a
	# clear walk-forward space at the foot of the first flight.
	_deco(Vector3(0.0, 3.12, CORR_ZB + 0.18), Vector3(3.6, 0.20, 0.22), wd)
	_deco(Vector3(-1.64, 1.55, CORR_ZB + 0.18), Vector3(0.18, 3.1, 0.22), wl)
	_deco(Vector3(1.64, 1.55, CORR_ZB + 0.18), Vector3(0.18, 3.1, 0.22), wl)
	_garland(Vector3(0.0, 3.00, CORR_ZB + 0.30), 2.8, 0.22)
	_sconce(Vector3(-2.55, 2.2, CORR_ZB + 0.20), 0.65)
	_sconce(Vector3(2.55, 2.2, CORR_ZB + 0.20), 0.65)


# =========================================================================
#  CENTRAL HALL  -  the preserved 22.3 x 18.3 m heart of the haveli
# =========================================================================
func _build_living() -> void:
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	var marble: Material = _mats["marble"]
	var brass: Material = _mats["brass"]

	# ---- royal dais against the north wall ----------------------------
	# The gods have moved to the pooja room. The hall's north end is now a
	# durbar dais: two high-backed chairs, a low table and the house portrait.
	_solid(Vector3(0.0, 0.18, -8.05), Vector3(5.6, 0.36, 1.9), marble)
	_solid(Vector3(0.0, 0.09, -7.10), Vector3(5.9, 0.18, 0.34), marble)
	_solid(Vector3(0.0, 0.045, -6.86), Vector3(6.2, 0.09, 0.28), marble)
	_deco(Vector3(0.0, 0.38, -8.05), Vector3(5.2, 0.03, 1.6),
		_mats["cloth_red"])

	# A tall carved screen, still in the original language of the hall.
	_deco(Vector3(0.0, 3.05, -8.60), Vector3(5.0, 6.10, 0.24), wd)
	_deco(Vector3(0.0, 2.65, -8.42), Vector3(3.8, 3.9, 0.05),
		_mats["dark"])
	_deco(Vector3(0.0, 5.95, -8.46), Vector3(5.5, 0.24, 0.42), wl)
	for sx in [-2.15, 2.15]:
		_deco(Vector3(sx, 3.05, -8.35), Vector3(0.24, 6.10, 0.24), wl)
		for k in 3:
			_deco(Vector3(sx, 1.2 + float(k) * 1.8, -8.20),
				Vector3(0.34, 0.10, 0.12), brass)
	_deco(Vector3(0.0, 5.55, -8.36), Vector3(4.6, 0.13, 0.14), brass)

	# The empty throne dais.
	_chair(Vector3(-1.15, 0.40, -8.10), 180.0, wd)
	_chair(Vector3(1.15, 0.40, -8.10), 180.0, wd)
	_table(Vector3(0.0, 0.40, -7.55), Vector2(1.05, 0.62), 0.52, wd)
	_candle(Vector3(-0.26, 0.95, -7.55), 0.24)
	_candle(Vector3(0.26, 0.95, -7.55), 0.24)
	_rich_photo_frame(Vector3(0.0, 3.55, -8.28), 0.0, 2.15, 2.85,
		"royal_couple_sepia", "THE THRONE OF KAMLA", true, true)
	_lamp_light(Vector3(0.0, 3.9, -7.9), 0.90,
		Color(1.0, 0.60, 0.28), 8.0)

	# ---- sparse seating, pushed to the front edges ---------------------
	_diwan(Vector3(-7.4, 0.0, 8.20), 180.0, 4.6)
	_diwan(Vector3(7.4, 0.0, 8.20), 180.0, 4.6)
	_table(Vector3(-9.9, 0.0, 6.0), Vector2(1.1, 1.1), 0.55)
	_diya(Vector3(-9.9, 0.60, 6.0), 1.3)
	_table(Vector3(9.9, 0.0, 6.0), Vector2(1.1, 1.1), 0.55)
	_diya(Vector3(9.9, 0.60, 6.0), 1.3)

	# ---- photographs and the family clock ------------------------------
	_rich_photo_frame(Vector3(10.98, 3.45, -3.0), -90.0, 2.30, 1.36,
		"royal_couple_sepia", "THE ROYAL COUPLE", true, true)
	_rich_photo_frame(Vector3(-10.98, 3.45, -3.0), 90.0, 2.10, 1.24,
		"royal_couple_green", "THE HOUSE OF KAMLA", true, true)
	_rich_photo_frame(Vector3(-5.6, 2.75, 8.97), 180.0, 1.10, 1.55,
		"girl_ghost_green_portrait", "THE GIRL IN THE MIST", true, false)
	_rich_photo_frame(Vector3(5.6, 2.75, 8.97), 180.0, 1.00, 1.35,
		"01_royal_couple_king_queen", "KING & QUEEN", true, false)
	_wall_clock(Vector3(8.2, 3.30, 8.95), 180.0)

	# ---- light ---------------------------------------------------------
	_palace_chandelier(Vector3(0.0, 10.2, 2.4), 1.25, 2.3, true)
	_palace_chandelier(Vector3(0.0, 9.7, -4.3), 0.95, 1.8, false)
	_lantern(Vector3(-7.9, HALL_H - 0.4, 5.0), 2.6, 1.0, 10.0)
	_lantern(Vector3(7.9, HALL_H - 0.4, 5.0), 2.6, 1.0, 10.0)
	_lantern(Vector3(-7.9, HALL_H - 0.4, -4.0), 2.6, 1.0, 10.0)
	_lantern(Vector3(7.9, HALL_H - 0.4, -4.0), 2.6, 1.0, 10.0)
	for sx in [-10.9, 10.9]:
		for sz in [-6.8, -1.0, 4.6]:
			_sconce(Vector3(sx, 3.2, sz), 0.55,
				Vector3(1.0 if sx < 0.0 else -1.0, 0.0, 0.0))
	_garland(Vector3(0.0, 4.52, -6.82), 5.4, 0.48)
	_lamp_light(Vector3(0.0, 3.4, -7.7), 1.25,
		Color(1.0, 0.58, 0.24), 7.0)
	# Broad fill so the double-height volume does not fall into black.
	_lamp_light(Vector3(-5.6, 4.0, 2.6), 0.85, Color(1.0, 0.64, 0.34), 16.0)
	_lamp_light(Vector3(5.6, 4.0, 2.6), 0.85, Color(1.0, 0.64, 0.34), 16.0)
	_lamp_light(Vector3(-5.6, 4.0, -4.6), 0.85, Color(1.0, 0.64, 0.34), 16.0)
	_lamp_light(Vector3(5.6, 4.0, -4.6), 0.85, Color(1.0, 0.64, 0.34), 16.0)

	# Subtle wear on the processional floor.
	for i in 5:
		_deco(Vector3(-1.2 + float(i) * 0.6, 0.026, 2.2 + float(i % 2) * 1.4),
			Vector3(0.05, 0.006, 1.2), _mats["soot"])


# =========================================================================
#  DINING WING  -  15.55 x 18.3 m, table held to the west edge
# =========================================================================
func _build_dining() -> void:
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	var brass: Material = _mats["brass"]

	_rug(Vector3(-23.8, 0.020, 0.0), Vector2(3.9, 9.2),
		_mats["rug"], _mats["rug_inner"])
	_table(Vector3(-23.8, 0.0, 0.0), Vector2(2.0, 7.6), 0.86)

	for z in [-3.1, -1.55, 0.0, 1.55, 3.1]:
		_chair(Vector3(-25.15, 0.0, z), 90.0)
		_chair(Vector3(-22.45, 0.0, z), -90.0)
	_chair(Vector3(-23.8, 0.0, -4.25), 0.0, wd)
	_chair(Vector3(-23.8, 0.0, 4.25), 180.0, wd)

	# Long sideboard on the north wall, far from the walking line.
	_cupboard(Vector3(-18.6, 0.0, -8.28), 0.0, 3.6, 1.45, 0.62, wd)
	_deco(Vector3(-20.25, 1.72, -8.20), Vector3(0.28, 0.46, 0.24), brass)
	_deco(Vector3(-16.95, 1.72, -8.20), Vector3(0.28, 0.46, 0.24), brass)
	_candle(Vector3(-19.7, 1.52, -8.18), 0.36)
	_candle(Vector3(-17.5, 1.52, -8.18), 0.28)
	_pot(Vector3(-24.8, 0.0, 6.2), 0.28, 0.55, _mats["brass"])

	# Tall dining-room frames.
	_rich_photo_frame(Vector3(-19.7, 3.15, -8.96), 0.0, 2.35, 1.40,
		"royal_couple_stylized", "THE LAST SUPPER", true, true)
	_rich_photo_frame(Vector3(-16.1, 2.95, -8.96), 0.0, 1.25, 1.70,
		"05_couple_ghost_haveli", "THE HAVELI COUPLE", true, false)
	_rich_photo_frame(Vector3(-26.48, 3.05, 3.5), 90.0, 1.45, 1.85,
		"04_queen_ghost_solo", "THE QUEEN", true, true)

	_palace_wing_chandelier(Vector3(-23.8, 4.9, 0.0), 1.0, 1.6)
	_lantern(Vector3(-16.5, LOW_H - 0.4, 2.5), 1.4, 0.9, 8.5)
	_lantern(Vector3(-16.5, LOW_H - 0.4, -5.0), 1.4, 0.9, 8.5)
	_sconce(Vector3(-26.2, 2.3, -2.5), 0.55, Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(-26.2, 2.3, 6.3), 0.55, Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(-15.0, 2.4, -8.75), 0.55, Vector3(0.0, 0.0, 1.0))
	_window(Vector3(-26.52, 2.6, 5.8), 90.0, 2.4, 2.2)
	_window(Vector3(-26.52, 2.6, -4.2), 90.0, 2.4, 2.2)
	_garland(Vector3(-19.7, 4.30, -8.85), 3.2, 0.36)
	_dining_gore_palace(Vector3(-23.8, 0.0, 0.0), 0.86, 7.6)


## The dinner the family never finished, scaled for the palace table.
func _dining_gore_palace(center: Vector3, top_y: float, length: float) -> void:
	var blood: Material = _mats["blood"]
	var meat: Material = _mats["meat"]
	var bone: Material = _mats["bone"]
	var plate: Material = _mats["cloth_cream"]
	var dark: Material = _mats["dark"]
	var skin: Material = _mats["skin"]

	# Plates and raw joints down both sides of the long table.
	for i in 5:
		var z := center.z - 3.1 + float(i) * 1.55
		for sx in [-0.62, 0.62]:
			var p := Vector3(center.x + sx, top_y + 0.035, z)
			_cyl(p, 0.17, 0.024, plate)
			_cyl(p + Vector3(0.0, 0.016, 0.0), 0.125, 0.008, blood)
			var chunk := _sphere(p + Vector3(0.0, 0.065, 0.0), 0.075, meat)
			chunk.scale = Vector3(1.3, 0.55, 0.95)
			_sphere(p + Vector3(0.03, 0.085, -0.03), 0.043, meat)

	# Central platter with the severed head, turned toward the hall door.
	var c := Vector3(center.x, top_y + 0.045, center.z + 0.55)
	_cyl(c, 0.58, 0.034, plate)
	_cyl(c + Vector3(0.0, 0.020, 0.0), 0.50, 0.014, blood)
	var haunch := _sphere(c + Vector3(-0.30, 0.11, -0.30), 0.115, meat)
	haunch.scale = Vector3(1.35, 0.65, 0.95)
	var handle := _cyl(c + Vector3(-0.43, 0.075, -0.37), 0.034,
		0.26, bone)
	handle.rotation_degrees.z = 68.0

	var head := Node3D.new()
	head.position = c + Vector3(0.0, 0.22, 0.0)
	head.rotation_degrees.y = 90.0
	add_child(head)
	var skull := _sphere(Vector3.ZERO, 0.20, skin, head)
	skull.scale = Vector3(0.92, 1.05, 0.94)
	var hair := _sphere(Vector3(0.0, 0.13, -0.07), 0.212, dark, head)
	hair.scale = Vector3(1.0, 0.78, 0.96)
	_deco(Vector3(0.0, -0.15, 0.06), Vector3(0.19, 0.12, 0.17), skin, head)
	for ex in [-0.065, 0.065]:
		_sphere(Vector3(ex, 0.042, 0.170), 0.032, dark, head)
		_sphere(Vector3(ex, 0.042, 0.186), 0.011,
			_emissive(Color(0.95, 0.72, 0.35), 2.0), head)
	_deco(Vector3(0.0, 0.010, 0.202), Vector3(0.052, 0.070, 0.06), skin, head)
	_deco(Vector3(0.0, -0.070, 0.188), Vector3(0.10, 0.020, 0.024), blood, head)
	_sphere(Vector3(0.035, -0.035, 0.180), 0.016, blood, head)
	_cyl(Vector3(0.0, -0.20, 0.025), 0.082, 0.12, blood, head)

	# Knife, candelabra and blood running off the table edge.
	var knife := _deco(Vector3(center.x + 0.72, top_y + 0.09, 2.9),
		Vector3(0.42, 0.016, 0.055), _mats["iron"])
	knife.rotation_degrees.y = 22.0
	_deco(Vector3(center.x + 0.89, top_y + 0.09, 2.86),
		Vector3(0.13, 0.035, 0.075), wd_dining())
	for i in 4:
		var drip := _deco(Vector3(center.x + 1.01, top_y - 0.24,
			2.1 + float(i) * 0.42), Vector3(0.020, 0.48 + 0.11 * float(i % 2), 0.020), blood)
		drip.rotation_degrees.z = 2.0 - float(i) * 1.5
	for i in 3:
		_cyl(Vector3(center.x - 0.55 + float(i) * 0.55, top_y + 0.19,
			center.z - 2.9), 0.018, 0.34, _mats["cloth_cream"])
		_sphere(Vector3(center.x - 0.55 + float(i) * 0.55, top_y + 0.38,
			center.z - 2.9), 0.030, _mats["flame"])


func wd_dining() -> Material:
	return _mats["wood_dark"]


# =========================================================================
#  KITCHEN  -  14 x 12 m; all work at the walls, centre clear
# =========================================================================
func _build_kitchen() -> void:
	var wd: Material = _mats["wood_dark"]
	var stone: Material = _mats["stone_b"]

	# Continuous west work counter.
	_deco(Vector3(-26.30, 0.48, -19.3), Vector3(0.78, 0.96, 10.4), wd)
	_deco(Vector3(-26.30, 0.98, -19.3), Vector3(0.86, 0.08, 10.5), stone)
	_blocker(Vector3(-26.30, 0.50, -19.3), Vector3(0.82, 1.0, 10.45))
	for z in [-23.5, -21.8, -20.1, -18.4, -16.7, -15.0]:
		_deco(Vector3(-25.88, 0.48, z), Vector3(0.03, 0.72, 1.42),
			_mats["wood"])
		_sphere(Vector3(-25.85, 0.55, z + 0.55), 0.026, _mats["brass"])
	_deco(Vector3(-26.30, 0.94, -20.2), Vector3(0.52, 0.07, 0.78),
		_mats["dark"])
	_cyl(Vector3(-26.22, 1.14, -20.2), 0.028, 0.28, _mats["brass"])

	# Chulha in the north-west corner with its chimney.
	_deco(Vector3(-24.7, 0.38, -24.55), Vector3(1.15, 0.76, 0.90),
		_mats["clay"])
	_deco(Vector3(-24.7, 0.79, -24.55), Vector3(1.06, 0.09, 0.80),
		_mats["soot"])
	_deco(Vector3(-24.7, 0.84, -24.55), Vector3(0.48, 0.05, 0.36),
		_mats["dark"])
	_cyl(Vector3(-25.10, 2.40, -24.60), 0.18, 3.20, _mats["soot"])
	_pot(Vector3(-24.7, 0.86, -24.55), 0.26, 0.30, _mats["copper"])

	# North shelf and hanging utensils.
	_deco(Vector3(-19.4, 1.72, -24.86), Vector3(5.3, 0.08, 0.34),
		_mats["wood"])
	for i in 6:
		_pot(Vector3(-21.6 + float(i) * 0.85, 1.78, -24.86),
			0.12 + 0.02 * float(i % 3), 0.22 + 0.04 * float(i % 2))
	for i in 5:
		_cyl(Vector3(-21.4 + float(i) * 0.88, 2.60, -24.72),
			0.13, 0.05, _mats["iron"])
		_deco(Vector3(-21.4 + float(i) * 0.88, 2.78, -24.72),
			Vector3(0.024, 0.30, 0.024), _mats["iron"])

	# Grain sacks and water pots in the east corner, clear of the door.
	for i in 3:
		var sack := _sphere(Vector3(-13.45, 0.32, -23.4 + float(i) * 0.62),
			0.30, _mats["cloth_cream"])
		sack.scale = Vector3(0.88, 1.15, 0.88)
		_deco(Vector3(-13.45, 0.62, -23.4 + float(i) * 0.62),
			Vector3(0.22, 0.07, 0.22), _mats["soil"])
	_pot(Vector3(-14.1, 0.0, -15.0), 0.30, 0.56, _mats["clay"])
	_pot(Vector3(-13.4, 0.0, -15.0), 0.23, 0.44, _mats["clay"])

	_rich_photo_frame(Vector3(-26.48, 3.0, -14.6), 90.0, 1.10, 1.45,
		"09_couple_ghost_civilian", "THE FAMILY", true, false)
	_window(Vector3(-26.52, 2.75, -17.0), 90.0, 1.8, 1.6)
	_chhajja(-26.70, 3.78, -17.0, 1.8)
	_palace_wing_chandelier(Vector3(-19.5, 4.7, -18.8), 0.9, 1.3)
	_lantern(Vector3(-23.8, LOW_H - 0.4, -15.2), 1.2, 0.85, 7.0)
	_sconce(Vector3(-21.0, 2.3, -24.78), 0.55, Vector3(0.0, 0.0, 1.0))
	_sconce(Vector3(-14.0, 2.3, -24.78), 0.55, Vector3(0.0, 0.0, 1.0))
	_garland(Vector3(-19.4, 3.20, -24.70), 4.6, 0.34)


func _palace_wing_chandelier(pos: Vector3, ring: float, energy: float) -> void:
	var top := Vector3(pos.x, LOW_H - 0.25, pos.z)
	_cyl((top + pos) * 0.5, 0.012, top.y - pos.y, _mats["iron"])
	_cyl(pos + Vector3(0.0, 0.03, 0.0), 0.08, 0.22, _mats["brass"])
	_torus(pos, maxf(ring - 0.03, 0.06), ring + 0.03, _mats["brass"])
	for i in 6:
		var a := TAU * float(i) / 6.0
		_sphere(pos + Vector3(cos(a) * ring, -0.05, sin(a) * ring),
			0.050, _mats["flame"])
	_lamp_light(pos + Vector3(0.0, -0.12, 0.0), energy,
		Color(1.0, 0.64, 0.32), 9.0)


# =========================================================================
#  GROUND BEDROOM  -  15.55 x 18.3 m, bed and storage in the far corners
# =========================================================================
func _build_bedroom_ground() -> void:
	var wd: Material = _mats["wood_dark"]

	# The Netted Palang. The bed is raised on heavy legs so there is a real
	# crawlspace beneath it; the net is translucent and dusty, and the whole
	# silhouette breaks up whatever is standing on the other side.
	_palang(Vector3(24.55, 0.0, 4.2), -90.0, 2.55, 3.35)
	_doll(Vector3(23.9, 0.96, 3.7))
	_rug(Vector3(22.8, 0.020, 4.2), Vector2(5.0, 5.6),
		_mats["rug_inner"], _mats["rug"])

	# North side of the palang: the only safe gap in the net.
	_bed_hide_point = _hinteract(Vector3(24.55, 0.95, 2.02),
		Vector3(2.25, 1.75, 0.90), "", Callable())
	_bed_hide_point.prompt_provider = func() -> String:
		if _player != null and _player.is_hiding_under_bed():
			return "E  -  slip out from under the netted palang"
		return "Hide under the netted palang"
	_bed_hide_point.used.connect(_on_hide_under_bed)

	# The Antique Almirah. A real openable carcass, not a painted box; the
	# weeping girl can be sitting in its black interior.
	_antique_almirah(Vector3(14.5, 0.0, -8.20), 0.0, 3.8, 4.3, 0.95, wd)

	# Vanity: the old dressing table, a tarnished mirror, broken bangles and
	# dried sindoor. The glass is where the sandook's code can be read.
	_table(Vector3(24.6, 0.0, -5.4), Vector2(1.5, 0.55), 0.82)
	_mirror(Vector3(26.45, 2.05, -5.4), -90.0, 1.1, 1.4)
	_vanity_clutter()
	_mirror_point = _hinteract(Vector3(25.18, 1.62, -5.4),
		Vector3(1.15, 2.45, 1.85), "", Callable())
	_mirror_point.prompt_provider = func() -> String:
		if _mirror_gaze_active:
			return "Look away from the tarnished mirror"
		return "Gaze into the tarnished mirror"
	_mirror_point.used.connect(_on_mirror_interact)

	# Iron-bound Sandook at the foot of the palang. Three brass dials, a
	# traditional padlock, and no mercy while your back is turned.
	_sandook(Vector3(21.9, 0.0, 6.55), 0.0)
	_sandook_point = _hinteract(Vector3(21.9, 0.92, 7.28),
		Vector3(1.35, 1.55, 1.05), "", Callable())
	_sandook_point.prompt_provider = func() -> String:
		if _sandook_open:
			return "The sandook stands open and empty"
		if _sandook_active:
			return "Turn the three brass dials"
		return "Examine the brass padlock"
	_sandook_point.used.connect(_on_sandook_interact)

	# Brass surahi on the nightstand. The water is clean until the Black
	# Magic room gets into your clothes.
	_nightstand(Vector3(24.55, 0.0, 1.90))
	_surahi(Vector3(24.55, 0.78, 1.90))
	_surahi_point = _hinteract(Vector3(24.55, 1.15, 1.90),
		Vector3(0.95, 1.45, 0.95), "", Callable())
	_surahi_point.prompt_provider = func() -> String:
		if _surahi_cooldown > 0.0:
			return "The surahi is empty for now"
		if _tantra_taint > 0.0:
			return "Drink from the brass surahi  (the water looks wrong)"
		return "Drink from the brass surahi"
	_surahi_point.used.connect(_on_surahi_interact)

	# A chair/table/portrait wall at the quiet end of the room.
	_chair(Vector3(18.7, 0.0, 7.4), 170.0)
	_table(Vector3(17.4, 0.0, 7.4), Vector2(0.8, 0.8), 0.56)
	_diya(Vector3(17.4, 0.60, 7.4), 1.0)
	_rich_photo_frame(Vector3(16.5, 3.05, 8.96), 180.0, 1.25, 1.70,
		"06_girl_ghost_haunting", "THE ELDEST DAUGHTER", true, true)
	_rich_photo_frame(Vector3(19.4, 2.96, 8.96), 180.0, 1.10, 1.50,
		"07_girl_ghost_closeup", "SHE NEVER BLINKED", true, false)

	# The Portrait Wall. Four wedding portraits face the bed. Their people
	# leave the glass when sanity falls.
	_bedroom_portraits.append({"node": _rich_photo_frame(
		Vector3(11.36, 2.95, -7.2), 90.0, 1.05, 1.42,
		"01_royal_couple_king_queen", "THE KING & QUEEN", true, true),
		"threshold": 55.0, "label": "THE KING & QUEEN"})
	_bedroom_portraits.append({"node": _rich_photo_frame(
		Vector3(11.36, 2.90, -5.0), 90.0, 0.94, 1.28,
		"09_couple_ghost_civilian", "THE CIVILIAN COUPLE", true, true),
		"threshold": 38.0, "label": "THE CIVILIAN COUPLE"})
	_bedroom_portraits.append({"node": _rich_photo_frame(
		Vector3(11.36, 2.90, -2.8), 90.0, 0.86, 1.16,
		"03_king_ghost_solo", "THE KING WHO STAYED", true, false),
		"threshold": 28.0, "label": "THE KING"})
	_bedroom_portraits.append({"node": _rich_photo_frame(
		Vector3(11.36, 2.88, -0.6), 90.0, 0.86, 1.16,
		"04_queen_ghost_solo", "THE QUEEN", true, false),
		"threshold": 20.0, "label": "THE QUEEN"})

	_window(Vector3(26.52, 2.75, 0.0), -90.0, 2.5, 2.4)
	_window(Vector3(22.8, 2.75, 8.96), 180.0, 2.2, 2.2)
	_palace_wing_chandelier(Vector3(19.0, 4.9, 0.5), 1.0, 1.6)
	_lantern(Vector3(19.0, LOW_H - 0.4, -6.8), 1.4, 0.9, 8.0)
	_sconce(Vector3(12.4, 2.4, -5.2), 0.55, Vector3(-1.0, 0.0, 0.0))
	_sconce(Vector3(23.8, 2.4, -8.78), 0.55, Vector3(0.0, 0.0, 1.0))
	_garland(Vector3(16.5, 4.30, 8.84), 2.7, 0.36)

	_build_mirror_marks()
	_build_bedroom_overlays()
	_build_sandook_lock_ui()
	_tantra_taint = 0.0
	_sandook_code = [randi_range(1, 6), randi_range(1, 6), randi_range(1, 6)]
	_sandook_dials = [1, 1, 1]


## The Netted Palang: heavy four-poster, raised mattress, dust-white net.
## The gap under it is real - the player is teleported into it when hiding.
func _palang(pos: Vector3, yaw: float, w: float, l: float) -> void:
	var n := Node3D.new()
	n.name = "NettedPalang"
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood"]
	var cloth: Material = _mats["cloth_cream"]
	var red: Material = _mats["cloth_red"]
	var brass: Material = _mats["brass"]

	# Corner posts, carved collars, brass finials.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_deco(Vector3(sx * w * 0.5, 1.48, sz * l * 0.5),
				Vector3(0.13, 2.96, 0.13), wd, n)
			for yy in [0.45, 1.15, 1.85, 2.48]:
				_deco(Vector3(sx * w * 0.5, yy, sz * l * 0.5),
					Vector3(0.21, 0.07, 0.21), wl, n)
			_sphere(Vector3(sx * w * 0.5, 3.02, sz * l * 0.5), 0.085,
				brass, n)
			_sphere(Vector3(sx * w * 0.5, 3.10, sz * l * 0.5), 0.035,
				brass, n)

	# Canopy rails.
	for sz in [-1.0, 1.0]:
		_deco(Vector3(0.0, 2.73, sz * l * 0.5),
			Vector3(w + 0.18, 0.10, 0.10), wd, n)
		_deco(Vector3(0.0, 2.67, sz * l * 0.5),
			Vector3(w + 0.28, 0.04, 0.16), wl, n)
	for sx in [-1.0, 1.0]:
		_deco(Vector3(sx * w * 0.5, 2.73, 0.0),
			Vector3(0.10, 0.10, l + 0.18), wd, n)
		_deco(Vector3(sx * w * 0.5, 2.67, 0.0),
			Vector3(0.16, 0.04, l + 0.28), wl, n)

	# Four legs only. Everything under the mattress stays open.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_deco(Vector3(sx * (w * 0.5 - 0.12), 0.28, sz * (l * 0.5 - 0.14)),
				Vector3(0.16, 0.56, 0.16), wd, n)
			_deco(Vector3(sx * (w * 0.5 - 0.12), 0.035, sz * (l * 0.5 - 0.14)),
				Vector3(0.23, 0.07, 0.23), wl, n)
	# Side rails and the raised bed platform.
	_deco(Vector3(0.0, 0.58, 0.0), Vector3(w, 0.16, l), wd, n)
	for sz in [-1.0, 1.0]:
		_deco(Vector3(0.0, 0.49, sz * l * 0.5),
			Vector3(w + 0.04, 0.18, 0.10), wl, n)
	for sx2 in [-1.0, 1.0]:
		_deco(Vector3(sx2 * w * 0.5, 0.49, 0.0),
			Vector3(0.10, 0.18, l), wl, n)

	# Mattress, quilt and bolsters.
	_deco(Vector3(0.0, 0.74, 0.0), Vector3(w - 0.12, 0.22, l - 0.14),
		cloth, n)
	_deco(Vector3(0.0, 0.87, 0.18 * l), Vector3(w - 0.20, 0.05, l * 0.50),
		red, n)
	_deco(Vector3(0.0, 0.87, -l * 0.5 + 0.34),
		Vector3(w * 0.68, 0.16, 0.42), cloth, n)
	var bol := _cyl(Vector3(0.0, 0.91, -l * 0.5 + 0.66), 0.095, w * 0.58,
		cloth, n)
	bol.rotation_degrees.z = 90.0
	for i in 5:
		var t := float(i) / 4.0
		_deco(Vector3((t - 0.5) * (w - 0.35), 0.93, 0.18 * l),
			Vector3(0.035, 0.035, l * 0.30), brass, n)

	# Headboard at the east wall and a lower carved footboard.
	_deco(Vector3(0.0, 1.42, -l * 0.5 - 0.06), Vector3(w + 0.18, 1.72, 0.12),
		wd, n)
	_deco(Vector3(0.0, 1.40, -l * 0.5 + 0.01), Vector3(w - 0.18, 1.30, 0.04),
		wl, n)
	for sx3 in [-1.0, 1.0]:
		for yy2 in [0.82, 1.34, 1.86]:
			_sphere(Vector3(sx3 * (w * 0.5 - 0.23), yy2, -l * 0.5 + 0.02),
				0.040, brass, n)
	_deco(Vector3(0.0, 0.85, l * 0.5 + 0.05), Vector3(w + 0.10, 0.72, 0.10),
		wd, n)
	_deco(Vector3(0.0, 0.86, l * 0.5 - 0.01), Vector3(w - 0.16, 0.52, 0.04),
		wl, n)

	# The net itself: four translucent walls and a sagging ceiling.
	_net_quad(n, Vector3(0.0, 1.62, l * 0.5 + 0.01),
		Vector2(w, 2.10), 0.0)
	_net_quad(n, Vector3(0.0, 1.62, -l * 0.5 - 0.01),
		Vector2(w, 2.10), 0.0)
	_net_quad(n, Vector3(w * 0.5 + 0.01, 1.62, 0.0),
		Vector2(l, 2.10), 90.0)
	_net_quad(n, Vector3(-w * 0.5 - 0.01, 1.62, 0.0),
		Vector2(l, 2.10), 90.0)
	_net_quad(n, Vector3(0.0, 2.62, 0.0), Vector2(w, l), 0.0, 90.0)
	# A torn flap over the north side, where you crawl in to hide.
	_net_quad(n, Vector3(0.62, 1.75, 2.02), Vector2(1.15, 1.65), 20.0)

	# Net ties at every post, and a tiny brass bell on each.
	for sx4 in [-1.0, 1.0]:
		for sz4 in [-1.0, 1.0]:
			var tie := _torus(Vector3(sx4 * w * 0.5, 2.45, sz4 * l * 0.5),
				0.075, 0.13, brass, n)
			tie.rotation_degrees.x = 90.0
			_sphere(Vector3(sx4 * w * 0.5, 2.28, sz4 * l * 0.5), 0.045,
				brass, n)

	# Only the mattress box collides. The crawlspace below is free.
	_blocker(pos + Vector3(0.0, 0.80, 0.0),
		Vector3(w + 0.15, 0.60, l + 0.15), yaw)
	_blocker(pos + Vector3(0.0, 1.40, 0.0),
		Vector3(w + 0.20, 0.30, 0.12), yaw)


func _net_quad(parent: Node3D, local_pos: Vector3, size: Vector2,
		yaw: float, pitch := 0.0) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.80, 0.72, 0.20)
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.name = "MosquitoNet"
	mi.mesh = quad
	mi.material_override = mat
	mi.position = local_pos
	mi.rotation_degrees = Vector3(pitch, yaw, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _antique_almirah(pos: Vector3, yaw: float, w: float, h: float, d: float,
		wd: Material) -> void:
	var n := Node3D.new()
	n.name = "AntiqueAlmirah"
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var wl: Material = _mats["wood_light"]
	var brass: Material = _mats["brass"]
	var soot: Material = _mats["soot"]
	var rust := _mat(Color(0.31, 0.12, 0.055), 1.0)

	# Carcass built as separate boards, so the inside is genuinely dark.
	_deco(Vector3(0.0, h * 0.5, -d * 0.5 + 0.05),
		Vector3(w, h, 0.10), wd, n)
	for sx in [-1.0, 1.0]:
		_deco(Vector3(sx * (w * 0.5 - 0.06), h * 0.5, 0.0),
			Vector3(0.12, h, d), wd, n)
	_deco(Vector3(0.0, h * 0.5, -d * 0.5 + 0.12),
		Vector3(w - 0.18, h - 0.25, 0.03), soot, n)
	_deco(Vector3(0.0, 0.08, 0.0), Vector3(w + 0.10, 0.16, d + 0.10),
		wd, n)
	_deco(Vector3(0.0, h - 0.08, 0.0), Vector3(w + 0.16, 0.16, d + 0.12),
		wl, n)
	_deco(Vector3(0.0, h - 0.19, 0.02), Vector3(w + 0.24, 0.10, d + 0.20),
		wd, n)
	# Carved pediment.
	for i in 7:
		var fx := -w * 0.42 + float(i) * (w * 0.84 / 6.0)
		_deco(Vector3(fx, h + 0.04 - absf(fx) * 0.05, 0.03),
			Vector3(0.20, 0.16, 0.12), wl, n)
		_sphere(Vector3(fx, h + 0.15 - absf(fx) * 0.05, 0.10), 0.040,
			brass, n)

	# Two hinged doors. Hinges are deliberately rusty.
	_almirah_left = Node3D.new()
	_almirah_left.name = "AlmirahDoorLeft"
	_almirah_left.position = Vector3(-w * 0.5 + 0.08, 0.0, d * 0.5 - 0.02)
	n.add_child(_almirah_left)
	_almirah_right = Node3D.new()
	_almirah_right.name = "AlmirahDoorRight"
	_almirah_right.position = Vector3(w * 0.5 - 0.08, 0.0, d * 0.5 - 0.02)
	n.add_child(_almirah_right)
	for door in [_almirah_left, _almirah_right]:
		var sign := -1.0 if door == _almirah_left else 1.0
		_deco(Vector3(sign * (w * 0.5 - 0.10), h * 0.5, 0.0),
			Vector3(w * 0.5 - 0.04, h - 0.32, 0.07), wd, door)
		_deco(Vector3(sign * (w * 0.5 - 0.10), h * 0.52, 0.055),
			Vector3(w * 0.5 - 0.27, h - 0.62, 0.025), wl, door)
		for yy in [0.32, h - 0.38, h * 0.52]:
			_deco(Vector3(sign * (w * 0.5 - 0.10), yy, 0.075),
				Vector3(0.30, 0.045, 0.025), rust, door)
		_sphere(Vector3(sign * 0.17, h * 0.52, 0.095), 0.055, brass, door)
		# Rust weeping down from the hinges.
		for i in 4:
			_deco(Vector3(sign * (w * 0.5 - 0.16), h - 0.48 - float(i) * 0.22,
				0.082), Vector3(0.025, 0.13, 0.012), rust, door)

	# Huddled figure in the dark: the weeping girl.
	_weeping_girl = Node3D.new()
	_weeping_girl.name = "WeepingGirlInAlmirah"
	_weeping_girl.position = Vector3(0.0, 0.0, -d * 0.5 + 0.28)
	_weeping_girl.visible = false
	n.add_child(_weeping_girl)
	var dress: Material = _mat(Color(0.47, 0.45, 0.40), 1.0)
	var bone: Material = _mats["bone"]
	var hair: Material = _mats["dark"]
	var bod := _sphere(Vector3(0.0, 0.58, 0.0), 0.28, dress, _weeping_girl)
	bod.scale = Vector3(0.84, 1.25, 0.72)
	for sx2 in [-1.0, 1.0]:
		var knee := _sphere(Vector3(sx2 * 0.19, 0.34, 0.18), 0.15,
			dress, _weeping_girl)
		knee.scale = Vector3(0.86, 1.10, 0.90)
		_cyl(Vector3(sx2 * 0.14, 0.21, 0.27), 0.055, 0.36, dress,
			_weeping_girl)
		_cyl(Vector3(sx2 * 0.25, 0.63, 0.15), 0.045, 0.36, dress,
			_weeping_girl)
	var head := _sphere(Vector3(0.0, 0.99, 0.04), 0.18, bone,
		_weeping_girl)
	head.scale = Vector3(0.78, 1.02, 0.80)
	for sx3 in [-1.0, 1.0]:
		_sphere(Vector3(sx3 * 0.065, 1.01, 0.16), 0.022, hair,
			_weeping_girl)
		_deco(Vector3(sx3 * 0.12, 0.74, 0.10), Vector3(0.04, 0.34, 0.03),
			hair, _weeping_girl)
	# Long wet hair and a grey tear-track.
	for i in 5:
		var hx := -0.22 + float(i) * 0.11
		_deco(Vector3(hx, 0.80, -0.02), Vector3(0.055, 0.55, 0.05),
			hair, _weeping_girl)
	_deco(Vector3(0.055, 0.93, 0.185), Vector3(0.018, 0.20, 0.012),
		_mat(Color(0.62, 0.68, 0.70), 1.0), _weeping_girl)
	_lamp_light(n.to_global(Vector3(0.0, 1.15, 0.45)), 0.0,
		Color(0.44, 0.56, 0.68), 1.8)

	_blocker(pos + Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), yaw)
	_almirah_point = _hinteract(
		pos + Vector3(0.0, 1.24, d * 0.5 + 0.58),
		Vector3(2.40, 2.15, 0.95), "", Callable())
	_almirah_point.prompt_provider = func() -> String:
		if _almirah_girl_timer > 0.0:
			return "The weeping girl is inside the almirah"
		return "Open the antique almirah"
	_almirah_point.used.connect(_on_almirah_interact)
	_almirah_light = _lamp_light(pos + Vector3(0.0, 1.1, 0.78), 0.0,
		Color(0.55, 0.64, 0.52), 2.0)


func _vanity_clutter() -> void:
	var brass: Material = _mats["brass"]
	var glass := _mat(Color(0.50, 0.66, 0.62), 0.14)
	glass.metallic = 0.8
	var sindoor := _mat(Color(0.45, 0.018, 0.010), 1.0)
	# Broken bangles, some still whole, some just curved shards.
	for i in 5:
		var px := 23.98 + float(i) * 0.24
		var pz := -5.65 + float(i % 2) * 0.28
		if i < 2:
			var b := _torus(Vector3(px, 0.865, pz), 0.055, 0.073,
				glass if i == 0 else brass)
			b.rotation_degrees.x = 90.0
		else:
			_deco(Vector3(px, 0.858, pz), Vector3(0.20, 0.014, 0.045),
				glass if i % 2 == 0 else brass)
	# Dried sindoor in a tiny brass dish, and a spill that was never cleaned.
	_cyl(Vector3(24.86, 0.835, -5.15), 0.075, 0.028, brass)
	var sindoor_mound := _sphere(Vector3(24.86, 0.858, -5.15), 0.045, sindoor)
	sindoor_mound.scale = Vector3(1.0, 0.32, 1.0)
	var sindoor_spill := _sphere(Vector3(24.66, 0.856, -5.02), 0.060, sindoor)
	sindoor_spill.scale = Vector3(1.25, 0.08, 0.70)
	_deco(Vector3(24.34, 0.854, -5.66), Vector3(0.26, 0.012, 0.08), sindoor)
	# A tarnished hand-mirror lying face down.
	var hand := _torus(Vector3(24.16, 0.88, -5.24), 0.10, 0.135, brass)
	hand.rotation_degrees.x = 90.0
	_deco(Vector3(24.16, 0.885, -5.10), Vector3(0.035, 0.035, 0.24), brass)
	# Dark bloom on the wall mirror.
	for i in 3:
		var patch := _sphere(Vector3(26.382, 1.68 + float(i) * 0.40,
			-5.70 + float(i) * 0.25), 0.20,
			_mat(Color(0.12, 0.14, 0.13, 0.52), 0.8))
		patch.scale = Vector3(0.05, 0.9 + float(i) * 0.2, 0.55)
	# The face that appears when you stare too long.
	_mirror_face = Node3D.new()
	_mirror_face.name = "MaliciousReflection"
	_mirror_face.position = Vector3(26.365, 2.02, -5.4)
	_mirror_face.rotation_degrees.y = -90.0
	_mirror_face.visible = false
	add_child(_mirror_face)
	var pale: Material = _mats["bone"]
	var dark: Material = _mats["dark"]
	var mouth := _mat(Color(0.44, 0.012, 0.012), 1.0)
	var face := _sphere(Vector3(0.0, 0.0, 0.20), 0.23, pale, _mirror_face)
	face.scale = Vector3(0.76, 1.08, 0.18)
	for sx in [-1.0, 1.0]:
		var eye := _sphere(Vector3(sx * 0.075, 0.055, 0.285), 0.034,
			dark, _mirror_face)
		eye.scale = Vector3(1.0, 1.15, 0.25)
	# A wide, wrong smile made of small dark-red beads.
	for i in 7:
		var t := (float(i) - 3.0) / 3.0
		_sphere(Vector3(t * 0.12, -0.085 - (1.0 - t * t) * 0.025,
			0.292), 0.020, mouth, _mirror_face)
	# Wet hair hanging over the glass.
	for i in 5:
		_deco(Vector3(-0.13 + float(i) * 0.065, 0.20, 0.16),
			Vector3(0.025, 0.40, 0.012), dark, _mirror_face)


func _sandook(pos: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.name = "IronBoundSandook"
	n.position = pos
	n.rotation_degrees.y = yaw
	add_child(n)
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood"]
	var iron: Material = _mats["iron"]
	var brass: Material = _mats["brass"]
	# Base, feet, iron straps and rivets.
	_deco(Vector3(0.0, 0.32, 0.0), Vector3(1.55, 0.52, 0.85), wd, n)
	for sx in [-0.62, 0.62]:
		_deco(Vector3(sx, 0.33, 0.0), Vector3(0.10, 0.54, 0.91), iron, n)
		for i in 4:
			_sphere(Vector3(sx, 0.14 + float(i) * 0.13, 0.455), 0.024,
				brass, n)
	for sx2 in [-0.72, 0.72]:
		for sz in [-0.36, 0.36]:
			_deco(Vector3(sx2, 0.055, sz), Vector3(0.10, 0.12, 0.10),
				iron, n)
	_deco(Vector3(0.0, 0.08, 0.0), Vector3(1.60, 0.08, 0.90), wd, n)
	# Lid hinged at the back.
	_sandook_lid = Node3D.new()
	_sandook_lid.name = "SandookLid"
	_sandook_lid.position = Vector3(0.0, 0.60, -0.40)
	n.add_child(_sandook_lid)
	_deco(Vector3(0.0, 0.08, 0.40), Vector3(1.58, 0.18, 0.88), wd,
		_sandook_lid)
	for sx3 in [-0.62, 0.62]:
		_deco(Vector3(sx3, 0.09, 0.40), Vector3(0.10, 0.20, 0.90), iron,
			_sandook_lid)
	_deco(Vector3(0.0, 0.19, 0.40), Vector3(1.20, 0.035, 0.60), wl,
		_sandook_lid)
	# Traditional brass padlock and three dials.
	var lock_pos := Vector3(0.0, 0.56, 0.445)
	_deco(lock_pos, Vector3(0.28, 0.30, 0.10), brass, n)
	for i in 3:
		var dx := -0.085 + float(i) * 0.085
		var dial := _cyl(lock_pos + Vector3(dx, 0.0, 0.07), 0.034, 0.04,
			brass, n)
		dial.rotation_degrees.x = 90.0
		_deco(lock_pos + Vector3(dx, 0.0, 0.092), Vector3(0.008, 0.042, 0.008),
			iron, n)
	var shackle := _torus(lock_pos + Vector3(0.0, 0.19, 0.0), 0.085, 0.115,
		iron, n)
	shackle.rotation_degrees.x = 90.0
	_torus(Vector3(0.0, 0.56, 0.50), 0.035, 0.055, iron, n)
	_blocker(pos + Vector3(0.0, 0.36, 0.0), Vector3(1.6, 0.72, 0.9), yaw)


func _nightstand(pos: Vector3) -> void:
	_nightstand_ref = Node3D.new()
	_nightstand_ref.name = "Nightstand"
	_nightstand_ref.position = pos
	add_child(_nightstand_ref)
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	_deco(Vector3(0.0, 0.68, 0.0), Vector3(0.55, 0.07, 0.55), wd,
		_nightstand_ref)
	_deco(Vector3(0.0, 0.60, 0.0), Vector3(0.44, 0.14, 0.44), wl,
		_nightstand_ref)
	for sx in [-0.20, 0.20]:
		for sz in [-0.20, 0.20]:
			_deco(Vector3(sx, 0.32, sz), Vector3(0.055, 0.64, 0.055), wd,
				_nightstand_ref)
	_sphere(Vector3(0.0, 0.47, 0.22), 0.025, _mats["brass"],
		_nightstand_ref)
	_blocker(pos + Vector3(0.0, 0.35, 0.0), Vector3(0.58, 0.7, 0.58))


func _surahi(pos: Vector3) -> void:
	var brass: Material = _mats["brass"]
	var n := Node3D.new()
	n.name = "BrassSurahi"
	n.position = pos
	add_child(n)
	var body := _sphere(Vector3(0.0, 0.20, 0.0), 0.17, brass, n)
	body.scale = Vector3(1.0, 1.22, 1.0)
	_cyl(Vector3(0.0, 0.36, 0.0), 0.085, 0.14, brass, n)
	_cyl(Vector3(0.0, 0.46, 0.0), 0.115, 0.055, brass, n)
	# Spout, angled out of the shoulder.
	var spout := _cyl(Vector3(0.15, 0.39, 0.0), 0.032, 0.27, brass, n)
	spout.rotation_degrees.z = -48.0
	_cyl(Vector3(0.23, 0.48, 0.0), 0.045, 0.045, brass, n)
	# Handle.
	var handle := _torus(Vector3(-0.19, 0.30, 0.0), 0.075, 0.105, brass, n)
	handle.rotation_degrees.z = 90.0
	for i in 3:
		_deco(Vector3(0.0, 0.12 + float(i) * 0.08, 0.171),
			Vector3(0.026, 0.012, 0.008), _mats["wood"], n)
	_blocker(pos + Vector3(0.0, 0.22, 0.0), Vector3(0.38, 0.5, 0.38))


func _build_mirror_marks() -> void:
	var mark_mat := _emissive(Color(0.34, 0.72, 0.58), 0.55)
	var pts := [
		Vector3(24.25, 0.035, -3.80), Vector3(24.45, 0.035, -2.20),
		Vector3(24.58, 0.035, -0.55), Vector3(24.55, 0.035, 1.05),
		Vector3(24.10, 0.035, 2.20), Vector3(23.10, 0.035, 2.50)]
	for i in pts.size():
		var mark := _sphere(pts[i], 0.11, mark_mat)
		mark.scale = Vector3(0.65, 0.055, 1.55)
		mark.rotation_degrees.y = -18.0 + float(i) * 6.0
		mark.visible = false
		_mirror_marks.append(mark)


func _build_bedroom_overlays() -> void:
	# The net veil. A screen-space shader distorts the view, draws a dusty
	# mosquito mesh, and lets an ambiguous silhouette bleed through when
	# Kamla is standing at the bedside.
	_net_layer = CanvasLayer.new()
	_net_layer.name = "NetVeil"
	_net_layer.layer = 44
	_net_layer.visible = false
	add_child(_net_layer)
	var net_rect := ColorRect.new()
	net_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_net_layer.add_child(net_rect)
	net_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_net_mat = ShaderMaterial.new()
	var net_shader := Shader.new()
	net_shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float ghost_amount = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float sway = sin(uv.y * 27.0 + TIME * 0.8) * 0.0028
		+ sin(uv.x * 19.0 - TIME * 0.55) * 0.0018;
	vec3 col = texture(screen_texture, uv + vec2(sway, sway * 0.55)).rgb;
	vec2 p = uv * vec2(32.0, 21.0);
	float l1 = abs(fract((p.x + p.y) * 0.5) - 0.5);
	float l2 = abs(fract((p.x - p.y) * 0.5) - 0.5);
	float line = 1.0 - smoothstep(0.0, 0.055, min(l1, l2));
	col = mix(col, vec3(0.84, 0.82, 0.73), line * 0.22);
	col *= 0.86;
	// A head and shoulders, deliberately vague.
	vec2 q = (uv - vec2(0.5, 0.43)) * vec2(1.0, 0.78);
	float head = smoothstep(0.155, 0.105,
		length((q - vec2(0.0, 0.19)) * vec2(0.92, 1.14)));
	float body = smoothstep(0.46, 0.35, length(q * vec2(0.62, 1.48)));
	float shape = max(head, body);
	float shimmer = 0.84 + 0.16 * sin(TIME * 3.1);
	col = mix(col, vec3(0.010, 0.008, 0.012),
		shape * ghost_amount * 0.78 * shimmer);
	COLOR = vec4(col, 1.0);
}
"""
	_net_mat.shader = net_shader
	net_rect.material = _net_mat

	# Corrupted surahi water: a short screen-space blur and a sickly tint.
	_blur_layer = CanvasLayer.new()
	_blur_layer.name = "CorruptWaterBlur"
	_blur_layer.layer = 46
	_blur_layer.visible = false
	add_child(_blur_layer)
	var blur_rect := ColorRect.new()
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_layer.add_child(blur_rect)
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur_mat = ShaderMaterial.new()
	var blur_shader := Shader.new()
	blur_shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = vec2(0.0055, 0.0055) * amount;
	vec3 c = texture(screen_texture, uv).rgb * 0.20;
	c += texture(screen_texture, uv + vec2(d.x, 0.0)).rgb * 0.12;
	c += texture(screen_texture, uv - vec2(d.x, 0.0)).rgb * 0.12;
	c += texture(screen_texture, uv + vec2(0.0, d.y)).rgb * 0.12;
	c += texture(screen_texture, uv - vec2(0.0, d.y)).rgb * 0.12;
	c += texture(screen_texture, uv + d).rgb * 0.08;
	c += texture(screen_texture, uv - d).rgb * 0.08;
	c += texture(screen_texture, uv + vec2(d.x, -d.y)).rgb * 0.08;
	c += texture(screen_texture, uv + vec2(-d.x, d.y)).rgb * 0.08;
	c = mix(c, c * vec3(0.62, 0.86, 0.64), amount * 0.45);
	COLOR = vec4(c, 1.0);
}
"""
	_blur_mat.shader = blur_shader
	blur_rect.material = _blur_mat


func _build_sandook_lock_ui() -> void:
	_sandook_ui_layer = CanvasLayer.new()
	_sandook_ui_layer.name = "SandookLock"
	_sandook_ui_layer.layer = 72
	_sandook_ui_layer.visible = false
	add_child(_sandook_ui_layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sandook_ui_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640.0, 312.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.014, 0.94)
	style.border_color = Color(0.48, 0.34, 0.12, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(2)
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "THE IRON-BOUND SANDOOK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.86, 0.67, 0.31))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Three brass dials. The house listens while you work."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.68, 0.62, 0.52))
	box.add_child(sub)
	_sandook_dial_label = Label.new()
	_sandook_dial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sandook_dial_label.add_theme_font_size_override("font_size", 48)
	_sandook_dial_label.add_theme_color_override("font_color",
		Color(0.94, 0.86, 0.62))
	box.add_child(_sandook_dial_label)
	_sandook_hint_label = Label.new()
	_sandook_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sandook_hint_label.add_theme_font_size_override("font_size", 16)
	_sandook_hint_label.add_theme_color_override("font_color",
		Color(0.74, 0.70, 0.61))
	box.add_child(_sandook_hint_label)
	_sandook_hint_label.text = "A / D  turn     W / S  choose dial     ENTER  try     Q  step back"
	_update_sandook_ui()


func _update_sandook_ui() -> void:
	if _sandook_dial_label == null:
		return
	var parts: Array[String] = []
	for i in 3:
		var v := int(_sandook_dials[i])
		if i == _sandook_sel:
			parts.append("  [ %d ]  " % v)
		else:
			parts.append("   %d   " % v)
	_sandook_dial_label.text = " ".join(parts)


func _open_sandook_ui() -> void:
	_sandook_active = true
	_sandook_sel = 0
	_sandook_fumble = 2.2
	if _player != null and is_instance_valid(_player):
		_player.set_frozen(true)
	if _sandook_ui_layer != null:
		_sandook_ui_layer.visible = true
	if _sandook_hint_label != null:
		_sandook_hint_label.text = \
			"A / D  turn     W / S  choose dial     ENTER  try     Q  step back"
	_update_sandook_ui()
	GameManager.set_interact_prompt("")
	GameManager.show_message(
		"The padlock is cold. Three dials click under your thumb. Do not look behind you.",
		4.2)


func _close_sandook_ui() -> void:
	_sandook_active = false
	if _player != null and is_instance_valid(_player):
		_player.set_frozen(false)
	if _sandook_ui_layer != null:
		_sandook_ui_layer.visible = false


func _on_sandook_interact(_node: Node) -> void:
	if _sandook_open or _sandook_active:
		return
	if _player == null or not is_instance_valid(_player):
		return
	_open_sandook_ui()


func _on_sandook_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_A, KEY_LEFT:
			var i := _sandook_sel
			var v := int(_sandook_dials[i]) - 1
			if v < 1:
				v = 6
			_sandook_dials[i] = v
			_update_sandook_ui()
			ProcAudio.play_click()
		KEY_D, KEY_RIGHT:
			var i2 := _sandook_sel
			var v2 := int(_sandook_dials[i2]) + 1
			if v2 > 6:
				v2 = 1
			_sandook_dials[i2] = v2
			_update_sandook_ui()
			ProcAudio.play_click()
		KEY_W, KEY_UP:
			_sandook_sel = (_sandook_sel + 2) % 3
			_update_sandook_ui()
			ProcAudio.play_click()
		KEY_S, KEY_DOWN:
			_sandook_sel = (_sandook_sel + 1) % 3
			_update_sandook_ui()
			ProcAudio.play_click()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_try_sandook()
		KEY_Q:
			_close_sandook_ui()
			GameManager.show_message(
				"You take your hands off the lock. The bedroom is very quiet.",
				3.0)


func _try_sandook() -> void:
	if not _sandook_active:
		return
	var solved := true
	for i in 3:
		if int(_sandook_dials[i]) != int(_sandook_code[i]):
			solved = false
	if solved:
		_sandook_open = true
		_close_sandook_ui()
		GameManager.add_inventory_item("matches", "Box of matches", 2)
		GameManager.add_inventory_item("iron_key", "Iron key stamped KAMLA", 1)
		if _sandook_lid != null:
			var tw := create_tween()
			tw.tween_property(_sandook_lid, "rotation_degrees:x", -104.0, 0.75) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		GameManager.show_message(
			"The padlock opens. Inside: a tin of matches, and an iron key stamped KAMLA.\nThe sandook lid creaks up behind you.",
			5.5)
		ProcAudio.play_pickup()
		GameEventBroker.player_noise_made.emit(9.0, _player.global_position)
		return
	# Wrong. The lock punishes fumbling with a noise spike.
	GameEventBroker.player_noise_made.emit(13.0, _player.global_position)
	GameManager.add_threat(4.0)
	GameManager.add_sanity(-1.5)
	ProcAudio.play_impact(_player.global_position)
	if _player != null:
		_player.add_trauma(0.35)
	if _sandook_hint_label != null:
		_sandook_hint_label.text = \
			"Wrong. The brass bites your thumb. Something shifts behind you."


func _on_hide_under_bed(_node: Node) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.is_hiding_under_bed():
		_player.exit_hiding_under_bed()
		return
	_player.enter_hiding_under_bed(
		Vector3(24.55, 0.14, 4.20),
		Vector3(24.55, 0.25, 1.92),
		180.0)
	_net_ghost = 0.0
	GameManager.show_message(
		"You slide under the palang. Dust and old netting. The bed above you creaks once, then settles.",
		4.5)


func _on_almirah_interact(_node: Node) -> void:
	if _almirah_notice_cd > 0.0:
		return
	_almirah_notice_cd = 1.4
	_almirah_opens += 1
	_almirah_open_timer = 6.0
	if _almirah_left != null and _almirah_right != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_almirah_left, "rotation_degrees:y", -102.0, 0.65) \
			.set_trans(Tween.TRANS_SINE)
		tw.tween_property(_almirah_right, "rotation_degrees:y", 102.0, 0.65) \
			.set_trans(Tween.TRANS_SINE)
	# Rusty hinges: the loudest thing in the east wing.
	GameEventBroker.player_noise_made.emit(32.0, _player.global_position)
	GameManager.add_threat(5.0)
	ProcAudio.play_door(_almirah_point.global_position)
	ProcAudio.play_impact(_almirah_point.global_position)
	if _almirah_light != null:
		_almirah_light.light_energy = 0.7

	var loot := ""
	match _almirah_opens:
		1:
			GameManager.add_inventory_item("matches", "Box of matches", 1)
			loot = "A damp box of matches."
		2:
			GameManager.add_inventory_item("rusted_key", "Rusted bedroom key", 1)
			loot = "A rusted key, warm from someone's hand."
		3:
			GameManager.add_inventory_item("camphor_sachet",
				"Camphor sachet", 1)
			_camphor = mini(_camphor + 1, 5)
			loot = "A camphor sachet wrapped in red thread."
		_:
			loot = "Nothing but dust and the smell of old sarees."

	if _live and randf() < 0.32:
		_weeping_girl.visible = true
		_almirah_girl_timer = 4.8
		GameManager.add_sanity(-9.0)
		GameManager.add_threat(8.0)
		GameManager.set_interact_prompt("")
		GameManager.show_message(
			"The weeping girl is huddled inside the almirah. Her face is wet. She does not look up.\n%s" % loot,
			6.0)
		ProcAudio.play_whisper(_almirah_point.global_position)
	else:
		GameManager.show_message(
			"The almirah groans open on rusty hinges.  %s" % loot, 4.2)


func _on_mirror_interact(_node: Node) -> void:
	if _mirror_notice_cd > 0.0:
		return
	if _mirror_gaze_active:
		_end_mirror_gaze(false)
		return
	_begin_mirror_gaze()


func _begin_mirror_gaze() -> void:
	_mirror_gaze_active = true
	_mirror_gaze_time = 0.0
	_mirror_smile = false
	_mirror_revealed = false
	_mirror_vision_timer = 9.0
	if _mirror_face != null:
		_mirror_face.visible = false
	GameManager.show_message(
		"The tarnished glass is cloudy. Your reflection is a heartbeat late.",
		3.0)
	ProcAudio.play_whisper(Vector3(25.8, 1.8, -5.4))


func _end_mirror_gaze(forced: bool) -> void:
	if not _mirror_gaze_active:
		return
	_mirror_gaze_active = false
	_mirror_smile = false
	_mirror_notice_cd = 0.45
	_mirror_vision_timer = maxf(_mirror_vision_timer, 7.0)
	if _mirror_face != null:
		_mirror_face.visible = false
	if forced:
		GameManager.add_sanity(-10.0)
		GameManager.add_threat(8.0)
		GameManager.show_message(
			"Your reflection smiles with too many teeth. You wrench your eyes away.",
			5.0)
		ProcAudio.play_whisper(Vector3(25.8, 1.8, -5.4))


func _on_surahi_interact(_node: Node) -> void:
	if _surahi_cooldown > 0.0:
		GameManager.show_message(
			"The surahi is empty. It will fill again when the house forgets you.",
			2.8)
		return
	if _player == null or not is_instance_valid(_player):
		return
	_surahi_cooldown = 16.0
	if _tantra_taint > 0.0 or _has_cursed_items():
		_player.drain_stamina_to_zero()
		_blur_timer = 4.8
		GameManager.add_sanity(-8.0)
		GameManager.add_threat(7.0)
		GameManager.show_message(
			"The water is black and bitter. Your legs fold. The room smears sideways.",
			5.0)
		ProcAudio.play_hurt(_player.global_position)
		_player.add_trauma(0.65)
		GameEventBroker.player_noise_made.emit(12.0, _player.global_position)
		return
	_player.restore_stamina(48.0)
	GameManager.show_message(
		"The water is cold and clean. Your breath comes back.  (+48 stamina)",
		3.2)
	ProcAudio.play_pickup()


func _update_bedroom(delta: float) -> void:
	_surahi_cooldown = maxf(0.0, _surahi_cooldown - delta)
	_almirah_notice_cd = maxf(0.0, _almirah_notice_cd - delta)
	_mirror_notice_cd = maxf(0.0, _mirror_notice_cd - delta)
	_mirror_vision_timer = maxf(0.0, _mirror_vision_timer - delta)

	# The Black Magic room clings to your clothes for half a minute.
	if GameManager.current_zone == "black_magic_room":
		_tantra_taint = 42.0
	if _has_cursed_items():
		_tantra_taint = maxf(_tantra_taint, 22.0)
	_tantra_taint = maxf(0.0, _tantra_taint - delta)

	# The almirah closes itself when you stop watching.
	if _almirah_open_timer > 0.0:
		_almirah_open_timer = maxf(0.0, _almirah_open_timer - delta)
		if _almirah_open_timer <= 0.0 and _almirah_left != null \
				and _almirah_right != null:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(_almirah_left, "rotation_degrees:y", 0.0, 0.9)
			tw.tween_property(_almirah_right, "rotation_degrees:y", 0.0, 0.9)
			if _almirah_light != null:
				_almirah_light.light_energy = 0.0
	if _almirah_girl_timer > 0.0:
		_almirah_girl_timer = maxf(0.0, _almirah_girl_timer - delta)
		if _almirah_girl_timer <= 0.0 and _weeping_girl != null:
			_weeping_girl.visible = false

	# Net veil / ghost silhouette under the bed.
	var hiding := _player != null and is_instance_valid(_player) \
		and _player.is_hiding_under_bed()
	if _net_layer != null:
		_net_layer.visible = hiding
	if hiding:
		var near := 0.0
		if _ghost != null and is_instance_valid(_ghost):
			var d := _ghost.global_position.distance_to(_player.global_position)
			near = clampf(1.0 - d / 9.0, 0.0, 1.0)
		_net_ghost = lerpf(_net_ghost, near, 1.0 - exp(-2.2 * delta))
		if _net_mat != null:
			_net_mat.set_shader_parameter("ghost_amount", _net_ghost)
		# You are safe under the palang, but the net is not free: the
		# ambiguity wears at you while the dead stand over the bed.
		if _net_ghost > 0.25:
			GameManager.add_sanity(-1.1 * delta)
		if _net_ghost > 0.72 and not _net_warning_shown:
			_net_warning_shown = true
			GameManager.show_message(
				"Something leans over the bed. The net turns it into a smear of black. You cannot tell if it has gone.",
				4.5)
			ProcAudio.play_whisper(_player.global_position)
	elif _net_ghost > 0.0:
		_net_ghost = lerpf(_net_ghost, 0.0, 1.0 - exp(-5.0 * delta))
		_net_warning_shown = false
		if _net_mat != null:
			_net_mat.set_shader_parameter("ghost_amount", _net_ghost)

	# Tarnished mirror gaze.
	if _mirror_gaze_active and _player != null and is_instance_valid(_player):
		_mirror_gaze_time += delta
		var dist := _player.global_position.distance_to(
			Vector3(25.6, 1.4, -5.4))
		if dist > 4.4 or _mirror_gaze_time > 8.2:
			_end_mirror_gaze(_mirror_gaze_time > 8.2)
		elif _mirror_gaze_time > 1.15 and not _mirror_revealed:
			_mirror_revealed = true
			for mark in _mirror_marks:
				if is_instance_valid(mark):
					mark.visible = true
			GameManager.add_threat(2.0)
			GameManager.show_message(
				"In the glass, pale marks crawl across the floor - and three scratched numbers: %d . %d . %d" %
				[int(_sandook_code[0]), int(_sandook_code[1]),
				int(_sandook_code[2])], 5.5)
		elif _mirror_gaze_time > 2.0:
			GameManager.add_sanity(-4.8 * delta)
			if _mirror_gaze_time > 3.4:
				_mirror_smile = true
				if _mirror_face != null:
					_mirror_face.visible = true
				if not _mirror_warned:
					_mirror_warned = true
					GameManager.show_message(
						"Your reflection is smiling. You are not.",
						3.8)
					ProcAudio.play_whisper(Vector3(25.8, 1.8, -5.4))
	else:
		_mirror_warned = false

	if _mirror_vision_timer <= 0.0:
		for mark in _mirror_marks:
			if is_instance_valid(mark):
				mark.visible = false

	# Corrupted water blur.
	if _blur_timer > 0.0:
		_blur_timer = maxf(0.0, _blur_timer - delta)
		if _blur_layer != null:
			_blur_layer.visible = true
		if _blur_mat != null:
			_blur_mat.set_shader_parameter("amount",
				clampf(_blur_timer / 4.8, 0.0, 1.0) * 1.25)
	else:
		if _blur_layer != null:
			_blur_layer.visible = false

	# The sandook lock. Every wrong turn is heard; your back stays turned.
	if _sandook_active:
		if _player == null or not is_instance_valid(_player) \
				or _player.is_dead():
			_close_sandook_ui()
		else:
			_sandook_fumble -= delta
			if _sandook_fumble <= 0.0:
				_sandook_fumble = 2.6
				GameEventBroker.player_noise_made.emit(8.0,
					_player.global_position)
				GameManager.add_threat(1.0)

	# Portrait Wall: the wedding guests step out of their frames.
	_bedroom_check -= delta
	if _bedroom_check <= 0.0:
		_bedroom_check = 0.35
		var s := GameManager.sanity
		for entry in _bedroom_portraits:
			var node: Node3D = entry["node"]
			if node == null or not is_instance_valid(node):
				continue
			var photo := node.get_node_or_null("Photograph") as MeshInstance3D
			if photo == null:
				continue
			var threshold := float(entry["threshold"])
			var gone := s < threshold
			photo.visible = not gone
			var key := String(entry["label"])
			if gone and not _portrait_warned.get(key, false):
				_portrait_warned[key] = true
				GameManager.show_message(
					"%s is no longer in the portrait. The frame is empty." % key,
					4.0)
				GameManager.add_threat(3.0)
				ProcAudio.play_whisper(node.global_position)
			elif not gone and _portrait_warned.get(key, false):
				_portrait_warned[key] = false


# =========================================================================
#  REAR WALKWAY  -  the long palace corridor and the Black Magician shrine
# =========================================================================
func _build_corridor() -> void:
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	var brass: Material = _mats["brass"]

	# A colonnade of shallow pilasters down both long walls.
	var x := PAL_XW + 2.2
	while x < PAL_XE - 1.0:
		_deco(Vector3(x, LOW_H * 0.5, HALL_ZB + 0.22),
			Vector3(0.34, LOW_H, 0.26), wd)
		_deco(Vector3(x, 0.16, HALL_ZB + 0.22),
			Vector3(0.50, 0.32, 0.36), wl)
		_deco(Vector3(x, LOW_H - 0.32, HALL_ZB + 0.22),
			Vector3(0.48, 0.30, 0.34), wl)
		_deco(Vector3(x, LOW_H * 0.5, CORR_ZB - 0.22),
			Vector3(0.34, LOW_H, 0.26), wd)
		_deco(Vector3(x, 0.16, CORR_ZB - 0.22),
			Vector3(0.50, 0.32, 0.36), wl)
		_deco(Vector3(x, LOW_H - 0.32, CORR_ZB - 0.22),
			Vector3(0.48, 0.30, 0.34), wl)
		x += 5.2

	# The Black Magician shrine, exactly as the reference: a dark central
	# niche, marigold garland, a single diya, a chair, and two rich ghost
	# portraits flanking the magician.
	var sx := -15.1
	_deco(Vector3(sx, 3.20, CORR_ZB + 0.18), Vector3(3.15, 5.40, 0.20),
		_mats["wood_dark"])
	_deco(Vector3(sx, 3.20, CORR_ZB + 0.29), Vector3(2.45, 4.60, 0.06),
		_mats["dark"])
	_deco(Vector3(sx, 5.92, CORR_ZB + 0.31), Vector3(3.55, 0.22, 0.34),
		wl)
	for px in [sx - 1.52, sx + 1.52]:
		_deco(Vector3(px, 3.20, CORR_ZB + 0.30), Vector3(0.22, 5.40, 0.26),
			wd)
		for k in 3:
			_deco(Vector3(px, 1.3 + float(k) * 1.7, CORR_ZB + 0.42),
				Vector3(0.30, 0.08, 0.10), brass)
	_deco(Vector3(sx, 1.02, CORR_ZB + 0.44), Vector3(2.1, 0.12, 0.50),
		wl)
	_deco(Vector3(sx, 0.50, CORR_ZB + 0.42), Vector3(1.75, 0.90, 0.38),
		wd)
	_diya(Vector3(sx, 1.12, CORR_ZB + 0.52), 1.8)
	_garland(Vector3(sx, 5.72, CORR_ZB + 0.44), 2.9, 0.34)
	_rich_photo_frame(Vector3(sx, 3.35, CORR_ZB + 0.42), 0.0, 1.70, 3.04,
		"black_magician", "THE BLACK MAGICIAN", true, true)
	# The two witnesses, angled out from the shrine.
	_rich_photo_frame(Vector3(sx - 2.35, 3.10, CORR_ZB + 0.28), 0.0,
		1.05, 1.42, "04_queen_ghost_solo", "THE QUEEN", true, true)
	_rich_photo_frame(Vector3(sx + 2.35, 3.10, CORR_ZB + 0.28), 0.0,
		1.05, 1.42, "03_king_ghost_solo", "THE KING WHO STAYED", true, true)
	_chair(Vector3(sx + 1.35, 0.0, -10.85), 168.0)
	_table(Vector3(sx - 1.55, 0.0, -10.9), Vector2(0.72, 0.72), 0.52)
	_candle(Vector3(sx - 1.55, 0.56, -10.9), 0.22)
	_lamp_light(Vector3(sx, 3.4, CORR_ZB + 1.2), 0.95,
		Color(0.92, 0.20, 0.08), 6.0)

	# A second, quieter portrait further down the walkway.
	_rich_photo_frame(Vector3(-2.9, 2.85, CORR_ZB - 0.14), 0.0,
		1.05, 1.42, "02_royal_couple_vibrant", "THE VIBRANT COURT", true, true)
	# And the weeping girl at the east end.
	_rich_photo_frame(Vector3(23.5, 2.80, HALL_ZB + 0.16), 180.0,
		1.00, 1.35, "10_girl_ghost_weeping", "THE WEEPING GIRL", true, false)

	# Light and seating. The centre of the walkway stays clear.
	for lx in [-22.0, -8.0, 7.0, 21.0]:
		_lantern(Vector3(lx, LOW_H - 0.4, -11.225), 1.5, 0.9, 8.0)
	for i in 4:
		_bench(Vector3(-24.0 + float(i) * 13.2, 0.0, HALL_ZB - 0.55),
			0.0, 2.4)
	_sconce(Vector3(-24.0, 2.35, HALL_ZB + 0.18), 0.55)
	_sconce(Vector3(24.0, 2.35, HALL_ZB + 0.18), 0.55)
	_sconce(Vector3(-6.0, 2.35, CORR_ZB - 0.15), 0.50,
		Vector3(0.0, 0.0, 1.0))
	_sconce(Vector3(14.0, 2.35, CORR_ZB - 0.15), 0.50,
		Vector3(0.0, 0.0, 1.0))
	# Ceiling beams make the long walk feel like a palace verandah.
	for bx in [-21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0]:
		_deco(Vector3(bx, LOW_H - 0.32, -11.225),
			Vector3(0.28, 0.28, 4.05), wd)


# =========================================================================
#  GUEST ROOM  -  14 x 12 m in the north-east corner
# =========================================================================
func _build_back_hall() -> void:
	var wd: Material = _mats["wood_dark"]
	# The old "back hall" slot is now the guest room. Everything is in
	# corners; the centre is empty.
	_bed(Vector3(24.7, 0.0, -21.4), -90.0, 2.2, 2.9)
	_canopy(Vector3(24.7, 0.0, -21.4), -90.0, 2.2, 2.9)
	_rug(Vector3(21.5, 0.020, -20.3), Vector2(4.6, 5.0),
		_mats["rug_inner"], _mats["rug"])
	_cupboard(Vector3(13.4, 0.0, -23.7), 90.0, 2.6, 3.5, 0.80, wd)
	_table(Vector3(14.0, 0.0, -15.4), Vector2(1.5, 0.6), 0.80)
	_mirror(Vector3(13.05, 1.95, -15.4), 90.0, 1.0, 1.35)
	_chair(Vector3(16.5, 0.0, -15.4), 90.0)
	_trunk(Vector3(23.7, 0.0, -14.4), 90.0)
	_window(Vector3(18.0, 2.7, PAL_ZB + 0.17), 0.0, 2.0, 2.0)
	_chhajja(18.0, 3.75, PAL_ZB + 0.17, 2.0)
	_palace_wing_chandelier(Vector3(18.0, 4.7, -19.3), 0.9, 1.3)
	_sconce(Vector3(12.9, 2.3, -18.0), 0.55, Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(23.0, 2.3, CORR_ZB - 0.19), 0.55,
		Vector3(0.0, 0.0, 1.0))
	_garland(Vector3(24.7, 3.75, -24.95), 2.0, 0.30)


# =========================================================================
#  POOJA ROOM  -  9.3 x 12 m, marble and brass
# =========================================================================
func _build_pooja() -> void:
	var marble: Material = _mats["marble"]
	var brass: Material = _mats["brass"]
	var wd: Material = _mats["wood_dark"]
	var cx := (POOJA_XW + POOJA_XE) * 0.5

	# Carved north wall and altar.
	_deco(Vector3(cx, 2.55, PAL_ZB + 0.42), Vector3(6.2, 5.10, 0.24), wd)
	_deco(Vector3(cx, 2.45, PAL_ZB + 0.55), Vector3(4.5, 3.5, 0.06),
		_mats["dark"])
	for px in [cx - 2.65, cx + 2.65]:
		_deco(Vector3(px, 2.55, PAL_ZB + 0.58), Vector3(0.25, 5.1, 0.28),
			_mats["wood_light"])
	_deco(Vector3(cx, 5.12, PAL_ZB + 0.58), Vector3(6.4, 0.24, 0.42),
		_mats["wood_light"])
	_solid(Vector3(cx, 0.22, PAL_ZB + 1.55), Vector3(4.8, 0.44, 1.35),
		marble)
	_solid(Vector3(cx, 0.10, PAL_ZB + 2.38), Vector3(5.1, 0.20, 0.38),
		marble)
	_deco(Vector3(cx, 0.45, PAL_ZB + 1.55), Vector3(4.5, 0.03, 1.15),
		_mats["cloth_red"])

	_idol(Vector3(cx - 1.5, 0.45, PAL_ZB + 1.55), 1.6)
	_idol(Vector3(cx, 0.45, PAL_ZB + 1.57), 1.9, _mats["dark"])
	_idol(Vector3(cx + 1.5, 0.45, PAL_ZB + 1.55), 1.6)
	_diya(Vector3(cx - 2.0, 0.47, PAL_ZB + 2.0), 1.7)
	_diya(Vector3(cx, 0.47, PAL_ZB + 1.98), 2.1)
	_diya(Vector3(cx + 2.0, 0.47, PAL_ZB + 2.0), 1.7)
	_pot(Vector3(cx - 2.25, 0.45, PAL_ZB + 1.55), 0.18, 0.34, brass)
	_sphere(Vector3(cx - 2.25, 0.83, PAL_ZB + 1.55), 0.10, _mats["green"])
	_pot(Vector3(cx + 2.25, 0.45, PAL_ZB + 1.55), 0.18, 0.34, brass)
	_sphere(Vector3(cx + 2.25, 0.83, PAL_ZB + 1.55), 0.10, _mats["green"])
	_bell(Vector3(cx - 2.35, 5.10, PAL_ZB + 1.35), 0.75, 1.3)
	_bell(Vector3(cx + 2.35, 5.10, PAL_ZB + 1.35), 0.75, 1.3)
	_puja_lamp(Vector3(cx, 5.10, PAL_ZB + 2.05), 1.15)

	# Rangoli in the centre of the room, prayer mats to the south.
	var rangoli := _torus(Vector3(cx, 0.035, REAR_MID_Z + 0.9), 0.72, 0.86,
		_mats["marigold"])
	for i in 10:
		var a := TAU * float(i) / 10.0
		var petal := _sphere(Vector3(cx + cos(a) * 0.55, 0.045,
			REAR_MID_Z + 0.9 + sin(a) * 0.55), 0.09, _mats["marigold2"])
		petal.scale = Vector3(1.0, 0.25, 1.0)
	for x in [cx - 0.55, cx + 0.55]:
		_deco(Vector3(x, 0.028, -17.5), Vector3(0.82, 0.05, 1.20),
			_mats["cloth_cream"])
		_deco(Vector3(x, 0.055, -17.5), Vector3(0.70, 0.02, 1.05),
			_mats["cloth_red"])

	# Side cupboard and brass ware at the east edge.
	_cupboard(Vector3(POOJA_XE - 0.55, 0.0, -22.2), -90.0, 2.2, 2.2,
		0.55, _mats["wood"])
	_pot(Vector3(POOJA_XE - 0.55, 2.25, -22.8), 0.12, 0.22, brass)
	_pot(Vector3(POOJA_XE - 0.55, 2.25, -22.2), 0.10, 0.18, brass)
	_incense_stand(Vector3(POOJA_XW + 0.85, 0.0, -15.6))
	_window(Vector3(POOJA_XE - 0.15, 2.9, -16.4), -90.0, 1.3, 1.6, false)
	_sconce(Vector3(POOJA_XW + 0.2, 2.4, -17.0), 0.55,
		Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(POOJA_XW + 0.2, 2.4, -22.6), 0.55,
		Vector3(1.0, 0.0, 0.0))
	_lantern(Vector3(cx, LOW_H - 0.4, -18.9), 1.4, 1.0, 8.0)
	_lamp_light(Vector3(cx, 3.4, PAL_ZB + 2.2), 1.1,
		Color(1.0, 0.66, 0.30), 6.0)
	_build_temple_sanctuary()


func _incense_stand(pos: Vector3) -> void:
	_cyl(pos + Vector3(0.0, 0.28, 0.0), 0.14, 0.56, _mats["brass"])
	_deco(pos + Vector3(0.0, 0.58, 0.0), Vector3(0.34, 0.05, 0.34),
		_mats["brass"])
	for i in 3:
		_cyl(pos + Vector3(-0.09 + float(i) * 0.09, 0.80, 0.0),
			0.005, 0.38, _mats["wood"])
		_sphere(pos + Vector3(-0.09 + float(i) * 0.09, 1.00, 0.0),
			0.010, _mats["flame"])


# =========================================================================
#  TANTRA ROOM  -  centred altar, wall sigil, red floor pentagram
# =========================================================================
func _build_tantra() -> void:
	var dark: Material = _mats["dark"]
	var soot: Material = _mats["soot"]
	var red: Material = _mats["cloth_red"]
	var iron: Material = _mats["iron"]
	var cx := (TANTRA_XW + TANTRA_XE) * 0.5

	# Drapes and painted wall sigil, exactly centred on the room.
	for i in 5:
		_deco(Vector3(cx - 2.8 + float(i) * 1.4, 1.55, PAL_ZB + 0.43),
			Vector3(1.05, 3.10, 0.07), red)
	_deco(Vector3(cx, 3.05, PAL_ZB + 0.45), Vector3(5.7, 0.18, 0.16), dark)
	_wall_sigil(Vector3(cx, 3.65, PAL_ZB + 0.48), 1.35)

	# Black altar and skulls.
	_solid(Vector3(cx, 0.45, PAL_ZB + 1.55), Vector3(4.6, 0.90, 1.15),
		soot)
	_deco(Vector3(cx, 0.92, PAL_ZB + 1.55), Vector3(4.75, 0.05, 1.24),
		_mats["tantra"])
	_deco(Vector3(cx, 0.90, PAL_ZB + 1.55), Vector3(4.4, 0.035, 1.02),
		red)
	for i in 4:
		_skull(Vector3(cx - 1.35 + float(i) * 0.90, 0.94,
			PAL_ZB + 1.32), 1.15)
	_candle(Vector3(cx - 2.0, 0.95, PAL_ZB + 1.66), 0.38)
	_candle(Vector3(cx + 2.0, 0.95, PAL_ZB + 1.66), 0.32)
	var book := Node3D.new()
	book.position = Vector3(cx, 0.96, PAL_ZB + 1.28)
	book.rotation_degrees.y = 16.0
	add_child(book)
	_deco(Vector3(0.0, 0.035, 0.0), Vector3(0.58, 0.07, 0.42),
		_mats["tantra"], book)
	_deco(Vector3(0.0, 0.075, 0.0), Vector3(0.52, 0.02, 0.36),
		_mats["cloth_cream"], book)
	_deco(Vector3(cx + 2.05, 0.96, PAL_ZB + 1.9),
		Vector3(0.54, 0.022, 0.055), iron)
	_deco(Vector3(cx + 2.36, 0.96, PAL_ZB + 1.9),
		Vector3(0.20, 0.04, 0.08), _mats["bone"])

	# The red pentagram is centred in the room, with a candle ring.
	_floor_sigil(Vector3(cx, 0.035, REAR_MID_Z), 2.35)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var p := Vector3(cx + cos(a) * 2.68, 0.0, REAR_MID_Z + sin(a) * 2.68)
		_cyl(p + Vector3(0.0, 0.11, 0.0), 0.036, 0.22,
			_mats["cloth_cream"])
		_sphere(p + Vector3(0.0, 0.25, 0.0), 0.028, _mats["flame"])

	# Nishanth's memorial on the side wall, clear of the ritual floor.
	_memorial_portrait(Vector3(TANTRA_XE - 0.18, 3.10, -19.4),
		0.95, 1.69, -90.0)
	_rich_photo_frame(Vector3(TANTRA_XE - 0.18, 2.95, -23.2), -90.0,
		0.95, 1.28, "03_king_ghost_solo", "THE KING WHO STAYED", true, false)
	_rich_photo_frame(Vector3(TANTRA_XW + 0.18, 2.95, -22.2), 90.0,
		0.95, 1.28, "08_girl_ghost_angry", "THE ANGRY ONE", true, false)

	# Occult clutter, all at the edges.
	_cyl(Vector3(TANTRA_XW + 1.2, 0.30, PAL_ZB + 1.4), 0.40, 0.60, iron)
	_torus(Vector3(TANTRA_XW + 1.2, 0.60, PAL_ZB + 1.4), 0.34, 0.44, iron)
	_cyl(Vector3(TANTRA_XW + 1.2, 0.62, PAL_ZB + 1.4), 0.33, 0.035,
		_emissive(Color(0.16, 0.80, 0.25), 1.6))
	for i in 3:
		var a2 := TAU * float(i) / 3.0
		_sphere(Vector3(TANTRA_XW + 1.2 + cos(a2) * 0.50, 0.03,
			PAL_ZB + 1.4 + sin(a2) * 0.50), 0.09, _mats["flame"])
	_deco(Vector3(TANTRA_XW + 0.32, 1.40, -17.2), Vector3(0.34, 0.06, 3.0),
		_mats["wood_dark"])
	_deco(Vector3(TANTRA_XW + 0.32, 2.00, -17.2), Vector3(0.34, 0.06, 3.0),
		_mats["wood_dark"])
	for i in 4:
		_jar(Vector3(TANTRA_XW + 0.32, 1.44, -18.25 + float(i) * 0.62), 1.0)
	for i in 3:
		_jar(Vector3(TANTRA_XW + 0.32, 2.04, -17.9 + float(i) * 0.62), 0.8)
	_cage(Vector3(TANTRA_XW + 1.3, LOW_H - 0.3, -15.6), 1.2)
	_chain_wall(Vector3(TANTRA_XE - 0.55, 2.55, PAL_ZB + 1.0))
	_chain_wall(Vector3(TANTRA_XW + 0.55, 2.20, -14.2))
	_doll(Vector3(TANTRA_XE - 0.8, 0.0, -14.4))
	for i in 6:
		var a3 := TAU * float(i) / 6.0
		var bone := _cyl(Vector3(TANTRA_XE - 1.0 + cos(a3) * 0.36, 0.06,
			-14.0 + sin(a3) * 0.32), 0.026, 0.56, _mats["bone"])
		bone.rotation_degrees.z = 90.0
		bone.rotation_degrees.y = rad_to_deg(a3)
	_skull(Vector3(TANTRA_XE - 1.0, 0.05, -14.0), 1.3)
	_lamp_light(Vector3(cx, 2.7, REAR_MID_Z + 1.0), 1.2,
		Color(0.90, 0.08, 0.04), 9.0)
	_lantern(Vector3(cx, LOW_H - 0.45, -17.6), 1.6, 0.9, 7.0)
	_sconce(Vector3(TANTRA_XW + 0.2, 2.4, -24.0), 0.50,
		Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(TANTRA_XE - 0.2, 2.4, -16.6), 0.50,
		Vector3(-1.0, 0.0, 0.0))
	_build_tantra_occult()


# =========================================================================
#  STAIR HALL  -  the old domestic stair is replaced by the rear tower
# =========================================================================
func _build_stair_hall() -> void:
	pass


# =========================================================================
#  UPPER GALLERY  -  a 53 m first-floor promenade over the rear walkway
# =========================================================================
func _build_upper_gallery() -> void:
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]

	# Pilasters and corbels break up the long north wall.
	var x := PAL_XW + 2.6
	while x < PAL_XE - 1.0:
		if absf(x) > 3.5:
			_deco(Vector3(x, LOW_H + 2.72, CORR_ZB + 0.20),
				Vector3(0.38, 5.44, 0.24), wd)
			_deco(Vector3(x, LOW_H + 0.18, CORR_ZB + 0.26),
				Vector3(0.56, 0.32, 0.34), wl)
			_deco(Vector3(x, GALLERY_H - 0.35, CORR_ZB + 0.26),
				Vector3(0.54, 0.30, 0.34), wl)
		x += 5.2

	# Seating in the bays. The centre line stays a clear 2.4 m promenade.
	_bench(Vector3(-24.2, LOW_H, CORR_ZB + 0.54), 0.0, 2.3)
	_bench(Vector3(-8.6, LOW_H, CORR_ZB + 0.54), 0.0, 2.1)
	_bench(Vector3(9.0, LOW_H, CORR_ZB + 0.54), 0.0, 2.1)
	_bench(Vector3(24.2, LOW_H, CORR_ZB + 0.54), 0.0, 2.3)

	# Low tables with a diya at either end.
	_table(Vector3(-20.2, LOW_H, CORR_ZB + 0.55), Vector2(1.1, 0.55), 0.54)
	_diya(Vector3(-20.2, LOW_H + 0.58, CORR_ZB + 0.55), 1.0)
	_table(Vector3(20.4, LOW_H, CORR_ZB + 0.55), Vector2(1.1, 0.55), 0.54)
	_diya(Vector3(20.4, LOW_H + 0.58, CORR_ZB + 0.55), 1.0)

	# Rich frames along both walls, high enough to read from the promenade.
	_rich_photo_frame(Vector3(-21.9, LOW_H + 2.62, CORR_ZB + 0.38), 0.0,
		1.20, 1.62, "09_couple_ghost_civilian", "THE OTHER WEDDING",
		true, true)
	_rich_photo_frame(Vector3(14.9, LOW_H + 2.62, CORR_ZB + 0.38), 0.0,
		1.05, 1.42, "06_girl_ghost_haunting", "THE ELDEST DAUGHTER",
		true, false)
	_rich_photo_frame(Vector3(-17.1, LOW_H + 2.52, HALL_ZB - 0.20), 180.0,
		1.15, 1.55, "10_girl_ghost_weeping", "THE WEEPING GIRL",
		true, true)
	_rich_photo_frame(Vector3(19.0, LOW_H + 2.52, HALL_ZB - 0.20), 180.0,
		1.10, 1.50, "05_couple_ghost_haveli", "THE HAVELI COUPLE",
		true, false)

	# A cabinet and a writing nook keep the far ends furnished without
	# crowding the walk.
	_cupboard(Vector3(PAL_XW + 0.66, LOW_H, -12.35), 90.0, 2.2, 2.6,
		0.58, wd)
	_pot(Vector3(PAL_XW + 0.80, LOW_H + 2.68, -12.8), 0.13, 0.24,
		_mats["brass"])
	_table(Vector3(PAL_XE - 1.15, LOW_H, -12.35), Vector2(1.2, 0.65), 0.78)
	_chair(Vector3(PAL_XE - 2.25, LOW_H, -12.35), -90.0)
	_candle(Vector3(PAL_XE - 1.35, LOW_H + 0.82, -12.35), 0.20)

	# Lanterns hang from the gallery roof in a long rhythm.
	for lx in [-24.0, -13.0, -2.0, 9.0, 20.0, 25.0]:
		_lantern(Vector3(lx, GALLERY_H - 0.35, -11.225), 1.30, 0.95, 7.5)
	_sconce(Vector3(0.0, LOW_H + 2.2, CORR_ZB + 0.30), 0.55,
		Vector3(0.0, 0.0, 1.0))
	_sconce(Vector3(-12.0, LOW_H + 2.2, CORR_ZB + 0.30), 0.50,
		Vector3(0.0, 0.0, 1.0))
	_sconce(Vector3(12.0, LOW_H + 2.2, CORR_ZB + 0.30), 0.50,
		Vector3(0.0, 0.0, 1.0))

	# A low red runner mirrors the processional route below.
	_rug(Vector3(0.0, LOW_H + 0.024, -11.225), Vector2(2.4, 3.8),
		_mats["rug"], _mats["rug_inner"])
	_lamp_light(Vector3(0.0, LOW_H + 2.5, -11.225), 0.85,
		Color(1.0, 0.58, 0.25), 9.0)


# =========================================================================
#  UPPER BEDROOM  -  the whole east wing at first-floor level
# =========================================================================
func _build_bedroom_upper() -> void:
	var y := LOW_H
	var wd: Material = _mats["wood_dark"]
	var wl: Material = _mats["wood_light"]
	var brass: Material = _mats["brass"]

	# Bed and canopy in the far south-east corner.
	_bed(Vector3(24.55, y, 5.55), -90.0, 2.60, 3.35)
	_canopy(Vector3(24.55, y, 5.55), -90.0, 2.60, 3.35)
	_doll(Vector3(23.6, y + 0.64, 5.0))
	_rug(Vector3(22.4, y + 0.020, 5.4), Vector2(5.4, 5.9),
		_mats["rug_inner"], _mats["rug"])

	# Wardrobe against the west wall, clear of the gallery door.
	_cupboard(Vector3(HALL_XE + 0.60, y, -5.8), 90.0, 3.6, 4.2, 0.85, wd)
	_mirror(Vector3(HALL_XE + 1.12, y + 2.10, -5.8), 90.0, 1.3, 1.7)
	_trunk(Vector3(12.1, y, 7.4), 0.0)
	_chair(Vector3(18.2, y, 7.9), 170.0)
	_table(Vector3(16.9, y, 7.9), Vector2(0.9, 0.7), 0.58)
	_diya(Vector3(16.9, y + 0.62, 7.9), 1.0)

	# Writing table and family photographs on the south wall.
	_table(Vector3(14.0, y, 8.25), Vector2(1.8, 0.55), 0.82)
	_mirror(Vector3(14.0, y + 1.86, 8.60), 180.0, 1.0, 1.25)
	_candle(Vector3(13.3, y + 0.86, 8.25), 0.22)
	_rich_photo_frame(Vector3(19.1, y + 2.86, PAL_ZF - 0.19), 180.0,
		1.35, 1.80, "09_couple_ghost_civilian", "THE OTHER WEDDING",
		true, true)
	_rich_photo_frame(Vector3(22.3, y + 2.76, PAL_ZF - 0.19), 180.0,
		1.05, 1.42, "07_girl_ghost_closeup", "SHE NEVER BLINKED",
		true, false)

	_window(Vector3(PAL_XE - 0.18, y + 2.55, 1.1), -90.0, 2.6, 2.5)
	_window(Vector3(PAL_XE - 0.18, y + 2.55, -6.1), -90.0, 2.3, 2.3)
	_window(Vector3(20.8, y + 2.65, PAL_ZF - 0.18), 180.0, 2.2, 2.2)
	_chhajja(20.8, y + 3.90, PAL_ZF - 0.10, 2.2)
	_palace_wing_chandelier(Vector3(19.0, y + 4.55, 0.0), 1.2, 1.8)
	_lantern(Vector3(19.2, HALL_H - 0.45, -6.8), 1.5, 0.9, 9.0)
	_sconce(Vector3(HALL_XE + 0.20, y + 2.35, 0.0), 0.55,
		Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(HALL_XE + 0.20, y + 2.35, 6.5), 0.55,
		Vector3(1.0, 0.0, 0.0))
	_sconce(Vector3(18.0, y + 2.35, PAL_ZF - 0.18), 0.55,
		Vector3(0.0, 0.0, -1.0))
	_garland(Vector3(19.1, y + 4.10, PAL_ZF - 0.24), 3.0, 0.38)
	_pot(Vector3(12.2, y, 1.4), 0.22, 0.40, _mats["clay"])
	_pot(Vector3(12.55, y, 2.0), 0.16, 0.30, _mats["clay"])
	_lamp_light(Vector3(17.0, y + 3.0, 5.2), 0.85,
		Color(1.0, 0.60, 0.28), 7.0)


# =========================================================================
#  EXTERIOR  -  veranda, courtyard, garden and the silent graveyard
# =========================================================================
func _build_exterior() -> void:
	var stone: Material = _mats["stone_b"]
	var dark: Material = _mats["wood_dark"]
	var plaster: Material = _mats["plaster"]
	var plaster_dark: Material = _mats["plaster_dark"]
	var iron: Material = _mats["iron"]
	var grass := _mat(Color(0.055, 0.115, 0.045), 0.96)
	var leaf := _mat(Color(0.075, 0.165, 0.060), 0.92)

	# The whole property, larger than the palace footprint.
	_solid(Vector3(0.0, -0.30, 8.0), Vector3(86.0, 0.50, 86.0),
		_mats["soil"])

	# ---- veranda ------------------------------------------------------
	_solid(Vector3(0.0, -0.01, 11.05), Vector3(53.4, 0.16, 3.80), stone)
	_deco(Vector3(0.0, 0.075, 12.92), Vector3(53.4, 0.04, 0.24),
		_mats["stone_a"])
	for i in 10:
		var cx := -25.2 + float(i) * 5.6
		_cyl(Vector3(cx, 2.42, 12.66), 0.27, 4.60, stone)
		_deco(Vector3(cx, 0.21, 12.66), Vector3(0.72, 0.28, 0.72),
			_mats["stone_a"])
		_deco(Vector3(cx, 4.56, 12.66), Vector3(0.62, 0.22, 0.62), stone)
		_deco(Vector3(cx, 4.80, 12.66), Vector3(0.92, 0.20, 0.92), dark)
		_blocker(Vector3(cx, 2.42, 12.66), Vector3(0.60, 4.70, 0.60))
	_solid(Vector3(0.0, 4.94, 11.00), Vector3(53.8, 0.22, 4.00), dark)
	_deco(Vector3(0.0, 4.82, 12.94), Vector3(53.8, 0.20, 0.20),
		_mats["wood_light"])
	_deco(Vector3(0.0, 4.62, 9.20), Vector3(53.8, 0.30, 0.18),
		plaster_dark)
	for lx in [-21.0, -10.5, 0.0, 10.5, 21.0]:
		_lantern(Vector3(lx, 4.78, 11.40), 0.55, 1.15, 7.5)

	# Entrance steps down to the courtyard.
	for i in 3:
		var sz := 13.10 + float(i) * 0.44
		_solid(Vector3(0.0, 0.05 - float(i) * 0.035, sz),
			Vector3(7.2, 0.14, 0.46), stone)
	# Veranda benches and pots, all at the edges.
	_bench(Vector3(-11.8, 0.07, 11.45), 0.0, 2.2)
	_bench(Vector3(11.8, 0.07, 11.45), 0.0, 2.2)
	_tulsi(Vector3(-5.6, 0.07, 10.55))
	_pot(Vector3(5.8, 0.07, 10.60), 0.24, 0.46, _mats["clay"])
	_pot(Vector3(6.4, 0.07, 10.25), 0.17, 0.34, _mats["clay"])
	_charpai(Vector3(20.5, 0.07, 11.20), 0.0)

	# ---- processional path --------------------------------------------
	_tile_floor(Rect2(-2.30, 13.20, 4.60, 10.80), _mats["stone_a"],
		_mats["stone_b"], 0.006, 0.82)
	_deco(Vector3(-2.42, 0.02, 18.6), Vector3(0.18, 0.05, 10.8),
		_mats["stone_b"])
	_deco(Vector3(2.42, 0.02, 18.6), Vector3(0.18, 0.05, 10.8),
		_mats["stone_b"])
	# Side paths to the well and the graveyard gate.
	_tile_floor(Rect2(-18.5, 15.9, 16.2, 1.9), _mats["stone_b"],
		_mats["stone_a"], 0.006, 0.75)
	_tile_floor(Rect2(2.3, 17.05, 6.2, 1.9), _mats["stone_b"],
		_mats["stone_a"], 0.006, 0.75)

	# ---- compound wall and closed gate --------------------------------
	for sx in [-1.0, 1.0]:
		_wall_x(sx * 34.0, 9.15, 23.90, 0.0, 2.80, plaster_dark, 0.45)
		_deco(Vector3(sx * 34.0, 2.84, 16.5), Vector3(0.62, 0.12, 14.90),
			stone)
		for gz in [9.4, 14.0, 18.6, 23.5]:
			_deco(Vector3(sx * 34.0, 1.45, gz), Vector3(0.72, 2.90, 0.72),
				stone)
			_sphere(Vector3(sx * 34.0, 2.98, gz), 0.18, _mats["brass"])
	_wall_z(23.90, -34.0, -2.60, 0.0, 2.80, plaster_dark, 0.45)
	_wall_z(23.90, 2.60, 34.0, 0.0, 2.80, plaster_dark, 0.45)
	_deco(Vector3(0.0, 2.86, 23.90), Vector3(4.60, 0.12, 0.62), stone)

	for sx in [-1.0, 1.0]:
		_deco(Vector3(sx * 2.60, 1.60, 23.90), Vector3(0.78, 3.20, 0.78),
			stone)
		_deco(Vector3(sx * 2.60, 3.24, 23.90), Vector3(0.98, 0.18, 0.98),
			_mats["stone_a"])
		_sphere(Vector3(sx * 2.60, 3.44, 23.90), 0.20, _mats["brass"])
	# Two closed iron leaves.
	for sx in [-1.0, 1.0]:
		var gx0: float = sx * 2.45
		var gx1: float = sx * 0.12
		for b in 8:
			var bx := lerpf(gx0, gx1, float(b) / 7.0)
			_cyl(Vector3(bx, 1.20, 23.90), 0.035, 2.30, iron)
			_sphere(Vector3(bx, 2.40, 23.90), 0.050, iron)
		for gy in [0.42, 1.20, 1.98]:
			_deco(Vector3((gx0 + gx1) * 0.5, gy, 23.90),
				Vector3(absf(gx1 - gx0), 0.065, 0.09), iron)
	_blocker(Vector3(0.0, 1.22, 23.90), Vector3(4.95, 2.45, 0.24))
	_torus(Vector3(0.0, 1.40, 23.80), 0.22, 0.28, iron)
	_lantern(Vector3(3.10, 2.55, 23.62), 0.48, 0.85, 5.5)
	_lantern(Vector3(-3.10, 2.55, 23.62), 0.48, 0.85, 5.5)

	# Road beyond the gate: only ever seen through the bars.
	_tile_floor(Rect2(-3.2, 24.0, 6.4, 14.0), _mats["stone_b"],
		_mats["soil"], 0.006, 0.9)

	# ---- garden --------------------------------------------------------
	_deco(Vector3(-19.4, 0.006, 18.0), Vector3(27.4, 0.012, 9.5), grass)
	_deco(Vector3(-32.2, 0.018, 18.0), Vector3(1.6, 0.030, 9.2),
		_mats["soil"])
	_deco(Vector3(-22.0, 0.018, 13.55), Vector3(13.0, 0.030, 1.4),
		_mats["soil"])
	_well(Vector3(-18.5, 0.0, 17.7))
	_lamp_light(Vector3(-18.5, 2.30, 17.7), 1.15,
		Color(1.0, 0.60, 0.26), 9.0)
	# Shrubs and hedges frame the lawn without closing the paths.
	for i in 9:
		var hx := -31.2 + float(i) * 3.0
		var hedge := _sphere(Vector3(hx, 0.42, 22.45), 0.62, leaf)
		hedge.scale = Vector3(1.25, 0.72, 1.0)
	for i in 5:
		var hz := 14.2 + float(i) * 2.0
		var shrub := _sphere(Vector3(-33.0, 0.40, hz), 0.55, leaf)
		shrub.scale = Vector3(0.9, 0.7, 1.1)
	_dead_tree(Vector3(-29.4, 0.0, 21.6))
	_yard_lamp(Vector3(-14.2, 0.0, 14.4))
	_yard_lamp(Vector3(-22.6, 0.0, 20.8))
	_yard_lamp(Vector3(-9.4, 0.0, 20.2))
	_lamp_light(Vector3(-13.8, 1.0, 17.8), 0.55,
		Color(1.0, 0.64, 0.30), 8.0)
	# Marigold beds along the west wall and south edge.
	for i in 9:
		var fz := 14.2 + float(i) * 0.95
		_sphere(Vector3(-32.2, 0.25, fz), 0.16, _mats["marigold"])
		_sphere(Vector3(-31.85, 0.22, fz + 0.28), 0.12,
			_mats["marigold2"])
		_sphere(Vector3(-32.45, 0.20, fz - 0.20), 0.11, leaf)
	for i in 11:
		var fx := -27.8 + float(i) * 1.05
		_sphere(Vector3(fx, 0.22, 13.55), 0.13, _mats["marigold"])
		_sphere(Vector3(fx + 0.30, 0.19, 13.85), 0.10, leaf)
	# Benches, a charpai and a dead tree.
	_bench(Vector3(-11.4, 0.0, 14.15), 0.0, 2.4)
	_bench(Vector3(-25.2, 0.0, 21.9), 180.0, 2.4)
	_charpai(Vector3(-25.6, 0.0, 14.35), 0.0)
	_tulsi(Vector3(-6.7, 0.0, 14.15))
	_pot(Vector3(-16.0, 0.0, 19.0), 0.26, 0.50, _mats["clay"])
	_pot(Vector3(-20.8, 0.0, 19.2), 0.20, 0.40, _mats["clay"])
	_yard_lamp(Vector3(-7.0, 0.0, 21.4))
	_yard_lamp(Vector3(-31.0, 0.0, 13.7))
	# Fireflies in the dark beds.
	for i in 18:
		var a := TAU * float(i) * 0.618
		var p := Vector3(-19.4 + cos(a) * (4.0 + float(i % 5) * 1.8),
			0.75 + 0.32 * float(i % 4),
			17.7 + sin(a) * (2.8 + float(i % 3) * 1.2))
		var fly := _sphere(p, 0.026, _mats["flame"])
		fly.name = "Firefly%d" % i

	# ---- graveyard -----------------------------------------------------
	_deco(Vector3(20.2, 0.006, 17.8), Vector3(23.6, 0.012, 9.4),
		_mats["soil"])
	_cemetery_fence(Rect2(8.4, 13.1, 23.6, 9.4))
	# The gate arch into the silent garden.
	for gz in [17.05, 18.95]:
		_deco(Vector3(8.4, 1.30, gz), Vector3(0.52, 2.60, 0.52), stone)
		_deco(Vector3(8.4, 2.66, gz), Vector3(0.70, 0.16, 0.70), stone)
		_sphere(Vector3(8.4, 2.88, gz), 0.13, iron)
		_blocker(Vector3(8.4, 1.30, gz), Vector3(0.55, 2.6, 0.55))
	_deco(Vector3(8.4, 2.48, 18.0), Vector3(0.22, 0.16, 2.4), iron)
	for i in 7:
		var sz := 17.05 + float(i) * 0.32
		_sphere(Vector3(8.4, 2.62, sz), 0.045, iron)
	_cyl(Vector3(8.4, 2.95, 18.0), 0.07, 0.55, iron)
	_sphere(Vector3(8.4, 3.25, 18.0), 0.11, _mats["bone"])

	# Rows of graves, some older and leaning.
	for row in 5:
		for col in 4:
			if (row == 2 and col == 1) or (row == 4 and col == 3):
				continue
			var gx := 12.7 + float(col) * 4.65
			var gz := 14.0 + float(row) * 2.05
			var tilt := -7.0 + float((row * 3 + col * 2) % 5) * 3.4
			_grave(Vector3(gx, 0.0, gz), -90.0, 1.0, tilt)
	# Two small stones by the arch.
	_grave(Vector3(10.4, 0.0, 20.9), -90.0, 0.62, 4.0)
	_grave(Vector3(10.4, 0.0, 15.3), -90.0, 0.58, -6.0)

	# The chhatri at the east end.
	_cemetery_chhatri(Vector3(28.6, 0.0, 18.0))
	_dead_tree(Vector3(10.3, 0.0, 21.9))
	_dead_tree(Vector3(31.4, 0.0, 14.2))
	# Low lamps between the rows keep the stones readable.
	_yard_lamp(Vector3(9.9, 0.0, 21.6))
	_yard_lamp(Vector3(31.0, 0.0, 22.0))
	_lamp_light(Vector3(15.2, 1.10, 17.9), 0.60,
		Color(0.48, 0.52, 0.78), 8.5)
	_lamp_light(Vector3(22.8, 1.10, 17.9), 0.60,
		Color(0.48, 0.52, 0.78), 8.5)
	for cp in [Vector3(12.7, 1.10, 14.0), Vector3(17.35, 1.10, 18.1),
			Vector3(26.7, 1.10, 16.0), Vector3(28.6, 2.95, 18.0)]:
		_crow(cp)
	# Candles left at a few graves.
	for cz in [14.0, 16.05, 18.1, 20.15]:
		_candle(Vector3(15.1, 0.20, cz), 0.18)
	for i in 5:
		var bone := _cyl(Vector3(14.0 + float(i) * 3.1, 0.06,
			21.6 - float(i % 2) * 0.8), 0.025, 0.48, _mats["bone"])
		bone.rotation_degrees.z = 90.0
		bone.rotation_degrees.y = 20.0 + float(i) * 33.0
	_lantern(Vector3(11.5, 2.55, 17.9), 0.65, 1.0, 7.0)
	_lantern(Vector3(29.6, 3.05, 18.0), 0.75, 1.0, 7.0)
	_lamp_light(Vector3(28.6, 2.1, 18.0), 0.85,
		Color(0.90, 0.16, 0.08), 7.0)
	_lamp_light(Vector3(20.0, 1.4, 17.8), 0.55,
		Color(0.35, 0.42, 0.72), 8.0)

	# ---- front elevation windows and trims -----------------------------
	for bx in [-22.0, -17.5, -13.0]:
		_window(Vector3(bx, 2.35, PAL_ZF + 0.19), 0.0, 1.55, 2.15, false)
		_chhajja(bx, 3.62, PAL_ZF + 0.12, 1.55)
	for bx in [14.6, 19.6, 24.2]:
		_window(Vector3(bx, 2.35, PAL_ZF + 0.19), 0.0, 1.55, 2.15, false)
		_chhajja(bx, 3.62, PAL_ZF + 0.12, 1.55)
	for bx in [-7.0, 7.0]:
		_window(Vector3(bx, 2.35, PAL_ZF + 0.19), 0.0, 1.35, 2.15, true)
		_chhajja(bx, 3.62, PAL_ZF + 0.12, 1.35)
	# Upper-floor windows over the east wing.
	for bx in [14.6, 19.6, 24.2]:
		_window(Vector3(bx, LOW_H + 2.55, PAL_ZF + 0.19), 0.0,
			1.45, 2.05, true)
		_chhajja(bx, LOW_H + 3.82, PAL_ZF + 0.12, 1.45)
	_deco(Vector3(0.0, LOW_H + 0.16, PAL_ZF + 0.22),
		Vector3(53.2, 0.18, 0.18), plaster)
	_deco(Vector3(0.0, HALL_H - 0.55, PAL_ZF + 0.20),
		Vector3(53.2, 0.16, 0.16), plaster_dark)
	for sx in [-26.35, -11.55, 11.55, 26.35]:
		_deco(Vector3(sx, 6.8, PAL_ZF + 0.22), Vector3(0.30, 13.4, 0.14),
			plaster_dark)

	# Moon and stars.
	_sphere(Vector3(28.0, 44.0, -72.0), 3.5, _mats["moon_glow"])
	for i in 34:
		var az := TAU * float(i) * 0.618
		var el := deg_to_rad(14.0 + fmod(float(i) * 37.0, 58.0))
		var p := Vector3(cos(az) * cos(el) * 64.0, sin(el) * 64.0 + 10.0,
			sin(az) * cos(el) * 64.0)
		_sphere(p, 0.22 + 0.05 * float(i % 3), _mats["star"])


func _cemetery_fence(rect: Rect2) -> void:
	var iron: Material = _mats["iron"]
	var stone: Material = _mats["stone_a"]
	var x0 := rect.position.x
	var x1 := rect.position.x + rect.size.x
	var z0 := rect.position.y
	var z1 := rect.position.y + rect.size.y
	# North and south runs.
	for z in [z0, z1]:
		_deco(Vector3((x0 + x1) * 0.5, 0.20, z),
			Vector3(x1 - x0, 0.40, 0.26), stone)
		_deco(Vector3((x0 + x1) * 0.5, 0.86, z),
			Vector3(x1 - x0, 0.055, 0.055), iron)
		_deco(Vector3((x0 + x1) * 0.5, 1.42, z),
			Vector3(x1 - x0, 0.055, 0.055), iron)
		var x := x0
		while x <= x1 + 0.01:
			_cyl(Vector3(x, 0.86, z), 0.040, 1.32, iron)
			_sphere(Vector3(x, 1.54, z), 0.055, iron)
			x += 1.65
		_blocker(Vector3((x0 + x1) * 0.5, 0.82, z),
			Vector3(x1 - x0, 1.55, 0.16))
	# East run, full length.
	_deco(Vector3(x1, 0.20, (z0 + z1) * 0.5),
		Vector3(0.26, 0.40, z1 - z0), stone)
	_deco(Vector3(x1, 0.86, (z0 + z1) * 0.5),
		Vector3(0.055, 0.055, z1 - z0), iron)
	_deco(Vector3(x1, 1.42, (z0 + z1) * 0.5),
		Vector3(0.055, 0.055, z1 - z0), iron)
	var z := z0
	while z <= z1 + 0.01:
		_cyl(Vector3(x1, 0.86, z), 0.040, 1.32, iron)
		_sphere(Vector3(x1, 1.54, z), 0.055, iron)
		z += 1.65
	_blocker(Vector3(x1, 0.82, (z0 + z1) * 0.5),
		Vector3(0.16, 1.55, z1 - z0))
	# West run, with the arched entrance left open.
	for seg in [Vector2(z0, 16.95), Vector2(19.05, z1)]:
		var za: float = seg.x
		var zb: float = seg.y
		_deco(Vector3(x0, 0.20, (za + zb) * 0.5),
			Vector3(0.26, 0.40, zb - za), stone)
		_deco(Vector3(x0, 0.86, (za + zb) * 0.5),
			Vector3(0.055, 0.055, zb - za), iron)
		_deco(Vector3(x0, 1.42, (za + zb) * 0.5),
			Vector3(0.055, 0.055, zb - za), iron)
		var zz := za
		while zz <= zb + 0.01:
			_cyl(Vector3(x0, 0.86, zz), 0.040, 1.32, iron)
			_sphere(Vector3(x0, 1.54, zz), 0.055, iron)
			zz += 1.65
		_blocker(Vector3(x0, 0.82, (za + zb) * 0.5),
			Vector3(0.16, 1.55, zb - za))


func _grave(pos: Vector3, yaw_deg: float, scale := 1.0,
		tilt := 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = Vector3(0.0, yaw_deg, tilt)
	add_child(n)
	var stone: Material = _mats["stone_b"]
	var kerb: Material = _mats["stone_a"]
	var dark: Material = _mats["dark"]
	var bone: Material = _mats["bone"]
	# Plot, kerb and a low mound.
	_deco(Vector3(0.0, 0.030, 0.12), Vector3(1.26 * scale, 0.06,
		2.32 * scale), _mats["soil"], n)
	for sx in [-1.0, 1.0]:
		_deco(Vector3(sx * 0.66 * scale, 0.11, 0.12),
			Vector3(0.08, 0.22, 2.42 * scale), kerb, n)
	_deco(Vector3(0.0, 0.11, -1.02 * scale),
		Vector3(1.40 * scale, 0.22, 0.08), kerb, n)
	_deco(Vector3(0.0, 0.11, 1.26 * scale),
		Vector3(1.40 * scale, 0.22, 0.08), kerb, n)
	var mound := _sphere(Vector3(0.0, 0.09, 0.34 * scale),
		0.54 * scale, _mats["soil"], n)
	mound.scale = Vector3(1.0, 0.24, 1.45)
	# Headstone with a rounded top.
	_deco(Vector3(0.0, 0.58 * scale, -0.80 * scale),
		Vector3(0.78 * scale, 1.16 * scale, 0.16 * scale), stone, n)
	var cap := _sphere(Vector3(0.0, 1.15 * scale, -0.80 * scale),
		0.39 * scale, stone, n)
	cap.scale = Vector3(1.0, 0.58, 0.24)
	# Cross and carved lines.
	_deco(Vector3(0.0, 0.92 * scale, -0.70 * scale),
		Vector3(0.09 * scale, 0.66 * scale, 0.07 * scale), dark, n)
	_deco(Vector3(0.0, 1.06 * scale, -0.70 * scale),
		Vector3(0.46 * scale, 0.09 * scale, 0.07 * scale), dark, n)
	for i in 3:
		_deco(Vector3(0.0, (0.46 + float(i) * 0.13) * scale,
			-0.705 * scale), Vector3(0.34 * scale, 0.022, 0.02), bone, n)
	# A little offering on the grave.
	if scale > 0.75:
		_cyl(Vector3(0.36 * scale, 0.22, 0.42 * scale),
			0.020, 0.18, bone, n)
		_sphere(Vector3(0.36 * scale, 0.32, 0.42 * scale), 0.022,
			_mats["flame"], n)


func _cemetery_chhatri(pos: Vector3) -> void:
	var stone: Material = _mats["stone_b"]
	var pale: Material = _mats["stone_a"]
	var dark: Material = _mats["wood_dark"]
	_solid(pos + Vector3(0.0, 0.16, 0.0), Vector3(4.8, 0.32, 4.8),
		pale)
	_solid(pos + Vector3(0.0, 0.34, 0.0), Vector3(4.2, 0.12, 4.2),
		stone)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := pos + Vector3(sx * 1.55, 1.62, sz * 1.55)
			_cyl(p, 0.20, 2.56, stone)
			_deco(p + Vector3(0.0, -1.18, 0.0),
				Vector3(0.52, 0.20, 0.52), pale)
			_deco(p + Vector3(0.0, 1.18, 0.0),
				Vector3(0.46, 0.16, 0.46), pale)
			_blocker(p, Vector3(0.44, 2.56, 0.44))
	_solid(pos + Vector3(0.0, 2.98, 0.0), Vector3(4.5, 0.30, 4.5), stone)
	var dome := _sphere(pos + Vector3(0.0, 3.55, 0.0), 1.85, pale)
	dome.scale = Vector3(1.0, 0.68, 1.0)
	_cyl(pos + Vector3(0.0, 4.55, 0.0), 0.10, 0.70, _mats["brass"])
	_sphere(pos + Vector3(0.0, 4.95, 0.0), 0.16, _mats["brass"])
	# Sarcophagus and grave goods under the dome.
	_solid(pos + Vector3(0.0, 0.66, 0.0), Vector3(1.30, 0.64, 2.40), stone)
	_deco(pos + Vector3(0.0, 1.02, 0.0), Vector3(1.44, 0.10, 2.54), pale)
	_blocker(pos + Vector3(0.0, 0.66, 0.0), Vector3(1.35, 0.70, 2.45))
	for sx in [-1.0, 1.0]:
		_candle(pos + Vector3(sx * 1.90, 0.42, 1.55), 0.34)
		_candle(pos + Vector3(sx * 1.90, 0.42, -1.55), 0.28)
	_garland(pos + Vector3(0.0, 2.78, 2.18), 3.0, 0.35)
	_deco(pos + Vector3(0.0, 2.55, 2.18), Vector3(3.4, 0.15, 0.16), dark)


# =========================================================================
#  FLOOR SIGNATURES
# =========================================================================
func _build_floor_signatures() -> void:
	# Only the two main approach points carry the maker's name.
	_floor_text("A GAME BY\nNISHANTH", Vector3(0.0, 0.055, 19.1),
		42, 0.0078, Color(0.80, 0.77, 0.66), 0.0)
	_floor_text("A GAME BY NISHANTH", Vector3(0.0, 0.055, 6.55),
		40, 0.0062, Color(0.48, 0.075, 0.055), 0.0)


# =========================================================================
#  TEMPLE SANCTUARY  -  the pooja room is the only place Kamla cannot enter
# =========================================================================
func _build_temple_sanctuary() -> void:
	var cx := (POOJA_XW + POOJA_XE) * 0.5
	var iron: Material = _mats["iron"]
	var dark: Material = _mats["dark"]
	var ash := _mat(Color(0.58, 0.56, 0.50), 1.0)
	var withered := _mat(Color(0.24, 0.145, 0.070), 0.98)

	# The original central idol gains the Weeping Murti's face. The geometry
	# is laid over the existing statue so the old altar keeps its silhouette.
	_build_murti_face(cx)
	_altar_point = _hinteract(Vector3(cx, 1.10, -22.55),
		Vector3(3.5, 2.2, 1.5), "Pray at the weeping murti",
		_on_altar_interact)
	_build_withered_garlands(cx, withered)

	# The everlasting diya, the room's heart and save point.
	_build_everlasting_diya(cx)
	_diya_point = _hinteract(Vector3(cx, 1.15, -20.15),
		Vector3(1.6, 2.2, 1.0), "Rest at the everlasting diya",
		_on_everlasting_interact)

	# The vibhuti urn against the west wall.
	_build_vibhuti_urn(ash)
	_vibhuti_point = _hinteract(Vector3(4.40, 1.15, -21.40),
		Vector3(1.25, 1.9, 1.25), "Scoop sacred ash",
		_on_vibhuti_interact)

	_build_temple_bells(cx)
	_add_ash_thresholds()

	# Kamla and all lesser dead collide with layer 6. The living do not.
	_ghost_gate(Vector3(7.90, 2.05, CORR_ZB - 0.02),
		Vector3(2.75, 4.10, 0.40))

	_build_temple_supplies()
	_lamp_light(Vector3(cx, 3.0, -22.8), 0.65,
		Color(1.0, 0.66, 0.32), 5.0)


func _build_murti_face(cx: float) -> void:
	var dark: Material = _mats["dark"]
	var ash := _mat(Color(0.62, 0.59, 0.52), 0.95)
	var tear := _emissive(Color(0.35, 0.58, 0.68), 0.40)
	# The central idol's head is a 0.228 m sphere centered at z=-23.73.
	# Keep the face just in front of that surface, or the overlays vanish
	# inside the statue.
	var face_z := PAL_ZB + 1.845

	_murti_normal = Node3D.new()
	_murti_normal.name = "MurtiSerene"
	add_child(_murti_normal)
	for sx in [-1.0, 1.0]:
		_deco(Vector3(cx + sx * 0.080, 1.962, face_z),
			Vector3(0.082, 0.014, 0.020), dark, _murti_normal)
		_deco(Vector3(cx + sx * 0.080, 2.022, face_z + 0.004),
			Vector3(0.098, 0.014, 0.020), ash, _murti_normal)
	_deco(Vector3(cx, 1.792, face_z), Vector3(0.078, 0.010, 0.018),
		dark, _murti_normal)

	_murti_furious = Node3D.new()
	_murti_furious.name = "MurtiFurious"
	_murti_furious.visible = false
	add_child(_murti_furious)
	for sx in [-1.0, 1.0]:
		_sphere(Vector3(cx + sx * 0.082, 1.968, face_z + 0.008), 0.034,
			_emissive(Color(1.0, 0.10, 0.02), 2.6), _murti_furious)
		var brow := _deco(Vector3(cx + sx * 0.080, 2.032, face_z),
			Vector3(0.112, 0.024, 0.022), dark, _murti_furious)
		brow.rotation_degrees.z = sx * 18.0
	_deco(Vector3(cx, 1.786, face_z + 0.004),
		Vector3(0.126, 0.060, 0.020), dark, _murti_furious)
	for i in 4:
		_deco(Vector3(cx - 0.045 + float(i) * 0.030, 1.806,
			face_z + 0.014), Vector3(0.020, 0.030, 0.012), ash,
			_murti_furious)
	_sphere(Vector3(cx, 2.118, face_z), 0.030,
		_emissive(Color(1.0, 0.08, 0.02), 2.8), _murti_furious)

	# The tears never stop, even when the face is furious.
	for sx in [-1.0, 1.0]:
		_deco(Vector3(cx + sx * 0.096, 1.855, face_z + 0.010),
			Vector3(0.014, 0.20, 0.012), tear)
		_sphere(Vector3(cx + sx * 0.096, 1.744, face_z + 0.012),
			0.018, tear)

	_murti_wrath_light = OmniLight3D.new()
	_murti_wrath_light.position = Vector3(cx, 2.05, -23.15)
	_murti_wrath_light.light_color = Color(0.95, 0.10, 0.03)
	_murti_wrath_light.light_energy = 0.0
	_murti_wrath_light.omni_range = 3.2
	_murti_wrath_light.shadow_enabled = false
	add_child(_murti_wrath_light)


func _garland_strand(pos: Vector3, width: float, drop: float,
		mat: Material, parent: Node3D = null) -> void:
	var n := maxi(6, int(width / 0.13))
	for i in n:
		var t := float(i) / float(n - 1)
		var local := Vector3((t - 0.5) * width, -sin(t * PI) * drop, 0.0)
		_sphere(pos + local, 0.052, mat, parent)


func _build_withered_garlands(cx: float, withered: Material) -> void:
	var fresh_a: Material = _mats["marigold"]
	var fresh_b: Material = _mats["marigold2"]
	for i in 3:
		var wx := cx - 1.55 + float(i) * 1.55
		var wroot := Node3D.new()
		wroot.name = "WitheredGarland%d" % i
		add_child(wroot)
		_garland_strand(Vector3(wx, 1.00, PAL_ZB + 2.08), 1.55, 0.16,
			withered, wroot)
		_withered_garlands.append(wroot)
		var froot := Node3D.new()
		froot.name = "FreshGarland%d" % i
		froot.visible = false
		add_child(froot)
		_garland_strand(Vector3(wx, 1.03, PAL_ZB + 2.07), 1.55, 0.18,
			fresh_a, froot)
		_garland_strand(Vector3(wx, 0.99, PAL_ZB + 2.11), 1.45, 0.14,
			fresh_b, froot)
		_fresh_garland_segments.append(froot)


func _build_everlasting_diya(cx: float) -> void:
	var brass: Material = _mats["brass"]
	var marble: Material = _mats["marble"]
	var iron: Material = _mats["iron"]
	var pos := Vector3(cx, 0.0, -20.90)

	_solid(pos + Vector3(0.0, 0.26, 0.0), Vector3(1.10, 0.52, 1.10),
		marble)
	_deco(pos + Vector3(0.0, 0.55, 0.0), Vector3(0.82, 0.07, 0.82),
		_mats["stone_a"])
	_cyl(pos + Vector3(0.0, 0.93, 0.0), 0.16, 0.78, brass)
	_cyl(pos + Vector3(0.0, 1.36, 0.0), 0.48, 0.18, brass)
	_torus(pos + Vector3(0.0, 1.46, 0.0), 0.39, 0.53, brass)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var p := pos + Vector3(cos(a) * 0.30, 1.53, sin(a) * 0.30)
		_cyl(p, 0.060, 0.08, iron)
		var flame := _sphere(p + Vector3(0.0, 0.10, 0.0), 0.045,
			_mats["flame"])
		_everlasting_flames.append(flame)
	_cyl(pos + Vector3(0.0, 1.63, 0.0), 0.075, 0.075, _mats["flame"])
	var heart := _sphere(pos + Vector3(0.0, 1.73, 0.0), 0.075,
		_mats["flame"])
	_everlasting_flames.append(heart)

	_everlasting_light = _lamp_light(pos + Vector3(0.0, 2.05, 0.0), 2.35,
		Color(1.0, 0.62, 0.28), 11.0)
	_everlasting_light.set_meta("base", 2.35)
	# Two brass oil pots at the pedestal's edge.
	for sx in [-1.0, 1.0]:
		_cyl(pos + Vector3(sx * 0.72, 0.22, 0.0), 0.17, 0.44, brass)
		_torus(pos + Vector3(sx * 0.72, 0.44, 0.0), 0.10, 0.18, iron)


func _build_vibhuti_urn(ash: Material) -> void:
	var brass: Material = _mats["brass"]
	var marble: Material = _mats["marble"]
	var pos := Vector3(4.40, 0.0, -21.40)

	_solid(pos + Vector3(0.0, 0.11, 0.0), Vector3(0.94, 0.22, 0.94),
		marble)
	var body := _sphere(pos + Vector3(0.0, 0.60, 0.0), 0.40, brass)
	body.scale = Vector3(1.0, 1.08, 1.0)
	_cyl(pos + Vector3(0.0, 1.02, 0.0), 0.245, 0.18, brass)
	_torus(pos + Vector3(0.0, 1.115, 0.0), 0.205, 0.290, brass)
	_cyl(pos + Vector3(0.0, 1.095, 0.0), 0.205, 0.05, ash)
	# The scoop resting across the rim.
	var scoop := _cyl(pos + Vector3(0.19, 1.19, 0.05), 0.060, 0.035,
		brass)
	scoop.rotation_degrees.z = 24.0
	_deco(pos + Vector3(0.33, 1.22, 0.05), Vector3(0.24, 0.025, 0.035),
		brass)
	_blocker(pos + Vector3(0.0, 0.55, 0.0), Vector3(0.86, 1.10, 0.86))
	_lamp_light(pos + Vector3(0.0, 1.45, 0.0), 0.30,
		Color(0.95, 0.88, 0.70), 2.8)


func _build_temple_bells(cx: float) -> void:
	var brass: Material = _mats["brass"]
	var iron: Material = _mats["iron"]
	var dark: Material = _mats["wood_dark"]

	_deco(Vector3(cx, 6.50, -16.10), Vector3(6.9, 0.17, 0.17), dark)
	for i in 7:
		var x := cx - 3.0 + float(i)
		var pivot := Node3D.new()
		pivot.name = "Ghanti%d" % i
		pivot.position = Vector3(x, 6.42, -16.10)
		add_child(pivot)
		_cyl(Vector3(0.0, -0.55, 0.0), 0.010, 1.10, iron, pivot)
		var mi := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.052
		mesh.bottom_radius = 0.190
		mesh.height = 0.30
		mi.mesh = mesh
		mi.material_override = brass
		mi.position = Vector3(0.0, -1.18, 0.0)
		pivot.add_child(mi)
		_sphere(Vector3(0.0, -1.36, 0.0), 0.046, iron, pivot)
		_temple_bells.append(pivot)


func _add_ash_thresholds() -> void:
	# The interaction points sit to one side of each doorway. Centering them
	# on the threshold would put their collision box in front of the door
	# and swallow the normal "open door" prompt.
	_add_ash_threshold(Vector3(9.55, 1.15, -14.35),
		Vector3(7.90, 0.0, CORR_ZB - 0.06), 2.9)
	_add_ash_threshold(Vector3(-11.35, 1.15, -14.35),
		Vector3(-9.10, 0.0, CORR_ZB - 0.06), 2.9)
	_add_ash_threshold(Vector3(-23.55, 1.15, -14.35),
		Vector3(-21.10, 0.0, CORR_ZB - 0.06), 2.9)
	_add_ash_threshold(Vector3(22.55, 1.15, -14.35),
		Vector3(20.90, 0.0, CORR_ZB - 0.06), 2.9)
	_add_ash_threshold(Vector3(3.15, 1.15, 10.15),
		Vector3(0.0, 0.0, HALL_ZF + 0.06), 4.2)
	_add_ash_threshold(Vector3(-17.35, 1.15, -10.15),
		Vector3(-19.70, 0.0, HALL_ZB - 0.06), 2.5)
	_add_ash_threshold(Vector3(22.55, LOW_H + 1.15, -10.15),
		Vector3(20.90, LOW_H, HALL_ZB - 0.06), 2.5)


func _add_ash_threshold(pos: Vector3, barrier: Vector3, width: float) -> void:
	# A small grey mark on the floor shows where the vibhuti line can be
	# drawn without the interaction box covering the door itself.
	var floor_y := LOW_H if pos.y > LOW_H * 0.5 else 0.0
	_deco(Vector3(pos.x, floor_y + 0.015, pos.z),
		Vector3(0.34, 0.025, 0.34), _mat(Color(0.62, 0.60, 0.54), 1.0))
	var point := _hinteract(pos, Vector3(0.95, 2.2, 1.0), "",
		Callable())
	point.prompt_provider = func() -> String:
		if _ash_charges <= 0:
			return "Sacred ash needed - gather vibhuti in the pooja room"
		return "Draw a sacred ash barrier (%d left)" % _ash_charges
	point.used.connect(_on_ash_threshold.bind(barrier, width))


func _hinteract(pos: Vector3, size: Vector3, label: String,
		cb: Callable, solid := false) -> HaveliInteractable:
	var node := HaveliInteractable.new()
	node.name = "HaveliPoint"
	node.position = pos
	node.prompt_text = label
	node.collision_layer = 9 if solid else 8
	node.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	node.add_child(shape)
	add_child(node)
	if cb.is_valid():
		node.used.connect(cb)
	return node


func _ghost_gate(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "GhostGate"
	body.position = pos
	body.collision_layer = 32
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


func _has_cursed_items() -> bool:
	return not _cursed_items.is_empty()


func _update_temple(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_pray_cooldown = maxf(0.0, _pray_cooldown - delta)
	_diya_rest_cooldown = maxf(0.0, _diya_rest_cooldown - delta)
	_bell_notice_cooldown = maxf(0.0, _bell_notice_cooldown - delta)

	_murti_check -= delta
	if _murti_check <= 0.0:
		_murti_check = 0.35
		_update_murti_expression()

	# The ghanti row sways, and rings when the dead come near.
	var alarm := _ghost_near_temple()
	if _live and alarm and not _bell_alarm and _bell_notice_cooldown <= 0.0:
		_bell_notice_cooldown = 18.0
		GameManager.show_message(
			"The temple bells begin to ring on their own. Kamla is near.",
			4.0)
	_bell_alarm = alarm
	for i in _temple_bells.size():
		var pivot := _temple_bells[i]
		if not is_instance_valid(pivot):
			continue
		var amp := 0.38 if _bell_alarm else 0.030
		pivot.rotation.z = sin(t * 5.2 + float(i) * 0.72) * amp
		pivot.rotation.x = sin(t * 3.7 + float(i) * 1.1) * amp * 0.55
	if _bell_alarm:
		_bell_chime -= delta
		if _bell_chime <= 0.0:
			_bell_chime = randf_range(1.1, 2.3)
			var idx := randi() % _temple_bells.size()
			ProcAudio.play_bell(_temple_bells[idx].global_position,
				randf_range(0.92, 1.08))

	if _live and _diya_lit:
		_diya_fuel -= delta
		if _diya_fuel <= 0.0:
			_extinguish_diya()

	if _blessing_timer > 0.0:
		_blessing_timer -= delta
		GameManager.add_sanity(_blessing_rate * delta)
		if _player != null and is_instance_valid(_player):
			_player.heal(0.45 * delta)
		if _blessing_timer <= 0.0:
			GameManager.show_message(
				"The marigold blessing settles into your bones.", 3.0)

	# Barriers of vibhuti burn down after twenty-five seconds.
	for i in range(_barriers.size() - 1, -1, -1):
		var b: Dictionary = _barriers[i]
		b["timer"] = float(b["timer"]) - delta
		var light := b["light"] as OmniLight3D
		if is_instance_valid(light):
			light.light_energy = 0.50 + 0.22 * sin(t * 5.4)
		if float(b["timer"]) <= 0.0:
			var root := b["root"] as Node3D
			if is_instance_valid(root):
				root.queue_free()
			var gate := b["gate"] as StaticBody3D
			if is_instance_valid(gate):
				gate.queue_free()
			_barriers.remove_at(i)

	_update_temple_prompts()
	_enforce_sanctuary(delta)

	if _live and _player != null and is_instance_valid(_player):
		var p := _player.global_position
		if p.x > POOJA_XW and p.x < POOJA_XE and p.z < CORR_ZB:
			GameManager.complete_objective("sanctuary")


func _update_temple_prompts() -> void:
	if _altar_point != null and is_instance_valid(_altar_point):
		if _fresh_garlands > 0 and _garlands_replaced < 3:
			_altar_point.prompt_text = \
				"Replace the withered garland (%d fresh left)" % _fresh_garlands
		elif _garlands_replaced < 3:
			_altar_point.prompt_text = \
				"Pray at the weeping murti (fresh marigolds in the garden)"
		else:
			_altar_point.prompt_text = "Pray at the weeping murti"

	if _vibhuti_point != null and is_instance_valid(_vibhuti_point):
		if _ash_charges >= 3:
			_vibhuti_point.prompt_text = "Your palms are full of sacred ash (3/3)"
		else:
			_vibhuti_point.prompt_text = "Scoop sacred ash (%d/3)" % _ash_charges

	if _diya_point != null and is_instance_valid(_diya_point):
		if not _diya_lit:
			if _ghee > 0 or _camphor > 0:
				_diya_point.prompt_text = "Offer fuel to relight the everlasting diya"
			else:
				_diya_point.prompt_text = \
					"The everlasting diya is dead - find ghee or camphor"
		elif _diya_fuel < 120.0 and (_ghee > 0 or _camphor > 0):
			_diya_point.prompt_text = \
				"Feed the everlasting diya (%d s of oil left)" % int(_diya_fuel)
		else:
			_diya_point.prompt_text = "Rest at the everlasting diya (save)"


func _update_murti_expression() -> void:
	var wrath := _has_cursed_items()
	if wrath == _murti_wrath:
		return
	_murti_wrath = wrath
	if _murti_normal != null:
		_murti_normal.visible = not wrath
	if _murti_furious != null:
		_murti_furious.visible = wrath
	if _murti_wrath_light != null:
		_murti_wrath_light.light_energy = 1.15 if wrath else 0.0
	if wrath and _live:
		GameManager.show_message(
			"The weeping murti goes still. Its eyes find the black room on you, and its face turns furious.",
			5.0)
		ProcAudio.play_whisper(Vector3(
			(POOJA_XW + POOJA_XE) * 0.5, 1.9, -23.3))
	elif not wrath and _live:
		GameManager.show_message(
			"The murti's face softens. The tears return.", 3.0)


func _ghost_near_temple() -> bool:
	if not _live:
		return false
	var center := Vector3((POOJA_XW + POOJA_XE) * 0.5, 0.0, REAR_MID_Z)
	var targets: Array[EnemyGhost] = []
	if _ghost != null and is_instance_valid(_ghost):
		targets.append(_ghost)
	for g in _minor_spirits:
		if is_instance_valid(g):
			targets.append(g)
	for g in targets:
		if g.state == EnemyGhost.State.BANISHED \
				or g.state == EnemyGhost.State.DORMANT:
			continue
		if g.global_position.distance_to(center) < 16.0:
			return true
	return false


func _enforce_sanctuary(delta: float) -> void:
	_sanctuary_check -= delta
	if _sanctuary_check > 0.0:
		return
	_sanctuary_check = 0.6
	_push_out_of_temple(_ghost)
	for g in _minor_spirits:
		_push_out_of_temple(g)


func _push_out_of_temple(g: EnemyGhost) -> void:
	if g == null or not is_instance_valid(g):
		return
	var p := g.global_position
	if p.x > POOJA_XW and p.x < POOJA_XE and p.z < CORR_ZB \
			and p.z > PAL_ZB:
		g.global_position = Vector3(7.90, 0.02, CORR_ZB + 1.35)
		g.blind(1.2)


func _on_altar_interact(_node: Node) -> void:
	if _fresh_garlands > 0 and _garlands_replaced < 3:
		_fresh_garlands -= 1
		_replace_garland()
		return
	if _murti_wrath:
		GameManager.set_sanity(GameManager.sanity - 8.0)
		GameManager.show_message(
			"The murti will not listen while you carry the black room's curses.",
			3.8)
		ProcAudio.play_whisper(Vector3(
			(POOJA_XW + POOJA_XE) * 0.5, 1.9, -23.3))
		return
	if _pray_cooldown > 0.0:
		GameManager.show_message(
			"You have already prayed here. The flame is still listening.", 2.4)
		return
	_pray_cooldown = 12.0
	GameManager.add_sanity(12.0)
	if _player != null and is_instance_valid(_player):
		_player.heal(6.0)
	GameManager.show_message(
		"The murti's tears are cool. A little of the Haveli's weight lifts.",
		3.8)


func _replace_garland() -> void:
	var idx := _garlands_replaced
	_garlands_replaced += 1
	if idx < _withered_garlands.size():
		var w := _withered_garlands[idx]
		if is_instance_valid(w):
			w.visible = false
	if idx < _fresh_garland_segments.size():
		var f := _fresh_garland_segments[idx]
		if is_instance_valid(f):
			f.visible = true
	_blessing_timer = 10.0
	_blessing_rate = 1.5
	if _player != null and is_instance_valid(_player):
		_player.max_health += 5.0
		_player.heal(5.0)
		GameManager.report_health(_player.health, _player.max_health)
	if _garlands_replaced >= 3:
		GameManager.show_message(
			"Fresh marigolds on all three garlands. The altar is bright again.  Max HP +15.",
			5.0)
	else:
		GameManager.show_message(
			"Fresh marigolds. The altar breathes again.  Max HP +5, and a slow blessing begins.",
			4.5)
	ProcAudio.play_pickup()


func _on_everlasting_interact(_node: Node) -> void:
	if not _diya_lit or _diya_fuel < 120.0:
		if _ghee > 0:
			_ghee -= 1
			_diya_fuel = minf(_diya_fuel + 90.0, 420.0)
			_light_diya()
			GameManager.show_message(
				"The flame drinks the ghee and rises.  (+90 s of sanctuary)", 3.5)
			return
		if _camphor > 0:
			_camphor -= 1
			_diya_fuel = minf(_diya_fuel + 65.0, 420.0)
			_light_diya()
			GameManager.show_message(
				"The camphor flares blue-white.  (+65 s of sanctuary)", 3.5)
			return
	if not _diya_lit:
		GameManager.show_message(
			"The flame is dead. Search the kitchen for ghee or the courtyard for camphor.",
			4.0)
		return
	if _diya_rest_cooldown > 0.0:
		GameManager.show_message(
			"The flame is steady. Rest a moment longer.", 2.0)
		return
	_diya_rest_cooldown = 20.0
	if _player != null and is_instance_valid(_player):
		_player.heal(_player.max_health)
	GameManager.set_sanity(100.0)
	GameManager.set_checkpoint(Vector3((POOJA_XW + POOJA_XE) * 0.5,
		0.25, -20.0), 0.0)
	GameManager.show_message(
		"The flame remembers you.  Checkpoint saved.  HP and sanity restored.",
		4.0)


func _light_diya() -> void:
	_diya_lit = true
	for f in _everlasting_flames:
		if is_instance_valid(f):
			f.visible = true
	if _everlasting_light != null:
		_everlasting_light.set_meta("base", 2.35)
		_everlasting_light.light_color = Color(1.0, 0.62, 0.28)
		_everlasting_light.light_energy = 2.35


func _extinguish_diya() -> void:
	_diya_lit = false
	_diya_fuel = 0.0
	for f in _everlasting_flames:
		if is_instance_valid(f):
			f.visible = false
	if _everlasting_light != null:
		_everlasting_light.set_meta("base", 0.07)
		_everlasting_light.light_color = Color(0.70, 0.12, 0.05)
	GameManager.show_message(
		"The everlasting diya gutters out. The sanctuary grows cold.", 5.0)
	ProcAudio.play_whisper(Vector3(
		(POOJA_XW + POOJA_XE) * 0.5, 1.9, -21.0))


func _on_vibhuti_interact(_node: Node) -> void:
	if not _diya_lit:
		GameManager.show_message(
			"The vibhuti is cold and inert. Relight the everlasting diya first.",
			3.5)
		return
	if _ash_charges >= 3:
		GameManager.show_message(
			"Your hands are already full of sacred ash.", 2.4)
		return
	_ash_charges += 1
	GameManager.show_message(
		"You scoop a handful of vibhuti. It is warm, and it remembers the flame.  (%d/3)"
		% _ash_charges, 3.6)
	ProcAudio.play_pickup()


func _on_ash_threshold(_node: Node, center: Vector3, width: float) -> void:
	if _ash_charges <= 0:
		GameManager.show_message(
			"You need sacred ash. The vibhuti urn is in the pooja room.", 3.8)
		return
	_ash_charges -= 1
	_draw_ash_barrier(center, width)
	GameManager.show_message(
		"You draw a line of vibhuti across the threshold. It glows, and the dead will not cross.  (%d left)"
		% _ash_charges, 4.0)
	ProcAudio.play_whisper(center)


func _draw_ash_barrier(center: Vector3, width: float) -> void:
	var root := Node3D.new()
	root.name = "VibhutiBarrier"
	root.position = center
	add_child(root)
	var glow := _emissive(Color(0.92, 0.90, 0.74), 0.85)
	_deco(Vector3(0.0, 0.035, 0.0), Vector3(width, 0.035, 0.18),
		glow, root)
	var veil_mat := StandardMaterial3D.new()
	veil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil_mat.albedo_color = Color(0.86, 0.87, 0.76, 0.16)
	veil_mat.emission_enabled = true
	veil_mat.emission = Color(0.82, 0.84, 0.72)
	veil_mat.emission_energy_multiplier = 0.65
	_deco(Vector3(0.0, 1.40, 0.0), Vector3(width, 2.80, 0.02),
		veil_mat, root)
	var ash := _mat(Color(0.68, 0.67, 0.60), 1.0)
	for i in 16:
		var sx := randf_range(-width * 0.48, width * 0.48)
		var sy := randf_range(0.10, 2.65)
		_sphere(Vector3(sx, sy, randf_range(-0.04, 0.04)), 0.022,
			ash, root)
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.45, 0.0)
	light.light_color = Color(0.88, 0.90, 0.78)
	light.light_energy = 0.55
	light.omni_range = 4.2
	light.shadow_enabled = false
	root.add_child(light)
	var gate := _ghost_gate(Vector3(center.x, center.y + 1.70, center.z),
		Vector3(width, 3.20, 0.22))
	_barriers.append({
		"root": root,
		"light": light,
		"gate": gate,
		"timer": 25.0,
	})


func _build_temple_supplies() -> void:
	var clay: Material = _mats["clay"]
	var brass: Material = _mats["brass"]
	var stone: Material = _mats["stone_b"]
	var fresh_a: Material = _mats["marigold"]
	var fresh_b: Material = _mats["marigold2"]

	# Three jars of ghee on a crate in the kitchen.
	_deco(Vector3(-16.20, 0.26, -24.45), Vector3(1.15, 0.52, 0.62),
		_mats["wood_dark"])
	_blocker(Vector3(-16.20, 0.26, -24.45), Vector3(1.15, 0.52, 0.62))
	for i in 3:
		var root := Node3D.new()
		root.position = Vector3(-16.55 + float(i) * 0.35, 0.52, -24.45)
		add_child(root)
		_cyl(Vector3(0.0, 0.14, 0.0), 0.10, 0.28, clay, root)
		_cyl(Vector3(0.0, 0.30, 0.0), 0.075, 0.05, brass, root)
		_supply_pickup(root.position + Vector3(0.0, 0.72, 0.38),
			Vector3(0.55, 0.95, 0.55), "Take a jar of ghee (+90 s of sanctuary)",
			"ghee", root)

	# Three fresh marigold garlands waiting in the garden beds.
	for i in 3:
		var root := Node3D.new()
		root.position = Vector3(-31.10 + float(i % 2) * 0.55,
			0.0, 15.0 + float(i) * 2.2)
		add_child(root)
		_deco(Vector3(0.0, 0.08, 0.0), Vector3(0.62, 0.16, 0.62),
			stone, root)
		_garland_strand(Vector3(0.0, 0.46, 0.0), 0.80, 0.22, fresh_a,
			root)
		_garland_strand(Vector3(0.0, 0.41, 0.02), 0.74, 0.18, fresh_b,
			root)
		_supply_pickup(root.position + Vector3(0.0, 0.72, 0.48),
			Vector3(0.95, 1.05, 0.95),
			"Gather a fresh marigold garland", "garland", root)

	# Camphor: one dish on the veranda, one beside the garden well.
	for pos in [Vector3(-4.90, 0.08, 10.90), Vector3(-17.15, 0.04, 18.45)]:
		var root := Node3D.new()
		root.position = pos
		add_child(root)
		_cyl(Vector3(0.0, 0.06, 0.0), 0.20, 0.06, brass, root)
		for i in 3:
			var chunk := _sphere(Vector3(-0.07 + float(i) * 0.07, 0.12,
				0.02 * float(i % 2)), 0.045,
				_mat(Color(0.90, 0.88, 0.74), 0.55), root)
			chunk.scale = Vector3(1.0, 0.55, 1.0)
		_supply_pickup(root.position + Vector3(0.0, 0.62, 0.42),
			Vector3(0.85, 0.85, 0.85),
			"Take camphor (+65 s of sanctuary)", "camphor", root)


func _supply_pickup(pos: Vector3, size: Vector3, label: String,
		kind: String, visual: Node3D) -> void:
	var point := _hinteract(pos, size, label, Callable())
	point.used.connect(_on_supply_pickup.bind(kind, visual, point))


func _on_supply_pickup(_node: Node, kind: String, visual: Node3D,
		point: HaveliInteractable) -> void:
	if visual != null and is_instance_valid(visual):
		visual.visible = false
	if point != null and is_instance_valid(point):
		point.enabled = false
	match kind:
		"ghee":
			_ghee += 1
			GameManager.show_message(
				"You tuck away a jar of ghee.  (%d carried)" % _ghee, 2.8)
		"camphor":
			_camphor += 1
			GameManager.show_message(
				"You wrap a pinch of camphor in cloth.  (%d carried)" % _camphor,
				2.8)
		"garland":
			_fresh_garlands = mini(_fresh_garlands + 1, 3)
			GameManager.show_message(
				"A fresh marigold garland. The altar is waiting.  (%d carried)"
				% _fresh_garlands, 3.0)
	ProcAudio.play_pickup()


# =========================================================================
#  BLACK MAGIC ROOM  -  ash matkas, kapala, nimbu-mirchi, yantras, dolls
# =========================================================================
func _build_tantra_occult() -> void:
	var clay: Material = _mats["clay"]
	var iron: Material = _mats["iron"]
	var bone: Material = _mats["bone"]
	var soot: Material = _mats["soot"]
	var blood: Material = _mats["blood"]
	var brass: Material = _mats["brass"]
	var ash := _mat(Color(0.56, 0.54, 0.48), 1.0)
	var kumkum := _mat(Color(0.40, 0.018, 0.012), 1.0)
	var coal := _mat(Color(0.035, 0.032, 0.030), 1.0)
	var mustard := _mat(Color(0.76, 0.58, 0.05), 0.85)
	var chilli := _mat(Color(0.09, 0.30, 0.045), 0.88)
	var cream: Material = _mats["cloth_cream"]

	_build_ash_matkas(clay, ash, iron, bone)
	_build_kapala(soot, bone, blood, brass, iron)
	_build_nimbu_mirchi(mustard, chilli, iron)
	_build_yantras(kumkum, coal)
	_build_pierced_dolls(iron, cream)
	_build_cursed_pickups(iron, soot, cream)
	_build_bottle_ritual()
	_lamp_light(Vector3(TANTRA_XW + 0.95, 1.15, -18.35), 0.42,
		Color(0.70, 0.10, 0.05), 4.2)


func _build_ash_matkas(clay: Material, ash: Material, iron: Material,
		bone: Material) -> void:
	for i in 3:
		var pos := Vector3(TANTRA_XW + 0.66, 0.0,
			-20.35 - float(i) * 1.20)
		var root := Node3D.new()
		root.name = "CremationMatka%d" % i
		root.position = pos
		add_child(root)
		_deco(Vector3(0.0, 0.045, 0.0), Vector3(0.76, 0.09, 0.76),
			_mats["stone_a"], root)
		var body := _sphere(Vector3(0.0, 0.42, 0.0), 0.32, clay, root)
		body.scale = Vector3(1.0, 1.12, 1.0)
		_deco(Vector3(0.0, 0.30, 0.0), Vector3(0.58, 0.035, 0.58),
			iron, root)
		_cyl(Vector3(0.0, 0.74, 0.0), 0.19, 0.16, clay, root)
		_cyl(Vector3(0.0, 0.84, 0.0), 0.21, 0.05, ash, root)
		for k in 3:
			var a := TAU * float(k) / 3.0
			_sphere(Vector3(cos(a) * 0.16, 0.86, sin(a) * 0.16), 0.030,
				bone, root)
		_blocker(pos + Vector3(0.0, 0.46, 0.0),
			Vector3(0.68, 0.92, 0.68))
		var point := _hinteract(pos + Vector3(0.86, 0.78, 0.0),
			Vector3(0.98, 1.50, 0.98),
			"Break the cremation ash matka", Callable())
		point.used.connect(_on_ash_matka.bind(i, root, point))
		_ash_pots.append(root)


func _on_ash_matka(_node: Node, _idx: int, root: Node3D,
		point: HaveliInteractable) -> void:
	if root == null or not is_instance_valid(root) or not root.visible:
		return
	var pos := root.global_position + Vector3(0.0, 0.55, 0.0)
	root.visible = false
	if point != null and is_instance_valid(point):
		point.enabled = false
	_cremation_ash = mini(_cremation_ash + 2, 6)
	var blinded := _spawn_ash_cloud(pos, 3.8, true)
	var extra := ""
	if blinded > 0:
		extra = "  Something in the grey recoils."
	GameManager.show_message(
		"The matka splits open. Grave ash spills over your hands.  (+2 ash, %d carried)\nPress G to throw the ash.%s"
		% [_cremation_ash, extra], 5.0)
	ProcAudio.play_impact(pos)
	if _live and randf() < 0.45:
		_spawn_ash_wraith(root.global_position + Vector3(0.95, 0.0, 0.35))


func _build_kapala(soot: Material, bone: Material, blood: Material,
		brass: Material, iron: Material) -> void:
	var pos := Vector3(TANTRA_XE - 0.66, 0.0, -17.15)
	_solid(pos + Vector3(0.0, 0.48, 0.0),
		Vector3(0.56, 0.96, 0.56), soot)
	_deco(pos + Vector3(0.0, 0.98, 0.0), Vector3(0.72, 0.06, 0.72),
		iron)
	_skull(pos + Vector3(0.0, 1.02, 0.0), 1.35)
	_torus(pos + Vector3(0.0, 1.145, 0.0), 0.205, 0.265, brass)
	_deco(pos + Vector3(0.0, 0.52, 0.30), Vector3(0.20, 0.52, 0.03),
		bone)
	for sx in [-1.0, 1.0]:
		_deco(pos + Vector3(sx * 0.27, 0.12, 0.0),
			Vector3(0.10, 0.24, 0.10), bone)
	_kapala_blood = Node3D.new()
	_kapala_blood.name = "KapalaBlood"
	_kapala_blood.position = pos + Vector3(0.0, 1.16, 0.0)
	_kapala_blood.visible = false
	add_child(_kapala_blood)
	_cyl(Vector3.ZERO, 0.225, 0.012, blood, _kapala_blood)
	for i in 3:
		var a := TAU * float(i) / 3.0
		_deco(Vector3(cos(a) * 0.20, -0.10, sin(a) * 0.20),
			Vector3(0.035, 0.22, 0.035), blood, _kapala_blood)
	_kapala_glow = _lamp_light(pos + Vector3(0.0, 1.60, 0.0), 0.0,
		Color(0.95, 0.10, 0.03), 2.8)
	_blocker(pos + Vector3(0.0, 0.50, 0.0),
		Vector3(0.62, 1.00, 0.62))

	_kapala_point = _hinteract(pos + Vector3(-0.82, 1.20, 0.0),
		Vector3(0.95, 1.35, 0.95), "", Callable())
	_kapala_point.prompt_provider = func() -> String:
		if _has_cursed_items():
			return "Return the cursed items to the kapala"
		if _blood_charges >= 3:
			return "The kapala is full (%d blood charges)" % _blood_charges
		if _player == null or not is_instance_valid(_player) \
				or _player.health <= 22.0:
			return "The kapala is thirsty - you are too weak"
		return "Spill blood into the kapala (%d charges)" % _blood_charges
	_kapala_point.used.connect(_on_kapala_interact)


func _on_kapala_interact(_node: Node) -> void:
	if _has_cursed_items():
		_cursed_items.clear()
		GameManager.add_sanity(-4.0)
		GameManager.show_message(
			"You drop the cursed things into the skull bowl. The blood-mark fades from your palm. The murti will look at you again.",
			5.0)
		ProcAudio.play_whisper(Vector3(TANTRA_XE - 0.66, 1.2, -17.15))
		_update_murti_expression()
		return
	if _player == null or not is_instance_valid(_player):
		return
	if _blood_charges >= 3:
		GameManager.show_message(
			"The kapala is already full. The skull will not drink another drop.",
			3.2)
		return
	if _player.health <= 22.0:
		GameManager.show_message(
			"The bowl is thirsty, but your hands are already shaking. Heal first.",
			3.8)
		return
	var cost := minf(18.0, _player.health - 10.0)
	_player.health = maxf(10.0, _player.health - cost)
	GameManager.report_health(_player.health, _player.max_health)
	GameManager.report_damage(cost)
	_blood_charges += 1
	if _kapala_blood != null and is_instance_valid(_kapala_blood):
		_kapala_blood.visible = true
		var spread := 0.88 + float(_blood_charges) * 0.06
		_kapala_blood.scale = Vector3(spread, 1.0, spread)
	if _kapala_glow != null and is_instance_valid(_kapala_glow):
		_kapala_glow.set_meta("base", 0.65)
		_kapala_glow.light_energy = 0.65
	if not _cursed_items.has("blood_mark"):
		_cursed_items.append("blood_mark")
	GameManager.show_message(
		"You open your palm over the kapala. The skull drinks.  Blood charge %d.  -%d HP"
		% [_blood_charges, int(cost)], 5.0)
	ProcAudio.play_hurt(_player.global_position)
	ProcAudio.play_whisper(Vector3(TANTRA_XE - 0.66, 1.2, -17.15))
	_update_murti_expression()


func _build_nimbu_mirchi(mustard: Material, chilli: Material,
		iron: Material) -> void:
	var root := Node3D.new()
	root.name = "NimbuMirchi"
	root.position = Vector3(TANTRA_XE - 1.22, 1.95, -15.25)
	add_child(root)
	_nimbu_root = root
	_deco(Vector3(-1.18, 0.0, 0.0), Vector3(0.06, 0.16, 0.06), iron, root)
	_deco(Vector3(1.18, 0.0, 0.0), Vector3(0.06, 0.16, 0.06), iron, root)
	_deco(Vector3(0.0, 0.0, 0.0), Vector3(2.36, 0.012, 0.012),
		_mats["dark"], root)
	for i in 9:
		var lx := -1.06 + float(i) * 0.265
		var ly := -0.08 - absf(sin(float(i) * 1.1)) * 0.08
		if i % 2 == 0:
			var lemon := _sphere(Vector3(lx, ly, 0.0), 0.075, mustard,
				root)
			lemon.scale = Vector3(1.0, 0.82, 0.82)
			_cyl(Vector3(lx, ly + 0.085, 0.0), 0.012, 0.06,
				_mats["green"], root)
		else:
			for s in [-1.0, 1.0]:
				var ch := _cyl(Vector3(lx + s * 0.025, ly - 0.04, 0.0),
					0.014, 0.18, chilli, root)
				ch.rotation_degrees.z = s * 18.0
	var area := Area3D.new()
	area.name = "NimbuTrigger"
	area.position = Vector3(TANTRA_XE - 1.22, 1.0, -15.25)
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 1.9, 0.95)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_nimbu_entered)


func _on_nimbu_entered(body: Node3D) -> void:
	if not _live or body != _player or _nimbu_cooldown > 0.0:
		return
	_nimbu_cooldown = 7.0
	GameManager.add_sanity(-2.5)
	GameManager.show_message(
		"The lemon-chilli string shivers. Footsteps pass behind you. Nothing is there.",
		4.0)
	var origin := _player.global_position
	for i in 4:
		await get_tree().create_timer(0.16 + float(i) * 0.18).timeout
		if not _live or _player == null or not is_instance_valid(_player):
			return
		var behind := origin + Vector3(randf_range(-1.2, 1.2), 0.0,
			randf_range(-1.2, 1.2))
		ProcAudio.play_footstep(behind, -7.0)


func _build_yantras(kumkum: Material, coal: Material) -> void:
	_make_yantra(Vector3(TANTRA_XW + 0.82, 0.02, -15.15),
		"empty_vessel", "Yantra of the Empty Vessel",
		"A vessel must be empty before it can hold a soul.", kumkum, coal)
	_make_yantra(Vector3(TANTRA_XE - 1.02, 0.02, -20.95),
		"binding_circle", "Yantra of the Binding Circle",
		"A circle of chalk holds what iron cannot.", kumkum, coal)
	_make_yantra(Vector3(TANTRA_XW + 0.74, 0.02, -24.68),
		"perfect_moment", "Yantra of the Perfect Moment",
		"The dead are blind for a breath after ash. Strike then.",
		kumkum, coal)


func _make_yantra(pos: Vector3, id: String, title: String, clue: String,
		kumkum: Material, coal: Material) -> void:
	_draw_yantra(pos, kumkum, coal)
	var point := _hinteract(pos + Vector3(0.0, 0.72, 0.0),
		Vector3(1.15, 1.30, 1.15), "", Callable())
	point.prompt_provider = func() -> String:
		if id in _yantras_studied:
			return "%s - memorized" % title
		return "Memorize the %s" % title
	point.used.connect(_on_yantra_study.bind(id, title, clue, pos))


func _draw_yantra(center: Vector3, kumkum: Material,
		coal: Material) -> void:
	var c := Vector3(center.x, center.y + 0.006, center.z)
	_deco(c, Vector3(0.88, 0.018, 0.88), kumkum)
	var half := 0.38
	_line_xz(c + Vector3(-half, 0.0, -half),
		c + Vector3(half, 0.0, -half), 0.026, coal)
	_line_xz(c + Vector3(half, 0.0, -half),
		c + Vector3(half, 0.0, half), 0.026, coal)
	_line_xz(c + Vector3(half, 0.0, half),
		c + Vector3(-half, 0.0, half), 0.026, coal)
	_line_xz(c + Vector3(-half, 0.0, half),
		c + Vector3(-half, 0.0, -half), 0.026, coal)
	var top := c + Vector3(0.0, 0.0, -0.27)
	var left := c + Vector3(-0.25, 0.0, 0.20)
	var right := c + Vector3(0.25, 0.0, 0.20)
	_line_xz(top, left, 0.024, coal)
	_line_xz(left, right, 0.024, coal)
	_line_xz(right, top, 0.024, coal)
	_line_xz(c + Vector3(-0.27, 0.0, 0.0),
		c + Vector3(0.27, 0.0, 0.0), 0.020, coal)
	_sphere(c + Vector3(0.0, 0.03, 0.0), 0.045, coal)


func _on_yantra_study(_node: Node, id: String, title: String, clue: String,
		pos: Vector3) -> void:
	if id in _yantras_studied:
		GameManager.show_message(
			"The %s is already fixed in your mind." % title, 2.4)
		return
	_yantras_studied.append(id)
	_ritual_insight += 1
	GameManager.add_sanity(-3.0)
	var mark := _sphere(pos + Vector3(0.0, 0.045, 0.0), 0.060,
		_emissive(Color(0.90, 0.10, 0.03), 1.2))
	mark.scale = Vector3(1.0, 0.35, 1.0)
	GameManager.show_message(
		"You memorize the %s.\n%s\nRitual insight %d/3.  (-3 sanity)"
		% [title, clue, _ritual_insight], 6.0)
	ProcAudio.play_whisper(pos)


func _build_pierced_dolls(iron: Material, cream: Material) -> void:
	_make_pierced_doll(Vector3(TANTRA_XW + 0.78, 0.0, -16.80),
		Vector3(0.62, 0.0, 0.0), "meera", "MEERA",
		"The bride who never left the mandap. The Queen was wearing her face when the doors were sealed.",
		iron, cream)
	_make_pierced_doll(Vector3(TANTRA_XE - 0.86, 0.0, -22.10),
		Vector3(-0.62, 0.0, 0.0), "arjun", "ARJUN",
		"The groom who opened the wrong door. He wrote: 'She cannot cross the line of sacred ash.'",
		iron, cream)
	_make_pierced_doll(Vector3(TANTRA_XW + 0.78, 0.0, -19.35),
		Vector3(0.62, 0.0, 0.0), "lakshmi", "LAKSHMI",
		"The cook who heard scratching under the grain. 'The bottle was empty when the screaming stopped.'",
		iron, cream)
	_make_pierced_doll(Vector3(TANTRA_XE - 0.86, 0.0, -18.85),
		Vector3(-0.62, 0.0, 0.0), "devi", "DEVI",
		"The child who counted the bells. 'When the bells stop, she is already behind you.'",
		iron, cream)


func _make_pierced_doll(pos: Vector3, inward: Vector3, id: String,
		victim: String, clue: String, iron: Material,
		cream: Material) -> void:
	_doll(pos)
	var nail := _cyl(pos + Vector3(0.0, 0.28, 0.05), 0.012, 0.30, iron)
	nail.rotation_degrees.z = 90.0
	_deco(pos + Vector3(0.0, 0.006, 0.28), Vector3(0.28, 0.006, 0.18),
		cream)
	var point := _hinteract(pos + inward + Vector3(0.0, 0.62, 0.0),
		Vector3(0.95, 1.15, 0.95), "", Callable())
	point.prompt_provider = func() -> String:
		if id in _read_dolls:
			return "Read the pierced doll again"
		return "Read the pierced doll"
	point.used.connect(_on_doll_read.bind(id, victim, clue, pos))


func _on_doll_read(_node: Node, id: String, victim: String, clue: String,
		pos: Vector3) -> void:
	if id in _read_dolls:
		GameManager.show_message(
			"The doll's cloth is torn where you already read the name. Nothing new.",
			2.6)
		return
	_read_dolls.append(id)
	GameManager.add_sanity(-6.0)
	GameManager.show_message(
		"A name is stitched into the doll: %s.\n%s\nThe room tilts.  (-6 sanity)"
		% [victim, clue], 6.5)
	ProcAudio.play_whisper(pos)


func _build_cursed_pickups(iron: Material, soot: Material,
		cream: Material) -> void:
	# The spool of black thread, on a low table against the east wall.
	var table_pos := Vector3(TANTRA_XE - 0.72, 0.0, -20.05)
	_deco(table_pos + Vector3(0.0, 0.30, 0.0),
		Vector3(0.62, 0.60, 0.62), soot)
	_blocker(table_pos + Vector3(0.0, 0.30, 0.0),
		Vector3(0.62, 0.60, 0.62))
	var spool := Node3D.new()
	spool.name = "BlackThread"
	spool.position = table_pos + Vector3(0.0, 0.60, 0.0)
	add_child(spool)
	_cyl(Vector3(0.0, 0.14, 0.0), 0.12, 0.24, _mats["wood_dark"], spool)
	_cyl(Vector3(0.0, 0.14, 0.0), 0.135, 0.12, _mats["dark"], spool)
	_cyl(Vector3(0.0, 0.02, 0.0), 0.16, 0.035, _mats["wood"], spool)
	_cyl(Vector3(0.0, 0.26, 0.0), 0.16, 0.035, _mats["wood"], spool)
	_deco(Vector3(0.20, 0.14, 0.0), Vector3(0.30, 0.012, 0.012),
		_mats["dark"], spool)
	var thread_point := _hinteract(
		table_pos + Vector3(-0.64, 0.86, 0.0),
		Vector3(0.92, 1.20, 0.92), "", Callable())
	thread_point.prompt_provider = func() -> String:
		return "Take the spool of black thread (cursed)"
	thread_point.used.connect(_on_cursed_pickup.bind("black_thread",
		"You take the spool of black thread.", spool, thread_point))

	# The cursed nail, driven upright into a stool in the north-east corner.
	var stool_pos := Vector3(TANTRA_XE - 0.70, 0.0, -24.55)
	_deco(stool_pos + Vector3(0.0, 0.28, 0.0),
		Vector3(0.50, 0.56, 0.50), soot)
	_blocker(stool_pos + Vector3(0.0, 0.28, 0.0),
		Vector3(0.50, 0.56, 0.50))
	var nail_root := Node3D.new()
	nail_root.name = "CursedNail"
	nail_root.position = stool_pos + Vector3(0.0, 0.56, 0.0)
	add_child(nail_root)
	_cyl(Vector3(0.0, 0.17, 0.0), 0.014, 0.34, iron, nail_root)
	_deco(Vector3(0.0, 0.35, 0.0), Vector3(0.075, 0.035, 0.018),
		iron, nail_root)
	_deco(Vector3(0.0, 0.05, 0.0), Vector3(0.14, 0.012, 0.14),
		cream, nail_root)
	var nail_point := _hinteract(
		stool_pos + Vector3(-0.62, 0.86, 0.0),
		Vector3(0.92, 1.20, 0.92), "", Callable())
	nail_point.prompt_provider = func() -> String:
		return "Take the cursed iron nail"
	nail_point.used.connect(_on_cursed_pickup.bind("cursed_nail",
		"You take the cursed nail. Its point is warm.", nail_root, nail_point))


func _on_cursed_pickup(_node: Node, id: String, label: String,
		root: Node3D, point: HaveliInteractable) -> void:
	if root != null and is_instance_valid(root):
		root.visible = false
	if point != null and is_instance_valid(point):
		point.enabled = false
	if not _cursed_items.has(id):
		_cursed_items.append(id)
	GameManager.show_message(
		"%s\nA cold stain spreads through your palm. The murti will feel it."
		% label, 4.0)
	var where := Vector3(TANTRA_XW + 0.7, 1.0, -20.0)
	if root != null and is_instance_valid(root):
		where = root.global_position
	ProcAudio.play_whisper(where)
	_update_murti_expression()


# =========================================================================
#  BOTTLE RITUAL  -  chalk circle, empty bottle, blood, the perfect moment
# =========================================================================
func _build_bottle_ritual() -> void:
	var chalk := _mat(Color(0.86, 0.84, 0.74), 1.0)
	var chalk_dark := _mat(Color(0.48, 0.47, 0.42), 1.0)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.28, 0.44, 0.38, 0.48)
	glass.metallic = 0.28
	glass.roughness = 0.08
	_ritual_glass = glass
	var soot: Material = _mats["soot"]
	var bone: Material = _mats["bone"]
	var iron: Material = _mats["iron"]
	var stone: Material = _mats["stone_a"]

	# The chalk ring is drawn over the floor, outside the red pentagram,
	# without touching the centred altar or sigil.
	_chalk_root = Node3D.new()
	_chalk_root.name = "ChalkCircle"
	_chalk_root.visible = false
	add_child(_chalk_root)
	_torus(_ritual_center + Vector3(0.0, 0.055, 0.0), 2.88, 2.95,
		chalk, _chalk_root)
	_torus(_ritual_center + Vector3(0.0, 0.050, 0.0), 2.72, 2.76,
		chalk_dark, _chalk_root)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var p := _ritual_center + Vector3(cos(a) * 3.04, 0.06,
			sin(a) * 3.04)
		var tick := _deco(p, Vector3(0.055, 0.016, 0.20), chalk,
			_chalk_root)
		tick.rotation_degrees.y = rad_to_deg(atan2(cos(a), sin(a)))
	_chalk_glow_ring = _torus(_ritual_center + Vector3(0.0, 0.070, 0.0),
		2.86, 2.93, _emissive(Color(0.46, 0.95, 0.62), 1.0),
		_chalk_root)
	_chalk_glow_ring.visible = false

	# The seal station sits on the northern edge of the chalk ring. The
	# player stands inside the ring and Kamla must cross the bottle to reach
	# them.
	var pedestal := Vector3(-9.10, 0.0, -22.05)
	_solid(pedestal + Vector3(0.0, 0.42, 0.0),
		Vector3(0.56, 0.84, 0.56), stone)
	_deco(pedestal + Vector3(0.0, 0.87, 0.0),
		Vector3(0.74, 0.08, 0.74), _mats["stone_b"])
	_cyl(pedestal + Vector3(0.0, 0.94, 0.0), 0.20, 0.07, iron)
	_cyl(pedestal + Vector3(0.0, 0.99, 0.0), 0.145, 0.05, bone)
	_deco(pedestal + Vector3(0.0, 1.015, 0.0),
		Vector3(0.24, 0.020, 0.24), chalk)
	_pedestal_bottle = Node3D.new()
	_pedestal_bottle.name = "PedestalBottle"
	_pedestal_bottle.position = pedestal + Vector3(0.0, 1.04, 0.0)
	add_child(_pedestal_bottle)
	_make_ritual_bottle_mesh(_pedestal_bottle)
	_candle(pedestal + Vector3(0.34, 0.96, 0.26), 0.22)

	# The bottle that waits at the heart of the circle.
	_ritual_bottle = Node3D.new()
	_ritual_bottle.name = "RitualBottle"
	_ritual_bottle.position = _ritual_center + Vector3(0.0, 0.06, 0.0)
	_ritual_bottle.visible = false
	add_child(_ritual_bottle)
	_make_ritual_bottle_mesh(_ritual_bottle)

	_ritual_light = OmniLight3D.new()
	_ritual_light.position = _ritual_center + Vector3(0.0, 1.15, 0.0)
	_ritual_light.light_color = Color(0.40, 0.95, 0.55)
	_ritual_light.light_energy = 0.0
	_ritual_light.omni_range = 5.5
	_ritual_light.shadow_enabled = false
	add_child(_ritual_light)

	_ritual_point = _hinteract(Vector3(pedestal.x, 1.16,
		pedestal.z + 0.42), Vector3(1.35, 1.8, 0.95), "", Callable())
	_ritual_point.prompt_provider = func() -> String:
		return _ritual_prompt()
	_ritual_point.used.connect(_on_ritual_interact)


func _make_ritual_bottle_mesh(parent: Node3D) -> void:
	_cyl(Vector3(0.0, 0.16, 0.0), 0.105, 0.26, _ritual_glass, parent)
	var belly := _sphere(Vector3(0.0, 0.17, 0.0), 0.110,
		_ritual_glass, parent)
	belly.scale = Vector3(1.0, 0.78, 1.0)
	_cyl(Vector3(0.0, 0.35, 0.0), 0.105, 0.10, _ritual_glass, parent)
	_cyl(Vector3(0.0, 0.46, 0.0), 0.037, 0.15, _ritual_glass, parent)
	_torus(Vector3(0.0, 0.545, 0.0), 0.033, 0.048,
		_ritual_glass, parent)
	_cyl(Vector3(0.0, 0.565, 0.0), 0.036, 0.075, _mats["wood"], parent)
	_deco(Vector3(0.0, 0.23, 0.104), Vector3(0.085, 0.105, 0.012),
		_mats["cloth_cream"], parent)
	_deco(Vector3(0.0, 0.235, 0.111), Vector3(0.048, 0.012, 0.006),
		_mats["blood"], parent)


func _ritual_prompt() -> String:
	match _ritual_phase:
		RitualPhase.IDLE:
			return "Draw the chalk circle"
		RitualPhase.DRAWN:
			if _bottle_on_pedestal:
				return "Take the empty ritual bottle"
			if GameManager.inventory_item_count("empty_bottle") > 0:
				return "Place the empty bottle at the circle's heart"
			return "The circle needs an empty bottle"
		RitualPhase.PLACED:
			return "Spill blood into the chalk circle (-15 HP)"
		RitualPhase.BOUND:
			if _ritual_window > 0.0:
				return "SEAL THE BOTTLE  -  NOW"
			return "Wait for Kamla to cross the bottle"
		RitualPhase.SEALED:
			return "The bottle is sealed"
	return "The ritual circle"


func _on_ritual_interact(_node: Node) -> void:
	if _ritual_guard > 0.0 and _ritual_phase != RitualPhase.BOUND:
		return
	match _ritual_phase:
		RitualPhase.IDLE:
			_ritual_guard = 0.30
			_draw_chalk_circle()
		RitualPhase.DRAWN:
			_ritual_guard = 0.30
			if _bottle_on_pedestal:
				_bottle_on_pedestal = false
				_pedestal_bottle.visible = false
				GameManager.add_inventory_item("empty_bottle",
					"Empty ritual bottle")
				GameManager.show_message(
					"You lift the empty bottle from the pedestal. The chalk dust is cold on the glass.",
					4.0)
				ProcAudio.play_impact(_ritual_center)
			elif GameManager.inventory_item_count("empty_bottle") > 0:
				GameManager.remove_inventory_item("empty_bottle")
				_ritual_bottle.visible = true
				if _bottle_shards != null and is_instance_valid(_bottle_shards):
					_bottle_shards.visible = false
				_ritual_phase = RitualPhase.PLACED
				GameManager.show_message(
					"You set the empty bottle at the heart of the circle. Now the circle wants blood.",
					5.0)
				ProcAudio.play_whisper(_ritual_center)
			else:
				GameManager.show_message(
					"The circle is drawn, but there is nothing to hold a soul. Search the house for an empty bottle.",
					4.5)
		RitualPhase.PLACED:
			_ritual_guard = 0.30
			_bind_bottle()
		RitualPhase.BOUND:
			_try_seal_now()
		RitualPhase.SEALED:
			GameManager.show_message(
				"The bottle is sealed. Kamla is a cold weight behind the glass.",
				3.5)


func _draw_chalk_circle() -> void:
	_ritual_phase = RitualPhase.DRAWN
	_chalk_root.visible = true
	GameManager.add_sanity(-1.0)
	GameManager.show_message(
		"You draw the chalk circle around the pentagram. The line closes with a sound like a held breath.",
		5.0)
	ProcAudio.play_impact(_ritual_center)


func _bind_bottle() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.health <= 25.0:
		GameManager.show_message(
			"Your hands are shaking too badly. Heal before you open a vein into the circle.",
			4.0)
		return
	_player.take_damage(15.0)
	_ritual_phase = RitualPhase.BOUND
	_ritual_window = 0.0
	_ritual_arm_delay = 1.6
	_ritual_guard = 0.30
	_ritual_fail_glow = 0.0
	GameManager.add_sanity(-3.0)
	GameManager.add_threat(8.0)
	var coming := ""
	if _ghost != null and is_instance_valid(_ghost) and _ghost.is_alive():
		_ghost.provoke(_player)
		coming = "\nKamla feels the seal. She is coming."
	GameManager.show_message(
		"Blood runs down the glass and into the chalk.\nDo not seal early. Wait until she is over the bottle.%s"
		% coming, 7.0)
	ProcAudio.play_bell(_ritual_center, 0.78)
	ProcAudio.play_whisper(_ritual_center)


func _try_seal_now() -> void:
	if _ritual_phase != RitualPhase.BOUND or _ritual_guard > 0.0:
		return
	_ritual_guard = 0.24
	if _ritual_window > 0.0:
		_success_ritual()
		return
	GameManager.show_message(
		"Not yet. The bottle is still empty. Wait until Kamla is over it.",
		3.0)


func _start_seal_window() -> void:
	var length := 1.75 + 0.42 * float(mini(_ritual_insight, 3))
	_ritual_window = length
	_ritual_window_max = maxf(length, 0.01)
	_ritual_pulse = 0.0
	if _chalk_glow_ring != null:
		_chalk_glow_ring.visible = true
	if _ghost != null and is_instance_valid(_ghost) and _ghost.is_alive():
		# The circle pins her over the bottle for the length of the window.
		_ghost.blind(length + 0.10)
	GameManager.show_message(
		"The bottle drinks. Kamla hangs over the chalk line.\nPRESS E  -  SEAL HER NOW.",
		length + 0.35)
	ProcAudio.play_bell(_ritual_center, 1.18)
	ProcAudio.play_whisper(_ritual_center)


func _success_ritual() -> void:
	if _ritual_phase == RitualPhase.SEALED:
		return
	_ritual_phase = RitualPhase.SEALED
	_ritual_window = 0.0
	_ritual_guard = 0.60
	_chalk_glow_ring.visible = true
	_ritual_bottle.visible = false
	_pedestal_bottle.visible = false
	if _bottle_shards != null and is_instance_valid(_bottle_shards):
		_bottle_shards.visible = false
	GameManager.add_inventory_item("sealed_bottle", "Bottle of Kamla")
	GameManager.add_sanity(14.0)
	GameManager.complete_objective("bottle_ritual")
	GameManager.complete_objective("kamla")
	if _ghost != null and is_instance_valid(_ghost) and _ghost.is_alive():
		_ghost.banish()
	GameManager.show_message(
		"The glass pulls her in. Kamla folds smaller and smaller until she is only a dark shape behind the bottle.\nTHE BOTTLE IS SEALED.",
		10.0)
	ProcAudio.play_bell(_ritual_center, 0.62)
	ProcAudio.play_whisper(_ritual_center)


func _fail_ritual() -> void:
	if _ritual_phase != RitualPhase.BOUND:
		return
	_ritual_phase = RitualPhase.DRAWN
	_ritual_window = 0.0
	_ritual_arm_delay = 0.0
	_ritual_guard = 0.30
	_ritual_fail_glow = 2.4
	_bottle_on_pedestal = true
	_ritual_bottle.visible = false
	_pedestal_bottle.visible = true
	_spawn_bottle_shards()
	GameManager.add_sanity(-8.0)
	GameManager.add_threat(18.0)
	if _player != null and is_instance_valid(_player):
		_player.add_trauma(0.7)
	if _ghost != null and is_instance_valid(_ghost) and _ghost.is_alive():
		_ghost.provoke(_player)
	GameManager.show_message(
		"The moment passes. The bottle bursts in your hand.\nKamla comes through the shards.",
		7.0)
	ProcAudio.play_impact(_ritual_center)
	ProcAudio.play_whisper(_ritual_center)


func _spawn_bottle_shards() -> void:
	if _bottle_shards != null and is_instance_valid(_bottle_shards):
		_bottle_shards.queue_free()
	_bottle_shards = Node3D.new()
	_bottle_shards.name = "BottleShards"
	_bottle_shards.position = _ritual_center
	add_child(_bottle_shards)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.08, 0.85)
		var shard := _deco(Vector3(cos(a) * r, 0.025,
			sin(a) * r), Vector3(rng.randf_range(0.035, 0.10), 0.035,
			rng.randf_range(0.08, 0.20)), _ritual_glass, _bottle_shards)
		shard.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		shard.rotation_degrees.z = rng.randf_range(-28.0, 28.0)


func _update_ritual(delta: float) -> void:
	_ritual_guard = maxf(0.0, _ritual_guard - delta)
	var t := Time.get_ticks_msec() / 1000.0

	if _live and not _ritual_hint_shown and _player != null \
			and is_instance_valid(_player):
		var p := _player.global_position
		if p.x > TANTRA_XW and p.x < TANTRA_XE and p.z < CORR_ZB:
			_ritual_hint_shown = true
			GameManager.show_message(
				"A chalk bowl waits on the northern edge of the pentagram.\nSomething in this room was built to hold a soul.",
				6.5)

	if _ritual_light != null and is_instance_valid(_ritual_light):
		var target := 0.0
		if _ritual_phase == RitualPhase.SEALED:
			target = 0.85 + sin(t * 2.1) * 0.18
		elif _ritual_window > 0.0:
			target = 2.10 + sin(t * 16.0) * 0.55
		elif _ritual_phase == RitualPhase.BOUND:
			target = 0.38 + sin(t * 2.8) * 0.10
		if _ritual_fail_glow > 0.0:
			_ritual_fail_glow = maxf(0.0, _ritual_fail_glow - delta)
			target = maxf(target, 1.10 + sin(t * 19.0) * 0.35)
			_ritual_light.light_color = Color(0.95, 0.12, 0.06)
		elif _ritual_phase == RitualPhase.SEALED:
			_ritual_light.light_color = Color(0.35, 0.95, 0.52)
		else:
			_ritual_light.light_color = Color(0.40, 0.95, 0.55)
		_ritual_light.light_energy = lerpf(_ritual_light.light_energy,
			target, 1.0 - exp(-7.0 * delta))

	if _chalk_glow_ring != null and _chalk_glow_ring.visible:
		var pulse := 0.72 + 0.28 * sin(t * (14.0 if _ritual_window > 0.0 else 2.4))
		_chalk_glow_ring.scale = Vector3(pulse, 1.0, pulse)

	if _ritual_phase == RitualPhase.BOUND:
		_ritual_arm_delay = maxf(0.0, _ritual_arm_delay - delta)
		if _ghost == null or not is_instance_valid(_ghost) \
				or not _ghost.is_alive():
			return
		var flat := Vector3(_ghost.global_position.x, 0.0,
			_ghost.global_position.z)
		var dist := flat.distance_to(_ritual_center)
		if _ritual_window > 0.0:
			_ritual_window -= delta
			if _ritual_window <= 0.0:
				_ritual_window = 0.0
				_fail_ritual()
		elif _ritual_arm_delay <= 0.0:
			var radius := 1.55 + 0.23 * float(mini(_ritual_insight, 3))
			if dist <= radius:
				_start_seal_window()


func _ritual_phase_name() -> String:
	match _ritual_phase:
		RitualPhase.IDLE:
			return "IDLE"
		RitualPhase.DRAWN:
			return "DRAWN"
		RitualPhase.PLACED:
			return "PLACED"
		RitualPhase.BOUND:
			return "BOUND"
		RitualPhase.SEALED:
			return "SEALED"
	return "?"


func _setup_ritual_preview() -> void:
	_chalk_root.visible = true
	_ritual_phase = RitualPhase.PLACED
	_bottle_on_pedestal = false
	_pedestal_bottle.visible = false
	_ritual_bottle.visible = true
	_chalk_glow_ring.visible = false


func _update_tantra(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_nimbu_cooldown = maxf(0.0, _nimbu_cooldown - delta)
	if _nimbu_root != null and is_instance_valid(_nimbu_root):
		_nimbu_root.rotation.z = sin(t * 1.7) * 0.035
		_nimbu_root.rotation.x = sin(t * 1.3 + 1.0) * 0.025
	if _kapala_glow != null and is_instance_valid(_kapala_glow):
		var base := float(_kapala_glow.get_meta("base", 0.0))
		if base > 0.0:
			_kapala_glow.light_energy = base + sin(t * 2.3) * 0.10

	for i in range(_ash_clouds.size() - 1, -1, -1):
		var c: Dictionary = _ash_clouds[i]
		var life := float(c["life"])
		c["timer"] = float(c["timer"]) - delta
		var root := c["root"] as Node3D
		if is_instance_valid(root):
			var k := clampf(float(c["timer"]) / maxf(life, 0.001), 0.0, 1.0)
			root.scale = Vector3.ONE * (0.35 + 0.65 * k)
		if float(c["timer"]) <= 0.0:
			if is_instance_valid(root):
				root.queue_free()
			_ash_clouds.remove_at(i)

	for i in range(_minor_spirits.size() - 1, -1, -1):
		var g := _minor_spirits[i]
		if g == null or not is_instance_valid(g):
			_minor_spirits.remove_at(i)
		elif g.state == EnemyGhost.State.BANISHED:
			_minor_spirits.remove_at(i)

	if _live and _player != null and is_instance_valid(_player):
		var p := _player.global_position
		if p.x > TANTRA_XW and p.x < TANTRA_XE and p.z < CORR_ZB:
			GameManager.complete_objective("black_magician")


func _spawn_ash_cloud(pos: Vector3, radius: float,
		blind_dead: bool) -> int:
	var root := Node3D.new()
	root.name = "AshCloud"
	root.position = pos
	add_child(root)
	var ash_a := _mat(Color(0.54, 0.52, 0.46), 1.0)
	var ash_b := _mat(Color(0.34, 0.32, 0.29), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 18:
		var p := Vector3(rng.randf_range(-radius * 0.55, radius * 0.55),
			rng.randf_range(0.05, 1.35),
			rng.randf_range(-radius * 0.55, radius * 0.55))
		var puff := _sphere(p, rng.randf_range(0.14, 0.36),
			ash_a if i % 2 == 0 else ash_b, root)
		puff.scale = Vector3(1.0, 0.65, 1.0)
	for i in 10:
		var p := Vector3(rng.randf_range(-radius * 0.7, radius * 0.7),
			rng.randf_range(0.05, 1.6),
			rng.randf_range(-radius * 0.7, radius * 0.7))
		_sphere(p, rng.randf_range(0.03, 0.08), ash_a, root)
	_ash_clouds.append({"root": root, "timer": 6.5, "life": 6.5})
	if not blind_dead:
		return 0
	var count := 0
	var targets: Array[EnemyGhost] = []
	if _ghost != null and is_instance_valid(_ghost):
		targets.append(_ghost)
	for g in _minor_spirits:
		if is_instance_valid(g):
			targets.append(g)
	for g in targets:
		if g.state == EnemyGhost.State.BANISHED \
				or g.state == EnemyGhost.State.DORMANT:
			continue
		if g.global_position.distance_to(pos) <= radius + 1.0:
			g.blind(4.0)
			count += 1
	return count


func _throw_cremation_ash() -> void:
	if _cremation_ash <= 0:
		GameManager.show_message(
			"You have no cremation ash. Break a matka in the Black Magic room.",
			3.2)
		return
	if _player == null or not is_instance_valid(_player):
		return
	_cremation_ash -= 1
	var fwd := -_player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var pos := _player.global_position + fwd * 2.4 + Vector3(0.0, 1.1, 0.0)
	var blinded := _spawn_ash_cloud(pos, 5.4, true)
	if blinded > 0:
		GameManager.show_message(
			"The ash bursts open. The dead lose you in the grey.  (%d ash left)"
			% _cremation_ash, 3.8)
	else:
		GameManager.show_message(
			"The ash bursts in a grey cloud. Nothing moves in it.  (%d ash left)"
			% _cremation_ash, 3.0)
	ProcAudio.play_whisper(pos)


func _spawn_ash_wraith(pos: Vector3) -> void:
	var wraith := GHOST_SCENE.instantiate() as EnemyGhost
	wraith.name = "AshWraith"
	wraith.rig_body = GhostRig.Body.SOLDIER_FEMALE
	wraith.display_name = "Ash Wraith"
	wraith.quest_id = ""
	wraith.use_difficulty_preset = false
	wraith.start_dormant = false
	wraith.max_health = 55.0
	wraith.damage_resist = 0.05
	wraith.roam_radius = 6.0
	wraith.roam_speed = 1.15
	wraith.chase_speed = 2.75
	wraith.attack_damage = 9.0
	wraith.attack_range = 1.8
	wraith.attack_windup = 0.42
	wraith.attack_cooldown = 2.4
	wraith.detect_radius = 10.0
	wraith.lose_radius = 15.0
	wraith.position = pos
	wraith.collision_mask |= 32
	add_child(wraith)
	_minor_spirits.append(wraith)
	GameManager.show_message(
		"Something rises out of the ash. It wears a dead woman's shape.",
		4.0)
	ProcAudio.play_whisper(pos)


# =========================================================================
#  PLAYER, GHOST AND PREVIEW
# =========================================================================
func _yaw_to(from: Vector3, to: Vector3) -> float:
	return rad_to_deg(atan2(-(to.x - from.x), -(to.z - from.z)))


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	var use_checkpoint := _live and GameManager.checkpoint_valid \
		and GameManager.checkpoint_level == GameManager.current_level_id
	var pos := GameManager.checkpoint_position if use_checkpoint else HOME_POS
	var look := Vector3(0.0, 3.0, -4.0)
	var pitch := 0.0

	match _angle:
		"hall":
			pos = Vector3(0.0, 0.2, 7.4)
			look = Vector3(0.0, 4.6, -7.0)
			pitch = 5.0
		"hallwide":
			pos = Vector3(0.0, 0.2, 8.55)
			look = Vector3(0.0, 4.0, -7.0)
			pitch = 6.0
		"entrance":
			pos = Vector3(0.0, 0.2, 16.2)
			look = Vector3(0.0, 6.0, PAL_ZF)
			pitch = 17.0
		"dining":
			pos = Vector3(-19.0, 0.2, 6.3)
			look = Vector3(-23.8, 1.2, 0.0)
			pitch = -3.0
		"dininggore":
			pos = Vector3(-21.7, 0.2, 3.8)
			look = Vector3(-23.8, 1.0, 0.55)
			pitch = -8.0
		"kitchen":
			pos = Vector3(-20.0, 0.2, -14.5)
			look = Vector3(-19.7, 1.2, -20.6)
		"bedroom":
			pos = Vector3(15.8, 0.2, 6.7)
			look = Vector3(24.6, 1.2, 4.2)
			pitch = -3.0
		"bedroomantique":
			pos = Vector3(17.2, 0.2, 0.4)
			look = Vector3(23.2, 1.35, 6.35)
			pitch = -4.0
		"bedroommirror":
			pos = Vector3(22.3, 0.2, -2.2)
			look = Vector3(26.35, 2.0, -5.4)
			pitch = 1.0
		"bedroomportraits":
			pos = Vector3(17.4, 0.2, 2.6)
			look = Vector3(11.36, 2.9, -1.8)
			pitch = 3.0
		"bedroomalmirah":
			pos = Vector3(18.0, 0.2, -4.0)
			look = Vector3(14.5, 1.6, -8.1)
			pitch = -1.0
		"corridor":
			pos = Vector3(-22.0, 0.2, -11.225)
			look = Vector3(0.0, 1.8, -11.225)
		"corridore":
			pos = Vector3(22.0, 0.2, -11.225)
			look = Vector3(0.0, 1.8, -11.225)
		"tantra":
			pos = Vector3(-8.05, 0.2, -14.7)
			look = Vector3(-8.05, 1.6, -24.0)
			pitch = 4.0
		"tantraoccult":
			pos = Vector3(-10.9, 0.2, -14.9)
			look = Vector3(-4.0, 1.25, -20.7)
			pitch = 1.0
		"ritual":
			pos = Vector3(-8.05, 0.2, -14.35)
			look = Vector3(-8.05, 1.05, -20.8)
			pitch = 9.0
		"pooja":
			pos = Vector3(8.05, 0.2, -14.7)
			look = Vector3(8.05, 1.6, -24.0)
			pitch = 4.0
		"poojabells":
			pos = Vector3(8.05, 0.2, -14.05)
			look = Vector3(8.05, 3.2, -22.0)
			pitch = 28.0
		"murti":
			pos = Vector3(8.05, 0.2, -21.75)
			look = Vector3(8.05, 1.88, -23.6)
			pitch = 7.0
		"stairs":
			pos = Vector3(0.0, 0.2, -14.2)
			look = Vector3(-0.7, 2.6, -19.0)
			pitch = 8.0
		"upper":
			pos = Vector3(-8.5, LOW_H + 0.2, -10.4)
			look = Vector3(-8.5, 1.2, 2.0)
			pitch = -10.0
		"uppergallery":
			pos = Vector3(24.8, LOW_H + 0.2, -11.225)
			look = Vector3(-24.0, LOW_H + 1.7, -11.225)
		"upperbed":
			pos = Vector3(13.2, LOW_H + 0.2, 7.4)
			look = Vector3(24.6, LOW_H + 1.2, 5.6)
			pitch = -2.0
		"guest":
			pos = Vector3(13.5, 0.2, -14.8)
			look = Vector3(23.5, 1.2, -21.0)
			pitch = -3.0
		"outside":
			pos = Vector3(-10.5, 0.2, 19.8)
			look = Vector3(0.0, 5.0, PAL_ZF)
			pitch = 8.0
		"gate":
			pos = Vector3(0.0, 0.2, 20.6)
			look = Vector3(0.0, 2.2, 23.9)
			pitch = 3.0
		"garden":
			pos = Vector3(-6.2, 0.2, 19.1)
			look = Vector3(-18.5, 1.3, 17.7)
			pitch = -1.0
		"graveyard":
			pos = Vector3(5.7, 0.2, 18.0)
			look = Vector3(20.5, 1.2, 18.0)
		"blackmagician", "photos":
			pos = Vector3(-15.1, 0.2, -10.45)
			look = Vector3(-15.1, 3.35, CORR_ZB)
			pitch = 15.0
		"ghost":
			pos = Vector3(0.0, 0.2, 8.2)
			look = Vector3(0.0, 1.55, -4.4)
			pitch = 0.0

	_player.position = pos
	var look_yaw := _yaw_to(pos, look)
	if use_checkpoint:
		look_yaw = GameManager.checkpoint_yaw
	_preview_yaw = look_yaw
	_preview_pitch = pitch
	if _angle != "" or use_checkpoint:
		_player.rotation_degrees.y = look_yaw
	add_child(_player)

	# PlayerController captures the mouse in _ready. Stills must never be
	# steered by the launching mouse, so release it and freeze mouse look.
	if not _live:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_player.set_process_unhandled_input(false)
		_player.rotation_degrees.y = look_yaw

	var head := _player.get_node_or_null("HeadPivot") as Node3D
	if head != null:
		head.rotation_degrees.x = pitch

	var view := _player.get_node_or_null("HeadPivot/Camera3D/WeaponView") as Node3D
	if view != null:
		view.visible = false

	_spawn_ghost()
	if _angle == "ritual":
		_setup_ritual_preview()


func _spawn_ghost() -> void:
	# Kamla walks the central hall. The stills stay clean; live play and
	# the ghost camera wake her.
	var ritual_still := _angle == "ritual"
	if not (_live or _angle == "ghost" or ritual_still):
		return
	_ghost = GHOST_SCENE.instantiate() as EnemyGhost
	_ghost.name = "Kamla"
	_ghost.rig_body = GhostRig.Body.GHOST_QUEEN
	_ghost.display_name = "Kamla"
	_ghost.quest_id = "kamla"
	_ghost.roam_radius = 7.0
	_ghost.start_dormant = ritual_still
	if ritual_still:
		_ghost.position = Vector3(RITUAL_X, 0.02, -20.9)
		_ghost.rotation_degrees.y = 0.0
		_ghost.detect_radius = 0.0
	elif _angle == "ghost":
		_ghost.position = Vector3(0.0, 0.02, -4.4)
		_ghost.rotation_degrees.y = 180.0
	else:
		_ghost.position = Vector3(0.0, 0.02, -3.2)
		_ghost.rotation_degrees.y = 180.0
	# Layer 6 holds the temple's sanctuary gate and ash barriers. Only the
	# dead collide with it; the living walk straight through the pooja door.
	_ghost.collision_mask |= 32
	add_child(_ghost)
	if _angle == "ghost":
		# Give the still a full-length view instead of a face pressed into
		# the lens.
		_ghost.detect_radius = 18.0
		_ghost.chase_speed = 2.5
		_ghost.alert_duration = 1.15


func _run_preview() -> void:
	var t := 0.0
	var noise_t := 0.0
	while t < 2.6:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		noise_t += dt
		if not _live and _player != null and is_instance_valid(_player):
			# Keep the still camera locked no matter what the window
			# manager does with the cursor.
			_player.rotation_degrees.y = _preview_yaw
			var hp := _player.get_node_or_null("HeadPivot") as Node3D
			if hp != null:
				hp.rotation_degrees.x = _preview_pitch
		GameManager.set_threat(10.0 + t * 16.0)
		GameManager.set_sanity(100.0 - t * 11.0)
		if _player != null:
			_player.stamina = clampf(94.0 - t * 8.0, 25.0, 100.0)
		if noise_t >= 0.9:
			noise_t = 0.0
			GameEventBroker.player_noise_made.emit(5.0,
				_player.global_position)

	await get_tree().create_timer(0.35).timeout
	if "--dumpframe" in OS.get_cmdline_user_args():
		_dump_frame()
		get_tree().quit()
		return
	if _ghost != null and is_instance_valid(_ghost):
		print("GHOST state=", _ghost.state, " pos=", _ghost.global_position)
	var cam := _player.get_node_or_null("HeadPivot/Camera3D") as Camera3D
	if cam != null:
		print("SHOT CAM pos=", cam.global_position, " rot=",
			cam.global_rotation_degrees, " player=", _player.global_position)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var suffix := "_" + _angle if _angle != "" else ""
	var path := ProjectSettings.globalize_path(
		"res://preview/step1_palace%s.png" % suffix)
	var err := img.save_png(path)
	print("PALACE PREVIEW: ", path, "  err=", err)
	get_tree().quit()


