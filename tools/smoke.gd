extends Node
## Boots the main scene, runs a named scenario with simulated input, saves a screenshot, quits.
## Usage: tools/smoke.sh <scenario>. Scenarios: idle, move, combat, kill, round, fall, pick, roar, title, pause, boss, grounds, rooms, talk.
## Prints machine-readable lines prefixed SMOKE_ for tools/smoke.sh to check.
## Waits are counted in physics ticks (60 Hz) because gameplay runs in _physics_process;
## render frames vary with the display refresh rate and would make timings machine-dependent.
## A 30 s real-time watchdog quits with code 3 if a scenario hangs.

const MAIN := preload("res://scenes/main.tscn")
const SMOKE_SERIES := "res://tools/smoke_series.tres"  # two rounds of one chaser each
const SMOKE_BOSS_SERIES := "res://tools/smoke_boss_series.tres"  # one round whose only wave is the boss
const WATCHDOG_SECONDS := 30.0
const IMAGE_SAMPLE_STEP := 32
const MAX_PICKS := 20  # a refund chain is at most a handful of rounds; more means the menu is stuck
## Past a real-time timer's end: it fires on the first frame after its time, so the suites' margin holds here too.
const TIMER_MARGIN := 0.1
## Presses through a text box at most this many times (each line takes two) before giving up.
const MAX_BOX_PRESSES := 40
## Past the longest line's reveal (StoryCatalog.BOX_LINE_CAP letters at the box's rate), seconds.
const LINE_WHOLE_MARGIN := 0.5

var scenario := "idle"


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func() -> void:
		print("SMOKE_TIMEOUT")
		get_tree().quit(3))
	# The project runs fullscreen; screenshots must stay 1280x720 regardless of the display.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
	# The tool must never touch the player's save: a scenario's verdict commits to a scratch file,
	# per process so two tools never share one; removed again at the end.
	Profile.path = "user://smoke_profile_%d.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))  # an earlier run's, before the reset reads it
	Profile.reset()
	var main := MAIN.instantiate()
	if scenario in ["round", "fall", "pick", "roar"]:
		main.series_def = load(SMOKE_SERIES)
	elif scenario == "boss":
		main.series_def = load(SMOKE_BOSS_SERIES)
	main.restart_requested.connect(func() -> void: print("SMOKE_RESTART_REQUESTED"))
	main.start_at_title = scenario == "title"
	add_child(main)
	# Only combat, round, pick, roar, and boss need the waves: combat counts the first wave, round,
	# pick, and roar clear one, boss waits for the runner to place the boss.
	if scenario not in ["combat", "round", "pick", "roar", "boss"]:
		main.get_node("Room/WaveRunner").enabled = false
	var ticks_at_start := Engine.get_physics_frames()
	await _ticks(5)
	var ok: bool = await _run_scenario(main)
	print("SMOKE_AUDIO %d" % _total_plays())
	print("SMOKE_PHYSICS_TICKS %d" % (Engine.get_physics_frames() - ticks_at_start))
	if not ok:
		get_tree().quit(2)
		return
	await _capture("smoke_%s" % scenario)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))
	print("SMOKE_DONE scenario=%s" % scenario)
	get_tree().quit(0)


## Returns false when the scenario cannot run; the caller then exits without a screenshot.
func _run_scenario(main: Node) -> bool:
	match scenario:
		"idle":
			await _ticks(30)
		"move":
			var player := _require_player()
			if player == null:
				return false
			var start := player.global_position
			print("SMOKE_PLAYER_START %s" % start)
			Input.action_press("move_right")
			await _ticks(52)
			# Dash late so its puff (0.25 s) is still on screen at the capture. A press is seen by
			# is_action_just_pressed on the next tick, so hold it for two.
			Input.action_press("dash")
			await _ticks(2)
			Input.action_release("dash")
			print("SMOKE_DASHED %s" % (player.dash_left > 0.0))
			await _ticks(6)
			Input.action_release("move_right")
			print("SMOKE_PLAYER_END %s" % player.global_position)
			print("SMOKE_PLAYER_DELTA %s" % (player.global_position - start))
		"combat":
			var player := _require_player()
			if player == null:
				return false
			Input.action_press("shoot")
			await _ticks(150)
			Input.action_release("shoot")
			print("SMOKE_ENEMIES_ALIVE %d" % main.get_node("Room/Enemies").get_child_count())
			print("SMOKE_PROJECTILES_ALIVE %d" % main.get_node("Room/Projectiles").get_child_count())
			print("SMOKE_KILLS %d" % RunState.kills)
			print("SMOKE_PLAYER_HP %d" % player.hp)
		"kill":
			var player := _require_player()
			if player == null:
				return false
			var enemy := _chaser_at(main, player.global_position + Vector2(80, 0))
			player.aim_override = enemy.global_position
			Input.action_press("shoot")
			await _ticks(90)
			Input.action_release("shoot")
			print("SMOKE_KILLS %d" % RunState.kills)
		"round":
			var player := _require_player()
			if player == null:
				return false
			await _clear_first_round(main, player)
			await _picker_beat()
			await _pick_first_card(main)
			await get_tree().create_timer(Main.ROUND_GAP + TIMER_MARGIN, true, false, true).timeout  # the gap is real time
			await get_tree().physics_frame
			print("SMOKE_ROUND %d" % main.round_index)
		"fall":
			var player := _require_player()
			if player == null:
				return false
			var verdicts: Array[bool] = []
			Events.verdict_given.connect(func(up: bool) -> void: verdicts.append(up), CONNECT_ONE_SHOT)
			var narrated: Array[String] = []
			var on_started := func(id: String) -> void: narrated.append(id)
			Events.event_started.connect(on_started)
			player.hp = 1
			_chaser_at(main, player.global_position + Vector2(4, 0))
			await _ticks(10)
			# The verdict scene is real time: the hold, the build-up (the camera's drift to the box
			# under the drum roll, the held pause), then the thumb over the box with the narrator's
			# line at the bottom (captured once the line is whole, with the camera on the box:
			# smoke_fall.png is the gate screen over the black, dark by design; SMOKE_NARRATOR is the
			# trigger of the line up, none without one), its stay, the fade, then the gate screen.
			await get_tree().create_timer(Main.VERDICT_HOLD + TIMER_MARGIN, true, false, true).timeout
			print("SMOKE_DRIFT %s roll=%d" % [main.camera.drifting, int(Audio.plays.get("verdict_roll", 0))])
			await get_tree().create_timer(Main.VERDICT_DRIFT + Main.VERDICT_PAUSE, true, false, true).timeout
			print("SMOKE_VERDICT %s" % ("none" if verdicts.is_empty() else ("up" if verdicts[0] else "down")))
			var box: DialogueBox = main.get_node("DialogueBox")
			await _line_whole(box)
			Events.event_started.disconnect(on_started)
			var trigger := "none"
			if box.is_timed() and not narrated.is_empty():
				trigger = (Story.catalog.by_id[narrated.back()] as StoryEvent).trigger
			print("SMOKE_NARRATOR %s" % trigger)
			await _capture("smoke_fall_verdict")
			await get_tree().create_timer(Main.VERDICT_SHOW + Main.FADE_TIME + 0.3, true, false, true).timeout
			print("SMOKE_GATE %s" % main.get_node("GateScreen/Center/Box/Title").text)
		"pick":
			var player := _require_player()
			if player == null:
				return false
			await _clear_first_round(main, player)
			await _picker_beat()
			var menu: UpgradeMenu = main.get_node("UpgradeMenu")
			print("SMOKE_MENU_OPEN %s" % menu.is_open())
			await _capture("smoke_pick_menu")  # the cards, paused
			await _pick_first_card(main)
			await _ticks(10)
		"roar":
			var player := _require_player()
			if player == null:
				return false
			RunState.favour = FavourRules.MAX  # the round ends on a Roar: four cards, one the crowd's
			await _clear_first_round(main, player)
			await _picker_beat()
			var menu: UpgradeMenu = main.get_node("UpgradeMenu")
			print("SMOKE_MENU_OPEN %s" % menu.is_open())
			await get_tree().create_timer(UpgradeMenu.CROWD_CARD_DELAY + UpgradeMenu.CROWD_CARD_DROP + TIMER_MARGIN, true, false, true).timeout
			var built := 0
			for card in menu.cards.get_children():
				built += int(card is Button)
			print("SMOKE_ROAR %d" % built)
			print("SMOKE_CROWD_ROARS %d" % int(Audio.plays.get("crowd_roar", 0)))
			await _capture("smoke_roar_menu")  # the four cards, the crowd's landed in its slot
			await _pick_first_card(main)
			await _ticks(10)
		"title":
			var title: Title = main.get_node("Title")
			print("SMOKE_TITLE_OPEN %s" % title.is_open())
			await _capture("smoke_title_screen")  # the front door, paused; smoke_title.png is the run after Play
			await get_tree().process_frame
			Input.action_press("title_play")  # Enter: ui_accept would include Space, the dash
			await _ticks(2)
			Input.action_release("title_play")
			await _ticks(10)
			print("SMOKE_TITLE played=%s paused=%s" % [not title.is_open(), get_tree().paused])
		"pause":
			var screen: BuildScreen = main.get_node("BuildScreen")
			screen.settings_path = "user://smoke_settings.cfg"  # the tool must not rewrite the player's settings
			await get_tree().process_frame
			Input.action_press("pause")
			await _ticks(2)
			Input.action_release("pause")
			print("SMOKE_PAUSE open=%s paused=%s" % [screen.is_open(), get_tree().paused])
			await _capture("smoke_pause_menu")  # the Options tab (Esc opened it), paused; smoke_pause.png is the run after the close
			await get_tree().process_frame
			Input.action_press("pause")
			await _ticks(2)
			Input.action_release("pause")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(screen.settings_path))  # the close saved it
		"grounds":
			var player := _require_player()
			if player == null:
				return false
			# A returned profile's Play lands in the grounds (the scratch save, never committed here);
			# money enough for a rank of every line, so the capture shows the rows lit. The first
			# arrival's box comes up at once: its line captured whole (smoke_arrival.png,
			# SMOKE_ARRIVAL <event id>), then pressed through.
			Profile.save.set_flag("returned", true)
			Profile.save.money = 500
			var started: Array[String] = []
			var on_started := func(id: String) -> void: started.append(id)
			Events.event_started.connect(on_started)
			main.play()
			var grounds: Grounds = main.get_node_or_null("Grounds")
			if grounds == null:
				push_error("Play on a returned profile did not enter the grounds")
				return false
			var box: DialogueBox = main.get_node("DialogueBox")
			await _line_whole(box)
			print("SMOKE_ARRIVAL %s open=%s" % [" ".join(started), box.is_open()])
			await _capture("smoke_arrival")
			if not await _through_box(box):
				return false
			# Walk to the post from below until it is the focus (nothing opens on contact; the
			# lanista stands at its right), capture the key cap over it with the lanista's mark
			# beside it, then E: the lanista's new word, pressed through, then the panel.
			var post: Station = grounds.station("post")
			player.global_position = post.stand_position() + Vector2(0, 40)
			Input.action_press("move_up")
			for i in 120:
				await get_tree().physics_frame
				if grounds.focus == post:
					break
			Input.action_release("move_up")
			await _ticks(10)  # the body's slide out
			var panel: TrainingPanel = main.get_node("TrainingPanel")
			print("SMOKE_GROUNDS_FOCUS %s open=%s mark=%s" % ["post" if grounds.focus == post else "none", panel.is_open(), post.keeper.mark.visible])
			await _capture("smoke_grounds_key")  # the key cap over the post, no panel yet
			started.clear()
			await _press_event("interact")
			if not await _through_box(box):
				return false
			Events.event_started.disconnect(on_started)
			await _ticks(5)
			print("SMOKE_GROUNDS_WORD %s" % " ".join(started))
			print("SMOKE_GROUNDS %s" % ("post" if panel.is_open() else "none"))
		"rooms":
			var player := _require_player()
			if player == null:
				return false
			# The map walked by real input on a returned profile that has seen the Spoliarium (the
			# scratch save, never committed here): each room captured once, on its first arrival,
			# as reports/smoke_room_<id>.png, and the key cap over the Ludus's left door before E
			# as reports/smoke_room_door_key.png.
			Profile.save.set_flag("returned", true)
			Profile.save.set_flag("spoliarium_seen", true)
			main.play()
			if main.get("grounds") == null:
				push_error("Play on a returned profile did not enter the grounds")
				return false
			if not await _through_box(main.get_node("DialogueBox")):  # the first arrival's word
				return false
			var seen: Array[String] = []
			for to: String in ["", "armamentarium", "ludus", "sanitarium", "ludus", "hypogeum", "spoliarium"]:
				if to != "" and not await _walk_through(main, player, to, "smoke_room_door_key" if seen.size() == 1 else ""):
					return false
				var here: String = (main.get("grounds") as Grounds).room_def.id
				if here in seen:
					continue
				seen.append(here)
				await _ticks(10)
				await _capture("smoke_room_%s" % here)
			print("SMOKE_ROOMS %s" % " ".join(seen))
		"talk":
			var player := _require_player()
			if player == null:
				return false
			# The text box on the shipped story: a returned profile, the Ludus (the first arrival's
			# word pressed through), the veteran's mark captured as reports/smoke_talk_mark.png, the
			# walk in until the key cap stands over them (smoke_talk_key.png), E, the first line
			# whole (smoke_talk_box.png), the choices up (smoke_talk_choices.png), the first taken
			# and its line passed. The end capture is the Ludus after the box.
			Profile.save.set_flag("returned", true)
			main.play()
			var grounds: Grounds = main.get("grounds")
			if grounds == null:
				push_error("Play on a returned profile did not enter the grounds")
				return false
			if not await _through_box(main.get_node("DialogueBox")):
				return false
			var veteran := grounds.interactable("veteran") as Character
			if veteran == null:
				push_error("no veteran in the Ludus")
				return false
			player.global_position = veteran.stand_position() + Vector2(48, 0)
			await _ticks(10)
			print("SMOKE_TALK_MARK %s" % veteran.figure.mark.visible)
			await _capture("smoke_talk_mark")
			Input.action_press("move_left")
			for i in 120:
				await get_tree().physics_frame
				if grounds.focus == veteran:
					break
			Input.action_release("move_left")
			await _ticks(10)
			await _capture("smoke_talk_key")
			var box: DialogueBox = main.get_node("DialogueBox")
			var started: Array[String] = []
			Events.event_started.connect(func(id: String) -> void: started.append(id), CONNECT_ONE_SHOT)
			await _press_event("interact")
			if not box.is_open():
				push_error("E on the veteran opened no box")
				return false
			await _line_whole(box)
			await _capture("smoke_talk_box")
			for i in 8:
				if box.choosing() or not box.is_open():
					break
				await _press_event("interact")
			print("SMOKE_TALK_CHOICES %d" % box.choice_buttons().size())
			await _capture("smoke_talk_choices")
			await _press_event("pick_1")
			for i in 8:
				if not box.is_open():
					break
				await _press_event("interact")
			print("SMOKE_TALK_BLEEPS %d" % int(Audio.plays.get("bleep_veteran", 0)))
			print("SMOKE_TALK %s open=%s" % [" ".join(started), box.is_open()])
			await _ticks(10)
		"boss":
			var player := _require_player()
			if player == null:
				return false
			var boss: Boss = null
			for i in 600:  # the runner places it after the breather; it is active after its fade-in
				await get_tree().physics_frame
				boss = get_tree().get_first_node_in_group("boss") as Boss
				if boss != null and boss.is_harmful():
					break
			if boss == null:
				push_error("no boss spawned")
				return false
			Input.action_press("shoot")
			for i in 300:  # shoot until the first ring is out, so the capture shows the fight
				player.aim_override = boss.global_position
				await get_tree().physics_frame
				if Audio.plays.get("boss_ring", 0) > 0:
					break
			await _ticks(6)
			Input.action_release("shoot")
			print("SMOKE_BOSS_HP %d of %d" % [int(boss.health.hp), int(boss.def.max_hp)])
			print("SMOKE_BOSS_BAR %s" % main.get_node("HUD").boss_bar.visible)
		_:
			push_error("unknown scenario %s" % scenario)
			return false
	return true


## From a step back on the floor, the player walks (a held move) into the door to room `to` until
## it is the focus, then E, and the walk: until that room is up and the black has lifted. False,
## with the error out, when the door is missing, never takes the focus, or the walk never lands.
## With a capture name, the screen is saved with the key cap over the door before E.
func _walk_through(main: Node, player: Player, to: String, capture := "") -> bool:
	var grounds: Grounds = main.get("grounds")
	var door: Door = grounds.door_to(to)
	if door == null:
		push_error("no door to %s in the %s" % [to, grounds.room_def.id])
		return false
	var action := {Vector2.LEFT: "move_left", Vector2.RIGHT: "move_right", Vector2.UP: "move_up", Vector2.DOWN: "move_down"}[-door.inward()] as String
	player.global_position = door.stand_position() + door.inward() * 40.0
	Input.action_press(action)
	for i in 120:
		await get_tree().physics_frame
		if grounds.focus == door:
			break
	Input.action_release(action)
	if grounds.focus != door:
		push_error("the door to %s did not take the focus" % to)
		return false
	await _ticks(5)
	if capture != "":
		await _capture(capture)
	await _press_event("interact")
	var fade: ColorRect = main.get_node("Fade/Black")
	for i in 120:
		var now: Grounds = main.get("grounds")
		if now != null and now.room_def.id == to and fade.color.a == 0.0:
			return true
		await get_tree().physics_frame
	push_error("the walk to %s did not land" % to)
	return false


## Until the line on show in the box is whole, on the wall clock (the reveal's own), at most the
## longest line's reveal plus LINE_WHOLE_MARGIN; an error when it is still growing then.
func _line_whole(box: DialogueBox) -> void:
	var deadline := Time.get_ticks_msec() + int((StoryCatalog.BOX_LINE_CAP / box.reveal_per_second + LINE_WHOLE_MARGIN) * 1000.0)
	while box.is_revealing() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	if box.is_revealing():
		push_error("the box's line was still growing past the longest line's reveal")


## E (or the first choice's key) until the box has shut; false, with the error out, when it never
## does.
func _through_box(box: DialogueBox) -> bool:
	for i in MAX_BOX_PRESSES:
		if not box.is_open():
			return true
		await _press_event("pick_1" if box.choosing() else "interact")
	if box.is_open():
		push_error("the text box did not shut")
		return false
	return true


## Also fixes the aim to the right so screenshots never depend on where the real mouse is.
func _require_player() -> Player:
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("scenario %s needs a player in group 'player'" % scenario)
		return null
	player.aim_override = player.global_position + Vector2(200, 0)
	return player


## Holds shoot on whatever spawns until the round clears (up to 10 s). Prints SMOKE_CLEARED.
func _clear_first_round(main: Node, player: Player) -> void:
	var cleared := [false]
	# Stays connected if the round never clears; fine, the process quits right after.
	Events.round_cleared.connect(func() -> void: cleared[0] = true, CONNECT_ONE_SHOT)
	Input.action_press("shoot")
	for i in 600:  # up to 10 s: the chaser spawns, activates, and walks into the shots
		var enemies := main.get_node("Room/Enemies").get_children()
		if not enemies.is_empty():
			player.aim_override = enemies[0].global_position
		await get_tree().physics_frame
		if cleared[0]:
			break
	Input.action_release("shoot")
	print("SMOKE_CLEARED %s" % cleared[0])


## The picker opens a real-time beat after the clear and pauses the tree.
func _picker_beat() -> void:
	await get_tree().create_timer(Main.PICKER_DELAY + TIMER_MARGIN, true, false, true).timeout


## Takes card 1 with the key the player would press. Prints SMOKE_UPGRADE <id>, or
## SMOKE_UPGRADE_NONE when the menu never opened (a distinct line, so smoke.sh's id grep cannot
## match it). Gives up after MAX_PICKS picks with SMOKE_PICK_LOOP_STUCK.
func _pick_first_card(main: Node) -> void:
	var menu: UpgradeMenu = main.get_node("UpgradeMenu")
	if not menu.is_open():
		print("SMOKE_UPGRADE_NONE")
		return
	var picked := [""]
	Events.upgrade_chosen.connect(func(card: UpgradeDef, _rank: int) -> void: picked[0] = card.id, CONNECT_ONE_SHOT)
	# A fresh frame first: a press stamped after this frame's _process (a timer or a capture await
	# ends there) is never "just pressed" for the menu's poll, and the first pick would be lost.
	await get_tree().process_frame
	var picks := 0
	while menu.is_open():  # a switch card re-offers; keep taking card 1
		if picks >= MAX_PICKS:
			print("SMOKE_PICK_LOOP_STUCK")
			return
		picks += 1
		Input.action_press("pick_1")
		await _ticks(2)
		Input.action_release("pick_1")
	print("SMOKE_UPGRADE %s" % picked[0])


## An ACTIVE, stationary chaser, like the test suites' active_chaser_on.
func _chaser_at(main: Node, at: Vector2) -> Enemy:
	var enemy: Enemy = load("res://scenes/enemies/chaser.tscn").instantiate()
	enemy.def = enemy.def.duplicate()
	enemy.def.spawn_delay = 0.0
	enemy.def.speed = 0.0
	main.get_node("Room/Enemies").add_child(enemy)
	enemy.global_position = at
	return enemy


## Every Audio play since boot, all names together: a scenario that ran silent is a regression.
func _total_plays() -> int:
	var total := 0
	for name in Audio.plays:
		total += int(Audio.plays[name])
	return total


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## An action pressed and released as InputEventActions fed to Input, a frame's flush each: the
## real path through _unhandled_input (a bare Input.action_press reaches only the pollers).
func _press_event(action: String) -> void:
	await get_tree().process_frame
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _ticks(2)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://reports")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s.png" % [dir, file_name]
	var err := image.save_png(path)
	print("SMOKE_SCREENSHOT %s err=%d" % [path, err])
	print("SMOKE_IMAGE size=%dx%d mean=%.3f" % [image.get_width(), image.get_height(), _mean_luminance(image)])


## Mean luminance (0..1) of the image sampled on a coarse grid; ~0 means a black capture.
func _mean_luminance(image: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(0, image.get_height(), IMAGE_SAMPLE_STEP):
		for x in range(0, image.get_width(), IMAGE_SAMPLE_STEP):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(count, 1)
