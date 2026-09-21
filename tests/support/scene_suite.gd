class_name SceneSuite
extends GdUnitTestSuite
## Base class for tests that drive the real main scene. Holds the helpers every scene suite
## needs and the after_test hygiene so no freeze, shake, or fixed seed leaks between tests.

const MAIN := "res://scenes/main.tscn"
const CHASER := "res://scenes/enemies/chaser.tscn"
const SHOOTER := "res://scenes/enemies/shooter.tscn"
const BOSS := "res://scenes/enemies/boss.tscn"
## Where the build screen saves the volumes under a test, so no suite writes user://settings.cfg.
const SETTINGS_SCRATCH := "user://test_scene_settings.cfg"


## Subclasses that override this must call super(), or freezes, fixed seeds, and audio counters
## leak into later tests.
func after_test() -> void:
	get_tree().paused = false
	Juice.reset()
	RunState.start_run()
	Audio.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_SCRATCH))


func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func real_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## A wall-clock wait: Audio's minimum gap (Time.get_ticks_msec) and the mixer run on real time,
## and the runner's frame timers can fire ahead of the clock by tens of milliseconds.
func wall_msec(msec: int) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < msec:
		await get_tree().process_frame


## The kill freeze is real time, so a dead enemy is only gone after it plus one physics frame.
func wait_for_death_freeze() -> void:
	await real_seconds(Enemy.DEATH_HITSTOP + 0.05)
	await get_tree().physics_frame


## The main scene with nothing spawning on its own and no title. Pass a seed for placement-dependent tests.
func quiet_main(seed_value: int = -1) -> Node:
	if seed_value >= 0:
		RunState.start_run(seed_value)
	var main: Main = load(MAIN).instantiate()
	main.start_at_title = false
	add_child(main)
	return quiet(main)


## A Main just added to the tree, made quiet: freed after the test, nothing spawning on its own
## (only in the first room: a room entered later gets a fresh runner), and the volumes saved to
## the scratch file instead of the player's settings.
func quiet(main: Main) -> Main:
	auto_free(main)
	main.get_node("Room/WaveRunner").enabled = false
	main.get_node("BuildScreen").settings_path = SETTINGS_SCRATCH
	return main


## Places an ACTIVE chaser by skipping its spawn delay. Stationary by default so the tests own
## the geometry; pass false to keep the def's speed and let it chase.
func active_chaser_on(main: Node, at: Vector2, stationary := true) -> Enemy:
	return _active_enemy_on(main, CHASER, at, stationary)


## Same as active_chaser_on for the Shooter. Stationary keeps it from repositioning.
func active_shooter_on(main: Node, at: Vector2, stationary := true) -> Enemy:
	return _active_enemy_on(main, SHOOTER, at, stationary)


func _active_enemy_on(main: Node, scene_path: String, at: Vector2, stationary: bool) -> Enemy:
	var enemy: Enemy = load(scene_path).instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 0.0
	if stationary:
		enemy.def.speed = 0.0
	enemies_of(main).add_child(enemy)
	enemy.global_position = at
	return enemy


## An ACTIVE boss with no fade-in. Stationary keeps it from approaching; the timings are the def's.
func active_boss_on(main: Node, at: Vector2, stationary := true) -> Boss:
	var boss: Boss = load(BOSS).instantiate()
	boss.def = boss.def.duplicate()
	boss.def.spawn_delay = 0.0
	if stationary:
		boss.def.speed = 0.0
	enemies_of(main).add_child(boss)
	boss.global_position = at
	return boss


## The container enemies live in, under the current Room; only this helper knows where.
func enemies_of(main: Node) -> Node2D:
	return main.get_node("Room/Enemies")


func projectiles_of(main: Node) -> Node2D:
	return main.get_node("Room/Projectiles")


## Main built around a floor made in code, quiet. Use for room-flow tests.
func quiet_main_with_floor(floor_def: FloorDef) -> Node:
	var main: Main = load(MAIN).instantiate()
	main.floor_def = floor_def
	main.start_at_title = false
	add_child(main)
	return quiet(main)


## A floor of `count` rooms, each one wave of one chaser, exits on top.
func tiny_floor(count: int) -> FloorDef:
	var f := FloorDef.new()
	for i in count:
		var g := SpawnGroup.new()
		g.enemy = load(CHASER)
		g.count = 1
		var w := WaveDef.new()
		w.groups = [g]
		w.breather = 0.0
		var t := WaveTable.new()
		t.waves = [w]
		var r := RoomDef.new()
		r.waves = t
		f.rooms.append(r)
	return f


## A one-room floor whose only wave is the boss.
func boss_floor() -> FloorDef:
	var g := SpawnGroup.new()
	g.enemy = load(BOSS)
	g.count = 1
	var w := WaveDef.new()
	w.groups = [g]
	w.breather = 0.0
	var t := WaveTable.new()
	t.waves = [w]
	var r := RoomDef.new()
	r.waves = t
	var f := FloorDef.new()
	f.rooms.append(r)
	return f


## Clears the room and takes the first card, so the exit opens. For tests about what comes after.
func clear_and_pick(main: Node) -> void:
	Events.room_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)  # the menu opens after a real-time beat
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	if menu.is_open():
		menu.choose(0)
	await get_tree().process_frame


## Index of the first card of `kind` on offer, or -1.
func offer_index(menu: UpgradeMenu, kind: UpgradeDef.Kind) -> int:
	for i in menu.offers.size():
		if menu.offers[i].kind == kind:
			return i
	return -1
