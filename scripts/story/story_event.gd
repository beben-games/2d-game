class_name StoryEvent
extends RefCounted
## One event of a character's pool (data/story/<pool>.txt), as StoryScript parsed it: its
## gates (requires, unless, when), how it is chosen (priority, once, trigger), its body, and the
## writer's comments (kept, so a file rewritten from its events loses nothing). Pure: the story's
## classes never name an autoload or a Node (the Story tab runs them in the editor), so the state
## an event reads or writes comes in as a Save or a StoryContext.
##
## The body's entries and the effects are Dictionaries, each kind built only by its constructor
## below (the keys are written there and nowhere else): line_entry, choice_entry, comment_entry,
## effect_entry as parsed; shown_line and shown_choice as StoryPicker hands them out. `set` is the
## only effect verb today (StoryScript.EFFECT_VERBS); a later verb is a new row there and a
## branch in apply_effects.

var pool := ""
var name := ""
## "<pool>.<name>", the id every requires, unless, and save entry uses.
var id := ""
var requires: Array[String] = []
var unless: Array[String] = []
var when: StoryCondition = null
## story | high | normal | filler (StoryScript.PRIORITIES, highest first).
var priority := "normal"
var once := true
## talk | enter | verdict_wait | verdict_up | verdict_down | pick (StoryScript.TRIGGERS).
var trigger := "talk"
## The room of an `enter` trigger; "" for the others.
var trigger_arg := ""
## 1 to 3, or 0 when the event names no act.
var act := 0
## Line, choice, and comment entries in file order.
var body: Array = []
## The effects after the body: they run at the event's end (Story.finish).
var effects: Array = []
## The comment block before the event's `==` line (directly above it or across blank lines), one
## line per comment line, each without its '#' and the one blank after it.
var comment := ""
## The full-line comments among the header keys, in order, in the same form (a writer's
## commented-out `# when: wins >= 3`); the writer back to text puts them after the header keys.
var header_notes: Array[String] = []
## The `==` line's number in its file.
var line_number := 0
## The header key -> its line's number (for the catalog's errors and the Story tab).
var header_line: Dictionary = {}


## An event's id: "<pool>.<name>".
static func id_for(pool_id: String, event_name: String) -> String:
	return pool_id + "." + event_name


## The pool's file name, as errors name it.
func file() -> String:
	return pool + ".txt"


## True when playing the event uses up its pool's turn this return: a talk event that is not
## filler (each character says at most one new thing a return).
func uses_turn() -> bool:
	return trigger == "talk" and priority != "filler"


## A body line as parsed: the speaker's cast id (lowercase), the text as written (the marker
## kept), its [condition] or null, and its line in the file.
static func line_entry(speaker: String, text: String, condition: StoryCondition, line: int) -> Dictionary:
	return {"kind": "line", "speaker": speaker, "text": text, "when": condition, "line": line}


## A choice as parsed: its text, the effects and the line and comment entries indented under it.
static func choice_entry(text: String, line: int) -> Dictionary:
	return {"kind": "choice", "text": text, "effects": [], "lines": [], "line": line}


## A full-line comment kept in the body (or a choice's lines): the text without its '#' and the
## one blank after it. Nothing plays it.
static func comment_entry(text: String, line: int) -> Dictionary:
	return {"kind": "comment", "text": text, "line": line}


## An effect: its verb and what it acts on (for `set`, the flag and the value), and its line.
static func effect_entry(verb: String, flag: String, value: Variant, line: int) -> Dictionary:
	return {"verb": verb, "flag": flag, "value": value, "line": line}


## A line as it plays: the speaker's cast id and the text shown.
static func shown_line(speaker: String, text: String) -> Dictionary:
	return {"kind": "line", "speaker": speaker, "text": text}


## A choice as it plays: the text shown, its effects (a copy), and its lines as they play.
static func shown_choice(text: String, choice_effects: Array, choice_lines: Array) -> Dictionary:
	return {"kind": "choice", "text": text, "effects": choice_effects, "lines": choice_lines}


## Runs the effects against the save's story section. A verb the catalog accepted has a branch
## here; nothing else reaches this (an effect is validated at load).
static func apply_effects(effects: Array, save: Save) -> void:
	for effect: Dictionary in effects:
		match effect["verb"]:
			"set":
				save.set_story_flag(effect["flag"], effect["value"])
