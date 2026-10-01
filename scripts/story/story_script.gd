class_name StoryScript
extends RefCounted
## The story format's parser (docs/plans/2026-10-01-milestone-6.md, "The file format"): a pool's
## text to StoryEvents, and the flags file to the declared flags. It checks the shape of every
## line (the header keys and their values, the body's lines, choices, and effects, the conditions'
## syntax); the catalog checks what needs the other files (names, speakers, events, flags). An
## error names the file and the line ("veteran.txt:12: ...") and drops only the event it is in.
## Pure: no autoload, no Node; phase 2's writer back to text lives here too.
##
## Comments: a line whose first non-blank character is '#', or the rest of a line from a '#'
## that follows a blank (so a line's text keeps a '#' that touches a word). A block of comment
## lines directly above an `==` line (no blank between) is that event's comment.

const PRIORITIES: Array[String] = ["story", "high", "normal", "filler"]
const TRIGGERS: Array[String] = ["talk", "enter", "verdict_wait", "verdict_up", "verdict_down", "pick"]
## The rooms an `enter <room>` may name (the grounds' rooms, Task 4's GroundsRoomDefs).
const ROOMS: Array[String] = ["ludus", "armamentarium", "hypogeum", "sanitarium", "spoliarium"]
const HEADER_KEYS: Array[String] = ["requires", "unless", "when", "priority", "trigger", "act"]
## The bare header words; `once` is the default.
const HEADER_WORDS: Array[String] = ["once", "repeat"]
## The effect verbs (the second seam: a later `give` or `raise` is a new row and a branch in
## StoryEvent.apply_effects).
const EFFECT_VERBS: Array[String] = ["set"]
const ACT_MAX := 3
## A placeholder line starts with this; the box never shows it (strip_marker).
const MARKER := "PLACEHOLDER"

const _NAME := "^[A-Za-z_][A-Za-z0-9_]*$"
const _EVENT_ID := "^[A-Za-z_][A-Za-z0-9_]*\\.[A-Za-z_][A-Za-z0-9_]*$"
const _SPEAKER_LINE := "^(?:\\[([^\\]]*)\\]\\s*)?([A-Z][A-Z0-9_]*)\\s*:\\s*(.*)$"
const _EFFECT_LINE := "^([a-z_]+)\\s*:(.*)$"
const _HEADER_LINE := "^([A-Za-z_][A-Za-z0-9_]*)\\s*:(.*)$"

static var _regex: Dictionary = {}


## {"events": Array[StoryEvent] (the well-formed ones, in file order), "errors": Array[String]}.
static func parse(text: String, pool: String) -> Dictionary:
	var state := _State.new(pool)
	var lines := text.split("\n")
	for i in lines.size():
		state.feed(lines[i].trim_suffix("\r"), i + 1)
	state.close_event()
	return {"events": state.events, "errors": state.errors}


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
	if text.is_valid_int():
		return int(text)
	if text == "true" or text == "false":
		return text == "true"
	return text if _matches(_NAME, text) else null


## The effect on a line ("verb: argument"): {"verb", "flag", "value"}, or {"error"}.
static func parse_effect(line: String) -> Dictionary:
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
	return {"verb": verb, "flag": flag, "value": value}


## The text without its leading placeholder marker (and the space after it).
static func strip_marker(text: String) -> String:
	if text == MARKER:
		return ""
	return text.substr(MARKER.length() + 1) if text.begins_with(MARKER + " ") else text


## The line without its comment and its outer blanks: "" for a blank or a comment line.
static func strip_comment(line: String) -> String:
	var stripped := line.strip_edges()
	if stripped.begins_with("#"):
		return ""
	for i in range(1, stripped.length()):
		if stripped[i] == "#" and (stripped[i - 1] == " " or stripped[i - 1] == "\t"):
			return stripped.left(i).strip_edges()
	return stripped


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
	var event: StoryEvent = null
	## The current event had an error: it is dropped at its close.
	var bad := false
	var in_header := false
	## The comment lines since the last blank or content line.
	var comment_block: PackedStringArray = []
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
		if event != null and not bad:
			events.append(event)
		event = null
		bad = false

	func feed(raw: String, n: int) -> void:
		var trimmed := raw.strip_edges()
		if trimmed.begins_with("#"):
			var text := trimmed.substr(1)
			comment_block.append(text.substr(1) if text.begins_with(" ") else text)
			return
		var line := StoryScript.strip_comment(raw)
		if line == "":
			comment_block.clear()
			in_header = false
			return
		if line.begins_with("=="):
			_open(line.substr(2).strip_edges(), n)
			return
		comment_block.clear()
		if event == null:
			error(n, "a line outside an event (an event starts with '== name')")
		elif in_header:
			_header(line, n)
		else:
			_body(line, n, raw[0] == " " or raw[0] == "\t")

	func _open(name: String, n: int) -> void:
		close_event()
		event = StoryEvent.new()
		event.pool = pool
		event.name = name
		event.id = pool + "." + name
		event.line_number = n
		event.comment = "\n".join(comment_block)
		comment_block.clear()
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
				if not value.is_valid_int():
					error(n, "act '%s' is not a number (1 to %d)" % [value, StoryScript.ACT_MAX])
				elif int(value) < 1 or int(value) > StoryScript.ACT_MAX:
					error(n, "act %s is not 1 to %d" % [value, StoryScript.ACT_MAX])
				else:
					event.act = int(value)

	func _trigger(value: String, n: int) -> void:
		var parts := value.split(" ", false)
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
		if line.begins_with("?"):
			if indented:
				error(n, "a nested choice: a choice has no choices")
			elif ended:
				error(n, "a line after the event's end effects")
			else:
				choice = {"kind": "choice", "text": line.substr(1).strip_edges(), "effects": [], "lines": [], "line": n}
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

	func _effect(line: String, n: int, into: Array) -> void:
		var effect := StoryScript.parse_effect(line)
		if effect.has("error"):
			error(n, effect["error"])
			return
		effect["line"] = n
		into.append(effect)

	func _line(line: String, n: int, into: Array) -> void:
		var m := StoryScript._re(StoryScript._SPEAKER_LINE).search(line)
		if m == null:
			error(n, "'%s' is not a body line ('SPEAKER: text', '? choice', or 'verb: argument')" % line)
			return
		var when: StoryCondition = null
		if m.get_start(1) >= 0:
			var parsed := StoryCondition.parse(m.get_string(1))
			if parsed["condition"] == null:
				error(n, "[%s]: %s" % [m.get_string(1), parsed["error"]])
				return
			when = parsed["condition"]
		into.append({"kind": "line", "speaker": m.get_string(2).to_lower(), "text": m.get_string(3).strip_edges(), "when": when, "line": n})
