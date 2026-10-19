extends RefCounted
class_name GhostDB
## =========================================================================
## GhostDB  -  the DIFFICULTY LADDER for the four ghosts
## =========================================================================
## This is the single place where "how hard is this ghost" lives.
##
## EASIEST  ->  HARDEST   (exactly the design you asked for)
##
##   1. SOLDIER_FEMALE  "the girl soldier"   -> easiest, dies fast
##   2. SOLDIER_MALE    "the boy soldier"    -> easy, a bit tougher
##   3. GHOST_QUEEN     "the girl queen"     -> hard, hits hard, very stubborn
##   4. GHOST_KING      "the boy king"       -> hardest, boss, but now beatable
##
## EnemyGhost reads this automatically from its `rig_body` value, so you never
## have to hand-tune four scenes - just pick the character and the difficulty
## follows.
##
## Every key in a profile:
##   health            how much damage it survives
##   damage_resist     0.0 - 0.8  fraction of incoming damage ignored
##   roam_speed        walk speed while patrolling (m/s)
##   chase_speed       walk speed while hunting you (m/s)
##   damage            hit points it takes off you per strike
##   attack_range      how close it must be to hit you (m)
##   attack_windup     seconds of tell before the hit lands (your dodge window)
##   attack_cooldown   seconds between strikes
##   detect_radius     how far away it notices you (m)
##   lose_radius       how far you must run before it gives up (m)
##   teleport          can it blink through walls to cut you off
##                     (SWITCHED OFF for every ghost - see the notes below.
##                      The code still supports it, so one `true` revives it.)
##   teleport_cooldown seconds between blinks
##   stun_scale        multiplies how long it staggers when you hit it
##   score             points awarded for banishing it
## =========================================================================

const EASIEST := "EASIEST"
const EASY := "EASY"
const HARD := "HARD"
const HARDEST := "HARDEST"

const PROFILES := {
	GhostRig.Body.SOLDIER_FEMALE: {
		"name": "Wailing Sister",
		"tag": EASIEST,
		"blurb": "Bandaged girl soldier. Slow, fragile, telegraphs every swipe.",
		"health": 60.0,
		"damage_resist": 0.0,
		"roam_speed": 1.0,
		"chase_speed": 2.9,
		"damage": 6.0,
		"attack_range": 1.7,
		"attack_windup": 0.75,
		"attack_cooldown": 2.6,
		"detect_radius": 7.5,
		"lose_radius": 13.0,
		"teleport": false,
		"teleport_cooldown": 0.0,
		"stun_scale": 1.8,
		"score": 100,
	},
	GhostRig.Body.SOLDIER_MALE: {
		"name": "Fallen Rifleman",
		"tag": EASY,
		"blurb": "Helmeted boy soldier. Hits harder, still easy to stagger.",
		"health": 95.0,
		"damage_resist": 0.05,
		"roam_speed": 1.2,
		"chase_speed": 3.2,
		"damage": 10.0,
		"attack_range": 1.9,
		"attack_windup": 0.60,
		"attack_cooldown": 2.2,
		"detect_radius": 9.0,
		"lose_radius": 15.0,
		"teleport": false,
		"teleport_cooldown": 0.0,
		"stun_scale": 1.3,
		"score": 200,
	},
	GhostRig.Body.GHOST_QUEEN: {
		"name": "The Ghost Queen",
		"tag": HARD,
		"blurb": "Red saree, blood tears. Hits like a truck and will not stop coming.",
		"health": 110.0,
		"damage_resist": 0.15,
		"roam_speed": 1.4,
		"chase_speed": 3.7,
		"damage": 18.0,
		"attack_range": 2.3,
		"attack_windup": 0.42,
		"attack_cooldown": 1.5,
		"detect_radius": 12.0,
		"lose_radius": 19.0,
		# TELEPORT OFF: blinking through walls was more frustrating than scary.
		# Set this back to true (and give it a cooldown) to bring it back.
		"teleport": false,
		"teleport_cooldown": 0.0,
		"stun_scale": 0.7,
		"score": 600,
	},
	GhostRig.Body.GHOST_KING: {
		"name": "The Ghost King",
		"tag": HARDEST,
		"blurb": "Crowned, crimson, cyan-eyed. Still the hardest fight in the game - but now a fight you can win.",
		# TUNED DOWN: he used to be 400 hp / 25% resist / 26 damage / a 6 s
		# teleport, which meant 12 katana hits while he killed you in 4. He is
		# still the toughest ghost in the game (more hits than the Queen, the
		# only one who hits harder), but the fight is now winnable.
		"health": 150.0,
		"damage_resist": 0.0,
		"roam_speed": 1.4,
		"chase_speed": 3.8,
		"damage": 13.0,
		"attack_range": 2.4,
		"attack_windup": 0.52,
		"attack_cooldown": 1.8,
		"detect_radius": 12.0,
		"lose_radius": 18.0,
		# TELEPORT OFF: see the note on the Queen. Same reason.
		"teleport": false,
		"teleport_cooldown": 0.0,
		"stun_scale": 0.85,
		"score": 1500,
	},
}

## Easiest first - handy for documentation and level design.
const ORDER := [
	GhostRig.Body.SOLDIER_FEMALE,
	GhostRig.Body.SOLDIER_MALE,
	GhostRig.Body.GHOST_QUEEN,
	GhostRig.Body.GHOST_KING,
]


static func get_profile(body: int) -> Dictionary:
	return PROFILES.get(body, PROFILES[GhostRig.Body.SOLDIER_MALE])


static func ghost_name(body: int) -> String:
	return String(get_profile(body).get("name", "Ghost"))


static func difficulty_tag(body: int) -> String:
	return String(get_profile(body).get("tag", "?"))


static func order_index(body: int) -> int:
	return ORDER.find(body)
