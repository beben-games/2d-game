extends GdUnitTestSuite


func test_main_scene_loads_and_has_expected_root() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert_object(packed).is_not_null()
	var root: Node = auto_free(packed.instantiate())
	assert_str(root.name).is_equal("Main")
	assert_bool(root is Node2D).is_true()
