extends Node
## Child of the probe's root: receives raw input and window notifications and prints them.


func _t() -> float:
	return float(Time.get_ticks_usec()) / 1_000_000.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		print("PROBE t=%.3f KEY %s%s phys=%s label=%s" % [_t(), "down" if k.pressed else "UP", " echo" if k.echo else "", OS.get_keycode_string(k.physical_keycode), OS.get_keycode_string(k.key_label)])
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		print("PROBE t=%.3f MOUSE button=%d %s" % [_t(), m.button_index, "down" if m.pressed else "UP"])


func _notification(what: int) -> void:
	if what >= 1000:
		var names := {1002: "WM_MOUSE_ENTER", 1003: "WM_MOUSE_EXIT", 1004: "WM_WINDOW_FOCUS_IN", 1005: "WM_WINDOW_FOCUS_OUT", 2016: "APPLICATION_FOCUS_IN", 2017: "APPLICATION_FOCUS_OUT"}
		print("PROBE t=%.3f NOTIFICATION %s" % [_t(), names.get(what, str(what))])
