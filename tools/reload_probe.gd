extends SceneTree
## Drives Main as the real current scene through the paths that reload it (tests and the smoke
## tool host Main as a child, where nothing reloads): Play, Restart, Play, Quit to title. Run by
## tools/check_boot.sh, which fails on any ERROR line; prints RELOAD_PROBE ok when the title is up
## at the end. Must quit() on every path (a -s script that stops early hangs).


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	current_scene.play()
	await _frames(5)
	current_scene.restart()
	await _frames(5)
	current_scene.play()
	await _frames(5)
	current_scene.quit_to_title()
	await _frames(5)
	if current_scene == null or not current_scene.title.visible or not paused:
		push_error("RELOAD_PROBE: the title is not up after Quit to title")
		quit(1)
		return
	print("RELOAD_PROBE ok")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
