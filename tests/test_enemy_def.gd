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
