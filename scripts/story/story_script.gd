class_name StoryScript
extends RefCounted
## The story format's parser (docs/plans/2026-10-01-milestone-6.md, "The file format"): a pool's
## text to StoryEvents, and the flags file to the declared flags. It checks the shape of every
## line (the header keys and their values, the body's lines, choices, and effects, the conditions'
## syntax); the catalog checks what needs the other files (names, speakers, events, flags). An
## error names the file and the line ("veteran.txt:12: ...") and drops only the event it is in.
## Pure: no autoload, no Node. The writer back to text (write, write_event) lives here too.
##
## Comments are never lost on a parse (the writer back to text works from what this returns):
## - a line whose first non-blank character is '#' is a comment anywhere, kept as its text without
##   the '#' and the one blank after it (a writer emits "# " + text, so "#x" comes back "# x");
## - the file's header: the first comment block, at the top before any event, followed by a blank
##   line (`header`, its lines joined by newlines);
## - a block before an event (directly above its `==`, or across blank lines) is the event's
##   `comment` (the blank lines are not kept);
## - a comment among an event's header keys (before the blank line that ends the header) is one
##   of its `header_notes`;
## - a comment in the body is a comment entry in place (in the open choice's lines when the
##   comment is indented under a choice), which nothing plays;
## - a block after the last event's last line is the file's `footer`.
## On an `==` line, a header line, and an effect line the rest of the line from a '#' that follows
## a blank is an inline comment: stripped, and a warning says the rewrite will drop it. In a
## speaker line's text and a choice's text a '#' is prose ("Gate #3 again").

const PRIORITIES: Array[String] = ["story", "high", "normal", "filler"]
const TRIGGERS: Array[String] = ["talk", "enter", "verdict_wait", "verdict_up", "verdict_down", "pick"]
## The rooms an `enter <room>` may name: the grounds' rooms. The room data
## (data/grounds/<room>.tres, GroundsRooms.IDS) must agree with this list; a test pins the two.
const ROOMS: Array[String] = ["ludus", "armamentarium", "hypogeum", "sanitarium", "spoliarium"]
const HEADER_KEYS: Array[String] = ["requires", "unless", "when", "priority", "trigger", "act"]
## The bare header words; `once` is the default.
const HEADER_WORDS: Array[String] = ["once", "repeat"]
## The triggers shown in the timed window are StoryCatalog.TIMED_TRIGGERS. The third seam: a later
## moment (round_start, boss_spawn, low_health) is a new row in TRIGGERS, and in TIMED_TRIGGERS
## when the timed presenter shows it.
## The effect verbs (the second seam: a later `give` or `raise` is a new row and a branch in
## StoryEvent.apply_effects).
const EFFECT_VERBS: Array[String] = ["set"]
const ACT_MAX := 3
## A placeholder line starts with this; the box never shows it (strip_marker).
const MARKER := "PLACEHOLDER"

const _NAME := "^[A-Za-z_][A-Za-z0-9_]*$"
const _CAST_ID := "^[a-z][a-z0-9_]*$"
const _EVENT_ID := "^[A-Za-z_][A-Za-z0-9_]*\\.[A-Za-z_][A-Za-z0-9_]*$"
const _SPEAKER_LINE := "^(?:\\[([^\\]]*)\\]\\s*)?([A-Z][A-Z0-9_]*)\\s*:\\s*(.*)$"
const _EFFECT_LINE := "^([a-z_]+)\\s*:(.*)$"
const _HEADER_LINE := "^([A-Za-z_][A-Za-z0-9_]*)\\s*:(.*)$"

static var _regex: Dictionary = {}


## The pool's text parsed: {"events": Array[StoryEvent] (the well-formed ones, in file order),
## "errors": Array[String] (each "<pool>.txt:<line>: ..."), "warnings": Array[String] (an inline
## comment the rewrite would drop, one per line), "dropped": Array[String] (the ids of the events
## an error left out, for the catalog's dependents), "header" and "footer" (the file's comment
## blocks, "" for none)}.
static func parse(text: String, pool: String) -> Dictionary:
	var state := _State.new(pool)
	var lines := text.split("\n")
	for i in lines.size():
		state.feed(lines[i].trim_suffix("\r"), i + 1)
	state.finish()
	return {
		"events": state.events, "errors": state.errors, "warnings": state.warnings,
		"dropped": state.dropped, "header": state.header, "footer": state.footer,
	}


## A pool's events back to text in the one canonical form, with the file's header and footer
## comment blocks (parse's `header` and `footer`): the header, a blank line, the events with a
## blank line between them, a blank line, the footer, and a newline at the end ("" for nothing at
## all). A file written by hand and one saved from the Story tab are the same thing: parse() of
## the result gives equal events, and write(parse(text)) is `text` for a canonical file. Every
## comment the parser kept is written back as "# " + its text; the inline comments it warned of
## are the only thing a rewrite drops. See write_event for one event's form.
static func write(events: Array[StoryEvent], header := "", footer := "") -> String:
	var blocks: PackedStringArray = []
	if header != "":
		blocks.append("\n".join(comment_lines(header)))
	for event in events:
		blocks.append(write_event(event))
	if footer != "":
		blocks.append("\n".join(comment_lines(footer)))
	return "\n\n".join(blocks) + "\n" if not blocks.is_empty() else ""


## One event in the canonical form, without a newline at the end: its comment directly above the
## `==` line; the header keys in the reference block's order (requires, unless, when, priority,
## repeat, trigger, act), each omitted at its default (no list, no condition, normal, once, talk,
## no act); the header notes after the keys; then, when there is a body or an end effect, a blank
## line and the body (a choice's effects, then its lines and comments, indented four spaces) and
## the end effects. A condition is written as its source (the writer's spelling, trimmed): the
## form is the layout, never a condition's wording.
static func write_event(event: StoryEvent) -> String:
	var out: PackedStringArray = comment_lines(event.comment) if event.comment != "" else PackedStringArray()
	out.append("== " + event.name)
	if not event.requires.is_empty():
		out.append("requires: " + ", ".join(event.requires))
	if not event.unless.is_empty():
		out.append("unless: " + ", ".join(event.unless))
	if event.when != null:
		out.append("when: " + event.when.source)
	if event.priority != "normal":
		out.append("priority: " + event.priority)
	if not event.once:
		out.append("repeat")
	if event.trigger != "talk":
		out.append("trigger: " + (event.trigger + " " + event.trigger_arg).strip_edges())
	if event.act != 0:
		out.append("act: %d" % event.act)
	for note in event.header_notes:
		out.append(_comment_line(note))
	var body: PackedStringArray = []
	for entry: Dictionary in event.body:
		_write_entry(entry, "", body)
	for effect: Dictionary in event.effects:
		body.append(_effect_text(effect))
	if not body.is_empty():
		out.append("")
		out.append_array(body)
	return "\n".join(out)


## A comment block's lines as written: "# " + each line of `text` ("#" alone for an empty line).
static func comment_lines(text: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	for line in text.split("\n"):
		lines.append(_comment_line(line))
	return lines


## True for a name's shape (an event's name, a flag): letters, digits, '_', not starting with a
## digit.
static func is_name(text: String) -> bool:
	return _matches(_NAME, text)


static func _comment_line(text: String) -> String:
	return "# " + text if text != "" else "#"


## A body entry (a line, a choice, a comment) as written, with `indent` before each of its lines.
static func _write_entry(entry: Dictionary, indent: String, into: PackedStringArray) -> void:
	match entry["kind"]:
		"line":
			var when: StoryCondition = entry["when"]
			var gate := "[%s] " % when.source if when != null else ""
			into.append("%s%s%s: %s" % [indent, gate, str(entry["speaker"]).to_upper(), entry["text"]])
		"comment":
			into.append(indent + _comment_line(entry["text"]))
		"choice":
			into.append(indent + "? " + str(entry["text"]))
			for effect: Dictionary in entry["effects"]:
				into.append(indent + "    " + _effect_text(effect))
			for line: Dictionary in entry["lines"]:
				_write_entry(line, indent + "    ", into)


## An effect as written: `set: flag` for true (the bare form), else `set: flag = value`.
static func _effect_text(effect: Dictionary) -> String:
	var value: Variant = effect["value"]
	if value is bool and value:
		return "%s: %s" % [effect["verb"], effect["flag"]]
	return "%s: %s = %s" % [effect["verb"], effect["flag"], str(value)]


## The flags file: {"flags": name -> default (false for a bare name, else the value's type),
## "lines": name -> line, "errors": Array[String]}.
static func parse_flags(text: String, file := "flags.txt") -> Dictionary:
	var flags := {}
	var lines_of := {}
	var errors: Array[String] = []
	var lines := text.split("\n")
	for i in lines.size():
		var line := strip_comment(lines[i].trim_suffix("\r"))
		if line == "":
			continue
		var name := line
		var value: Variant = false
		var eq := line.find("=")
		if eq >= 0:
			name = line.left(eq).strip_edges()
			value = parse_value(line.substr(eq + 1).strip_edges())
		if not _matches(_NAME, name):
			errors.append(_at(file, i + 1, "'%s' is not a flag ('name' or 'name = value')" % line))
		elif typeof(value) == TYPE_NIL:
			errors.append(_at(file, i + 1, "'%s' is not a value (an integer, true, false, or a word)" % line.substr(eq + 1).strip_edges()))
		elif flags.has(name):
			errors.append(_at(file, i + 1, "flag '%s' twice" % name))
		else:
			flags[name] = value
			lines_of[name] = i + 1
	return {"flags": flags, "lines": lines_of, "errors": errors}


## A literal: an integer, true or false, or a bare word (a name's shape); null for anything else.
static func parse_value(text: String) -> Variant:
	if StoryCondition.is_integer(text):
		return int(text)
	if text == "true" or text == "false":
		return text == "true"
	return text if _matches(_NAME, text) else null


## The effect on a line ("verb: argument", its inline comment already stripped): an effect entry
## (StoryEvent.effect_entry) at `at`, or {"error"}.
static func parse_effect(line: String, at := 0) -> Dictionary:
	var m := _re(_EFFECT_LINE).search(line)
	if m == null:
		return {"error": "'%s' is not an effect ('verb: argument')" % line}
	var verb := m.get_string(1)
	if not verb in EFFECT_VERBS:
		return {"error": "unknown effect '%s' (the verbs: %s)" % [verb, ", ".join(EFFECT_VERBS)]}
	var argument := m.get_string(2).strip_edges()
	if argument == "":
		return {"error": "set needs a flag"}
	var flag := argument
	var value: Variant = true
	var eq := argument.find("=")
	if eq >= 0:
		flag = argument.left(eq).strip_edges()
		var raw := argument.substr(eq + 1).strip_edges()
		value = parse_value(raw)
		if typeof(value) == TYPE_NIL:
			return {"error": "'%s' is not a value (an integer, true, false, or a word)" % raw}
	if not _matches(_NAME, flag):
		return {"error": "'%s' is not 'set: flag' or 'set: flag = value'" % argument}
	return StoryEvent.effect_entry(verb, flag, value, at)


## The text without its leading placeholder marker (and the space after it).
static func strip_marker(text: String) -> String:
	if text == MARKER:
		return ""
	return text.substr(MARKER.length() + 1) if text.begins_with(MARKER + " ") else text


## The line without its comment and its outer blanks: "" for a blank or a comment line. For the
## lines that may carry an inline comment (`==`, a header, an effect, the flags file), never for
## a speaker line's or a choice's text.
static func strip_comment(line: String) -> String:
	var stripped := line.strip_edges()
	if stripped.begins_with("#"):
		return ""
	for i in range(1, stripped.length()):
		if stripped[i] == "#" and (stripped[i - 1] == " " or stripped[i - 1] == "\t"):
			return stripped.left(i).strip_edges()
	return stripped


## True for a cast id's shape (cast.json's keys, the pools' file names): lowercase letters,
## digits, '_', starting with a letter.
static func is_cast_id(text: String) -> bool:
	return _matches(_CAST_ID, text)


## A full-line comment's text: the line without its '#' and the one blank after it.
static func comment_text(trimmed: String) -> String:
	var text := trimmed.substr(1)
	return text.substr(1) if text.begins_with(" ") else text


static func _at(file: String, line: int, message: String) -> String:
	return "%s:%d: %s" % [file, line, message]


static func _re(pattern: String) -> RegEx:
	if not _regex.has(pattern):
		_regex[pattern] = RegEx.create_from_string(pattern)
	return _regex[pattern]


static func _matches(pattern: String, text: String) -> bool:
	return _re(pattern).search(text) != null


## The parser's state through one file, a line at a time.
class _State:
	var pool: String
	var file: String
	var events: Array[StoryEvent] = []
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var dropped: Array[String] = []
	var header := ""
	var footer := ""
	var event: StoryEvent = null
	## The current event had an error: it is dropped at its close.
	var bad := false
	var in_header := false
	## True until the file's header is taken or an event or a content line comes first.
	var header_open := true
	## The comment lines not yet placed: {"text", "line", "indented"}. The next line that is not a
	## comment or a blank decides where they go (a blank decides at the top and in a header).
	var pending: Array[Dictionary] = []
	## The current choice's entry ({} outside one).
	var choice: Dictionary = {}
	## An unindented effect was read: the body is over.
	var ended := false

	func _init(pool_id: String) -> void:
		pool = pool_id
		file = pool_id + ".txt"

	func error(line: int, message: String) -> void:
		errors.append(StoryScript._at(file, line, message))
		if event != null:
			bad = true

	func close_event() -> void:
		if event != null:
			if not bad:
				events.append(event)
			elif StoryScript._matches(StoryScript._NAME, event.name):
				dropped.append(event.id)
		event = null
		bad = false

	## The end of the file: a block left after the last line is the footer.
	func finish() -> void:
		footer = _take_pending()
		close_event()

	func feed(raw: String, n: int) -> void:
		var trimmed := raw.strip_edges()
		var indented := raw != "" and (raw[0] == " " or raw[0] == "\t")
		if trimmed.begins_with("#"):
			pending.append({"text": StoryScript.comment_text(trimmed), "line": n, "indented": indented})
			return
		if trimmed == "":
			_blank()
			return
		if trimmed.begins_with("=="):
			header_open = false
			var comment := _take_pending()
			_open(_inline(trimmed, n).substr(2).strip_edges(), n, comment)
			return
		header_open = false
		if event == null:
			error(n, "a line outside an event (an event starts with '== name')")
		elif in_header:
			for note: Dictionary in pending:
				event.header_notes.append(note["text"])
			pending.clear()
			_header(_inline(trimmed, n), n)
		else:
			_body(trimmed, n, indented)

	## A blank line: it takes the file's header at the top, and ends an event's header (the
	## comments among its keys become its notes). In a body it decides nothing.
	func _blank() -> void:
		if event == null:
			if header_open and not pending.is_empty():
				header = _take_pending()
				header_open = false
		elif in_header:
			for note: Dictionary in pending:
				event.header_notes.append(note["text"])
			pending.clear()
			in_header = false

	## The pending comments' texts, one a line, and the pending list cleared.
	func _take_pending() -> String:
		var texts: PackedStringArray = []
		for c: Dictionary in pending:
			texts.append(c["text"])
		pending.clear()
		return "\n".join(texts)

	## The line without its inline comment, warned of: the writer back to text cannot keep it.
	func _inline(trimmed: String, n: int) -> String:
		var stripped := StoryScript.strip_comment(trimmed)
		if stripped != trimmed:
			warnings.append(StoryScript._at(file, n, "an inline comment is dropped when the file is rewritten: put it on its own line"))
		return stripped

	func _open(name: String, n: int, comment: String) -> void:
		close_event()
		event = StoryEvent.new()
		event.pool = pool
		event.name = name
		event.id = pool + "." + name
		event.line_number = n
		event.comment = comment
		in_header = true
		choice = {}
		ended = false
		if name == "":
			error(n, "an event with no name")
		elif not StoryScript._matches(StoryScript._NAME, name):
			error(n, "'%s' is not a name (letters, digits, '_')" % name)

	func _header(line: String, n: int) -> void:
		if line in StoryScript.HEADER_WORDS:
			if event.header_line.has("repeat"):
				error(n, "'%s' twice: an event is once or repeat" % line)
				return
			event.header_line["repeat"] = n
			event.once = line == "once"
			return
		var m := StoryScript._re(StoryScript._HEADER_LINE).search(line)
		if m == null:
			error(n, "'%s' is not a header line ('key: value', 'once', or 'repeat')" % line)
			return
		var key := m.get_string(1)
		var value := m.get_string(2).strip_edges()
		if not key in StoryScript.HEADER_KEYS:
			if StoryScript._matches("^[A-Z][A-Z0-9_]*$", key):
				error(n, "a body line in the header: a blank line ends the header")
			else:
				error(n, "unknown header key '%s' (the keys: %s, once, repeat)" % [key, ", ".join(StoryScript.HEADER_KEYS)])
			return
		if event.header_line.has(key):
			error(n, "'%s' twice" % key)
			return
		event.header_line[key] = n
		match key:
			"requires", "unless":
				var ids: Array[String] = []
				for part: String in value.split(","):
					var id := part.strip_edges()
					if id == "":
						continue
					if not StoryScript._matches(StoryScript._EVENT_ID, id):
						error(n, "'%s' is not an event id (pool.name)" % id)
						return
					if ids.has(id):
						error(n, "'%s' twice in %s" % [id, key])
						return
					ids.append(id)
				if key == "requires":
					event.requires = ids
				else:
					event.unless = ids
			"when":
				var parsed := StoryCondition.parse(value)
				if parsed["condition"] == null:
					error(n, "when: " + str(parsed["error"]))
				else:
					event.when = parsed["condition"]
			"priority":
				if not value in StoryScript.PRIORITIES:
					error(n, "unknown priority '%s' (%s)" % [value, ", ".join(StoryScript.PRIORITIES)])
				else:
					event.priority = value
			"trigger":
				_trigger(value, n)
			"act":
				if not StoryCondition.is_integer(value):
					error(n, "act '%s' is not a number (1 to %d)" % [value, StoryScript.ACT_MAX])
				elif int(value) < 1 or int(value) > StoryScript.ACT_MAX:
					error(n, "act %s is not 1 to %d" % [value, StoryScript.ACT_MAX])
				else:
					event.act = int(value)

	## The trigger and its argument, split on any blanks (a tab is a blank).
	func _trigger(value: String, n: int) -> void:
		var parts: Array[String] = []
		for m: RegExMatch in StoryScript._re("\\S+").search_all(value):
			parts.append(m.get_string())
		var trigger := parts[0] if parts.size() > 0 else ""
		var arg := " ".join(parts.slice(1))
		if not trigger in StoryScript.TRIGGERS:
			error(n, "unknown trigger '%s' (%s)" % [trigger, ", ".join(StoryScript.TRIGGERS)])
		elif trigger == "enter" and arg == "":
			error(n, "'enter' needs a room (%s)" % ", ".join(StoryScript.ROOMS))
		elif trigger == "enter" and not arg in StoryScript.ROOMS:
			error(n, "unknown room '%s' (%s)" % [arg, ", ".join(StoryScript.ROOMS)])
		elif trigger != "enter" and arg != "":
			error(n, "'%s' takes no argument" % trigger)
		else:
			event.trigger = trigger
			event.trigger_arg = arg

	func _body(line: String, n: int, indented: bool) -> void:
		for c: Dictionary in pending:
			var into: Array = choice["lines"] if c["indented"] and not choice.is_empty() else event.body
			into.append(StoryEvent.comment_entry(c["text"], c["line"]))
		pending.clear()
		if line.begins_with("?"):
			var text := line.substr(1).strip_edges()
			if indented:
				error(n, "a nested choice: a choice has no choices")
			elif ended:
				error(n, "a line after the event's end effects")
			elif text == "":
				error(n, "a choice with no text")
			else:
				choice = StoryEvent.choice_entry(text, n)
				event.body.append(choice)
			return
		var is_effect := StoryScript._matches(StoryScript._EFFECT_LINE, line)
		if indented:
			if choice.is_empty():
				error(n, "an indented line outside a choice")
			elif is_effect:
				_effect(line, n, choice["effects"])
			else:
				_line(line, n, choice["lines"])
			return
		choice = {}
		if is_effect:
			ended = true
			_effect(line, n, event.effects)
		elif ended:
			error(n, "a line after the event's end effects")
		else:
			_line(line, n, event.body)

	## An effect line may carry an inline comment (a speaker line's text may not: see the top).
	func _effect(line: String, n: int, into: Array) -> void:
		var effect := StoryScript.parse_effect(_inline(line, n), n)
		if effect.has("error"):
			error(n, effect["error"])
			return
		into.append(effect)

	func _line(line: String, n: int, into: Array) -> void:
		var m := StoryScript._re(StoryScript._SPEAKER_LINE).search(line)
		if m == null:
			error(n, "'%s' is not a body line ('SPEAKER: text', '? choice', or 'verb: argument')" % line)
			return
		var text := m.get_string(3).strip_edges()
		if text == "":
			error(n, "a line with no text")
			return
		var when: StoryCondition = null
		if m.get_start(1) >= 0:
			var parsed := StoryCondition.parse(m.get_string(1))
			if parsed["condition"] == null:
				error(n, "[%s]: %s" % [m.get_string(1), parsed["error"]])
				return
			when = parsed["condition"]
		into.append(StoryEvent.line_entry(m.get_string(2).to_lower(), text, when, n))
