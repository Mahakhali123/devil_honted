extends Area3D
## =========================================================================
## DamageZone  -  anything that hurts the player while they stand in it.
## =========================================================================
## Used in Stage 1 for the "cursed mist" around the old well.
##
## Setup in the Inspector:
##   Collision > Mask  = "player"      (the Area watches for the player)
##   Collision > Layer = nothing       (it does not need a layer)
## Then add a CollisionShape3D child.
## =========================================================================

@export var damage_per_second := 14.0
@export var tick_seconds := 0.5
@export var only_players := true

var _bodies: Array[Node3D] = []
var _timer := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _bodies.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = tick_seconds
	var chunk := damage_per_second * tick_seconds
	for b in _bodies:
		if is_instance_valid(b) and b.has_method("take_damage"):
			b.take_damage(chunk)


func _on_body_entered(body: Node3D) -> void:
	if only_players and not body.is_in_group("player"):
		return
	if not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)
