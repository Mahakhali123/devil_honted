extends StaticBody3D
class_name Interactable
## =========================================================================
## Interactable  -  BASE CLASS for everything you can look at and press E.
## =========================================================================
## The Player raycasts forward. If the thing it hits:
##   * has a method called "interact"
##   * has a method called "get_interact_text"
## then the prompt appears and E calls interact().
##
## To make your own interactable, create a script that does:
##     extends Interactable
##     func get_interact_text() -> String: return "Open the chest"
##     func _on_interact(player: Node) -> void: ...
##
## IMPORTANT: set the node's Collision Layer to both "world" and
## "interactable" so the player ray can see it AND the player collides.
## =========================================================================

@export var prompt_text := "Press E to interact"
@export var one_shot := false

## If true, the child node named "Model" slowly turns and bobs up and down.
## That makes pickups readable in a dark level.
@export var float_and_spin := false
@export var spin_speed := 0.9
@export var bob_height := 0.06

var _used := false
var _bob_t := 0.0
var _base_model_y := 0.0
var _model: Node3D


func _ready() -> void:
	_model = get_node_or_null("Model") as Node3D
	if _model != null:
		_base_model_y = _model.position.y


func _process(delta: float) -> void:
	if not float_and_spin or _model == null:
		return
	_bob_t += delta
	_model.rotation.y += spin_speed * delta
	_model.position.y = _base_model_y + sin(_bob_t * 1.6) * bob_height


func get_interact_text() -> String:
	return prompt_text


func can_interact() -> bool:
	return not (one_shot and _used)


func interact(player: Node) -> void:
	if not can_interact():
		return
	_used = true
	_on_interact(player)


## Override this in your own script.
func _on_interact(_player: Node) -> void:
	pass


## Hides the prop and switches off every collision shape under it.
## Call this after a pickup is consumed.
func hide_and_disable() -> void:
	visible = false
	for c in find_children("*", "CollisionShape3D", true, false):
		(c as CollisionShape3D).set_deferred("disabled", true)
