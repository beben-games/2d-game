extends Node
## Every sound in the game. Listens to the bus like Fx (the handlers land in Task 2) and plays
## one-shots from data/audio.json (name -> file, volume, pitch jitter, minimum gap). A listed file
## that is missing is silence plus one AUDIO_MISSING line at boot, never an error, so the game is
## complete before any file arrives. Two pools of players on the Sfx bus: the game pool pauses
## with the tree, the UI pool runs under the menus. Two music players on the Music bus crossfade.
## Volumes come from Settings through apply(). Engine.time_scale (hitstop) does not touch
## playback speed in Godot 4 (the docs say so; AudioServer.playback_speed_scale stays 1), so
## nothing here compensates for a freeze. The Sfx and Music buses are made here rather than in a
## bus layout file, so a fresh checkout and an export have them with no editor step.

const TABLE_PATH := "res://data/audio.json"
const ASSETS_DIR := "res://assets"
const SILENT_DB := -80.0
const GAME_POOL := 8
const UI_POOL := 4
const MUSIC_FADE := 0.8
const DEFAULT_VOLUME_DB := -6.0
const DEFAULT_JITTER := 0.0
const DEFAULT_GAP := 0.03

var settings: Settings
## Plays counted by name since the last reset(); a missing file still counts (the event fired).
## Tests and the smoke tool read it.
var plays: Dictionary = {}
## Names whose file was missing at load, in table order.
var missing: Array[String] = []
var current_music := ""

var _table: Dictionary = {}  ## name -> {stream: AudioStream or null, volume_db, pitch_jitter, min_gap, music}
var _game_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _music_live := 0  ## index into _music of the player carrying the current loop
var _music_tween: Tween
var _last_play_msec: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Sfx")
	_ensure_bus("Music")
	settings = Settings.load_from()
	apply(settings)
	_table = load_table(TABLE_PATH)
	_game_pool = _make_pool("Game", GAME_POOL, "Sfx", Node.PROCESS_MODE_PAUSABLE)
	_ui_pool = _make_pool("Ui", UI_POOL, "Sfx", Node.PROCESS_MODE_ALWAYS)
	_music = _make_pool("Music", 2, "Music", Node.PROCESS_MODE_ALWAYS)


## Reads the table. Every entry's file is resolved under res://assets; a missing one loads as null
## and is reported once with a print (a push_warning would fail the boot gate). Music loops.
func load_table(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	assert(not text.is_empty(), "Audio: cannot read %s" % path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Audio: %s is not a JSON object" % path)
	var table: Dictionary = {}
	missing = []
	for section: String in ["sfx", "music"]:
		var entries: Dictionary = parsed.get(section, {})
		for name: String in entries:
			var e: Dictionary = entries[name]
			var file := ASSETS_DIR.path_join(str(e.get("file", "")))
			var stream: AudioStream = null
			if ResourceLoader.exists(file):
				stream = load(file) as AudioStream
				if section == "music" and stream != null:
					stream.set("loop", true)  # AudioStreamOggVorbis; a WAV would need loop_mode
			else:
				missing.append(name)
				print("AUDIO_MISSING %s (%s)" % [name, file])
			table[name] = {
				"stream": stream,
				"volume_db": float(e.get("volume_db", DEFAULT_VOLUME_DB)),
				"pitch_jitter": float(e.get("pitch_jitter", DEFAULT_JITTER)),
				"min_gap": float(e.get("min_gap", DEFAULT_GAP)),
				"music": section == "music",
			}
	return table


func has_sound(name: String) -> bool:
	return _table.has(name)


func names() -> Array:
	return _table.keys()


## Swaps a name's stream and gap (tests play a generated tone through the pool before any file
## lands). Returns the previous {stream, min_gap} so the caller can put them back.
func override_stream(name: String, stream: AudioStream, min_gap: float) -> Dictionary:
	assert(_table.has(name), "Audio: no sound '%s'" % name)
	var entry: Dictionary = _table[name]
	var previous := {"stream": entry["stream"], "min_gap": entry["min_gap"]}
	entry["stream"] = stream
	entry["min_gap"] = min_gap
	return previous


## A game sound: pauses with the tree.
func play(name: String) -> void:
	_play_on(_game_pool, name)


## A menu sound: plays under a paused tree.
func play_ui(name: String) -> void:
	_play_on(_ui_pool, name)


## Switches the music loop with a crossfade; "" fades the music out. A repeat of the current name
## is a no-op. The tween ignores time scale and runs under the pause, so a loop fades in on the
## title and out under a kill freeze alike. A call mid-fade retargets: the previous tween dies.
func music(name: String) -> void:
	if name == current_music:
		return
	if not name.is_empty() and not _table.has(name):
		push_error("Audio: no music '%s' in %s" % [name, TABLE_PATH])
		return
	current_music = name
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var outgoing := _music[_music_live]
	_music_live = 1 - _music_live
	var incoming := _music[_music_live]
	var fading_out := outgoing.playing
	var stream: AudioStream = null
	var volume_db := 0.0
	if not name.is_empty():
		plays[name] = int(plays.get(name, 0)) + 1
		var entry: Dictionary = _table[name]
		stream = entry["stream"]
		volume_db = float(entry["volume_db"])
	if not fading_out and stream == null:
		return  # nothing to fade either way (a missing file): the counters say what happened
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.set_ignore_time_scale(true)
	_music_tween.set_parallel(true)
	if fading_out:
		_music_tween.tween_property(outgoing, "volume_db", SILENT_DB, MUSIC_FADE)
	if stream != null:
		incoming.stream = stream
		incoming.volume_db = SILENT_DB
		incoming.play()
		_music_tween.tween_property(incoming, "volume_db", volume_db, MUSIC_FADE)
	if fading_out:
		_music_tween.chain().tween_callback(outgoing.stop)


func apply(s: Settings) -> void:
	settings = s
	_set_bus("Master", s.volume("master"))
	_set_bus("Sfx", s.volume("sfx"))
	_set_bus("Music", s.volume("music"))


## Clears the counters, stops the music, and reloads the saved volumes. Tests call it between
## cases; the game never does (the title and the run set their own music).
func reset() -> void:
	plays = {}
	_last_play_msec = {}
	current_music = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for p in _music:
		p.stop()
	apply(Settings.load_from())


func _play_on(pool: Array[AudioStreamPlayer], name: String) -> void:
	if not _table.has(name):
		push_error("Audio: no sound '%s' in %s" % [name, TABLE_PATH])
		return
	var entry: Dictionary = _table[name]
	var now := Time.get_ticks_msec()
	var gap_msec := int(float(entry["min_gap"]) * 1000.0)
	if _last_play_msec.has(name) and now - int(_last_play_msec[name]) < gap_msec:
		return
	_last_play_msec[name] = now
	plays[name] = int(plays.get(name, 0)) + 1
	var stream: AudioStream = entry["stream"]
	if stream == null:
		return
	var player := _next_player(pool)
	player.stream = stream
	player.volume_db = float(entry["volume_db"])
	var jitter := float(entry["pitch_jitter"])
	player.pitch_scale = 1.0 + randf_range(-jitter, jitter)  # cosmetic: the global RNG
	player.play()


## A free player, or the one furthest into its sound (it has the least left to lose).
func _next_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	var stolen := pool[0]
	for p in pool:
		if p.get_playback_position() > stolen.get_playback_position():
			stolen = p
	return stolen


func _make_pool(prefix: String, count: int, bus: String, mode: Node.ProcessMode) -> Array[AudioStreamPlayer]:
	var pool: Array[AudioStreamPlayer] = []
	for i in count:
		var p := AudioStreamPlayer.new()
		p.name = "%s%d" % [prefix, i]
		p.bus = bus
		p.process_mode = mode
		add_child(p)
		pool.append(p)
	return pool


func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, "Master")


## linear_to_db(0) is -inf; the floor keeps the bus at a finite silence.
func _set_bus(bus: String, linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), maxf(linear_to_db(linear), SILENT_DB))
