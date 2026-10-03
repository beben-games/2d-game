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
## press. The reveal runs on the Clock (the engine's unscaled time), so neither the pause nor a
## time scale touches it.
##
## The timed mode (show_timed, hide_timed: the narrator at the verdict) shows one line in the same
## box without input, pause, or wait: the caller hides it when its time is up. It never sets the
## open flag (is_open() stays false: nothing it covers is blocked, and no input is read for it;
## the box and its children ignore the mouse), shows no mark at the line's end, and the line is
## revealed as a played line is. A cast member marked `"silhouette": true` shows its portrait as a
## dark shape, and a member with no name shows none (the line takes the name's place). A play
## takes the box over from a timed line (the line hidden first, the caller's late hide_timed then
## a no-op); a timed line while an event plays is refused.

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
## The portrait of a cast member marked `"silhouette": true`: the sprite's shape, all but black.
const SILHOUETTE := Color(0.06, 0.05, 0.05)
## The timed window: the same frame, narrower and one line tall (two wrapped at most: the
## catalog's TIMED_LINE_CAP fits one), so it hides less of the scene it speaks over; the portrait
## smaller beside the line (a 16 x 28 frame at 3x fits).
const TIMED_BOX_SIZE := Vector2(864, 160)
const TIMED_PORTRAIT_SCALE := 3.0
const TIMED_PORTRAIT_SLOT := Vector2(64, 96)
const TIMED_MAX_LINES := 2

## Letters a second; a test lowers it to hold a line mid-reveal.
var reveal_per_second := REVEAL_PER_SECOND
var box: Control
var portrait: TextureRect
var name_label: Label
var line_label: Label
var choices_box: VBoxContainer
var more_mark: Polygon2D

## The two frames, one shown: the box's and the timed window's.
var _frame: Control
var _timed_frame: Control
var _open := false
var _timed := false
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
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_frame = _framed("Frame", BOX_SIZE)
	_timed_frame = _framed("TimedFrame", TIMED_BOX_SIZE)
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
	box.add_child(name_label)
	line_label = UiTheme.label("", FONT_SIZE)
	line_label.name = "Line"
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # no word jumps a line as it grows
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
	_layout()
	visible = false


## A frame of `size` on the box (the paper and the border), shown by _layout for its mode.
func _framed(node_name: String, size: Vector2) -> Control:
	var host := Control.new()
	host.name = node_name
	host.size = size
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(host)
	UiTheme.framed_panel(host, size, PANEL_SCALE)
	return host


## The box's size, its frame, and the text's column for the mode on show (_timed: the timed
## window); the line's place under the name is _show_speaker's.
func _layout() -> void:
	var size := TIMED_BOX_SIZE if _timed else BOX_SIZE
	var slot := TIMED_PORTRAIT_SLOT if _timed else PORTRAIT_SLOT
	box.size = size
	_frame.visible = not _timed
	_timed_frame.visible = _timed
	var text_x := INSET + slot.x + TEXT_GAP
	name_label.position = Vector2(text_x, INSET)
	name_label.size = Vector2(size.x - text_x - INSET, LINE_TOP)
	line_label.position.x = text_x
	line_label.size.x = size.x - text_x - INSET
	line_label.max_lines_visible = TIMED_MAX_LINES if _timed else MAX_LINES


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
	hide_timed()
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


## True while an event plays (the normal mode); never for a timed line.
func is_open() -> bool:
	return _open


## True while a timed line is up.
func is_timed() -> bool:
	return _timed


## One line of `speaker_id`'s (a cast id) in the timed mode, at the top of the view or its
## bottom: shown and revealed at once, no input, no pause, nothing awaited; up until hide_timed (a
## new show_timed replaces the line). Refused while an event plays (an error, nothing changed).
func show_timed(speaker_id: String, text: String, at_top := false) -> void:
	if _open:
		push_error("DialogueBox: a timed line while an event plays")
		return
	_timed = true
	_layout()
	_place(at_top)
	_show_line(speaker_id, text)
	visible = true


## The timed line gone; nothing when none is up (a play took the box over, or none was shown).
func hide_timed() -> void:
	if not _timed:
		return
	_timed = false
	_revealing = false
	visible = false


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
	_layout()
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
	var y := view.position.y + EDGE_GAP if top else view.end.y - box.size.y - EDGE_GAP
	box.position = Vector2(view.position.x + (view.size.x - box.size.x) * 0.5, y).round()


## A box freed mid-play (its scene torn down) leaves no paused tree behind.
func _exit_tree() -> void:
	if _open:
		_open = false
		get_tree().paused = false


## The line `entry` (a StoryEvent.shown_line), revealed from its first letter; returns when a
## press passes it whole.
func _say(entry: Dictionary) -> void:
	_show_line(entry["speaker"], entry["text"])
	await _stepped


## The speaker and the line, revealed from its first letter (both modes).
func _show_line(speaker_id: String, text: String) -> void:
	_show_speaker(speaker_id)
	line_label.visible = true
	line_label.text = text
	more_mark.visible = false
	_letters = 0
	_blips = 0
	_reveal_start_usec = Clock.now_usec()
	_revealing = true
	_reveal()


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


## The cast member's name (the marker stripped; with none, no name, and the line takes the text
## column's height, centred), portrait (a silhouette when the member is marked so), and bleep.
func _show_speaker(cast_id: String) -> void:
	var entry: Variant = Story.catalog.cast.get(cast_id, {})
	var member: Dictionary = entry if entry is Dictionary else {}
	name_label.text = StoryScript.strip_marker(str(member.get("name", "")))
	name_label.visible = name_label.text != ""
	var top := LINE_TOP if name_label.visible else 0.0
	line_label.position.y = INSET + top
	line_label.size.y = box.size.y - INSET * 2.0 - top
	line_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if name_label.visible else VERTICAL_ALIGNMENT_CENTER
	_voice = str(member.get("bleep", ""))
	var sprite := str(member.get("sprite", ""))
	portrait.visible = SpriteAtlas.has(sprite)
	if not portrait.visible:
		return
	portrait.modulate = SILHOUETTE if member.get("silhouette", false) == true else Color.WHITE
	portrait.texture = SpriteAtlas.texture(sprite)
	var slot := TIMED_PORTRAIT_SLOT if _timed else PORTRAIT_SLOT
	var size := SpriteAtlas.region(sprite).size * (TIMED_PORTRAIT_SCALE if _timed else PORTRAIT_SCALE)
	portrait.size = size
	portrait.position = Vector2(INSET + (slot.x - size.x) * 0.5, INSET + slot.y - size.y).round()


func _process(_delta: float) -> void:
	if _revealing:
		_reveal()


## The letters the Clock has reached since the line began (the first at once), a bleep for
## each BLIP_EVERY of them reached (one a frame at most).
func _reveal() -> void:
	var total := line_label.text.length()
	var elapsed := float(Clock.now_usec() - _reveal_start_usec) / 1000000.0
	_letters = mini(total, int(elapsed * reveal_per_second) + 1)
	line_label.visible_characters = _letters
	@warning_ignore("integer_division")
	var due := (_letters + BLIP_EVERY - 1) / BLIP_EVERY
	if due > _blips:
		_blips = due
		Events.dialogue_blip.emit(_voice)
	if _letters >= total:
		_whole()


## The line shown whole, the mark at its end (a played line's: a timed line waits for no press).
func _whole() -> void:
	_revealing = false
	_letters = line_label.text.length()
	line_label.visible_characters = -1
	more_mark.visible = _open


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
