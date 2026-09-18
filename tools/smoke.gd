extends Node
## Boots the main scene, runs a named scenario with simulated input, saves a screenshot, quits.
## Usage: tools/smoke.sh <scenario>. Scenarios: idle, move, combat, kill, room, death, pick, title, pause.
## Prints machine-readable lines prefixed SMOKE_ for tools/smoke.sh to check.
## Waits are counted in physics ticks (60 Hz) because gameplay runs in _physics_process;
## render frames vary with the display refresh rate and would make timings machine-dependent.
## A 30 s real-time watchdog quits with code 3 if a scenario hangs.

const MAIN := preload("res://scenes/main.tscn")
const SMOKE_FLOOR := "res://tools/smoke_floor.tres"  # two rooms of one chaser each
const WATCHDOG_SECONDS := 30.0
const IMAGE_SAMPLE_STEP := 32
const MAX_PICKS := 20  # a refund chain is at most a handful of rounds; more means the menu is stuck

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
	var main := MAIN.instantiate()
	if scenario in ["room", "death", "pick"]:
		main.floor_def = load(SMOKE_FLOOR)
	main.restart_requested.connect(func() -> void: print("SMOKE_RESTART_REQUESTED"))
	main.start_at_title = scenario == "title"
	add_child(main)
	# Only combat, room, and pick need the waves: combat counts the first wave, the others clear one.
	if scenario not in ["combat", "room", "pick"]:
		main.get_node("Room/WaveRunner").enabled = false
	var ticks_at_start := Engine.get_physics_frames()
	await _ticks(5)
	var ok: bool = await _run_scenario(main)
	print("SMOKE_PHYSICS_TICKS %d" % (Engine.get_physics_frames() - ticks_at_start))
	if not ok:
		get_tree().quit(2)
		return
	await _capture("smoke_%s" % scenario)
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
		"room":
			var player := _require_player()
			if player == null:
				return false
			await _clear_first_room(main, player)
			await _picker_beat()
			await _pick_first_card(main)
			await _ticks(10)  # the door is open; walk through it
			var gap := ArenaGrid.door_gap(main.room.def.width, main.room.def.height, RoomDef.Side.TOP)
			player.global_position = Vector2(gap.get_center().x, gap.end.y + 8)  # just clear of the wall band
			player.aim_override = player.global_position
			Input.action_press("move_up")
			await _ticks(40)
			Input.action_release("move_up")
			await get_tree().create_timer(0.6, true, false, true).timeout  # the fade is real time
			await get_tree().physics_frame
			print("SMOKE_ROOM %d" % main.room_index)
		"death":
			var player := _require_player()
			if player == null:
				return false
			player.hp = 1
			_chaser_at(main, player.global_position + Vector2(4, 0))
			await _ticks(10)
			await get_tree().create_timer(1.0, true, false, true).timeout  # DEATH_SUMMARY_DELAY is real time
			print("SMOKE_SUMMARY %s" % main.get_node("Summary/Center/Box/Title").text)
		"pick":
			var player := _require_player()
			if player == null:
				return false
			await _clear_first_room(main, player)
			await _picker_beat()
			var menu: UpgradeMenu = main.get_node("UpgradeMenu")
			print("SMOKE_MENU_OPEN %s" % menu.is_open())
			await _capture("smoke_pick_menu")  # the cards, paused
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
			await _capture("smoke_pause_menu")  # the options and the build, paused; smoke_pause.png is the run after the close
			await get_tree().process_frame
			Input.action_press("pause")
			await _ticks(2)
			Input.action_release("pause")
		_:
			push_error("unknown scenario %s" % scenario)
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


## Holds shoot on whatever spawns until the room clears (up to 10 s). Prints SMOKE_CLEARED.
func _clear_first_room(main: Node, player: Player) -> void:
	var cleared := [false]
	# Stays connected if the room never clears; fine, the process quits right after.
	Events.room_cleared.connect(func() -> void: cleared[0] = true, CONNECT_ONE_SHOT)
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
	await get_tree().create_timer(Main.PICKER_DELAY + 0.1, true, false, true).timeout


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


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
