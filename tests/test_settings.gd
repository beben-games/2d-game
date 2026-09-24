extends GdUnitTestSuite
## Settings: defaults on a missing file, a round trip through a scratch file, clamping.

const PATH := "user://test_settings.cfg"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_defaults_when_the_file_is_missing() -> void:
	var s := Settings.load_from("user://does_not_exist.cfg")
	assert_float(s.master).is_equal(0.8)
	assert_float(s.sfx).is_equal(1.0)
	assert_float(s.music).is_equal(1.0)  # playtest notes 2026-09-23: the music was too quiet, twice


func test_round_trip() -> void:
	var s := Settings.new()
	s.set_volume("master", 0.5)
	s.set_volume("music", 0.25)
	assert_int(s.save_to(PATH)).is_equal(OK)
	var back := Settings.load_from(PATH)
	assert_float(back.master).is_equal(0.5)
	assert_float(back.sfx).is_equal(1.0)
	assert_float(back.music).is_equal(0.25)
	assert_float(back.volume("music")).is_equal(0.25)


func test_values_clamp_to_the_unit_range() -> void:
	var s := Settings.new()
	s.set_volume("sfx", 3.0)
	assert_float(s.sfx).is_equal(1.0)
	s.set_volume("sfx", -1.0)
	assert_float(s.sfx).is_equal(0.0)
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", 5.0)
	cfg.save(PATH)
	assert_float(Settings.load_from(PATH).master).is_equal(1.0)
