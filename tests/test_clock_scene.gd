extends SceneSuite
## The Clock autoload: the engine's unscaled time, the clock every create_timer(..., true) in the
## game runs on. Sixty physics frames are about a second of it whether the runner keeps the wall
## clock (--realtime) or steps a fixed 1/60 s a frame (--fixed-fps 60), and neither a hitstop's
## time scale nor a pause slows it. The base is for after_test (the pause and the time scale back).

## Sixty physics frames are a second; the margin is a few frames either way (a realtime runner's
## physics and process steps are not locked to each other).
const FRAMES := 60
const SECOND := 1.0
const MARGIN := 4.0 / 60.0


func after_test() -> void:
	Clock.rotate()  # back on the full span, whatever a test set
	await super()


## The clock's seconds over `frames` physics frames.
func _seconds_over(frames: int) -> float:
	var start := Clock.now_usec()
	await ticks(frames)
	return float(Clock.now_usec() - start) / 1_000_000.0


func test_sixty_physics_frames_are_about_a_second() -> void:
	var seconds: float = await _seconds_over(FRAMES)
	assert_float(seconds).is_between(SECOND - MARGIN, SECOND + MARGIN)


func test_a_hitstop_time_scale_does_not_slow_it() -> void:
	Engine.time_scale = Juice.HITSTOP_SCALE
	var seconds: float = await _seconds_over(FRAMES)
	Engine.time_scale = 1.0
	assert_float(seconds).is_between(SECOND - MARGIN, SECOND + MARGIN)


func test_a_pause_does_not_stop_it() -> void:
	get_tree().paused = true
	var seconds: float = await _seconds_over(FRAMES)
	get_tree().paused = false
	assert_float(seconds).is_between(SECOND - MARGIN, SECOND + MARGIN)


## It reads the same as a real-time timer made beside it: the two are one clock.
func test_it_runs_with_a_real_time_timer() -> void:
	var start := Clock.now_usec()
	await real_seconds(0.5)
	var seconds := float(Clock.now_usec() - start) / 1_000_000.0
	assert_float(seconds).is_between(0.5 - MARGIN, 0.5 + MARGIN)


## A rotation (a new timer before the old one runs out) neither jumps nor stalls the clock; on a
## short span it rotates many times a second and stays monotonic, at the same rate.
func test_a_rotation_keeps_it_monotonic() -> void:
	var before := Clock.now_usec()
	Clock.rotate()
	assert_int(Clock.now_usec()).is_equal(before)
	Clock.rotate(Clock.ROTATE_TEST_SPAN)
	var rotated := Clock.rotations
	var start := Clock.now_usec()
	var last := start
	for i in FRAMES * 2:
		await get_tree().physics_frame
		var now := Clock.now_usec()
		assert_int(now).is_greater_equal(last)
		last = now
	assert_int(Clock.rotations - rotated).is_greater(2)  # every quarter second over two
	var seconds := float(last - start) / 1_000_000.0
	assert_float(seconds).is_between(2.0 * SECOND - MARGIN, 2.0 * SECOND + MARGIN)
