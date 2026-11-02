extends SceneTree
## Temporary headless probe for the Haveli temple and Black Magic systems.
## Run with:
##   godot --headless --path <project> --script res://tests/temple_probe.gd -- --live

var _level: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var packed := load("res://tests/step1_duplex_palace.tscn") as PackedScene
	_level = packed.instantiate()
	root.add_child(_level)
	for i in 20:
		await process_frame

	var player = _level._player
	var ghost = _level._ghost
	if player == null or ghost == null:
		print("PROBE FAIL: missing player or ghost")
		quit(1)
		return

	# 1. Ghost sanctuary gate + bell alarm.
	player.global_position = Vector3(8.05, 0.25, -20.0)
	ghost.global_position = Vector3(7.9, 0.02, -12.0)
	for i in 240:
		await process_frame
	var gp: Vector3 = ghost.global_position
	var in_pooja: bool = gp.x > 3.4 and gp.x < 12.7 and gp.z < -13.3
	print("PROBE ghost_pos=", gp, " state=", ghost.state,
		" bell_alarm=", _level._bell_alarm, " in_pooja=", in_pooja)
	print("SANCTUARY PROBE: ", "PASS" if not in_pooja else "FAIL")

	# 2. Temple state: ash scoop and barrier.
	_level._ash_charges = 1
	_level._on_ash_threshold(player, Vector3(0.0, 0.0, 9.21), 4.2)
	print("BARRIER PROBE: count=", _level._barriers.size(),
		" charges=", _level._ash_charges)

	# 3. Matka breaks and yields ash.
	var matka = _level.get_node_or_null("CremationMatka0") as Node3D
	if matka != null:
		_level._on_ash_matka(player, 0, matka, null)
	print("MATKA PROBE: ash=", _level._cremation_ash,
		" clouds=", _level._ash_clouds.size())

	# 4. Ash throw with G.
	_level._throw_cremation_ash()
	print("THROW PROBE: ash=", _level._cremation_ash,
		" clouds=", _level._ash_clouds.size())

	# 5. Kapala blood offering, then cleansing.
	player.health = 100.0
	_level._on_kapala_interact(player)
	print("KAPALA PROBE: blood=", _level._blood_charges,
		" cursed=", _level._cursed_items)
	_level._on_kapala_interact(player)
	print("CLEANSE PROBE: blood=", _level._blood_charges,
		" cursed=", _level._cursed_items)

	# 6. Yantra study and doll reading.
	_level._on_yantra_study(player, "empty_vessel",
		"Yantra of the Empty Vessel",
		"A vessel must be empty before it can hold a soul.", Vector3.ZERO)
	_level._on_doll_read(player, "meera", "MEERA", "Test clue.", Vector3.ZERO)
	print("OCCULT PROBE: insight=", _level._ritual_insight,
		" yantras=", _level._yantras_studied,
		" dolls=", _level._read_dolls)

	# 7. Ash Wraith spawn.
	_level._spawn_ash_wraith(Vector3(-8.0, 0.02, -18.0))
	print("WRAITH PROBE: minor_spirits=", _level._minor_spirits.size())

	print("TEMPLE PROBE: DONE")
	quit()
