class_name Save
extends RefCounted
## The profile's file: money, the training ranks, the flags, every all-time stat, and the run
## log, persisted in user://save.cfg. Pure like Settings: load_from and save_to take a path so
## tests use a scratch file; the Profile autoload holds the live one and is the only writer.
## The stats record more than M5 reads (achievements and unlocks later come from the past):
## adding a counter means adding its name to STAT_KEYS, and an older file loads it at its
## default. A file the game does not understand (a later version, or one ConfigFile cannot
## parse) loads as defaults, but never silently: it is first copied to `<path>.bak` (the
## BACKUP_SUFFIX; an older .bak is overwritten) and `backup_note` says so, for Profile to warn
## with (this class prints nothing), since the next commit() writes a version-1 file over the
## path. The .bak is for the player, or a later version that can read it; nothing here reads it
## back. Godot's parser itself prints an ERROR on a corrupt file; there is no silent parse.

const VERSION := 1
const DEFAULT_PATH := "user://save.cfg"
const RUN_LOG_CAP := 500
const BACKUP_SUFFIX := ".bak"
## The flags and their defaults: counts of runs by outcome, and whether the grounds were seen.
const FLAG_KEYS := {"runs": 0, "wins": 0, "falls": 0, "deaths": 0, "perfect_runs": 0, "returned": false}
## The stats and their empty values. A per-id counter (PER_ID_KEYS) is a Dictionary id -> int;
## a counter an int; a time or a peak a float; best_run the one record {rounds, kills, time}.
## boss_time_best is a min (set_boss_time; 0.0 is none yet) and favour_peak a max (raise_stat):
## neither is addable. A new stat is a row here, plus its name in PER_ID_KEYS when it is nested
## by id, or in NOT_ADDABLE when it is a record, a min, or a max (a test pins both as subsets).
const STAT_KEYS := {
	"shots_fired": {}, "shots_hit": 0, "hits_landed": {}, "kills": {}, "hits_taken": {},
	"deaths_by": {}, "dashes": 0, "dashes_through_danger": 0, "cards_taken": {}, "switches": 0,
	"rounds_cleared": 0, "rounds_by_band": {}, "clean_rounds": 0, "perfect_runs": 0,
	"boss_kills": 0, "boss_time_best": 0.0, "coins_earned": 0, "coins_lost": 0, "coins_spent": 0,
	"piles_collected": 0, "favour_peak": 0.0, "time_played": 0.0, "time_in_grounds": 0.0,
	"best_run": {},
}
const PER_ID_KEYS: Array[String] = ["shots_fired", "hits_landed", "kills", "hits_taken", "deaths_by", "cards_taken", "rounds_by_band"]
## The stats add_stat refuses: a record, a min, and a max, each with its own setter.
const NOT_ADDABLE: Array[String] = ["best_run", "boss_time_best", "favour_peak"]
## What "" means in a per-id stat when the source had no id (a bare hit in a test, a stub).
const UNKNOWN_ID := "unknown"

var money: int = 0
## Training line id -> rank bought.
var training: Dictionary = {}
var flags: Dictionary = FLAG_KEYS.duplicate()
var stats: Dictionary = _default_stats()
## One record per run, newest first, at most RUN_LOG_CAP.
var runs: Array[Dictionary] = []
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
		s.backup_note = _back_up(path, "could not be read")
		return s
	if int(cfg.get_value("meta", "version", VERSION)) > VERSION:
		s.backup_note = _back_up(path, "is from a later version")
		return s
	s.money = int(cfg.get_value("money", "value", 0))
	for line: String in _section_keys(cfg, "training"):
		s.training[line] = int(cfg.get_value("training", line))
	for key: String in FLAG_KEYS:
		var value: Variant = cfg.get_value("flags", key, FLAG_KEYS[key])
		if typeof(value) == typeof(FLAG_KEYS[key]):
			s.flags[key] = value
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
	return s


func save_to(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("money", "value", money)
	for line: String in training:
		cfg.set_value("training", line, training[line])
	for key: String in FLAG_KEYS:
		cfg.set_value("flags", key, flags[key])
	for key: String in STAT_KEYS:
		cfg.set_value("stats", key, stats[key])
	cfg.set_value("runs", "log", runs)
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


## Keeps the fastest boss kill; 0.0 means none yet.
func set_boss_time(seconds: float) -> void:
	var best := float(stat("boss_time_best"))
	set_stat("boss_time_best", seconds if best == 0.0 or seconds < best else best)


## Keeps the better run by rounds, then kills, then the faster time (a full tie keeps the one
## held). Returns true when the record replaced the old one. record is {rounds, kills, time}.
func set_best_run(record: Dictionary) -> bool:
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


static func _default_stats() -> Dictionary:
	var result := {}
	for key: String in STAT_KEYS:
		var value: Variant = STAT_KEYS[key]
		result[key] = value.duplicate() if value is Dictionary else value
	return result


## Copies the file the game could not use to `<path>.bak`, over any older one; returns the note.
static func _back_up(path: String, why: String) -> String:
	var backup := path + BACKUP_SUFFIX
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
	if err == OK:
		return "%s %s; kept as %s and starting from the defaults" % [path, why, backup]
	return "%s %s and could not be copied to %s (%s); starting from the defaults" % [path, why, backup, error_string(err)]


static func _section_keys(cfg: ConfigFile, section: String) -> PackedStringArray:
	return cfg.get_section_keys(section) if cfg.has_section(section) else PackedStringArray()
