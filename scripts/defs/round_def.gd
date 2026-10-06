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
		errors.append_array(_boss_errors())
	return errors


## A boss fight is one wave's bodies (BossFight): a round whose bodies come in two waves or more is
## refused, and so is a scene that runs the boss's script without the group `boss` in its file
## (the bodies are counted from the files, never instanced).
func _boss_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var with_bodies: PackedStringArray = []
	for i in waves.waves.size():
		var wave := waves.waves[i]
		if wave == null:
			continue
		var bodies := 0
		for group in wave.groups:
			if group == null or group.enemy == null:
				continue
			if BossFight.is_boss_scene(group.enemy):
				bodies += 1
			elif BossFight.runs_the_boss_script(group.enemy):
				errors.append("wave %d: a boss's scene without the group `boss`" % i)
		if bodies > 0:
			with_bodies.append(str(i))
	if with_bodies.size() > 1:
		errors.append("the boss's bodies must come in one wave (waves %s)" % ", ".join(with_bodies))
	return errors
