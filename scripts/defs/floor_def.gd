class_name FloorDef
extends Resource
## A run: rooms in order. Clearing the last one wins.

@export var rooms: Array[RoomDef] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if rooms.is_empty():
		errors.append("floor has no rooms")
	for i in rooms.size():
		if rooms[i] == null:
			errors.append("room %d: missing" % i)
			continue
		if i > 0 and rooms[i - 1] != null and rooms[i].exit_side == FloorRules.opposite(rooms[i - 1].exit_side):
			errors.append("room %d: exit is on its entry side" % i)
		for e in rooms[i].validate():
			errors.append("room %d: %s" % [i, e])
	return errors
