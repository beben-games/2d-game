class_name SpawnGroup
extends Resource
## One kind of enemy, count times, inside a wave.

@export var enemy: PackedScene
@export var count: int = 1


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if enemy == null:
		errors.append("enemy must be set")
	if count < 1:
		errors.append("count must be >= 1")
	return errors
