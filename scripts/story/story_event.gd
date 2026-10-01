class_name StoryEvent
extends RefCounted
## One event of a character's pool (data/story/<pool>.txt), as StoryScript parsed it: its
## gates (requires, unless, when), how it is chosen (priority, once, trigger), and its body.
## Pure: the story's classes never name an autoload or a Node (the Story tab runs them in the
## editor), so the state an event reads or writes comes in as a Save or a StoryContext.
##
## A body entry is a line {"kind": "line", "speaker": <cast id>, "text", "when": StoryCondition
## or null, "line": <file line>} or a choice {"kind": "choice", "text", "effects", "lines": [line
## entries], "line"}. An effect is {"verb": "set", "flag", "value", "line"}: `set` is the only
## verb today (StoryScript.EFFECT_VERBS); a later verb is a new row there and a branch in
## apply_effects.

var pool := ""
var name := ""
## "<pool>.<name>", the id every requires, unless, and save entry uses.
var id := ""
var requires: Array[String] = []
var unless: Array[String] = []
var when: StoryCondition = null
## story | high | normal | filler (StoryCatalog.PRIORITIES, highest first).
var priority := "normal"
var once := true
## talk | enter | verdict_wait | verdict_up | verdict_down | pick (StoryCatalog.TRIGGERS).
var trigger := "talk"
## The room of an `enter` trigger; "" for the others.
var trigger_arg := ""
## 1 to 3, or 0 when the event names no act.
var act := 0
var body: Array = []
## The effects after the body: they run at the event's end (Story.finish).
var effects: Array = []
## The comment block directly above the event's `==` line, without the '#'s.
var comment := ""
## The `==` line's number in its file.
var line_number := 0
## The header key -> its line's number (for the catalog's errors and the Story tab).
var header_line: Dictionary = {}


## The pool's file name, as errors name it.
func file() -> String:
	return pool + ".txt"


## Runs the effects against the save's story section. A verb the catalog accepted has a branch
## here; nothing else reaches this (an effect is validated at load).
static func apply_effects(effects: Array, save: Save) -> void:
	for effect: Dictionary in effects:
		match effect["verb"]:
			"set":
				save.set_story_flag(effect["flag"], effect["value"])
