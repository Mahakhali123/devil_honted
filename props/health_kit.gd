extends Interactable
class_name HealthKit
## =========================================================================
## HealthKit  -  press E to heal.
## =========================================================================
## Attached to props/health_kit.tscn
## =========================================================================

@export var heal_amount := 35.0
@export var pickup_name := "bandages"


func get_interact_text() -> String:
	return "Take %s  (+%d HP)" % [pickup_name, int(heal_amount)]


func _on_interact(player: Node) -> void:
	if player.has_method("heal"):
		player.heal(heal_amount)
	GameManager.show_message("You bind your wounds.  +%d HP" % int(heal_amount), 2.5)
	ProcAudio.play_pickup()
	hide_and_disable()
