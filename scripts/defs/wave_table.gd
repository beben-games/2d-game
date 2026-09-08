class_name WaveTable
extends Resource
## The waves of one room, in order. The room is cleared when the last wave is dead.

@export var waves: Array[WaveDef] = []


func total_enemies() -> int:
	var n := 0
	for w in waves:
		n += w.total()
	return n


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if waves.is_empty():
		errors.append("table has no waves")
	for i in waves.size():
		for e in waves[i].validate():
			errors.append("wave %d: %s" % [i, e])
	return errors
