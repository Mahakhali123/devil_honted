extends CharacterBody3D
class_name PlayerController
## =========================================================================
## PLAYER  -  first person controller
## =========================================================================
## Attach this script to the root node of  player/player.tscn
##
## Controls (registered automatically in GameManager):
##   W A S D ................ walk
##   SHIFT .................. run
##   CTRL ................... crouch
##   SPACE .................. jump
##   MOUSE .................. look
##   LEFT CLICK ............. swing the equipped weapon
##   E ...................... interact / open doors / read notes
##   F ...................... torch (flashlight) on / off
##   ESC .................... pause
##   F3 ..................... debug info
## =========================================================================

@export_group("Movement")
@export var walk_speed := 3.6
@export var sprint_speed := 6.4
@export var crouch_speed := 1.7
@export var ground_accel := 26.0
@export var air_accel := 5.0
@export var jump_velocity := 6.2
@export var gravity_scale := 1.0
@export var coyote_time := 0.12

@export_group("Look")
@export var max_look_angle_deg := 88.0

@export_group("Stance")
@export var stand_height := 1.8
@export var crouch_height := 1.0
@export var stand_cam_y := 1.58
@export var crouch_cam_y := 0.92

@export_group("Head bob")
@export var bob_speed := 9.0
@export var bob_amplitude := 0.045

@export_group("Health")
@export var max_health := 100.0
@export var invulnerable_time := 0.25

@export_group("Interaction")
@export var interact_distance := 2.6

@export_group("Combat")
## Radius of the sphere the melee sweep uses - roughly the width of a swing.
@export var melee_sweep_radius := 0.55
## Hard cap on how many ghosts a single swing can connect with.
@export var max_melee_targets := 6

# --- node shortcuts -------------------------------------------------------
@onready var _col: CollisionShape3D = $CollisionShape3D
@onready var _head: Node3D = $HeadPivot
@onready var _cam: Camera3D = $HeadPivot/Camera3D
@onready var _ray: RayCast3D = $HeadPivot/Camera3D/InteractRay
@onready var _head_room: RayCast3D = $HeadCheck

# --- runtime state --------------------------------------------------------
var health := 100.0
var _dead := false
var _pitch := 0.0
var _cam_y := 1.58
var _bob_time := 0.0
var _is_crouching := false
var _step_accum := 0.0
var _coyote := 0.0
var _hurt_sound_cd := 0.0
var _invuln := 0.0
var _trauma := 0.0
var _current_target: Node = null
var _gravity := 18.0

# --- combat state ---------------------------------------------------------
signal weapon_switched(weapon_id: String)
signal struck_enemy(ghost_name: String, damage: float)

## Everything the player is carrying. Slot 0 is always something usable.
var weapons: Array[String] = ["fists"]
var weapon_index := 0

var _weapon_view: WeaponView
var _attack_cd := 0.0
var _pending_swing: Dictionary = {}
var _pending_time := 0.0
var _swing_flash := 0.0


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	health = max_health
	_cam_y = stand_cam_y
	if _ray != null:
		_ray.target_position = Vector3(0.0, 0.0, -interact_distance)
	# Report to the HUD.
	GameManager.report_health(health, max_health)

	# Build the first-person weapon on the camera.
	weapons.clear()
	for id in WeaponDB.STARTING_WEAPONS:
		weapons.append(String(id))
	weapon_index = 0
	_weapon_view = WeaponView.new()
	_weapon_view.name = "WeaponView"
	_cam.add_child(_weapon_view)
	_equip_refresh()

	if GameManager.current_level_id != "" and not GameManager.is_paused and not GameManager.player_is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	GameManager.set_interact_prompt("")
	if is_instance_valid(_current_target):
		_current_target = null


# =========================================================================
#  INPUT
# =========================================================================
func _unhandled_input(event: InputEvent) -> void:
	if _dead or GameManager.is_paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens: float = GameManager.mouse_sensitivity
		rotate_y(-motion.relative.x * sens)
		var dy := motion.relative.y * sens
		if GameManager.invert_mouse_y:
			dy = -dy
		_pitch = clampf(_pitch - dy, deg_to_rad(-max_look_angle_deg), deg_to_rad(max_look_angle_deg))
		_head.rotation.x = _pitch

	# Mouse wheel cycles weapons.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_weapon(1)
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_weapon(-1)
				return

	# Number keys jump straight to a weapon slot.
	for i in WeaponDB.SLOT_ORDER.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			_equip_slot(i)
			return


# =========================================================================
#  PHYSICS
# =========================================================================
func _physics_process(delta: float) -> void:
	if _dead:
		_trauma = maxf(0.0, _trauma - delta * 1.6)
		return
	if GameManager.is_paused:
		return

	_invuln = maxf(0.0, _invuln - delta)
	_hurt_sound_cd = maxf(0.0, _hurt_sound_cd - delta)

	_update_stance(delta)
	_apply_gravity(delta)
	_update_horizontal(delta)
	_update_jump(delta)

	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()

	if not was_on_floor and is_on_floor() and fall_speed < -5.0:
		ProcAudio.play_land(global_position)

	_update_footsteps(delta)
	_update_combat(delta)
	_update_interaction()
	_update_camera_effects(delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_coyote = coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)
		velocity.y -= _gravity * gravity_scale * delta


func _update_horizontal(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	dir = dir.normalized()

	var speed := _current_speed()
	var target := dir * speed
	var accel := ground_accel if is_on_floor() else air_accel
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)


func _update_jump(_delta: float) -> void:
	if _is_crouching:
		return
	if Input.is_action_just_pressed("jump") and (is_on_floor() or _coyote > 0.0):
		velocity.y = jump_velocity
		_coyote = 0.0
		ProcAudio.play_footstep(global_position, 0.0)


func _current_speed() -> float:
	if _is_crouching:
		return crouch_speed
	if Input.is_action_pressed("sprint") and not Input.is_action_pressed("move_back"):
		return sprint_speed
	return walk_speed


# =========================================================================
#  STANCE / CROUCH
# =========================================================================
func _update_stance(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch")
	if not wants_crouch and _is_crouching and _blocked_above():
		wants_crouch = true      # something is over our head - stay crouched
	_is_crouching = wants_crouch

	var ch := crouch_height if _is_crouching else stand_height
	var capsule := _col.shape as CapsuleShape3D
	if capsule != null and not is_equal_approx(capsule.height, ch):
		capsule.height = ch
		_col.position.y = ch * 0.5

	var target_cam := crouch_cam_y if _is_crouching else stand_cam_y
	_cam_y = lerpf(_cam_y, target_cam, 1.0 - exp(-13.0 * delta))


func _blocked_above() -> bool:
	if _head_room == null:
		return false
	_head_room.force_raycast_update()
	return _head_room.is_colliding()


# =========================================================================
#  FOOTSTEPS
# =========================================================================
func _update_footsteps(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and flat > 0.8:
		var stride := clampf(flat * 0.45, 0.9, 2.6)
		_step_accum += flat * delta
		if _step_accum >= stride:
			_step_accum = 0.0
			ProcAudio.play_footstep(global_position, -6.0 if _is_crouching else 0.0)
	else:
		_step_accum = 0.0


# =========================================================================
#  CAMERA (head bob + shake)
# =========================================================================
func _update_camera_effects(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z).length()
	var speed_factor := clampf(flat / maxf(walk_speed, 0.001), 0.0, 1.6)
	if is_on_floor():
		_bob_time += delta * bob_speed * speed_factor
	var bob_y := sin(_bob_time * 2.0) * bob_amplitude * speed_factor
	var bob_x := sin(_bob_time) * bob_amplitude * 0.6 * speed_factor

	_trauma = maxf(0.0, _trauma - delta * 1.6)
	var shake := _trauma * _trauma
	var shake_x := sin(_bob_time * 31.0) * 0.04 * shake
	var shake_y := sin(_bob_time * 27.0 + 1.3) * 0.04 * shake

	_head.position.y = _cam_y + bob_y + shake_y
	_cam.position = Vector3(bob_x + shake_x, 0.0, 0.0)
	_cam.rotation.z = shake_x * 0.8
	_cam.fov = lerpf(_cam.fov, GameManager.field_of_view + (4.0 if _is_crouching == false and flat > walk_speed + 0.6 else 0.0), 1.0 - exp(-6.0 * delta))


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


# =========================================================================
#  INTERACTION
# =========================================================================
func _update_interaction() -> void:
	if _ray == null:
		return
	_ray.force_raycast_update()
	var found: Node = null
	if _ray.is_colliding():
		var hit := _ray.get_collider()
		if hit != null and hit.has_method("interact") and hit.has_method("get_interact_text"):
			if not hit.has_method("can_interact") or hit.can_interact():
				found = hit
	if found != _current_target:
		_current_target = found
		GameManager.set_interact_prompt(_current_target.get_interact_text() if _current_target != null else "")

	if _current_target != null and Input.is_action_just_pressed("interact"):
		_current_target.interact(self)
		# The prompt may change (door opened / note read) - refresh it.
		if is_instance_valid(_current_target) and _current_target.has_method("can_interact") and not _current_target.can_interact():
			_current_target = null
			GameManager.set_interact_prompt("")


# =========================================================================
#  HEALTH
# =========================================================================
func take_damage(amount: float, _source: Node3D = null) -> void:
	if _dead or amount <= 0.0 or _invuln > 0.0:
		return
	health = maxf(0.0, health - amount)
	GameManager.report_health(health, max_health)
	GameManager.report_damage(amount)
	add_trauma(clampf(amount * 0.04, 0.15, 0.8))
	if _hurt_sound_cd <= 0.0:
		_hurt_sound_cd = 0.4
		ProcAudio.play_hurt(global_position)
	if amount >= 5.0:
		_invuln = invulnerable_time
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if _dead:
		return
	health = minf(max_health, health + amount)
	GameManager.report_health(health, max_health)


func is_dead() -> bool:
	return _dead


func is_crouching() -> bool:
	return _is_crouching


func _die() -> void:
	_dead = true
	health = 0.0
	velocity = Vector3.ZERO
	GameManager.set_interact_prompt("")
	GameManager.report_player_death()
	# Simple "collapse" animation.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_head, "position:y", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_cam, "rotation:z", deg_to_rad(75.0), 1.1).set_trans(Tween.TRANS_SINE)


# =========================================================================
#  COMBAT
# =========================================================================
## Runs every physics frame: ticks the cooldown, sways the viewmodel, and
## fires the swing when you click. The actual damage happens a moment later,
## on the frame the swing animation reaches its impact point.
func _update_combat(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_swing_flash = maxf(0.0, _swing_flash - delta)

	if _weapon_view != null:
		_weapon_view.motion = clampf(Vector2(velocity.x, velocity.z).length() / maxf(sprint_speed, 0.001), 0.0, 1.2)

	if not _pending_swing.is_empty():
		_pending_time -= delta
		if _pending_time <= 0.0:
			var w := _pending_swing
			_pending_swing = {}
			_apply_melee(w)

	if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
		_swing()


func current_weapon_id() -> String:
	if weapons.is_empty():
		return "fists"
	return weapons[clampi(weapon_index, 0, weapons.size() - 1)]


func current_weapon() -> Dictionary:
	return WeaponDB.get_weapon(current_weapon_id())


## Called by props/weapon_pickup.gd when you walk over a weapon.
func add_weapon(id: String) -> bool:
	if not WeaponDB.has_weapon(id) or weapons.has(id):
		return false
	weapons.append(id)
	weapon_index = weapons.size() - 1
	_equip_refresh()
	return true


func has_weapon(id: String) -> bool:
	return weapons.has(id)


func _cycle_weapon(step: int) -> void:
	if weapons.size() <= 1:
		return
	weapon_index = wrapi(weapon_index + step, 0, weapons.size())
	_equip_refresh()
	ProcAudio.play_click()


func _equip_slot(slot: int) -> void:
	if slot < 0 or slot >= WeaponDB.SLOT_ORDER.size():
		return
	var id: String = WeaponDB.SLOT_ORDER[slot]
	var idx := weapons.find(id)
	if idx < 0:
		if id != "fists":
			GameManager.show_message("You are not carrying a %s." % WeaponDB.display_name(id), 1.6)
		return
	if idx == weapon_index:
		return
	weapon_index = idx
	_equip_refresh()
	ProcAudio.play_click()


func _equip_refresh() -> void:
	var id := current_weapon_id()
	if _weapon_view != null:
		_weapon_view.set_weapon(id)
		_weapon_view.play_swing(0.22)
	weapon_switched.emit(id)
	GameManager.report_weapons(weapons, weapon_index)


func _swing() -> void:
	var w := current_weapon()
	var cooldown := float(w.get("cooldown", 0.5))
	_attack_cd = cooldown
	var dur := cooldown * 0.85
	if _weapon_view != null:
		_weapon_view.play_swing(dur)
	ProcAudio.play_swing(global_position)
	add_trauma(0.05)
	# Damage lands partway through the animation so the hit reads visually.
	_pending_swing = w
	_pending_time = clampf(float(w.get("windup", 0.15)) * dur, 0.02, 0.45)


## The melee "sweep": a sphere placed in front of the camera, then a range and
## angle test per candidate, then a wall check so you cannot hit through walls.
func _apply_melee(w: Dictionary) -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return

	var origin := _cam.global_position
	var dir := -_cam.global_transform.basis.z
	dir = dir.normalized()
	var reach := float(w.get("range", 2.0))
	var half_arc := deg_to_rad(float(w.get("arc", 70.0)) * 0.5)

	var sphere := SphereShape3D.new()
	sphere.radius = melee_sweep_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis(), origin + dir * maxf(reach * 0.5, 0.3))
	params.collision_mask = 4          # physics layer 3 = "enemy"
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var hits := space.intersect_shape(params, maxi(1, max_melee_targets))
	var connected := false
	for h in hits:
		var node: Variant = h.get("collider")
		if not (node is EnemyGhost):
			continue
		var ghost := node as EnemyGhost
		if not ghost.is_alive():
			continue
		var chest: Vector3 = ghost.global_position + Vector3(0.0, 0.95, 0.0)
		var to_ghost := chest - origin
		if to_ghost.length() > reach + melee_sweep_radius + 0.3:
			continue
		if dir.angle_to(to_ghost.normalized()) > half_arc + 0.30:
			continue
		if not _strike_is_clear(space, origin, chest, ghost):
			continue

		var dmg := float(w.get("damage", 5.0)) * float(w.get("ghost_bonus", 1.0))
		ghost.take_damage(dmg, self, float(w.get("stun", 0.0)), float(w.get("knockback", 0.0)))
		struck_enemy.emit(ghost.display_name, dmg)
		GameManager.report_hit(ghost.display_name, dmg)
		connected = true

	if connected:
		add_trauma(0.12)
		_swing_flash = 0.25
		ProcAudio.play_impact(global_position)


## True when nothing solid (walls, floors) sits between the camera and the
## ghost's chest. Without this you could kill ghosts through a wall.
func _strike_is_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, ghost: EnemyGhost) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1               # physics layer 1 = "world"
	q.exclude = [get_rid(), ghost.get_rid()]
	return space.intersect_ray(q).is_empty()
