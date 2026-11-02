extends Interactable
## RadioInteractable  -  turns off the radio when pressed E
## Attached to a radio interactable node in the home scene
## 
## When the player presses E on this radio, the AudioStreamPlayer3D
## named "Radio" in the scene will stop playing.

func _ready() -> void:
	# Find the Radio AudioStreamPlayer3D in the parent Room node
	var room = get_parent() as Node3D
	if room != null:
		radio_player = room.get_node("Radio") as AudioStreamPlayer3D
	prompt_text = "Press E to turn off radio"

func _on_interact(_player: Node) -> void:
	# Stop the radio sound when interacted with
	if radio_player != null and radio_player.is_playing():
		radio_player.stop()
		prompt_text = "Radio turned off"

var radio_player: AudioStreamPlayer3D