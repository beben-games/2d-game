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
## (priorities, triggers, rooms) are StoryScript's. The pools' header and footer comments are
## kept, so a pool is written back whole (text_of, save_dir: the Story tab's save, through
## StoryEdit).
##
## Checked here, beyond StoryScript's shapes: a duplicate id; an unknown speaker; an unknown event
## in requires or unless; a cycle of requires; an unknown name in a condition or a substitution;
## a word outside a name's list; an effect on an undeclared flag or of the wrong type; a timed
## event (is_timed: a timed trigger or a timed pool) with a choice or a line over TIMED_LINE_CAP
## (the marker stripped, before substitution); a line of an event shown in the text box over
## BOX_LINE_CAP, a choice's text over CHOICE_TEXT_CAP, or a run of more than CHOICE_MAX choices
## (a line with a condition does not end the run: dropped, it would join two runs into one); a
## cast member without a name where one is needed (every member but a timed one), with a name
## that is not a string, or a `timed` or a `silhouette` (the portrait drawn dark) that is not true
## or false; a pool not in the cast; a flag that takes a name the story already reads.
##
## The act cheat's presets (acts.json, optional: no file is no presets) are checked after the
## events: an act outside PRESET_ACTS, a key outside PRESET_KEYS, a profile flag not in
## Save.FLAG_KEYS or not of its type (a count is an integer, 0 or more), a story flag not declared
## or not of its declared type, a played id that names no event, names one that did not load, or
## comes twice. Each error names acts.json and the act; a preset with an error is left out.
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
## The choices offered at once (a run of choices, comments and conditioned lines between them
## ignored): one a pick key (DialogueBox.pick_action has one for each) and one a row of the box.
const CHOICE_MAX := 5
## A choice's text, the marker stripped, before substitution: one row of the box (a row trims an
## overflow with an ellipsis rather than wrapping).
const CHOICE_TEXT_CAP := 60
const CAST_FILE := "cast.json"
const FLAGS_FILE := "flags.txt"
const ACTS_FILE := "acts.json"
## The acts a preset can start (the title's actus2 and actus3, Cheats.ACTIONS): act 1 is a fresh
## save (tabula), so it has none.
const PRESET_ACTS: Array[int] = [2, 3]
## A preset's keys, each optional: the profile's flags, the story flags, the events played.
const PRESET_KEYS: Array[String] = ["flags", "story_flags", "played"]
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
## Pool id -> its file's header and footer comment blocks (StoryScript.parse's), for every cast
## pool given a text: what text_of writes around the events.
var headers: Dictionary = {}
var footers: Dictionary = {}
## Cast id -> its pool's text as read from disk at the load ("" for no file), and as written by
## each save since: save_dir refuses a file that no longer holds it (changed on disk since the
## load). A catalog from with_texts starts from a copy of its parent's (an edit writes nothing to
## disk; two editors on one catalog each keep their own, so the second save is refused).
var loaded: Dictionary = {}
## Pool id -> the text this catalog was built from (load_dir: the file as read; from_texts and
## with_texts: the text given; no entry for a pool given none). For a with_texts catalog (an
## edit's) it is the edited text, while `loaded` stays the disk's: the Story tab draws from this.
var texts: Dictionary = {}
## Act -> its preset from acts.json: {"flags": the profile's (Save.FLAG_KEYS), "story_flags",
## "played": event ids in the file's order}, every value of its flag's type (JSON's numbers read
## as integers). Only load_dir and from_texts read an acts file: a with_texts catalog (an edit's)
## has none, since the acts file is not a pool and the Story tab neither reads nor writes it (a
## preset an edit breaks, a renamed event it names, is an error at the next load: the tab's
## Reload, the lint, the boot). The Story autoload's apply_act writes one into the profile.
var acts: Dictionary = {}
var _pools: Dictionary = {}
var _order: Dictionary = {}
## What the catalog was built from beside the pools (with_texts builds another on them).
var _cast_data: Dictionary = {}
var _flags_text := ""
## Every id a pool defines, loaded or not (a preset's played id that did not load is told apart).
var _defined: Dictionary = {}


## The story in `dir`: cast.json, flags.txt (missing: no flags), <dir>/<id>.txt per cast id, and
## acts.json (missing: no presets).
static func load_dir(dir: String) -> StoryCatalog:
	var catalog := StoryCatalog.new()
	var cast_path := dir.path_join(CAST_FILE)
	if not FileAccess.file_exists(cast_path):
		catalog.errors.append("%s: missing (%s)" % [CAST_FILE, cast_path])
		return catalog
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(cast_path)) != OK:
		catalog.errors.append("%s:%d: %s" % [CAST_FILE, json.get_error_line() + 1, json.get_error_message()])  # JSON counts its lines from 0
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
	catalog._remember_loaded(pools)
	var acts_path := dir.path_join(ACTS_FILE)
	catalog._load_acts(FileAccess.get_file_as_string(acts_path) if FileAccess.file_exists(acts_path) else "")
	return catalog


## The story flags declared in `dir`'s flags.txt and their defaults (none when it is missing),
## as load_dir would hold them: for a check that reads conditions without loading the pools (the
## grounds' doors).
static func declared_flags(dir := DATA_DIR) -> Dictionary:
	var path := dir.path_join(FLAGS_FILE)
	var catalog := StoryCatalog.new()
	catalog._load_flags(FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "")
	return catalog.flags


## The story from texts: the cast's entries, the flags file's text, pool id -> its file's text,
## and the acts file's text ("" for none).
static func from_texts(cast_data: Dictionary, flags_text: String, pools: Dictionary, acts_text := "") -> StoryCatalog:
	var catalog := StoryCatalog.new()
	catalog._build(cast_data, flags_text, pools)
	catalog._remember_loaded(pools)
	catalog._load_acts(acts_text)
	return catalog


## The same cast and flags with these pools' texts (pool id -> text): a StoryEdit's candidate,
## validated as a load is.
func with_texts(pools: Dictionary) -> StoryCatalog:
	var catalog := StoryCatalog.new()
	catalog._build(_cast_data, _flags_text, pools)
	catalog.loaded = loaded.duplicate()  # a save moves only its own chain's record of the disk
	return catalog


## The pool written back in the canonical form (StoryScript.write): its events, its file's header
## and footer. "" for a pool with no text and no events. Lossless only while `errors` is empty (an
## event that did not load is not here to write).
func text_of(id: String) -> String:
	return StoryScript.write(pool(id), headers.get(id, ""), footers.get(id, ""))


## Writes each named pool to <dir>/<id>.txt as text_of gives it, the directory it was loaded
## from, and returns the errors: empty when every file was written (and at once when `pools` is
## empty). Writes nothing while the catalog has errors (an event that did not load would be lost),
## for a name not in the cast, or when a pool's file no longer holds the text it was loaded with
## (changed on disk since the load: reload first). Each file is written to <file>.tmp and renamed
## over the real one, so a failed write leaves the old file whole; a written pool's `loaded` is
## its new text.
func save_dir(dir: String, pools: Array[String]) -> Array[String]:
	if pools.is_empty():
		return []
	var refused: Array[String] = []
	if not errors.is_empty():
		refused.append("not saved: the story has %d errors (an event that did not load would be lost)" % errors.size())
	for id in pools:
		if not cast.has(id):
			refused.append("%s.txt: not saved: not in the cast (%s)" % [id, CAST_FILE])
		elif _on_disk(dir, id) != str(loaded.get(id, "")):
			refused.append("%s.txt: not saved: changed on disk since load: reload first" % id)
	if not refused.is_empty():
		return refused
	var failed: Array[String] = []
	for id in pools:
		var text := text_of(id)
		var problem := _write_file(dir.path_join("%s.txt" % id), text)
		if problem == "":
			loaded[id] = text
		else:
			failed.append(problem)
	return failed


## The pool's file in `dir` as it is now, "" when there is none.
static func _on_disk(dir: String, id: String) -> String:
	var path := dir.path_join("%s.txt" % id)
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## Writes `text` to `path` through `<path>.tmp` and a rename: "" when it is there, else the error
## (the temporary file removed, the old file untouched). The rename is atomic on macOS and Linux;
## on Windows Godot removes the target first.
static func _write_file(path: String, text: String) -> String:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "%s: not saved (%s)" % [path, error_string(FileAccess.get_open_error())]
	var stored := file.store_string(text)
	var error := file.get_error()
	file.close()
	if not stored or error != OK:
		DirAccess.remove_absolute(temporary)
		return "%s: not saved (%s)" % [path, error_string(error if error != OK else FAILED)]
	var renamed := DirAccess.rename_absolute(temporary, path)
	if renamed != OK:
		DirAccess.remove_absolute(temporary)
		return "%s: not saved (%s)" % [path, error_string(renamed)]
	return ""


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


## Every cast pool's text as given ("" for none): what its file held at the load.
func _remember_loaded(pools: Dictionary) -> void:
	for id: String in cast:
		loaded[id] = str(pools.get(id, ""))


func _build(cast_data: Dictionary, flags_text: String, pools: Dictionary) -> void:
	_cast_data = cast_data
	_flags_text = flags_text
	texts = pools.duplicate()
	_load_cast(cast_data)
	_load_flags(flags_text)
	var parsed: Array[StoryEvent] = []
	var known := {}  # every id a pool defines, loaded or not
	for id: String in cast:
		if pools.has(id):
			var result := StoryScript.parse(pools[id], id)
			errors.append_array(result["errors"])
			warnings.append_array(result["warnings"])
			headers[id] = result["header"]
			footers[id] = result["footer"]
			parsed.append_array(result["events"])
			for dropped: String in result["dropped"]:
				known[dropped] = true
	for id: Variant in pools:
		if not cast.has(id) and not cast_data.has(id):
			errors.append("%s.txt: not in the cast (%s)" % [id, CAST_FILE])
	for event: StoryEvent in parsed:
		known[event.id] = true
	_defined = known
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
		elif entry.has("silhouette") and not entry["silhouette"] is bool:
			errors.append("%s: '%s': silhouette is true or false" % [CAST_FILE, id])
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
				var text := StoryScript.strip_marker(entry["text"])
				if text.length() > CHOICE_TEXT_CAP:
					found.append(_at(event, entry["line"], "a choice over %d characters (%d)" % [CHOICE_TEXT_CAP, text.length()]))
				found.append_array(_check_text(event, entry, context))
				found.append_array(_check_effects(event, entry["effects"]))
				for line: Dictionary in entry["lines"]:
					if line["kind"] == "line":
						found.append_array(_check_line(event, line, context, timed))
			"line":
				if entry["when"] == null:  # a line that may be dropped leaves the runs either side of it one run
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


## The presets in the acts file's text ("" or blanks: none), each checked; see `acts`.
func _load_acts(text: String) -> void:
	if text.strip_edges() == "":
		return
	var json := JSON.new()
	if json.parse(text) != OK:  # JSON counts its lines from 0
		errors.append("%s:%d: %s" % [ACTS_FILE, json.get_error_line() + 1, json.get_error_message()])
		return
	if not json.data is Dictionary:
		errors.append("%s: not an object of acts (%s)" % [ACTS_FILE, _acts_list()])
		return
	for key: Variant in json.data:
		var act := int(key) if StoryCondition.is_integer(str(key)) else 0
		if not act in PRESET_ACTS:
			errors.append("%s: '%s' is not an act with a preset (%s)" % [ACTS_FILE, key, _acts_list()])
			continue
		var found: Array[String] = []
		var preset := _preset(json.data[key], found)
		for message in found:
			errors.append("%s: act %d: %s" % [ACTS_FILE, act, message])
		if found.is_empty():
			acts[act] = preset


## One act's preset, its values typed, with what is wrong with it appended to `found`.
func _preset(entry: Variant, found: Array[String]) -> Dictionary:
	var preset := {"flags": {}, "story_flags": {}, "played": []}
	if not entry is Dictionary:
		found.append("not an object (%s)" % ", ".join(PRESET_KEYS))
		return preset
	for key: Variant in entry:
		if not str(key) in PRESET_KEYS:
			found.append("unknown key '%s' (%s)" % [key, ", ".join(PRESET_KEYS)])
	for key: String in ["flags", "story_flags"]:
		var given: Variant = entry.get(key, {})
		if not given is Dictionary:
			found.append("%s: not an object" % key)
			continue
		for name: Variant in given:
			var value: Variant = _flag_value(key, str(name), given[name], found)
			if value != null:
				preset[key][str(name)] = value
	var played: Variant = entry.get("played", [])
	if not played is Array:
		found.append("played: not a list of event ids")
		return preset
	for id: Variant in played:
		if not id is String:
			found.append("played: %s is not an event id" % _json_text(id))
		elif preset["played"].has(id):
			found.append("played: '%s' twice" % id)
		elif not by_id.has(id):
			found.append("played: '%s', which did not load" % id if _defined.has(id) else "played: unknown event '%s'" % id)
		else:
			preset["played"].append(id)
	return preset


## A preset's flag value of the flag's type (an integral JSON number read as an int), or null with
## why appended to `found`: `table` is "flags" (the profile's, Save.FLAG_KEYS: a count is an
## integer, 0 or more) or "story_flags" (flags.txt's declared flags).
func _flag_value(table: String, name: String, value: Variant, found: Array[String]) -> Variant:
	var profile := table == "flags"
	var declared: Dictionary = Save.FLAG_KEYS if profile else flags
	if not declared.has(name):
		if profile:
			found.append("flags: unknown flag '%s' (the profile's: %s)" % [name, ", ".join(Save.FLAG_KEYS.keys())])
		else:
			found.append("story_flags: undeclared flag '%s' (%s)" % [name, FLAGS_FILE])
		return null
	var default: Variant = declared[name]
	var typed: Variant = null
	if default is bool:
		typed = value if value is bool else null
	elif default is int:
		typed = _json_int(value)
		if profile and typed != null and int(typed) < 0:
			typed = null
	elif value is String and StoryScript.parse_value(value) is String:
		typed = value
	if typed == null:
		var kind := "a count (an integer, 0 or more)" if profile and default is int else _kind_of(default)
		found.append("%s: '%s' is %s, set to %s" % [table, name, kind, _json_text(value)])
	return typed


## A JSON number that is an integer (JSON reads every number as a float) as an int; null for
## anything else.
static func _json_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < 9.0e15:
		return int(value)
	return null


## A JSON value as the acts file wrote it: an integral number without ".0", a string bare.
static func _json_text(value: Variant) -> String:
	var whole: Variant = _json_int(value)
	if whole != null:
		return str(whole)
	return value if value is String else JSON.stringify(value)


static func _acts_list() -> String:
	var names: Array[String] = []
	for act in PRESET_ACTS:
		names.append(str(act))
	return ", ".join(names)


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
