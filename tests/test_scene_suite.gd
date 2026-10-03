extends SceneSuite
## SceneSuite's own clean slate: after_test resets the profile before it starts the run it leaves
## behind, so a training rank one test leaves in the live save never becomes the next test's run
## (RunState reads the profile's ranks at start_run: offer_bonus, rerolls_left).


func test_after_test_resets_the_profile_before_the_run_it_starts() -> void:
	Profile.save.training["offer"] = 1
	Profile.save.training["reroll"] = 1
	await after_test()
	assert_dict(Profile.save.training).is_empty()
	assert_int(RunState.offer_bonus).is_equal(0)
	assert_int(RunState.rerolls_left).is_equal(0)
