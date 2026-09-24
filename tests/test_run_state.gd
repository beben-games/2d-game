extends GdUnitTestSuite

const RunStateScript := preload("res://scripts/autoload/run_state.gd")


class FakeDef:
	var score: int = 25


class FakeEnemy extends Node2D:
	var def


## The bare instances below emit run_started on the live bus, which starts Audio's run loop.
func after_test() -> void:
	Audio.reset()


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
	state.heal_slot_uses = 2
	state.cheats = {"immortal": true}
	state.start_run(7)
	assert_int(state.score).is_equal(0)
	assert_int(state.kills).is_equal(0)
	assert_float(state.elapsed).is_equal(0.0)
	assert_int(state.heal_slot_uses).is_equal(0)
	assert_that(state.cheats).is_equal({})


func test_start_run_takes_the_cheats_for_the_run_as_a_copy() -> void:
	var state := _new_state(7)
	var flags := {"immortal": true}
	state.start_run(-1, flags)
	assert_that(state.cheats).is_equal({"immortal": true})
	assert_that(state.cheats).is_not_same(flags)
	assert_int(state.seed_value).is_greater_equal(0)


func test_negative_seed_means_random_seed() -> void:
	var state := _new_state(-1)
	assert_int(state.seed_value).is_greater_equal(0)
	var first_seed: int = state.seed_value
	state.start_run(-1)
	assert_int(state.seed_value).is_not_equal(first_seed)


func test_reseeding_same_instance_replays_sequence() -> void:
	var state := _new_state(7)
	var first: float = state.rng.randf()
	state.start_run(7)
	assert_float(state.rng.randf()).is_equal(first)


func test_enemy_died_counts_kill_and_def_score() -> void:
	RunState.start_run(1)
	var enemy: FakeEnemy = auto_free(FakeEnemy.new())
	enemy.def = FakeDef.new()
	Events.enemy_died.emit(enemy, Vector2.ZERO)
	assert_int(RunState.kills).is_equal(1)
	assert_int(RunState.score).is_equal(25)


func test_enemy_without_def_scores_default_10() -> void:
	RunState.start_run(1)
	Events.enemy_died.emit(auto_free(Node2D.new()), Vector2.ZERO)
	assert_int(RunState.kills).is_equal(1)
	assert_int(RunState.score).is_equal(10)


func test_stream_same_name_same_state_replays() -> void:
	var state := _new_state(42)
	assert_float(state.stream("spawn").randf()).is_equal(state.stream("spawn").randf())


func test_stream_different_names_differ() -> void:
	var state := _new_state(42)
	assert_float(state.stream("spawn").randf()).is_not_equal(state.stream("other").randf())


func test_stream_same_name_different_seeds_differ() -> void:
	var a := _new_state(1)
	var b := _new_state(2)
	assert_float(a.stream("spawn").randf()).is_not_equal(b.stream("spawn").randf())
