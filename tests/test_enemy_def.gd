extends GdUnitTestSuite


func test_chaser_resource_is_valid() -> void:
	var def: EnemyDef = load("res://data/enemies/chaser.tres")
	assert_object(def).is_not_null()
	assert_array(def.validate()).is_empty()
	assert_str(def.id).is_equal("chaser")


func test_chaser_animations_exist_in_atlas() -> void:
	var def: EnemyDef = load("res://data/enemies/chaser.tres")
	assert_bool(SpriteAtlas.has(def.idle_anim)).is_true()
	assert_bool(SpriteAtlas.has(def.run_anim)).is_true()


func test_validate_reports_bad_values() -> void:
	var def := EnemyDef.new()
	def.max_hp = 0.0
	def.speed = -5.0
	assert_array(def.validate()).has_size(2)


func test_validate_reports_negative_contact_damage() -> void:
	var def := EnemyDef.new()
	def.contact_damage = -1
	assert_array(def.validate()).contains(["contact_damage must be >= 0"])


func test_shooter_def_needs_a_bolt_and_sane_ranges() -> void:
	var d := EnemyDef.new()
	d.behavior = EnemyDef.Behavior.SHOOTER
	d.preferred_range = 50.0
	d.too_close_range = 80.0
	d.telegraph_time = -1.0
	assert_array(d.validate()).contains_exactly_in_any_order([
		"bolt must be set for a shooter", "too_close_range must be < preferred_range", "telegraph_time must be >= 0"])


func test_shipped_shooter_def_is_valid() -> void:
	var d: EnemyDef = load("res://data/enemies/shooter.tres")
	assert_array(d.validate()).is_empty()
	assert_int(d.behavior).is_equal(EnemyDef.Behavior.SHOOTER)


func test_shooter_bolt_is_validated() -> void:
	var d: EnemyDef = load("res://data/enemies/shooter.tres").duplicate()
	d.bolt = d.bolt.duplicate()
	d.bolt.damage = 0.5
	d.bolt.lifetime = 0.0
	assert_array(d.validate()).contains_exactly_in_any_order(["bolt.damage must be >= 1", "bolt: lifetime must be > 0"])


func test_the_shield_is_off_by_default_and_its_numbers_are_validated() -> void:
	var d := EnemyDef.new()
	assert_bool(d.shield).is_false()
	assert_float(d.shield_arc_degrees).is_equal(180.0)
	assert_float(d.shield_turn_degrees).is_equal(180.0)
	assert_array(d.validate()).is_empty()
	d.shield = true
	d.shield_arc_degrees = 400.0
	d.shield_turn_degrees = -1.0
	assert_array(d.validate()).contains_exactly_in_any_order([
		"shield_arc_degrees must be within 0..360", "shield_turn_degrees must be >= 0"])
	d.shield_arc_degrees = -10.0
	d.shield_turn_degrees = 0.0
	assert_array(d.validate()).contains_exactly(["shield_arc_degrees must be within 0..360"])
