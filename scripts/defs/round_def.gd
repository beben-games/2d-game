class_name RoundDef
extends Resource
## One round of a series: its waves. The arena is the series', so a round is only what it sends.

@export var waves: WaveTable


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if waves == null:
		errors.append("waves must be set")
	else:
		for e in waves.validate():
			errors.append("waves: %s" % e)
	return errors
