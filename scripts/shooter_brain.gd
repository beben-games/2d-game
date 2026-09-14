class_name ShooterBrain
extends RefCounted
## The Shooter's cycle: approach to range, wind up, fire once, recover, repeat. Pure: the enemy
## feeds it the distance to its target and reads back a movement wish and a fire tick.

enum Phase { APPROACH, TELEGRAPH, RECOVER }

var phase := Phase.APPROACH
var phase_time := 0.0


## Advances the cycle. Returns true on the one tick the bolt should leave.
func tick(delta: float, distance: float, def: EnemyDef) -> bool:
	phase_time += delta
	match phase:
		Phase.APPROACH:
			if distance <= def.preferred_range:
				_enter(Phase.TELEGRAPH)
		Phase.TELEGRAPH:
			if phase_time >= def.telegraph_time:
				_enter(Phase.RECOVER)
				return true
		Phase.RECOVER:
			if phase_time >= def.recover_time:
				_enter(Phase.APPROACH)
	return false


## Movement wish for this phase. to_target is the vector from the shooter to the player.
func wish(to_target: Vector2, def: EnemyDef) -> Vector2:
	var distance := to_target.length()
	match phase:
		Phase.APPROACH:
			if distance > def.preferred_range:
				return to_target
			if distance < def.too_close_range:
				return -to_target
		Phase.RECOVER:
			if distance < def.too_close_range:
				return -to_target
	return Vector2.ZERO


## A stun mid-wind-up cuts the attack: back to APPROACH, so the next telegraph starts from zero
## and the shot is never a surprise. A no-op outside TELEGRAPH.
func interrupt() -> void:
	if phase == Phase.TELEGRAPH:
		_enter(Phase.APPROACH)


func _enter(next: Phase) -> void:
	phase = next
	phase_time = 0.0
