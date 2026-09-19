extends GdUnitTestSuite


func test_shipped_boss_def_is_valid_and_uses_atlas_animations() -> void:
	var d: BossDef = load("res://data/enemies/boss.tres")
	assert_array(d.validate()).is_empty()
	assert_str(d.id).is_equal("boss")
	assert_bool(SpriteAtlas.has(d.idle_anim)).is_true()
	assert_bool(SpriteAtlas.has(d.run_anim)).is_true()
	assert_object(d.bolt).is_not_null()
	assert_object(d.summon_scene).is_not_null()
	assert_float(d.status_scale).is_equal(0.5)


func test_validate_reports_bad_values() -> void:
	var d := BossDef.new()
	d.max_hp = 0.0
	d.charge_time = -1.0
	d.ring_count = 0
	d.phase2_fraction = 1.5
	d.status_scale = 0.0
	d.summon_count = -1
	var errors := d.validate()
	assert_array(errors).contains(["max_hp must be > 0", "charge_time must be >= 0", "ring_count must be >= 1",
		"phase2_fraction must be in (0, 1)", "status_scale must be > 0", "summon_count must be >= 0",
		"bolt must be set", "summon_scene must be set"])
