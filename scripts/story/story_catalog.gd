class_name StoryCatalog
extends RefCounted
## Every story event, validated at load as UpgradeCatalog validates the cards: the cast (cast.json,
## also the pools' index: a pool is <dir>/<cast id>.txt, read by name, never by listing a
## directory, since an exported build cannot be trusted to list raw files; a missing file is an
## empty pool), the story flags (flags.txt), and the pools. Every error names the file and the
## line; an event with an error is left out and the rest load. Pure: the Story autoload pushes
## the errors (so check_boot fails on bad shipped content), the tests read them.
##
## Checked here, beyond StoryScript's shapes: a duplicate id; an unknown speaker; an unknown event
## in requires or unless; a cycle of requires; an unknown name in a condition or a substitution;
## a word outside a name's list; an effect on an undeclared flag or of the wrong type; a timed
## trigger's event with a choice or a line over TIMED_LINE_CAP (the marker stripped); a cast id
## without a name where one is needed (every member but a timed one); a pool not in the cast; a
## flag that takes a name the story already reads.

const PRIORITIES := StoryScript.PRIORITIES
## The third seam: a later moment (round_start, boss_spawn, low_health) is a new row here and in
## TIMED_TRIGGERS when the timed presenter shows it.
const TRIGGERS := StoryScript.TRIGGERS
const ROOMS := StoryScript.ROOMS
## The moments shown without input (the narrator at the verdict, the crowd at the pick): no
## choices, and a line short enough to read in the window.
const TIMED_TRIGGERS: Array[String] = ["verdict_wait", "verdict_up", "verdict_down", "pick"]
const TIMED_LINE_CAP := 48
const CAST_FILE := "cast.json"
const FLAGS_FILE := "flags.txt"

## Cast id -> its entry from cast.json (name, timed, and what later tasks add).
var cast: Dictionary = {}
## Story flag -> its default.
var flags: Dictionary = {}
## Every valid event, by the cast's order and then file order.
var events: Array[StoryEvent] = []
var by_id: Dictionary = {}
var errors: Array[String] = []
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
	return PRIORITIES.find(priority)


static func is_timed(event: StoryEvent) -> bool:
	return event.trigger in TIMED_TRIGGERS


func _build(cast_data: Dictionary, flags_text: String, pools: Dictionary) -> void:
	_load_cast(cast_data)
	_load_flags(flags_text)
	var parsed: Array[StoryEvent] = []
	for id: String in cast:
		if pools.has(id):
			parsed.append_array(_parse_pool(id, pools[id]))
	for id: Variant in pools:
		if not cast.has(id) and not cast_data.has(id):
			errors.append("%s.txt: not in the cast (%s)" % [id, CAST_FILE])
	var context := StoryContext.new(null, flags)
	var first_line := {}
	var all_ids := {}
	for event: StoryEvent in parsed:
		all_ids[event.id] = true
	var valid: Array[StoryEvent] = []
	for event: StoryEvent in parsed:
		var found: Array[String] = []
		if first_line.has(event.id):
			found.append(_at(event, event.line_number, "duplicate event '%s' (first at line %d)" % [event.id, first_line[event.id]]))
		else:
			first_line[event.id] = event.line_number
			found.append_array(_check(event, context, all_ids))
		errors.append_array(found)
		if found.is_empty():
			valid.append(event)
	var in_cycle := _cycles(valid)
	for event: StoryEvent in valid:
		if in_cycle.has(event.id):
			continue
		_order[event.id] = events.size()
		events.append(event)
		by_id[event.id] = event
		if not _pools.has(event.pool):
			_pools[event.pool] = []
		(_pools[event.pool] as Array).append(event)


func _load_cast(cast_data: Dictionary) -> void:
	for id: Variant in cast_data:
		var entry: Variant = cast_data[id]
		if not (id is String and StoryScript._matches("^[a-z][a-z0-9_]*$", id)):
			errors.append("%s: '%s' is not a cast id (lowercase letters, digits, '_')" % [CAST_FILE, id])
		elif not entry is Dictionary:
			errors.append("%s: '%s' is not an object" % [CAST_FILE, id])
		elif not entry.get("timed", false) and not (entry.get("name") is String and entry.get("name") != ""):
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


func _parse_pool(id: String, text: String) -> Array[StoryEvent]:
	var parsed := StoryScript.parse(text, id)
	errors.append_array(parsed["errors"])
	return parsed["events"]


## What is wrong with one event against the cast, the flags, and the other events.
func _check(event: StoryEvent, context: StoryContext, all_ids: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for key: String in ["requires", "unless"]:
		for id: String in event.get(key):
			if not all_ids.has(id):
				found.append(_at(event, event.header_line[key], "unknown event '%s' in %s" % [id, key]))
	if event.when != null:
		for message: String in event.when.check(context):
			found.append(_at(event, event.header_line["when"], "when: " + message))
	var timed := is_timed(event)
	for entry: Dictionary in event.body:
		if entry["kind"] == "choice":
			if timed:
				found.append(_at(event, entry["line"], "a timed event has no choices (trigger %s)" % event.trigger))
			found.append_array(_check_text(event, entry, context))
			found.append_array(_check_effects(event, entry["effects"]))
			for line: Dictionary in entry["lines"]:
				found.append_array(_check_line(event, line, context, timed))
		else:
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
