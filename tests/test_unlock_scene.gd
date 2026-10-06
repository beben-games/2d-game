extends SceneSuite
## The unlocks and the record (M7 Task 10): a tier's first win stores the tier its series opens
## (SeriesDef.first_win_unlock) in the same commit as the run's money; a second win, a fall, and a
## yield open nothing; the record, the gate screen's run block, and the RUN_END line carry the tier
## fought (RunState.run_tier, the series' own); the per-tier wins and bests are that tier's. The
## title's `scalae` unlocks every shipped tier and plays on uncheated; `--tier=N` on the command
## line sets the tier once per process (Main.user_args is the seam). The profile is SceneSuite's
## scratch.

## The scratch file as it was when run_ended went out (right after _close_run's one commit).
var _at_end: Array[Save] = []
## Main's command-line seam as the suite found it, put back after each test.
var _saved_args: PackedStringArray
var _saved_applied := false


func before_test() -> void:
	super()
	_at_end = []
	_saved_args = Main.user_args
	_saved_applied = Main._args_applied
	Events.run_ended.connect(_on_run_ended)


func after_test() -> void:
	Events.run_ended.disconnect(_on_run_ended)
	Main.user_args = _saved_args
	Main._args_applied = _saved_applied
	await super()


func _on_run_ended(_outcome: String) -> void:
	_at_end.append(Save.load_from(PROFILE_SCRATCH))


func _gate(main: Node) -> GateScreen:
	return main.get_node("GateScreen")


## A one-round series whose first win opens tier 2, as tier 1's does.
func _unlocking_series() -> SeriesDef:
	var series := tiny_series(1)
	series.first_win_unlock = "tier:2"
	return series


## The last round cleared, the win's hold, its stay, and the fade to the gate screen.
func _win_to_the_gate(main: Node) -> void:
	Events.round_cleared.emit()
	await real_seconds(Main.WIN_HOLD + Main.WIN_SHOW + Main.FADE_TIME + 0.3)
	assert_bool(_gate(main).is_open()).override_failure_message("the gate screen is not up").is_true()


func test_winning_tier_1_writes_the_unlock_in_the_same_commit_as_the_money() -> void:
	var main := quiet_main_with_series(_unlocking_series())
	assert_int(RunState.run_tier).is_equal(1)
	RunState.add_coins(9)
	assert_bool(FileAccess.file_exists(PROFILE_SCRATCH)).is_false()  # nothing committed before the win
	await _win_to_the_gate(main)
	assert_int(_at_end.size()).is_equal(1)
	var written := _at_end[0]  # the file as the run's one commit left it
	assert_int(written.money).is_equal(9)
	assert_int(int(written.unlocks["tier"])).is_equal(2)
	assert_int(written.highest_tier()).is_equal(2)
	assert_int(int(written.flags["wins"])).is_equal(1)
	assert_int(written.wins_of(1)).is_equal(1)
	assert_int(written.wins_of(2)).is_equal(0)
	assert_int(int(written.best_run_of(1)["rounds"])).is_equal(1)
	assert_that(written.best_run_of(2)).is_equal({})
	assert_int(int(written.runs[0]["tier"])).is_equal(1)
	assert_int(Profile.save.highest_tier()).is_equal(2)
	assert_str(_gate(main).run_label.text).starts_with("Tier 1\nRounds 1/1\n")
	assert_str(main._run_end_line("win", true)).contains(" tier=1 ")


func test_a_second_win_opens_nothing_more() -> void:
	var main := quiet_main_with_series(_unlocking_series())
	await _win_to_the_gate(main)
	main.restart()
	RunState.add_coins(4)
	await _win_to_the_gate(main)
	assert_int(_at_end.size()).is_equal(2)
	var written := _at_end[1]
	assert_that(written.unlocks).is_equal({"tier": 2, "lifts_seen": 1})
	assert_int(written.highest_tier()).is_equal(2)
	assert_int(written.money).is_equal(4)
	assert_int(written.wins_of(1)).is_equal(2)


func test_a_fall_and_a_yield_open_nothing() -> void:
	var series := _unlocking_series()
	series.rounds.append(tiny_series(1).rounds[0])  # two rounds: the first clear is no win
	var main := quiet_main_with_series(series)
	await fall_to_the_gate(main)
	assert_int(int(_at_end[0].unlocks["tier"])).is_equal(1)
	assert_int(_at_end[0].highest_tier()).is_equal(1)
	assert_int(int(_at_end[0].runs[0]["tier"])).is_equal(1)
	main.restart()  # after the verdict: a new run, nothing yielded
	main.restart()  # mid-run: a yield
	assert_int(_at_end.size()).is_equal(2)
	assert_str(_at_end[1].runs[0]["outcome"]).is_equal("yield")
	assert_int(int(_at_end[1].runs[0]["tier"])).is_equal(1)
	assert_that(_at_end[1].unlocks).is_equal({"tier": 1, "lifts_seen": 1})
	assert_int(Profile.save.highest_tier()).is_equal(1)


## A tier 2 series (made in code, two screens as tier 2's) is filed under tier 2 throughout: the
## record, the gate's row, RUN_END, the tier's wins and best; tier 1's stay empty.
func test_a_tier_2_win_is_filed_under_tier_2() -> void:
	var series := wide_series(1)
	series.tier = 2
	var main := quiet_main_with_series(series)
	assert_int(RunState.run_tier).is_equal(2)
	await _win_to_the_gate(main)
	var written := _at_end[0]
	assert_int(int(written.runs[0]["tier"])).is_equal(2)
	assert_int(written.wins_of(2)).is_equal(1)
	assert_int(written.wins_of(1)).is_equal(0)
	assert_int(int(written.best_run_of(2)["rounds"])).is_equal(1)
	assert_that(written.best_run_of(1)).is_equal({})
	assert_int(int(written.unlocks["tier"])).is_equal(1)  # tier 2's first win opens nothing (yet)
	assert_str(_gate(main).run_label.text).starts_with("Tier 2\n")
	assert_str(main._run_end_line("win", true)).contains(" tier=2 ")


## scalae at the title: every shipped tier unlocked on the save (committed, nothing else moved: no
## wipe, no backup) and an uncheated run (a first-run profile plays in the arena at once, on tier 1).
func test_scalae_unlocks_every_tier_and_starts_an_uncheated_run() -> void:
	Profile.save.money = 30
	assert_int(Profile.commit()).is_equal(OK)
	var main: Main = load(MAIN).instantiate()
	add_child(main)
	quiet(main)
	var title: Title = main.get_node("Title")
	assert_bool(title.is_open()).is_true()
	title.seed_field.text = "scalae"
	title.play()
	await get_tree().process_frame
	for save: Save in [Profile.save, Save.load_from(PROFILE_SCRATCH)]:
		assert_int(save.highest_tier()).is_equal(Tiers.IDS.max())
		assert_int(int(save.unlocks["tier"])).is_equal(Tiers.IDS.max())
		assert_int(save.money).is_equal(30)
	assert_bool(FileAccess.file_exists(PROFILE_SCRATCH + Save.BACKUP_SUFFIX)).is_false()
	assert_object(main.room).is_not_null()
	assert_that(RunState.cheats).is_equal({})
	assert_int(main.series_def.tier).is_equal(1)


## On a returned profile scalae lands in the Ludus as Play does, the lift's run uncheated.
func test_scalae_on_a_returned_profile_lands_in_the_ludus() -> void:
	Profile.save.set_flag("returned", true)
	assert_int(Profile.commit()).is_equal(OK)
	var main: Main = load(MAIN).instantiate()
	add_child(main)
	quiet(main)
	var title: Title = main.get_node("Title")
	title.seed_field.text = "scalae"
	title.play()
	await get_tree().process_frame
	assert_int(Profile.save.highest_tier()).is_equal(Tiers.IDS.max())
	assert_object(main.grounds).is_not_null()
	assert_that(main._pending_cheats).is_equal({})
	assert_int(main._pending_seed).is_equal(Cheats.RANDOM_SEED)


## `--tier=2` after `--` fights tier 2 from the boot, skipping the title as `--seed` does; it is
## applied once a process: a later read changes nothing.
func test_a_tier_argument_sets_the_tier_once() -> void:
	Main.user_args = PackedStringArray(["--tier=2"])
	Main._args_applied = false
	var main: Main = load(MAIN).instantiate()
	add_child(main)  # start_at_title: the argument skips it
	quiet(main)
	assert_bool((main.get_node("Title") as Title).is_open()).is_false()
	assert_int(RunState.tier).is_equal(2)
	assert_int(main.series_def.tier).is_equal(2)
	assert_int(RunState.run_tier).is_equal(2)
	assert_int(main.room.width).is_equal(Tiers.series(2).arena_width)
	RunState.reset_tier()
	assert_bool(main._apply_arguments()).is_false()  # once a process
	assert_int(RunState.tier).is_equal(1)


## With a seed beside it the tier's run replays that seed; an unknown or malformed tier is refused
## (a warning, muted here) and the tier kept.
func test_a_tier_argument_with_a_seed_and_a_refused_tier() -> void:
	Main.user_args = PackedStringArray(["--seed=77", "--tier=2"])
	Main._args_applied = false
	var main: Main = quiet_main()
	assert_int(RunState.tier).is_equal(2)
	assert_int(main.series_def.tier).is_equal(2)
	assert_int(RunState.seed_value).is_equal(77)
	RunState.reset_tier()
	for arg: String in ["--tier=9", "--tier=x", "--tier=0"]:
		Main.user_args = PackedStringArray([arg])
		Main._args_applied = false
		Engine.print_error_messages = false
		var applied := main._apply_arguments()
		Engine.print_error_messages = true
		assert_bool(applied).override_failure_message(arg).is_false()
		assert_int(RunState.tier).override_failure_message(arg).is_equal(1)
