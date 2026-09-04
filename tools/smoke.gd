extends Node
## Boots the main scene, runs a named scenario with simulated input, saves a screenshot, quits.
## Usage: tools/smoke.sh <scenario>. Scenarios: idle, move, combat.
## Prints machine-readable lines prefixed SMOKE_ for tools/smoke.sh to check.

const MAIN := preload("res://scenes/main.tscn")

var scenario := "idle"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
	var main := MAIN.instantiate()
	add_child(main)
	await _frames(5)
	if not await _run_scenario(main):
		get_tree().quit(2)
		return
	await _capture("smoke_%s" % scenario)
	print("SMOKE_DONE scenario=%s" % scenario)
	get_tree().quit(0)


## Returns false when the scenario cannot run; the caller then exits without a screenshot.
func _run_scenario(main: Node) -> bool:
	match scenario:
		"idle":
			await _frames(30)
		"move":
			var player := _player()
			if player == null:
				push_error("scenario %s needs a player in group 'player'" % scenario)
				return false
			print("SMOKE_PLAYER_START %s" % player.global_position)
			Input.action_press("move_right")
			await _frames(60)
			Input.action_release("move_right")
			print("SMOKE_PLAYER_END %s" % player.global_position)
		"combat":
			var player := _player()
			if player == null:
				push_error("scenario %s needs a player in group 'player'" % scenario)
				return false
			player.aim_override = player.global_position + Vector2(200, 0)
			Input.action_press("shoot")
			await _frames(150)
			Input.action_release("shoot")
			print("SMOKE_ENEMIES_ALIVE %d" % main.get_node("Enemies").get_child_count())
			print("SMOKE_KILLS %d" % RunState.kills)
		_:
			push_error("unknown scenario %s" % scenario)
			return false
	return true


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://reports")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s.png" % [dir, file_name]
	var err := image.save_png(path)
	print("SMOKE_SCREENSHOT %s err=%d" % [path, err])
