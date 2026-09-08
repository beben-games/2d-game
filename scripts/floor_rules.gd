class_name FloorRules
extends RefCounted
## Pure rules for walking a FloorDef: which side you enter a room from, and when you are done.

const NO_DOOR := -1


static func opposite(side: int) -> int:
	match side:
		RoomDef.Side.TOP:
			return RoomDef.Side.BOTTOM
		RoomDef.Side.BOTTOM:
			return RoomDef.Side.TOP
		RoomDef.Side.LEFT:
			return RoomDef.Side.RIGHT
	return RoomDef.Side.LEFT


static func entry_side(floor_def: FloorDef, index: int) -> int:
	if index <= 0:
		return NO_DOOR
	return opposite(floor_def.rooms[index - 1].exit_side)


static func is_last(floor_def: FloorDef, index: int) -> bool:
	return index >= floor_def.rooms.size() - 1
