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
	assert_array(BossDef.new().validate()).contains(["bolt must be set", "summon_scene must be set"])
	var d := BossDef.new()
	d.id = ""
	d.max_hp = 0.0
	d.volley_spread_degrees = -1.0
	d.bolt = WeaponDef.new()
	d.bolt.damage = 0.5
	d.charge_time = -1.0
	d.ring_count = 0
	d.phase2_fraction = 1.5
	d.status_scale = 0.0
	d.summon_count = -1
	d.recover_move = -0.5
	var errors := d.validate()
	assert_array(errors).contains(["recover_move must be >= 0", "max_hp must be > 0", "charge_time must be >= 0", "ring_count must be >= 1",
		"phase2_fraction must be in (0, 1)", "status_scale must be > 0", "summon_count must be >= 0",
		"summon_scene must be set", "bolt.damage must be >= 1", "volley_spread_degrees must be >= 0", "id must be set"])
	var crowded := BossDef.new()
	crowded.summon_count = 3
	assert_array(crowded.validate()).contains(["summon_count must be <= 2"])


func test_the_boss_carries_sixty_coins_and_negative_coins_fail() -> void:
	var shipped: BossDef = load("res://data/enemies/boss.tres")
	assert_int(shipped.coins).is_equal(60)
	var d: BossDef = shipped.duplicate()
	d.coins = -1
	assert_array(d.validate()).contains_exactly(["coins must be >= 0"])


## Playtest 1 of M5 (two wins in about three minutes each) set stage one's numbers; playtest 1 of
## M6 ("the boss is too easy") a quarter more health and a shorter cycle: a shorter approach and
## shorter recovers in both stages, the wind-ups kept so every attack still reads.
func test_the_shipped_boss_numbers_after_m6_playtest_1() -> void:
	var d: BossDef = load("res://data/enemies/boss.tres")
	assert_float(d.max_hp).is_equal(750.0)
	assert_float(d.approach_time).is_equal(0.8)
	assert_float(d.telegraph_time).is_equal(0.5)
	assert_float(d.recover_time).is_equal(0.45)
	assert_float(d.charge_speed).is_equal(380.0)
	assert_float(d.phase2_telegraph_time).is_equal(0.45)
	assert_float(d.phase2_recover_time).is_equal(0.4)
	assert_float(d.recover_move).is_equal(1.0)  # M6 playtest 2: it walks at the player through its recover
	assert_int(d.summon_count).is_equal(2)
	assert_int(d.phase2_ring_count).is_equal(16)


## M7 Task 7's fields default to tier 1's boss, and the shipped boss leaves them so.
func test_the_several_bodies_fields_default_to_tier_1_s_boss() -> void:
	for d: BossDef in [BossDef.new(), load("res://data/enemies/boss.tres")]:
		assert_array(d.stage1_cycle).is_equal(["ring", "volley", "charge"])
		assert_array(d.stage2_cycle).is_equal(["ring", "volley", "charge", "summon"])
		assert_float(d.keep_range).is_equal(0.0)
		assert_int(d.charge_chain).is_equal(1)
		assert_bool(d.charge_line).is_false()
		assert_bool(d.enrage_on_partner).is_false()


func test_validate_reports_bad_cycles_chains_and_ranges() -> void:
	var d: BossDef = (load("res://data/enemies/boss.tres") as BossDef).duplicate()
	d.stage1_cycle = []
	d.stage2_cycle = ["ring", "roar"]
	d.charge_chain = 0
	d.keep_range = -1.0
	assert_array(d.validate()).contains_exactly(["stage1_cycle must not be empty", "stage2_cycle: no pattern 'roar'",
		"charge_chain must be >= 1", "keep_range must be >= 0"])


## A boss enraged by its partner's death may never enrage by its health (phase2_fraction 0);
## one with no partner's rule keeps the health's.
func test_phase2_fraction_zero_only_with_the_partner_s_enrage() -> void:
	var d: BossDef = (load("res://data/enemies/boss.tres") as BossDef).duplicate()
	d.phase2_fraction = 0.0
	assert_array(d.validate()).contains_exactly(["phase2_fraction must be in (0, 1)"])
	d.enrage_on_partner = true
	assert_array(d.validate()).is_empty()
	d.phase2_fraction = 1.0
	assert_array(d.validate()).contains_exactly(["phase2_fraction must be in [0, 1)"])
