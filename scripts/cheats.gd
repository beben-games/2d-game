class_name Cheats
extends RefCounted
## Cheat codes for testing, typed into the title's seed field (playtest note 2026-09-22). Pure:
## parse() reads only this table. One row per code word: the flags it turns on for the run
## (RunState.cheats, reset by start_run). A code word is never a seed: a cheated run takes a
## random seed. Adding a code is one row here; nothing in the title changes.

const RANDOM_SEED := -1  ## what RunState.start_run reads as "pick one"
const CODES := {
	"permawhat?": {"immortal": true},  # Player.hurt lands nothing
}


## The seed and the flags for the field's text: a code word gives RANDOM_SEED and its flags (a
## copy), a non-negative number gives that seed and no flags, anything else (blank, junk, a
## negative) RANDOM_SEED and no flags.
static func parse(text: String) -> Dictionary:
	var word := text.strip_edges()
	if CODES.has(word):
		return {"seed": RANDOM_SEED, "cheats": (CODES[word] as Dictionary).duplicate()}
	var seed_value := int(word) if word.is_valid_int() and int(word) >= 0 else RANDOM_SEED
	return {"seed": seed_value, "cheats": {}}


## The flags that are on, sorted and comma-separated ("immortal"), or "" when none is: what the
## summary and the RUN_OVER/RUN_WON line print, so a cheated run is never mistaken for a real one.
static func describe(flags: Dictionary) -> String:
	var on: Array[String] = []
	for name: String in flags:
		if flags[name]:
			on.append(name)
	on.sort()
	return ",".join(on)
