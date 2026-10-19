extends Interactable
class_name HauntedDoor
## =========================================================================
## HauntedDoor  -  an interactable door that swings open.
## =========================================================================
## Attached to props/door.tscn
##
## The door leaf hangs off the child node "Pivot". The pivot sits at the
## HINGE, so rotating the pivot swings the door like a real one.
##
## Inspector:
##   open_angle      how far it swings (negative = towards the player)
##   swing_speed     degrees per second
##   locked          if true the player cannot open it
##   required_key    name of the key that unlocks it (used in later stages)
## =========================================================================

@export var open_angle := -95.0
@export var swing_speed := 190.0
@export var locked := false
@export var required_key := ""
@export var locked_message := "It will not budge. Something is holding it shut."

var is_open := false
var _angle := 0.0

@onready var _pivot: Node3D = $Pivot


func _ready() -> void:
	super._ready()
	GameManager.key_collected.connect(_on_key_collected)
	# If we already picked the key up earlier in this run, stay unlocked.
	if locked and required_key != "" and GameManager.has_key(required_key):
		locked = false
		required_key = ""


func _on_key_collected(key_id: String, _label: String) -> void:
	if locked and required_key != "" and key_id == required_key:
		unlock(key_id)


func _physics_process(delta: float) -> void:
	var target := deg_to_rad(open_angle) if is_open else 0.0
	if not is_equal_approx(_angle, target):
		_angle = move_toward(_angle, target, deg_to_rad(swing_speed) * delta)
		_pivot.rotation.y = _angle


func get_interact_text() -> String:
	if locked:
		if required_key != "":
			return "LOCKED  -  needs: %s" % required_key
		return "LOCKED"
	return "Close the door" if is_open else "Open the door"


func _on_interact(_player: Node) -> void:
	if locked:
		GameManager.show_message(locked_message, 2.5)
		ProcAudio.play_door(global_position)
		return
	is_open = not is_open
	ProcAudio.play_door(global_position)


## Later stages call this when the player picks up the matching key.
func unlock(key_name: String = "") -> void:
	if key_name != "" and required_key != "" and key_name != required_key:
		return
	locked = false
	required_key = ""
	GameManager.show_message("The lock clicks open.", 2.0)
