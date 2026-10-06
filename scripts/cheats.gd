class_name Cheats
extends RefCounted
## Cheat codes for testing, typed into the title's seed field (playtest note 2026-09-22). Pure:
## parse() reads only this table. One row per code word: the flags it turns on for the run
## (RunState.cheats, reset by start_run). A code word is never a seed: a cheated run takes a
## random seed. Adding a code is one row here; nothing in the title changes. The readers:
## Player.hurt (immortal), RunState.start_run (rich), VerdictRules.decide (thumbs_down).
## ACTIONS is the second table: words that do something at the title instead of flagging the
## run (Main.play reads the action; the run that follows carries no flags). A word is in one
## table or the other, never both. An act action is ACT_ACTION plus the act (act_of reads it):
## the act's preset story state (data/story/acts.json, StoryCatalog.acts) over a wiped save.

const RANDOM_SEED := -1  ## what RunState.start_run reads as "pick one"
const CODES := {
	"permawhat?": {"immortal": true},  # Player.hurt lands nothing
	"verso": {"thumbs_down": true},  # VerdictRules.decide turns the thumb down (pollice verso)
	"dives": {"rich": true},  # RunState.start_run gives the run RICH_COINS
}
const ACTIONS := {
	"tabula": "wipe",  # Main.play: Profile.wipe() before the run (tabula rasa), so it is a first run
	"actus2": "act:2",  # Main.play: the wipe, then act 2's preset (Story.apply_act) committed
	"actus3": "act:3",  # the same for act 3
	"scalae": "tiers",  # Main.play: every shipped tier unlocked on the save (Profile.unlock_all_tiers), no wipe
}
## The tiers action (scalae, the stairs): read by Main.play.
const TIERS_ACTION := "tiers"
## The act actions' prefix: "act:2" is act 2.
const ACT_ACTION := "act:"


## The seed, the flags, and the action for the field's text: a code word gives RANDOM_SEED and
## its flags (the table's own row; RunState.start_run copies it), an action word RANDOM_SEED, no
## flags, and its action, a non-negative number gives that seed and no flags, anything else
## (blank, junk, a negative) RANDOM_SEED and no flags. The action is "" unless the word is in
## ACTIONS.
static func parse(text: String) -> Dictionary:
	var word := text.strip_edges()
	if CODES.has(word):
		return {"seed": RANDOM_SEED, "cheats": CODES[word], "action": ""}
	if ACTIONS.has(word):
		return {"seed": RANDOM_SEED, "cheats": {}, "action": ACTIONS[word]}
	var seed_value := int(word) if word.is_valid_int() and int(word) >= 0 else RANDOM_SEED
	return {"seed": seed_value, "cheats": {}, "action": ""}


## The act an act action names ("act:2" is 2), or 0 for any other action ("wipe", "", or one
## whose act is not a positive integer).
static func act_of(action: String) -> int:
	if not action.begins_with(ACT_ACTION):
		return 0
	var act := action.trim_prefix(ACT_ACTION)
	return int(act) if act.is_valid_int() and int(act) > 0 and str(int(act)) == act else 0


## The flags that are on, sorted and comma-separated ("immortal"), or "" when none is: what the
## gate screen, the run's record, and the RUN_END line print, so a cheated run is never mistaken
## for a real one.
static func describe(flags: Dictionary) -> String:
	var on: Array[String] = []
	for name: String in flags:
		if flags[name]:
			on.append(name)
	on.sort()
	return ",".join(on)
