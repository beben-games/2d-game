extends Node
## The engine's unscaled time, in microseconds since boot: the clock every
## create_timer(t, true, false, true) in the game already runs on. It is one scene-tree timer made
## with ignore_time_scale and process_always, from which the engine subtracts its unscaled process
## step every frame, under a pause and under a hitstop alike. In the game that step is the wall
## clock's frame time; under the test runner's --fixed-fps 60 it is exactly 1/60 s a frame, so a
## test that waits on frames and code that reads this clock agree. Read it instead of
## Time.get_ticks_* for anything the game times (Juice, Audio's minimum gap, the text box's reveal);
## only what waits on another thread (the mixer at quit) keeps the OS clock.
##
## The reading is constant within a frame: the engine steps the timer after every node's _process.
## The first autoload, so every other one can read it; before its _ready it reads 0.

## The timer's length: a day, rotated at half (a double holds the microseconds far past it).
const SPAN := 86_400.0
## A span short enough to rotate several times a second (the rotation's test).
const ROTATE_TEST_SPAN := 0.5

## Rotations since boot (the rotation's test counts them).
var rotations := 0

var _span := SPAN
var _timer: SceneTreeTimer
var _base_usec := 0  ## the time the rotated-out timers ran


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rotate()


func _process(_delta: float) -> void:
	if _timer.time_left < _span * 0.5:
		rotate(_span)


## Microseconds of unscaled engine time since boot; never goes back.
func now_usec() -> int:
	if _timer == null:
		return _base_usec
	return _base_usec + int((_span - _timer.time_left) * 1_000_000.0)


## Seconds of unscaled engine time since boot.
func now() -> float:
	return float(now_usec()) / 1_000_000.0


## Folds the running timer's time into the base and starts a new one of `span` seconds: the
## reading is the same before and after. _process calls it at half the span; a test may shorten
## the span (and after_test calls it bare to put SPAN back).
func rotate(span := SPAN) -> void:
	_base_usec = now_usec()
	if _timer != null:
		_timer.time_left = 0.0  # the old one times out on the next step, unheard, and leaves the tree
	_span = span
	_timer = get_tree().create_timer(span, true, false, true)
	rotations += 1
