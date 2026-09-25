class_name Title
extends CanvasLayer
## The front door: the game's name over the dimmed arena, Play, a seed field (blank means
## random; a code word from Cheats.CODES starts a cheated run), Quit, the controls line, and the
## version. Main boots into it with the tree paused and
## starts the run on play_pressed. Layer 15: over the HUD (1) and the menus (10), under the fade
## (20) and the summary (30); process_mode ALWAYS so it runs under the pause.

signal play_pressed(seed_value: int, cheats: Dictionary)  ## -1 for a random seed; the cheat flags, empty in a real run
signal quit_requested  ## the Quit button: Main connects it to get_tree().quit

const GAME_NAME := "Arena"  ## a placeholder until the user names the game
const NAME_SIZE := 96
const BUTTON_SIZE := Vector2(320, 88)
const FIELD_SIZE := Vector2(320, 48)
const FIELD_MAX_LENGTH := 16  ## sixteen characters: any non-negative int64 seed or a code word
const JUNK_TINT := Color(0.85, 0.35, 0.3)  ## the field's text when it is neither a seed nor a code word (it will be ignored)
const HINT := "WASD move, mouse aim, click shoot, Space dash, Tab or Esc menu, R restart"

var seed_field: LineEdit
var play_button: Button
var quit_button: Button

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
	seed_field.max_length = FIELD_MAX_LENGTH  # no character filter: a cheat code carries letters and a '?'; Cheats.parse is the gate
	seed_field.add_theme_font_override("font", UiTheme.FONT)
	seed_field.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	seed_field.text_changed.connect(_on_seed_text_changed)
	seed_field.text_submitted.connect(func(_text: String) -> void: play())
	box.add_child(seed_field)
	quit_button = UiTheme.button("Quit", BUTTON_SIZE)
	quit_button.name = "Quit"
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	box.add_child(quit_button)
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
	_on_seed_text_changed("")  # a set text emits no text_changed; the tint of the last visit must not stay
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


## The field's text read by Cheats.parse: {"seed": a number, or -1 (random) when blank, junk, or
## a code word; "cheats": the code word's flags, else {}}.
func parsed() -> Dictionary:
	return Cheats.parse(seed_field.text)


func play() -> void:
	if not visible:
		return
	var run := parsed()
	close()
	play_pressed.emit(int(run["seed"]), run["cheats"])


## Junk (non-empty text that is neither a seed nor a code word) is tinted so the player sees it
## will be ignored; a seed, a code word, or a blank field keeps the plain colour.
func _on_seed_text_changed(text: String) -> void:
	var run := Cheats.parse(text)
	var junk := not text.strip_edges().is_empty() and int(run["seed"]) == Cheats.RANDOM_SEED and (run["cheats"] as Dictionary).is_empty()
	if junk:
		seed_field.add_theme_color_override("font_color", JUNK_TINT)
	else:
		seed_field.remove_theme_color_override("font_color")


## Enter (or KP Enter) anywhere on the title plays; the field's own submit closes first, so the
## second call is a no-op. Not ui_accept: that includes Space, which is the dash, and the
## player's first unpaused tick would see the same press and start the run mid-dash.
func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("title_play"):
		play()
