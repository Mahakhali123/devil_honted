extends CanvasLayer
## =========================================================================
## HUD  -  the in-game interface
## =========================================================================
## Attached to ui/hud.tscn. The level spawns it as a child.
##
## Widgets are found by "unique name" (%HealthBar) so you can move them
## around in the editor without breaking this script.
##
##   HealthBar     player health
##   DamageFlash   red flash when hurt
##   DebugLabel    F3 diagnostics
##   PauseMenu     ESC
##   DeathScreen   shown by GameManager.player_died
## =========================================================================

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _damage_flash: ColorRect = %DamageFlash
@onready var _debug_label: Label = %DebugLabel
@onready var _pause_menu: Control = %PauseMenu
@onready var _death_screen: Control = %DeathScreen
@onready var _hit_text: Label = %HitText
@onready var _target_panel: Control = %TargetPanel
@onready var _target_name: Label = %TargetName
@onready var _target_bar: ProgressBar = %TargetBar
@onready var _todo_list: RichTextLabel = %TodoList
@onready var _weapon_list: Label = %WeaponList
@onready var _hunt_status: Label = %HuntStatus
@onready var _cross_h: ColorRect = $Root/Crosshair/H
@onready var _cross_v: ColorRect = $Root/Crosshair/V

var _show_debug := false
var _flash := 0.0
var _low_health_pulse := 0.0
var _hit_alpha := 0.0
var _hit_marker := 0.0


func _ready() -> void:
	# Keep the HUD alive while the game is paused, otherwise the pause menu
	# would freeze and you could never click "Resume".
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	%ResumeBtn.pressed.connect(_on_resume_pressed)
	%PauseRestartBtn.pressed.connect(_on_restart_pressed)
	%PauseMenuBtn.pressed.connect(_on_main_menu_pressed)
	%PauseQuitBtn.pressed.connect(_on_quit_pressed)
	%DeathRestartBtn.pressed.connect(_on_restart_pressed)
	%DeathMenuBtn.pressed.connect(_on_main_menu_pressed)

	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.player_damaged.connect(_on_player_damaged)
	GameManager.player_died.connect(_on_player_died)
	GameManager.pause_changed.connect(_on_pause_changed)
	GameManager.weapons_changed.connect(_on_weapons_changed)
	GameManager.key_collected.connect(_on_key_collected)
	GameManager.objectives_changed.connect(_on_objectives_changed)
	GameManager.enemy_hit.connect(_on_enemy_hit)

	_on_health_changed(GameManager.player_health, GameManager.player_max_health)
	_pause_menu.visible = false
	_death_screen.visible = false
	_debug_label.visible = false
	_damage_flash.color.a = 0.0
	_hit_text.text = ""
	_target_panel.visible = false
	_set_map_title()
	_refresh_weapons()
	_refresh_tasks()


func _set_map_title() -> void:
	var title := get_node_or_null("Root/RightPanel/MapTitle") as Label
	if title != null:
		title.text = GameManager.level_title().to_upper()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.7)
		_damage_flash.color.a = _flash * 0.42

	# Hearts beat faster when you are nearly dead.
	if GameManager.player_health < 30.0 and not GameManager.player_is_dead:
		_low_health_pulse += delta * 0.02
		var pulse := (sin(_low_health_pulse * TAU * 1.4) + 1.0) * 0.5
		_damage_flash.color.a = maxf(_damage_flash.color.a, pulse * 0.10)

	_update_crosshair(delta)
	_update_target_panel()
	_update_hunt_status()

	if _show_debug:
		_debug_label.text = _debug_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_show_debug = not _show_debug
		_debug_label.visible = _show_debug


func _debug_text() -> String:
	var lines: Array[String] = []
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	lines.append("Draw calls: %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	lines.append("Objects: %d" % int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	lines.append("Static mem: %.1f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	var p := get_tree().get_first_node_in_group("player") as PlayerController
	if p != null:
		lines.append("Pos: %.1f, %.1f, %.1f" % [p.global_position.x, p.global_position.y, p.global_position.z])
		lines.append("Speed: %.2f m/s" % Vector2(p.velocity.x, p.velocity.z).length())
		lines.append("On floor: %s" % str(p.is_on_floor()))
		lines.append("Crouching: %s" % str(p.is_crouching()))
	if GameManager.current_level_id != "":
		lines.append("Level: %s" % GameManager.current_level_id)
	return "\n".join(lines)


# =========================================================================
#  SIGNAL HANDLERS
# =========================================================================
func _on_health_changed(current: float, maximum: float) -> void:
	if _health_bar == null:
		return
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [int(round(current)), int(round(maximum))]
	if current <= 30.0:
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.28))
	else:
		_health_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.8))


func _on_player_damaged(amount: float) -> void:
	_flash = clampf(_flash + amount * 0.035, 0.0, 1.0)


func _on_player_died() -> void:
	_pause_menu.visible = false
	_death_screen.visible = true
	%DeathRestartBtn.grab_focus()


func _on_pause_changed(paused: bool) -> void:
	_pause_menu.visible = paused
	if paused:
		%ResumeBtn.grab_focus()


func _on_resume_pressed() -> void:
	ProcAudio.play_click()
	GameManager.set_paused(false)


func _on_restart_pressed() -> void:
	ProcAudio.play_click()
	GameManager.restart_level()


func _on_main_menu_pressed() -> void:
	ProcAudio.play_click()
	GameManager.goto_main_menu()


func _on_quit_pressed() -> void:
	GameManager.quit_game()


# =========================================================================
#  WEAPONS + KEYS  (the CARRIED list in the right-hand panel)
# =========================================================================
func _refresh_weapons() -> void:
	if _weapon_list == null:
		return
	var lines: Array[String] = []
	for i in WeaponDB.SLOT_ORDER.size():
		var id: String = WeaponDB.SLOT_ORDER[i]
		if GameManager.owned_weapons.has(id):
			var marker := ">" if GameManager.equipped_weapon_id() == id else " "
			lines.append("%s %d  %s" % [marker, i + 1, WeaponDB.display_name(id)])
		else:
			lines.append("  %d  - - - - -" % (i + 1))
	if not GameManager.keys.is_empty():
		lines.append("")
		for k in GameManager.keys:
			lines.append("KEY  %s" % GameManager.key_display_name(k))
	_weapon_list.text = "\n".join(lines)


func _on_weapons_changed(_list: Array, _index: int) -> void:
	_refresh_weapons()


func _on_key_collected(_key_id: String, _label: String) -> void:
	_refresh_weapons()


# =========================================================================
#  THE TASK BOX  (right-hand panel)
# =========================================================================
## Rewrites the TODO list as coloured BBCode: the difficulty ladder first,
## then the live task list. Finished tasks go green with a strikethrough.
func _refresh_tasks() -> void:
	if _todo_list == null:
		return
	var order := [
		[GhostRig.Body.SOLDIER_FEMALE, "Girl Soldier", "EASIEST"],
		[GhostRig.Body.SOLDIER_MALE, "Boy Soldier", "EASY"],
		[GhostRig.Body.GHOST_QUEEN, "Ghost Queen", "HARD"],
		[GhostRig.Body.GHOST_KING, "Ghost King", "HARDEST"],
	]
	var out := "[color=#8a8272]difficulty ladder[/color]\n"
	for e in order:
		var c: Color = Minimap.difficulty_color(e[0])
		out += "[color=#%s]  * %s - %s[/color]\n" % [c.to_html(false), e[1], e[2]]

	out += "\n[color=#8a8272]tasks[/color]\n"
	if GameManager.objectives.is_empty():
		out += "[color=#6f6a60]  (nothing yet)[/color]\n"
	else:
		for o in GameManager.objectives:
			if typeof(o) != TYPE_DICTIONARY:
				continue
			var done := bool(o.get("done", false))
			var text := String(o.get("text", ""))
			if done:
				out += "[color=#63a06c][s]  [x] %s[/s][/color]\n" % text
			else:
				out += "[color=#ded6c4]  [ ] %s[/color]\n" % text
	_todo_list.text = out


func _on_objectives_changed(_objectives: Array) -> void:
	_refresh_tasks()


# =========================================================================
#  ENEMY HEALTH BAR + HIT MARKER
# =========================================================================
## Picks the ghost worth showing a health bar for: nearest and most in front
## of you, with priority given to anything already hunting you.
func _best_target() -> EnemyGhost:
	var p := get_tree().get_first_node_in_group("player") as PlayerController
	if p == null:
		return null
	var origin := p.global_position + Vector3(0.0, 1.5, 0.0)
	var fwd := -p.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return null
	fwd = fwd.normalized()

	var best: EnemyGhost = null
	var best_score := -100.0
	for n in get_tree().get_nodes_in_group("ghost"):
		var g := n as EnemyGhost
		if g == null or not g.is_alive():
			continue
		var to := g.global_position + Vector3(0.0, 1.0, 0.0) - origin
		var dist := to.length()
		if dist > 24.0:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		var angle := 0.0
		if flat.length_squared() > 0.0001:
			angle = fwd.angle_to(flat.normalized())
		var hunting := g.state == EnemyGhost.State.CHASE \
			or g.state == EnemyGhost.State.ATTACK \
			or g.state == EnemyGhost.State.STAGGER
		if angle > deg_to_rad(58.0) and not hunting:
			continue
		var score := (1.0 - dist / 24.0) * 2.0
		score += (1.0 - angle / PI) * 1.2
		score += 1.6 if hunting else 0.0
		score += (1.0 - clampf(g.health / maxf(g.max_health, 0.001), 0.0, 1.0)) * 1.0
		if score > best_score:
			best_score = score
			best = g
	return best


func _update_target_panel() -> void:
	if _target_panel == null:
		return
	var g := _best_target()
	if g == null:
		_target_panel.visible = false
		return
	_target_panel.visible = true
	var colour: Color = Minimap.difficulty_color(g.rig_body)
	_target_name.text = "%s   [%s]" % [g.display_name, GhostDB.difficulty_tag(g.rig_body)]
	_target_name.add_theme_color_override("font_color", colour)
	_target_bar.max_value = g.max_health
	_target_bar.value = g.health


func _update_hunt_status() -> void:
	if _hunt_status == null:
		return
	var left := GameManager.alive_ghost_count()
	var tag := "SPIRITS LEFT: %d" % left
	if GameManager.ghosts_total > 0:
		tag = "SPIRITS LEFT: %d / %d" % [left, GameManager.ghosts_total]
	_hunt_status.text = "%s    SCORE: %d\n%s" % [tag, GameManager.score, _nearest_ghost_text()]


## "NEAREST: The Ghost Queen - 18 m (behind you)".
## The minimap shows where the ghosts are; this tells you how far and which
## direction, so you can hunt instead of wandering.
func _nearest_ghost_text() -> String:
	var p := get_tree().get_first_node_in_group("player") as PlayerController
	if p == null:
		return ""
	var best: EnemyGhost = null
	var best_d := 1e20
	for n in get_tree().get_nodes_in_group("ghost"):
		var g := n as EnemyGhost
		if g == null or not g.is_alive():
			continue
		var d := p.global_position.distance_to(g.global_position)
		if d < best_d:
			best_d = d
			best = g
	if best == null:
		return "All spirits banished."

	var to_g := best.global_position - p.global_position
	var flat := Vector3(to_g.x, 0.0, to_g.z)
	var where := ""
	if flat.length_squared() > 0.0001:
		flat = flat.normalized()
		var ahead := (-p.global_transform.basis.z).normalized().dot(flat)
		if ahead > 0.45:
			where = "ahead"
		elif ahead < -0.45:
			where = "behind you"
		elif p.global_transform.basis.x.dot(flat) > 0.0:
			where = "to your right"
		else:
			where = "to your left"
	return "NEAREST: %s - %d m  (%s)" % [best.display_name, int(round(best_d)), where]


func _on_enemy_hit(_ghost_name: String, damage: float) -> void:
	_hit_marker = 0.16
	_hit_alpha = 1.0
	if _hit_text != null:
		_hit_text.text = "-%d" % int(round(damage))


func _update_crosshair(delta: float) -> void:
	_hit_marker = maxf(0.0, _hit_marker - delta)
	_hit_alpha = maxf(0.0, _hit_alpha - delta * 2.4)
	if _hit_text != null:
		_hit_text.modulate.a = _hit_alpha
	if _cross_h == null or _cross_v == null:
		return
	var hot := _hit_marker > 0.0
	var c := Color(1.0, 0.85, 0.35, 0.95) if hot else Color(0.9, 0.88, 0.85, 0.5)
	_cross_h.color = c
	_cross_v.color = c
	var grow := 2.0 if hot else 0.0
	_cross_h.offset_left = -9.0 - grow
	_cross_h.offset_right = 9.0 + grow
	_cross_v.offset_top = -9.0 - grow
	_cross_v.offset_bottom = 9.0 + grow
