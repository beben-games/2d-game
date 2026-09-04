class_name PlayerHitRules
extends RefCounted
## Pure rules for taking contact damage.

const BLINK_PERIOD := 0.1


static func can_take_hit(invuln_left: float) -> bool:
	return invuln_left <= 0.0


## Knockback pushing the player away from the attacker. Falls back to a fixed direction if they overlap.
static func knockback_from(player_position: Vector2, attacker_position: Vector2, strength: float) -> Vector2:
	var away := player_position - attacker_position
	if away.length_squared() == 0.0:
		away = Vector2.UP
	return away.normalized() * strength


## While invulnerable the sprite blinks: visible for the first half of each period, hidden for the
## second. invuln_left counts down, so the first half in elapsed time is the upper half of the remainder.
static func blink_visible(invuln_left: float) -> bool:
	if invuln_left <= 0.0:
		return true
	return fmod(invuln_left, BLINK_PERIOD) >= BLINK_PERIOD * 0.5
