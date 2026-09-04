extends GdUnitTestSuite
## Tests for the Juice autoload and the Fx node inside the real main scene.


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func after_test() -> void:
	Juice.trauma = 0.0
	Engine.time_scale = 1.0


func test_trauma_clamps_and_decays() -> void:
	Juice.trauma = 0.0
	Juice.add_trauma(0.7)
	Juice.add_trauma(0.7)
	assert_float(Juice.trauma).is_equal(1.0)
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_float(Juice.trauma).is_less(1.0)
	assert_float(Juice.trauma).is_greater(0.0)


func test_hitstop_slows_time_then_restores() -> void:
	Juice.hitstop(0.05)
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	await get_tree().create_timer(0.15, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal(1.0)


func test_fx_spawns_muzzle_flash_and_death_burst() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	var main: Node = runner.scene()
	main.get_node("Spawner").enabled = false
	var fx: Node2D = main.get_node("Fx")
	Events.shot_fired.emit(Vector2(100, 100), Vector2.RIGHT)
	Events.enemy_died.emit(auto_free(Node2D.new()), Vector2(200, 200))
	await get_tree().process_frame
	var flashes := 0
	var bursts := 0
	for child in fx.get_children():
		if child is MuzzleFlash:
			flashes += 1
		elif child is CPUParticles2D:
			bursts += 1
	assert_int(flashes).is_equal(1)
	assert_int(bursts).is_equal(1)
	await get_tree().create_timer(0.8, true, false, true).timeout
	await get_tree().process_frame
	assert_int(fx.get_child_count()).is_equal(0)  # both effects freed themselves
