class_name FireController
extends RefCounted
## Tracks the cooldown between shots. Pure logic so it is testable without a scene.
## The sub-tick remainder carries over (at most one tick) so the real rate matches fire_rate
## instead of rounding down to whole ticks.

var cooldown := 0.0


func tick(delta: float) -> void:
	cooldown = maxf(cooldown - delta, -delta)


## Returns true and starts the cooldown if a shot is allowed now.
func try_fire(fire_rate: float) -> bool:
	if cooldown > 0.0:
		return false
	cooldown += 1.0 / fire_rate
	return true
