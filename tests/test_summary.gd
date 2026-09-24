extends GdUnitTestSuite

const SummaryScript := preload("res://scripts/ui/summary.gd")


func test_format_time_is_minutes_and_seconds() -> void:
	assert_str(SummaryScript.format_time(0.0)).is_equal("0:00")
	assert_str(SummaryScript.format_time(65.4)).is_equal("1:05")
	assert_str(SummaryScript.format_time(600.0)).is_equal("10:00")


func test_body_lists_rooms_kills_time_and_seed() -> void:
	var body := SummaryScript.body(2, 4, 17, 83.0, 12345)
	assert_str(body).is_equal("Rooms cleared 2/4\nKills 17\nTime 1:23\nSeed 12345")


## A cheated run is never mistaken for a real one: the card names the cheats that were on.
func test_body_names_the_cheats_when_any_was_on() -> void:
	assert_str(SummaryScript.body(2, 4, 17, 83.0, 12345, "immortal")).is_equal("Rooms cleared 2/4\nKills 17\nTime 1:23\nSeed 12345\nCheats immortal")
	assert_str(SummaryScript.body(2, 4, 17, 83.0, 12345, "")).is_equal("Rooms cleared 2/4\nKills 17\nTime 1:23\nSeed 12345")
