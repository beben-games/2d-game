class_name Health
extends Node
## Hit points for anything that can be damaged. Emits signals; owners react.

signal damaged(amount: float, knockback: Vector2)
signal died()

@export var max_hp: float = 3.0

var hp: float = -1.0
var dead := false
## True while the damaged signal for a quiet hit (a burn tick) is being handled: owners skip the
## flash and shake for those. Reset by the next loud hit.
var last_hit_quiet := false


func _ready() -> void:
	if hp < 0.0:
		hp = max_hp


## Owners call this when the max comes from a definition.
func setup(max_hp_value: float) -> void:
	max_hp = max_hp_value
	hp = max_hp_value
	dead = false


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, quiet: bool = false) -> void:
	if dead or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	last_hit_quiet = quiet
	damaged.emit(amount, knockback)
	if hp == 0.0:
		dead = true
		died.emit()
