class_name Settings
extends RefCounted
## The player's options: three volumes in 0..1, persisted in user://settings.cfg. Pure: load_from
## and save_to take a path so tests use a scratch file; Audio.apply() puts the volumes on the buses.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "audio"
const KEYS: Array[String] = ["master", "sfx", "music"]
const DEFAULTS := {"master": 0.8, "sfx": 1.0, "music": 0.85}  ## music raised from 0.7 on the 2026-09-23 note (too quiet)

var master: float = DEFAULTS["master"]
var sfx: float = DEFAULTS["sfx"]
var music: float = DEFAULTS["music"]


## The saved settings, or the defaults when the file is missing or unreadable (a fresh install).
static func load_from(path: String = DEFAULT_PATH) -> Settings:
	var s := Settings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return s
	for key in KEYS:
		s.set_volume(key, float(cfg.get_value(SECTION, key, DEFAULTS[key])))
	return s


func save_to(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value(SECTION, key, volume(key))
	return cfg.save(path)


func volume(key: String) -> float:
	assert(key in KEYS, "Settings: no volume '%s'" % key)
	return clampf(float(get(key)), 0.0, 1.0)


func set_volume(key: String, value: float) -> void:
	assert(key in KEYS, "Settings: no volume '%s'" % key)
	set(key, clampf(value, 0.0, 1.0))
