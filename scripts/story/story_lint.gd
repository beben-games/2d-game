class_name StoryLint
extends RefCounted
## What the story's load accepts but the game would never show, or should not say: the writer's
## warnings (M6 Task 15), beside the catalog's errors. Never an error: a warning is something to
## look at; the catalog's errors are the only thing that stops a story. Read by tools/story_lint.sh,
## the Story tab (a badge on the event, a line in its list), and tests/test_story_data.gd (the
## shipped story lints clean). Pure: the story is the StoryCatalog handed in, and what the lint needs
## of the game (the stations' keepers, the enemy ids, what a door's condition reads) is handed in as
## data (StoryLintInputs gathers it from the project); it reads no file and names no autoload or Node.
##
## Only the events that loaded are linted (one left out has its errors). Each warning is
## {"kind", "event", "message"}: `event` the event's id ("" for none), `message` headed by
## "<pool>.txt:<line>: " where a line is at hand and "<event id>: " otherwise (the heads
## StoryGraph.target_of places), or "<pool>.txt: " / "flags.txt: " for a finding on no event. The
## kinds, in the order run() checks them:
## - PARSE: the catalog's warnings (an inline comment a rewrite drops), surfaced as they are.
## - NEVER_ASKED: an event at a trigger its pool is never asked at (StoryExplain.asks: a veteran
##   verdict_up, a narrator talk).
## - MERCHANT_FILLER: a talk filler of a station's keeper who stands nowhere else: a kept station with
##   nothing new opens its panel (Main._on_interacted plays only an event that uses the turn).
## - NEVER_FIRES: an event that requires an event it also has in its unless, or requires one that
##   never plays (any of these three kinds, to a fixed point).
## - MOMENT_FACT: a moment's fact (arrival, run_band, round_band, round_loss) read by an event at a
##   trigger the game never hands it in at (StoryExplain.FACTS): it is always none there.
## - KILLER: last_killer compared with a word that is no enemy's id (nor none); only when the enemy
##   ids are handed in.
## - TIMED_LINES: a line of a timed event after a line with no condition: the window shows only the
##   first line shown.
## - ENTER_CLASH: two `enter <room>` events of one room in different pools without each in the
##   other's unless, whose arrivals can meet (StoryCondition.words_held on their whens: two that
##   can never hold at one arrival never compete): one plays per arrival, so the other plays on a
##   later arrival (a door walk).
## - ENTER_REPEAT: a repeat `enter` event whose when does not provably fail at a door walk (the
##   arrivals words_held allows include door): it plays on every arrival.
## - FLAG_UNREAD, FLAG_UNSET, FLAG_UNUSED: a declared flag set and never read (a warning per setter),
##   read and never set (per reader, at its first reading line), or neither. Only for a story with
##   no error (an event that did not load may set or read a flag): `flags_checked` says which.
## - WORD: a line or a choice holding an entry of the word list, its {substitutions} and the
##   PLACEHOLDER marker not the line's prose. Two forms (word_pattern): a plain entry (a word or a
##   phrase: a term never in the world's voice) matches as whole words, any case, a phrase's blank
##   any run of blanks, a word's letters those of any script; a `key: <name>` entry (a key's or an
##   input's name) matches only in an instruction frame (KEY_FRAMES: "press E", "the E key", "use the
##   mouse to"). One warning a line per match's text. A false positive is silenced by editing the
##   list (data/story/lint_words.txt), never by a mark in the prose.
## - PICK_UNANSWERED: a band and loss at the pick (four bands by four losses) that no event of a pool
##   asked at the pick (StoryExplain.ASKED, the crowd) always answers: a repeat `pick` event with no
##   requires or unless whose when reads only the pick's facts and holds there, with a line shown
##   there (one with no condition, or one reading only the pick's facts that holds). One warning
##   when no case is answered.
##
## The flag map: every declared flag, in flags.txt's order, -> {"set": the ids of the events whose
## effects set it, "read": the ids of the events that read it (a when, a line's condition, a
## {substitution}), then the game's readers handed in (a door's condition)}, each once.

const PARSE := "parse"
const NEVER_ASKED := "never_asked"
const MERCHANT_FILLER := "merchant_filler"
const NEVER_FIRES := "never_fires"
const MOMENT_FACT := "moment_fact"
const KILLER := "killer"
const TIMED_LINES := "timed_lines"
const ENTER_CLASH := "enter_clash"
const ENTER_REPEAT := "enter_repeat"
const FLAG_UNREAD := "flag_unread"
const FLAG_UNSET := "flag_unset"
const FLAG_UNUSED := "flag_unused"
const WORD := "word"
const PICK_UNANSWERED := "pick_unanswered"
const KINDS: Array[String] = [PARSE, NEVER_ASKED, MERCHANT_FILLER, NEVER_FIRES, MOMENT_FACT, KILLER, TIMED_LINES, ENTER_CLASH, ENTER_REPEAT, FLAG_UNREAD, FLAG_UNSET, FLAG_UNUSED, WORD, PICK_UNANSWERED]
## The word list's file in the story's directory (not a pool: the catalog reads pools by cast id).
const WORDS_FILE := "lint_words.txt"
const KILLER_NAME := "last_killer"
const ENTER := "enter"
const PICK := "pick"
## The arrival of a door walk (StoryContext.WORDS["arrival"]).
const DOOR_ARRIVAL := "door"
const ARRIVAL := "arrival"
## A word list entry naming a key or an input: "key: <name>".
const KEY_PREFIX := "key:"
## The instruction frames a `key:` entry matches in, `%s` the key names (any of them): a verb of
## pressing before it ("press E", "hit the Space"), the word key or button after it ("the E key"),
## or a use of it for something ("use the mouse to", "with the mouse to"). Blanks are any run of
## blanks; a frame matches as whole words, any case. A new frame is a row here.
const KEY_FRAMES: Array[String] = [
	"(?:press|hit|tap|hold|push|click)\\s+(?:the\\s+)?%s",
	"%s\\s+(?:key|button)",
	"(?:use|with)\\s+(?:the\\s+)?%s\\s+to",
]
## A word's letters for whole-word matching: a letter or digit of any script, or '_'.
const WORD_CHAR := "[\\p{L}\\p{N}_]"


## The lint of the catalog: {"errors": the catalog's errors, "warnings": the findings in the order
## above, "flag_map", "flags_checked": false when the flag rules waited for a story with no error,
## "placeholders": the lines and choices still marked PLACEHOLDER, "texts": every line and choice}. `words`: the word list (parse_words). `game`: what the lint knows of the game,
## each key optional: "merchants" (the cast ids of the stations' keepers who stand nowhere else),
## "enemies" (every enemy id: last_killer's words; absent, unchecked), "reads" (a reader outside
## the story, such as "door ludus -> hypogeum", -> the names its condition reads).
static func run(catalog: StoryCatalog, words: Array[String], game: Dictionary = {}) -> Dictionary:
	var warnings: Array[Dictionary] = []
	var reads := {}  # id -> [[name, line], ...]
	for event in catalog.events:
		reads[event.id] = _reads(event)
	_parse_warnings(catalog, warnings)
	_never_plays(catalog, game, warnings)
	_moment_facts(catalog, reads, warnings)
	_killers(catalog, game, warnings)
	_timed_lines(catalog, warnings)
	_entries(catalog, warnings)
	var flag_map := _flag_map(catalog, reads, game)
	var flags_checked := catalog.errors.is_empty()
	if flags_checked:
		_flags(catalog, flag_map, reads, warnings)
	_words(catalog, words, warnings)
	_pick(catalog, warnings)
	var placeholders := 0
	var texts := 0
	for event in catalog.events:
		for text: Array in _texts(event):
			texts += 1
			if str(text[0]).begins_with(StoryScript.MARKER):
				placeholders += 1
	return {
		"errors": catalog.errors.duplicate(),
		"warnings": warnings,
		"flag_map": flag_map,
		"flags_checked": flags_checked,
		"placeholders": placeholders,
		"texts": texts,
	}


## The word list from its file's text: an entry a line, `#` to the end of a line a comment, blanks
## around ignored and a run of blanks inside one blank, lower case, each once; a key's entry written
## "key: <name>".
static func parse_words(text: String) -> Array[String]:
	var out: Array[String] = []
	for raw in text.split("\n"):
		var entry := _collapse(raw.get_slice("#", 0).to_lower())
		if entry.begins_with(KEY_PREFIX):
			var key := _collapse(entry.substr(KEY_PREFIX.length()))
			entry = KEY_PREFIX + " " + key if key != "" else ""
		if entry != "" and not out.has(entry):
			out.append(entry)
	return out


static func _collapse(text: String) -> String:
	return " ".join(text.replace("\t", " ").split(" ", false))


# --- the checks ---------------------------------------------------------------------------------

static func _parse_warnings(catalog: StoryCatalog, out: Array[Dictionary]) -> void:
	for message in catalog.warnings:
		out.append(_finding(PARSE, _event_at(catalog, message), message))


## NEVER_ASKED, MERCHANT_FILLER, then NEVER_FIRES to a fixed point.
static func _never_plays(catalog: StoryCatalog, game: Dictionary, out: Array[Dictionary]) -> void:
	var dead := {}
	for event in catalog.events:
		if not StoryExplain.asks(catalog, event.trigger, event.pool):
			dead[event.id] = true
			out.append(_finding(NEVER_ASKED, event.id, "%s: never plays: %s" % [event.id, StoryExplain.never_asked(event.trigger, event.pool)]))
	var merchants: Array = game.get("merchants", [])
	for event in catalog.events:
		if not dead.has(event.id) and merchants.has(event.pool) and event.trigger == StoryExplain.TALK and event.priority == "filler":
			dead[event.id] = true
			out.append(_finding(MERCHANT_FILLER, event.id, "%s: never plays: %s keeps a station, which opens its panel when they have nothing new" % [event.id, event.pool]))
	for event in catalog.events:
		if dead.has(event.id):
			continue
		for id in event.requires:
			if event.unless.has(id):
				dead[event.id] = true
				out.append(_finding(NEVER_FIRES, event.id, "%s: never plays: it requires %s and has it in its unless" % [event.id, id]))
				break
	var changed := true
	while changed:
		changed = false
		for event in catalog.events:
			if dead.has(event.id):
				continue
			for id in event.requires:
				if dead.has(id):
					dead[event.id] = true
					changed = true
					out.append(_finding(NEVER_FIRES, event.id, "%s: never plays: it requires %s, which never plays" % [event.id, id]))
					break


static func _moment_facts(catalog: StoryCatalog, reads: Dictionary, out: Array[Dictionary]) -> void:
	for event in catalog.events:
		var handed: Array = StoryExplain.FACTS.get(event.trigger, [])
		var seen := {}
		for read: Array in reads[event.id]:
			var name: String = read[0]
			var key := "%s@%d" % [name, read[1]]
			if not name in StoryContext.MOMENT_FACTS or handed.has(name) or seen.has(key):
				continue
			seen[key] = true
			out.append(_finding(MOMENT_FACT, event.id, _at(event, read[1], "reads %s, which the game hands in only at %s: at %s it is none" % [name, ", ".join(_handing(name)), event.trigger])))


static func _killers(catalog: StoryCatalog, game: Dictionary, out: Array[Dictionary]) -> void:
	if not game.has("enemies"):
		return
	var enemies: Array = game["enemies"]
	var known := PackedStringArray(enemies)
	for event in catalog.events:
		for found: Array in _conditions(event):
			for word in (found[0] as StoryCondition).compared_words(KILLER_NAME):
				if word != StoryContext.NONE and not enemies.has(word):
					out.append(_finding(KILLER, event.id, _at(event, found[1], "%s is compared with %s, which is no enemy's id (%s)" % [KILLER_NAME, word, ", ".join(known)])))


static func _timed_lines(catalog: StoryCatalog, out: Array[Dictionary]) -> void:
	for event in catalog.events:
		if not catalog.is_timed(event):
			continue
		var always := 0  # the line of the first line with no condition
		for entry: Dictionary in event.body:
			if entry["kind"] != "line":
				continue
			if always > 0:
				out.append(_finding(TIMED_LINES, event.id, _at(event, entry["line"], "never shown: a timed event shows only its first shown line, and the line at %d always shows" % always)))
			elif entry["when"] == null:
				always = entry["line"]


## ENTER_CLASH (on the later of each pair, by the catalog's order), then ENTER_REPEAT.
static func _entries(catalog: StoryCatalog, out: Array[Dictionary]) -> void:
	var entries: Array[StoryEvent] = []
	for event in catalog.events:
		if event.trigger == ENTER:
			entries.append(event)
	for j in entries.size():
		var later := entries[j]
		for i in j:
			var first := entries[i]
			if first.trigger_arg != later.trigger_arg or first.pool == later.pool:
				continue
			if first.unless.has(later.id) and later.unless.has(first.id):
				continue
			if not _arrivals(first).any(func(word: String) -> bool: return _arrivals(later).has(word)):
				continue
			out.append(_finding(ENTER_CLASH, later.id, "%s: enter %s, as %s is: without each in the other's unless, one plays on an arrival and the other on a later one" % [later.id, later.trigger_arg, first.id]))
	for event in entries:
		if event.once or not _arrivals(event).has(DOOR_ARRIVAL):
			continue
		out.append(_finding(ENTER_REPEAT, event.id, "%s: repeat on enter %s: it plays on every arrival there, door walks included" % [event.id, event.trigger_arg]))


## The arrivals the event's when can hold at (StoryCondition.words_held); all of them with no when.
static func _arrivals(event: StoryEvent) -> Array[String]:
	var words: Array = StoryContext.WORDS[ARRIVAL]
	if event.when == null:
		var all: Array[String] = []
		all.assign(words)
		return all
	return event.when.words_held(ARRIVAL, words)


static func _flag_map(catalog: StoryCatalog, reads: Dictionary, game: Dictionary) -> Dictionary:
	var map := {}
	for flag: String in catalog.flags:
		map[flag] = {"set": [] as Array[String], "read": [] as Array[String]}
	for event in catalog.events:
		for flag in StoryLinks.sets(event):
			_add_once(map, flag, "set", event.id)
		for read: Array in reads[event.id]:
			_add_once(map, read[0], "read", event.id)
	var outside: Dictionary = game.get("reads", {})
	for reader: String in outside:
		for name: String in outside[reader]:
			_add_once(map, name, "read", reader)
	return map


static func _flags(catalog: StoryCatalog, map: Dictionary, reads: Dictionary, out: Array[Dictionary]) -> void:
	for flag: String in map:
		var setters: Array[String] = map[flag]["set"]
		var readers: Array[String] = map[flag]["read"]
		if readers.is_empty() and not setters.is_empty():
			for id in setters:
				out.append(_finding(FLAG_UNREAD, id, "%s: sets %s, which nothing reads" % [id, flag]))
	for flag: String in map:
		var setters: Array[String] = map[flag]["set"]
		var readers: Array[String] = map[flag]["read"]
		if setters.is_empty() and not readers.is_empty():
			for id in readers:
				var event: StoryEvent = catalog.by_id.get(id)
				var tail := "reads %s, which nothing sets (it is always %s)" % [flag, str(catalog.flags[flag])]
				if event == null:
					out.append(_finding(FLAG_UNSET, "", "%s: %s" % [id, tail]))
				else:
					out.append(_finding(FLAG_UNSET, id, _at(event, _first_reading(reads[id], flag), tail)))
	for flag: String in map:
		if (map[flag]["set"] as Array).is_empty() and (map[flag]["read"] as Array).is_empty():
			out.append(_finding(FLAG_UNUSED, "", "%s: %s is declared, and nothing sets or reads it" % [StoryCatalog.FLAGS_FILE, flag]))


static func _words(catalog: StoryCatalog, words: Array[String], out: Array[Dictionary]) -> void:
	var pattern := word_pattern(words)
	if pattern == null:
		return
	for event in catalog.events:
		for text: Array in _texts(event):
			var said := {}
			for found in pattern.search_all(prose(text[0])):
				var word := found.get_string()
				var normal := _collapse(word.to_lower())
				if said.has(normal):
					continue
				said[normal] = true
				var what := "a key's name" if found.get_string("key") != "" else "a word"
				out.append(_finding(WORD, event.id, _at(event, text[1], "says '%s', %s on the lint list" % [word, what])))


## A line's or a choice's text as the word list reads it: the PLACEHOLDER marker stripped and each
## {substitution} a blank (its name is no prose).
static func prose(text: String) -> String:
	var out := StoryScript.strip_marker(text)
	var open := out.find("{")
	while open >= 0:
		var close := out.find("}", open + 1)
		if close < 0:
			break
		out = out.left(open) + " " + out.substr(close + 1)
		open = out.find("{", open + 1)
	return out


## One regex for the list, the longer entries first within each form: the key entries in their
## frames (KEY_FRAMES, the match's group "key") before the plain entries (group "plain"), each as
## whole words (no letter of any script either side), any case, a phrase's blank any run of blanks.
## null for an empty list.
static func word_pattern(words: Array[String]) -> RegEx:
	var plain: Array[String] = []
	var keys: Array[String] = []
	for entry in words:
		if entry.begins_with(KEY_PREFIX):
			keys.append(entry.substr(KEY_PREFIX.length()).strip_edges())
		else:
			plain.append(entry)
	var forms: PackedStringArray = []
	if not keys.is_empty():
		var names := _alternatives(keys)
		var frames: PackedStringArray = []
		for frame in KEY_FRAMES:
			frames.append(frame % names)
		forms.append("(?<key>%s)" % "|".join(frames))
	if not plain.is_empty():
		forms.append("(?<plain>%s)" % _alternatives(plain))
	if forms.is_empty():
		return null
	return RegEx.create_from_string("(?i)(?<!%s)(?:%s)(?!%s)" % [WORD_CHAR, "|".join(forms), WORD_CHAR])


## "(?:a\\s+b|c)": the entries as one group, the longer first, a blank any run of blanks.
static func _alternatives(entries: Array[String]) -> String:
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var alternatives: PackedStringArray = []
	for entry: String in sorted:
		var parts: PackedStringArray = []
		for part in entry.split(" ", false):
			parts.append(_escape(part))
		alternatives.append("\\s+".join(parts))
	return "(?:%s)" % "|".join(alternatives)


static func _pick(catalog: StoryCatalog, out: Array[Dictionary]) -> void:
	var facts: Array = StoryExplain.FACTS[PICK]
	var bands: Array[String] = []
	for band: String in StoryContext.WORDS["round_band"]:
		if band != StoryContext.NONE:
			bands.append(band)
	var losses: Array = StoryContext.WORDS["round_loss"]
	for pool: String in StoryExplain.ASKED.get(PICK, []):
		if not catalog.cast.has(pool):
			continue
		var sure: Array[StoryEvent] = []
		for event in catalog.pool(pool):
			if event.trigger == PICK and not event.once and event.requires.is_empty() and event.unless.is_empty() and _reads_only(event.when, facts):
				sure.append(event)
		var missing: Array[String] = []
		for band in bands:
			for loss: String in losses:
				var context := StoryContext.new(null, catalog.flags, {"round_band": band, "round_loss": loss})
				if not sure.any(func(event: StoryEvent) -> bool: return _answers(event, facts, context)):
					missing.append("round_band == %s and round_loss == %s" % [band, loss])
		if missing.size() == bands.size() * losses.size():
			out.append(_finding(PICK_UNANSWERED, "", "%s.txt: nothing always answers the pick, in any band or loss" % pool))
			continue
		for case in missing:
			out.append(_finding(PICK_UNANSWERED, "", "%s.txt: nothing always answers the pick at %s" % [pool, case]))


# --- reading an event ---------------------------------------------------------------------------

## Every name the event reads, with its line, in file order: its when (the when line), then each
## line's condition and substitutions, each choice's substitutions and its lines'. A name twice on
## one line is listed once.
static func _reads(event: StoryEvent) -> Array:
	var out: Array = []
	if event.when != null:
		_add_names(_condition_names(event.when), event.header_line.get("when", event.line_number), out)
	for entry: Dictionary in event.body:
		match entry["kind"]:
			"line":
				_add_line_reads(entry, out)
			"choice":
				_add_names(StoryContext.names_in(entry["text"]), entry["line"], out)
				for line: Dictionary in entry["lines"]:
					if line["kind"] == "line":
						_add_line_reads(line, out)
	return out


static func _add_line_reads(line: Dictionary, out: Array) -> void:
	var when: StoryCondition = line["when"]
	var names: Array[String] = _condition_names(when) if when != null else ([] as Array[String])
	names.append_array(StoryContext.names_in(line["text"]))
	_add_names(names, line["line"], out)


static func _add_names(names: Array[String], line: int, out: Array) -> void:
	var seen := {}
	for name in names:
		if not seen.has(name):
			seen[name] = true
			out.append([name, line])


## A condition's names, its left and then its right-hand names (as StoryLinks.reads).
static func _condition_names(condition: StoryCondition) -> Array[String]:
	var out := condition.names()
	for name in condition.right_names():
		if not out.has(name):
			out.append(name)
	return out


## The event's conditions with their lines: its when, then each line's [condition] in file order.
static func _conditions(event: StoryEvent) -> Array:
	var out: Array = []
	if event.when != null:
		out.append([event.when, event.header_line.get("when", event.line_number)])
	for entry: Dictionary in event.body:
		var lines: Array = entry["lines"] if entry["kind"] == "choice" else [entry]
		for line: Dictionary in lines:
			if line["kind"] == "line" and line["when"] != null:
				out.append([line["when"], line["line"]])
	return out


## Every line's and choice's text as written (the marker kept) with its line, in file order, a
## choice's lines after it.
static func _texts(event: StoryEvent) -> Array:
	var out: Array = []
	for entry: Dictionary in event.body:
		match entry["kind"]:
			"line":
				out.append([entry["text"], entry["line"]])
			"choice":
				out.append([entry["text"], entry["line"]])
				for line: Dictionary in entry["lines"]:
					if line["kind"] == "line":
						out.append([line["text"], line["line"]])
	return out


## True when the condition reads none but `names` (no condition reads nothing).
static func _reads_only(condition: StoryCondition, names: Array) -> bool:
	if condition == null:
		return true
	for name in _condition_names(condition):
		if not names.has(name):
			return false
	return true


## True when the event surely answers the pick's case: its when holds there, and a line of it shows
## there for sure (one with no condition, or one whose condition reads only the pick's facts and
## holds).
static func _answers(event: StoryEvent, facts: Array, context: StoryContext) -> bool:
	if event.when != null and not event.when.evaluate(context):
		return false
	for entry: Dictionary in event.body:
		if entry["kind"] != "line":
			continue
		var when: StoryCondition = entry["when"]
		if when == null or (_reads_only(when, facts) and when.evaluate(context)):
			return true
	return false


static func _first_reading(reads: Array, name: String) -> int:
	for read: Array in reads:
		if read[0] == name:
			return read[1]
	return 0


## The triggers the game hands the moment's fact in at (StoryExplain.FACTS), in its order.
static func _handing(name: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for trigger: String in StoryExplain.FACTS:
		if (StoryExplain.FACTS[trigger] as Array).has(name):
			out.append(trigger)
	return out


## The loaded event whose block holds a "<pool>.txt:<line>: ..." message's line, "" for none.
static func _event_at(catalog: StoryCatalog, message: String) -> String:
	var parts := message.get_slice(": ", 0).split(":")
	if parts.size() != 2 or not parts[0].ends_with(".txt") or not parts[1].is_valid_int():
		return ""
	var line := int(parts[1])
	var found := ""
	for event in catalog.pool(parts[0].trim_suffix(".txt")):
		if event.line_number > line:
			break
		found = event.id
	return found


static func _add_once(map: Dictionary, flag: String, side: String, id: String) -> void:
	if not map.has(flag):
		return
	var list: Array[String] = map[flag][side]
	if not list.has(id):
		list.append(id)


static func _escape(text: String) -> String:
	var out := ""
	for c in text:
		out += ("\\" + c) if c in "\\^$.|?*+()[]{}/-" else c
	return out


static func _finding(kind: String, event_id: String, message: String) -> Dictionary:
	return {"kind": kind, "event": event_id, "message": message}


static func _at(event: StoryEvent, line: int, message: String) -> String:
	return "%s:%d: %s" % [event.file(), line, message]
