extends Camera2D
## Follows the player (as its child) and leans a little toward the aim point so you see what you aim at.

const MAX_LEAN := 48.0
const LEAN_FACTOR := 0.3

@onready var player: Node2D = get_parent()


func _process(_delta: float) -> void:
	var to_aim: Vector2 = player.aim_position() - player.global_position
	offset = to_aim.limit_length(MAX_LEAN) * LEAN_FACTOR
