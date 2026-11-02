extends Control
## =========================================================================
## MainMenu
## =========================================================================
## Attached to ui/main_menu.tscn  -  this is the project's main scene.
##
## The stage buttons are NOT written into the scene by hand. They are built
## from `GameManager.LEVELS` at runtime, so the moment you add a level to that
## table it appears here with a button and no extra work.
##
## This used to hard-code "Play -> stage1_village". That meant Stage 1 was the
## ONLY level you could ever reach, and the Ghost Queen and Ghost King - who
## only exist in Stage 2 - were unreachable.
## =========================================================================

## The order the stages are listed in on the menu. Add a new level here and in
## GameManager.LEVELS and it gets a button.
const STAGE_ORDER := ["stage1_village", "stage2_barracks", "haveli_mansion"]

@onready var _main_panel: Control = %MainPanel
@onready var _settings_panel: Control = %SettingsPanel
@onready var _buttons: VBoxContainer = %Buttons
@onready var _sens_value: Label = %SensValue
@onready var _fov_value: Label = %FovValue
@onready var _vol_value: Label = %VolValue

var _first_stage_button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	%SettingsBtn.pressed.connect(_on_settings_pressed)
	%QuitBtn.pressed.connect(_on_quit_pressed)
	%BackBtn.pressed.connect(_on_back_pressed)
	%SensSlider.value_changed.connect(_on_sensitivity_changed)
	%VolumeSlider.value_changed.connect(_on_volume_changed)
	%FovSlider.value_changed.connect(_on_fov_changed)
	%InvertCheck.toggled.connect(_on_invert_toggled)

	_build_stage_buttons()
	_settings_panel.visible = false
	_main_panel.visible = true
	_load_values()
	if _first_stage_button != null:
		_first_stage_button.grab_focus()


## One button per level, inserted above SETTINGS and QUIT.
func _build_stage_buttons() -> void:
	var slot := 0
	for id in STAGE_ORDER:
		if not GameManager.LEVELS.has(id):
			continue  # listed but the scene is not built yet - skip it quietly
		var b := Button.new()
		b.text = "STAGE %d   -   %s" % [slot + 1, String(GameManager.LEVEL_TITLES.get(id, id)).to_upper()]
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_start_stage.bind(id))
		_buttons.add_child(b)
		_buttons.move_child(b, slot)
		if _first_stage_button == null:
			_first_stage_button = b
		slot += 1


func _start_stage(level_id: String) -> void:
	ProcAudio.play_click()
	# Wipe the kill counter, the keys and the weapon list from the last run,
	# so a new game really is a new game.
	GameManager.reset_run_state()
	GameManager.start_level(level_id)


func _load_values() -> void:
	%SensSlider.set_value_no_signal(GameManager.mouse_sensitivity)
	%VolumeSlider.set_value_no_signal(GameManager.master_volume)
	%FovSlider.set_value_no_signal(GameManager.field_of_view)
	%InvertCheck.set_pressed_no_signal(GameManager.invert_mouse_y)
	_update_labels()


func _update_labels() -> void:
	_sens_value.text = "%.1f" % (GameManager.mouse_sensitivity * 1000.0)
	_vol_value.text = "%d%%" % int(round(GameManager.master_volume * 100.0))
	_fov_value.text = "%d" % int(round(GameManager.field_of_view))


# =========================================================================
#  BUTTONS
# =========================================================================
func _on_settings_pressed() -> void:
	ProcAudio.play_click()
	_main_panel.visible = false
	_settings_panel.visible = true
	%BackBtn.grab_focus()


func _on_back_pressed() -> void:
	ProcAudio.play_click()
	GameManager.save_settings()
	_settings_panel.visible = false
	_main_panel.visible = true
	if _first_stage_button != null:
		_first_stage_button.grab_focus()


func _on_quit_pressed() -> void:
	GameManager.quit_game()


# =========================================================================
#  SETTINGS
# =========================================================================
func _on_sensitivity_changed(v: float) -> void:
	GameManager.mouse_sensitivity = v
	_update_labels()


func _on_volume_changed(v: float) -> void:
	GameManager.master_volume = v
	GameManager.apply_audio()
	_update_labels()


func _on_fov_changed(v: float) -> void:
	GameManager.field_of_view = v
	_update_labels()


func _on_invert_toggled(v: bool) -> void:
	GameManager.invert_mouse_y = v
