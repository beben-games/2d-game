class_name KeyCap
extends Control
## The interact key's cap over the grounds' focus: the UI sheet's beige panel with the key the
## action is bound to (read from the InputMap, "E" by default) in the pixel font, and nothing
## else: a key's name, never a word about what it does. Lives on its own CanvasLayer under Main
## (between the HUD and the menus); each frame its bottom centre stands GAP over the target's
## prompt position, the camera's view of the world in screen pixels (as the HUD's coin flights
## start), kept EDGE inside the view (the gate's art is the view's top). Hidden with no target
## or under a pause (it processes under one only to hide). Main sets `target` from the grounds'
## focus.

const ACTION := "interact"
const PANEL_SCALE := 3.0  ## the world's zoom: the sheet's pixels as big as the tiles'
const SIZE := Vector2(48, 48)  ## whole nine-patch pixels at PANEL_SCALE
const FONT_SIZE := UiTheme.FONT_SMALL
## Between the cap's bottom and the prompt position, screen pixels.
const GAP := 6.0
## The cap stays this far inside the view.
const EDGE := 6.0

## The interactable the cap stands over, or null.
var target: Interactable

var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	add_child(UiTheme.nine_patch(UiTheme.PANEL, UiTheme.PANEL_MARGIN, SIZE, PANEL_SCALE))
	_label = UiTheme.label(key_name(ACTION), FONT_SIZE)
	_label.name = "Key"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = SIZE
	add_child(_label)
	visible = false


func _process(_delta: float) -> void:
	_place()


## The name of the first key bound to `action` ("" when none is: a joypad-only binding gives an
## empty cap until gamepad support exists). A physical binding is named by the keyboard
## layout's label for that key (the E key's place on a Dvorak board reads "."), asked of the
## display server; the headless server cannot answer (it pushes an error), so there, and
## whenever the answer is none, the keycode's own name ("E").
static func key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		if key.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			var label := DisplayServer.keyboard_get_label_from_physical(key.physical_keycode)
			if label != KEY_NONE:
				return OS.get_keycode_string(label)
		return OS.get_keycode_string(key.keycode if key.keycode != KEY_NONE else key.physical_keycode)
	return ""


## The key's name the cap shows.
func text() -> String:
	return _label.text


func _place() -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or get_tree().paused:
		visible = false
		return
	var at := get_viewport().get_canvas_transform() * target.prompt_position()
	var view := get_viewport().get_visible_rect()
	var spot := at - Vector2(SIZE.x * 0.5, SIZE.y + GAP)
	spot = spot.clamp(view.position + Vector2(EDGE, EDGE), view.end - SIZE - Vector2(EDGE, EDGE))
	position = spot.round()
	visible = true
