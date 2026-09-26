class_name BuildScreen
extends CanvasLayer
## Tab or Esc: the pause screen. The tree pauses under a dim; the left column holds the options
## (Resume, Restart, the three volume sliders, Quit to title, Quit game) and the right column the build: the
## weapon, every owned weapon upgrade with rank and the effect at that rank (UpgradeDef.summary),
## the player upgrades. Tab or Esc closes; R restarts, handled here like the picker does because
## Main is paused with everything else. Main sets `blocked` so it never opens over the picker or
## the title, or after the run has ended. Same layer and process mode as
## the picker; the two never show together. Sliders apply through Audio at once; the settings
## save on close.

signal restart_pressed
signal quit_pressed  ## Quit to title
signal quit_requested  ## Quit game: Main connects it to get_tree().quit

## 1240 x 600 at whole nine-patch pixels: the inner box (INSET) is 1168 x 528, the columns split
## the 1152 left after their separation 1:3 (288 for the options, 864 for the build), and the
## widest catalog row (a 3x icon, a 240 px name, a 56 px rank, a 452 px effect, three
## separations) needs 844.
const PANEL_SIZE := Vector2(1240, 600)
const PANEL_SCALE := 4.0
const INSET := 36.0
const ICON_SCALE := 3.0
const COLUMN_SEPARATION := 16
const OPTIONS_RATIO := 1.0
const BUILD_RATIO := 3.0
const BUTTON_SIZE := Vector2(240, 56)
## The frame's top ornament (a gem over a hanging tab) reaches 81 px below the frame's top edge at
## PANEL_SCALE (measured on the pause capture), 45 px past INSET; the build column starts this far
## below the inset (plus its 8 px row separation) so the weapon name is never under it. Not more:
## the widest build (seven rows) then needs exactly the inner 528 px.
const ORNAMENT_CLEARANCE := 40.0
const SLIDER_STEP := 5
const VOLUMES: Array[String] = ["master", "sfx", "music"]
const VOLUME_TITLES := {"master": "Master", "sfx": "Sound", "music": "Music"}

## Main sets this; open() refuses while it returns true.
var blocked: Callable = func() -> bool: return false
## Where close() saves the volumes; tests point it at a scratch file.
var settings_path: String = Settings.DEFAULT_PATH
var options: VBoxContainer
var lines: VBoxContainer
var sliders: Dictionary = {}  ## volume key -> HSlider

var _volume_labels: Dictionary = {}  ## volume key -> Label

@onready var panel: Control = $Center/Panel


func _ready() -> void:
	panel.custom_minimum_size = PANEL_SIZE
	UiTheme.framed_panel(panel, PANEL_SIZE, PANEL_SCALE)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.position = Vector2(INSET, INSET)
	columns.size = PANEL_SIZE - Vector2(INSET, INSET) * 2.0
	columns.add_theme_constant_override("separation", COLUMN_SEPARATION)
	panel.add_child(columns)
	options = VBoxContainer.new()
	options.name = "Options"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_stretch_ratio = OPTIONS_RATIO
	options.add_theme_constant_override("separation", 8)
	columns.add_child(options)
	lines = VBoxContainer.new()
	lines.name = "Lines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.size_flags_stretch_ratio = BUILD_RATIO
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 8)
	columns.add_child(lines)
	_build_options()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("build_screen") or Input.is_action_just_pressed("pause"):
		if visible:
			close()
		else:
			open()
	elif visible and Input.is_action_just_pressed("restart"):
		restart_pressed.emit()


func open() -> void:
	if blocked.call():
		return
	_rebuild()
	_sync_sliders()
	Juice.reset()
	get_tree().paused = true
	visible = true
	Events.menu_opened.emit("build")


## Also called blind by Main.restart() and the picker: the unpause is unconditional, the save and
## the sound only when it was open.
func close() -> void:
	var was_open := visible
	visible = false
	get_tree().paused = false
	if was_open:
		if Audio.settings.save_to(settings_path) != OK:
			push_warning("BuildScreen: could not save %s" % settings_path)
		Events.menu_closed.emit("build")


func is_open() -> bool:
	return visible


## Main hides Restart while the grounds are up (no run to restart there) and shows it in the arena.
func set_restart_visible(shown: bool) -> void:
	options.get_node("Restart").visible = shown


func _build_options() -> void:
	var heading := UiTheme.title("Options")
	heading.name = "Heading"
	options.add_child(heading)
	options.add_child(_button("Resume", "Resume", close))
	options.add_child(_button("Restart", "Restart", func() -> void: restart_pressed.emit()))
	for key in VOLUMES:
		options.add_child(_volume_row(key))
	var quit := _button("QuitToTitle", "Quit to title", func() -> void: quit_pressed.emit())
	quit.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END  # the two quits sit at the bottom
	options.add_child(quit)
	options.add_child(_button("QuitGame", "Quit game", func() -> void:
		close()  # saves the volumes first: a slider moved before quitting is kept
		quit_requested.emit()))


func _button(node_name: String, text: String, on_pressed: Callable) -> Button:
	var b := UiTheme.button(text, BUTTON_SIZE)
	b.name = node_name
	b.pressed.connect(on_pressed)
	return b


## "Master 80" over a slider. The label follows the slider; the slider drives the bus at once.
func _volume_row(key: String) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = "Volume_" + key
	row.add_theme_constant_override("separation", 2)
	var label := UiTheme.label("", UiTheme.FONT_SMALL)
	label.name = "Label"
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = SLIDER_STEP
	slider.custom_minimum_size = Vector2(BUTTON_SIZE.x, 24)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(value: float) -> void: _on_volume_changed(key, value))
	row.add_child(slider)
	sliders[key] = slider
	_volume_labels[key] = label
	return row


func _on_volume_changed(key: String, value: float) -> void:
	_set_volume_label(key, value)
	Audio.settings.set_volume(key, value / 100.0)
	Audio.apply(Audio.settings)


func _sync_sliders() -> void:
	for key in VOLUMES:
		var slider: HSlider = sliders[key]
		slider.set_value_no_signal(roundf(Audio.settings.volume(key) * 100.0))
		_set_volume_label(key, slider.value)


func _set_volume_label(key: String, value: float) -> void:
	var label: Label = _volume_labels[key]
	label.text = "%s %d" % [VOLUME_TITLES[key], int(value)]


func _rebuild() -> void:
	UiTheme.clear_children(lines)
	var spacer := Control.new()
	spacer.name = "OrnamentSpacer"
	spacer.custom_minimum_size = Vector2(0, ORNAMENT_CLEARANCE)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(spacer)
	var build := RunState.build
	var catalog := UpgradeCatalog.upgrades()
	var weapon := UpgradeCatalog.weapon(build.weapon_id)
	lines.add_child(_row("Row_weapon", weapon.icon, weapon.display_name, "", ""))
	var owned := build.owned_weapon_ids()
	for id in owned:
		var u: UpgradeDef = catalog[id]
		lines.add_child(_upgrade_row(id, u, build))
	var player_ids := build.owned_player_ids()
	for id in player_ids:
		var u: UpgradeDef = catalog[id]
		lines.add_child(_upgrade_row(id, u, build))
	if owned.is_empty() and player_ids.is_empty():
		lines.add_child(UiTheme.label("No upgrades yet", UiTheme.FONT_SMALL))
	var hint := UiTheme.label("Tab or Esc to close", UiTheme.FONT_SMALL)
	hint.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	lines.add_child(hint)


## Rank and the effect at that rank: two ranks of "+1 damage" read "+2 damage", not the per-pick line.
func _upgrade_row(id: String, u: UpgradeDef, build: Build) -> HBoxContainer:
	var rank := build.rank_of(id)
	return _row("Row_" + id, u.icon, u.name, "%d/%d" % [rank, u.max_rank], u.summary(rank))


func _row(row_name: String, icon: String, title: String, rank: String, description: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	row.add_child(IconAtlas.rect(icon, ICON_SCALE))
	var is_weapon := rank.is_empty() and description.is_empty()
	var name_label := UiTheme.title(title) if is_weapon else UiTheme.label(title, UiTheme.FONT_SMALL)
	name_label.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_label)
	if is_weapon:
		return row  # the weapon row is the heading: the icon and the name on the title font
	var rank_label := UiTheme.label(rank, UiTheme.FONT_SMALL)
	rank_label.custom_minimum_size = Vector2(56, 0)
	row.add_child(rank_label)
	row.add_child(UiTheme.label(description, UiTheme.FONT_SMALL))
	return row
