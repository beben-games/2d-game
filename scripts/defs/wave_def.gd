class_name WaveDef
extends Resource
## One wave: groups of enemies placed together, after a breather.

@export var groups: Array[SpawnGroup] = []
@export var breather: float = 1.0  ## seconds of calm before this wave starts placing


func total() -> int:
	var n := 0
	for g in groups:
		if g != null:
			n += g.count
	return n


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if groups.is_empty():
		errors.append("wave has no groups")
	if breather < 0.0:
		errors.append("breather must be >= 0")
	for i in groups.size():
		if groups[i] == null:
			errors.append("group %d: missing" % i)
			continue
		for e in groups[i].validate():
			errors.append("group %d: %s" % [i, e])
	return errors
