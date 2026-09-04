extends Camera2D
## Follows the player (as its child), leans toward the aim point, and shakes from Juice.trauma.
## Lean goes through position so the camera limits and smoothing clamp it; shake goes through
## offset so it is screen-space and may briefly show past a wall, which is fine.
## Shake randomness uses the global RNG on purpose: it is cosmetic and must not disturb the run seed.

const MAX_LEAN := 48.0
const LEAN_FACTOR := 0.3
const MAX_SHAKE := 7.0

@onready var player: Player = get_parent()


func _process(_delta: float) -> void:
	var to_aim: Vector2 = player.aim_position() - player.global_position
	position = to_aim.limit_length(MAX_LEAN) * LEAN_FACTOR
	offset = JuiceMath.shake_offset(Juice.trauma, MAX_SHAKE, randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
