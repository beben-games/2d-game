extends GdUnitTestSuite

const CHASER := preload("res://scenes/enemies/chaser.tscn")


func _table(counts: Array, breather := 0.0) -> WaveTable:
	var t := WaveTable.new()
	for count in counts:
		var g := SpawnGroup.new()
		g.enemy = CHASER
		g.count = count
		var w := WaveDef.new()
		w.groups = [g]
		w.breather = breather
		t.waves.append(w)
	return t


func test_breather_then_one_spawn_per_interval() -> void:
	var p := WaveProgress.new(_table([2], 0.5))
	assert_object(p.tick(0.4)).is_null()
	assert_object(p.tick(0.2)).is_same(CHASER)  # breather over at 0.5
	assert_object(p.tick(0.1)).is_null()
	assert_object(p.tick(0.2)).is_same(CHASER)  # 0.25 s later
	assert_object(p.tick(1.0)).is_null()  # wave fully placed
	assert_int(p.spawned).is_equal(2)


func test_deaths_advance_waves_and_clear_the_round() -> void:
	var p := WaveProgress.new(_table([1, 2]))
	assert_int(p.wave_index).is_equal(0)
	p.tick(0.0)
	assert_int(p.on_death()).is_equal(WaveProgress.Outcome.NEXT_WAVE)
	assert_int(p.wave_index).is_equal(1)
	p.tick(0.0)
	p.tick(0.3)
	assert_int(p.on_death()).is_equal(WaveProgress.Outcome.NONE)
	assert_int(p.on_death()).is_equal(WaveProgress.Outcome.CLEARED)
	assert_bool(p.cleared).is_true()
	assert_object(p.tick(1.0)).is_null()


func test_a_death_before_the_wave_is_fully_placed_does_not_end_it() -> void:
	var p := WaveProgress.new(_table([3]))
	p.tick(0.0)  # one placed, two queued
	assert_int(p.on_death()).is_equal(WaveProgress.Outcome.NONE)
	p.tick(0.3)
	p.tick(0.3)
	p.on_death()
	assert_int(p.on_death()).is_equal(WaveProgress.Outcome.CLEARED)


func test_deaths_after_clear_are_ignored() -> void:
	var p := WaveProgress.new(_table([1]))
	p.tick(0.0)
	assert_int(p.on_death()).is_equal(WaveProgress.Outcome.CLEARED)
	assert_int(p.on_death()).is_equal(WaveProgress.Outcome.NONE)
	assert_bool(p.cleared).is_true()
