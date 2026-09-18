extends GdUnitTestSuite


func test_main_scene_boots_with_expected_root() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	var root: Main = load(main_scene).instantiate()
	root.start_at_title = false
	add_child(root)
	auto_free(root)
	assert_object(root).is_not_null()
	root.get_node("Room/WaveRunner").enabled = false
	assert_str(root.name).is_equal("Main")
	assert_object(root).is_instanceof(Node2D)
	assert_bool(root.has_node("Room")).is_true()
	assert_bool(root.has_node("Room/Arena")).is_true()
	assert_bool(root.has_node("Room/Enemies")).is_true()
	assert_bool(root.has_node("Room/Projectiles")).is_true()
	assert_bool(root.has_node("Room/Spawner")).is_true()
	assert_bool(root.has_node("Room/WaveRunner")).is_true()
	assert_bool(root.has_node("Room/Doors")).is_true()
	assert_bool(root.has_node("Player")).is_true()
	assert_bool(root.has_node("Fx")).is_true()
	assert_bool(root.get_node("Player").has_node("Camera")).is_true()
	assert_bool(root.has_node("Title")).is_true()
