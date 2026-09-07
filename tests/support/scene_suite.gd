class_name SceneSuite
extends GdUnitTestSuite
## Base class for tests that drive the real main scene. Holds the helpers every scene suite
## needs and the after_test hygiene so no freeze, shake, or fixed seed leaks between tests.

const MAIN := "res://scenes/main.tscn"
const CHASER := "res://scenes/enemies/chaser.tscn"


## Subclasses that override this must call super(), or freezes and fixed seeds leak into later tests.
func after_test() -> void:
	Juice.reset()
	RunState.start_run()


func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func real_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## The kill freeze is real time, so a dead enemy is only gone after it plus one physics frame.
func wait_for_death_freeze() -> void:
	await real_seconds(Enemy.DEATH_HITSTOP + 0.05)
	await get_tree().physics_frame


## The main scene with nothing spawning on its own. Pass a seed for placement-dependent tests.
func quiet_main(seed_value: int = -1) -> Node:
	if seed_value >= 0:
		RunState.start_run(seed_value)
	var runner := scene_runner(MAIN)
	var main: Node = runner.scene()
	main.get_node("Spawner").enabled = false
	return main


## Places an ACTIVE chaser by skipping its spawn delay. Stationary by default so the tests own
## the geometry; pass false to keep the def's speed and let it chase.
func active_chaser_on(main: Node, at: Vector2, stationary := true) -> Enemy:
	var enemy: Enemy = load(CHASER).instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 0.0
	if stationary:
		enemy.def.speed = 0.0
	enemies_of(main).add_child(enemy)
	enemy.global_position = at
	return enemy


## The container enemies live in. Task 4 moves it under the Room; only this helper knows where.
func enemies_of(main: Node) -> Node2D:
	return main.get_node("Enemies")


func projectiles_of(main: Node) -> Node2D:
	return main.get_node("Projectiles")
