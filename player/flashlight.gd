extends SpotLight3D
class_name PlayerFlashlight
## =========================================================================
## FLASHLIGHT  -  the player's torch
## =========================================================================
## Mounted on the camera, so the beam always points exactly where you look -
## no rotation code at all, because a node under the camera already has "-Z"
## pointing straight ahead.
##
##   F  .................... toggle the torch on / off
##
## WHY THIS EXISTS
## The levels are lit at ambient energy ~0.3, which is genuinely pitch black.
## "Dark" and "black" are not the same thing:
##   * black  = you cannot tell a wall from a door, and playing is guesswork
##   * dark   = you can see silhouettes, and the torch is what you aim at things
## A torch is what turns it into a horror game instead of a broken one.
##
## It has NO battery by default. Running out of light in a level you cannot
## see in is not tense, it is just unplayable. Set `battery_seconds` above 0
## later if you want that, and the beam will dim and warn you first.
##
## `TorchFill` (a short-range OmniLight3D child) is a soft bubble of light
## around the player so the floor at your feet and your own weapon hand are
## never black either. Turn it off by setting `fill_energy` to 0.
## =========================================================================

@export_group("Beam")
## Brightness at full power. Godot lights are energy-scaled, not watts.
@export var beam_energy := 10.0
## How far the beam reaches, in metres.
@export var beam_range := 48.0
## Width of the cone, in degrees. Smaller = tighter, more "searchlight".
@export var beam_angle_deg := 40.0
@export var beam_color := Color(1.0, 0.94, 0.82)

@export_group("Fill light")
## The soft bubble of light around the player. 0 turns it off.
@export var fill_energy := 1.1
@export var fill_range := 5.5

@export_group("Behaviour")
@export var on_at_start := true
## 0 = never runs out. Otherwise the beam dies over this many seconds.
@export var battery_seconds := 0.0

@export_group("Flicker")
## How much the beam wavers. 0 = a rock-steady electric torch.
@export var flicker_strength := 0.07
@export var flicker_speed := 9.0
## Chance per second of a hard drop-out - the failing-bulb stutter.
@export var drop_out_rate := 0.5

var is_on := false

var _t := 0.0
var _dip := 0.0
var _battery := 0.0
var _fill: OmniLight3D


func _ready() -> void:
	light_color = beam_color
	spot_range = beam_range
	spot_angle = beam_angle_deg
	spot_angle_attenuation = 1.35
	shadow_enabled = true
	shadow_bias = 0.04
	light_specular = 0.35

	_fill = get_node_or_null("TorchFill") as OmniLight3D
	if _fill != null:
		_fill.light_color = beam_color
		_fill.omni_range = fill_range

	_battery = battery_seconds
	is_on = on_at_start
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	# Never let the torch be toggled from a menu or while the player is dead.
	if GameManager.is_paused or GameManager.player_is_dead:
		return
	if event.is_action_pressed("lantern"):
		set_torch(not is_on)
		get_viewport().set_input_as_handled()


func set_torch(value: bool) -> void:
	is_on = value
	_apply()
	if value:
		GameManager.show_message("TORCH  ON", 1.5)
	else:
		GameManager.show_message("TORCH  OFF   -   press F for light", 2.0)


func _process(delta: float) -> void:
	if not is_on:
		return
	_t += delta

	var power := 1.0
	if flicker_strength > 0.0:
		power += sin(_t * flicker_speed) * flicker_strength
		power += sin(_t * flicker_speed * 2.37 + 0.9) * flicker_strength * 0.5

	# Occasional 30-90 ms stutters. This is most of what sells "haunted torch".
	_dip = maxf(0.0, _dip - delta)
	if _dip <= 0.0 and drop_out_rate > 0.0 and randf() < drop_out_rate * delta * 3.0:
		_dip = randf_range(0.03, 0.09)
	if _dip > 0.0:
		power *= 0.2

	if battery_seconds > 0.0:
		var was := _battery
		_battery = maxf(0.0, _battery - delta)
		power *= clampf(0.3 + (_battery / battery_seconds) * 0.7, 0.08, 1.0)
		if was > 15.0 and _battery <= 15.0:
			GameManager.show_message("The torch is dying.", 3.0)

	light_energy = maxf(0.0, beam_energy * power)
	if _fill != null:
		_fill.light_energy = maxf(0.0, fill_energy * power)


func _apply() -> void:
	# A Light3D switched off with `visible` costs nothing to draw.
	visible = is_on
	light_energy = beam_energy if is_on else 0.0
	if _fill != null:
		_fill.visible = is_on
		_fill.light_energy = fill_energy if is_on else 0.0
