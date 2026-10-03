@tool
extends RefCounted
## The Story tab's editing, with no UI (docs/plans/2026-10-01-milestone-6.md, Task 13): one load
## of the story and what the writer has done to it since. It holds the StoryEdit every change goes
## through, the graph drawn from it (`model`, StoryGraph), the event the side panel shows
## (`selected`), the text not applied per event (`drafts`, and the `when` field's per event), the
## edge a drag has picked up, and the rules of each gesture. Every gesture returns an Outcome the
## tab renders (the notice, the panel's errors, whether to draw again, what to select); a gesture
## is one Outcome, so a refusal is never cleared by the rest of its own gesture. Pure of the UI and
## of the game: it names no autoload and no Node class (the tab and the tests drive it alike).
##
## Drafts. The tab hands every change of the panel's text to note_text, so a draft is always the
## text on screen, kept whatever is drawn again. A draft remembers the event text it was started
## from: when an edit changes that event under it (a link into it, a rename of an event it names),
## the draft stays, flagged until Apply or Revert, and the Outcome says so once; an Apply of a
## flagged draft says the event had changed. A rename moves a draft with its event, its `==` line
## renamed (StoryEdit.with_name), so an Apply does not rename the event back. Nothing but the
## writer's Apply applies a draft: the editor's save writes the pools and leaves the drafts.
##
## Presets. The act cheat's presets (acts.json, StoryCatalog.acts) are the load's: the tab never
## reads nor writes the file, and an edit's catalog has none. An edit that takes an event a preset
## names out of the story (a rename, a delete, an Apply renaming it through its text) is made, and
## its notice warns that acts.json must be changed by hand (it would be an error at the next load).

## Drags (GraphEdit 4.7.2, measured): a new drag is connection_drag_started, a connection_request
## when it ends on a port, then connection_drag_ended; an edge picked up by its right end is
## disconnection_request first, then the same. So the gesture is decided at the drag's end
## (drag_ended): a drop alone adds; a pick-up dropped back on its port, or released within `reach`
## of where it was picked up (a click on the port), changes nothing; a pick-up dropped elsewhere
## off a port is removed; a pick-up dropped on another port is a move, the new link added first
## and the old removed only when the add was made (refused, nothing changes). A drag_started that
## does not continue a pick-up forgets it.

## How far (at scale 1) a picked-up edge may be released from where it was picked up and still be
## a click, put back rather than removed.
const PUT_BACK_REACH := 4.0
const DRAFT_FIRST := "the event's text has changes not applied: Apply or Revert them first"
const CHANGED_ON_DISK := "changed on disk since load"

var edit: StoryEdit
## The graph of edit.catalog, drawn again after every edit made.
var model: StoryGraph
## The event the side panel shows ("" none); the tab keeps it a selected node's.
var selected := ""
## Event id -> {"text": the panel's text not applied, "base": the event's text it started from,
## "changed": the event changed under it since (cleared only by Apply or Revert)}.
var drafts: Dictionary = {}
## Event id -> the `when` field's text not set.
var when_drafts: Dictionary = {}
## The load's warnings, each {"message", "target", "pool"}, until their pool is saved.
var warnings: Array[Dictionary] = []
## The lint of the story as it is now (StoryLint.run on edit.catalog, with `lint_inputs`), run again
## with each graph (the load and every edit made); its warnings are on the model too (take_lint).
## Read only: the lint never edits, so it never dirties a pool.
var lint: Dictionary = {}
## What the lint reads beside the story: {"words": the word list, "game": StoryLint.run's game}
## (the tab gathers them through StoryLintInputs at each load); {} lints with neither.
var lint_inputs: Dictionary = {}
## The load's act presets (StoryCatalog.acts): act -> {"played", ...}; read only.
var acts: Dictionary = {}
## The last save's errors (the editor's save lists them rather than a dialog); [] after a save
## that wrote everything.
var save_errors: Array[String] = []
## PUT_BACK_REACH at the editor's scale, in the pointer's pixels.
var reach := PUT_BACK_REACH
## The edge the current drag picked up: {"kind", "from", "to"}, {} for none.
var _picked: Dictionary = {}
## Where the pick-up happened (the pointer, graph pixels).
var _picked_at := Vector2.ZERO
## The link the current drag ended on a port with: {"kind", "from", "to"}, {} for none.
var _drop: Dictionary = {}


func _init(story: StoryCatalog, inputs: Dictionary = {}) -> void:
	edit = StoryEdit.new(story)
	acts = story.acts
	lint_inputs = inputs
	_draw_model()
	for message in story.warnings:
		warnings.append({"message": message, "target": model.target_of(message), "pool": message.get_slice(".txt:", 0)})


## The lint's warnings the tab lists: every one but the catalog's own warnings (StoryLint.PARSE),
## which the tab lists from the load (`warnings`) until their pool is saved.
func lint_warnings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for warning: Dictionary in lint.get("warnings", []):
		if warning["kind"] != StoryLint.PARSE:
			out.append(warning)
	return out


## True while the story can be edited: it loaded clean (StoryEdit refuses every edit otherwise).
func can_edit() -> bool:
	return edit.catalog.errors.is_empty()


# --- the panel's text ---------------------------------------------------------------------------

## The text the panel shows for the event: its draft, else the event's.
func panel_text(id: String) -> String:
	return str((drafts[id] as Dictionary)["text"]) if drafts.has(id) else model.text(id)


func has_draft(id := selected) -> bool:
	return drafts.has(id)


## True while the event changed under its draft (since the text was opened).
func draft_changed(id := selected) -> bool:
	return drafts.has(id) and bool((drafts[id] as Dictionary)["changed"])


## The panel's text for the event, as it stands: a draft while it differs from the event.
func note_text(id: String, text: String) -> void:
	if model.event(id) == null:
		return
	var now := model.text(id)
	if text == now:
		drafts.erase(id)
	elif drafts.has(id):
		(drafts[id] as Dictionary)["text"] = text
	else:
		drafts[id] = {"text": text, "base": now, "changed": false}


## The draft dropped: the event's text again.
func revert(id := selected) -> void:
	drafts.erase(id)


## The `when` field's text for the event: its draft, else the event's.
func when_text(id: String) -> String:
	if when_drafts.has(id):
		return when_drafts[id]
	var event := model.event(id)
	return StoryEdit.header_value(event, "when") if event != null else ""


func has_when_draft(id := selected) -> bool:
	return when_drafts.has(id)


func note_when(id: String, text: String) -> void:
	var event := model.event(id)
	if event == null or text == StoryEdit.header_value(event, "when"):
		when_drafts.erase(id)
	else:
		when_drafts[id] = text


## The event the panel shows once the selection is `highlighted` (the graph's selected nodes):
## the shown one while it is selected, else the first selected in the graph's order, else none.
func next_shown(highlighted: Array[String]) -> String:
	if highlighted.has(selected):
		return selected
	for event in model.events:
		if highlighted.has(event.id):
			return event.id
	return ""


# --- drags --------------------------------------------------------------------------------------

## A drag starts: one that does not continue a pick-up forgets it (a stale pick-up never removes
## an edge later).
func drag_started(from_id: String, kind: String, is_output: bool) -> void:
	_drop = {}
	if _picked.is_empty():
		return
	if not (is_output and from_id == _picked["from"] and kind == _picked["kind"]):
		_picked = {}


## An edge's right end picked up at `pointer`.
func disconnection_requested(kind: String, from_id: String, to_id: String, pointer: Vector2) -> void:
	_picked = {"kind": kind, "from": from_id, "to": to_id}
	_picked_at = pointer
	_drop = {}


## The drag ends on a port: the link it would make.
func connection_requested(kind: String, from_id: String, to_id: String) -> void:
	_drop = {"kind": kind, "from": from_id, "to": to_id}


## The drag over, released at `pointer`: the gesture decided (see the top).
func drag_ended(pointer: Vector2) -> Outcome:
	var picked := _picked
	var drop := _drop
	_picked = {}
	_drop = {}
	if picked.is_empty() and drop.is_empty():
		return Outcome.unchanged()
	if picked.is_empty():
		return link(drop["kind"], drop["from"], drop["to"], true)
	if drop == picked:
		return Outcome.unchanged()
	if drop.is_empty():
		if pointer.distance_to(_picked_at) <= reach:
			return Outcome.unchanged()
		return link(picked["kind"], picked["from"], picked["to"], false)
	var before := edit.catalog
	var added := edit.add_link(drop["kind"], drop["from"], drop["to"])
	if not added.is_empty():
		return Outcome.refused(added)
	var removed := edit.remove_link(picked["kind"], picked["from"], picked["to"])
	if not removed.is_empty():
		edit.catalog = before
		return Outcome.refused(removed)
	return _made()


## True while a drag has picked up an edge (a test reads it).
func is_picking() -> bool:
	return not _picked.is_empty()


# --- the edits ----------------------------------------------------------------------------------

## The link of `kind` made (add) or removed.
func link(kind: String, from_id: String, to_id: String, add: bool) -> Outcome:
	var errors := edit.add_link(kind, from_id, to_id) if add else edit.remove_link(kind, from_id, to_id)
	return _made() if errors.is_empty() else Outcome.refused(errors)


## A new event, selected and scrolled to.
func add_event(pool: String, name: String) -> Outcome:
	var errors := edit.add_event(pool, name)
	if not errors.is_empty():
		return Outcome.refused(errors)
	selected = StoryEvent.id_for(pool, name)
	var outcome := _made()
	outcome.select = selected
	return outcome


## The event renamed (every requires and unless follows); its drafts and the selection follow,
## the text draft's `==` line renamed.
func rename(id: String, new_name: String) -> Outcome:
	var event: StoryEvent = edit.catalog.by_id.get(id)
	var before := edit.catalog
	var errors := edit.rename(id, new_name)
	if not errors.is_empty():
		return Outcome.refused(errors)
	if event != null:
		var new_id := StoryEvent.id_for(event.pool, new_name)
		if drafts.has(id):
			var draft: Dictionary = drafts[id]
			drafts.erase(id)
			drafts[new_id] = {"text": StoryEdit.with_name(draft["text"], event.name, new_name), "base": StoryEdit.with_name(draft["base"], event.name, new_name), "changed": draft["changed"]}
		if when_drafts.has(id):
			when_drafts[new_id] = when_drafts[id]
			when_drafts.erase(id)
		if selected == id:
			selected = new_id
	return _warn_presets(_made(), before)


## The events deleted as one gesture, all or nothing (StoryEdit.delete_events), their drafts with
## them.
func delete(ids: Array[String]) -> Outcome:
	var before := edit.catalog
	var errors := edit.delete_events(ids)
	return _warn_presets(_made(), before) if errors.is_empty() else Outcome.refused(errors)


## A header field of the shown event set (StoryEdit.set_header); refused while the event's text
## has a draft. A refusal goes to the panel, not the notice.
func set_field(key: String, value: String) -> Outcome:
	if selected == "":
		return Outcome.unchanged()
	var errors: Array[String] = []
	if has_draft():
		errors.append(DRAFT_FIRST)
	else:
		errors = edit.set_header(selected, key, value)
	if not errors.is_empty():
		return Outcome.in_panel(errors)
	if key == "when":
		when_drafts.erase(selected)
	return _made()


## The shown event's draft replaces it (StoryEdit.replace_event): made, the selection follows a
## new name in the text (and a draft flagged as changed under it says so: Apply is the writer's
## act, so it still applies); refused, the event and the draft are kept and the errors go to the
## panel.
func apply() -> Outcome:
	if selected == "" or not has_draft():
		return Outcome.unchanged()
	var id := selected
	var stale := draft_changed(id)
	var before := edit.catalog
	var errors := _apply(id)
	if not errors.is_empty():
		return Outcome.in_panel(errors)
	var outcome := _made()
	if stale:
		outcome.notice = "%s changed since its text was opened: your text replaced it as it stood." % id
		outcome.notice_kind = Outcome.WARN
	return _warn_presets(outcome, before)


## Writes the pools with unsaved edits (StoryEdit.save). A pool not written stays unsaved and the
## Outcome says why plainly (`alert` for the tab's Save button).
func save(dir: String) -> Outcome:
	var before := edit.dirty_pools()
	var errors := edit.save(dir)
	save_errors = errors
	var saved: Array[String] = []
	for pool in before:
		if not edit.dirty_pools().has(pool):
			saved.append(pool)
	warnings = warnings.filter(func(warning: Dictionary) -> bool: return not saved.has(warning["pool"]))
	var outcome := Outcome.new()
	outcome.redraw = true
	if errors.is_empty():
		outcome.notice = "Saved %s." % ", ".join(files(saved)) if not saved.is_empty() else ""
		outcome.notice_kind = Outcome.INFO
	else:
		outcome.errors = errors
		outcome.notice = save_message(errors)
		outcome.notice_kind = Outcome.ERROR
		outcome.alert = true
	return outcome


## The editor's save (Ctrl+S, Save All, before a run, Save & Quit): the pools with unsaved edits
## written; the drafts left as they are (applying is the writer's act) and named in the notice as
## not saved. Never a dialog: a refusal is the notice and the error list (save_errors).
func save_external(dir: String) -> Outcome:
	var outcome := save(dir) if not edit.dirty_pools().is_empty() else Outcome.unchanged()
	outcome.alert = false
	if not drafts.is_empty():
		var note := "Text not applied, not saved: %s (Apply it to keep it)." % ", ".join(PackedStringArray(drafts.keys()))
		outcome.notice = (outcome.notice + "\n" + note).strip_edges()
		if outcome.notice_kind != Outcome.ERROR:
			outcome.notice_kind = Outcome.WARN
		outcome.keep_notice = false
	return outcome


func dirty_pools() -> Array[String]:
	return edit.dirty_pools()


## True while a pool has unsaved edits or an event has text not applied.
func has_unsaved() -> bool:
	return not edit.dirty_pools().is_empty() or not drafts.is_empty()


## "the unsaved edits to a.txt and the text not applied of veteran.hello (lost unless applied)".
func unsaved_words() -> String:
	var parts: PackedStringArray = []
	var dirty := edit.dirty_pools()
	if not dirty.is_empty():
		parts.append("the unsaved edits to " + ", ".join(files(dirty)))
	if not drafts.is_empty():
		parts.append("the text not applied of %s (unapplied text will be lost)" % ", ".join(PackedStringArray(drafts.keys())))
	return " and ".join(parts)


## What the editor's quit prompt lists ("" for nothing).
func unsaved_status() -> String:
	return "Story tab: %s." % unsaved_words() if has_unsaved() else ""


## What the writer reads when a save fails: the errors, and for a file changed on disk since the
## load, what happened and what to do.
static func save_message(errors: Array[String]) -> String:
	var message := "Not saved:\n" + "\n".join(errors)
	for error in errors:
		if error.contains(CHANGED_ON_DISK):
			message += "\n\nA file changed on disk after the tab read it (edited outside the tab, or by git). Saving would overwrite that change, so it was not saved. To keep both: copy your edited events' text aside, Reload (it drops the tab's unsaved edits), and make them again."
			break
	return message


static func files(pools: Array[String]) -> PackedStringArray:
	var out: PackedStringArray = []
	for pool in pools:
		out.append(pool + ".txt")
	return out


# --- after an edit ------------------------------------------------------------------------------

## The draft of `id` applied; its errors, [] when made (the draft and the selection follow a new
## name in the text).
func _apply(id: String) -> Array[String]:
	var event: StoryEvent = edit.catalog.by_id.get(id)
	if event == null or not drafts.has(id):
		return []
	var text: String = (drafts[id] as Dictionary)["text"]
	var errors := edit.replace_event(id, text)
	if errors.is_empty():
		drafts.erase(id)
		var applied: StoryEvent = StoryScript.parse(text, event.pool)["events"][0]
		if selected == id:
			selected = applied.id
	return errors


## The made edit's Outcome with a warning for each event a preset names that the edit took out of
## the story (in `before`, the catalog the edit started from, and not in the edited one): the
## writer changes acts.json by hand.
func _warn_presets(outcome: Outcome, before: StoryCatalog) -> Outcome:
	var gone := {}  # id -> the acts naming it
	for act: int in acts:
		for id: String in (acts[act] as Dictionary).get("played", []):
			if before.by_id.has(id) and not edit.catalog.by_id.has(id):
				if not gone.has(id):
					gone[id] = []  # an Array, shared by reference (a PackedStringArray here is a copy)
				(gone[id] as Array).append(str(act))
	if gone.is_empty():
		return outcome
	var lines := PackedStringArray()
	for id: String in gone:
		lines.append("%s names %s (act %s): change it there by hand before the next load." % [StoryCatalog.ACTS_FILE, id, ", ".join(PackedStringArray(gone[id]))])
	outcome.notice = (outcome.notice + "\n" + "\n".join(lines)).strip_edges()
	if outcome.notice_kind != Outcome.ERROR:
		outcome.notice_kind = Outcome.WARN
	return outcome


## A made edit's Outcome: the graph again, the drafts checked against it.
func _made() -> Outcome:
	var outcome := Outcome.new()
	outcome.made = true
	outcome.redraw = true
	_refresh(outcome)
	return outcome


## The graph of the edited catalog; drafts of gone events dropped, drafts now equal to their event
## dropped, and a draft whose event changed under it kept and named in the notice.
func _refresh(outcome: Outcome) -> void:
	_draw_model()
	var changed: PackedStringArray = []
	for id: String in drafts.keys():
		var draft: Dictionary = drafts[id]
		if model.event(id) == null:
			drafts.erase(id)
			continue
		var now := model.text(id)
		if draft["text"] == now:
			drafts.erase(id)
		elif draft["base"] != now and not draft["changed"]:
			changed.append(id)
			draft["changed"] = true
	for id: String in when_drafts.keys():
		if model.event(id) == null:
			when_drafts.erase(id)
	if model.event(selected) == null:
		selected = ""
	if not changed.is_empty():
		outcome.notice = "%s changed under its text not applied: the panel keeps your text; Apply puts it in the event's place, Revert shows the event as it is now." % ", ".join(changed)
		outcome.notice_kind = Outcome.WARN


## The graph of edit.catalog and its lint, the lint's warnings filed on the graph's events.
func _draw_model() -> void:
	model = StoryGraph.of(edit.catalog)
	var words: Array[String] = []
	words.assign(lint_inputs.get("words", []))
	lint = StoryLint.run(edit.catalog, words, lint_inputs.get("game", {}))
	model.take_lint(lint_warnings())


## What a gesture did, for the tab to render.
class Outcome:
	extends RefCounted

	const INFO := "info"
	const WARN := "warn"
	const ERROR := "error"

	## The edit was made.
	var made := false
	## The refusal (or a save's errors).
	var errors: Array[String] = []
	## The notice under the toolbar: shown, or cleared when "" (unless keep_notice).
	var notice := ""
	var notice_kind := INFO
	## Leave the notice as it is (a gesture that did nothing, or one answered in the panel).
	var keep_notice := false
	## The errors for the side panel (an Apply, a header field), listed there with their lines.
	var panel_errors: Array[String] = []
	## Draw the graph again (from the session's model).
	var redraw := false
	## An event to select and scroll to ("" none).
	var select := ""
	## Show the notice in a dialog too (the Save button's failure).
	var alert := false

	## Nothing changed and nothing to say.
	static func unchanged() -> Outcome:
		var outcome := Outcome.new()
		outcome.keep_notice = true
		return outcome

	## Refused, the reason in the notice; nothing changed.
	static func refused(reasons: Array[String]) -> Outcome:
		var outcome := Outcome.new()
		outcome.errors = reasons
		outcome.notice = "Refused: " + "\n".join(reasons)
		outcome.notice_kind = ERROR
		return outcome

	## Refused, the reasons in the side panel; nothing changed.
	static func in_panel(reasons: Array[String]) -> Outcome:
		var outcome := Outcome.new()
		outcome.errors = reasons
		outcome.panel_errors = reasons
		outcome.keep_notice = true
		return outcome
