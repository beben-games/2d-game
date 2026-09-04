extends Node
## Boots the main scene, runs a named scenario with simulated input, saves a screenshot, quits.
## Usage: tools/smoke.sh <scenario>. Scenarios: idle, move, combat.
## Prints machine-readable lines prefixed SMOKE_ for tools/smoke.sh to check.
## Waits are counted in physics ticks (60 Hz) because gameplay runs in _physics_process;
## render frames vary with the display refresh rate and would make timings machine-dependent.

const MAIN := preload("res://scenes/main.tscn")
const IMAGE_SAMPLE_STEP := 32

var scenario := "idle"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
	var main := MAIN.instantiate()
	main.restart_requested.connect(func() -> void: print("SMOKE_RESTART_REQUESTED"))
	add_child(main)
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
			await _ticks(60)
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
			print("SMOKE_ENEMIES_ALIVE %d" % main.get_node("Enemies").get_child_count())
			print("SMOKE_PROJECTILES_ALIVE %d" % main.get_node("Projectiles").get_child_count())
			print("SMOKE_KILLS %d" % RunState.kills)
			print("SMOKE_PLAYER_HP %d" % player.hp)
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
