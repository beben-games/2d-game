extends GdUnitTestSuite
## The gate screen's text, pure: the run's block and the all-time block from a run record and a
## Save, and the deadliest enemy (the id with the most hits landed on the player).

const GateScreenScript := preload("res://scripts/ui/gate_screen.gd")


func _run(cheats := "") -> Dictionary:
	return {"rounds": 2, "rounds_total": 8, "kills": 17, "time": 83.0, "coins_earned": 40, "coins_kept": 40, "seed": 12345, "cheats": cheats}


func _save() -> Save:
	var save := Save.new()
	save.flags["runs"] = 5
	save.flags["wins"] = 1
	save.flags["falls"] = 4
	save.flags["deaths"] = 2
	save.add_stat("kills", 100, "chaser")
	save.add_stat("kills", 20, "shooter")
	save.add_stat("hits_taken", 30, "chaser")
	save.add_stat("hits_taken", 3, "shooter")
	save.add_stat("shots_fired", 900, "handgun")
	return save


func test_format_time_is_minutes_and_seconds() -> void:
	assert_str(GateScreenScript.format_time(0.0)).is_equal("0:00")
	assert_str(GateScreenScript.format_time(65.4)).is_equal("1:05")
	assert_str(GateScreenScript.format_time(600.0)).is_equal("10:00")


func test_blocks_are_the_run_then_all_time() -> void:
	var blocks := GateScreenScript.blocks(_run(), _save())
	assert_int(blocks.size()).is_equal(2)
	assert_str(blocks[0]).is_equal("Rounds 2/8\nKills 17\nTime 1:23\nCoins earned 40\nCoins kept 40\nSeed 12345")
	assert_str(blocks[1]).is_equal("Runs 5\nWins 1\nFalls 4\nDeaths 2\nKills 120\nHits taken 33\nShots fired 900")


func test_body_joins_the_blocks_with_a_blank_line() -> void:
	var body := GateScreenScript.body(_run(), _save())
	assert_str(body).is_equal(
		"Rounds 2/8\nKills 17\nTime 1:23\nCoins earned 40\nCoins kept 40\nSeed 12345"
		+ "\n\nRuns 5\nWins 1\nFalls 4\nDeaths 2\nKills 120\nHits taken 33\nShots fired 900")


## A cheated run is never mistaken for a real one: the run's block names the cheats that were on.
func test_body_names_the_cheats_when_any_was_on() -> void:
	var blocks := GateScreenScript.blocks(_run("immortal"), _save())
	assert_str(blocks[0]).ends_with("\nSeed 12345\nCheats immortal")


func test_body_of_a_fresh_save_is_zeros() -> void:
	assert_str(GateScreenScript.blocks(_run(), Save.new())[1]).is_equal("Runs 0\nWins 0\nFalls 0\nDeaths 0\nKills 0\nHits taken 0\nShots fired 0")


func test_deadliest_is_the_id_with_the_most_hits_taken() -> void:
	assert_str(GateScreenScript.deadliest(_save())).is_equal("chaser")
	assert_str(GateScreenScript.deadliest(Save.new())).is_equal("")


func test_deadliest_breaks_a_tie_by_name_order() -> void:
	var save := Save.new()
	save.add_stat("hits_taken", 4, "shooter")
	save.add_stat("hits_taken", 4, "boss")
	save.add_stat("hits_taken", 4, "chaser")
	assert_str(GateScreenScript.deadliest(save)).is_equal("boss")


## The line under the portrait names the deadliest enemy and its all-time hits (UI may name);
## nothing when no hit was ever taken or the id has no def.
func test_portrait_line_names_the_deadliest_and_its_hits() -> void:
	assert_str(GateScreenScript.portrait_line(_save(), GateScreenScript.deadliest(_save()))).is_equal("Imp hit you 30 times")
	var one := Save.new()
	one.add_stat("hits_taken", 1, "shooter")
	assert_str(GateScreenScript.portrait_line(one, "shooter")).is_equal("Shaman hit you 1 time")
	var lord := Save.new()
	lord.add_stat("hits_taken", 2, "boss")
	assert_str(GateScreenScript.portrait_line(lord, "boss")).is_equal("Imp Lord hit you 2 times")
	assert_str(GateScreenScript.portrait_line(Save.new(), "")).is_equal("")
	var unknown := Save.new()
	unknown.add_stat("hits_taken", 5, "nobody")
	assert_str(GateScreenScript.portrait_line(unknown, "nobody")).is_equal("")
