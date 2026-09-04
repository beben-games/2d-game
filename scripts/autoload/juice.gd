extends Node
## Central impact feedback: trauma for screen shake, hitstop, and sprite flash.
## Every tunable feel number lives here so balancing feel means editing one file.

const TRAUMA_DECAY := 2.5
const HITSTOP_SCALE := 0.05
const FLASH_DURATION := 0.08

var trauma := 0.0

var _hitstop_id := 0
var _hitstop_until_usec := 0
var _last_usec := Time.get_ticks_usec()


func _process(_delta: float) -> void:
	# Decay in measured real time. Godot captures Engine.time_scale before the frame runs, so
	# on the frame a hitstop starts the delta is still unscaled; dividing it by the new scale
	# would decay 20x too fast and wipe the kill trauma before the camera samples it.
	var now := Time.get_ticks_usec()
	trauma = JuiceMath.decay(trauma, TRAUMA_DECAY, float(now - _last_usec) / 1_000_000.0)
	_last_usec = now


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Freezes the game for duration real seconds. Overlapping calls extend the freeze; a shorter
## call never cuts a longer one short.
func hitstop(duration: float) -> void:
	var until := Time.get_ticks_usec() + int(duration * 1_000_000.0)
	if until <= _hitstop_until_usec:
		return
	_hitstop_until_usec = until
	_hitstop_id += 1
	var my_id := _hitstop_id
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id == _hitstop_id:
		Engine.time_scale = 1.0
		_hitstop_until_usec = 0


## Clears trauma and any running hitstop and restores normal time. Called on run restart and
## by tests so no freeze or shake leaks across a scene reload.
func reset() -> void:
	trauma = 0.0
	_hitstop_id += 1
	_hitstop_until_usec = 0
	Engine.time_scale = 1.0
	_last_usec = Time.get_ticks_usec()


## Flashes a sprite white via the flash shader uniform. Returns the fade tween so the owner can
## kill it when it wants to hold the pose instead.
func flash(material: ShaderMaterial) -> Tween:
	material.set_shader_parameter("flash", 1.0)
	var tween := create_tween()
	tween.tween_property(material, "shader_parameter/flash", 0.0, FLASH_DURATION)
	return tween
