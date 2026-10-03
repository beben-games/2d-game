@tool
extends VBoxContainer
## The Story tab: the story in `dir` (data/story) as a graph, and its editing. A lane per character
## (a frame, the cast's order), a node per event placed by StoryLayout (columns by depth in the
## chain of requires), the three kinds of edge from StoryLinks told apart by colour (the legend),
## every event the files hold even when the catalog left it out (StoryGraph: its errors as its
## badge). The toolbar reloads from disk, saves, filters by character and act, and searches ids and
## text (a node that does not match dims); the catalog's errors, the load's warnings, and a failed
## save's errors list under it (a click selects the event); the side panel edits the selected event.
##
## Editing (Task 13). The rules live in the session (story_session.gd: the StoryEdit every change
## goes through, the selection, the drafts, the drag's state, each gesture's Outcome); this tab
## draws, holds the dialogs, wires GraphEdit's and the controls' signals to the session, and renders
## what each gesture returns. The gestures:
## - a drag from a node's row to another node's same row adds that kind of link (the port types
##   keep a drag to its row); dragging an edge's right end off its port removes it, dropped on
##   another port moves it, dropped back or clicked leaves it; a right-click near an edge offers its
##   removal. A flag link is derived and refused with why.
## - a lane's "+ Event" adds an event; a node's menu (its title bar, or a right-click) renames or
##   deletes it; the Delete key deletes the selected events as one gesture, after asking.
## - the side panel: the header as controls (priority, once or repeat, the trigger and its room, the
##   act, the when field), the event as text in the file's format in a CodeEdit (Apply; its errors
##   listed under it and their lines marked). Text not applied is a draft, kept per event across
##   selections and every edit elsewhere; the header controls wait while the event has one.
## - Save writes the pools with unsaved edits; their lanes say "unsaved" until then. Reload with
##   unsaved edits or drafts asks first; the plugin asks on quit (unsaved_status) and saves on the
##   editor's save (save_external: the pools only, never a draft).
## The story's errors stop every edit: the text is read only until the files are fixed.
##
## The pixel layout is measured, so it holds at any editor scale; every other pixel size is
## multiplied by the editor's scale. Built on the first showing (ensure_built: the plugin's
## _make_visible), never at editor start.
##
## Room for the next tasks: What-if (Task 14) is another tab of the side panel and dims by its own
## reason (EventNode.set_dim), its state beside the session's; the lint's badges (Task 15) are more
## keys of StoryGraph.badges.

const EventNode := preload("res://addons/story_graph/event_node.gd")
const StorySession := preload("res://addons/story_graph/story_session.gd")
## At scale 1 (EventNode.editor_scale() times these): the room between columns (the edges run
## there), between rows, and around a lane's nodes inside its frame.
const COLUMN_GAP := 72.0
const ROW_GAP := 20.0
const LANE_MARGIN := 16.0
const SWATCH := 14.0
## How near a right-click must be to an edge to offer its removal, at scale 1.
const EDGE_REACH := 8.0
const LANE_TINTS: Array[Color] = [Color(0.3, 0.45, 0.7, 0.10), Color(0.7, 0.55, 0.3, 0.10)]
const WARNING_COLOR := Color(0.95, 0.8, 0.35)
const SAVED_COLOR := Color(0.55, 0.85, 0.55)
const ERROR_LINE_COLOR := Color(0.85, 0.2, 0.2, 0.3)
## The dimming reason of the toolbar's filters and search.
const FILTER := "filter"
## A lane's title while its pool has unsaved edits.
const UNSAVED_MARK := "  (unsaved)"
## The once-or-repeat control's items, as set_header's `repeat` values.
const REPEAT_WORDS: Array[String] = ["once", "repeat"]

## The story's directory.
var dir := StoryCatalog.DATA_DIR
## The editing of the story drawn (a new one at each load).
var session: StorySession = null
## The session's, for the tests and the next tasks.
var edit: StoryEdit:
	get:
		return session.edit if session != null else null
var catalog: StoryCatalog:
	get:
		return session.edit.catalog if session != null else null
var model: StoryGraph:
	get:
		return session.model if session != null else null
var selected: String:
	get:
		return session.selected if session != null else ""
var drafts: Dictionary:
	get:
		return session.drafts if session != null else {}
## The pointer in the graph's pixels when called (a test sets it); when unset, the last mouse
## event's position (_input).
var pointer := Callable()
## Event id -> its EventNode.
var nodes: Dictionary = {}
## Pool -> its lane's GraphFrame.
var lanes: Dictionary = {}
## A floor under every node's minimum size (none at Vector2.ZERO): a test's way to make the nodes
## big, as a larger editor scale or font does.
var node_floor := Vector2.ZERO
## StoryLayout's grid cell in pixels, as last measured.
var cell := Vector2.ZERO
var built := false
var _building := false
## The event whose text the side panel holds ("" none).
var _shown := ""
var _confirm: ConfirmationDialog = null
var _confirm_action := Callable()
var _name_dialog: ConfirmationDialog = null
var _name_field: LineEdit = null
var _name_action := Callable()
var _alert: AcceptDialog = null
var _edge_menu: PopupMenu = null
## The edge the edge menu is about: {"kind", "from", "to"}.
var _edge: Dictionary = {}
## The last mouse event's position in the graph's pixels: read from the events themselves, which
## reach _input before GraphEdit handles the same press or release (the display's mouse position
## is not the event's, and a headless run never moves it).
var _last_pointer := Vector2.ZERO

@onready var graph: GraphEdit = %Graph
@onready var _reload: Button = %Reload
@onready var _save: Button = %Save
@onready var _character: OptionButton = %Character
@onready var _act: OptionButton = %Act
@onready var _search: LineEdit = %Search
@onready var _legend: HBoxContainer = %Legend
@onready var _status: Label = %Status
@onready var _notice: Label = %Notice
@onready var _errors: ItemList = %Errors
@onready var _title: Label = %Title
@onready var _facts: Label = %Facts
@onready var _header: GridContainer = %Header
@onready var _priority: OptionButton = %EventPriority
@onready var _repeat: OptionButton = %EventRepeat
@onready var _trigger: OptionButton = %EventTrigger
@onready var _room: OptionButton = %EventRoom
@onready var _event_act: OptionButton = %EventAct
@onready var _when: LineEdit = %EventWhen
@onready var _when_set: Button = %EventWhenSet
@onready var _text: CodeEdit = %Text
@onready var _apply: Button = %Apply
@onready var _revert: Button = %Revert
@onready var _event_errors: ItemList = %EventErrors


func _ready() -> void:
	if is_part_of_edited_scene():
		return
	var factor := EventNode.editor_scale()
	for control: Control in [_search, _errors, %Side, _facts, _event_errors]:
		control.custom_minimum_size *= factor
	_build_legend(factor)
	for item: Array in act_items():
		_act.add_item(item[0])
		_act.set_item_metadata(_act.item_count - 1, item[1])
	_fill_header_items()
	_make_dialogs()
	_reload.pressed.connect(reload)
	_save.pressed.connect(save)
	_character.item_selected.connect(_on_filter.unbind(1))
	_act.item_selected.connect(_on_filter.unbind(1))
	_search.text_changed.connect(_on_filter.unbind(1))
	graph.right_disconnects = true
	graph.node_selected.connect(_on_node_selected)
	graph.node_deselected.connect(_on_node_deselected)
	graph.connection_drag_started.connect(_on_connection_drag_started)
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	graph.connection_drag_ended.connect(_on_connection_drag_ended)
	graph.delete_nodes_request.connect(_on_delete_nodes_request)
	graph.popup_request.connect(_on_popup_request)
	_errors.item_clicked.connect(_on_error_clicked)
	_priority.item_selected.connect(func(index: int) -> void: set_field("priority", StoryScript.PRIORITIES[index]))
	_repeat.item_selected.connect(func(index: int) -> void: set_field("repeat", REPEAT_WORDS[index]))
	_trigger.item_selected.connect(func(_index: int) -> void: set_field("trigger", _trigger_value()))
	_room.item_selected.connect(func(_index: int) -> void: set_field("trigger", _trigger_value()))
	_event_act.item_selected.connect(func(index: int) -> void: set_field("act", "" if index == 0 else str(index)))
	_when.text_changed.connect(_on_when_changed)
	_when.text_submitted.connect(func(text: String) -> void: set_field("when", text))
	_when_set.pressed.connect(func() -> void: set_field("when", _when.text))
	_text.text_changed.connect(_on_text_changed)
	_text.text_set.connect(_on_text_changed)
	_apply.pressed.connect(apply_text)
	_revert.pressed.connect(revert_text)
	_event_errors.item_clicked.connect(_on_event_error_clicked)
	show_event("")


## The act filter's items, [text, act]: every act, each act to StoryScript.ACT_MAX, no act.
static func act_items() -> Array[Array]:
	var items: Array[Array] = [["All acts", StoryGraph.ANY_ACT]]
	for act in range(1, StoryScript.ACT_MAX + 1):
		items.append(["Act %d" % act, act])
	items.append(["No act", 0])
	return items


## Builds the graph once (the tab's first showing).
func ensure_built() -> void:
	if not built:
		_load()


## The story read again from `dir`: a file edited outside shows. With unsaved edits or text not
## applied, it asks first (the dialog's OK reloads).
func reload() -> void:
	if has_unsaved():
		_ask("Discard %s and read the story again from %s?" % [session.unsaved_words(), dir], _load)
		return
	_load()


func _load() -> void:
	show_catalog(StoryCatalog.load_dir(dir))


## Draws the catalog: the graph rebuilt, the filters kept, the selected event selected again (the
## side panel cleared when it is gone). A catalog that is not the session's starts a new session (a
## load: the drafts and the drag's state dropped, the load's warnings listed); the session's own
## (after an edit) keeps the scroll.
func show_catalog(story: StoryCatalog) -> void:
	var fresh := session == null or session.edit.catalog != story
	if fresh:
		var keep := selected
		session = StorySession.new(story)
		session.reach = StorySession.PUT_BACK_REACH * EventNode.editor_scale()
		session.selected = keep if session.model.event(keep) != null else ""
		_shown = ""
		_show_notice("")
	_redraw_graph(not fresh)


## True while the story can be edited: it loaded clean.
func can_edit() -> bool:
	return session != null and session.can_edit()


## Dims every node the toolbar's filters and search leave out; returns how many pass.
func apply_filters() -> int:
	var pool: String = _character.get_item_metadata(_character.selected) if _character.selected >= 0 else ""
	var act: int = _act.get_item_metadata(_act.selected) if _act.selected >= 0 else StoryGraph.ANY_ACT
	var shown := 0
	for id: String in nodes:
		var passes := model.shows(id, pool, act, _search.text)
		(nodes[id] as EventNode).set_dim(FILTER, not passes)
		shown += 1 if passes else 0
	var unsaved := session.dirty_pools()
	var status := "%d events, %d shown, %d errors" % [nodes.size(), shown, catalog.errors.size()]
	if not session.warnings.is_empty():
		status += ", %d warnings" % session.warnings.size()
	if not unsaved.is_empty():
		status += "; unsaved: " + ", ".join(StorySession.files(unsaved))
	_status.text = status
	return shown


## Selects the event's node, scrolls to it, and shows it in the side panel.
func select_event(id: String) -> void:
	if not nodes.has(id):
		return
	var node: GraphNode = nodes[id]
	graph.set_selected(node)
	graph.scroll_offset = (node.position_offset + node.size / 2) * graph.zoom - graph.size / 2
	show_event(id)


## The side panel: the event's facts, its header in the controls, its text and its when field
## (their drafts when they have some); "" clears it.
func show_event(id: String) -> void:
	var event := model.event(id) if model != null else null
	if event == null:
		id = ""
	if id != _shown:
		_clear_event_errors()
	if session != null:
		session.selected = id
	_shown = id
	if event == null:
		_title.text = "No event selected"
		_facts.text = ""
		_set_text("")
		_header.visible = false
		_update_editing()
		return
	_title.text = event.id
	var facts: PackedStringArray = []
	if not model.is_parsed(id):
		facts.append("Not parsed: its header is unknown until its errors are fixed.")
	if not model.is_loaded(id):
		facts.append("Not loaded: the game does not play it until its errors are fixed.")
	if not catalog.errors.is_empty():
		facts.append("The story has errors: fix the files and Reload to edit.")
	for message: String in model.errors_of.get(id, []):
		facts.append(message)
	_facts.text = "\n".join(facts)
	_header.visible = model.is_parsed(id)
	_fill_header(event)
	_set_text(session.panel_text(id))
	_update_editing()


## True when the shown event's text has changes not applied.
func has_draft() -> bool:
	return session != null and _shown != "" and session.has_draft(_shown)


# --- the edits: each a session gesture, its Outcome rendered ----------------------------------------

## The link of `kind` from one event to another made (add) or removed.
func link(kind: String, from_id: String, to_id: String, add: bool) -> Array[String]:
	return _render(session.link(kind, from_id, to_id, add))


## A new event in the pool, selected and scrolled to.
func add_event(pool: String, name: String) -> Array[String]:
	return _render(session.add_event(pool, name))


## The event renamed; its draft and the selection follow.
func rename_event(id: String, new_name: String) -> Array[String]:
	return _render(session.rename(id, new_name))


func delete_event(id: String) -> Array[String]:
	return delete_events([id] as Array[String])


## The events deleted as one gesture, all or nothing.
func delete_events(ids: Array[String]) -> Array[String]:
	return _render(session.delete(ids))


## A header field of the shown event set from a control; a refusal is listed in the panel and the
## controls show the event as it is (the when field keeps what was typed).
func set_field(key: String, value: String) -> Array[String]:
	if _shown == "" or not _is_highlighted(_shown):
		return []
	if key == "when":
		session.note_when(_shown, value)
	var outcome := session.set_field(key, value)
	var errors := _render(outcome)
	if not outcome.made:
		_fill_header(model.event(_shown))
	return errors


## The side panel's text replaces the shown event: made, the graph is drawn again (a new name in
## the text renames it, the selection following); refused, the event is kept, the text stays, and
## the errors are listed under it with their lines marked.
func apply_text() -> Array[String]:
	if _shown == "" or not _is_highlighted(_shown) or not can_edit():
		return []
	session.note_text(_shown, _text.text)
	return _render(session.apply())


## The shown event's text back to the event: its draft dropped.
func revert_text() -> void:
	if _shown == "":
		return
	session.revert(_shown)
	_clear_event_errors()
	_set_text(session.panel_text(_shown))
	_update_editing()


## Writes the pools with unsaved edits; a refusal is said plainly (the notice and a dialog).
func save() -> Array[String]:
	return _render(session.save(dir)) if session != null else ([] as Array[String])


## True while a pool has unsaved edits or an event has text not applied.
func has_unsaved() -> bool:
	return session != null and session.has_unsaved()


## What the editor's quit prompt lists ("" for nothing).
func unsaved_status() -> String:
	return session.unsaved_status() if session != null else ""


## The editor's save (the plugin's _save_external_data): the pools with unsaved edits written, the
## drafts left for the writer to Apply (named in the notice); a refusal goes to the notice and the
## error list, never a dialog.
func save_external() -> void:
	if session != null and session.has_unsaved():
		_render(session.save_external(dir))


# --- rendering ----------------------------------------------------------------------------------

## A gesture's Outcome on screen; returns its errors.
func _render(outcome: StorySession.Outcome) -> Array[String]:
	if outcome.redraw:
		_redraw_graph(true)
	if outcome.select != "":
		select_event(outcome.select)
	if not outcome.keep_notice:
		_show_notice(outcome.notice, _notice_color(outcome.notice_kind))
	if not outcome.panel_errors.is_empty():
		_show_event_errors(outcome.panel_errors)
	elif outcome.made:
		_clear_event_errors()
	if outcome.alert:
		_alert.dialog_text = outcome.notice
		_alert.popup_centered()
	return outcome.errors


static func _notice_color(kind: String) -> Color:
	match kind:
		StorySession.Outcome.INFO:
			return SAVED_COLOR
		StorySession.Outcome.WARN:
			return WARNING_COLOR
	return EventNode.ERROR_COLOR


## The graph drawn again from the session's model; the selection kept, and the scroll when asked.
func _redraw_graph(keep_scroll: bool) -> void:
	built = true
	_building = true
	var keep := selected
	var scroll := graph.scroll_offset
	_clear()
	_fill_characters()
	_draw_graph()
	_list_errors()
	apply_filters()
	if nodes.has(keep):
		graph.set_selected(nodes[keep])
	_building = false
	if keep_scroll:
		graph.scroll_offset = scroll
		# GraphEdit sizes its scroll range after the rebuild's frame: set it again then
		graph.set_deferred("scroll_offset", scroll)
	show_event(keep if nodes.has(keep) else "")


func _show_notice(text: String, color := EventNode.ERROR_COLOR) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)
	_notice.visible = text != ""


func _set_text(text: String) -> void:
	if _text.text != text:
		_text.text = text
		_text.clear_undo_history()
	_clear_line_marks()


## What the panel lets the writer do now: the text editable for a loaded event of a clean story,
## the header controls while the text is the event's, Apply and Revert while it is not; the when
## field tinted while it holds text not set.
func _update_editing() -> void:
	var editable := _shown != "" and can_edit() and model.is_loaded(_shown)
	var draft := has_draft()
	_text.editable = editable
	for control: Control in [_priority, _repeat, _trigger, _room, _event_act, _when, _when_set]:
		if control is BaseButton:
			(control as BaseButton).disabled = not editable or draft
		elif control is LineEdit:
			(control as LineEdit).editable = editable and not draft
	_header.tooltip_text = StorySession.DRAFT_FIRST if draft else ""
	_apply.disabled = not editable or not draft
	_revert.disabled = not draft
	if session != null and session.has_when_draft(_shown):
		_when.add_theme_color_override("font_color", WARNING_COLOR)
	else:
		_when.remove_theme_color_override("font_color")


## The panel's text changed (typed, or set): the session keeps it as the event's draft, and the
## last Apply's errors go with their line marks (the lines they named may have moved).
func _on_text_changed() -> void:
	if session != null and _shown != "":
		session.note_text(_shown, _text.text)
	_clear_event_errors()
	_update_editing()


func _on_when_changed(text: String) -> void:
	if session != null and _shown != "":
		session.note_when(_shown, text)
	_update_editing()


func _show_event_errors(errors: Array[String]) -> void:
	_event_errors.clear()
	_clear_line_marks()
	for message in errors:
		var index := _event_errors.add_item(message)
		_event_errors.set_item_custom_fg_color(index, EventNode.ERROR_COLOR)
		var line := StoryEdit.text_line(message)
		_event_errors.set_item_metadata(index, line)
		if line >= 1 and line <= _text.get_line_count():
			_text.set_line_background_color(line - 1, ERROR_LINE_COLOR)
	_event_errors.visible = not errors.is_empty()


## The panel's errors and their line marks, cleared together.
func _clear_event_errors() -> void:
	_event_errors.clear()
	_event_errors.visible = false
	_clear_line_marks()


func _clear_line_marks() -> void:
	for line in _text.get_line_count():
		_text.set_line_background_color(line, Color(0, 0, 0, 0))


## The line marks of the panel's errors (a test reads them).
func marked_lines() -> Array[int]:
	var marked: Array[int] = []
	for line in _text.get_line_count():
		if _text.get_line_background_color(line).a > 0:
			marked.append(line + 1)
	return marked


func _on_event_error_clicked(index: int, _at: Vector2, button: int) -> void:
	var line: int = _event_errors.get_item_metadata(index)
	if button == MOUSE_BUTTON_LEFT and line >= 1:
		_text.set_caret_line(line - 1)
		_text.grab_focus()


func _is_highlighted(id: String) -> bool:
	return nodes.has(id) and (nodes[id] as GraphNode).selected


## The selected nodes' events.
func _highlighted() -> Array[String]:
	var ids: Array[String] = []
	for id: String in nodes:
		if _is_highlighted(id):
			ids.append(id)
	return ids


# --- the header controls ------------------------------------------------------------------------

func _fill_header_items() -> void:
	for priority in StoryScript.PRIORITIES:
		_priority.add_item(priority)
	for word in REPEAT_WORDS:
		_repeat.add_item(word)
	for trigger in StoryScript.TRIGGERS:
		_trigger.add_item(trigger)
	for room in StoryScript.ROOMS:
		_room.add_item(room)
	_event_act.add_item("no act")
	for act in range(1, StoryScript.ACT_MAX + 1):
		_event_act.add_item("act %d" % act)


func _fill_header(event: StoryEvent) -> void:
	if event == null:
		return
	_priority.select(StoryScript.PRIORITIES.find(StoryEdit.header_value(event, "priority")))
	_repeat.select(REPEAT_WORDS.find(StoryEdit.header_value(event, "repeat")))
	_trigger.select(StoryScript.TRIGGERS.find(event.trigger))
	_room.visible = event.trigger == "enter"
	if event.trigger == "enter":
		_room.select(StoryScript.ROOMS.find(event.trigger_arg))
	_event_act.select(event.act)
	_when.text = session.when_text(event.id)
	_update_editing()


## The trigger control's value as set_header takes it: an enter names the room control's room.
func _trigger_value() -> String:
	var trigger := StoryScript.TRIGGERS[maxi(_trigger.selected, 0)]
	if trigger == "enter":
		return "enter " + StoryScript.ROOMS[maxi(_room.selected, 0)]
	return trigger


# --- the graph's signals, to the session ------------------------------------------------------------

func _on_connection_drag_started(from_node: StringName, from_port: int, is_output: bool) -> void:
	if session != null:
		session.drag_started(_id_of(from_node), _kind(from_port), is_output)


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	if session != null:
		session.connection_requested(_kind(from_port), _id_of(from_node), _id_of(to_node))


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	if session != null:
		session.disconnection_requested(_kind(from_port), _id_of(from_node), _id_of(to_node), _pointer())


## The drag over: the session decides the gesture, deferred, so the graph is drawn again after
## GraphEdit has finished with the drag (the pointer read now).
func _on_connection_drag_ended() -> void:
	_end_drag.call_deferred(_pointer())


func _end_drag(at: Vector2) -> void:
	if session != null:
		_render(session.drag_ended(at))


func _pointer() -> Vector2:
	return pointer.call() if pointer.is_valid() else _last_pointer


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse != null and graph != null and built:
		_last_pointer = graph.get_global_transform_with_canvas().affine_inverse() * mouse.position


## The Delete key on the selected events: asks, then deletes them as one gesture.
func _on_delete_nodes_request(names: Array[StringName]) -> void:
	var ids: Array[String] = []
	for node_name in names:
		var id := _id_of(node_name)
		if id != "":
			ids.append(id)
	if ids.is_empty() or not can_edit():
		return
	_ask("Delete %s? Each event's comment block goes with it; nothing is written until Save." % ", ".join(ids), func() -> void: delete_events(ids))


## A right-click near an edge offers its removal (a flag link says why it cannot be removed).
func _on_popup_request(at: Vector2) -> void:
	var near := graph.get_closest_connection_at_point(at, EDGE_REACH * EventNode.editor_scale())
	if near.is_empty():
		return
	_edge = {"kind": _kind(near["from_port"]), "from": _id_of(near["from_node"]), "to": _id_of(near["to_node"])}
	_edge_menu.clear()
	if _edge["kind"] == StoryLinks.FLAG:
		_edge_menu.add_item("A flag link: change the set: or the when: to change it")
		_edge_menu.set_item_disabled(0, true)
	else:
		_edge_menu.add_item("Remove: %s %s %s" % [_edge["to"], _edge["kind"], _edge["from"]])
		_edge_menu.set_item_disabled(0, not can_edit())
	_edge_menu.popup(Rect2i(Vector2i(graph.get_screen_transform() * at), Vector2i.ZERO))


func _on_edge_menu(_index: int) -> void:
	if not _edge.is_empty():
		link(_edge["kind"], _edge["from"], _edge["to"], false)


func _kind(port: int) -> String:
	return StoryLinks.KINDS[port] if port >= 0 and port < StoryLinks.KINDS.size() else ""


## The event id of a node by its name in the graph ("" for none).
func _id_of(node_name: StringName) -> String:
	var node := graph.get_node_or_null(NodePath(node_name))
	return (node as EventNode).id if node is EventNode else ""


func _on_rename_requested(id: String) -> void:
	var event: StoryEvent = catalog.by_id.get(id) if session != null else null
	if event == null or not can_edit():
		return
	_ask_name("Rename %s" % id, event.name, func(new_name: String) -> void: rename_event(id, new_name))


func _on_delete_requested(id: String) -> void:
	if not can_edit():
		return
	_ask("Delete %s? Its comment block goes with it; nothing is written until Save." % id, func() -> void: delete_event(id))


func _on_add_requested(pool: String) -> void:
	if not can_edit():
		return
	_ask_name("New event in %s" % pool, edit.unused_name(pool), func(name: String) -> void: add_event(pool, name))


# --- dialogs ------------------------------------------------------------------------------------

func _make_dialogs() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Story"
	_confirm.confirmed.connect(func() -> void:
		var action := _confirm_action
		_confirm_action = Callable()
		if action.is_valid():
			action.call()
	)
	add_child(_confirm)
	_name_dialog = ConfirmationDialog.new()
	_name_field = LineEdit.new()
	_name_field.custom_minimum_size.x = 240 * EventNode.editor_scale()
	_name_dialog.add_child(_name_field)
	_name_dialog.register_text_enter(_name_field)
	_name_dialog.confirmed.connect(func() -> void:
		var action := _name_action
		_name_action = Callable()
		if action.is_valid():
			action.call(_name_field.text.strip_edges())
	)
	add_child(_name_dialog)
	_alert = AcceptDialog.new()
	_alert.title = "Story: not saved"
	add_child(_alert)
	_edge_menu = PopupMenu.new()
	_edge_menu.index_pressed.connect(_on_edge_menu)
	add_child(_edge_menu)


func _ask(text: String, action: Callable) -> void:
	_confirm.dialog_text = text
	_confirm_action = action
	_confirm.popup_centered()


func _ask_name(title: String, initial: String, action: Callable) -> void:
	_name_dialog.title = title
	_name_field.text = initial
	_name_action = action
	_name_dialog.popup_centered()
	_name_field.select_all()
	_name_field.grab_focus()


# --- drawing ------------------------------------------------------------------------------------

func _clear() -> void:
	graph.clear_connections()
	# freed in place, not removed: GraphEdit's deferred reordering of a just-added element (frames
	# behind nodes) would find a removed one not its child. Renamed so the new nodes take the names.
	for child in graph.get_children():
		if child is GraphElement and not child.is_queued_for_deletion():
			child.name = "Old%d" % child.get_instance_id()
			child.queue_free()
	nodes.clear()
	lanes.clear()


func _draw_graph() -> void:
	var factor := EventNode.editor_scale()
	var depths := StoryLayout.depths(model.events)
	var rows := StoryLayout.lanes(model.events, model.pools, depths)
	var cells := StoryLayout.positions(model.events, model.pools, depths)
	var columns := 1
	for at: Vector2i in cells.values():
		columns = maxi(columns, at.x + 1)
	var editable := can_edit()
	for i in model.pools.size():  # the frames first: they draw under the nodes
		var pool := model.pools[i]
		var frame := GraphFrame.new()
		frame.name = "Lane%d" % i
		frame.autoshrink_enabled = false
		frame.draggable = false
		frame.selectable = false
		frame.tint_color_enabled = true
		frame.tint_color = LANE_TINTS[i % LANE_TINTS.size()]
		var add := Button.new()
		add.text = "+ Event"
		add.tooltip_text = "Add an event to %s's pool" % pool
		add.disabled = not editable
		add.pressed.connect(_on_add_requested.bind(pool))
		frame.get_titlebar_hbox().add_child(add)
		graph.add_child(frame)
		lanes[pool] = frame
	_mark_unsaved()
	for index in model.events.size():
		var event := model.events[index]
		if not cells.has(event.id):
			continue
		var node := EventNode.new()
		node.name = "Event%d" % index
		graph.add_child(node)
		node.show_event(event, model.badges(event.id))
		node.set_editable(editable)
		node.custom_minimum_size = node.custom_minimum_size.max(node_floor)
		node.rename_requested.connect(_on_rename_requested)
		node.delete_requested.connect(_on_delete_requested)
		nodes[event.id] = node
	_place(rows, cells, columns, factor)
	for edge: Dictionary in StoryLinks.edges(model.events):
		if nodes.has(edge["from"]) and nodes.has(edge["to"]):
			var port := EventNode.port(edge["kind"])
			graph.connect_node((nodes[edge["from"]] as Node).name, port, (nodes[edge["to"]] as Node).name, port)


## Each lane's title, marked while its pool has unsaved edits; Save enabled while one has.
func _mark_unsaved() -> void:
	var dirty := session.dirty_pools()
	for pool: String in lanes:
		(lanes[pool] as GraphFrame).title = _lane_title(pool) + (UNSAVED_MARK if dirty.has(pool) else "")
	_save.disabled = dirty.is_empty()
	_save.tooltip_text = "Write %s to %s." % [", ".join(StorySession.files(dirty)), dir] if not dirty.is_empty() else "Nothing to save."


## Places the nodes and the frames from measured sizes: a cell is the widest and the tallest node
## plus the gaps; a lane's title room is the tallest frame title bar plus a margin either side.
func _place(rows: Dictionary, cells: Dictionary, columns: int, factor: float) -> void:
	var gap := Vector2(COLUMN_GAP, ROW_GAP) * factor
	var margin := LANE_MARGIN * factor
	var biggest := Vector2.ZERO
	for node: GraphNode in nodes.values():
		biggest = biggest.max(node.get_combined_minimum_size())
	cell = biggest + gap
	var title_room := 0.0
	for frame: GraphFrame in lanes.values():
		var bar := frame.get_theme_stylebox("titlebar")
		var bar_height := frame.get_titlebar_hbox().get_combined_minimum_size().y + (bar.get_minimum_size().y if bar != null else 0.0)
		title_room = maxf(title_room, bar_height)
	var lane_gap := title_room + 2 * margin
	for i in model.pools.size():
		var lane: Vector2i = rows[model.pools[i]]
		var frame: GraphFrame = lanes[model.pools[i]]
		var top := _lane_top(i, lane, lane_gap)
		frame.position_offset = Vector2(-margin, top - lane_gap + margin)
		frame.size = Vector2(columns * cell.x - gap.x + 2 * margin, lane.y * cell.y - gap.y + lane_gap)
	for id: String in nodes:
		var event := model.event(id)
		var lane_index := model.pools.find(event.pool)
		var lane: Vector2i = rows[event.pool]
		var at: Vector2i = cells[id]
		(nodes[id] as GraphNode).position_offset = Vector2(at.x * cell.x, _lane_top(lane_index, lane, lane_gap) + (at.y - lane.x) * cell.y)


## The lane's top in pixels: its first row, below every lane's title room above it and its own.
func _lane_top(index: int, lane: Vector2i, lane_gap: float) -> float:
	return lane.x * cell.y + (index + 1) * lane_gap


func _lane_title(pool: String) -> String:
	var entry: Variant = catalog.cast.get(pool, {})
	var name := str(entry.get("name", "")) if entry is Dictionary else ""
	name = StoryScript.strip_marker(name)
	return pool if name == "" or name.to_lower() == pool else "%s (%s)" % [pool, name]


func _fill_characters() -> void:
	var kept: String = _character.get_item_metadata(_character.selected) if _character.selected >= 0 else ""
	_character.clear()
	_character.add_item("All characters")
	_character.set_item_metadata(0, "")
	for pool in model.pools:
		_character.add_item(pool)
		_character.set_item_metadata(_character.item_count - 1, pool)
		if pool == kept:
			_character.select(_character.item_count - 1)
	if _character.selected < 0:
		_character.select(0)


## The catalog's errors (red), the load's warnings (yellow), and the last save's errors (red, on
## no event); each selects its event.
func _list_errors() -> void:
	_errors.clear()
	for entry: Dictionary in model.errors:
		var index := _errors.add_item(entry["message"])
		_errors.set_item_metadata(index, entry["target"])
		_errors.set_item_custom_fg_color(index, EventNode.ERROR_COLOR)
	for warning in session.warnings:
		var index := _errors.add_item("warning: " + str(warning["message"]))
		_errors.set_item_metadata(index, warning["target"])
		_errors.set_item_custom_fg_color(index, WARNING_COLOR)
	for error in session.save_errors:
		var index := _errors.add_item(error)
		_errors.set_item_metadata(index, "")
		_errors.set_item_custom_fg_color(index, EventNode.ERROR_COLOR)
	_errors.visible = _errors.item_count > 0


func _build_legend(factor: float) -> void:
	for kind: String in StoryLinks.KINDS:
		_legend.add_child(_swatch(EventNode.PORT_COLORS[kind], factor))
		_legend.add_child(_legend_label(kind))
	_legend.add_child(VSeparator.new())
	for priority: String in StoryScript.PRIORITIES:
		_legend.add_child(_swatch(EventNode.PRIORITY_COLORS[priority], factor))
		_legend.add_child(_legend_label(priority))


static func _swatch(color: Color, factor: float) -> ColorRect:
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(SWATCH, SWATCH) * factor
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return swatch


static func _legend_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_filter() -> void:
	apply_filters()


func _on_node_selected(node: Node) -> void:
	if node is EventNode and not _building:
		show_event((node as EventNode).id)


## A node deselected: the side panel stays on a selected node (StorySession.next_shown: the first
## still selected when the one it showed is not; a click elsewhere deselects first, then selects).
func _on_node_deselected(_node: Node) -> void:
	if _building or session == null:
		return
	var next := session.next_shown(_highlighted())
	if next != _shown:
		show_event(next)


## A click on an error, the selected one too (item_clicked fires on every click; item_selected,
## only on a change, is not connected, so a click selects once).
func _on_error_clicked(index: int, _at: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	var id: String = _errors.get_item_metadata(index)
	if id != "":
		select_event(id)
