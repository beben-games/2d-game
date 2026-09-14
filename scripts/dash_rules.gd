class_name DashRules
extends RefCounted
## Pure rules for the dash: a short burst through enemy bodies with no i-frames. Charges: a dash
## spends one; below the max, one charge comes back every COOLDOWN. With one charge this is the
## Milestone 2 dash exactly.

const SPEED := 330.0  ## three times run speed
const DURATION := 0.15
const COOLDOWN := 0.6  ## per charge, from the moment the refill clock starts


static func can_start(charges: int, dashing: bool) -> bool:
	return charges > 0 and not dashing


## Advances the refill clock by delta. Returns [charges, cooldown_left]. Below the max a new
## clock starts as soon as a charge lands; at the max there is no clock.
static func refill(charges: int, max_charges: int, cooldown_left: float, delta: float) -> Array:
	if charges >= max_charges:
		return [charges, 0.0]
	cooldown_left -= delta
	if cooldown_left <= 0.0:
		charges += 1
		cooldown_left = COOLDOWN if charges < max_charges else 0.0
	return [charges, cooldown_left]


## Dash along the movement input, or toward the aim when standing still.
static func direction(move_wish: Vector2, aim_dir: Vector2) -> Vector2:
	if move_wish.length_squared() > 0.0:
		return move_wish.normalized()
	return aim_dir.normalized()
