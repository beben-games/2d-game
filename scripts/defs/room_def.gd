class_name RoomDef
extends Resource
## One room: size in tiles, its waves, and which wall the exit door is on. The entry door is
## on the side opposite the previous room's exit; Main works that out (FloorRules).

enum Side { TOP, BOTTOM, LEFT, RIGHT }

@export var width: int = 28
@export var height: int = 15
@export var waves: WaveTable
@export var exit_side: RoomDef.Side = Side.TOP  # qualified: a bare Side annotation breaks external test scripts in 4.7.2


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if width < 8:
		errors.append("width must be >= 8")
	if height < 6:
		errors.append("height must be >= 6")
	if exit_side != Side.TOP and exit_side != Side.BOTTOM:
		errors.append("exit_side must be TOP or BOTTOM")
	if waves == null:
		errors.append("waves must be set")
	else:
		for e in waves.validate():
			errors.append("waves: %s" % e)
	return errors
