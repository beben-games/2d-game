extends GdUnitTestSuite


## A fresh def with the one field validate needs set: the display name.
func _fresh() -> EnemyDef:
	var d := EnemyDef.new()
	d.display_name = "Test"
	return d


func test_display_name_defaults_empty_and_is_validated() -> void:
	var d := EnemyDef.new()
	assert_str(d.display_name).is_equal("")
	assert_array(d.validate()).contains_exactly(["display_name must be set"])
	d.display_name = "Imp"
	assert_array(d.validate()).is_empty()


## The name the gate screen's portrait line says (UI may name).
func test_shipped_enemies_carry_their_display_names() -> void:
	assert_str(load("res://data/enemies/chaser.tres").display_name).is_equal("Imp")
	assert_str(load("res://data/enemies/chaser_shield.tres").display_name).is_equal("Shield imp")
	assert_str(load("res://data/enemies/shooter.tres").display_name).is_equal("Shaman")


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
	var def := _fresh()
	def.max_hp = 0.0
	def.speed = -5.0
	assert_array(def.validate()).has_size(2)


func test_validate_reports_negative_contact_damage() -> void:
	var def := _fresh()
	def.contact_damage = -1
	assert_array(def.validate()).contains(["contact_damage must be >= 0"])


func test_shooter_def_needs_a_bolt_and_sane_ranges() -> void:
	var d := _fresh()
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
	var d := _fresh()
	assert_bool(d.shield).is_false()
	assert_float(d.shield_arc_degrees).is_equal(120.0)
	assert_float(d.shield_turn_degrees).is_equal(60.0)
	assert_array(d.validate()).is_empty()
	d.shield = true
	d.shield_arc_degrees = 400.0
	d.shield_turn_degrees = -1.0
	assert_array(d.validate()).contains_exactly_in_any_order([
		"shield_arc_degrees must be within 0..360", "shield_turn_degrees must be >= 0"])
	d.shield_arc_degrees = -10.0
	d.shield_turn_degrees = 0.0
	assert_array(d.validate()).contains_exactly(["shield_arc_degrees must be within 0..360"])


func test_shipped_shielded_chaser_is_the_chaser_with_a_shield() -> void:
	var shield: EnemyDef = load("res://data/enemies/chaser_shield.tres")
	var plain: EnemyDef = load("res://data/enemies/chaser.tres")
	assert_array(shield.validate()).is_empty()
	assert_str(shield.id).is_equal("chaser_shield")
	assert_bool(shield.shield).is_true()
	assert_float(shield.shield_arc_degrees).is_equal(120.0)  # playtest 1, note 5: 180 was too big
	assert_float(shield.shield_turn_degrees).is_equal(60.0)  # and 90 turned too fast (180 the first cut)
	assert_int(shield.score).is_equal(15)
	for stat: String in ["max_hp", "speed", "accel", "contact_damage", "spawn_delay", "idle_anim", "run_anim", "sprite_offset", "death_color"]:
		assert_that(shield.get(stat)).override_failure_message(stat).is_equal(plain.get(stat))
	var scene: PackedScene = load("res://scenes/enemies/chaser_shield.tscn")
	var enemy: Enemy = auto_free(scene.instantiate())
	assert_str(enemy.def.id).is_equal("chaser_shield")
	assert_bool(enemy.is_in_group("enemies")).is_true()


func test_coins_default_to_none_and_are_validated() -> void:
	var d := _fresh()
	assert_int(d.coins).is_equal(0)
	assert_array(d.validate()).is_empty()
	d.coins = -1
	assert_array(d.validate()).contains_exactly(["coins must be >= 0"])


func test_shipped_enemies_carry_the_designed_coins() -> void:
	assert_int(load("res://data/enemies/chaser.tres").coins).is_equal(1)
	assert_int(load("res://data/enemies/chaser_shield.tres").coins).is_equal(2)
	assert_int(load("res://data/enemies/shooter.tres").coins).is_equal(2)


func test_a_charger_def_validates_its_numbers() -> void:
	var d := _fresh()
	d.behavior = EnemyDef.Behavior.CHARGER
	assert_array(d.validate()).is_empty()  # the defaults are a charger's
	d.charge_range = 0.0
	d.windup_time = -0.1
	d.charge_speed = 0.0
	d.charge_time = 0.0
	d.skid_time = -1.0
	d.back_damage_scale = 0.5
	d.back_arc_degrees = 400.0
	assert_array(d.validate()).contains_exactly_in_any_order([
		"charge_range must be > 0", "windup_time must be >= 0", "charge_speed must be > 0",
		"charge_time must be > 0", "skid_time must be >= 0", "back_damage_scale must be >= 1",
		"back_arc_degrees must be within 0..360"])
	d.behavior = EnemyDef.Behavior.CHASER
	assert_array(d.validate()).is_empty()  # a chaser ignores the charge's numbers


## The id is the file's name: the gate screen's portrait loads data/enemies/<id>.tres.
func test_shipped_charger_def_is_valid() -> void:
	var d: EnemyDef = load("res://data/enemies/charger.tres")
	assert_array(d.validate()).is_empty()
	assert_str(d.id).is_equal("charger")
	assert_int(d.behavior).is_equal(EnemyDef.Behavior.CHARGER)
	assert_str(d.display_name).is_equal("Chort")  # the creature's name, as "Imp" and "Shaman" are
	assert_int(d.coins).is_equal(3)
	assert_bool(SpriteAtlas.has(d.idle_anim)).is_true()
	assert_bool(SpriteAtlas.has(d.run_anim)).is_true()
	assert_object(GateScreen.enemy_def("charger")).is_equal(d)
	var enemy: Enemy = auto_free((load("res://scenes/enemies/charger.tscn") as PackedScene).instantiate())
	assert_str(enemy.def.id).is_equal("charger")
	assert_bool(enemy.is_in_group("enemies")).is_true()
	assert_int(enemy.collision_layer).is_equal(2)
	assert_int(enemy.collision_mask).is_equal(19)


func test_a_bearer_def_validates_its_numbers() -> void:
	var d := _fresh()
	d.behavior = EnemyDef.Behavior.BEARER
	assert_array(d.validate()).is_empty()  # the defaults are a bearer's
	d.banner_radius = 0.0
	d.banner_haste = 0.9
	d.flee_range = -1.0
	assert_array(d.validate()).contains_exactly_in_any_order([
		"banner_radius must be > 0", "banner_haste must be >= 1", "flee_range must be >= 0"])
	d.behavior = EnemyDef.Behavior.CHASER
	assert_array(d.validate()).is_empty()  # a chaser ignores the banner's numbers


## The id is the file's name: the gate screen's portrait loads data/enemies/<id>.tres.
func test_shipped_standard_bearer_def_is_valid() -> void:
	var d: EnemyDef = load("res://data/enemies/standard_bearer.tres")
	assert_array(d.validate()).is_empty()
	assert_str(d.id).is_equal("standard_bearer")
	assert_int(d.behavior).is_equal(EnemyDef.Behavior.BEARER)
	assert_str(d.display_name).is_equal("Masked orc")
	assert_int(d.contact_damage).is_equal(0)
	assert_int(d.coins).is_equal(3)
	assert_bool(SpriteAtlas.has(d.idle_anim)).is_true()
	assert_bool(SpriteAtlas.has(d.run_anim)).is_true()
	assert_bool(SpriteAtlas.has("wall_banner_red")).is_true()
	assert_object(GateScreen.enemy_def("standard_bearer")).is_equal(d)
	var enemy: Enemy = auto_free((load("res://scenes/enemies/standard_bearer.tscn") as PackedScene).instantiate())
	assert_str(enemy.def.id).is_equal("standard_bearer")
	assert_bool(enemy.is_in_group("enemies")).is_true()
	assert_int(enemy.collision_layer).is_equal(2)
	assert_int(enemy.collision_mask).is_equal(19)
