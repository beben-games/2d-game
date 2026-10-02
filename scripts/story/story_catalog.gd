class_name StoryCatalog
extends RefCounted
## Every story event, validated at load as UpgradeCatalog validates the cards: the cast (cast.json,
## also the pools' index: a pool is <dir>/<cast id>.txt, read by name, never by listing a
## directory, since an exported build cannot be trusted to list raw files; a missing file is an
## empty pool), the story flags (flags.txt), and the pools. Every error names the file and the
## line (a cast error names cast.json and the member: JSON has no line to give); an event with an
## error is left out and the rest load. The parser's warnings (an inline comment a rewrite would
## drop) are collected as `warnings`, never errors. Pure: the Story autoload pushes the errors
## (so check_boot fails on bad shipped content), the tests read them. The format's tables
## (priorities, triggers, rooms) are StoryScript's.
##
## Checked here, beyond StoryScript's shapes: a duplicate id; an unknown speaker; an unknown event
## in requires or unless; a cycle of requires; an unknown name in a condition or a substitution;
## a word outside a name's list; an effect on an undeclared flag or of the wrong type; a timed
## event (is_timed: a timed trigger or a timed pool) with a choice or a line over TIMED_LINE_CAP
## (the marker stripped, before substitution); a line of an event shown in the text box over
## BOX_LINE_CAP, or a run of more than CHOICE_MAX choices; a cast member without a name where one is needed
## (every member but a timed one), with a name that is not a string, or a `timed` that is not
## true or false; a pool not in the cast; a flag that takes a name the story already reads.
##
## The valid set is closed under dependence: an event whose `requires` or `unless` names an event
## that did not load (an error at its parse, at a check here, or a member of a cycle) does not
## load either, with one error naming that cause ("requires veteran.x, which did not load"), to a
## fixed point; an id that names no event at all is the "unknown event" error instead.

## The moments shown without input (the narrator at the verdict, the crowd at the pick): no
## choices, and a line short enough to read in the window.
const TIMED_TRIGGERS: Array[String] = ["verdict_wait", "verdict_up", "verdict_down", "pick"]
const TIMED_LINE_CAP := 48
## A line the text box shows (any line not timed), the marker stripped, before substitution: what
## three wrapped lines hold in the box (its text column is 936 px of the pixel font at 32 px, about
## 13 px a letter: 200 lowercase or 180 capitals fit three lines; the box shows three at most).
const BOX_LINE_CAP := 180
## The choices offered at once (a run of choices, comments between them ignored): one a pick key
## (DialogueBox.PICK_ACTIONS has this many) and one a row of the box.
const CHOICE_MAX := 5
const CAST_FILE := "cast.json"
const FLAGS_FILE := "flags.txt"
## The shipped story's directory (the Story autoload's, and the grounds' rooms' for their doors'
## conditions).
const DATA_DIR := "res://data/story"

## Cast id -> its entry from cast.json (name, timed, and what later tasks add).
var cast: Dictionary = {}
## Story flag -> its default.
var flags: Dictionary = {}
## Every valid event, by the cast's order and then file order.
var events: Array[StoryEvent] = []
var by_id: Dictionary = {}
var errors: Array[String] = []
## The parsers' warnings, each "<file>:<line>: ...": not errors, the lint shows them.
var warnings: Array[String] = []
var _pools: Dictionary = {}
var _order: Dictionary = {}


## The story in `dir`: cast.json, flags.txt (missing: no flags), and <dir>/<id>.txt per cast id.
static func load_dir(dir: String) -> StoryCatalog:
	var catalog := StoryCatalog.new()
	var cast_path := dir.path_join(CAST_FILE)
	if not FileAccess.file_exists(cast_path):
		catalog.errors.append("%s: missing (%s)" % [CAST_FILE, cast_path])
		return catalog
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(cast_path)) != OK:
		catalog.errors.append("%s:%d: %s" % [CAST_FILE, json.get_error_line(), json.get_error_message()])
		return catalog
	if not json.data is Dictionary:
		catalog.errors.append("%s: not an object of cast ids" % CAST_FILE)
		return catalog
	var cast_data: Dictionary = json.data
	var flags_path := dir.path_join(FLAGS_FILE)
	var flags_text := FileAccess.get_file_as_string(flags_path) if FileAccess.file_exists(flags_path) else ""
	var pools := {}
	for id: Variant in cast_data:
		var path := dir.path_join("%s.txt" % id)
		if FileAccess.file_exists(path):
			pools[id] = FileAccess.get_file_as_string(path)
	catalog._build(cast_data, flags_text, pools)
	return catalog


## The story flags declared in `dir`'s flags.txt and their defaults (none when it is missing),
## as load_dir would hold them: for a check that reads conditions without loading the pools (the
## grounds' doors).
static func declared_flags(dir := DATA_DIR) -> Dictionary:
	var path := dir.path_join(FLAGS_FILE)
	var catalog := StoryCatalog.new()
	catalog._load_flags(FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "")
	return catalog.flags


## The story from texts: the cast's entries, the flags file's text, and pool id -> its file's text.
static func from_texts(cast_data: Dictionary, flags_text: String, pools: Dictionary) -> StoryCatalog:
	var catalog := StoryCatalog.new()
	catalog._build(cast_data, flags_text, pools)
	return catalog


## The pool's valid events in file order; empty for a pool with none (or none at all).
func pool(id: String) -> Array[StoryEvent]:
	var list: Array[StoryEvent] = []
	list.assign(_pools.get(id, []))
	return list


## The event's place in the catalog (the cast's order, then file order): the picker's last
## tiebreak. -1 for an event not in it.
func index_of(event: StoryEvent) -> int:
	return int(_order.get(event.id, -1))


## The priority's tier: 0 for story, the highest, up to 3 for filler.
static func priority_rank(priority: String) -> int:
	return StoryScript.PRIORITIES.find(priority)


## True when the event is shown in the timed window (no input, no choice, a capped line): its
## trigger is a timed moment, or its pool is a timed member of the cast (the narrator's `enter
## spoliarium` line plays in the window because the narrator is timed).
func is_timed(event: StoryEvent) -> bool:
	if is_timed_trigger(event.trigger):
		return true
	var entry: Variant = cast.get(event.pool, {})
	var timed: Variant = entry.get("timed", false) if entry is Dictionary else false
	return timed is bool and timed


## The trigger's meaning alone: a moment shown without input.
static func is_timed_trigger(trigger: String) -> bool:
	return trigger in TIMED_TRIGGERS


func _build(cast_data: Dictionary, flags_text: String, pools: Dictionary) -> void:
	_load_cast(cast_data)
	_load_flags(flags_text)
	var parsed: Array[StoryEvent] = []
	var known := {}  # every id a pool defines, loaded or not
	for id: String in cast:
		if pools.has(id):
			var result := StoryScript.parse(pools[id], id)
			errors.append_array(result["errors"])
			warnings.append_array(result["warnings"])
			parsed.append_array(result["events"])
			for dropped: String in result["dropped"]:
				known[dropped] = true
	for id: Variant in pools:
		if not cast.has(id) and not cast_data.has(id):
			errors.append("%s.txt: not in the cast (%s)" % [id, CAST_FILE])
	for event: StoryEvent in parsed:
		known[event.id] = true
	var context := StoryContext.new(null, flags)
	var first_line := {}
	var valid: Array[StoryEvent] = []
	for event: StoryEvent in parsed:
		var found: Array[String] = []
		if first_line.has(event.id):
			found.append(_at(event, event.line_number, "duplicate event '%s' (first at line %d)" % [event.id, first_line[event.id]]))
		else:
			first_line[event.id] = event.line_number
			found.append_array(_check(event, context, known))
		errors.append_array(found)
		if found.is_empty():
			valid.append(event)
	var in_cycle := _cycles(valid)
	var kept: Array[StoryEvent] = []
	for event: StoryEvent in valid:
		if not in_cycle.has(event.id):
			kept.append(event)
	kept = _close_under_dependence(kept)
	for event: StoryEvent in kept:
		_order[event.id] = events.size()
		events.append(event)
		by_id[event.id] = event
		if not _pools.has(event.pool):
			_pools[event.pool] = []
		(_pools[event.pool] as Array).append(event)


## The events left once every event naming one that did not load is gone too, repeated until
## none goes: one error per event dropped, naming the first missing id it names.
func _close_under_dependence(candidates: Array[StoryEvent]) -> Array[StoryEvent]:
	var kept := candidates.duplicate()
	var changed := true
	while changed:
		changed = false
		var loaded := {}
		for event: StoryEvent in kept:
			loaded[event.id] = true
		var next: Array[StoryEvent] = []
		for event: StoryEvent in kept:
			var cause := _missing_dependency(event, loaded)
			if cause == "":
				next.append(event)
			else:
				errors.append(cause)
				changed = true
		kept = next
	return kept


## The error for the first id the event's requires or unless names that is not loaded, or "".
func _missing_dependency(event: StoryEvent, loaded: Dictionary) -> String:
	for key: String in ["requires", "unless"]:
		for id: String in event.get(key):
			if not loaded.has(id):
				return _at(event, event.header_line[key], "%s %s, which did not load" % [key, id])
	return ""


func _load_cast(cast_data: Dictionary) -> void:
	for id: Variant in cast_data:
		var entry: Variant = cast_data[id]
		if not (id is String and StoryScript.is_cast_id(id)):
			errors.append("%s: '%s' is not a cast id (lowercase letters, digits, '_')" % [CAST_FILE, id])
		elif not entry is Dictionary:
			errors.append("%s: '%s' is not an object" % [CAST_FILE, id])
		elif entry.has("timed") and not entry["timed"] is bool:
			errors.append("%s: '%s': timed is true or false" % [CAST_FILE, id])
		elif entry.has("name") and not entry["name"] is String:
			errors.append("%s: '%s': name is a string" % [CAST_FILE, id])
		elif not entry.get("timed", false) and entry.get("name", "") == "":
			errors.append("%s: '%s' has no name" % [CAST_FILE, id])
		else:
			cast[id] = entry


func _load_flags(flags_text: String) -> void:
	var parsed := StoryScript.parse_flags(flags_text, FLAGS_FILE)
	errors.append_array(parsed["errors"])
	var reads := StoryContext.new()
	for name: String in parsed["flags"]:
		if reads.knows(name):
			errors.append("%s:%d: '%s' is a name the story already reads" % [FLAGS_FILE, parsed["lines"][name], name])
		else:
			flags[name] = parsed["flags"][name]


## What is wrong with one event against the cast, the flags, and the ids the pools define
## (`known`: loaded or not; a dependency that did not load is _close_under_dependence's).
func _check(event: StoryEvent, context: StoryContext, known: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for key: String in ["requires", "unless"]:
		for id: String in event.get(key):
			if not known.has(id):
				found.append(_at(event, event.header_line[key], "unknown event '%s' in %s" % [id, key]))
	if event.when != null:
		for message: String in event.when.check(context):
			found.append(_at(event, event.header_line["when"], "when: " + message))
	var timed := is_timed(event)
	var run := 0
	for entry: Dictionary in event.body:
		match entry["kind"]:
			"choice":
				run += 1
				if run == CHOICE_MAX + 1:
					found.append(_at(event, entry["line"], "more than %d choices at once" % CHOICE_MAX))
				if timed:
					found.append(_at(event, entry["line"], "a timed event has no choices (trigger %s in pool %s)" % [event.trigger, event.pool]))
				found.append_array(_check_text(event, entry, context))
				found.append_array(_check_effects(event, entry["effects"]))
				for line: Dictionary in entry["lines"]:
					if line["kind"] == "line":
						found.append_array(_check_line(event, line, context, timed))
			"line":
				run = 0
				found.append_array(_check_line(event, entry, context, timed))
	found.append_array(_check_effects(event, event.effects))
	return found


func _check_line(event: StoryEvent, line: Dictionary, context: StoryContext, timed: bool) -> Array[String]:
	var found: Array[String] = []
	if not cast.has(line["speaker"]):
		found.append(_at(event, line["line"], "unknown speaker '%s'" % str(line["speaker"]).to_upper()))
	var when: StoryCondition = line["when"]
	if when != null:
		for message: String in when.check(context):
			found.append(_at(event, line["line"], "[%s]: %s" % [when.source, message]))
	found.append_array(_check_text(event, line, context))
	var shown := StoryScript.strip_marker(line["text"])
	if timed and shown.length() > TIMED_LINE_CAP:
		found.append(_at(event, line["line"], "a timed line over %d characters (%d)" % [TIMED_LINE_CAP, shown.length()]))
	elif not timed and shown.length() > BOX_LINE_CAP:
		found.append(_at(event, line["line"], "a line over %d characters (%d)" % [BOX_LINE_CAP, shown.length()]))
	return found


func _check_text(event: StoryEvent, entry: Dictionary, context: StoryContext) -> Array[String]:
	var found: Array[String] = []
	for name: String in StoryContext.names_in(entry["text"]):
		if not context.knows(name):
			found.append(_at(event, entry["line"], "unknown name '%s' in {%s}" % [name, name]))
	return found


func _check_effects(event: StoryEvent, effects: Array) -> Array[String]:
	var found: Array[String] = []
	for effect: Dictionary in effects:
		var flag: String = effect["flag"]
		if not flags.has(flag):
			found.append(_at(event, effect["line"], "undeclared flag '%s' (%s)" % [flag, FLAGS_FILE]))
		elif typeof(effect["value"]) != typeof(flags[flag]):
			found.append(_at(event, effect["line"], "'%s' is %s, set to %s" % [flag, _kind_of(flags[flag]), str(effect["value"])]))
	return found


static func _kind_of(value: Variant) -> String:
	if value is bool:
		return "a bool"
	return "an int" if value is int else "a word"


## The ids of the events in a cycle of requires, each cycle reported once at the requires line
## of the event the walk entered it by.
func _cycles(valid: Array[StoryEvent]) -> Dictionary:
	var ids := {}
	for event: StoryEvent in valid:
		ids[event.id] = event
	var state := {}  # id -> 1 on the walk's path, 2 done
	var in_cycle := {}
	for event: StoryEvent in valid:
		_walk(event, ids, state, [], in_cycle)
	return in_cycle


func _walk(event: StoryEvent, ids: Dictionary, state: Dictionary, path: Array[String], in_cycle: Dictionary) -> void:
	if state.get(event.id, 0) == 2:
		return
	state[event.id] = 1
	path.append(event.id)
	for id: String in event.requires:
		if not ids.has(id):
			continue
		if state.get(id, 0) == 1:
			var loop := path.slice(path.find(id))
			loop.append(id)
			var first: StoryEvent = ids[loop[0]]
			errors.append(_at(first, first.header_line["requires"], "a cycle of requires: %s" % " -> ".join(loop)))
			for member: String in loop:
				in_cycle[member] = true
		else:
			_walk(ids[id], ids, state, path, in_cycle)
	path.pop_back()
	state[event.id] = 2


static func _at(event: StoryEvent, line: int, message: String) -> String:
	return "%s:%d: %s" % [event.file(), line, message]
