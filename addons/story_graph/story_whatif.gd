@tool
extends RefCounted
## The Story tab's What-if (docs/plans/2026-10-01-milestone-6.md, Task 14), with no UI: a scratch
## story state and a moment, and what the graph shows for them: each pool's next event marked, the
## events that would not play dimmed (EventNode's "whatif" reason), and the reasons of the selected
## one (StoryExplain, on StoryPicker's own rules, so the tab never disagrees with the game). It
## never touches the story's files or the session's edits: no pool is ever dirtied here.
##
## The state: a Save (Blank: a fresh one; Load my save: the game's save read from a copy), the
## last run's facts (as handed to StoryContext, a fact winning over the save's newest record), and
## the moment: a trigger the game asks the story at (talk, enter <room>, the verdict's three, the
## pick) with the facts Main hands in at it (an entry's arrival, the verdict's run_band, the pick's
## round_band and round_loss; talk none). What is marked is what the game plays (StoryExplain.plays,
## on its table of the pools the game asks, StoryExplain.ASKED): an entry is asked of every pool at
## once, so it marks one event; the verdict marks the narrator's, the pick the crowd's, talk each
## pool's that is not timed.
##
## Load my save never opens the player's file for writing, never backs it up, never moves it: the
## file's bytes are read (FileAccess.get_file_as_bytes, a read-only open) and written to a
## per-process scratch (`scratch_path`), which Save.load_from reads; a copy it cannot use is backed
## up beside the scratch by Save, and both are removed before this returns. A missing, unreadable,
## or newer save leaves the state as it was. Names no autoload and no Node class.

## The moment's facts Main hands in, by trigger (StoryContext.MOMENT_FACTS): StoryExplain's table,
## which the lint reads too.
const MOMENT_FACTS := StoryExplain.FACTS
## The last run's facts a condition reads (StoryContext.last_run_facts).
const LAST_RUN: Array[String] = ["last_outcome", "last_verdict", "last_band", "last_killer"]
const NOT_LOADED := "not loaded: the game does not play it until its errors are fixed"

var save: Save = Save.new()
## The last run's facts: name -> word.
var last_run: Dictionary = StoryContext.last_run_facts({})
## The moment's trigger and the room of `enter`.
var trigger := "talk"
var room: String = StoryScript.ROOMS[0]
## Every moment fact's value; facts() hands in the moment's own.
var moment_values: Dictionary = {"arrival": "door", "round_band": "quiet", "round_loss": "none", "run_band": "quiet"}
## The save Load my save reads (a copy of it).
var source_path := Save.DEFAULT_PATH
## Where the copy is read from; removed after each load.
var scratch_path := "user://story_whatif_%d.cfg" % OS.get_process_id()


## A fresh state: nothing played, every count 0, no last run. The moment is kept.
func blank() -> void:
	save = Save.new()
	last_run = StoryContext.last_run_facts({})


## The save at `source` (source_path when "") read from a copy: {"ok", "message"}. Refused (a
## missing file, one that cannot be copied, read, or is from a later version), the state is kept.
func load_save(source := "") -> Dictionary:
	if source == "":
		source = source_path
	if not FileAccess.file_exists(source):
		return _refused("No save at %s (the game has not written one)" % source)
	var bytes := FileAccess.get_file_as_bytes(source)
	if bytes.is_empty() and FileAccess.get_open_error() != OK:
		return _refused("Could not read %s (%s)" % [source, error_string(FileAccess.get_open_error())])
	var copy := FileAccess.open(scratch_path, FileAccess.WRITE)
	if copy == null:
		return _refused("Could not copy %s to %s (%s)" % [source, scratch_path, error_string(FileAccess.get_open_error())])
	copy.store_buffer(bytes)
	copy.close()
	var printing := Engine.print_error_messages
	Engine.print_error_messages = false  # a corrupt file's parse error: the message below says it
	var loaded := Save.load_from(scratch_path)
	Engine.print_error_messages = printing
	var unusable := loaded.backup_note
	for path in [scratch_path, scratch_path + Save.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if unusable != "":
		var why := "is from a later version of the game" if unusable.contains("later version") else "could not be read"
		return _refused("%s %s" % [source, why])
	save = loaded
	last_run = StoryContext.last_run_facts(save.runs[0] if not save.runs.is_empty() else {})
	return {"ok": true, "message": "Loaded a copy of %s: %d runs, %d events played." % [source, int(save.flags.get("runs", 0)), (save.story["played"] as Dictionary).size()]}


static func _refused(why: String) -> Dictionary:
	return {"ok": false, "message": why + ": the What-if state is unchanged."}


# --- the profile, the last run, the story flags ----------------------------------------------------

## A profile flag (Save.FLAG_KEYS) set to a value of its type; false (nothing set) otherwise.
func set_profile(key: String, value: Variant) -> bool:
	if not Save.settable(key, value):
		return false
	save.set_flag(key, value)
	return true


## A last-run fact set to one of its words (any word for last_killer, "" its none); false otherwise.
func set_last(name: String, word: String) -> bool:
	if not LAST_RUN.has(name):
		return false
	var words: Array = StoryContext.WORDS.get(name, [])
	if name in StoryContext.OPEN_WORDS:
		word = word.strip_edges()
		word = word if word != "" else StoryContext.NONE
	elif not words.has(word):
		return false
	last_run[name] = word
	return true


## A declared story flag set to a value of its declared type; false otherwise. An empty word is the
## flag's declared default (a word flag is never "").
func set_story_flag(catalog: StoryCatalog, name: String, value: Variant) -> bool:
	if not catalog.flags.has(name) or typeof(value) != typeof(catalog.flags[name]):
		return false
	if value is String:
		value = (value as String).strip_edges()
		if value == "":
			value = catalog.flags[name]
	save.set_story_flag(name, value)
	return true


## The story flag's value now (its declared default until set).
func story_flag(catalog: StoryCatalog, name: String) -> Variant:
	return save.story_flag(name, catalog.flags.get(name))


# --- played, and the return ------------------------------------------------------------------------

## The event marked played as the game's begin marks it (a talk event that is not filler uses its
## pool's turn this return), or unmarked (it plays again; the turn stays used until a Return). No
## effect runs: the flags are the panel's.
func set_played(catalog: StoryCatalog, id: String, on: bool) -> void:
	if on == is_played(id):
		return
	if not on:
		(save.story["played"] as Dictionary).erase(id)
		return
	save.mark_story_played(id)
	var event: StoryEvent = catalog.by_id.get(id)
	if event != null and event.uses_turn():
		save.mark_story_spoken(event.pool)


func toggle_played(catalog: StoryCatalog, id: String) -> void:
	set_played(catalog, id, not is_played(id))


func is_played(id: String) -> bool:
	return save.story_played(id) > 0


## The pools that have spoken this return.
func spoken() -> Array[String]:
	var out: Array[String] = []
	for pool: Variant in save.story["spoken"]:
		out.append(str(pool))
	return out


## A run's end: every pool may speak again (Story's _new_return).
func new_return() -> void:
	save.clear_story_spoken()


# --- the moment ----------------------------------------------------------------------------------

## Every moment the panel offers, as the file writes a trigger: talk, enter <room> for each room,
## the verdict's three, the pick.
func moments() -> Array[String]:
	var out: Array[String] = []
	for each: String in StoryScript.TRIGGERS:
		if each == "enter":
			for at: String in StoryScript.ROOMS:
				out.append(StoryExplain.moment(each, at))
		else:
			out.append(each)
	return out


func moment() -> String:
	return StoryExplain.moment(trigger, room if trigger == "enter" else "")


## The moment from its text ("enter ludus"); false (unchanged) for one not offered.
func set_moment(text: String) -> bool:
	if not moments().has(text):
		return false
	trigger = text.get_slice(" ", 0)
	if trigger == "enter":
		room = text.get_slice(" ", 1)
	return true


## The facts the moment hands in.
func moment_fact_names() -> Array[String]:
	var out: Array[String] = []
	out.assign(MOMENT_FACTS.get(trigger, []))
	return out


## A moment fact set to one of its words (StoryContext.WORDS); false otherwise.
func set_fact(name: String, word: String) -> bool:
	if not moment_values.has(name) or not (StoryContext.WORDS.get(name, []) as Array).has(word):
		return false
	moment_values[name] = word
	return true


## What the context is handed: the last run's facts and the moment's.
func facts() -> Dictionary:
	var out := last_run.duplicate()
	for name in moment_fact_names():
		out[name] = moment_values[name]
	return out


func context(catalog: StoryCatalog) -> StoryContext:
	return StoryContext.new(save, catalog.flags, facts())


# --- what the graph shows ----------------------------------------------------------------------------

## The events marked next (id -> true): what the game plays at the moment (StoryExplain.plays).
func next_ids(catalog: StoryCatalog, at: StoryContext = null) -> Dictionary:
	var ctx := at if at != null else context(catalog)
	var out := {}
	for event in StoryExplain.plays(catalog, save, ctx, trigger, _arg()):
		out[event.id] = true
	return out


## What the tab draws for the events `ids` (the graph's, loaded or not): {"next": id -> true,
## "dim": id -> true for one that would not play (not loaded, or a reason against it), "played":
## id -> its count, for the played ones}.
func view(catalog: StoryCatalog, ids: Array[String]) -> Dictionary:
	var ctx := context(catalog)
	var dim := {}
	var played := {}
	for id in ids:
		var event: StoryEvent = catalog.by_id.get(id)
		if event == null or not StoryExplain.why_not(event, catalog, save, ctx, trigger, _arg()).is_empty():
			dim[id] = true
		if save.story_played(id) > 0:
			played[id] = save.story_played(id)
	return {"next": next_ids(catalog, ctx), "dim": dim, "played": played}


## Why the event would not play at the moment (StoryExplain.why_not); when nothing stands against
## it, that it plays next, or which event plays first.
func reasons(catalog: StoryCatalog, id: String) -> Array[String]:
	var event: StoryEvent = catalog.by_id.get(id)
	if event == null:
		return [NOT_LOADED] as Array[String]
	var ctx := context(catalog)
	var why := StoryExplain.why_not(event, catalog, save, ctx, trigger, _arg())
	if not why.is_empty():
		return why
	var first := StoryPicker.pick(catalog, save, ctx, "" if StoryExplain.asked_at_once(trigger) else event.pool, trigger, _arg())
	if first == event:
		return ["plays next at " + moment()] as Array[String]
	return ["eligible, but %s plays first" % (first.id if first != null else "another")] as Array[String]


func _arg() -> String:
	return room if trigger == "enter" else ""
