extends Interactable
class_name WeaponPickup
## =========================================================================
## WeaponPickup  -  a weapon lying in the world, waiting to be picked up
## =========================================================================
## Attached to props/weapon_pickup.tscn.
##
## Set `weapon_id` in the level to one of the ids in WeaponDB:
##   wooden_bat / frying_pan / katana / ghost_lantern / spirit_trap
##
## The floating mesh is built with the SAME factory the first-person viewmodel
## uses (WeaponView.build_weapon_mesh), so the thing you see on the floor is
## exactly the thing you end up holding.
## =========================================================================

@export var weapon_id := "wooden_bat"
@export var is_secret := false


func _ready() -> void:
	super._ready()
	add_to_group("pickup")
	float_and_spin = true
	spin_speed = 1.0
	_build()
	_apply_glow()


func get_interact_text() -> String:
	return "Take the %s" % WeaponDB.display_name(weapon_id)


func _on_interact(player: Node) -> void:
	if player == null or not player.has_method("add_weapon"):
		return
	var ok := bool(player.add_weapon(weapon_id))
	if not ok:
		GameManager.show_message("You already carry a %s." % WeaponDB.display_name(weapon_id), 2.0)
		return
	GameManager.show_message("%s\n%s" % [WeaponDB.display_name(weapon_id), WeaponDB.describe(weapon_id)], 4.5)
	ProcAudio.play_pickup()
	hide_and_disable()


func _build() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return
	for c in model.get_children():
		c.queue_free()
	var mesh := WeaponView.build_weapon_mesh(weapon_id)
	if mesh == null:
		return
	# Stand the weapon upright-ish so it reads clearly on the floor.
	mesh.rotation = Vector3(0.0, 0.0, deg_to_rad(-22.0))
	mesh.scale = Vector3(1.15, 1.15, 1.15)
	model.add_child(mesh)


func _apply_glow() -> void:
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow == null:
		return
	var w := WeaponDB.get_weapon(weapon_id)
	var c: Color = w.get("color", Color(0.9, 0.85, 0.6))
	glow.light_color = c
	glow.light_energy = 0.4 if not is_secret else 0.9
	glow.omni_range = 2.8 if not is_secret else 4.5
