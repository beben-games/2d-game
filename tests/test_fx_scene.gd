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
