@tool
extends ScrollContainer
## The Story tab's What-if side tab (Task 14): the controls of the scratch state the controller
## (story_whatif.gd) holds, built in code. Blank and Load my save; the moment and its facts; the
## selected event's reasons; who has spoken this return and Return; the profile's counts and flags;
## the last run's facts; the story flags (a box for a bool, a spinner for an int, a field for a
## word). Each control sets the controller and emits `changed`; the tab draws the graph from the
## controller again. The controls show the state again (refresh) only after Blank, a load, and a new
## set of declared flags, so nothing typed is overwritten. Every pixel size at the editor's scale.

signal changed

const EventNode := preload("res://addons/story_graph/event_node.gd")
const StoryWhatIf := preload("res://addons/story_graph/story_whatif.gd")
## At scale 1.
const FIELD_WIDTH := 120.0
const MAX_COUNT := 9999

var whatif: StoryWhatIf = null
## The catalog the story flags' controls were built for.
var catalog: StoryCatalog = null
var _flags_built: Dictionary = {}
var _message: Label
var _moment: OptionButton
## Moment fact -> [its label, its OptionButton].
var _fact_rows: Dictionary = {}
var _selected: Label
var _reasons: Label
var _spoken: Label
## Profile flag -> its SpinBox or CheckBox.
var _profile: Dictionary = {}
## Last-run fact -> its OptionButton or LineEdit.
var _last: Dictionary = {}
var _flags: GridContainer
## Story flag -> its CheckBox, SpinBox, or LineEdit.
var _flag_controls: Dictionary = {}


## The controls built for the controller (once).
func setup(state: StoryWhatIf) -> void:
	whatif = state
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	buttons.add_child(_button("Blank", "Start from nothing: no runs, nothing played, no flags set.", blank))
	buttons.add_child(_button("Load my save", "Read a copy of %s (the game's save) into the What-if state; the file itself is never written." % whatif.source_path, load_save))
	_message = _wrapped("")
	box.add_child(_message)
	box.add_child(_heading("Moment"))
	var moment_grid := _grid()
	box.add_child(moment_grid)
	_moment = OptionButton.new()
	_moment.tooltip_text = "The moment the game asks the story at: a talk, a room's entry, the verdict, the pick."
	for text in whatif.moments():
		_moment.add_item(text)
	_moment.item_selected.connect(func(index: int) -> void: _set_moment(_moment.get_item_text(index)))
	_row(moment_grid, "Trigger", _moment)
	for name: String in whatif.moment_values:
		var option := _words(StoryContext.WORDS[name], func(word: String) -> void: _apply(whatif.set_fact(name, word)))
		_fact_rows[name] = [_row(moment_grid, name, option), option]
	box.add_child(_heading("Selected"))
	_selected = _wrapped("No event selected")
	box.add_child(_selected)
	_reasons = _wrapped("")
	box.add_child(_reasons)
	box.add_child(_heading("This return"))
	var spoken_row := HBoxContainer.new()
	box.add_child(spoken_row)
	_spoken = Label.new()
	_spoken.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spoken.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spoken_row.add_child(_spoken)
	spoken_row.add_child(_button("Return", "A run's end: every character may speak again.", new_return))
	box.add_child(_heading("Profile"))
	var profile_grid := _grid()
	box.add_child(profile_grid)
	for key: String in Save.FLAG_KEYS:
		var kind: Variant = Save.FLAG_KEYS[key]
		if not (kind is bool or kind is int):
			push_warning("What-if: the profile flag %s is neither an int nor a bool; the panel does not show it" % key)
			continue
		var control: Control = _check(func(on: bool) -> void: _apply(whatif.set_profile(key, on))) if kind is bool else _spin(func(value: int) -> void: _apply(whatif.set_profile(key, value)))
		_profile[key] = control
		_row(profile_grid, key, control)
	box.add_child(_heading("Last run"))
	var last_grid := _grid()
	box.add_child(last_grid)
	for name in StoryWhatIf.LAST_RUN:
		var control: Control
		if name in StoryContext.OPEN_WORDS:
			control = _field(func(text: String) -> void: _apply(whatif.set_last(name, text)), StoryContext.NONE)
		else:
			control = _words(StoryContext.WORDS[name], func(word: String) -> void: _apply(whatif.set_last(name, word)))
		_last[name] = control
		_row(last_grid, name, control)
	box.add_child(_heading("Story flags"))
	_flags = _grid()
	box.add_child(_flags)
	refresh()


## The story flags' controls for the catalog's declared flags (rebuilt only when they change).
func show_catalog(story: StoryCatalog) -> void:
	catalog = story
	if story.flags == _flags_built:
		return
	_flags_built = story.flags.duplicate()
	for child in _flags.get_children():  # freed in place (removed first, they would be orphans until freed)
		(child as Control).hide()
		child.queue_free()
	_flag_controls.clear()
	for name: String in story.flags:
		var default: Variant = story.flags[name]
		var control: Control
		if default is bool:
			control = _check(func(on: bool) -> void: _apply(whatif.set_story_flag(catalog, name, on)))
		elif default is int:
			control = _spin(func(value: int) -> void: _apply(whatif.set_story_flag(catalog, name, value)), -MAX_COUNT)
		else:
			control = _field(func(text: String) -> void: _apply(whatif.set_story_flag(catalog, name, text)), str(default))
		_flag_controls[name] = control
		_row(_flags, name, control)
	refresh()


## The selected event and its reasons, and who has spoken.
func show_view(id: String, reasons: Array[String]) -> void:
	_selected.text = id if id != "" else "No event selected"
	_reasons.text = "\n".join(reasons)
	var spoken := whatif.spoken()
	_spoken.text = "Spoken: " + (", ".join(spoken) if not spoken.is_empty() else "nobody")


## The reasons shown, and the message under the buttons (a test reads them).
func reasons_text() -> String:
	return _reasons.text


func message_text() -> String:
	return _message.text


## Every control shows the controller's state, emitting nothing.
func refresh() -> void:
	_moment.select(whatif.moments().find(whatif.moment()))
	var shown := whatif.moment_fact_names()
	for name: String in _fact_rows:
		var row: Array = _fact_rows[name]
		(row[0] as Control).visible = shown.has(name)
		(row[1] as Control).visible = shown.has(name)
		_show_word(row[1], whatif.moment_values[name])
	for key: String in _profile:
		_show_value(_profile[key], whatif.save.flags[key])
	for name: String in _last:
		_show_value(_last[name], whatif.last_run[name])
	if catalog != null:
		for name: String in _flag_controls:
			_show_value(_flag_controls[name], whatif.story_flag(catalog, name))


func blank() -> void:
	whatif.blank()
	_message.text = "Blank: no runs, nothing played, no flags set."
	refresh()
	changed.emit()


## Load my save: the result said under the buttons; a refusal changes nothing.
func load_save() -> void:
	var result := whatif.load_save()
	_message.text = result["message"]
	if result["ok"]:
		refresh()
		changed.emit()


func new_return() -> void:
	whatif.new_return()
	changed.emit()


## The moment's control (a test sets it by text).
func set_moment_text(text: String) -> void:
	var index := whatif.moments().find(text)
	if index >= 0:
		_moment.select(index)
		_set_moment(text)


## The control of a profile flag, a last-run fact, a story flag, or a moment fact (a test drives it).
func control_of(name: String) -> Control:
	for table: Dictionary in [_profile, _last, _flag_controls]:
		if table.has(name):
			return table[name]
	return (_fact_rows[name] as Array)[1] if _fact_rows.has(name) else null


func _set_moment(text: String) -> void:
	if whatif.set_moment(text):
		refresh()
		changed.emit()


func _apply(made: bool) -> void:
	if made:
		changed.emit()


# --- controls -------------------------------------------------------------------------------------

func _button(text: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(action)
	return button


static func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "HeaderSmall"
	return label


static func _wrapped(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = FIELD_WIDTH * EventNode.editor_scale()
	return label


static func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	return grid


## A label and its control as one row of the grid; returns the label.
static func _row(grid: GridContainer, text: String, control: Control) -> Label:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.x = FIELD_WIDTH * EventNode.editor_scale()
	grid.add_child(control)
	return label


static func _words(words: Array, on_word: Callable) -> OptionButton:
	var option := OptionButton.new()
	for word: String in words:
		option.add_item(word)
	option.item_selected.connect(func(index: int) -> void: on_word.call(option.get_item_text(index)))
	return option


static func _check(on_toggle: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.toggled.connect(on_toggle)
	return check


static func _spin(on_value: Callable, low := 0) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = MAX_COUNT
	spin.step = 1
	spin.rounded = true
	spin.value_changed.connect(func(value: float) -> void: on_value.call(int(value)))
	return spin


## A field for a word: each change sets the state, an empty one meaning `empty` (a flag's declared
## default, "none" for the killer), shown as the placeholder while typing and put back in the field
## when the edit ends (Enter or the focus leaving), so the field never disagrees with the state.
static func _field(on_text: Callable, empty: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = empty
	field.text_changed.connect(on_text)
	var settle := func(_text := "") -> void:
		if field.text.strip_edges() == "":
			field.text = empty
	field.text_submitted.connect(settle)
	field.focus_exited.connect(settle)
	return field


static func _show_word(option: OptionButton, word: String) -> void:
	for index in option.item_count:
		if option.get_item_text(index) == word:
			option.select(index)


static func _show_value(control: Control, value: Variant) -> void:
	if control is CheckBox:
		(control as CheckBox).set_pressed_no_signal(bool(value))
	elif control is SpinBox:
		(control as SpinBox).set_value_no_signal(int(value))
	elif control is OptionButton:
		_show_word(control, str(value))
	elif control is LineEdit and (control as LineEdit).text != str(value):
		(control as LineEdit).text = str(value)
