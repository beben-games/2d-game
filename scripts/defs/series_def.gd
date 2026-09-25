class_name SeriesDef
extends Resource
## A run: the arena's size in tiles and its rounds in order, all fought in the one arena.
## Clearing the last round wins.

@export var arena_width: int = 28
@export var arena_height: int = 15
@export var rounds: Array[RoundDef] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	# The top gap needs width / 2 - 1 >= 1 (ArenaGrid.door_cells); the rest is playable floor.
	if arena_width < 8:
		errors.append("arena_width must be >= 8")
	if arena_height < 6:
		errors.append("arena_height must be >= 6")
	if rounds.is_empty():
		errors.append("series has no rounds")
	for i in rounds.size():
		if rounds[i] == null:
			errors.append("round %d: missing" % i)
			continue
		for e in rounds[i].validate():
			errors.append("round %d: %s" % [i, e])
	return errors


func is_last(index: int) -> bool:
	return index >= rounds.size() - 1
