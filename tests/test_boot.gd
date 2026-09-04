extends GdUnitTestSuite


func test_main_scene_boots_with_expected_root() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	var runner := scene_runner(main_scene)
	var root: Node = runner.scene()
	assert_object(root).is_not_null()
	if root == null:
		return
	assert_str(root.name).is_equal("Main")
	assert_object(root).is_instanceof(Node2D)
	assert_bool(root.has_node("Arena")).is_true()
	assert_bool(root.has_node("Enemies")).is_true()
	assert_bool(root.has_node("Player")).is_true()
	assert_bool(root.get_node("Player").has_node("Camera")).is_true()
