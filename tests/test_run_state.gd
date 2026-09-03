extends GdUnitTestSuite

const RunStateScript := preload("res://scripts/autoload/run_state.gd")


func _new_state(seed_value: int) -> Node:
	var state: Node = auto_free(RunStateScript.new())
	state.start_run(seed_value)
	return state


func test_same_seed_gives_same_sequence() -> void:
	var a := _new_state(1234)
	var b := _new_state(1234)
	for i in 20:
		assert_float(a.rng.randf()).is_equal(b.rng.randf())


func test_different_seed_gives_different_sequence() -> void:
	var a := _new_state(1)
	var b := _new_state(2)
	assert_float(a.rng.randf()).is_not_equal(b.rng.randf())


func test_start_run_resets_counters() -> void:
	var state := _new_state(7)
	state.score = 50
	state.kills = 3
	state.elapsed = 12.0
	state.start_run(7)
	assert_int(state.score).is_equal(0)
	assert_int(state.kills).is_equal(0)
	assert_float(state.elapsed).is_equal(0.0)


func test_negative_seed_means_random_seed() -> void:
	var state := _new_state(-1)
	assert_int(state.seed_value).is_greater_equal(0)
