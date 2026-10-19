extends Node
## =========================================================================
## ProcAudio  -  AUTOLOAD / SINGLETON
## =========================================================================
## Horror games need sound, but you cannot download a sound pack in the first
## five minutes. So this script SYNTHESISES every sound effect with maths and
## builds a real AudioStreamWAV at runtime. Nothing to import, nothing to
## license, works offline.
##
## Use it from anywhere:
##     ProcAudio.play_footstep(global_position)
##     ProcAudio.play_pickup()
##
## Later (Stage 9) you can keep these or drop real .ogg/.wav files next to
## them - the rest of the game will not need to change.
## =========================================================================

const RATE := 22050          # samples per second of every generated sound
const VOICES_3D := 12        # how many sounds can play at once in 3D

# ---------------------------------------------------------------------------
#  VOLUME MIX  -  every sound effect level, in dB. Negative = quieter.
#  This is the ONE place to change the audio balance. If fights are drowning
#  out the music, lower DB_IMPACT / DB_SWING / DB_WHISPER here.
#
#  NOTE: 3D sounds get an extra -4 dB inside _play_3d(), so the level you
#  actually hear is (these values - 4).
# ---------------------------------------------------------------------------
const DB_FOOTSTEP := 0.0
const DB_LAND := -4.0
const DB_HURT := -6.0
const DB_WHISPER := -12.0    # ghosts whisper constantly - keep it well back
const DB_DOOR := -6.0
const DB_SWING := -8.0
const DB_IMPACT := -7.0
const DB_PICKUP := -6.0
const DB_CLICK := -12.0

var _footsteps: Array[AudioStreamWAV] = []
var _land: AudioStreamWAV
var _hurt: AudioStreamWAV
var _pickup: AudioStreamWAV
var _door: AudioStreamWAV
var _whisper: AudioStreamWAV
var _click: AudioStreamWAV
var _swing: AudioStreamWAV
var _impact: AudioStreamWAV

var _rng := RandomNumberGenerator.new()
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_index := 0
var _player_2d: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_all_sounds()

	_player_2d = AudioStreamPlayer.new()
	_player_2d.volume_db = -6.0
	add_child(_player_2d)

	for i in VOICES_3D:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 45.0
		p.unit_size = 7.0
		p.volume_db = -4.0
		add_child(p)
		_pool.append(p)


# =========================================================================
#  PUBLIC PLAY FUNCTIONS
# =========================================================================
## Every level here is one of the DB_* constants up top, so the whole game's
## audio balance is tunable in a single place.
func play_footstep(pos: Vector3, loud := 0.0) -> void:
	if _footsteps.is_empty():
		return
	_play_3d(_footsteps[randi() % _footsteps.size()], pos, DB_FOOTSTEP + loud, randf_range(0.9, 1.12))


func play_land(pos: Vector3) -> void:
	_play_3d(_land, pos, DB_LAND, randf_range(0.95, 1.05))


func play_hurt(pos: Vector3) -> void:
	_play_3d(_hurt, pos, DB_HURT)


func play_whisper(pos: Vector3) -> void:
	_play_3d(_whisper, pos, DB_WHISPER, randf_range(0.85, 1.15))


func play_door(pos: Vector3) -> void:
	_play_3d(_door, pos, DB_DOOR, randf_range(0.92, 1.08))


## The "whoosh" of a weapon cutting through air.
func play_swing(pos: Vector3) -> void:
	_play_3d(_swing, pos, DB_SWING, randf_range(0.94, 1.1))


## A weapon connecting with something solid (or something dead).
func play_impact(pos: Vector3) -> void:
	_play_3d(_impact, pos, DB_IMPACT, randf_range(0.92, 1.06))


func play_pickup() -> void:
	_play_2d(_pickup, DB_PICKUP)


func play_click() -> void:
	_play_2d(_click, DB_CLICK)


# =========================================================================
#  INTERNAL PLAYBACK
# =========================================================================
func _play_3d(stream: AudioStream, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null or _pool.is_empty():
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.global_position = pos
	p.stream = stream
	p.volume_db = volume_db - 4.0
	p.pitch_scale = pitch
	p.play()


func _play_2d(stream: AudioStream, volume_db := 0.0) -> void:
	if stream == null or _player_2d == null:
		return
	if _player_2d.playing:
		return
	_player_2d.stream = stream
	_player_2d.volume_db = volume_db - 6.0
	_player_2d.play()


# =========================================================================
#  SOUND FACTORY
# =========================================================================
func _build_all_sounds() -> void:
	_footsteps.clear()
	for i in 6:
		_footsteps.append(_make_footstep())
	_land = _make_land()
	_hurt = _make_hurt()
	_pickup = _make_pickup()
	_door = _make_door()
	_whisper = _make_whisper()
	_click = _make_click()
	_swing = _make_swing()
	_impact = _make_impact()


## A short noise "tap" plus a low body thump = a believable footstep.
func _make_footstep() -> AudioStreamWAV:
	var dur := 0.17
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var thud_hz := _rng.randf_range(46.0, 82.0)
	var cutoff := _rng.randf_range(1100.0, 2600.0)
	var a := 1.0 - exp(-TAU * cutoff / float(RATE))
	var lp := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var nt := t / dur
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		var noise_part := lp * 0.85 * exp(-16.0 * nt)
		var body := sin(TAU * thud_hz * t) * 0.75 * exp(-30.0 * nt)
		out[i] = noise_part + body
	return _to_wav(out)


## Heavier version of a footstep, played when you hit the ground.
func _make_land() -> AudioStreamWAV:
	var dur := 0.34
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * 900.0 / float(RATE))
	var lp := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var nt := t / dur
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		var thud := sin(TAU * 44.0 * t) * 1.1 * exp(-13.0 * nt)
		var crack := lp * 1.0 * exp(-26.0 * nt)
		out[i] = thud + crack
	return _to_wav(out)


## Player gets hurt - a distorted downward growl.
func _make_hurt() -> AudioStreamWAV:
	var dur := 0.5
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var nt := t / dur
		var f := 220.0 * (1.0 - 0.6 * nt)
		phase += TAU * f / float(RATE)
		var tone := sin(phase) + 0.5 * sin(phase * 1.98)
		var noise := _rng.randf_range(-1.0, 1.0) * 0.25
		out[i] = (tone * 0.6 + noise) * exp(-4.5 * nt) * 0.9
	return _to_wav(out)


## A soft two-note chime for picking something up.
func _make_pickup() -> AudioStreamWAV:
	var dur := 0.42
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var f := 620.0 if t < 0.14 else 880.0
		phase += TAU * f / float(RATE)
		var env := 1.0 if t < 0.14 else exp(-7.0 * (t - 0.14))
		out[i] = sin(phase) * env * 0.35
	return _to_wav(out)


## A long, slow creak for doors.
func _make_door() -> AudioStreamWAV:
	var dur := 1.1
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var nt := t / dur
		var wobble := 90.0 + 55.0 * sin(TAU * 2.3 * nt) + 30.0 * sin(TAU * 7.1 * nt + 1.0)
		phase += TAU * wobble / float(RATE)
		var saw := fmod(phase, TAU) / PI - 1.0
		var noise := _rng.randf_range(-1.0, 1.0) * 0.12
		var env := sin(PI * nt) * 0.9
		out[i] = (saw * 0.35 + noise) * env
	return _to_wav(out)


## A breathy, wordless whisper.
func _make_whisper() -> AudioStreamWAV:
	var dur := 1.9
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a1 := 1.0 - exp(-TAU * 850.0 / float(RATE))
	var a2 := 1.0 - exp(-TAU * 1900.0 / float(RATE))
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var nt := t / dur
		lp1 += a1 * (_rng.randf_range(-1.0, 1.0) - lp1)
		lp2 += a2 * (lp1 - lp2)
		var breath := lp1 * 0.5 + (lp2 - lp1) * 1.4
		var syllables := 0.5 + 0.5 * sin(TAU * 3.1 * nt + 0.7) * sin(TAU * 0.9 * nt)
		out[i] = breath * sin(PI * nt) * syllables
	return _to_wav(out)


## Tiny UI blip.
func _make_click() -> AudioStreamWAV:
	var dur := 0.07
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := exp(-55.0 * (t / dur))
		out[i] = sin(TAU * 1150.0 * t) * env * 0.5
	return _to_wav(out)


## The "whoosh" of a blade or bat cutting through air: a short filtered
## noise burst whose brightness sweeps upward, then dies.
func _make_swing() -> AudioStreamWAV:
	var dur := 0.30
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var bp := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var nt := t / dur
		# The filter opens up as the swing accelerates.
		var cutoff := 500.0 + 4200.0 * sin(PI * pow(nt, 0.7))
		var a := 1.0 - exp(-TAU * cutoff / float(RATE))
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		bp += a * (lp - bp)
		out[i] = bp * sin(PI * nt) * 1.5
	return _to_wav(out)


## A dull, wet crack for a weapon landing on a ghost.
func _make_impact() -> AudioStreamWAV:
	var dur := 0.28
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var a := 1.0 - exp(-TAU * 1800.0 / float(RATE))
	for i in n:
		var t := float(i) / float(RATE)
		var nt := t / dur
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		var body := sin(TAU * 128.0 * t) * 0.8 * exp(-24.0 * nt)
		var body2 := sin(TAU * 71.0 * t) * 0.6 * exp(-15.0 * nt)
		var crack := lp * 0.9 * exp(-40.0 * nt)
		out[i] = body + body2 + crack
	return _to_wav(out)


## Converts a float array (-1..1) into a real 16 bit mono WAV stream.
func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var count := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		# tanh = gentle soft clipping, so loud samples distort instead of crack.
		var v := int(round(tanh(samples[i] * 1.15) * 32000.0))
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
