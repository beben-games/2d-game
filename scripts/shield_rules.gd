class_name ShieldRules
extends RefCounted
## Pure rules for an enemy's front shield (playtest 1, note 3): whether a player shot arriving
## from a direction is stopped by an arc around the enemy's facing, and how the facing turns
## toward where the enemy is going at a bounded rate. No nodes, no state; Enemy applies them.


## True when the shot cannot pierce `pierce_through` enemies and it arrives from inside the arc:
## the angle between the facing and the way back along the shot is at most half the arc.
static func blocks(facing: Vector2, shot_direction: Vector2, pierce: int, arc_degrees: float, pierce_through: int) -> bool:
	if pierce >= pierce_through:
		return false
	if facing == Vector2.ZERO or shot_direction == Vector2.ZERO:
		return false
	return facing.normalized().dot(-shot_direction.normalized()) >= cos(deg_to_rad(arc_degrees) / 2.0)


## `facing` rotated toward `toward` by at most `max_degrees`, the short way round; unchanged when
## there is nowhere to turn to. Always a unit vector.
static func turn(facing: Vector2, toward: Vector2, max_degrees: float) -> Vector2:
	if toward == Vector2.ZERO or facing == Vector2.ZERO:
		return facing
	return Vector2.from_angle(rotate_toward(facing.angle(), toward.angle(), deg_to_rad(max_degrees)))
