extends Node
## =========================================================================
## GameManager  -  AUTOLOAD / SINGLETON
## =========================================================================
## This script runs for the whole life of the game and can be reached from
## ANY other script just by typing:  GameManager.something
##
## It handles:
##   * registering the keyboard / mouse controls (InputMap)
##   * loading levels with a fade-to-black transition
##   * pause / unpause
##   * on screen messages + the current objective
##   * saving the player's settings to disk (mouse speed, volume, FOV)
## =========================================================================

# ---------------------------------------------------------------- signals
signal player_health_changed(current: float, maximum: float)
signal player_damaged(amount: float)
signal player_died
signal pause_changed(paused: bool)
signal level_started(level_id: String)
signal interact_prompt_changed(text: String)
signal clue_found(clue_id: String)
signal key_collected(key_id: String, label: String)
signal weapons_changed(weapons: Array, equipped_index: int)
signal ghost_banished(ghost_name: String, remaining: int, quest_id: String)
signal map_changed()
signal enemy_hit(ghost_name: String, damage: float)
signal objectives_changed(objectives: Array)

# ---------------------------------------------------------------- levels
const LEVELS := {
	"stage1_village": "res://levels/stage1_village.tscn",
	"stage2_barracks": "res://levels/stage2_barracks.tscn",
}

const LEVEL_TITLES := {
	"stage1_village": "The Abandoned Village",
	"stage2_barracks": "The Haunted Barracks",
}

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const OVERLAY_LAYER := 100

## Number keys 1-6 jump straight to these weapon slots.
const SLOT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]

# ---------------------------------------------------------------- state
var current_level_id := ""
var is_paused := false
var player_is_dead := false

var player_health := 100.0
var player_max_health := 100.0
var interact_prompt_text := ""

# ---------------------------------------------------------------- inventory
## Key ids the player has picked up, e.g. "armoury_key".
var keys: Array[String] = []
var key_labels: Dictionary = {}
## Mirror of the player's weapons, kept here so the HUD can read them.
var owned_weapons: Array = ["fists"]
var equipped_weapon_index := 0

# ---------------------------------------------------------------- run stats
var score := 0
var ghosts_total := 0
var ghosts_banished := 0
var banished_by_type: Dictionary = {}

# ---------------------------------------------------------------- map
## Top-down rectangles harvested from the level's LevelBlock nodes, used by
## the HUD minimap. Each entry: {"rect": Rect2, "height": float}.
var map_blocks: Array = []
var map_bounds := Rect2(-20.0, -20.0, 40.0, 40.0)
var map_ready := false

# ---------------------------------------------------------------- task list
## The in-game TODO list, shown in the HUD's right-hand panel.
## Each entry: {"id": String, "text": String, "done": bool}
var objectives: Array = []

# ---------------------------------------------------------------- settings
var mouse_sensitivity := 0.0025
var master_volume := 0.85
var invert_mouse_y := false
var field_of_view := 78.0

# ---------------------------------------------------------------- private
var _ui_layer: CanvasLayer
var _fade: ColorRect
var _message: Label
var _objective: Label
var _interact: Label
var _fade_alpha := 1.0
var _fade_target := 0.0
var _fade_speed := 2.0
var _message_timer := 0.0
var _message_alpha := 0.0
var _objective_timer := 0.0


# =========================================================================
#  LIFECYCLE
# =========================================================================
func _ready() -> void:
	# PROCESS_MODE_ALWAYS = keep working even when the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_default_input()
	_build_overlay()
	load_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_settings()


func _process(delta: float) -> void:
	_update_fade(delta)
	_update_overlay_text(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Escape = pause menu (only while actually playing a level).
	if current_level_id == "" or player_is_dead:
		return
	if event.is_action_pressed("ui_cancel"):
		set_paused(not is_paused)
		get_viewport().set_input_as_handled()


# =========================================================================
#  INPUT MAP  (all controls are created from code - change them here)
# =========================================================================
func _register_default_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("crouch", KEY_CTRL)
	_add_key_action("interact", KEY_E)
	_add_key_action("attack", KEY_NONE, MOUSE_BUTTON_LEFT)
	_add_key_action("aim", KEY_NONE, MOUSE_BUTTON_RIGHT)
	_add_key_action("lantern", KEY_F)
	_add_key_action("heal", KEY_Q)
	_add_key_action("toggle_debug", KEY_F3)
	for i in SLOT_KEYS.size():
		_add_key_action("slot_%d" % (i + 1), SLOT_KEYS[i])


func _add_key_action(action: StringName, keycode: Key, mouse_button: int = -1) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	if not InputMap.action_get_events(action).is_empty():
		return  # the user already mapped it in Project Settings - respect that
	if mouse_button >= 0:
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse_button as MouseButton
		InputMap.action_add_event(action, mb)
	elif keycode != KEY_NONE:
		var k := InputEventKey.new()
		k.physical_keycode = keycode
		InputMap.action_add_event(action, k)


# =========================================================================
#  PAUSE
# =========================================================================
func set_paused(value: bool) -> void:
	if player_is_dead and value:
		return
	is_paused = value
	get_tree().paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	pause_changed.emit(value)


# =========================================================================
#  LEVEL LOADING
# =========================================================================
func start_level(level_id: String) -> void:
	if not LEVELS.has(level_id):
		push_error("GameManager: unknown level id '%s'" % level_id)
		return
	await fade_to(1.0, 0.5)
	is_paused = false
	get_tree().paused = false
	player_is_dead = false
	current_level_id = level_id
	interact_prompt_text = ""
	clear_map()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var err := get_tree().change_scene_to_file(LEVELS[level_id])
	if err != OK:
		push_error("GameManager: could not load level, error code %d" % err)
		return

	await get_tree().process_frame
	await get_tree().process_frame
	level_started.emit(level_id)
	await fade_to(0.0, 0.9)


func restart_level() -> void:
	if current_level_id == "":
		start_level("stage1_village")
	else:
		start_level(current_level_id)


func goto_main_menu() -> void:
	is_paused = false
	player_is_dead = false
	current_level_id = ""
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func quit_game() -> void:
	save_settings()
	get_tree().quit()


# =========================================================================
#  FADE  (used by level loading and by the death screen)
# =========================================================================
func fade_to(target: float, duration: float) -> void:
	_fade_target = clampf(target, 0.0, 1.0)
	_fade_speed = 1.0 / maxf(duration, 0.001)
	while not is_equal_approx(_fade_alpha, _fade_target):
		await get_tree().process_frame


func _update_fade(delta: float) -> void:
	if _fade == null:
		return
	if is_equal_approx(_fade_alpha, _fade_target):
		return
	_fade_alpha = move_toward(_fade_alpha, _fade_target, _fade_speed * delta)
	_fade.color.a = _fade_alpha


# =========================================================================
#  PLAYER REPORTING  (the Player script calls these)
# =========================================================================
func report_health(current: float, maximum: float) -> void:
	player_health = current
	player_max_health = maximum
	player_health_changed.emit(current, maximum)


func report_damage(amount: float) -> void:
	player_damaged.emit(amount)


func report_player_death() -> void:
	player_is_dead = true
	is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player_died.emit()


func set_interact_prompt(text: String) -> void:
	if interact_prompt_text == text:
		return
	interact_prompt_text = text
	if _interact != null:
		_interact.text = text
	interact_prompt_changed.emit(text)


# =========================================================================
#  ON SCREEN TEXT
# =========================================================================
func show_message(text: String, duration := 4.0) -> void:
	if _message == null:
		return
	_message.text = text
	_message_timer = duration
	_message_alpha = 1.0


func set_objective(text: String) -> void:
	if _objective == null:
		return
	_objective.text = "OBJECTIVE\n" + text
	_objective_timer = 6.0


func find_clue(clue_id: String) -> void:
	clue_found.emit(clue_id)


# =========================================================================
#  KEYS  (props/key_item.gd calls collect_key)
# =========================================================================
func collect_key(key_id: String, label := "") -> void:
	if key_id == "" or keys.has(key_id):
		return
	keys.append(key_id)
	key_labels[key_id] = label if label != "" else key_id
	key_collected.emit(key_id, String(key_labels[key_id]))


func has_key(key_id: String) -> bool:
	return keys.has(key_id)


func key_display_name(key_id: String) -> String:
	return String(key_labels.get(key_id, key_id))


# =========================================================================
#  WEAPONS  (the player reports its list so the HUD stays in sync)
# =========================================================================
func report_weapons(list: Array, equipped_index: int) -> void:
	owned_weapons = list.duplicate()
	equipped_weapon_index = equipped_index
	weapons_changed.emit(owned_weapons, equipped_weapon_index)


func equipped_weapon_id() -> String:
	if owned_weapons.is_empty():
		return "fists"
	return String(owned_weapons[clampi(equipped_weapon_index, 0, owned_weapons.size() - 1)])


# =========================================================================
#  GHOST HUNT TRACKING
# =========================================================================
## A level calls this once it knows how many ghosts it spawned.
func register_ghost_targets(total: int) -> void:
	ghosts_total = total
	ghosts_banished = 0
	banished_by_type.clear()


func report_ghost_banished(ghost_name: String, body_type: int, quest_id := "") -> void:
	ghosts_banished += 1
	var p := GhostDB.get_profile(body_type)
	banished_by_type[body_type] = int(banished_by_type.get(body_type, 0)) + 1
	var gained := int(p.get("score", 100))
	score += gained
	var remaining := maxi(0, ghosts_total - ghosts_banished)
	if quest_id != "":
		complete_objective(quest_id)
	show_message("%s banished.   +%d   (%d left)" % [ghost_name, gained, remaining], 3.0)
	ghost_banished.emit(ghost_name, remaining, quest_id)


func ghosts_left() -> int:
	return maxi(0, ghosts_total - ghosts_banished)


func alive_ghost_count() -> int:
	return get_tree().get_nodes_in_group("ghost").size()


# =========================================================================
#  TASK LIST  (the "todo" box in the HUD)
# =========================================================================
func set_objectives(list: Array) -> void:
	objectives = list.duplicate(true)
	objectives_changed.emit(objectives)


func add_objective(id: String, text: String) -> void:
	objectives.append({"id": id, "text": text, "done": false})
	objectives_changed.emit(objectives)


func complete_objective(id: String) -> void:
	var changed := false
	for o in objectives:
		if typeof(o) == TYPE_DICTIONARY and String(o.get("id", "")) == id and not bool(o.get("done", false)):
			o["done"] = true
			changed = true
	if changed:
		objectives_changed.emit(objectives)


func is_objective_done(id: String) -> bool:
	for o in objectives:
		if typeof(o) == TYPE_DICTIONARY and String(o.get("id", "")) == id:
			return bool(o.get("done", false))
	return false


func is_objective_known(id: String) -> bool:
	for o in objectives:
		if typeof(o) == TYPE_DICTIONARY and String(o.get("id", "")) == id:
			return true
	return false


# =========================================================================
#  COMBAT FEEDBACK
# =========================================================================
func report_hit(ghost_name: String, damage: float) -> void:
	enemy_hit.emit(ghost_name, damage)


# =========================================================================
#  MAP  (the HUD minimap reads this)
# =========================================================================
func set_map(blocks: Array, bounds: Rect2) -> void:
	map_blocks = blocks
	map_bounds = bounds
	map_ready = true
	map_changed.emit()


func clear_map() -> void:
	map_blocks.clear()
	map_bounds = Rect2(-20.0, -20.0, 40.0, 40.0)
	map_ready = false
	map_changed.emit()


func level_title() -> String:
	return String(LEVEL_TITLES.get(current_level_id, "The Haunted Kingdom"))


# =========================================================================
#  NEW RUN  (main menu "Play" calls this)
# =========================================================================
func reset_run_state() -> void:
	keys.clear()
	key_labels.clear()
	owned_weapons = ["fists"]
	equipped_weapon_index = 0
	score = 0
	ghosts_total = 0
	ghosts_banished = 0
	banished_by_type.clear()
	objectives.clear()
	objectives_changed.emit(objectives)
	clear_map()


# =========================================================================
#  SETTINGS FILE
# =========================================================================
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_mouse_y", invert_mouse_y)
	cfg.set_value("video", "field_of_view", field_of_view)
	cfg.set_value("audio", "master_volume", master_volume)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("GameManager: could not save settings (code %d)" % err)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
		invert_mouse_y = cfg.get_value("controls", "invert_mouse_y", invert_mouse_y)
		field_of_view = cfg.get_value("video", "field_of_view", field_of_view)
		master_volume = cfg.get_value("audio", "master_volume", master_volume)
	apply_audio()


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))


# =========================================================================
#  OVERLAY UI  (built in code so there is no scene file to break)
# =========================================================================
func _build_overlay() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "GameManagerOverlay"
	_ui_layer.layer = OVERLAY_LAYER
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	_objective = _make_label(18, Color(0.84, 0.80, 0.68))
	_objective.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_objective.offset_left = 30.0
	_objective.offset_top = 22.0
	_objective.offset_right = 470.0
	_objective.offset_bottom = 130.0
	_objective.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.modulate.a = 0.0
	_ui_layer.add_child(_objective)

	_message = _make_label(20, Color(0.92, 0.90, 0.86))
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message.offset_left = 120.0
	_message.offset_right = -120.0
	_message.offset_bottom = -110.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.modulate.a = 0.0
	_ui_layer.add_child(_message)

	_interact = _make_label(17, Color(0.88, 0.84, 0.55))
	_interact.set_anchors_preset(Control.PRESET_CENTER)
	_interact.offset_left = -320.0
	_interact.offset_right = 320.0
	_interact.offset_top = 52.0
	_interact.offset_bottom = 82.0
	_interact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact.modulate.a = 0.0
	_ui_layer.add_child(_interact)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_fade)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 4)
	return l


func _update_overlay_text(delta: float) -> void:
	if _message != null:
		if _message_timer > 0.0:
			_message_timer -= delta
		else:
			_message_alpha = move_toward(_message_alpha, 0.0, delta * 1.1)
		_message.modulate.a = _message_alpha
	if _objective != null:
		if _objective_timer > 0.0:
			_objective_timer -= delta
			_objective.modulate.a = minf(1.0, (6.0 - _objective_timer) * 2.5)
		else:
			_objective.modulate.a = move_toward(_objective.modulate.a, 0.0, delta * 0.6)
	if _interact != null:
		var wanted := 1.0 if interact_prompt_text != "" else 0.0
		_interact.modulate.a = move_toward(_interact.modulate.a, wanted, delta * 6.0)
