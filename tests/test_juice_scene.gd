extends GdUnitTestSuite
## Tests for the Juice autoload, the camera shake it drives, enemy impact feedback, and the Fx
## node, all inside the real main scene.

const MAIN := "res://scenes/main.tscn"
const CHASER := "res://scenes/enemies/chaser.tscn"


func after_test() -> void:
	Juice.reset()


func _main_without_spawner() -> Node:
	var runner := scene_runner(MAIN)
	var main: Node = runner.scene()
	main.get_node("Spawner").enabled = false
	return main


func _chaser_in(main: Node) -> Enemy:
	var enemy: Enemy = load(CHASER).instantiate()
	main.get_node("Enemies").add_child(enemy)
	enemy.global_position = Vector2(400, 184)
	return enemy


func _real_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func test_trauma_clamps_and_decays() -> void:
	Juice.trauma = 0.0
	Juice.add_trauma(0.7)
	Juice.add_trauma(0.7)
	assert_float(Juice.trauma).is_equal(1.0)
	await _real_seconds(0.3)
	assert_float(Juice.trauma).is_less(1.0)
	assert_float(Juice.trauma).is_greater(0.0)


func test_trauma_survives_the_frame_a_hitstop_starts() -> void:
	# Godot reads Engine.time_scale once per frame, before physics. A hitstop started during
	# physics (an enemy dying) leaves that frame's process delta unscaled; decay must measure
	# real time rather than un-scale the delta, or the kill trauma is gone before the camera
	# ever samples it.
	_main_without_spawner()
	await get_tree().physics_frame
	Juice.trauma = 0.0
	Juice.add_trauma(0.42)
	Juice.hitstop(0.06)
	await get_tree().process_frame  # start of this frame's process, before Juice decays
	await get_tree().process_frame  # Juice has now decayed once on the unscaled frame
	assert_float(Juice.trauma).is_greater(0.2)


func test_hitstop_slows_time_then_restores() -> void:
	Juice.hitstop(0.05)
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	await _real_seconds(0.15)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_shorter_hitstop_never_cuts_a_longer_one_short() -> void:
	Juice.hitstop(0.2)
	Juice.hitstop(0.05)
	await _real_seconds(0.1)
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	await _real_seconds(0.15)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_reset_clears_trauma_and_running_hitstop() -> void:
	Juice.add_trauma(0.5)
	Juice.hitstop(0.5)
	Juice.reset()
	assert_float(Juice.trauma).is_equal(0.0)
	assert_float(Engine.time_scale).is_equal(1.0)
	await _real_seconds(0.6)
	assert_float(Engine.time_scale).is_equal(1.0)  # the abandoned hitstop did not come back


func test_camera_offset_responds_to_trauma() -> void:
	var main := _main_without_spawner()
	var camera: Camera2D = main.get_node("Player/Camera")
	Juice.trauma = 1.0
	await get_tree().process_frame
	await get_tree().process_frame  # the camera has sampled the trauma at least once
	assert_vector(camera.offset).is_not_equal(Vector2.ZERO)


func test_enemy_hit_lights_flash_uniform_immediately() -> void:
	var enemy := _chaser_in(_main_without_spawner())
	enemy.health.take_damage(1.0)
	assert_float(enemy.flash_material.get_shader_parameter("flash")).is_equal(1.0)


func test_enemy_death_freezes_time_and_holds_pose_until_freed() -> void:
	var enemy := _chaser_in(_main_without_spawner())
	enemy.health.take_damage(100.0)
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	assert_int(enemy.state).is_equal(Enemy.State.DEAD)
	assert_bool(is_instance_valid(enemy)).is_true()  # body lingers through the freeze
	assert_float(enemy.flash_material.get_shader_parameter("flash")).is_equal(1.0)
	await _real_seconds(Enemy.DEATH_HITSTOP + 0.05)
	await get_tree().physics_frame
	assert_bool(is_instance_valid(enemy)).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_fx_spawns_muzzle_flash_and_death_burst() -> void:
	var main := _main_without_spawner()
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
	await _real_seconds(0.8)
	await get_tree().process_frame
	assert_int(fx.get_child_count()).is_equal(0)  # both effects freed themselves
