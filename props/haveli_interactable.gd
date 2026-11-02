extends Interactable
class_name HaveliInteractable
## =========================================================================
## HaveliInteractable  -  a lightweight interaction point for the Haveli.
## =========================================================================
## The palace builds most of its shrines, altars and ritual stations from
## code. This class lets the level attach a prompt and a callback to a
## collision box without creating a new scene for every prop.
##
## prompt_provider is optional. If set, it is called for the current prompt,
## which lets a station change its text as its state changes.
## =========================================================================

signal used(player: Node)

var enabled := true
var prompt_provider: Callable = Callable()


func _ready() -> void:
	super._ready()
	# Interaction boxes live on the interactable layer. Set collision_layer
	# to 9 at the call site when the prop must also be solid.
	collision_mask = 0


func get_interact_text() -> String:
	if not enabled:
		return ""
	if prompt_provider.is_valid():
		return String(prompt_provider.call())
	return prompt_text


func can_interact() -> bool:
	return enabled and super.can_interact()


func _on_interact(player: Node) -> void:
	used.emit(player)
