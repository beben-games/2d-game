class_name Save
extends RefCounted
## The profile's file: money, the training ranks, the flags, every all-time stat, the run log,
## and the story's state, persisted in user://save.cfg. Pure like Settings: load_from and save_to take a path so
## tests use a scratch file; the Profile autoload holds the live one and is the only writer.
## The stats record more than M5 reads (achievements and unlocks later come from the past):
## adding a counter means adding its name to STAT_KEYS, and an older file loads it at its
## default. A file the game does not understand (a later version, or one ConfigFile cannot
## parse) loads as defaults, but never silently: it is first copied to `<path>.bak` (the
## BACKUP_SUFFIX; an older .bak is overwritten) and `backup_note` says so, for Profile to warn
## with (this class prints nothing), since the next commit() writes a version-1 file over the
## path. The .bak is for the player, or a later version that can read it; nothing here reads it
## back. Profile.wipe (the title's `tabula`) keeps the file it wipes the same way (back_up).
## Godot's parser itself prints an ERROR on a corrupt file; there is no silent parse.

const VERSION := 1
const DEFAULT_PATH := "user://save.cfg"
const RUN_LOG_CAP := 500
const BACKUP_SUFFIX := ".bak"
## The unlocks and their defaults (M7): `tier` the highest tier a first win (or `scalae`) opened,
## `lifts_seen` the highest tier whose lift the player has seen open (the grounds' rise plays for
## a tier above it). A section of its own, never a flag; an older file without it loads these.
## The tier a save may fight is highest_tier(), never `tier` read bare: a win before the unlocks
## existed counts there too.
const UNLOCK_KEYS := {"tier": 1, "lifts_seen": 1}
## The flags and their defaults: counts of runs by outcome, whether the grounds were seen, and
## whether the Spoliarium was (its door shows from then on).
const FLAG_KEYS := {"runs": 0, "wins": 0, "falls": 0, "deaths": 0, "perfect_runs": 0, "returned": false, "spoliarium_seen": false}
## The stats and their empty values. A per-id counter (PER_ID_KEYS) is a Dictionary id -> int;
## a counter an int; a time or a peak a float; best_run the one record {rounds, kills, time}.
## boss_time_best is a min (set_boss_time; 0.0 is none yet) and favour_peak a max (raise_stat):
## neither is addable. A new stat is a row here, plus its name in PER_ID_KEYS when it is nested
## by id, or in NOT_ADDABLE when it is a record, a min, or a max (a test pins both as subsets).
## By tier (M7), keyed by tier_key(tier) (the tier as a string, as the other ids): wins_by_tier a
## per-id counter; best_run_by_tier and boss_time_by_tier (BY_TIER_KEYS) a record and a min per
## tier, written by set_best_run and set_boss_time beside the all-time ones and read through
## best_run_of and boss_time_of.
const STAT_KEYS := {
	"shots_fired": {}, "shots_hit": 0, "hits_landed": {}, "kills": {}, "hits_taken": {},
	"deaths_by": {}, "dashes": 0, "dashes_through_danger": 0, "daring_kills": 0, "cards_taken": {},
	"switches": 0, "rounds_cleared": 0, "rounds_by_band": {}, "clean_rounds": 0, "perfect_runs": 0,
	"boss_kills": 0, "boss_time_best": 0.0, "coins_earned": 0, "coins_lost": 0, "coins_spent": 0,
	"piles_collected": 0, "favour_peak": 0.0, "time_played": 0.0, "time_in_grounds": 0.0,
	"best_run": {}, "wins_by_tier": {}, "best_run_by_tier": {}, "boss_time_by_tier": {},
}
const PER_ID_KEYS: Array[String] = ["shots_fired", "hits_landed", "kills", "hits_taken", "deaths_by", "cards_taken", "rounds_by_band", "wins_by_tier"]
## The stats add_stat refuses: a record, a min, and a max, each with its own setter.
const NOT_ADDABLE: Array[String] = ["best_run", "boss_time_best", "favour_peak", "best_run_by_tier", "boss_time_by_tier"]
## The tables by tier that are not counters: tier_key -> a best run record, or a boss time.
const BY_TIER_KEYS: Array[String] = ["best_run_by_tier", "boss_time_by_tier"]
## The story section's keys and their empty values (the Story autoload's state, read and written
## through the helpers below): `played` an event id -> [count, seq of its last play], `seq` the
## count of every play so far (the clock "least recently played" is measured on), `flags` the
## story flags set so far (name -> bool, int, or word; data/story/flags.txt declares them and
## their defaults), `spoken` the pools that spoke a non-filler talk event this return (cleared
## at a run's end). The section is additive: a file without it loads an empty story.
const STORY_KEYS := {"played": {}, "seq": 0, "flags": {}, "spoken": []}
## What "" means in a per-id stat when the source had no id (a bare hit in a test, a stub).
const UNKNOWN_ID := "unknown"

var money: int = 0
## Training line id -> rank bought.
var training: Dictionary = {}
var flags: Dictionary = FLAG_KEYS.duplicate()
## What the save has opened (UNLOCK_KEYS).
var unlocks: Dictionary = UNLOCK_KEYS.duplicate()
var stats: Dictionary = _default_stats()
## One record per run, newest first, at most RUN_LOG_CAP.
var runs: Array[Dictionary] = []
## The story's state (STORY_KEYS).
var story: Dictionary = empty_story()
## What load_from did with a file it could not use ("" when it used the file or found none).
var backup_note := ""


## The saved profile, or the defaults when the file is missing. A file that is there but not
## understood (unparsable, or from a later version) is backed up first, then the defaults. An
## older file loads what it has; whatever is missing or of the wrong shape stays at its default.
static func load_from(path: String = DEFAULT_PATH) -> Save:
	var s := Save.new()
	if not FileAccess.file_exists(path):
		return s
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		s.backup_note = _backup_note(path, "could not be read", back_up(path))
		return s
	if int(cfg.get_value("meta", "version", VERSION)) > VERSION:
		s.backup_note = _backup_note(path, "is from a later version", back_up(path))
		return s
	s.money = int(cfg.get_value("money", "value", 0))
	for line: String in _section_keys(cfg, "training"):
		s.training[line] = int(cfg.get_value("training", line))
	for key: String in FLAG_KEYS:
		var value: Variant = cfg.get_value("flags", key, FLAG_KEYS[key])
		if typeof(value) == typeof(FLAG_KEYS[key]):
			s.flags[key] = value
	for key: String in UNLOCK_KEYS:
		var value: Variant = cfg.get_value("unlocks", key, UNLOCK_KEYS[key])
		if typeof(value) == typeof(UNLOCK_KEYS[key]):
			s.unlocks[key] = value
	for key: String in STAT_KEYS:
		if not cfg.has_section_key("stats", key):
			continue
		var value: Variant = cfg.get_value("stats", key)
		if typeof(value) == typeof(STAT_KEYS[key]):
			s.stats[key] = value
	var records: Variant = cfg.get_value("runs", "log", [])
	if records is Array:
		for record: Variant in records:
			if record is Dictionary:
				s.runs.append(record)
	s.runs.resize(mini(s.runs.size(), RUN_LOG_CAP))
	for key: String in STORY_KEYS:
		if not cfg.has_section_key("story", key):
			continue
		var value: Variant = cfg.get_value("story", key)
		if typeof(value) == typeof(STORY_KEYS[key]):
			s.story[key] = value
	return s


func save_to(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("money", "value", money)
	for line: String in training:
		cfg.set_value("training", line, training[line])
	for key: String in FLAG_KEYS:
		cfg.set_value("flags", key, flags[key])
	for key: String in UNLOCK_KEYS:
		cfg.set_value("unlocks", key, unlocks[key])
	for key: String in STAT_KEYS:
		cfg.set_value("stats", key, stats[key])
	cfg.set_value("runs", "log", runs)
	for key: String in STORY_KEYS:
		cfg.set_value("story", key, story[key])
	return cfg.save(path)


static func is_per_id(key: String) -> bool:
	return key in PER_ID_KEYS


## True when add_stat accepts the call: a known, addable stat, with an id exactly when it is
## per-id, and an amount of the counter's type (an int for an int counter, since a fraction
## would drift it to a float that the next load drops as the wrong shape; an int or a float for
## a float stat). add_stat asserts on this.
static func addable(key: String, id: String, amount: Variant = 1) -> bool:
	if not STAT_KEYS.has(key) or key in NOT_ADDABLE:
		return false
	if (id != "") != is_per_id(key):
		return false
	if STAT_KEYS[key] is float:
		return amount is int or amount is float
	return amount is int


## Adds to a counter (an int, or a float for the times). A per-id stat needs its id.
func add_stat(key: String, amount: Variant = 1, id: String = "") -> void:
	assert(addable(key, id, amount), "Save: cannot add %s to stat '%s' with id '%s'" % [amount, key, id])
	if is_per_id(key):
		var table: Dictionary = stats[key]
		table[id] = int(table.get(id, 0)) + int(amount)
	elif STAT_KEYS[key] is float:
		stats[key] = float(stats[key]) + float(amount)
	else:
		stats[key] = int(stats[key]) + int(amount)


## The stat's value; 0 for an id never seen. A per-id stat needs its id.
func stat(key: String, id: String = "") -> Variant:
	assert(STAT_KEYS.has(key), "Save: no stat '%s'" % key)
	assert((id != "") == is_per_id(key), "Save: stat '%s' with id '%s'" % [key, id])
	if is_per_id(key):
		var table: Dictionary = stats[key]
		return int(table.get(id, 0))
	return stats[key]


## True when bump_flag accepts the key: a flag that is a count (not `returned`, a bool).
static func bumpable(key: String) -> bool:
	return FLAG_KEYS.has(key) and FLAG_KEYS[key] is int


## Counts a flag up by one (runs, wins, falls, deaths, perfect_runs): the one writer of the counts.
func bump_flag(key: String) -> void:
	assert(bumpable(key), "Save: cannot bump flag '%s'" % key)
	flags[key] = int(flags[key]) + 1


## True when set_flag accepts the pair: a flag, and a value of its own type (a bool for
## `returned`, an int for a count).
static func settable(key: String, value: Variant) -> bool:
	return FLAG_KEYS.has(key) and typeof(value) == typeof(FLAG_KEYS[key])


## Overwrites a flag with a value of its own type: how `returned` is set (bump_flag refuses a bool).
func set_flag(key: String, value: Variant) -> void:
	assert(settable(key, value), "Save: cannot set flag '%s' to %s" % [key, value])
	flags[key] = value


## The sum of a per-id stat over every id (all-time kills, hits taken, shots fired).
func total(key: String) -> int:
	assert(is_per_id(key), "Save: total of '%s', which is not per-id" % key)
	var sum := 0
	var table: Dictionary = stats[key]
	for id: String in table:
		sum += int(table[id])
	return sum


## Overwrites a plain (not per-id) stat with a value of its own type.
func set_stat(key: String, value: Variant) -> void:
	assert(STAT_KEYS.has(key) and not is_per_id(key), "Save: cannot set stat '%s'" % key)
	assert(typeof(value) == typeof(STAT_KEYS[key]), "Save: stat '%s' is not a %s" % [key, type_string(typeof(value))])
	stats[key] = value


## Keeps the larger of the stat and the value (favour_peak).
func raise_stat(key: String, value: float) -> void:
	set_stat(key, maxf(float(stat(key)), value))


## The highest tier the save may fight: the stored unlock, or 2 when the save has a win (a save
## from before the unlocks, whose first win opened nothing on disk), whichever is larger.
## Computed when read, never written at load: an old file, a wiped one, and an act preset agree.
func highest_tier() -> int:
	return maxi(int(unlocks["tier"]), 2 if int(flags["wins"]) >= 1 else 1)


## Stores `tier` as unlocked when it is above the stored one; true when it raised it (a second
## unlock of the same tier, or a lower one, changes nothing).
func unlock_tier(tier: int) -> bool:
	if tier <= int(unlocks["tier"]):
		return false
	unlocks["tier"] = tier
	return true


## A tier's key in the by-tier tables (wins_by_tier, best_run_by_tier, boss_time_by_tier).
static func tier_key(tier: int) -> String:
	return str(tier)


## The wins of tier `tier` (wins_by_tier).
func wins_of(tier: int) -> int:
	return int(stat("wins_by_tier", tier_key(tier)))


## Tier `tier`'s best run ({} for none yet).
func best_run_of(tier: int) -> Dictionary:
	var held: Variant = (stats["best_run_by_tier"] as Dictionary).get(tier_key(tier), {})
	return held if held is Dictionary else {}


## Tier `tier`'s fastest boss kill (0.0 for none yet).
func boss_time_of(tier: int) -> float:
	var held: Variant = (stats["boss_time_by_tier"] as Dictionary).get(tier_key(tier), 0.0)
	return float(held) if held is float or held is int else 0.0


## Keeps the fastest boss kill, all-time and tier `tier`'s; 0.0 means none yet.
func set_boss_time(seconds: float, tier: int) -> void:
	var best := float(stat("boss_time_best"))
	set_stat("boss_time_best", seconds if best == 0.0 or seconds < best else best)
	var held := boss_time_of(tier)
	(stats["boss_time_by_tier"] as Dictionary)[tier_key(tier)] = seconds if held == 0.0 or seconds < held else held


## Keeps the better run by rounds, then kills, then the faster time (a full tie keeps the one
## held), all-time and tier `tier`'s. Returns true when the record replaced the all-time one.
## record is {rounds, kills, time}.
func set_best_run(record: Dictionary, tier: int) -> bool:
	var held_tier := best_run_of(tier)
	if held_tier.is_empty() or _better_run(record, held_tier):
		(stats["best_run_by_tier"] as Dictionary)[tier_key(tier)] = record.duplicate()
	var held: Dictionary = stat("best_run")
	if not held.is_empty() and not _better_run(record, held):
		return false
	set_stat("best_run", record.duplicate())
	return true


static func _better_run(record: Dictionary, held: Dictionary) -> bool:
	if int(record.get("rounds", 0)) != int(held.get("rounds", 0)):
		return int(record.get("rounds", 0)) > int(held.get("rounds", 0))
	if int(record.get("kills", 0)) != int(held.get("kills", 0)):
		return int(record.get("kills", 0)) > int(held.get("kills", 0))
	return float(record.get("time", INF)) < float(held.get("time", INF))


## Puts a run's record at the front of the log and drops the oldest past RUN_LOG_CAP.
func log_run(record: Dictionary) -> void:
	runs.push_front(record.duplicate())
	if runs.size() > RUN_LOG_CAP:
		runs.resize(RUN_LOG_CAP)


## A fresh story section (its own tables: a Save never shares one with another).
static func empty_story() -> Dictionary:
	return STORY_KEYS.duplicate(true)


## How many times the story event has played; 0 for one never played (or an entry of no shape).
func story_played(id: String) -> int:
	var entry: Variant = (story["played"] as Dictionary).get(id)
	return int(entry[0]) if _is_play(entry) else 0


## The story's seq at the event's last play: 0 for never, larger for more recent.
func story_last(id: String) -> int:
	var entry: Variant = (story["played"] as Dictionary).get(id)
	return int(entry[1]) if _is_play(entry) else 0


## Counts a play of the event and stamps it with the next seq.
func mark_story_played(id: String) -> void:
	story["seq"] = int(story["seq"]) + 1
	(story["played"] as Dictionary)[id] = [story_played(id) + 1, int(story["seq"])]


## The story flag's value, or `default` when it was never set.
func story_flag(name: String, default: Variant) -> Variant:
	return (story["flags"] as Dictionary).get(name, default)


func set_story_flag(name: String, value: Variant) -> void:
	(story["flags"] as Dictionary)[name] = value


## The pool spoke a non-filler talk event this return.
func mark_story_spoken(pool: String) -> void:
	var spoken: Array = story["spoken"]
	if not spoken.has(pool):
		spoken.append(pool)


func story_has_spoken(pool: String) -> bool:
	return (story["spoken"] as Array).has(pool)


## A new return: every pool may speak again.
func clear_story_spoken() -> void:
	(story["spoken"] as Array).clear()


## A played entry of the right shape, [count, seq] as ints (a hand-edited file may hold anything).
static func _is_play(entry: Variant) -> bool:
	return entry is Array and entry.size() == 2 and entry[0] is int and entry[1] is int


static func _default_stats() -> Dictionary:
	var result := {}
	for key: String in STAT_KEYS:
		var value: Variant = STAT_KEYS[key]
		result[key] = value.duplicate() if value is Dictionary else value
	return result


## Copies the file at `path` to `<path>.bak`, over any older one. load_from keeps a file the
## game could not use; Profile.wipe keeps the one it wipes, and wipes nothing unless this is OK.
static func back_up(path: String) -> Error:
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + BACKUP_SUFFIX))


## load_from's note on a file it could not use: where the copy went, or why it could not.
static func _backup_note(path: String, why: String, err: Error) -> String:
	var backup := path + BACKUP_SUFFIX
	if err == OK:
		return "%s %s; kept as %s and starting from the defaults" % [path, why, backup]
	return "%s %s and could not be copied to %s (%s); starting from the defaults" % [path, why, backup, error_string(err)]


static func _section_keys(cfg: ConfigFile, section: String) -> PackedStringArray:
	return cfg.get_section_keys(section) if cfg.has_section(section) else PackedStringArray()
