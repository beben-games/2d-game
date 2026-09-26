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
## Where Profile.commit() writes under a test, so no suite reads or writes user://save.cfg.
const PROFILE_SCRATCH := "user://test_profile.cfg"


## Subclasses that override this must call super(): the profile starts every test empty, at the
## scratch path (missing, so the defaults), never the player's file.
func before_test() -> void:
	Profile.path = PROFILE_SCRATCH
	Profile.reset()


## Subclasses that override this must `await super()` (an await inside: a bare super() would
## run the rest of this a frame later, under the next test), or freezes, fixed seeds, audio
## counters, and a committed profile leak into later tests. The frame's await first: a node
## freed in the test's last line (a stage swapped, a shot spent) is queued, and gdUnit's orphan
## count runs right after this.
func after_test() -> void:
	await get_tree().process_frame
	get_tree().paused = false
	Juice.reset()
	RunState.start_run()
	await get_tree().process_frame  # run_started rebuilds the HUD's strip: its old children are queued frees until a frame passes
	Audio.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_SCRATCH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_SCRATCH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_SCRATCH + Save.BACKUP_SUFFIX))
	Profile.reset()


func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Polls `condition` once a physics frame up to `max_frames`, then asserts it held, naming `what`.
## For an event whose tick is not fixed (an area pairing, a flight's end): never a bare ticks(n).
func wait_until(condition: Callable, what: String, max_frames := 300) -> void:
	for i in max_frames:
		if condition.call():
			break
		await get_tree().physics_frame
	assert_bool(condition.call()).override_failure_message("waited %d frames for %s" % [max_frames, what]).is_true()


func real_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## A wall-clock wait: Audio's minimum gap (Time.get_ticks_msec) and the mixer run on real time,
## and the runner's frame timers can fire ahead of the clock by tens of milliseconds.
func wall_msec(msec: int) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < msec:
		await get_tree().process_frame


func plays(name: String) -> int:
	return int(Audio.plays.get(name, 0))


## A lethal chaser beside the player at 1 hp (the fall lands within a few ticks), then the
## verdict scene's real time (the hold, the build-up's drift and pause, the thumb's stay, the
## fade) through to the gate screen, asserted up.
func fall_to_the_gate(main: Node) -> void:
	var player := player_of(main)
	player.hp = 1
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(5)
	assert_bool(player.dead).override_failure_message("fall_to_the_gate: the player did not fall").is_true()
	await real_seconds(Main.VERDICT_HOLD + Main.VERDICT_DRIFT + Main.VERDICT_PAUSE + Main.VERDICT_SHOW + Main.FADE_TIME + 0.3)
	assert_bool((main.get_node("GateScreen") as GateScreen).is_open()).override_failure_message("fall_to_the_gate: the gate screen is not up").is_true()


## The player onto the grounds' gate station, the fade to black and the run's start (the
## grounds gone), the fade back; the new Room's runner is turned off like quiet_main's.
func pass_the_gate(main: Node) -> void:
	var grounds: Grounds = main.get_node("Grounds")
	player_of(main).global_position = grounds.station("gate").stand_position()
	await wait_until(func() -> bool: return main.get("grounds") == null, "the gate to take the grounds down", 60)
	await real_seconds(Main.FADE_TIME + 0.2)
	(main.get("room") as Room).wave_runner.enabled = false


## A left click (press and release, a frame each) on the control's centre. The rect is in the
## canvas; a mouse event carries window pixels, and the headless runner's window is tiny and
## scaled, so the centre goes through the viewport's final transform.
func click_control(control: Control) -> void:
	var centre := get_viewport().get_final_transform() * control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = pressed
		press.position = centre
		press.global_position = centre
		Input.parse_input_event(press)
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
## (the one Room's runner stays off for the whole run unless a test turns it on), and the
## volumes saved to the scratch file instead of the player's settings.
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


## Gives the boss its own copy of its def: a test that writes a field through the shared boss.tres
## (a cached resource) would leak that value into every later instantiation.
func own_def(boss: Boss) -> void:
	boss.def = boss.def.duplicate()


## An ACTIVE boss with no fade-in. Stationary keeps it from approaching; the timings are the def's.
func active_boss_on(main: Node, at: Vector2, stationary := true) -> Boss:
	var boss: Boss = load(BOSS).instantiate()
	own_def(boss)
	boss.def.spawn_delay = 0.0
	if stationary:
		boss.def.speed = 0.0
	enemies_of(main).add_child(boss)
	boss.global_position = at
	return boss


## The container enemies live in, under the Room; only this helper knows where.
func enemies_of(main: Node) -> Node2D:
	return main.get_node("Room/Enemies")


func player_of(main: Node) -> Player:
	return main.get_node("Player")


func hud_of(main: Node) -> Hud:
	return main.get_node("HUD")


func projectiles_of(main: Node) -> Node2D:
	return main.get_node("Room/Projectiles")


## Main built around a series made in code, quiet. Use for round-flow tests.
func quiet_main_with_series(series: SeriesDef) -> Node:
	var main: Main = load(MAIN).instantiate()
	main.series_def = series
	main.start_at_title = false
	add_child(main)
	return quiet(main)


func _one_wave_of(scene: PackedScene) -> WaveTable:
	var g := SpawnGroup.new()
	g.enemy = scene
	g.count = 1
	var w := WaveDef.new()
	w.groups = [g]
	w.breather = 0.0
	var t := WaveTable.new()
	t.waves = [w]
	return t


## A series of `count` rounds, each one wave of one chaser.
func tiny_series(count: int) -> SeriesDef:
	var s := SeriesDef.new()
	for i in count:
		var r := RoundDef.new()
		r.waves = _one_wave_of(load(CHASER))
		s.rounds.append(r)
	return s


## A one-round series whose only wave is the boss.
func boss_series() -> SeriesDef:
	var r := RoundDef.new()
	r.waves = _one_wave_of(load(BOSS))
	var s := SeriesDef.new()
	s.rounds.append(r)
	return s


## Clears the round and takes the first card once the picker is up, so the gap to the next round
## begins. For tests about what comes after.
func clear_and_pick(main: Node) -> void:
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)  # the menu opens after a real-time beat
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	assert_bool(menu.is_open()).override_failure_message("clear_and_pick: the picker did not open").is_true()
	menu.choose(0)
	await get_tree().process_frame


## Index of the first card of `kind` on offer, or -1.
func offer_index(menu: UpgradeMenu, kind: UpgradeDef.Kind) -> int:
	for i in menu.offers.size():
		if menu.offers[i].kind == kind:
			return i
	return -1
