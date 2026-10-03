class_name SceneSuite
extends GdUnitTestSuite
## Base class for tests that drive the real main scene. Holds the helpers every scene suite
## needs and the after_test hygiene so no freeze, shake, or fixed seed leaks between tests.

const MAIN := "res://scenes/main.tscn"
const CHASER := "res://scenes/enemies/chaser.tscn"
const SHOOTER := "res://scenes/enemies/shooter.tscn"
const BOSS := "res://scenes/enemies/boss.tscn"
## Where the build screen saves the volumes under a test, so no suite writes user://settings.cfg.
## Per process, as PROFILE_SCRATCH: two runners must never share the file, since after_test removes it.
static var SETTINGS_SCRATCH: String = "user://test_scene_settings_%d.cfg" % OS.get_process_id()
## Where Profile.commit() writes under a test, so no suite reads or writes user://save.cfg. Per
## process: two runners on the same machine (two sessions) must never share the file, since
## after_test removes it.
static var PROFILE_SCRATCH: String = "user://test_profile_%d.cfg" % OS.get_process_id()
## wait_for_round's cap: five seconds of physics ticks, generous over the one-second gap.
const ROUND_WAIT_FRAMES := 300
## pass_the_gate's cap: two seconds of physics ticks, generous over the fade out and back.
const GATE_PASS_FRAMES := 120
## through_box's presses at most (each line takes two).
const BOX_PRESSES := 16
## The story every scene test starts on: a cast and no events, so nothing in the story fires in a
## suite that did not ask for it (use_story) and no test depends on the shipped prose.
const STORY_EMPTY := "res://tests/support/story_empty"

## True once the running test called use_story: after_test puts the empty fixture back.
var _story_used := false


## Subclasses that override this must call super(): time unfrozen, the profile starts every test
## empty, at the scratch path (missing, so the defaults), never the player's file; the story on the
## empty fixture.
func before_test() -> void:
	# The last test's scene can outlive its after_test by a frame or two (a hit then is a hitstop
	# that would freeze this test's first frames): every test starts on normal time.
	Juice.reset()
	Profile.path = PROFILE_SCRATCH
	Profile.reset()
	_story_used = false
	if Story.dir != STORY_EMPTY:  # loaded once, not re-parsed before every scene test
		Story.load_from(STORY_EMPTY)


## The story from a fixture directory for this test (tests/support/story); after_test goes back
## to the empty fixture. The shipped story is never reloaded between scene tests: no scene test
## reads it (test_story_data.gd reads data/story through StoryCatalog.load_dir directly).
func use_story(dir: String) -> void:
	_story_used = true
	Story.load_from(dir)


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
	if _story_used:
		_story_used = false
		Story.load_from(STORY_EMPTY)


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


## Polls until Main's round `index` has started (round_index set, round_started emitted in the
## same call), up to ROUND_WAIT_FRAMES. For a test waiting out the round gap: the gap is a
## real-time timer, so a wall-clock wait of the gap plus a margin can lose the race under load. A
## test asserting the next round has NOT started keeps its real-time wait.
func wait_for_round(main: Node, index: int) -> void:
	await wait_until(func() -> bool: return main.round_index == index, "round %d to start" % index, ROUND_WAIT_FRAMES)


## Waits `seconds` on the Clock, the engine's unscaled step (a real-time timer): wall time in the
## game and under --realtime, 1/60 s a frame under --fixed-fps. Neither a pause nor a hitstop slows it.
func real_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Blocks the main thread for `msec` of the OS clock, then lets a frame pass: only for the mixer's
## thread, which mixes in real time whatever the engine's step (a test that needs mixed audio, a
## playback position). Everything the game times is on the Clock: wait with real_seconds or ticks.
## A spin on frames would not do under --fixed-fps: it runs minutes of engine time (and the
## runner's timeout) in a wall-clock second.
func wall_msec(msec: int) -> void:
	OS.delay_msec(msec)
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


## The gate screen passed as the player passes it (Enter), then until the grounds are up and the
## black has lifted, up to GATE_PASS_FRAMES physics ticks; `each_tick`, when given, is called on
## every tick of the wait (a test sampling what holds under the black).
func pass_the_gate(main: Node, each_tick := Callable()) -> void:
	await get_tree().process_frame
	Input.action_press("ui_accept")
	await ticks(2)
	Input.action_release("ui_accept")
	var fade: ColorRect = main.get_node("Fade/Black")
	await wait_until(func() -> bool:
		if each_tick.is_valid():
			each_tick.call()
		return main.get("grounds") != null and fade.color.a == 0.0, "the gate's pass into the grounds", GATE_PASS_FRAMES)


## Presses through the open text box to its end: E for each line (one to complete it, one to pass
## it), `choice` (the first by default) at each list of choices; fails when it does not shut.
## Nothing when no box is open.
func through_box(main: Node, choice := "pick_1") -> void:
	var box: DialogueBox = main.get_node("DialogueBox")
	for i in BOX_PRESSES:
		if not box.is_open():
			return
		await press_action(choice if box.choosing() else "interact")
	assert_bool(box.is_open()).override_failure_message("the box did not shut").is_false()


## From the Ludus (through its top door) or the Hypogeum: the player onto the lift, E, the fade
## to black and the run's start (the grounds gone), the fade back; the new Room's runner is
## turned off like quiet_main's.
func take_the_lift(main: Node) -> void:
	var grounds: Grounds = main.get("grounds")
	if grounds.room_def.id == "ludus":
		await go_through(main, "hypogeum")
	await stand_at(main, "lift")
	await interact()
	await wait_until(func() -> bool: return main.get("grounds") == null, "the lift to take the grounds down", 60)
	await real_seconds(Main.FADE_TIME + 0.2)
	(main.get("room") as Room).wave_runner.enabled = false


## The player onto the grounds' door to room `to`, E, and the walk: until that room is up and
## the black has lifted (the fade out, the room, the fade back).
func go_through(main: Node, to: String) -> void:
	var door: Door = (main.get("grounds") as Grounds).door_to(to)
	if door == null:
		fail("go_through: no door to %s in the %s" % [to, (main.get("grounds") as Grounds).room_def.id])
		return
	await stand_at(main, door.id)
	await interact()
	var fade: ColorRect = main.get_node("Fade/Black")
	await wait_until(func() -> bool:
		var grounds: Grounds = main.get("grounds")
		return grounds != null and grounds.room_def.id == to and fade.color.a == 0.0, "the walk to the %s" % to, 120)


## The player on the grounds' interactable `id` (its stand position), until the grounds take it
## as the focus: the area pairs with a placed body two or three ticks later.
func stand_at(main: Node, id: String) -> void:
	var grounds: Grounds = main.get("grounds")
	var item := grounds.interactable(id)
	if item == null:
		fail("stand_at: no %s in the %s" % [id, grounds.room_def.id])
		return
	player_of(main).global_position = item.stand_position()
	await wait_until(func() -> bool: return grounds.focus == item, "the %s to take the focus" % id, 30)


## E: the interact action pressed and released through the real input path.
func interact() -> void:
	await press_action("interact")


## An action's press, two physics ticks, and its release, as InputEventActions fed to Input:
## each is delivered at the next frame's flush, through _unhandled_input like a key (a bare
## Input.action_press reaches only the pollers). Starts on a fresh frame, so a poller's
## is_action_just_pressed sees the press; ends a frame after the release.
func press_action(action: String) -> void:
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		if pressed:
			await ticks(2)
	await get_tree().process_frame


## The control's centre in window pixels. The rect is in the canvas; a mouse event carries window
## pixels, and the headless runner's window is tiny and scaled, so the centre goes through the
## viewport's final transform.
func window_centre(control: Control) -> Vector2:
	return get_viewport().get_final_transform() * control.get_global_rect().get_center()


## A left click (press and release, a frame each) on the control's centre.
func click_control(control: Control) -> void:
	await click_at(window_centre(control))


## A left click (press and release, a frame each) at a window position.
func click_at(window_position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = pressed
		press.position = window_position
		press.global_position = window_position
		Input.parse_input_event(press)
		await get_tree().process_frame


## A mouse motion to the control's centre, so the viewport reports the hover: mouse_entered on
## it, mouse_exited on the one left. The next frame delivers it.
func hover_control(control: Control) -> void:
	await hover_at(window_centre(control))


## A mouse motion to a window position.
func hover_at(window_position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = window_position
	motion.global_position = window_position
	Input.parse_input_event(motion)
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


## Clears the round and takes the first card that is not a Switch and not the crowd's lock once
## the picker is up, so the gap to the next round begins. For tests about what comes after. Never
## a Switch: with a weapon rank owned (an earlier pick, on the suite's random seed) a Switch owes
## refund rounds, which re-open the picker and hold the gap; at most one Switch is offered. Never
## the locked card (a round ending at Boo, which a test reaches by lowering the meter or taking a
## hit: an untouched clear ends at Quiet): the pick would be refused. A lock leaves two cards
## pickable at least, so another card is there.
func clear_and_pick(main: Node) -> void:
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)  # the menu opens after a real-time beat
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	assert_bool(menu.is_open()).override_failure_message("clear_and_pick: the picker did not open").is_true()
	var index := -1
	for i in menu.offers.size():
		if menu.offers[i].kind != UpgradeDef.Kind.SWITCH and i != menu.locked:
			index = i
			break
	assert_int(index).override_failure_message("clear_and_pick: only a Switch or a locked card on offer").is_greater_equal(0)
	menu.choose(index)
	await get_tree().process_frame


## Index of the first card of `kind` on offer, or -1.
func offer_index(menu: UpgradeMenu, kind: UpgradeDef.Kind) -> int:
	for i in menu.offers.size():
		if menu.offers[i].kind == kind:
			return i
	return -1
