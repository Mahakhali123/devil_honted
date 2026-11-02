extends SceneTree
## Temporary headless probe for the Haveli bottle-sealing ritual.
## Run with:
##   godot --headless --path <project> --script res://tests/ritual_probe.gd -- --live

const GHOST_BANISHED := 6

var _level: Node
var _gm: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	var packed := load("res://tests/step1_duplex_palace.tscn") as PackedScene
	_level = packed.instantiate()
	root.add_child(_level)
	_gm = root.get_node("/root/GameManager")
	for i in 30:
		await process_frame

	var player = _level._player
	var ghost = _level._ghost
	if player == null or ghost == null:
		print("RITUAL PROBE FAIL: missing player or ghost")
		quit(1)
		return

	ghost.can_teleport = false
	player.health = 100.0
	_gm.report_health(100.0, player.max_health)

	print("RITUAL START phase=", _level._ritual_phase_name(),
		" bottle_on_pedestal=", _level._bottle_on_pedestal,
		" inventory=", _gm.inventory)

	# 1. Draw the circle and pick up the empty bottle.
	_level._on_ritual_interact(player)
	print("DRAW phase=", _level._ritual_phase_name(),
		" chalk=", _level._chalk_root.visible)
	_level._on_ritual_interact(player)
	print("TAKE phase=", _level._ritual_phase_name(),
		" pedestal_bottle=", _level._pedestal_bottle.visible,
		" empty=", _gm.inventory_item_count("empty_bottle"))

	# 2. Place the bottle and give blood.
	_level._on_ritual_interact(player)
	print("PLACE phase=", _level._ritual_phase_name(),
		" floor_bottle=", _level._ritual_bottle.visible,
		" empty=", _gm.inventory_item_count("empty_bottle"))
	player.health = 100.0
	_gm.report_health(100.0, player.max_health)
	_level._on_ritual_interact(player)
	print("BIND phase=", _level._ritual_phase_name(),
		" hp=", player.health, " ghost_state=", ghost.state)

	# 3. Freeze Kamla at the bottle. Let the window open, then miss it.
	ghost.position = _level._ritual_center
	ghost.blind(20.0)
	var waited := 0.0
	while _level._ritual_window <= 0.0 and waited < 4.0:
		await process_frame
		waited += 0.016
	print("WINDOW phase=", _level._ritual_phase_name(),
		" window=%.2f waited=%.2f" % [_level._ritual_window, waited])
	var window: float = _level._ritual_window
	waited = 0.0
	while waited < window + 0.6:
		await process_frame
		waited += 0.016
	print("MISS phase=", _level._ritual_phase_name(),
		" bottle_on_pedestal=", _level._bottle_on_pedestal,
		" shards=", _level._bottle_shards != null,
		" ghost_state=", ghost.state,
		" hp=", player.health)

	# 4. Retry. The spare bottle is back on the pedestal.
	player.health = 100.0
	_gm.report_health(100.0, player.max_health)
	_level._on_ritual_interact(player)
	_level._on_ritual_interact(player)
	_level._on_ritual_interact(player)
	print("RETRY phase=", _level._ritual_phase_name(),
		" hp=", player.health,
		" empty=", _gm.inventory_item_count("empty_bottle"))

	ghost.position = _level._ritual_center
	ghost.blind(20.0)
	waited = 0.0
	while _level._ritual_window <= 0.0 and waited < 4.0:
		await process_frame
		waited += 0.016
	print("PERFECT phase=", _level._ritual_phase_name(),
		" window=%.2f" % _level._ritual_window,
		" prompt=", _level._ritual_prompt())
	_level._try_seal_now()
	for i in 5:
		await process_frame
	print("SEALED phase=", _level._ritual_phase_name(),
		" ghost_state=", ghost.state,
		" sealed_bottle=", _gm.inventory_item_count("sealed_bottle"),
		" objective=", _gm.is_objective_done("bottle_ritual"),
		" prompt=", _level._ritual_prompt())

	var ok: bool = _level._ritual_phase_name() == "SEALED" \
		and _gm.inventory_item_count("sealed_bottle") == 1 \
		and ghost.state == GHOST_BANISHED \
		and _gm.is_objective_done("bottle_ritual")
	print("BOTTLE RITUAL PROBE: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
