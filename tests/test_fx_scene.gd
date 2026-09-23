extends SceneSuite
## The particle recipes: each bus moment leaves the node its recipe makes under Fx.


func _fx(main: Node) -> Node2D:
	return main.get_node("Fx")


## Children of a native class ("CPUParticles2D") or a script class ("RingFlash"): is_class and
## get_class see only the native class, so a script class is matched by its global name.
func _children_of_type(node: Node, type: String) -> Array:
	var out := []
	for child in node.get_children():
		var script := child.get_script() as Script
		if child.is_class(type) or (script != null and script.get_global_name() == type):
			out.append(child)
	return out


func _particles(main: Node) -> Array:
	return _children_of_type(_fx(main), "CPUParticles2D")


func test_a_death_bursts_in_the_enemys_colour_with_a_smoke_puff() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	var shaman := active_shooter_on(main, player.global_position + Vector2(80, 0))
	var before := _particles(main).size()
	shaman.health.take_damage(100.0)
	var after := _particles(main)
	assert_int(after.size()).is_equal(before + 3)  # the hit burst, the death burst, the puff
	var burst: CPUParticles2D = after[-2]
	assert_that(burst.color).is_equal(shaman.def.death_color)
	var puff: CPUParticles2D = after[-1]
	assert_float(puff.gravity.y).is_less(0.0)  # smoke rises
	await wait_for_death_freeze()


func test_a_dash_leaves_three_fading_afterimages() -> void:
	var main := quiet_main()
	var player: Player = main.get_node("Player")
	await get_tree().process_frame
	Input.action_press("dash")
	await ticks(2)
	Input.action_release("dash")
	await real_seconds(Fx.AFTERIMAGE_GAP * 2 + 0.03)
	var ghosts := _children_of_type(_fx(main), "Sprite2D")
	assert_int(ghosts.size()).is_equal(Fx.AFTERIMAGES)
	var ghost: Sprite2D = ghosts[0]
	assert_object(ghost.texture).is_not_null()
	assert_float(ghost.modulate.a).is_less(Fx.AFTERIMAGE_TINT.a)
	assert_vector(ghost.offset).is_equal(player.sprite.offset)
	await real_seconds(Fx.AFTERIMAGE_LIFE + 0.05)
	await get_tree().process_frame
	assert_int(_children_of_type(_fx(main), "Sprite2D").size()).is_equal(0)


func test_a_wall_hit_sparks_and_a_bounce_sparks_brighter() -> void:
	var main := quiet_main()
	var before := _particles(main).size()
	Events.shot_hit_wall.emit(Vector2(100, 100))
	assert_int(_particles(main).size()).is_equal(before + 1)
	var sparks: CPUParticles2D = _particles(main)[-1]
	assert_int(sparks.amount).is_equal(Fx.WALL_SPARKS)
	Events.shot_bounced.emit(Vector2(100, 100))
	var bounce: CPUParticles2D = _particles(main)[-1]
	assert_int(bounce.amount).is_equal(Fx.BOUNCE_SPARKS)


func test_the_exit_opening_drops_dust_from_the_lintel() -> void:
	var main := quiet_main()
	Events.door_opened.emit(Vector2(224, 16))
	var dust: CPUParticles2D = _particles(main)[-1]
	assert_float(dust.gravity.y).is_greater(0.0)
	assert_vector(dust.global_position).is_equal(Vector2(224, 16))


func test_the_ring_flashes_and_the_boss_death_is_staged() -> void:
	var main := quiet_main()
	Events.boss_attacked.emit("ring", Vector2(200, 100))
	var flashes := _children_of_type(_fx(main), "RingFlash")
	assert_int(flashes.size()).is_equal(1)
	assert_vector((flashes[0] as Node2D).global_position).is_equal(Vector2(200, 100))
	var player: Player = main.get_node("Player")
	var boss := active_boss_on(main, player.global_position + Vector2(150, 0))
	var before := _particles(main).size()
	boss.health.take_damage(1000.0)
	await real_seconds(Fx.BOSS_DEATH_STAGE * 2 + 0.05)
	# The death burst and puff, two more stages; the 0.18 s hit burst has freed itself by now (the
	# 0.12 s kill freeze at time scale 0.05 leaves it about 0.34 s of particle time).
	assert_int(_particles(main).size()).is_greater_equal(before + 4)
	assert_int(_children_of_type(_fx(main), "RingFlash").size()).is_greater_equal(2)
