class_name Title
extends CanvasLayer
## The front door: the game's name over the dimmed first room, Play, a seed field (blank means
## random), the controls line, and the version. Main boots into it with the tree paused and
## starts the run on play_pressed. Layer 15: over the HUD (1) and the menus (10), under the fade
## (20) and the summary (30); process_mode ALWAYS so it runs under the pause.

signal play_pressed(seed_value: int)  ## -1 for a random seed

const GAME_NAME := "Arena"  ## a placeholder until the user names the game
const NAME_SIZE := 96
const BUTTON_SIZE := Vector2(320, 88)
const FIELD_SIZE := Vector2(320, 48)
const HINT := "WASD move, mouse aim, click shoot, Space dash, Tab or Esc menu, R restart"

var seed_field: LineEdit
var play_button: Button

@onready var box: VBoxContainer = $Center/Box


func _ready() -> void:
	var name_label := UiTheme.title(GAME_NAME, NAME_SIZE, UiTheme.PAPER)
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	play_button = UiTheme.button("Play", BUTTON_SIZE, UiTheme.FONT_BODY)
	play_button.name = "Play"
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(play)
	box.add_child(play_button)
	seed_field = LineEdit.new()
	seed_field.name = "Seed"
	seed_field.custom_minimum_size = FIELD_SIZE
	seed_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	seed_field.placeholder_text = "seed (blank = random)"
	seed_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_field.max_length = 9  # under RunState's 31-bit seeds
	seed_field.add_theme_font_override("font", UiTheme.FONT)
	seed_field.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	seed_field.text_changed.connect(_digits_only)
	seed_field.text_submitted.connect(func(_text: String) -> void: play())
	box.add_child(seed_field)
	var hint := UiTheme.label(HINT, UiTheme.FONT_SMALL, UiTheme.PAPER)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var version := UiTheme.label("v" + str(ProjectSettings.get_setting("application/config/version")), UiTheme.FONT_SMALL, UiTheme.PAPER)
	version.name = "Version"
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(version)


func open() -> void:
	seed_field.text = ""
	visible = true
	seed_field.grab_focus()
	Events.menu_opened.emit("title")


func close() -> void:
	if not visible:
		return
	visible = false
	Events.menu_closed.emit("title")


func is_open() -> bool:
	return visible


## The field's number, or -1 (random) when blank.
func seed_value() -> int:
	return int(seed_field.text) if seed_field.text.is_valid_int() else -1


func play() -> void:
	if not visible:
		return
	var value := seed_value()
	close()
	play_pressed.emit(value)


## Enter (or Space) anywhere on the title plays; the field's own submit closes first, so the
## second call is a no-op.
func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("ui_accept"):
		play()


func _digits_only(text: String) -> void:
	var digits := ""
	for ch in text:
		if ch.is_valid_int():
			digits += ch
	if digits != text:
		var caret := seed_field.caret_column
		seed_field.text = digits
		seed_field.caret_column = mini(caret, digits.length())
