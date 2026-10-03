class_name StoryContext
extends RefCounted
## The one place a story name resolves to a value (a condition reads it, `{name}` substitutes
## it): the declared story flags (from the save's story section, at their declared default until
## set), the profile's flags (Save.FLAG_KEYS), the last run's facts (from the newest run record),
## the moment's facts (round_band, round_loss, run_band, arrival: "none" until handed in), and
## any other fact the caller hands in (a fact wins over every other name). A later namespace
## (relationship levels, `bond.lanista`) is one more lookup here. Pure: built from a Save, never
## Profile.

const NONE := "none"
## The closed word lists of the word-valued names; the catalog refuses a comparison with a word
## outside its name's list. The bands are FavourRules.BAND_NAMES and "none" (a test pins it).
const WORDS := {
	"last_outcome": ["win", "fall", "yield", "none"],
	"last_verdict": ["up", "down", "none"],
	"last_band": ["boo", "quiet", "cheer", "roar", "none"],
	"round_band": ["boo", "quiet", "cheer", "roar", "none"],
	"round_loss": ["hit", "fled", "slow", "none"],
	"run_band": ["boo", "quiet", "cheer", "roar", "none"],
	"arrival": ["gate", "door", "start", "none"],
}
## Word-valued names with no closed list: the enemy that felled the gladiator (any enemy id).
const OPEN_WORDS: Array[String] = ["last_killer"]
## The names the moments hand in (the pick, the verdict, a room's entry: arrival is how the
## gladiator came in, through the gate screen's pass, a door, or the title's Play); "none" when
## not handed in.
const MOMENT_FACTS: Array[String] = ["round_band", "round_loss", "run_band", "arrival"]

var _values: Dictionary = {}


## save null reads as a fresh Save (the catalog's validation context: every name known, every
## value its default). declared: the story flags and their defaults (StoryCatalog.flags).
func _init(save: Save = null, declared: Dictionary = {}, facts: Dictionary = {}) -> void:
	if save == null:
		save = Save.new()
	for key: String in Save.FLAG_KEYS:
		var flag: Variant = save.flags.get(key, Save.FLAG_KEYS[key])
		_values[key] = flag if typeof(flag) == typeof(Save.FLAG_KEYS[key]) else Save.FLAG_KEYS[key]
	_values.merge(last_run_facts(save.runs[0] if not save.runs.is_empty() else {}), true)
	for key: String in MOMENT_FACTS:
		_values[key] = NONE
	for name: String in declared:
		var value: Variant = save.story_flag(name, declared[name])
		_values[name] = value if typeof(value) == typeof(declared[name]) else declared[name]
	for name: String in facts:
		_values[name] = facts[name]


## The last run's facts from its record (Main's _record): the outcome, the verdict ("" for a
## yield reads as none), the band at the last round's end (the record keeps band indices), and
## the enemy that felled the gladiator (felled_by); each "none" when absent.
static func last_run_facts(record: Dictionary) -> Dictionary:
	var band := NONE
	var bands: Variant = record.get("bands", [])
	if bands is Array and not bands.is_empty():
		var last: Variant = bands[bands.size() - 1]
		if last is int and last >= 0 and last < FavourRules.BAND_NAMES.size():
			band = FavourRules.BAND_NAMES[last]
		elif last is String and (WORDS["last_band"] as Array).has(last):
			band = last
	var killer: Variant = record.get("felled_by", "")
	return {
		"last_outcome": _word(record.get("outcome"), WORDS["last_outcome"]),
		"last_verdict": _word(record.get("verdict"), WORDS["last_verdict"]),
		"last_band": band,
		"last_killer": killer if killer is String and killer != "" else NONE,
	}


static func _word(value: Variant, words: Array) -> String:
	return value if value is String and words.has(value) else NONE


func knows(name: String) -> bool:
	return _values.has(name)


## The name's value: an int, a bool, or a word (String); null for an unknown name.
func value(name: String) -> Variant:
	return _values.get(name)


## "int", "bool", or "word".
func kind(name: String) -> String:
	if WORDS.has(name) or name in OPEN_WORDS:
		return "word"
	var v: Variant = _values.get(name)
	if v is bool:
		return "bool"
	return "int" if v is int else "word"


## The name's closed word list; empty for an open word, a number, or a bool.
func words(name: String) -> Array:
	return WORDS.get(name, [])


## The text with every `{name}` the context knows replaced by its value; an unknown one is left.
func substitute(text: String) -> String:
	var out := ""
	var at := 0
	while true:
		var open := text.find("{", at)
		var close := text.find("}", open + 1) if open >= 0 else -1
		if close < 0:
			break
		var inner := text.substr(open + 1, close - open - 1)
		if inner.contains("{"):
			out += text.substr(at, open - at + 1)
			at = open + 1
			continue
		out += text.substr(at, open - at)
		var name := inner.strip_edges()
		out += str(value(name)) if knows(name) else text.substr(open, close - open + 1)
		at = close + 1
	return out + text.substr(at)


## The names inside `{...}` in the text, trimmed, in order (an empty `{}` gives "").
static func names_in(text: String) -> Array[String]:
	var out: Array[String] = []
	var at := text.find("{")
	while at >= 0:
		var close := text.find("}", at + 1)
		if close < 0:
			break
		var inner := text.substr(at + 1, close - at - 1)
		if not inner.contains("{"):
			out.append(inner.strip_edges())
		at = text.find("{", at + 1)
	return out


## A value's truth as a bare name: a bool itself, an int not zero, a word neither "" nor "none".
static func truth(v: Variant) -> bool:
	if v is bool:
		return v
	if v is int:
		return v != 0
	if v is String:
		return v != "" and v != NONE
	return false
