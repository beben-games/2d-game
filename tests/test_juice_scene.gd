extends SceneSuite
## Tests for the Juice autoload, the camera shake it drives, enemy impact feedback, and the Fx
## node, all inside the real main scene.

func _chaser_in(main: Node) -> Enemy:
	var enemy: Enemy = load(CHASER).instantiate()
	enemies_of(main).add_child(enemy)
	enemy.global_position = Vector2(400, 184)
	return enemy


func test_trauma_clamps_and_decays() -> void:
	Juice.trauma = 0.0
	Juice.add_trauma(0.7)
	Juice.add_trauma(0.7)
	assert_float(Juice.trauma).is_equal(1.0)
	await real_seconds(0.3)
	assert_float(Juice.trauma).is_less(1.0)
	assert_float(Juice.trauma).is_greater(0.0)


func test_trauma_survives_the_frame_a_hitstop_starts() -> void:
	# Godot reads Engine.time_scale once per frame, before physics. A hitstop started during
	# physics (an enemy dying) leaves that frame's process delta unscaled; decay must measure
	# real time rather than un-scale the delta, or the kill trauma is gone before the camera
	# ever samples it.
	quiet_main()
	await get_tree().physics_frame
	Juice.trauma = 0.0
	Juice.add_trauma(0.42)
	Juice.hitstop(0.06)
	await get_tree().process_frame  # start of this frame's process, before Juice decays
	await get_tree().process_frame  # Juice has now decayed once on the unscaled frame
	# 0.2 leaves room for headless frame-time variance; the guarded bug reads exactly 0.0 here.
	assert_float(Juice.trauma).is_greater(0.2)


func test_hitstop_slows_time_then_restores() -> void:
	Juice.hitstop(0.05)
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	await real_seconds(0.15)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_shorter_hitstop_never_cuts_a_longer_one_short() -> void:
	Juice.hitstop(0.2)
	Juice.hitstop(0.05)
	await real_seconds(0.1)
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	await real_seconds(0.15)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_reset_clears_trauma_and_running_hitstop() -> void:
	Juice.add_trauma(0.5)
	Juice.hitstop(0.5)
	Juice.reset()
	assert_float(Juice.trauma).is_equal(0.0)
	assert_float(Engine.time_scale).is_equal(1.0)
	await real_seconds(0.6)
	assert_float(Engine.time_scale).is_equal(1.0)  # the abandoned hitstop did not come back


func test_camera_offset_responds_to_trauma() -> void:
	var main := quiet_main()
	var camera: Camera2D = main.get_node("Player/Camera")
	Juice.trauma = 1.0
	await get_tree().process_frame
	await get_tree().process_frame  # the camera has sampled the trauma at least once
	assert_vector(camera.offset).is_not_equal(Vector2.ZERO)


func test_enemy_hit_lights_flash_uniform_immediately() -> void:
	var enemy := _chaser_in(quiet_main())
	enemy.health.take_damage(1.0)
	assert_float(enemy.flash_material.get_shader_parameter("flash")).is_equal(1.0)


func test_enemy_death_freezes_time_and_holds_pose_until_freed() -> void:
	var enemy := _chaser_in(quiet_main())
	enemy.health.take_damage(100.0)
	assert_float(Engine.time_scale).is_equal_approx(Juice.HITSTOP_SCALE, 0.001)
	assert_int(enemy.state).is_equal(Enemy.State.DEAD)
	assert_bool(is_instance_valid(enemy)).is_true()  # body lingers through the freeze
	assert_float(enemy.flash_material.get_shader_parameter("flash")).is_equal(1.0)
	await wait_for_death_freeze()
	assert_bool(is_instance_valid(enemy)).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_fx_spawns_muzzle_flash_and_death_burst() -> void:
	var main := quiet_main()
	var fx: Node2D = main.get_node("Fx")
	Events.shot_fired.emit(Vector2(100, 100), Vector2.RIGHT)
	Events.enemy_died.emit(auto_free(Node2D.new()), Vector2(200, 200))
	Events.player_died.emit(Vector2(300, 300))
	await get_tree().process_frame
	var flashes := 0
	var bursts := 0
	for child in fx.get_children():
		if child is MuzzleFlash:
			flashes += 1
		elif child is CPUParticles2D:
			bursts += 1
	assert_int(flashes).is_equal(1)
	assert_int(bursts).is_equal(2)  # one per death: enemy and player
	await real_seconds(0.8)
	await get_tree().process_frame
	assert_int(fx.get_child_count()).is_equal(0)  # every effect freed itself
