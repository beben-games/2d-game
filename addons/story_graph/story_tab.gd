@tool
extends VBoxContainer
## The Story tab: the story in `dir` (data/story) as a graph, and its editing. A lane per character
## (a frame, the cast's order), a node per event placed by StoryLayout (columns by depth in the
## chain of requires), the three kinds of edge from StoryLinks told apart by colour (the legend),
## every event the files hold even when the catalog left it out (StoryGraph: its errors as its
## badge). The toolbar reloads from disk, saves, filters by character and act, and searches ids and
## text (a node that does not match dims); the catalog's errors and the load's warnings list under
## it (a click selects the event); the side panel edits the selected event.
##
## Editing (Task 13). Every edit is a StoryEdit call on `edit`, so a refused one shows StoryEdit's
## reason (the catalog's) and changes nothing; a made one draws the graph again from
## `edit.catalog` (the selection and the scroll kept; hand-dragged node positions are laid out
## again). The gestures:
## - a drag from a node's row to another node's same row adds that kind of link (the requires row
##   a requires, the unless row an unless; StoryEdit.add_link): the drag's from is the
##   prerequisite (or the excluding event), its to the event that gains it, as the edges are drawn;
##   a flag link is derived and refused with why. Dragging an edge's right end off its port removes
##   it when the drag ends (StoryEdit.remove_link; dropped back, nothing changes), as does a
##   right-click on it.
## - a lane's "+ Event" adds an event (add_event); a node's menu (its title bar, or a right-click)
##   renames (rename: every requires and unless follows) or deletes it (delete_event); the Delete
##   key deletes the selected events, after asking.
## - the side panel: the header as controls (set_header: priority, once or repeat, the trigger and
##   its room, the act, the when field), the event as text in the file's own format in a CodeEdit
##   (Apply: replace_event, its errors listed under it and their lines marked). Text not applied is
##   a draft, kept per event across selections and rebuilds; the header controls wait while the
##   shown event has one (Apply or Revert first), so one edit never overwrites the other.
## - Save writes the pools with unsaved edits (StoryEdit.save); their lanes say "unsaved" until
##   then. Reload with unsaved edits or drafts asks first; the plugin asks on quit
##   (unsaved_status) and saves on the editor's save (save_external).
## The story's errors stop every edit (StoryEdit's rule: a pool written from a catalog with errors
## would lose the events that did not load): the text is read only until the files are fixed.
##
## Thin by design: what can be pure is in scripts/story (StoryEdit, StoryGraph, StoryLayout,
## StoryLinks) and tested there; this draws and routes. The pixel layout is measured, so it holds
## at any editor scale; every other pixel size is multiplied by the editor's scale. Built on the
## first showing (ensure_built: the plugin's _make_visible), never at editor start.
##
## Room for the next tasks: What-if (Task 14) is another tab of the side panel and dims by its own
## reason (EventNode.set_dim); the lint's badges (Task 15) are more keys of StoryGraph.badges.

const EventNode := preload("res://addons/story_graph/event_node.gd")
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
const DRAFT_FIRST := "the event's text has changes not applied: Apply or Revert them first"
const CHANGED_ON_DISK := "changed on disk since load"

## The story's directory.
var dir := StoryCatalog.DATA_DIR
## The catalog drawn (edit.catalog once editing).
var catalog: StoryCatalog = null
## The edits since the last load: every change goes through it (null before the first draw).
var edit: StoryEdit = null
var model: StoryGraph = null
## Event id -> its EventNode.
var nodes: Dictionary = {}
## Pool -> its lane's GraphFrame.
var lanes: Dictionary = {}
## The id shown in the side panel ("" for none): always a selected node's, or none.
var selected := ""
## Event id -> its side panel text not yet applied.
var drafts: Dictionary = {}
## A floor under every node's minimum size (none at Vector2.ZERO): a test's way to make the nodes
## big, as a larger editor scale or font does.
var node_floor := Vector2.ZERO
## StoryLayout's grid cell in pixels, as last measured.
var cell := Vector2.ZERO
var built := false
var _building := false
## The load's warnings (an inline comment a rewrite drops), each {"message", "target", "pool"}:
## listed from the load, before any edit, until their pool is saved.
var _warnings: Array[Dictionary] = []
var _confirm: ConfirmationDialog = null
var _confirm_action := Callable()
var _name_dialog: ConfirmationDialog = null
var _name_field: LineEdit = null
var _name_action := Callable()
var _alert: AcceptDialog = null
var _edge_menu: PopupMenu = null
## The edge the edge menu is about: {"kind", "from", "to"}.
var _edge: Dictionary = {}
## The edge a drag picked up by its right end, {"kind", "from", "to"} ({} for none).
var _picked: Dictionary = {}

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
		_ask("Discard %s and read the story again from %s?" % [_unsaved_words(), dir], _load)
		return
	_load()


func _load() -> void:
	show_catalog(StoryCatalog.load_dir(dir))


## Draws the catalog: the graph rebuilt, the filters kept, the selected event selected again (the
## side panel cleared when it is gone). A catalog that is not the edit's own starts a new edit of
## it (a load: the drafts dropped, its warnings listed); the edit's own (after an edit) keeps the
## scroll.
func show_catalog(story: StoryCatalog) -> void:
	var fresh := edit == null or edit.catalog != story
	if fresh:
		edit = StoryEdit.new(story)
		drafts.clear()
		_show_notice("")
	built = true
	_building = true
	var keep := selected
	var scroll := graph.scroll_offset
	catalog = story
	model = StoryGraph.of(story)
	if fresh:
		_warnings.clear()
		for message in story.warnings:
			_warnings.append({"message": message, "target": model.target_of(message), "pool": message.get_slice(".txt:", 0)})
	_clear()
	_fill_characters()
	_draw_graph()
	_list_errors()
	apply_filters()
	if nodes.has(keep):
		graph.set_selected(nodes[keep])
	_building = false
	if not fresh:
		_keep_scroll(scroll)
	show_event(keep if nodes.has(keep) else "")


## True while the story can be edited: it loaded clean (StoryEdit refuses every edit otherwise).
func can_edit() -> bool:
	return edit != null and catalog == edit.catalog and catalog.errors.is_empty()


## Dims every node the toolbar's filters and search leave out; returns how many pass.
func apply_filters() -> int:
	var pool: String = _character.get_item_metadata(_character.selected) if _character.selected >= 0 else ""
	var act: int = _act.get_item_metadata(_act.selected) if _act.selected >= 0 else StoryGraph.ANY_ACT
	var shown := 0
	for id: String in nodes:
		var passes := model.shows(id, pool, act, _search.text)
		(nodes[id] as EventNode).set_dim(FILTER, not passes)
		shown += 1 if passes else 0
	var unsaved := edit.dirty_pools() if edit != null else ([] as Array[String])
	var status := "%d events, %d shown, %d errors" % [nodes.size(), shown, catalog.errors.size()]
	if not _warnings.is_empty():
		status += ", %d warnings" % _warnings.size()
	if not unsaved.is_empty():
		status += "; unsaved: " + ", ".join(_files(unsaved))
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


## The side panel: the event's facts, its header in the controls, and its text (its draft when it
## has one); "" clears it. Leaving an event keeps its text not applied as its draft.
func show_event(id: String) -> void:
	if id != selected:
		_stash_draft()
		_clear_event_errors()
	selected = id
	var event := model.event(id) if model != null else null
	if event == null:
		selected = ""
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
	_set_text(drafts.get(id, model.text(id)))
	_update_editing()


## True when the shown event's text differs from the event (a draft).
func text_changed() -> bool:
	return selected != "" and model != null and _text.text != model.text(selected)


# --- the edits --------------------------------------------------------------------------------

## The link of `kind` from one event to another made (add) or removed: the graph's drag.
func link(kind: String, from_id: String, to_id: String, add: bool) -> Array[String]:
	if edit == null:
		return []
	return _edited(edit.add_link(kind, from_id, to_id) if add else edit.remove_link(kind, from_id, to_id))


## A new event in the pool, selected and scrolled to.
func add_event(pool: String, name: String) -> Array[String]:
	var errors := edit.add_event(pool, name)
	if errors.is_empty():
		var id := StoryEvent.id_for(pool, name)
		_stash_draft()
		_edited(errors)
		select_event(id)
		return errors
	return _edited(errors)


## The event renamed (every requires and unless follows); its draft and the selection follow.
func rename_event(id: String, new_name: String) -> Array[String]:
	var event: StoryEvent = edit.catalog.by_id.get(id)
	_stash_draft()
	var errors := edit.rename(id, new_name)
	if errors.is_empty() and event != null:
		var new_id := StoryEvent.id_for(event.pool, new_name)
		if drafts.has(id):
			drafts[new_id] = drafts[id]
			drafts.erase(id)
		if selected == id:
			selected = new_id
	return _edited(errors)


## The event deleted (refused while another names it), its draft with it.
func delete_event(id: String) -> Array[String]:
	var errors := edit.delete_event(id)
	if errors.is_empty():
		drafts.erase(id)
	return _edited(errors)


## A header field of the shown event set from a control (StoryEdit.set_header); refused while the
## event's text has changes not applied. A refusal is listed in the panel and the controls show the
## event as it is.
func set_field(key: String, value: String) -> Array[String]:
	if selected == "" or not _is_highlighted(selected):
		return []
	var errors: Array[String] = []
	if text_changed():
		errors.append(DRAFT_FIRST)
	else:
		errors = edit.set_header(selected, key, value)
	if errors.is_empty():
		_clear_event_errors()
		_edited(errors)
	else:
		_show_event_errors(errors)
		_fill_header(model.event(selected))
		if key == "when":
			_when.text = value  # kept to be fixed, not retyped
	return errors


## The side panel's text replaces the shown event (StoryEdit.replace_event): made, the graph is
## drawn again (a new name in the text renames it, the selection following); refused, the event
## is kept, the text stays, and the errors are listed under it with their lines marked.
func apply_text() -> Array[String]:
	if selected == "" or not _is_highlighted(selected) or not can_edit():
		return []
	var text := _text.text
	var pool := model.event(selected).pool
	var errors := edit.replace_event(selected, text)
	if not errors.is_empty():
		_show_event_errors(errors)
		return errors
	var applied: StoryEvent = StoryScript.parse(text, pool)["events"][0]
	drafts.erase(selected)
	_clear_event_errors()
	selected = applied.id
	_edited(errors)
	return errors


## The shown event's text back to the event: its draft dropped.
func revert_text() -> void:
	if selected == "":
		return
	drafts.erase(selected)
	_clear_event_errors()
	_set_text(model.text(selected))
	_update_editing()


## Writes the pools with unsaved edits (StoryEdit.save). A pool not written stays unsaved, and why
## is said plainly (the notice and a dialog). Returns the errors.
func save() -> Array[String]:
	if edit == null:
		return []
	var before := edit.dirty_pools()
	var errors := edit.save(dir)
	var after := edit.dirty_pools()
	var saved: Array[String] = []
	for pool in before:
		if not after.has(pool):
			saved.append(pool)
	_warnings = _warnings.filter(func(warning: Dictionary) -> bool: return not saved.has(warning["pool"]))
	_list_errors()
	_mark_unsaved()
	apply_filters()
	if errors.is_empty():
		if not saved.is_empty():
			_show_notice("Saved " + ", ".join(_files(saved)) + ".", SAVED_COLOR)
	else:
		var message := save_message(errors)
		_show_notice(message)
		_alert.dialog_text = message
		_alert.popup_centered()
	return errors


## What the writer reads when a save fails: the errors, and for a file changed on disk since the
## load, what happened and what to do.
static func save_message(errors: Array[String]) -> String:
	var message := "Not saved:\n" + "\n".join(errors)
	for error in errors:
		if error.contains(CHANGED_ON_DISK):
			message += "\n\nA file changed on disk after the tab read it (edited outside the tab, or by git). Saving would overwrite that change, so it was not saved. To keep both: copy your edited events' text aside, Reload (it drops the tab's unsaved edits), and make them again."
			break
	return message


## True while a pool has unsaved edits or an event has text not applied.
func has_unsaved() -> bool:
	_stash_draft()
	return edit != null and (not edit.dirty_pools().is_empty() or not drafts.is_empty())


## What the editor's quit prompt lists ("" for nothing): the unsaved pools and the drafts.
func unsaved_status() -> String:
	if not has_unsaved():
		return ""
	return "Story tab: %s." % _unsaved_words()


## The editor's save (the plugin's _save_external_data): the pools with unsaved edits written.
func save_external() -> void:
	if edit != null and not edit.dirty_pools().is_empty():
		save()


# --- after an edit ----------------------------------------------------------------------------

## An edit's result: made, the graph drawn again from the edit's catalog and the notice cleared;
## refused, the reason in the notice and nothing changed.
func _edited(errors: Array[String]) -> Array[String]:
	if errors.is_empty():
		_show_notice("")
		show_catalog(edit.catalog)
	else:
		_show_notice("Refused: " + "\n".join(errors))
	return errors


func _show_notice(text: String, color := EventNode.ERROR_COLOR) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)
	_notice.visible = text != ""


## The shown event's text not applied kept as its draft (none when it is the event's).
func _stash_draft() -> void:
	if selected == "" or model == null or model.event(selected) == null:
		return
	if _text.text != model.text(selected):
		drafts[selected] = _text.text
	else:
		drafts.erase(selected)


func _set_text(text: String) -> void:
	if _text.text != text:
		_text.text = text
		_text.clear_undo_history()
	_clear_line_marks()


## What the panel lets the writer do now: the text editable for a loaded event of a clean story,
## the header controls while the text is the event's, Apply and Revert while it is not.
func _update_editing() -> void:
	var editable := selected != "" and can_edit() and model.is_loaded(selected)
	var draft := text_changed()
	_text.editable = editable
	for control: Control in [_priority, _repeat, _trigger, _room, _event_act, _when, _when_set]:
		if control is BaseButton:
			(control as BaseButton).disabled = not editable or draft
		elif control is LineEdit:
			(control as LineEdit).editable = editable and not draft
	_header.tooltip_text = DRAFT_FIRST if draft else ""
	_apply.disabled = not editable or not draft
	_revert.disabled = not draft


func _on_text_changed() -> void:
	_clear_line_marks()
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


## The first selected node's event in the graph's order, "" for none.
func _first_selected() -> String:
	for event in model.events:
		if _is_highlighted(event.id):
			return event.id
	return ""


func _keep_scroll(offset: Vector2) -> void:
	graph.scroll_offset = offset
	# GraphEdit sizes its scroll range after the rebuild's frame: set it again then
	graph.set_deferred("scroll_offset", offset)


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
	_when.text = StoryEdit.header_value(event, "when")


## The trigger control's value as set_header takes it: an enter names the room control's room.
func _trigger_value() -> String:
	var trigger := StoryScript.TRIGGERS[maxi(_trigger.selected, 0)]
	if trigger == "enter":
		return "enter " + StoryScript.ROOMS[maxi(_room.selected, 0)]
	return trigger


# --- the graph's requests -----------------------------------------------------------------------

## A drag from one node's row to another's: the link of that row's kind. A picked-up edge dropped
## back on its own port changes nothing. Deferred, so the graph is drawn again after GraphEdit has
## finished with the drag.
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	var wanted := {"kind": _kind(from_port), "from": _id_of(from_node), "to": _id_of(to_node)}
	if wanted == _picked:
		_picked = {}
		return
	link.call_deferred(wanted["kind"], wanted["from"], wanted["to"], true)


## An edge's right end picked up (a press on its input port): held until the drag ends, since the
## drag may put it back (GraphEdit 4.7.2: disconnection_request, connection_drag_started, a
## connection_request if dropped on a port, then connection_drag_ended; it never removes the edge
## itself).
func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	_picked = {"kind": _kind(from_port), "from": _id_of(from_node), "to": _id_of(to_node)}


## The drag over: a picked-up edge not put back is removed (deferred, as a drag's link).
func _on_connection_drag_ended() -> void:
	if _picked.is_empty():
		return
	var picked := _picked
	_picked = {}
	link.call_deferred(picked["kind"], picked["from"], picked["to"], false)


## The Delete key on the selected events: asks, then deletes each.
func _on_delete_nodes_request(names: Array[StringName]) -> void:
	var ids: Array[String] = []
	for node_name in names:
		var id := _id_of(node_name)
		if id != "":
			ids.append(id)
	if ids.is_empty() or not can_edit():
		return
	_ask("Delete %s? Each event's comment block goes with it; nothing is written until Save." % ", ".join(ids), func() -> void:
		for id in ids:
			delete_event(id)
	)


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
	var event: StoryEvent = edit.catalog.by_id.get(id) if edit != null else null
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


## "unsaved edits to a.txt, b.txt and the text not applied of veteran.hello", as much as holds.
func _unsaved_words() -> String:
	var parts: PackedStringArray = []
	var dirty := edit.dirty_pools() if edit != null else ([] as Array[String])
	if not dirty.is_empty():
		parts.append("the unsaved edits to " + ", ".join(_files(dirty)))
	if not drafts.is_empty():
		parts.append("the text not applied of " + ", ".join(PackedStringArray(drafts.keys())))
	return " and ".join(parts)


static func _files(pools: Array[String]) -> PackedStringArray:
	var files: PackedStringArray = []
	for pool in pools:
		files.append(pool + ".txt")
	return files


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
	var dirty := edit.dirty_pools() if edit != null else ([] as Array[String])
	for pool: String in lanes:
		(lanes[pool] as GraphFrame).title = _lane_title(pool) + (UNSAVED_MARK if dirty.has(pool) else "")
	_save.disabled = dirty.is_empty()
	_save.tooltip_text = "Write %s to %s." % [", ".join(_files(dirty)), dir] if not dirty.is_empty() else "Nothing to save."


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


## The catalog's errors (red), then the load's warnings (yellow); each selects its event.
func _list_errors() -> void:
	_errors.clear()
	for entry: Dictionary in model.errors:
		var index := _errors.add_item(entry["message"])
		_errors.set_item_metadata(index, entry["target"])
		_errors.set_item_custom_fg_color(index, EventNode.ERROR_COLOR)
	for warning in _warnings:
		var index := _errors.add_item("warning: " + str(warning["message"]))
		_errors.set_item_metadata(index, warning["target"])
		_errors.set_item_custom_fg_color(index, WARNING_COLOR)
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


## A node deselected: the side panel stays on a selected node, the first still selected when the
## one it showed is not (a click elsewhere deselects first and then selects), none when none is.
func _on_node_deselected(_node: Node) -> void:
	if _building or _is_highlighted(selected):
		return
	show_event(_first_selected())


## A click on an error, the selected one too (item_clicked fires on every click; item_selected,
## only on a change, is not connected, so a click selects once).
func _on_error_clicked(index: int, _at: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	var id: String = _errors.get_item_metadata(index)
	if id != "":
		select_event(id)
