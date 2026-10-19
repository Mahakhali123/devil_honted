extends RefCounted
class_name WeaponDB
## =========================================================================
## WeaponDB  -  every weapon in the game, as plain data
## =========================================================================
## Player weapons all work the same way underneath:
##
##    * you press ATTACK
##    * the player sweeps a small sphere in front of the camera
##    * anything on the ENEMY physics layer inside the range + swing arc and
##      not hidden behind a wall takes damage
##
## Only the numbers change per weapon. Those numbers live here so you can
## rebalance the whole game without touching combat code.
##
## Every key in a weapon:
##   name            shown in the HUD
##   desc            one line of flavour
##   damage          hit points removed on a clean hit
##   range           how far the sweep reaches (metres)
##   arc             width of the swing cone in degrees (360 = hits behind you)
##   cooldown        seconds before you can swing again
##   windup          fraction of the swing before the hit actually lands
##   knockback       how hard it shoves the ghost away
##   stun            extra stagger seconds on top of the ghost's own stagger
##   ghost_bonus     damage multiplier against ghosts (>1 = ghost hunter gear)
##   color           viewmodel / pickup colour
## =========================================================================

const MELEE := "melee"
const TOOL := "tool"

const WEAPONS := {
	"fists": {
		"name": "Bare Hands",
		"desc": "Better than nothing. Barely.",
		"damage": 6.0,
		"range": 1.8,
		"arc": 55.0,
		"cooldown": 0.45,
		"windup": 0.05,
		"knockback": 0.6,
		"stun": 0.1,
		"ghost_bonus": 1.0,
		"color": Color(0.72, 0.58, 0.48),
		"shape": "fists",
	},
	"wooden_bat": {
		"name": "Wooden Bat",
		"desc": "Waterlogged and cracked, but it still swings true.",
		"damage": 22.0,
		"range": 2.6,
		"arc": 72.0,
		"cooldown": 0.62,
		"windup": 0.22,
		"knockback": 1.8,
		"stun": 0.45,
		"ghost_bonus": 1.0,
		"color": Color(0.46, 0.30, 0.16),
		"shape": "bat",
	},
	"frying_pan": {
		"name": "Frying Pan",
		"desc": "Loud, heavy, and it *stuns* spirits on contact.",
		"damage": 15.0,
		"range": 2.2,
		"arc": 88.0,
		"cooldown": 0.78,
		"windup": 0.26,
		"knockback": 2.8,
		"stun": 1.6,
		"ghost_bonus": 1.0,
		"color": Color(0.26, 0.26, 0.28),
		"shape": "pan",
	},
	"katana": {
		"name": "Katana",
		"desc": "Blessed steel. It cuts the dead like they were air.",
		"damage": 34.0,
		"range": 2.9,
		"arc": 62.0,
		"cooldown": 0.50,
		"windup": 0.18,
		"knockback": 1.4,
		"stun": 0.7,
		"ghost_bonus": 1.4,
		"color": Color(0.84, 0.88, 0.92),
		"shape": "katana",
	},
	"ghost_lantern": {
		"name": "Ghost Lantern",
		"desc": "Cold blue flame. Reveals what the dark is hiding.",
		"damage": 5.0,
		"range": 2.0,
		"arc": 60.0,
		"cooldown": 0.90,
		"windup": 0.20,
		"knockback": 0.5,
		"stun": 0.3,
		"ghost_bonus": 1.0,
		"color": Color(0.55, 0.82, 1.0),
		"shape": "lantern",
	},
	"spirit_trap": {
		"name": "Spirit Trap",
		"desc": "Locks a spirit in place. Long stun, almost no damage.",
		"damage": 9.0,
		"range": 2.4,
		"arc": 70.0,
		"cooldown": 1.70,
		"windup": 0.34,
		"knockback": 0.4,
		"stun": 3.0,
		"ghost_bonus": 1.0,
		"color": Color(0.45, 0.88, 0.82),
		"shape": "trap",
	},
}

const STARTING_WEAPONS := ["fists"]

## Order used by keys 1..6 in the HUD.
const SLOT_ORDER := ["fists", "wooden_bat", "frying_pan", "katana", "ghost_lantern", "spirit_trap"]


static func get_weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["fists"])


static func has_weapon(id: String) -> bool:
	return WEAPONS.has(id)


static func display_name(id: String) -> String:
	return String(get_weapon(id).get("name", id))


static func describe(id: String) -> String:
	return String(get_weapon(id).get("desc", ""))


static func all_ids() -> Array:
	return WEAPONS.keys()
