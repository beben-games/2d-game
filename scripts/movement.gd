class_name Movement
extends RefCounted
## Top-down velocity integration shared by the player and enemies.

const MOVING_THRESHOLD := 10.0


## Returns the new velocity after one step. wish_dir is the raw input vector (any length).
static func step(velocity: Vector2, wish_dir: Vector2, max_speed: float, accel: float, friction: float, delta: float) -> Vector2:
	if wish_dir.length_squared() > 0.0:
		return velocity.move_toward(wish_dir.normalized() * max_speed, accel * delta)
	return velocity.move_toward(Vector2.ZERO, friction * delta)


## Whether a velocity is fast enough to play a run animation instead of idle.
static func is_moving(velocity: Vector2) -> bool:
	return velocity.length() >= MOVING_THRESHOLD
