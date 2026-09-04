class_name Health
extends Node
## Hit points for anything that can be damaged. Emits signals; owners react.

signal damaged(amount: float, knockback: Vector2)
signal died()

@export var max_hp: float = 3.0

var hp: float = -1.0
var dead := false


func _ready() -> void:
	if hp < 0.0:
		hp = max_hp


## Owners call this when the max comes from a definition.
func setup(max_hp_value: float) -> void:
	max_hp = max_hp_value
	hp = max_hp_value
	dead = false


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, knockback)
	if hp == 0.0:
		dead = true
		died.emit()
