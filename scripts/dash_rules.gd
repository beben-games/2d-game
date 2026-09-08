class_name DashRules
extends RefCounted
## Pure rules for the dash: a short burst through enemy bodies with no i-frames.

const SPEED := 330.0  ## three times run speed
const DURATION := 0.15
const COOLDOWN := 0.6  ## from the start of the dash


static func can_start(cooldown_left: float, dashing: bool) -> bool:
	return cooldown_left <= 0.0 and not dashing


## Dash along the movement input, or toward the aim when standing still.
static func direction(move_wish: Vector2, aim_dir: Vector2) -> Vector2:
	if move_wish.length_squared() > 0.0:
		return move_wish.normalized()
	return aim_dir.normalized()
