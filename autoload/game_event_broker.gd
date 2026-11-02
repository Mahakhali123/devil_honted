extends Node
## =========================================================================
## GameEventBroker  -  AUTOLOAD / SINGLETON
## =========================================================================
## The decoupled event bus every Haveli system talks through.
## No gameplay script should call another gameplay script directly when an
## event will do - this keeps the AI, the HUD, the ritual and the player
## independent of each other.
##
## Emit:   GameEventBroker.player_noise_made.emit(5.0, pos)
## Listen: GameEventBroker.player_noise_made.connect(_on_noise)
## =========================================================================

## Footstep / prop noise. `volume` is the radius in metres the sound carries.
signal player_noise_made(volume: float, location: Vector3)

## Something was added to the 6-slot inventory.
signal item_picked_up(item)

## Kamla changed FSM state (int matches Kamla.State).
signal monster_state_changed(new_state: int)

## Player crossed into a new room / zone id.
signal zone_entered(zone_id: String)

## Sanity changed (0..100).
signal sanity_changed(current: float)

## Player hid inside, or left, a hiding spot. `spot` is the HidingSpot node.
signal player_hidden_changed(hidden: bool, spot: Node)

## Ritual altar progress.
signal ritual_progress(deposited: int, required: int)

## Ritual finished - Kamla can be banished.
signal ritual_completed()
