extends SceneTree
## Drives Main as the real current scene through the paths that reload it (tests and the smoke
## tool host Main as a child, where nothing reloads): Play, Restart (a yield), Play, a fall to
## the gate screen, the gate passed into the grounds (no reload: the stage swaps under the
## black), Quit to title from the grounds (no yield: nothing is live there), Play into the
## Ludus again (the profile has returned), E at its top door (the interact key, a real input
## event) into the Hypogeum, E at the lift into the arena, and Quit to title from the run (a
## yield, a reload). Run by
## tools/check_boot.sh, which fails on any ERROR line; prints RELOAD_PROBE ok when the title
## is up at the end. Must quit() on every path (a -s script that stops early hangs). The yields
## and the verdict commit the profile, so it is pointed at a scratch file first, never the
## player's save.

## Per process, so two probes on one machine never share the file.
var PROFILE_SCRATCH: String = "user://probe_profile_%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	# A -s script has no autoload identifiers at compile time; the singleton is a child of root.
	var profile: Node = root.get_node("Profile")
	profile.set("path", PROFILE_SCRATCH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_SCRATCH))  # an earlier probe's, before the reset reads it
	profile.call("reset")
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	current_scene.play()
	await _frames(5)
	current_scene.restart()
	await _frames(5)
	current_scene.play()
	await _frames(5)
	# Duck-typed throughout: naming Main (or any gameplay class) here would compile the game's
	# scripts before the autoloads exist, and every one of them would fail on Events or RunState.
	var main: Node = current_scene
	var constants: Dictionary = main.get_script().get_script_constant_map()
	var player: Node2D = main.get("player")
	player.call("hurt", 100, player.global_position + Vector2(4, 0), "chaser")
	var scene_time := 0.3  # the verdict scene's real time: the hold, the build-up's drift and pause, the thumb's stay, the fade
	for name: String in ["VERDICT_HOLD", "VERDICT_DRIFT", "VERDICT_PAUSE", "VERDICT_SHOW", "FADE_TIME"]:
		scene_time += float(constants[name])
	await create_timer(scene_time, true, false, true).timeout
	await _frames(2)
	var gate_screen: CanvasLayer = main.get("gate_screen")
	if current_scene != main or not gate_screen.visible:
		push_error("RELOAD_PROBE: the gate screen is not up after the fall")
		quit(1)
		return
	gate_screen.emit_signal("continue_requested")  # Enter on the screen: Main's _pass_gate
	await create_timer(float(constants["FADE_TIME"]) * 2.0 + 0.3, true, false, true).timeout
	await _frames(2)
	if current_scene != main or main.get_node_or_null("Grounds") == null or main.get_node_or_null("Room") != null:
		push_error("RELOAD_PROBE: the grounds are not up after the gate")
		quit(1)
		return
	if not bool(profile.get("save").flags["returned"]):
		push_error("RELOAD_PROBE: the profile did not record the return")
		quit(1)
		return
	current_scene.quit_to_title()
	await _frames(5)
	if current_scene == null or not current_scene.title.visible or not paused:
		push_error("RELOAD_PROBE: the title is not up after Quit to title")
		quit(1)
		return
	# Play on the returned profile: the Ludus; the gladiator onto its top door, the key, the
	# Hypogeum; onto the lift, the key, the arena.
	current_scene.play()
	await _frames(5)
	main = current_scene
	if main.get("grounds") == null or main.get("grounds").get("room_def").get("id") != "ludus":
		push_error("RELOAD_PROBE: Play on a returned profile did not enter the Ludus")
		quit(1)
		return
	player = main.get("player")
	if not await _press_at(main, player, "door:hypogeum"):
		return
	await create_timer(float(constants["FADE_TIME"]) * 2.0 + 0.3, true, false, true).timeout
	await _frames(2)
	if current_scene != main or main.get("grounds") == null or main.get("grounds").get("room_def").get("id") != "hypogeum":
		push_error("RELOAD_PROBE: E at the Ludus's top door did not walk to the Hypogeum")
		quit(1)
		return
	if not await _press_at(main, player, "lift"):
		return
	await create_timer(float(constants["FADE_TIME"]) * 2.0 + 0.3, true, false, true).timeout
	await _frames(2)
	if current_scene != main or main.get_node_or_null("Grounds") != null or main.get_node_or_null("Room") == null:
		push_error("RELOAD_PROBE: E at the lift did not start the run")
		quit(1)
		return
	current_scene.quit_to_title()
	await _frames(5)
	if current_scene == null or not current_scene.title.visible or not paused:
		push_error("RELOAD_PROBE: the title is not up after Quit to title from the run")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_SCRATCH))
	print("RELOAD_PROBE ok")
	quit()


## The player onto the grounds' interactable `id` until it is the focus, then E as a real input
## event (pressed, released). False, with the error out and the probe quit, when the focus never
## comes.
func _press_at(main: Node, player: Node2D, id: String) -> bool:
	var grounds: Node = main.get("grounds")
	var item: Node2D = grounds.call("interactable", id)
	if item == null:
		push_error("RELOAD_PROBE: no %s in the room" % id)
		quit(1)
		return false
	player.global_position = item.call("stand_position")
	for i in 60:
		await physics_frame
		if grounds.get("focus") == item:
			break
	if grounds.get("focus") != item:
		push_error("RELOAD_PROBE: the %s did not take the focus" % id)
		quit(1)
		return false
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)
	return true


func _frames(n: int) -> void:
	for i in n:
		await process_frame
