extends Area3D
## =========================================================================
## TriggerZone  -  fires a message / whisper once when the player walks in.
## =========================================================================
## Used for "environmental storytelling" and for the Stage 1 goal trigger.
##
## Setup in the Inspector:
##   Collision > Mask  = "player"
## Then add a CollisionShape3D child.
## =========================================================================

@export_multiline var message := ""
@export var message_seconds := 5.0
@export var new_objective := ""
@export var play_whisper := true
@export var once := true

var _fired := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if once and _fired:
		return
	_fired = true
	if message != "":
		GameManager.show_message(message, message_seconds)
	if new_objective != "":
		GameManager.set_objective(new_objective)
	if play_whisper:
		ProcAudio.play_whisper(global_position)
