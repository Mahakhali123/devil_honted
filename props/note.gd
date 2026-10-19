extends Interactable
class_name ClueNote
## =========================================================================
## ClueNote  -  a readable page. Reading it can advance the objective.
## =========================================================================
## Attached to props/note.tscn. Set the text per note in the level.
## =========================================================================

@export var clue_id := "note_1"
@export_multiline var text := "The ink has run, but the words are still readable."
@export var objective_after := ""
@export var read_message_line := "Read a torn page"


func _ready() -> void:
	one_shot = true


func get_interact_text() -> String:
	return "Read the page"


func _on_interact(_player: Node) -> void:
	GameManager.show_message(text, 8.0)
	GameManager.find_clue(clue_id)
	if objective_after != "":
		GameManager.set_objective(objective_after)
	ProcAudio.play_pickup()
	_consume()


func _consume() -> void:
	visible = false
	for c in find_children("*", "CollisionShape3D", true, false):
		(c as CollisionShape3D).set_deferred("disabled", true)
