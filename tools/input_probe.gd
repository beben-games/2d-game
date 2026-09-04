extends SceneTree
## Diagnostic: logs every key and mouse-button event, every window/app notification, and the
## move_right action state, so a stuck key can be traced to a lost key-up. Run via tools/input_probe.sh.

const DEFAULT_DURATION_SEC := 25.0
const NAMES := {
	1002: "WM_MOUSE_ENTER", 1003: "WM_MOUSE_EXIT", 1004: "WM_WINDOW_FOCUS_IN", 1005: "WM_WINDOW_FOCUS_OUT",
	2016: "APPLICATION_FOCUS_IN", 2017: "APPLICATION_FOCUS_OUT",
}

var start_usec := 0
var last_state := ""
var duration_sec := DEFAULT_DURATION_SEC


func _initialize() -> void:
	start_usec = Time.get_ticks_usec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			duration_sec = float(arg.get_slice("=", 1))
	var logger := Node.new()
	logger.name = "InputProbeLogger"
	logger.set_script(preload("res://tools/input_probe_logger.gd"))
	root.add_child(logger)
	print("PROBE start; window open for %d s" % int(duration_sec))


func _process(_delta: float) -> bool:
	var state := "right=%s phys_D=%s" % [Input.is_action_pressed("move_right"), Input.is_physical_key_pressed(KEY_D)]
	if state != last_state:
		print("PROBE t=%.3f STATE %s" % [elapsed(), state])
		last_state = state
	return elapsed() >= duration_sec


func elapsed() -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1_000_000.0
