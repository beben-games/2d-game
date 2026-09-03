extends GdUnitTestSuite

const REQUIRED := [
	"floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "floor_6", "floor_7", "floor_8",
	"wall_mid",
	"knight_m_idle_anim", "knight_m_run_anim",
	"imp_idle_anim", "imp_run_anim",
]


func test_required_sprites_exist() -> void:
	for name in REQUIRED:
		assert_bool(SpriteAtlas.has(name)).override_failure_message("missing sprite: " + name).is_true()


func test_has_is_false_for_unknown_names() -> void:
	assert_bool(SpriteAtlas.has("nope")).is_false()


func test_animation_frames_step_by_width() -> void:
	var first := SpriteAtlas.region("knight_m_idle_anim", 0)
	var second := SpriteAtlas.region("knight_m_idle_anim", 1)
	assert_float(second.position.x).is_equal(first.position.x + first.size.x)
	assert_float(second.position.y).is_equal(first.position.y)


func test_floor_is_a_16px_tile_on_the_grid() -> void:
	var coords := SpriteAtlas.tile_coords("floor_1")
	var region := SpriteAtlas.region("floor_1")
	assert_vector(region.size).is_equal(Vector2(16, 16))
	assert_vector(Vector2(coords) * 16.0).is_equal(region.position)


func test_wall_mid_tile_coords() -> void:
	assert_vector(SpriteAtlas.tile_coords("wall_mid")).is_equal(Vector2i(2, 1))


func test_frames_builds_looping_animations() -> void:
	var frames := SpriteAtlas.frames({"idle": "knight_m_idle_anim", "run": "knight_m_run_anim"})
	assert_bool(frames.has_animation("idle")).is_true()
	assert_bool(frames.has_animation("run")).is_true()
	assert_bool(frames.has_animation("default")).is_false()
	assert_int(frames.get_frame_count("idle")).is_equal(4)
	assert_bool(frames.get_animation_loop("run")).is_true()
	assert_float(frames.get_animation_speed("idle")).is_equal(8.0)
	var second := frames.get_frame_texture("idle", 1) as AtlasTexture
	assert_object(second).is_not_null()
	assert_object(second.atlas).is_same(SpriteAtlas.TEXTURE)
	assert_vector(second.region.position).is_equal(SpriteAtlas.region("knight_m_idle_anim", 1).position)
	assert_vector(second.region.size).is_equal(SpriteAtlas.region("knight_m_idle_anim", 1).size)
