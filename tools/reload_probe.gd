extends SceneTree
## Drives Main as the real current scene through the paths that reload it (tests and the smoke
## tool host Main as a child, where nothing reloads): Play, Restart (a yield), Play, a fall to
## the gate screen, Quit to title (a second yield is not logged: the verdict ended the run). Run
## by tools/check_boot.sh, which fails on any ERROR line; prints RELOAD_PROBE ok when the title
## is up at the end. Must quit() on every path (a -s script that stops early hangs). The yields
## and the verdict commit the profile, so it is pointed at a scratch file first, never the
## player's save.

const PROFILE_SCRATCH := "user://probe_profile.cfg"


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
	var scene_time := float(constants["VERDICT_HOLD"]) + float(constants["VERDICT_SHOW"]) + float(constants["FADE_TIME"]) + 0.3
	await create_timer(scene_time, true, false, true).timeout
	await _frames(2)
	var gate_screen: CanvasLayer = main.get("gate_screen")
	if current_scene != main or not gate_screen.visible:
		push_error("RELOAD_PROBE: the gate screen is not up after the fall")
		quit(1)
		return
	current_scene.quit_to_title()
	await _frames(5)
	if current_scene == null or not current_scene.title.visible or not paused:
		push_error("RELOAD_PROBE: the title is not up after Quit to title")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_SCRATCH))
	print("RELOAD_PROBE ok")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
