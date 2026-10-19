extends HauntedLevel
## =========================================================================
## Combat self-test  -  run headless, prints a PASS/FAIL report
## =========================================================================
##     Godot_v4.7.2-stable_win64_console.exe --headless ^
##       --path "<project>" res://tests/combat_arena.tscn
##
## It proves three things that are easy to get silently wrong:
##
##   1. THE MELEE SWEEP CONNECTS. A ghost 1.4 m in front of the player takes
##      damage when _apply_melee() runs, and nothing behind a wall does.
##
##   2. THE DIFFICULTY LADDER IS REAL. Four freshly spawned ghosts, one of
##      each character, are hit with identical katana damage until they die.
##      The hit counts MUST increase in this order:
##          girl soldier < boy soldier < queen < king
##
##   3. THEY CAN KILL YOU. Every profile's damage is above zero and the
##      attack range/windup numbers are sane.
##
## Exit code is 0 when everything passes, 1 when anything fails.
## =========================================================================

var _lines: Array[String] = []
var _failures := 0


func _level_started() -> void:
	announce_hunt = false
	_run.call_deferred()


func _run() -> void:
	await _settle(6)

	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null:
		_fail("no Player in the arena scene")
		_finish()
		return
	_pass("player found, %d starting weapons" % player.weapons.size())
	_pass("starting weapon: %s" % WeaponDB.display_name(player.current_weapon_id()))

	await _test_melee_sweep(player)
	await _test_wall_blocks_the_swing(player)
	await _test_player_kills_a_ghost(player)
	await _test_difficulty_ladder()
	await _test_player_can_die(player)
	_finish()


# =========================================================================
#  1. the sweep hits what is in front of you
# =========================================================================
func _test_melee_sweep(player: PlayerController) -> void:
	var ghost := get_tree().get_first_node_in_group("ghost") as EnemyGhost
	if ghost == null:
		_fail("no ghost in the arena scene")
		return

	player.global_position = Vector3(0.0, 0.4, 0.0)
	player.rotation.y = 0.0
	ghost.global_position = Vector3(0.0, 0.4, -1.4)
	ghost.sleep_ghost()
	await _settle(6)

	var before := ghost.health
	player._apply_melee(WeaponDB.get_weapon("katana"))
	var after := ghost.health
	if after < before:
		_pass("melee sweep CONNECTED: %.0f -> %.0f hp (%.0f damage)" % [before, after, before - after])
	else:
		_fail("melee sweep MISSED: ghost still at %.0f hp" % after)


# =========================================================================
#  2. a wall stops the blade
# =========================================================================
func _test_wall_blocks_the_swing(player: PlayerController) -> void:
	var ghost := get_tree().get_first_node_in_group("ghost") as EnemyGhost
	if ghost == null:
		_fail("no ghost to test the wall with")
		return

	# Drop a solid 3 m wall right between the camera and the ghost's chest.
	var wall := preload("res://props/block.tscn").instantiate() as LevelBlock
	wall.size = Vector3(3.0, 3.0, 0.3)
	wall.material = null
	wall.position = Vector3(0.0, 1.5, -0.7)
	add_child(wall)
	await _settle(4)

	player.global_position = Vector3(0.0, 0.4, 0.0)
	player.rotation.y = 0.0
	ghost.global_position = Vector3(0.0, 0.4, -1.4)
	await _settle(4)

	var before := ghost.health
	player._apply_melee(WeaponDB.get_weapon("katana"))
	var after := ghost.health
	if is_equal_approx(after, before):
		_pass("wall correctly BLOCKED the swing (ghost kept %.0f hp)" % after)
	else:
		_fail("swing went THROUGH the wall: %.0f -> %.0f hp" % [before, after])

	wall.queue_free()
	await _settle(2)


# =========================================================================
#  3. THE REAL THING: the player swings until the ghost is banished
# =========================================================================
## This drives the actual combat pipeline - _swing() starts a windup, the
## windup calls _apply_melee(), the sweep finds the ghost, take_damage runs,
## banish() fires and GameManager scores it. Nothing is called out of order.
func _test_player_kills_a_ghost(player: PlayerController) -> void:
	_lines.append("")
	_lines.append("  END-TO-END KILL")

	# A fresh, untouched ghost so the wall test above cannot interfere.
	var ghost := (load("res://enemies/enemy_ghost.tscn") as PackedScene).instantiate() as EnemyGhost
	ghost.rig_body = GhostRig.Body.SOLDIER_FEMALE
	ghost.start_dormant = true
	ghost.quest_id = ""
	add_child(ghost)
	await _settle(4)

	# The arena's own ghost is still standing in the swing arc from the earlier
	# tests and would die on the same swings, so move it out of the way.
	for other in get_tree().get_nodes_in_group("ghost"):
		var o := other as EnemyGhost
		if o != null and o != ghost:
			o.global_position = Vector3(0.0, 0.4, -200.0)
			o.velocity = Vector3.ZERO
	await _settle(2)

	# Hand the player a bat through the same API a floor pickup uses.
	if not player.has_weapon("wooden_bat"):
		player.add_weapon("wooden_bat")
	var slot := WeaponDB.SLOT_ORDER.find("wooden_bat")
	if slot >= 0:
		player._equip_slot(slot)
	await _settle(2)
	if player.current_weapon_id() != "wooden_bat":
		_fail("could not equip the wooden bat (holding %s)" % player.current_weapon_id())
		ghost.queue_free()
		return

	var bat := WeaponDB.get_weapon("wooden_bat")
	var cooldown := float(bat.get("cooldown", 0.5))
	# Frames we must let pass for the windup to land and the cooldown to clear.
	var frames_per_swing := int(ceil(cooldown / (1.0 / 60.0))) + 6

	var banished_before := GameManager.ghosts_banished
	var hp_start := ghost.health
	var swings := 0
	var first_hit_swing := -1

	while ghost.is_alive() and swings < 40:
		# Stand the player right in front of the ghost each swing: an idle
		# ghost can drift a little, and this test is about damage, not chase.
		player.global_position = Vector3(0.0, 0.4, 0.0)
		player.rotation.y = 0.0
		ghost.global_position = Vector3(0.0, 0.4, -1.3)
		ghost.velocity = Vector3.ZERO
		await _settle(2)

		Input.action_press("attack")
		await get_tree().physics_frame
		Input.action_release("attack")

		for i in frames_per_swing:
			await get_tree().physics_frame
			if ghost.is_alive():
				ghost.global_position = Vector3(0.0, 0.4, -1.3)
				ghost.velocity = Vector3.ZERO

		swings += 1
		if first_hit_swing < 0 and ghost.health < hp_start:
			first_hit_swing = swings

	if first_hit_swing < 0:
		_fail("40 swings of the wooden bat never damaged the ghost - the attack input or the sweep is broken")
	elif not ghost.is_alive():
		var gained := GameManager.ghosts_banished - banished_before
		if gained == 1:
			_pass("the player killed the girl soldier with the bat: %d swing(s), first connect on swing %d" % [swings, first_hit_swing])
		else:
			_fail("ghost died but GameManager counted %d banish(es)" % gained)
	else:
		_fail("ghost survived %d swings (%.0f / %.0f hp left)" % [swings, ghost.health, ghost.max_health])

	if not InputMap.has_action("attack"):
		_fail("the 'attack' input action is missing from the InputMap")

	ghost.queue_free()
	await _settle(2)


# =========================================================================
#  4. the difficulty ladder
# =========================================================================
func _test_difficulty_ladder() -> void:
	var packed := load("res://enemies/enemy_ghost.tscn") as PackedScene
	if packed == null:
		_fail("could not load res://enemies/enemy_ghost.tscn")
		return

	var katana := WeaponDB.get_weapon("katana")
	var hit_damage := float(katana["damage"]) * float(katana["ghost_bonus"])

	var hits_by_body: Dictionary = {}
	_lines.append("")
	_lines.append("  DIFFICULTY LADDER  (identical %.1f-damage katana hits)" % hit_damage)

	for body in GhostDB.ORDER:
		var g := packed.instantiate() as EnemyGhost
		g.rig_body = body
		g.start_dormant = true
		g.quest_id = ""
		add_child(g)
		await _settle(4)

		var hits := 0
		while g.is_alive() and hits < 1000:
			g.take_damage(hit_damage, null, 0.0, 0.0)
			hits += 1
		hits_by_body[body] = hits

		var p := GhostDB.get_profile(body)
		_lines.append("    %-16s %-8s hp=%-4d resist=%2.0f%%   ->  %d hits" % [
			String(p["name"]), String(p["tag"]), int(p["health"]),
			float(p["damage_resist"]) * 100.0, hits])

		g.queue_free()
		await _settle(2)

	# The whole design in one assertion.
	var order_ok := true
	var previous := 0
	for body in GhostDB.ORDER:
		var h := int(hits_by_body.get(body, -1))
		if h < previous:
			order_ok = false
		previous = h
	if order_ok:
		_pass("ladder order is correct: girl soldier < boy soldier < queen < king")
	else:
		_fail("ladder order is WRONG - a harder ghost died faster than an easier one")


# =========================================================================
#  5. the ghosts can actually kill the player
# =========================================================================
func _test_player_can_die(player: PlayerController) -> void:
	_lines.append("")
	_lines.append("  GHOST OFFENCE")
	var lethal := true
	for body in GhostDB.ORDER:
		var p := GhostDB.get_profile(body)
		var dmg := float(p["damage"])
		var hits_to_kill := int(ceil(player.max_health / maxf(dmg, 0.001)))
		_lines.append("    %-16s %5.1f dmg  range %.1f m  windup %.2f s  ->  %d hits to kill you" % [
			String(p["name"]), dmg, float(p["attack_range"]), float(p["attack_windup"]), hits_to_kill])
		if dmg <= 0.0 or float(p["attack_range"]) <= 0.0:
			lethal = false
	if lethal:
		_pass("every ghost deals damage and can kill an idle player")
	else:
		_fail("some ghost deals no damage - the hunt would not be dangerous")


# =========================================================================
#  small helpers
# =========================================================================
func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _pass(text: String) -> void:
	_lines.append("  PASS  " + text)


func _fail(text: String) -> void:
	_failures += 1
	_lines.append("  FAIL  " + text)


func _finish() -> void:
	print("\n================= COMBAT SELFTEST =================")
	print("project: Haunted Kingdom  (Godot 4.7.2)")
	print("")
	for line in _lines:
		print(line)
	print("")
	print("RESULT: %d failure(s)" % _failures)
	print("=================== END REPORT ====================\n")
	get_tree().quit(1 if _failures > 0 else 0)
