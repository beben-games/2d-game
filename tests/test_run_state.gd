extends GdUnitTestSuite

const RunStateScript := preload("res://scripts/autoload/run_state.gd")


class FakeDef:
	var score: int = 25


class FakeEnemy extends Node2D:
	var def


## start_run reads the live Profile, and this suite runs first in the runner, before any SceneSuite
## has pointed the profile at its scratch: point it there here too, so the player's real save
## (its training ranks, once a rank is bought) never reaches these numbers.
func before_test() -> void:
	Profile.path = SceneSuite.PROFILE_SCRATCH
	Profile.reset()


## The bare instances below emit run_started on the live bus (the HUD and the player of any
## Main would hear it; none is up here); the counters are cleared for symmetry with the suites.
func after_test() -> void:
	Audio.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SceneSuite.PROFILE_SCRATCH))
	Profile.reset()


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
	state.cheats = {"immortal": true}
	state.favour = 77.0
	state.perfect = false
	state.hits_this_round = 2
	state.coins = 9
	state.round_tally = 4
	state.start_run(7)
	assert_int(state.score).is_equal(0)
	assert_int(state.kills).is_equal(0)
	assert_float(state.elapsed).is_equal(0.0)
	assert_that(state.cheats).is_equal({})
	assert_float(state.favour).is_equal(FavourRules.START)
	assert_bool(state.perfect).is_true()
	assert_int(state.hits_this_round).is_equal(0)
	assert_int(state.coins).is_equal(0)
	assert_int(state.round_tally).is_equal(0)


## The profile's training shapes the run's start: the build's bases and the favour. The live
## Profile is read (an autoload; SceneSuite is not the base here, so the save is put back).
func test_start_run_builds_from_the_profiles_training() -> void:
	var held := Profile.save
	var save := Save.new()
	save.training = {"hearts": 1, "breath": 2, "renown": 1}
	Profile.save = save
	var state := _new_state(7)
	Profile.save = held
	assert_int(state.build.base_max_hp).is_equal(8)
	assert_int(state.build.base_dash_charges).is_equal(3)
	assert_float(state.favour).is_equal(30.0)
	state.start_run(7)  # the profile is back to the held one (no training): the bases too
	assert_int(state.build.base_max_hp).is_equal(Build.BASE_MAX_HP)
	assert_float(state.favour).is_equal(FavourRules.START)


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


func test_add_coins_adds_and_tells_the_counter_the_total() -> void:
	RunState.start_run(1)
	var totals: Array[int] = []
	var on_changed := func(run_coins: int) -> void: totals.append(run_coins)
	Events.coins_changed.connect(on_changed)
	RunState.add_coins(3)
	RunState.add_coins(2)
	Events.coins_changed.disconnect(on_changed)
	assert_int(RunState.coins).is_equal(5)
	assert_array(totals).is_equal([3, 5])


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


func test_the_dives_cheat_starts_the_run_rich() -> void:
	var state := _new_state(7)
	state.start_run(7, {"rich": true})
	assert_int(state.coins).is_equal(RunStateScript.RICH_COINS)
	state.start_run(7)
	assert_int(state.coins).is_equal(0)


func test_hits_taken_counts_the_runs_hits_from_the_bus_and_starts_over() -> void:
	RunState.start_run(7)
	Events.player_hit.emit(1, 5, 6, "chaser")
	Events.player_hit.emit(1, 4, 6, "")
	assert_int(RunState.hits_taken).is_equal(2)
	RunState.start_run(7)
	assert_int(RunState.hits_taken).is_equal(0)
