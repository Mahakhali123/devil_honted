extends OmniLight3D
## =========================================================================
## FlickerLight  -  a candle / torch that never sits still.
## =========================================================================
## Attach straight to any OmniLight3D. Tune base_energy and flicker_amount
## in the Inspector. Blackouts happen at random to keep the player nervous.
## =========================================================================

@export var base_energy := 1.4
@export var flicker_amount := 0.35
@export var flicker_speed := 9.0
@export var blackout_chance := 0.0035
@export var blackout_time := 0.09

var _t := 0.0
var _seed := 0.0
var _blackout := 0.0


func _ready() -> void:
	_seed = randf() * 100.0
	set_process(true)


func _process(delta: float) -> void:
	if _blackout > 0.0:
		_blackout -= delta
		light_energy = 0.0
		return

	_t += delta * flicker_speed
	var n := sin(_t + _seed) * 0.6 + sin(_t * 2.7 + 1.3) * 0.3 + sin(_t * 5.1 + 2.1) * 0.1
	light_energy = maxf(0.0, base_energy + n * flicker_amount * base_energy)

	if randf() < blackout_chance:
		_blackout = blackout_time
