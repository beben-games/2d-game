class_name BuildScreen
extends CanvasLayer
## Esc or Tab: the pause screen. The tree pauses under a dim; a strip of three tabs hangs under
## the frame's top ornament (Options, Boons, Training: the open one at full colour, the others at
## TAB_DIM) over one page each, filling the inner box. Options: Resume, Restart, the three volume
## sliders, Quit to title, Quit game. Boons: the build, the weapon, every owned weapon upgrade with
## rank and the effect at that rank (UpgradeDef.summary), the player upgrades. Training: the
## profile's lines (TrainingPanel.line_box: the icon, the name, the rank pips), a look, not a
## shop. Esc (the pause action) opens on Options and Tab (build_screen) on Boons; either closes;
## R restarts, handled here like the picker does because Main is paused with everything else.
## Main sets `blocked` so it never opens over the picker or the title, or after the run has
## ended. Same layer and process mode as the picker; the two never show together. Sliders apply
## through Audio at once; the settings save on close. UI may name, never narrate: the tab names,
## the options, the build's rows, the training names.

signal restart_pressed
signal quit_pressed  ## Quit to title
signal quit_requested  ## Quit game: Main connects it to get_tree().quit

## 1240 x 648 at whole nine-patch pixels (600 before the tabs: the strip under the ornament takes
## the top of the inner box, and the Options column (446 px) and the widest build (eight rows,
## 440 px) need the page's height under it).
const PANEL_SIZE := Vector2(1240, 648)
const PANEL_SCALE := 4.0
const INSET := 36.0
const ICON_SCALE := 3.0
const ROW_SEPARATION := 8
const BUTTON_SIZE := Vector2(240, 56)
## The frame's top ornament (a gem over a hanging tab, centred) ends 86 px below the panel's top
## at PANEL_SCALE (81 below the frame's drawn edge, 4 px in; measured on the pause capture). The
## tab strip starts under it, a gap clear, so the Training tab never touches it.
const ORNAMENT_DEPTH := 86.0
const TAB_TOP := 92.0
const TAB_SIZE := Vector2(200, 48)
const TAB_SEPARATION := 16
const TAB_DIM := Color(0.55, 0.55, 0.55)
## Between the strip and the page.
const TAB_GAP := 16.0
## The pages' box: the inner box under the strip.
const CONTENT_TOP := TAB_TOP + TAB_SIZE.y + TAB_GAP
const CONTENT_SIZE := Vector2(PANEL_SIZE.x - INSET * 2.0, PANEL_SIZE.y - INSET - CONTENT_TOP)
const TABS: Array[String] = ["options", "boons", "training"]
const TAB_TITLES := {"options": "Options", "boons": "Boons", "training": "Training"}
## The pause action opens here; build_screen opens on Boons.
const PAUSE_TAB := "options"
const BUILD_TAB := "boons"
const SLIDER_STEP := 5
const VOLUMES: Array[String] = ["master", "sfx", "music"]
const VOLUME_TITLES := {"master": "Master", "sfx": "Sound", "music": "Music"}

## Main sets this; open() refuses while it returns true.
var blocked: Callable = func() -> bool: return false
## Where close() saves the volumes; tests point it at a scratch file.
var settings_path: String = Settings.DEFAULT_PATH
var strip: HBoxContainer
var content: Control
var options: VBoxContainer
var boons: VBoxContainer
var training: VBoxContainer
var tabs: Dictionary = {}  ## tab -> its page
var tab_buttons: Dictionary = {}  ## tab -> its Button on the strip
var current_tab: String = PAUSE_TAB
var sliders: Dictionary = {}  ## volume key -> HSlider

var _volume_labels: Dictionary = {}  ## volume key -> Label

@onready var panel: Control = $Center/Panel


func _ready() -> void:
	panel.custom_minimum_size = PANEL_SIZE
	UiTheme.framed_panel(panel, PANEL_SIZE, PANEL_SCALE)
	strip = HBoxContainer.new()
	strip.name = "Tabs"
	strip.position = Vector2(INSET, TAB_TOP)
	strip.add_theme_constant_override("separation", TAB_SEPARATION)
	panel.add_child(strip)
	content = Control.new()
	content.name = "Content"
	content.position = Vector2(INSET, CONTENT_TOP)
	content.size = CONTENT_SIZE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	options = _page("options")
	options.size = Vector2(BUTTON_SIZE.x, CONTENT_SIZE.y)  # the column as wide as its buttons
	boons = _page("boons")
	training = _page("training")
	for tab in TABS:
		strip.add_child(_tab_button(tab))
	_build_options()
	show_tab(PAUSE_TAB)


func _process(_delta: float) -> void:
	var tab := ""
	if Input.is_action_just_pressed("pause"):
		tab = PAUSE_TAB
	elif Input.is_action_just_pressed("build_screen"):
		tab = BUILD_TAB
	if not tab.is_empty():
		if visible:
			close()
		else:
			open(tab)
	elif visible and Input.is_action_just_pressed("restart"):
		restart_pressed.emit()


## Opens on `tab` (Options by default: a caller outside the keys, like a test, gets the pause tab).
func open(tab: String = PAUSE_TAB) -> void:
	if blocked.call():
		return
	_rebuild()
	_rebuild_training()
	show_tab(tab)
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


## Shows the tab's page alone and lights its tab on the strip.
func show_tab(tab: String) -> void:
	assert(tabs.has(tab), "BuildScreen: no tab '%s'" % tab)
	current_tab = tab
	for key: String in tabs:
		(tabs[key] as Control).visible = key == tab
		(tab_buttons[key] as Button).modulate = tab_colour(key)


## The tab's colour on the strip without a hover: full for the open one, TAB_DIM for the rest.
func tab_colour(tab: String) -> Color:
	return Color.WHITE if tab == current_tab else TAB_DIM


## Main hides Restart while the grounds are up (no run to restart there) and shows it in the arena.
func set_restart_visible(shown: bool) -> void:
	options.get_node("Restart").visible = shown


func _build_options() -> void:
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


## A page under the strip, filling the content box; hidden until its tab shows.
func _page(tab: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = TAB_TITLES[tab]
	page.size = CONTENT_SIZE
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", ROW_SEPARATION)
	content.add_child(page)
	tabs[tab] = page
	return page


## A tab on the strip: the red button, dimmed unless open. The hover brightens it from its own
## colour (connected after UiTheme.button's, so these win).
func _tab_button(tab: String) -> Button:
	var b := UiTheme.button(TAB_TITLES[tab], TAB_SIZE)
	b.name = TAB_TITLES[tab]
	b.pressed.connect(show_tab.bind(tab))
	b.mouse_entered.connect(func() -> void: b.modulate = tab_colour(tab) * UiTheme.BUTTON_HOVER)
	b.mouse_exited.connect(func() -> void: b.modulate = tab_colour(tab))
	tab_buttons[tab] = b
	return b


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
	UiTheme.clear_children(boons)
	var build := RunState.build
	var catalog := UpgradeCatalog.upgrades()
	var weapon := UpgradeCatalog.weapon(build.weapon_id)
	boons.add_child(_row("Row_weapon", weapon.icon, weapon.display_name, "", ""))
	var owned := build.owned_weapon_ids()
	for id in owned:
		var u: UpgradeDef = catalog[id]
		boons.add_child(_upgrade_row(id, u, build))
	var player_ids := build.owned_player_ids()
	for id in player_ids:
		var u: UpgradeDef = catalog[id]
		boons.add_child(_upgrade_row(id, u, build))
	if owned.is_empty() and player_ids.is_empty():
		boons.add_child(UiTheme.label("No upgrades yet", UiTheme.FONT_SMALL))


## A row per training line at the profile's rank (the save is read on every open: a rank bought
## at the post shows the next time).
func _rebuild_training() -> void:
	UiTheme.clear_children(training)
	for line: String in TrainingRules.LINES:
		training.add_child(TrainingPanel.line_box(line, TrainingRules.rank(Profile.save, line)))


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
