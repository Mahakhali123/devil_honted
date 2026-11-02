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

# --- Haveli HUD widgets (built in code, so no scene file can break them) ---
var _stamina_bar: ProgressBar
var _stamina_label: Label
var _stamina_state: Label
var _sanity_bar: ProgressBar
var _sanity_label: Label
var _threat_bar: ProgressBar
var _threat_label: Label
var _noise_label: Label
var _interact_icon: Label


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
	GameManager.inventory_changed.connect(_on_inventory_changed)
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
	_build_status_widgets()


func _set_map_title() -> void:
	var title := get_node_or_null("Root/RightPanel/MapTitle") as Label
	if title != null:
		title.text = GameManager.level_title().to_upper()
	# The Haveli has no floor plan: use the map space for the mission TODO.
	if GameManager.current_level_id == "haveli_mansion":
		var mm := get_node_or_null("Root/RightPanel/Minimap") as Control
		if mm != null:
			mm.visible = false
		var hs := get_node_or_null("Root/RightPanel/HuntStatus") as Label
		if hs != null:
			hs.offset_top = 32.0
			hs.offset_bottom = 76.0
		var tt := get_node_or_null("Root/RightPanel/TodoTitle") as Label
		if tt != null:
			tt.offset_top = 86.0
			tt.offset_bottom = 108.0
		var tl := get_node_or_null("Root/RightPanel/TodoList") as RichTextLabel
		if tl != null:
			tl.offset_top = 110.0
			tl.offset_bottom = 424.0
		# Ritual items add a few lines under the weapon slots.
		var wl := get_node_or_null("Root/RightPanel/WeaponList") as Label
		if wl != null:
			wl.offset_bottom = 700.0


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
	_update_status_widgets()

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
		lines.append("Stamina: %.0f  Sprinting: %s" % [p.stamina, str(p.is_sprinting())])
	if GameManager.current_level_id != "":
		lines.append("Level: %s" % GameManager.current_level_id)
	lines.append("Threat: %.1f (%s)  Sanity: %.1f" % [GameManager.threat_level, GameManager.threat_tag(), GameManager.sanity])
	lines.append("Zone: %s  Hidden: %s" % [GameManager.current_zone, str(GameManager.player_hidden)])
	lines.append("Last noise: %.0f m  (%.1fs ago)" % [GameManager.last_noise_radius, GameManager.last_noise_age])
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
	if not GameManager.inventory.is_empty():
		lines.append("")
		for item_id in GameManager.inventory:
			var entry: Dictionary = GameManager.inventory[item_id]
			var count := int(entry.get("count", 0))
			if count <= 0:
				continue
			lines.append("%s  x%d" % [String(entry.get("label", item_id)), count])
	_weapon_list.text = "\n".join(lines)


func _on_weapons_changed(_list: Array, _index: int) -> void:
	_refresh_weapons()


func _on_key_collected(_key_id: String, _label: String) -> void:
	_refresh_weapons()


func _on_inventory_changed(_items: Dictionary) -> void:
	_refresh_weapons()


# =========================================================================
#  THE TASK BOX  (right-hand panel)
# =========================================================================
## Rewrites the TODO list as coloured BBCode: the difficulty ladder first,
## then the live task list. Finished tasks go green with a strikethrough.
func _refresh_tasks() -> void:
	if _todo_list == null:
		return

	# The Haveli is a different game mode: its right-hand panel shows the
	# mission TODO (ingredients / key / Havan / survival), not the ghost ladder.
	if GameManager.current_level_id == "haveli_mansion":
		var hout := ""
		if GameManager.objectives.is_empty():
			hout += "[color=#6f6a60]  (nothing yet)[/color]\n"
		else:
			for o in GameManager.objectives:
				if typeof(o) != TYPE_DICTIONARY:
					continue
				var hdone := bool(o.get("done", false))
				var htext := String(o.get("text", ""))
				if hdone:
					hout += "[color=#63a06c][s]  [x] %s[/s][/color]\n" % htext
				else:
					hout += "[color=#ded6c4]  [ ] %s[/color]\n" % htext
		_todo_list.text = hout
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

	if GameManager.current_level_id == "haveli_mansion":
		var kamla := get_tree().get_first_node_in_group("kamla")
		var kstate := "DORMANT"
		if kamla != null and kamla.has_method("state_name"):
			kstate = String(kamla.state_name())
		_hunt_status.text = "KAMLA: %s\nTHREAT %d - %s   ZONE: %s" % [
			kstate,
			int(round(GameManager.threat_level)),
			GameManager.threat_tag(),
			GameManager.current_zone if GameManager.current_zone != "" else "-",
		]
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


# =========================================================================
#  HAVELI STATUS WIDGETS  (stamina / sanity / threat / noise / interact)
# =========================================================================
func _build_status_widgets() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return

	# --- stamina, above the health bar -----------------------------------
	var sg := Control.new()
	sg.anchor_top = 1.0
	sg.anchor_bottom = 1.0
	sg.offset_left = 30.0
	sg.offset_top = -166.0
	sg.offset_right = 470.0
	sg.offset_bottom = -118.0
	sg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sg)
	_stamina_label = _widget_label("STAMINA  100", 14, Color(0.88, 0.84, 0.68))
	_stamina_label.size = Vector2(300.0, 20.0)
	sg.add_child(_stamina_label)
	_stamina_bar = _widget_bar(Color(0.72, 0.62, 0.22))
	_stamina_bar.position = Vector2(0.0, 22.0)
	_stamina_bar.size = Vector2(300.0, 14.0)
	sg.add_child(_stamina_bar)
	_stamina_state = _widget_label("", 13, Color(0.95, 0.42, 0.32))
	_stamina_state.size = Vector2(300.0, 20.0)
	_stamina_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sg.add_child(_stamina_state)
	_noise_label = _widget_label("NOISE  -", 13, Color(0.78, 0.82, 0.9))
	_noise_label.position = Vector2(312.0, 12.0)
	_noise_label.size = Vector2(130.0, 24.0)
	sg.add_child(_noise_label)

	# --- sanity, above stamina --------------------------------------------
	var ng := Control.new()
	ng.anchor_top = 1.0
	ng.anchor_bottom = 1.0
	ng.offset_left = 30.0
	ng.offset_top = -214.0
	ng.offset_right = 470.0
	ng.offset_bottom = -168.0
	ng.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ng)
	_sanity_label = _widget_label("SANITY  100", 14, Color(0.72, 0.68, 0.88))
	_sanity_label.size = Vector2(300.0, 20.0)
	ng.add_child(_sanity_label)
	_sanity_bar = _widget_bar(Color(0.42, 0.30, 0.68))
	_sanity_bar.position = Vector2(0.0, 22.0)
	_sanity_bar.size = Vector2(300.0, 14.0)
	ng.add_child(_sanity_bar)

	# --- threat, top centre ----------------------------------------------
	var tg := Control.new()
	tg.anchor_left = 0.5
	tg.anchor_right = 0.5
	tg.offset_left = -170.0
	tg.offset_top = 12.0
	tg.offset_right = 170.0
	tg.offset_bottom = 64.0
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tg)
	_threat_label = _widget_label("THREAT  0  -  CALM", 14, Color(0.85, 0.72, 0.28))
	_threat_label.size = Vector2(340.0, 20.0)
	_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tg.add_child(_threat_label)
	_threat_bar = _widget_bar(Color(0.80, 0.58, 0.18))
	_threat_bar.position = Vector2(0.0, 24.0)
	_threat_bar.size = Vector2(340.0, 12.0)
	tg.add_child(_threat_bar)

	# --- contextual interaction icon, just under the crosshair -----------
	_interact_icon = _widget_label("[E]", 20, Color(0.98, 0.82, 0.35))
	_interact_icon.anchor_left = 0.5
	_interact_icon.anchor_top = 0.5
	_interact_icon.anchor_right = 0.5
	_interact_icon.anchor_bottom = 0.5
	_interact_icon.offset_left = -40.0
	_interact_icon.offset_top = 26.0
	_interact_icon.offset_right = 40.0
	_interact_icon.offset_bottom = 56.0
	_interact_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_icon.visible = false
	root.add_child(_interact_icon)


func _widget_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 4)
	return l


func _widget_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.05, 0.78)
	bg.border_color = Color(0.32, 0.27, 0.22, 0.85)
	bg.set_border_width_all(2)
	bar.add_theme_stylebox_override("background", bg)
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	bar.add_theme_stylebox_override("fill", f)
	return bar


func _update_status_widgets() -> void:
	var p := get_tree().get_first_node_in_group("player") as PlayerController
	if p != null and _stamina_bar != null:
		_stamina_bar.value = p.stamina
		_stamina_label.text = "STAMINA  %d" % int(round(p.stamina))
		if p.is_exhausted():
			_stamina_state.text = "EXHAUSTED"
		elif p.is_sprinting():
			_stamina_state.text = "SPRINTING"
		else:
			_stamina_state.text = ""

	if _sanity_bar != null:
		_sanity_bar.value = GameManager.sanity
		_sanity_label.text = "SANITY  %d" % int(round(GameManager.sanity))
		if GameManager.sanity <= 25.0:
			_sanity_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.55))
		else:
			_sanity_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.88))

	if _threat_bar != null:
		_threat_bar.value = GameManager.threat_level
		_threat_label.text = "THREAT  %d  -  %s" % [int(round(GameManager.threat_level)), GameManager.threat_tag()]
		var c := Color(0.85, 0.72, 0.28)
		if GameManager.threat_level >= 70.0:
			c = Color(0.94, 0.20, 0.14)
		elif GameManager.threat_level >= 45.0:
			c = Color(0.94, 0.46, 0.14)
		elif GameManager.threat_level >= 20.0:
			c = Color(0.88, 0.66, 0.20)
		_threat_label.add_theme_color_override("font_color", c)

	if _noise_label != null:
		if GameManager.last_noise_age < 1.2:
			_noise_label.text = "NOISE  %d m" % int(round(GameManager.last_noise_radius))
			_noise_label.modulate.a = 1.0
		else:
			_noise_label.text = "NOISE  -"
			_noise_label.modulate.a = 0.25

	if _interact_icon != null:
		_interact_icon.visible = GameManager.interact_prompt_text != ""


func _update_crosshair(delta: float) -> void:
	_hit_marker = maxf(0.0, _hit_marker - delta)
	_hit_alpha = maxf(0.0, _hit_alpha - delta * 2.4)
	if _hit_text != null:
		_hit_text.modulate.a = _hit_alpha
	if _cross_h == null or _cross_v == null:
		return
	var hot := _hit_marker > 0.0
	var prompt := GameManager.interact_prompt_text != ""
	var c := Color(1.0, 0.85, 0.35, 0.95) if hot else Color(0.9, 0.88, 0.85, 0.5)
	if prompt and not hot:
		c = Color(0.98, 0.82, 0.35, 0.95)
	_cross_h.color = c
	_cross_v.color = c
	var grow := 2.0 if hot else (1.0 if prompt else 0.0)
	_cross_h.offset_left = -9.0 - grow
	_cross_h.offset_right = 9.0 + grow
	_cross_v.offset_top = -9.0 - grow
	_cross_v.offset_bottom = 9.0 + grow
