extends Node
## =========================================================================
## Music  -  the background music
## =========================================================================
## One looping track playing underneath everything:
##   "Baanali Jaarida" from the film Premada Oorali
##   (vocals: Shreeraam / Thapaswini, music: Sunaad Gowtham).
##
## It is an AUTOLOAD on purpose. That means:
##   * it starts on the main menu and keeps going when you press PLAY
##   * it does NOT restart every time you load a stage, and
##   * it survives the Stage 1 -> Stage 2 transition without a gap.
##
## VOLUME
## The music sits on the Master bus, so the master volume slider in SETTINGS
## already controls it. `MUSIC_DB` below is only the BALANCE between the music
## and the sound effects - turn it down if the music fights the footsteps,
## turn it up if you can barely hear it.
##
## SWAPPING THE SONG
## Drop a new .mp3 / .ogg / .wav into audio/music/ and change MUSIC_PATH.
## Looping is set up automatically, whatever the format.
## =========================================================================

const MUSIC_PATH := "res://audio/music/baanali_jaarida.ogg"

## Balance against the sound effects. 0 dB = as loud as the game, so this is
## deliberately well below it: the track is atmosphere, not a concert.
const MUSIC_DB := -12.0

## Fade in when the game boots, fade out if stop_music() is called.
const FADE_IN_SECONDS := 3.5
const FADE_OUT_SECONDS := 2.0

## Silence, expressed in dB. Quiet enough to be inaudible.
const SILENT_DB := -60.0

var _player: AudioStreamPlayer
var _want := 1.0        ## 1 = should be playing, 0 = should be silent
var _level := 0.0       ## where the fade actually is right now, 0..1
var _loaded := false


func _ready() -> void:
	# ALWAYS, so the music keeps playing while the game is paused. A pause
	# menu with dead silence feels broken.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var stream := load(MUSIC_PATH) as AudioStream
	if stream == null:
		push_warning("Music: could not load %s - the game will run without music." % MUSIC_PATH)
		return

	_make_loop(stream)

	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.stream = stream
	_player.bus = "Master"
	_player.volume_db = SILENT_DB
	add_child(_player)
	_player.play()
	_loaded = true


## Every Godot audio format spells "loop forever" differently.
func _make_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _process(delta: float) -> void:
	if not _loaded:
		return
	var seconds := FADE_IN_SECONDS if _want >= 1.0 else FADE_OUT_SECONDS
	_level = move_toward(_level, _want, delta / maxf(seconds, 0.01))
	# Fade on a dB curve. Fading the raw amplitude sounds like the music
	# vanishing instantly at the end; this fades evenly the whole way down.
	_player.volume_db = MUSIC_DB - (1.0 - _level) * (MUSIC_DB - SILENT_DB)
	if _level <= 0.001 and _player.playing and _want <= 0.0:
		_player.stop()


# =========================================================================
#  PUBLIC
# =========================================================================
func play_music() -> void:
	_want = 1.0
	if _player != null and not _player.playing:
		_player.play()


func stop_music() -> void:
	_want = 0.0


## True while the track is actually audible. Handy for debugging.
func is_playing() -> bool:
	return _loaded and _player != null and _player.playing and _level > 0.01


## Live balance knob: Music.set_volume_db(-22.0) to push it further back.
func set_volume_db(db: float) -> void:
	if _player != null:
		_player.volume_db = db
