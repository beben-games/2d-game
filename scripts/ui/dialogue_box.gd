class_name DialogueBox
extends CanvasLayer
## The text box: an event of the story played line by line at the bottom or the top of the view
## (the caller's choice: Main puts it on the side away from the gladiator), in the UI sheet's
## frame. The speaker's portrait (the cast sprite's first frame, scaled) at the left, the
## cast's name over the line (the PLACEHOLDER marker never shown), the line revealed letter by
## letter at reveal_per_second (REVEAL_PER_SECOND) with the speaker's bleep (Events.dialogue_blip
## with the cast's `bleep`) every BLIP_EVERY letters. E (interact), Enter (ui_accept, but not
## Space: it is the dash, and a Space that closed the box would dash on the unpaused grounds), or
## a click completes a line still revealing, then advances; after the lines the event's choices replace
## the name and the line as a numbered list, taken with pick_1.. (StoryCatalog.CHOICE_MAX of them)
## or a click: the choice's effects run (Story.choose), then its lines play (Story.choice_lines),
## then the event's body is read again past the choices, so every line after a choice, its own or
## the event's, reads the flags the choice set. A line shows three wrapped lines at most (the
## catalog caps a line at StoryCatalog.BOX_LINE_CAP; MAX_LINES guards a long substitution). A small
## wordless mark at the line's end shows when the line is whole. Nothing else is written on it: a
## name and a line.
##
## Paused like the menus (process_mode ALWAYS, Juice.reset() first): the tree is paused from
## play() until the last line is passed, when the box hides, unpauses, and finished goes out (the
## await of play() resolves with it). A play while the tree is already paused (by a menu) or while
## an event plays is refused; a box freed mid-play unpauses the tree. The event counts as played from its start (the caller's
## Story.begin), so there is no way to close it early. Input is read as events, never polled:
## the E that opened the box was handled by the grounds before it opened (the box, later in the
## tree, saw it first, still shut), and the press that advances or closes is marked handled here,
## so the E that ends the last line never reaches the unpaused grounds. A held key's echo is no
## press. The reveal runs on the wall clock (Time.get_ticks_usec), so neither the pause nor a
## time scale touches it.

signal finished
## A press with the line whole: on to the next.
signal _stepped
## A choice taken: its index in the shown list.
signal _picked(index: int)

## Letters a second, real time.
const REVEAL_PER_SECOND := 40.0
## A bleep every this many letters revealed (the first letter's included).
const BLIP_EVERY := 3
## The box, centred across the view at its bottom or its top; whole nine-patch pixels at PANEL_SCALE.
const BOX_SIZE := Vector2(1152, 224)
const PANEL_SCALE := 4.0
## Between the box and the view's edge it stands at (the bottom, or the top).
const EDGE_GAP := 24.0
## Inside the frame, around the portrait and the text.
const INSET := 32.0
## The portrait: the sprite's first frame at this scale, bottom-centred in PORTRAIT_SLOT (the
## ogre's 32 x 36 frame at 4x fits).
const PORTRAIT_SCALE := 4.0
const PORTRAIT_SLOT := Vector2(128, 160)
## Between the portrait and the text.
const TEXT_GAP := 24.0
const FONT_SIZE := UiTheme.FONT_SMALL
## The line starts this far under the name's top.
const LINE_TOP := 40.0
## The wrapped lines a line shows at most (the catalog's BOX_LINE_CAP fits them; a long
## substitution is cut here rather than run over the frame).
const MAX_LINES := 3
## A choice's row.
const CHOICE_HEIGHT := 32.0
const CHOICE_HOVER := Color(1.12, 1.12, 1.12)
## The mark at the line's end once it is whole: a small down-pointing triangle.
const MORE_SIZE := Vector2(16, 8)

## Letters a second; a test lowers it to hold a line mid-reveal.
var reveal_per_second := REVEAL_PER_SECOND
var box: Control
var portrait: TextureRect
var name_label: Label
var line_label: Label
var choices_box: VBoxContainer
var more_mark: Polygon2D

var _open := false
var _revealing := false
var _choosing := false
var _letters := 0
var _blips := 0
var _reveal_start_usec := 0
var _voice := ""
var _choice_count := 0


func _ready() -> void:
	box = Control.new()
	box.name = "Box"
	box.size = BOX_SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	UiTheme.framed_panel(box, BOX_SIZE, PANEL_SCALE)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)
	var text_x := INSET + PORTRAIT_SLOT.x + TEXT_GAP
	var text_size := Vector2(BOX_SIZE.x - text_x - INSET, BOX_SIZE.y - INSET * 2.0)
	name_label = UiTheme.title("", FONT_SIZE)
	name_label.name = "Name"
	name_label.position = Vector2(text_x, INSET)
	name_label.size = Vector2(text_size.x, LINE_TOP)
	box.add_child(name_label)
	line_label = UiTheme.label("", FONT_SIZE)
	line_label.name = "Line"
	line_label.position = Vector2(text_x, INSET + LINE_TOP)
	line_label.size = Vector2(text_size.x, text_size.y - LINE_TOP)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # no word jumps a line as it grows
	line_label.max_lines_visible = MAX_LINES
	box.add_child(line_label)
	choices_box = VBoxContainer.new()
	choices_box.name = "Choices"
	choices_box.position = Vector2(text_x, INSET)
	choices_box.size = text_size
	choices_box.add_theme_constant_override("separation", 0)
	choices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(choices_box)
	more_mark = Polygon2D.new()
	more_mark.name = "More"
	more_mark.polygon = PackedVector2Array([Vector2.ZERO, Vector2(MORE_SIZE.x, 0.0), Vector2(MORE_SIZE.x * 0.5, MORE_SIZE.y)])
	more_mark.color = UiTheme.INK
	more_mark.position = BOX_SIZE - Vector2(INSET, INSET) - MORE_SIZE
	more_mark.visible = false
	box.add_child(more_mark)
	visible = false


## Plays `event` (its lines read through Story.lines with `facts`, then its choices and what
## follows each) at the top of the view or its bottom, and returns when the last line is passed:
## the box is shut and the tree unpaused by then. The caller begins and finishes the event
## (Story.begin, Story.finish). An event with nothing to show opens and shuts at once. A play while
## one is open, or while the tree is paused by something else, is refused (an error; nothing
## paused or unpaused).
func play(event: StoryEvent, facts: Dictionary = {}, at_top := false) -> void:
	if _open:
		push_error("DialogueBox: %s while another event plays" % event.id)
		return
	if get_tree().paused:
		push_error("DialogueBox: %s while the tree is paused" % event.id)
		return
	_open_box(event, at_top)
	var entries := Story.lines(event, facts)
	var offered := 0
	var i := 0
	while i < entries.size():
		var entry: Dictionary = entries[i]
		if entry["kind"] == "line":
			await _say(entry)
			i += 1
			continue
		var group: Array = []
		while i < entries.size() and (entries[i] as Dictionary)["kind"] == "choice":
			group.append(entries[i])
			i += 1
		var picked: int = await _offer(group)
		Story.choose((group[picked] as Dictionary)["effects"])
		for line: Dictionary in Story.choice_lines(event, offered + picked, facts):
			await _say(line)
		offered += group.size()
		# The rest of the body read again with the choice's flags set (a choice is never dropped,
		# so the count of choices offered finds the place).
		entries = Story.lines(event, facts)
		i = past_choices(entries, offered)
	_shut()
	finished.emit()


## The index in `entries` (Story.lines's) just past its `count`-th choice: where the body goes on
## after that many choices were offered.
static func past_choices(entries: Array, count: int) -> int:
	var seen := 0
	for index in entries.size():
		if seen == count:
			return index
		if (entries[index] as Dictionary)["kind"] == "choice":
			seen += 1
	return entries.size()


func is_open() -> bool:
	return _open


## True while the line on show is still growing.
func is_revealing() -> bool:
	return _revealing


## True while the choices are up.
func choosing() -> bool:
	return _choosing


## The letters of the line on show.
func shown_letters() -> int:
	return _letters


## The choices' buttons, first to last (none unless choosing).
func choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in choices_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			buttons.append(child as Button)
	return buttons


func _open_box(event: StoryEvent, at_top: bool) -> void:
	_open = true
	_choosing = false
	_show_speaker(event.pool)
	line_label.text = ""
	_place(at_top)
	Juice.reset()  # a freeze's time scale must not outlive the pause (none is live in the grounds)
	get_tree().paused = true
	visible = true


func _shut() -> void:
	_open = false
	_revealing = false
	_choosing = false
	_clear_choices()
	visible = false
	get_tree().paused = false


## True while the box stands at the top of the view (the play's choice).
func at_top() -> bool:
	return box.position.y < get_viewport().get_visible_rect().get_center().y


## The box centred across the view, EDGE_GAP from its top or its bottom.
func _place(top: bool) -> void:
	var view := get_viewport().get_visible_rect()
	var y := view.position.y + EDGE_GAP if top else view.end.y - BOX_SIZE.y - EDGE_GAP
	box.position = Vector2(view.position.x + (view.size.x - BOX_SIZE.x) * 0.5, y).round()


## A box freed mid-play (its scene torn down) leaves no paused tree behind.
func _exit_tree() -> void:
	if _open:
		_open = false
		get_tree().paused = false


## The line `entry` (a StoryEvent.shown_line), revealed from its first letter; returns when a
## press passes it whole.
func _say(entry: Dictionary) -> void:
	_show_speaker(entry["speaker"])
	name_label.visible = true
	line_label.visible = true
	line_label.text = entry["text"]
	more_mark.visible = false
	_letters = 0
	_blips = 0
	_reveal_start_usec = Time.get_ticks_usec()
	_revealing = true
	_reveal()
	await _stepped


## The choices (StoryEvent.shown_choice entries) as a numbered list in place of the name and the
## line; returns the index taken.
func _offer(group: Array) -> int:
	_revealing = false
	_choosing = true
	name_label.visible = false
	line_label.visible = false
	more_mark.visible = false
	_clear_choices()
	_choice_count = group.size()
	for i in group.size():
		choices_box.add_child(_choice_button(i, (group[i] as Dictionary)["text"]))
	choices_box.visible = true
	var index: int = await _picked
	_choosing = false
	_clear_choices()
	return index


## The choices gone: queued, never removed at once (a click's own Button is still handling the
## press that took it).
func _clear_choices() -> void:
	choices_box.visible = false
	for child in choices_box.get_children():
		child.queue_free()


func _choice_button(index: int, text: String) -> Button:
	var button := Button.new()
	button.name = "Choice%d" % (index + 1)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, CHOICE_HEIGHT)
	var label := UiTheme.label("%d  %s" % [index + 1, text], FONT_SIZE)
	label.name = "Text"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_child(label)
	button.pressed.connect(func() -> void: _pick(index))
	button.mouse_entered.connect(func() -> void: button.modulate = CHOICE_HOVER)
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	return button


## The cast member's name (the marker stripped), portrait, and bleep.
func _show_speaker(cast_id: String) -> void:
	var entry: Variant = Story.catalog.cast.get(cast_id, {})
	var member: Dictionary = entry if entry is Dictionary else {}
	name_label.text = StoryScript.strip_marker(str(member.get("name", "")))
	_voice = str(member.get("bleep", ""))
	var sprite := str(member.get("sprite", ""))
	portrait.visible = SpriteAtlas.has(sprite)
	if not portrait.visible:
		return
	portrait.texture = SpriteAtlas.texture(sprite)
	var size := SpriteAtlas.region(sprite).size * PORTRAIT_SCALE
	portrait.size = size
	portrait.position = Vector2(INSET + (PORTRAIT_SLOT.x - size.x) * 0.5, INSET + PORTRAIT_SLOT.y - size.y).round()


func _process(_delta: float) -> void:
	if _revealing:
		_reveal()


## The letters the wall clock has reached since the line began (the first at once), a bleep for
## each BLIP_EVERY of them reached (one a frame at most).
func _reveal() -> void:
	var total := line_label.text.length()
	var elapsed := float(Time.get_ticks_usec() - _reveal_start_usec) / 1000000.0
	_letters = mini(total, int(elapsed * reveal_per_second) + 1)
	line_label.visible_characters = _letters
	@warning_ignore("integer_division")
	var due := (_letters + BLIP_EVERY - 1) / BLIP_EVERY
	if due > _blips:
		_blips = due
		Events.dialogue_blip.emit(_voice)
	if _letters >= total:
		_whole()


## The line shown whole, the mark at its end.
func _whole() -> void:
	_revealing = false
	_letters = line_label.text.length()
	line_label.visible_characters = -1
	more_mark.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if _choosing:
		for i in StoryCatalog.CHOICE_MAX:
			if event.is_action_pressed(pick_action(i)):
				get_viewport().set_input_as_handled()
				_pick(i)
				return
		return
	if not _is_press(event):
		return
	get_viewport().set_input_as_handled()  # first: the step may shut the box and unpause the grounds
	if _revealing:
		_whole()
	else:
		more_mark.visible = false
		_stepped.emit()


## The key of the index-th choice (0 is the first): pick_1 to pick_<StoryCatalog.CHOICE_MAX>.
static func pick_action(index: int) -> String:
	return "pick_%d" % (index + 1)


## E, Enter, or a left click, pressed (an echo is no press). ui_accept's Space is the dash: not a
## press here.
static func _is_press(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	if event.is_action_pressed("ui_accept") and not event.is_action("dash"):
		return true
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT


func _pick(index: int) -> void:
	if not _choosing or index < 0 or index >= _choice_count:
		return
	_picked.emit(index)
