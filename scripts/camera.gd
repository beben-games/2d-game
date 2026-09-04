extends Camera2D
## Follows the player (as its child) and leans a little toward the aim point so you see what you aim at.
## The lean goes through the local position (the player never rotates, so local == world direction)
## because Camera2D clamps position to limit_* but adds offset afterwards; offset stays free for screen shake.

const MAX_LEAN := 48.0
const LEAN_FACTOR := 0.3

@onready var player: Player = get_parent()


func _process(_delta: float) -> void:
	var to_aim: Vector2 = player.aim_position() - player.global_position
	# Limits and smoothing clamp position; offset stays free for screen shake.
	position = to_aim.limit_length(MAX_LEAN) * LEAN_FACTOR
