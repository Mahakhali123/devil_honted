extends CharacterBody3D
class_name EnemyGhost
## =========================================================================
## EnemyGhost  -  the haunted character controller + AI state machine
## =========================================================================
## Attached to enemies/enemy_ghost.tscn
##
## Drop this scene into a level, then in the Inspector pick the ghost:
##   rig_body = GHOST_KING / GHOST_QUEEN / SOLDIER_MALE / SOLDIER_FEMALE
## Everything else (look, height, sounds, animations) follows automatically.
##
## STATE MACHINE
##   DORMANT  -> asleep until you touch it or wake() is called
##   PATROL   -> wanders inside roam_radius of where it spawned
##   ALERT    -> spotted you, turns to face you, brief pause (your chance to hide)
##   CHASE    -> walks straight at you
##   ATTACK   -> winds up, strikes, cools down, repeats
##   STAGGER  -> was hit, reels for a moment
##   BANISHED -> health hit zero, fades away
##
## NOTE: this uses direct steering + move_and_slide, not NavigationAgent3D.
## Stage 3 replaces the steering with a baked navigation mesh so ghosts path
## around walls instead of sliding along them.
## =========================================================================

signal died(ghost_name: String)
signal state_changed(new_state: int)

enum State { DORMANT, PATROL, ALERT, CHASE, ATTACK, STAGGER, BANISHED }

const STATE_NAMES := ["DORMANT", "PATROL", "ALERT", "CHASE", "ATTACK", "STAGGER", "BANISHED"]
const BAR_WIDTH := 0.9
const BAR_HEIGHT := 0.08

@export_group("Identity")
## Pick the character. Difficulty follows automatically (see GhostDB):
##   SOLDIER_FEMALE = easiest, SOLDIER_MALE = easy,
##   GHOST_QUEEN = hard,      GHOST_KING   = hardest
@export var rig_body: GhostRig.Body = GhostRig.Body.SOLDIER_MALE
## Leave empty to use the character's story name from GhostDB.
@export var display_name := ""
## Optional: a unique id for this individual ghost. When set, the level adds a
## line to the HUD task list and ticks it off when this ghost is banished.
@export var quest_id := ""
@export_range(0.15, 1.0, 0.01) var spectral_alpha := 0.93

@export_group("Difficulty")
## ON  = pull health / speed / damage from the GhostDB difficulty ladder.
## OFF = use the numbers you typed in the groups below.
@export var use_difficulty_preset := true
@export var start_dormant := false
## Fraction of incoming damage ignored (0 = fragile, 0.5 = very tanky).
@export_range(0.0, 0.8, 0.01) var damage_resist := 0.0

@export_group("Movement")
@export var roam_radius := 10.0
@export var roam_speed := 1.4
@export var chase_speed := 3.4
@export var turn_speed := 5.5
@export var gravity_scale := 1.0

@export_group("Senses")
@export var detect_radius := 9.0
@export var crouch_detect_multiplier := 0.55
@export var lose_radius := 16.0
@export var require_line_of_sight := true
@export var eye_height := 1.5
@export var alert_duration := 0.7

@export_group("Combat")
@export var can_attack := true
@export var attack_range := 2.0
@export var attack_damage := 10.0
@export var attack_windup := 0.5
@export var attack_cooldown := 2.2
@export var stagger_time := 0.5
## Multiplies how long this ghost reels when you hit it. Low = hard to stun.
@export var stun_scale := 1.0
@export var max_health := 100.0

@export_group("Special")
@export var can_teleport := false
@export var teleport_cooldown := 10.0
@export var teleport_min_distance := 7.0

const PUSH_DECAY := 7.0

# --- runtime --------------------------------------------------------------
var health := 100.0
var state: State = State.PATROL

var _rig: GhostRig
var _player: PlayerController
var _home := Vector3.ZERO
var _roam_target := Vector3.ZERO
var _wait_timer := 0.0
var _alert_timer := 0.0
var _attack_timer := 0.0
var _struck := false
var _stagger_timer := 0.0
var _teleport_timer := 0.0
var _gravity := 18.0
var _push := Vector3.ZERO
var _bar_root: Node3D
var _bar_fill: MeshInstance3D


# =========================================================================
#  DIFFICULTY LADDER
# =========================================================================
## Copies the GhostDB profile for this character onto the exported stats.
## Called once, at the very start of _ready(), so a .tscn that only sets
## `rig_body` still ends up with the right health / speed / damage.
func _apply_profile() -> void:
	if not use_difficulty_preset:
		return
	var p := GhostDB.get_profile(rig_body)
	if display_name == "":
		display_name = String(p.get("name", "Ghost"))
	max_health = float(p.get("health", 100.0))
	damage_resist = float(p.get("damage_resist", 0.0))
	roam_speed = float(p.get("roam_speed", 1.4))
	chase_speed = float(p.get("chase_speed", 3.4))
	attack_damage = float(p.get("damage", 10.0))
	attack_range = float(p.get("attack_range", 2.0))
	attack_windup = float(p.get("attack_windup", 0.5))
	attack_cooldown = float(p.get("attack_cooldown", 2.2))
	detect_radius = float(p.get("detect_radius", 9.0))
	lose_radius = float(p.get("lose_radius", 16.0))
	can_teleport = bool(p.get("teleport", false))
	teleport_cooldown = float(p.get("teleport_cooldown", 10.0))
	stun_scale = float(p.get("stun_scale", 1.0))
	if display_name == "":
		display_name = "Ghost"


func difficulty_tag() -> String:
	return GhostDB.difficulty_tag(rig_body)


func _ready() -> void:
	_apply_profile()
	add_to_group("enemy")
	add_to_group("ghost")
	health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_home = global_position
	_roam_target = _home
	_teleport_timer = teleport_cooldown

	_rig = get_node_or_null("Rig") as GhostRig
	if _rig != null:
		_rig.body = rig_body
		_rig.spectral_alpha = spectral_alpha
		_rig.anim_phase = randf() * 10.0
		_rig.anim_speed = 1.0

	_build_health_bar()
	_pick_roam_target()
	state = State.DORMANT if start_dormant else State.PATROL


func _physics_process(delta: float) -> void:
	if state == State.BANISHED:
		return

	_find_player()
	_apply_gravity(delta)
	_wait_timer = maxf(0.0, _wait_timer - delta)
	_alert_timer = maxf(0.0, _alert_timer - delta)
	_teleport_timer = maxf(0.0, _teleport_timer - delta)

	# Sensing only happens when the ghost is NOT already hunting you.
	if state == State.DORMANT:
		pass
	elif state == State.PATROL and _can_sense():
		_enter_alert()
	elif state == State.STAGGER:
		pass
	elif state == State.ALERT and not _can_sense():
		_set_state(State.PATROL)

	match state:
		State.DORMANT:
			_stop()
		State.PATROL:
			_tick_patrol(delta)
		State.ALERT:
			_tick_alert(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.STAGGER:
			_tick_stagger(delta)
		State.BANISHED:
			pass

	# Knockback from a weapon hit decays over a few frames so a shove does not
	# turn into permanent sliding.
	if _push.length_squared() > 0.0001:
		velocity.x += _push.x
		velocity.z += _push.z
		_push = _push.move_toward(Vector3.ZERO, PUSH_DECAY * delta)

	move_and_slide()
	_update_health_bar()
	_update_rig()


# =========================================================================
#  STATES
# =========================================================================
func _tick_patrol(delta: float) -> void:
	if _wait_timer > 0.0:
		_stop()
		return
	var flat := Vector2(global_position.x - _roam_target.x, global_position.z - _roam_target.z).length()
	if flat < 0.8 or is_on_wall():
		_wait_timer = randf_range(1.2, 3.5)
		_pick_roam_target()
		return
	_steer_to(_roam_target, roam_speed, delta)


func _tick_alert(delta: float) -> void:
	_stop()
	if _player == null:
		_set_state(State.PATROL)
		return
	var to := _player.global_position - global_position
	to.y = 0.0
	_face(to.normalized(), delta)
	if _alert_timer <= 0.0:
		_set_state(State.CHASE)


func _tick_chase(delta: float) -> void:
	if _player == null or _player.is_dead():
		_set_state(State.PATROL)
		_pick_roam_target()
		return
	# Under the netted palang the player is out of reach. Kamla loses the
	# thread and drifts away - even when she is standing at the bedside.
	if GameManager.player_hidden:
		_set_state(State.PATROL)
		_pick_roam_target()
		return
	var dist := global_position.distance_to(_player.global_position)

	if dist > lose_radius:
		_set_state(State.PATROL)
		_pick_roam_target()
		return

	if dist <= attack_range and can_attack:
		_enter_attack()
		return

	# Signature horror moment: the Queen and King blink closer.
	if can_teleport and _teleport_timer <= 0.0 and dist > teleport_min_distance:
		if _try_teleport():
			_teleport_timer = teleport_cooldown
			return

	_steer_to(_player.global_position, chase_speed, delta)


func _enter_attack() -> void:
	_set_state(State.ATTACK)
	_attack_timer = attack_windup
	_struck = false
	ProcAudio.play_whisper(global_position)


func _tick_attack(delta: float) -> void:
	_stop()
	if GameManager.player_hidden:
		_set_state(State.PATROL)
		_pick_roam_target()
		return
	if _player != null:
		var to := _player.global_position - global_position
		to.y = 0.0
		_face(to.normalized(), delta)

	_attack_timer -= delta
	if not _struck:
		if _attack_timer <= 0.0:
			_struck = true
			_strike()
			_attack_timer = attack_cooldown
	else:
		if _attack_timer <= 0.0:
			var still_close := _player != null and global_position.distance_to(_player.global_position) <= attack_range + 0.6
			if still_close:
				_enter_attack()
			elif _player != null:
				_set_state(State.CHASE)
			else:
				_set_state(State.PATROL)


func _strike() -> void:
	if _player == null or GameManager.player_hidden:
		return
	if global_position.distance_to(_player.global_position) <= attack_range + 1.0:
		_player.take_damage(attack_damage, self)


func _tick_stagger(delta: float) -> void:
	_stop()
	_stagger_timer -= delta
	if _stagger_timer <= 0.0:
		_set_state(State.CHASE if _player != null else State.PATROL)


func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)
	if s == State.CHASE:
		ProcAudio.play_whisper(global_position)


# =========================================================================
#  MOVEMENT HELPERS
# =========================================================================
func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * gravity_scale * delta


func _steer_to(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.05:
		_stop()
		return
	var dir := to / dist
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(dir, delta)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	# The rig's face points along its LOCAL +Z, so this is the angle we need.
	var yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-turn_speed * delta))


func _pick_roam_target() -> void:
	for i in 14:
		var a := randf() * TAU
		var r := randf_range(2.0, roam_radius)
		var candidate := _home + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if _is_point_walkable(candidate):
			_roam_target = candidate
			return
	_roam_target = _home


func _is_point_walkable(p: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.5, 0.0), p - Vector3(0.0, 3.5, 0.0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var n: Vector3 = hit["normal"]
	return n.angle_to(Vector3.UP) < deg_to_rad(38.0)


func _has_line_of_sight() -> bool:
	if _player == null:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from := global_position + Vector3(0.0, eye_height, 0.0)
	var to := _player.global_position + Vector3(0.0, 1.2, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var n := get_tree().get_first_node_in_group("player")
	if n is PlayerController:
		_player = n as PlayerController
	elif n != null and n.has_method("is_dead"):
		_player = n as PlayerController


## Spotted you: freeze, turn to stare at you, then commit to the hunt.
## That pause is your one chance to break line of sight.
func _enter_alert() -> void:
	_set_state(State.ALERT)
	_alert_timer = alert_duration
	ProcAudio.play_whisper(global_position)


func _can_sense() -> bool:
	if _player == null or _player.is_dead() or GameManager.player_hidden:
		return false
	var dist := global_position.distance_to(_player.global_position)
	var effective := detect_radius
	if _player.is_crouching():
		effective *= crouch_detect_multiplier
	if dist > effective:
		return false
	if not require_line_of_sight:
		return true
	return _has_line_of_sight()


func _try_teleport() -> bool:
	if _player == null:
		return false
	for i in 10:
		var a := randf() * TAU
		var p := _player.global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(3.0, 5.0)
		if not _is_point_walkable(p):
			continue
		global_position = p + Vector3(0.0, 0.15, 0.0)
		velocity = Vector3.ZERO
		ProcAudio.play_whisper(global_position)
		return true
	return false


# =========================================================================
#  RIG DRIVING
# =========================================================================
func _update_rig() -> void:
	if _rig == null:
		return
	match state:
		State.ATTACK:
			_rig.pose = "attack"
			_rig.anim_speed = 1.0
		State.BANISHED:
			_rig.pose = "summon"
			_rig.anim_speed = 0.7
		State.STAGGER, State.DORMANT:
			_rig.pose = "idle"
			_rig.anim_speed = 1.0
		_:
			var speed := Vector2(velocity.x, velocity.z).length()
			_rig.pose = "walk" if speed > 0.35 else "idle"
			_rig.anim_speed = clampf(speed / 1.7, 0.55, 2.0)


# =========================================================================
#  HEALTH BAR
# =========================================================================
func _build_health_bar() -> void:
	var rig_h := 1.85
	if _rig != null:
		rig_h = _rig.height if _rig.height > 0.01 else float(GhostRig.DEFAULT_HEIGHTS.get(rig_body, 1.8))

	_bar_root = Node3D.new()
	_bar_root.name = "HealthBar"
	_bar_root.position = Vector3(0.0, rig_h + 0.34, 0.0)
	_bar_root.visible = false
	add_child(_bar_root)

	_bar_root.add_child(_make_bar_quad(
		Vector2(BAR_WIDTH + 0.035, BAR_HEIGHT + 0.035), Color(0.03, 0.01, 0.01, 0.8)))

	_bar_fill = _make_bar_quad(Vector2(BAR_WIDTH, BAR_HEIGHT), Color(0.74, 0.06, 0.06, 0.95))
	_bar_root.add_child(_bar_fill)


func _make_bar_quad(size: Vector2, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.disable_receive_shadows = true

	var qm := QuadMesh.new()
	qm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _update_health_bar() -> void:
	if _bar_root == null:
		return
	var r := clampf(health / maxf(max_health, 0.001), 0.0, 1.0)
	_bar_root.visible = state != State.BANISHED and r < 0.999
	if _bar_fill != null:
		_bar_fill.scale.x = maxf(0.001, r)
		_bar_fill.position.x = -(1.0 - r) * BAR_WIDTH * 0.5


# =========================================================================
#  PUBLIC API  (Stage 4 weapons call take_damage)
# =========================================================================
## Cremation ash or a temple bell can blind the dead for a few seconds.
## The ghost keeps its current position but loses the player completely.
func blind(duration: float) -> void:
	if state == State.BANISHED or state == State.DORMANT:
		return
	_stagger_timer = maxf(_stagger_timer, duration)
	_set_state(State.STAGGER)


func take_damage(amount: float, _source: Node3D = null, stun := 0.0, knockback := 0.0) -> void:
	if state == State.BANISHED or amount <= 0.0:
		return

	# Armour: the King shrugs off a quarter of everything you throw at him.
	var dealt := maxf(1.0, amount * (1.0 - clampf(damage_resist, 0.0, 0.8)))
	health = maxf(0.0, health - dealt)
	_update_health_bar()

	# Whoever hit us is now the target, even if we never saw them coming.
	if _source is PlayerController:
		_player = _source as PlayerController

	if knockback > 0.0 and _source != null:
		var away := global_position - _source.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_push += away.normalized() * knockback

	if health <= 0.0:
		banish()
		return

	# Stagger length = the ghost's own toughness * the weapon's stun power.
	_stagger_timer = maxf(0.12, stagger_time * stun_scale + stun)
	_set_state(State.STAGGER)
	ProcAudio.play_whisper(global_position)


func last_hit_was_lethal() -> bool:
	return health <= 0.0


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	_update_health_bar()


func banish() -> void:
	if state == State.BANISHED:
		return
	_set_state(State.BANISHED)
	velocity = Vector3.ZERO
	health = 0.0
	if _bar_root != null:
		_bar_root.visible = false
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		col.set_deferred("disabled", true)
	ProcAudio.play_whisper(global_position)
	GameManager.report_ghost_banished(display_name, rig_body, quest_id)
	died.emit(display_name)

	if _rig != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_rig, "spectral_alpha", 0.0, 1.3)
		tw.tween_property(_rig, "position:y", 1.0, 1.3)
		get_tree().create_timer(1.6).timeout.connect(queue_free)
	else:
		queue_free()


## The ritual uses this to call Kamla to the circle. Once provoked she treats
## the player as her target and hunts without needing to see them first.
func provoke(target: PlayerController = null) -> void:
	if target != null:
		_player = target
	if state == State.BANISHED:
		return
	if state == State.DORMANT:
		wake()
	_set_state(State.CHASE)


func wake() -> void:
	if state == State.DORMANT:
		_set_state(State.PATROL)


func sleep_ghost() -> void:
	if state != State.BANISHED:
		_set_state(State.DORMANT)


func is_alive() -> bool:
	return state != State.BANISHED


func state_name() -> String:
	return STATE_NAMES[state]
