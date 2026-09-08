class_name WaveProgress
extends RefCounted
## Walks a WaveTable: which scene to place next and when the room is cleared. No nodes, no
## bus; WaveRunner feeds it ticks and deaths and emits the signals.

enum Outcome { NONE, NEXT_WAVE, CLEARED }

const SPAWN_INTERVAL := 0.25

var table: WaveTable
var wave_index := -1
var queue: Array[PackedScene] = []  ## scenes of the current wave still to place
var spawned := 0
var dead := 0
var cleared := false

var _timer := 0.0


func _init(wave_table: WaveTable) -> void:
	table = wave_table
	_queue_wave(0)


## Advances time. Returns the scene to place now, or null.
func tick(delta: float) -> PackedScene:
	if cleared or queue.is_empty():
		return null
	_timer -= delta
	if _timer > 0.0:
		return null
	_timer = SPAWN_INTERVAL
	spawned += 1
	return queue.pop_front()


## One of this wave's enemies died.
func on_death() -> Outcome:
	dead += 1
	if not queue.is_empty() or dead < spawned:
		return Outcome.NONE
	if wave_index + 1 < table.waves.size():
		_queue_wave(wave_index + 1)
		return Outcome.NEXT_WAVE
	cleared = true
	return Outcome.CLEARED


func _queue_wave(index: int) -> void:
	wave_index = index
	queue = []
	for group in table.waves[index].groups:
		for i in group.count:
			queue.append(group.enemy)
	spawned = 0
	dead = 0
	_timer = table.waves[index].breather
