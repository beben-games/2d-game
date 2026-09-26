extends Node
## Every sound in the game. Listens to the bus like Fx and plays one-shots from data/audio.json
## (name -> file, volume, pitch jitter, minimum gap). A listed file
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
## At quit: the most the release waits for a mixer step after the players stop. The headless
## Dummy driver steps every ~93 ms (4096 frames at 44.1 kHz), a real driver every few ms;
## only a dead mixer reaches the cap.
const RELEASE_TIMEOUT_MSEC := 1000
## enemy_died by the enemy's def id; an unknown id squeals like an imp.
const DEATH_SOUNDS := {"chaser": "die_imp", "chaser_shield": "die_imp", "shooter": "die_shaman", "boss": "boss_die"}
const STATUS_SOUNDS := {"burn": "status_burn", "stun": "status_shock", "chill": "status_chill"}
## boss_attacked patterns with a sound of their own; charge_end and charge_wall are silent.
const BOSS_PATTERN_SOUNDS := {"ring": "boss_ring", "volley": "boss_volley", "charge": "boss_charge", "summon": "boss_summon"}
## round_ended's band to the crowd's sound at the round's end (FavourRules is a rules class, not a gameplay node).
const CROWD_SOUNDS := {
	FavourRules.BOO: "crowd_boo", FavourRules.QUIET: "crowd_quiet",
	FavourRules.CHEER: "crowd_cheer", FavourRules.ROAR: "crowd_roar",
}

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
	apply(Settings.load_from())
	_table = load_table(TABLE_PATH)
	_game_pool = _make_pool("Game", GAME_POOL, "Sfx", Node.PROCESS_MODE_PAUSABLE)
	_ui_pool = _make_pool("Ui", UI_POOL, "Sfx", Node.PROCESS_MODE_ALWAYS)
	_music = _make_pool("Music", 2, "Music", Node.PROCESS_MODE_ALWAYS)
	_connect()


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
					_loop(stream)
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


## Music loops whatever its format: a WAV needs its loop points (the whole file), an Ogg its flag.
static func _loop(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		stream.set("loop", true)
		return
	var bytes_per_sample := 1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2
	var channels := 2 if wav.stereo else 1
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / (bytes_per_sample * channels)


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


## A game sound: pauses with the tree. One requested under a pause is dropped (no count, no
## player): PAUSABLE only pauses playbacks that already exist, so a new one would sound.
func play(name: String) -> void:
	if get_tree().paused:
		return
	_play_on(_game_pool, name)


## Stops every game sound: the title silences the boot's sounds, frozen under its pause, so they
## never resume next to the rebuilt arena's own on Play.
func stop_game_sounds() -> void:
	for p in _game_pool:
		p.stop()


## A menu sound: plays under a paused tree.
func play_ui(name: String) -> void:
	_play_on(_ui_pool, name)


## Cuts a UI sound still playing (the drum roll under the thumb): every UI player carrying its
## stream. A name whose file is missing plays nothing and has nothing to stop.
func stop_ui(name: String) -> void:
	for p in _ui_players_of(name):
		p.stop()


## Whether a UI player still carries the name's stream (the roll through the build-up).
func is_playing_ui(name: String) -> bool:
	return not _ui_players_of(name).is_empty()


func _ui_players_of(name: String) -> Array[AudioStreamPlayer]:
	var found: Array[AudioStreamPlayer] = []
	if not _table.has(name):
		push_error("Audio: no sound '%s' in %s" % [name, TABLE_PATH])
		return found
	var stream: AudioStream = _table[name]["stream"]
	if stream == null:
		return found
	for p in _ui_pool:
		if p.playing and p.stream == stream:
			found.append(p)
	return found


## Switches the music loop with a crossfade; "" fades the music out. A repeat of the current name
## is a no-op. The tween ignores time scale and runs under the pause, so a loop fades in on the
## title and out under a kill freeze alike. A call mid-fade retargets: the previous tween dies.
func music(name: String) -> void:
	if name == current_music:
		return
	if not name.is_empty() and not _table.has(name):
		push_error("Audio: no music '%s' in %s" % [name, TABLE_PATH])
		return
	if not name.is_empty() and not bool(_table[name]["music"]):
		push_error("Audio: '%s' is a sound; use play()" % name)
		return
	current_music = name
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var outgoing := _music[_music_live]
	_music_live = 1 - _music_live
	var incoming := _music[_music_live]
	incoming.stop()  # a killed fade may have left it carrying the loop before last
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
	_music_live = 0
	apply(Settings.load_from())


func _play_on(pool: Array[AudioStreamPlayer], name: String) -> void:
	if not _table.has(name):
		push_error("Audio: no sound '%s' in %s" % [name, TABLE_PATH])
		return
	var entry: Dictionary = _table[name]
	if bool(entry["music"]):
		push_error("Audio: '%s' is music; use music()" % name)
		return
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


## A free player, or the one that has been playing longest (the oldest is stolen).
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


## For an autoload this runs only at quit; kept for symmetry with Fx, which the design mirrors.
func _exit_tree() -> void:
	for pair: Array in _handlers():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)
	_release_streams()


## At quit a playing stream and its playback are reported as leaked (the mixer drops a stopped
## playback on its next step, and the exit reaches the audio server's teardown first; the boot
## gate fails on the ERROR line), so every player is stopped and emptied, the mixer is waited
## for until a step has begun after the stops, and the table is let go before the autoload
## dies. get_time_since_last_mix takes the driver lock, so a step it reports as begun has also
## finished, and with it the stopped playbacks sit in the server's graveyard, which its own
## teardown empties. A fixed delay was wrong: the headless step is ~93 ms, so 50 ms covered only
## the exits whose remaining teardown made up the rest. Runs only at quit for an autoload.
func _release_streams() -> void:
	for pool: Array[AudioStreamPlayer] in [_game_pool, _ui_pool, _music]:
		for p in pool:
			p.stop()
			p.stream = null
	var stopped := Time.get_ticks_usec()
	while Time.get_ticks_usec() - stopped < RELEASE_TIMEOUT_MSEC * 1000:
		var since_mix_usec := AudioServer.get_time_since_last_mix() * 1_000_000.0
		if since_mix_usec < float(Time.get_ticks_usec() - stopped):
			break  # a step began after the stops and has finished: the playbacks are in the graveyard
		OS.delay_msec(1)
	_table = {}


func _connect() -> void:
	for pair: Array in _handlers():
		var sig: Signal = pair[0]
		sig.connect(pair[1])


## The event-to-sound map, one row per bus signal.
func _handlers() -> Array[Array]:
	return [
		[Events.shot_fired, _on_shot_fired], [Events.shot_bounced, _on_shot_bounced],
		[Events.shot_hit_wall, _on_shot_hit_wall], [Events.shot_blocked, _on_shot_blocked],
		[Events.enemy_hit, _on_enemy_hit],
		[Events.enemy_died, _on_enemy_died], [Events.status_applied, _on_status_applied],
		[Events.enemy_telegraphed, _on_enemy_telegraphed], [Events.enemy_fired, _on_enemy_fired],
		[Events.player_hit, _on_player_hit], [Events.player_healed, _on_player_healed],
		[Events.player_fell, _on_player_fell], [Events.mercy_granted, _on_mercy_granted],
		[Events.player_dashed, _on_player_dashed],
		[Events.verdict_drum, _on_verdict_drum], [Events.verdict_given, _on_verdict_given],
		[Events.card_revealed, _on_card_revealed], [Events.offer_rerolled, _on_offer_rerolled],
		[Events.round_started, _on_round_started], [Events.wave_started, _on_wave_started],
		[Events.round_cleared, _on_round_cleared], [Events.round_ended, _on_round_ended],
		[Events.run_won, _on_run_won],
		[Events.grounds_entered, _on_grounds_entered], [Events.training_bought, _on_training_bought],
		[Events.purchase_denied, _on_purchase_denied], [Events.upgrade_chosen, _on_upgrade_chosen],
		[Events.menu_opened, _on_menu_opened], [Events.menu_closed, _on_menu_closed],
		[Events.card_hovered, _on_card_hovered], [Events.boss_spawned, _on_boss_spawned],
		[Events.boss_phase_changed, _on_boss_phase_changed], [Events.boss_attacked, _on_boss_attacked],
		[Events.coin_landed, _on_coin_landed], [Events.coins_thrown, _on_coins_thrown],
		[Events.pile_collected, _on_pile_collected],
	]


func _on_shot_fired(_at: Vector2, _direction: Vector2, weapon_id: String) -> void:
	play("shot_" + weapon_id)


func _on_shot_bounced(_at: Vector2) -> void:
	play("shot_bounce")


func _on_shot_hit_wall(_at: Vector2) -> void:
	play("shot_wall")


func _on_shot_blocked(_at: Vector2) -> void:
	play("shot_shield")


## A burn tick is a quiet hit: no sound, as it has no flash. Duck-typed: any static reference to
## a gameplay Node class (Health, Enemy, Player) from this autoload leaks scripts at quit in
## 4.7.2 (a teardown-only load-order artifact; check_boot reports the leaked instances).
func _on_enemy_hit(enemy: Node2D, _damage: float, _at: Vector2) -> void:
	var health: Node = enemy.get_node_or_null("Health")
	if health != null and bool(health.get("last_hit_quiet")):
		return
	play("hit_enemy")


func _on_enemy_died(enemy: Node2D, _at: Vector2) -> void:
	var def: Variant = enemy.get("def")  # Variant like RunState's: a test's stub def is a RefCounted
	var id := str(def.get("id")) if def != null else ""
	play(str(DEATH_SOUNDS.get(id, "die_imp")))


func _on_status_applied(_enemy: Node2D, kind: String) -> void:
	play(str(STATUS_SOUNDS[kind]))


func _on_enemy_telegraphed(enemy: Node2D) -> void:
	play("boss_telegraph" if enemy.is_in_group("boss") else "telegraph")


func _on_enemy_fired(_enemy: Node2D, _at: Vector2) -> void:
	play("bolt_fire")


func _on_player_hit(_damage: int, _hp: int, _max_hp: int, _attacker_id: String) -> void:
	play("player_hurt")


## On the UI pool: a heal only ever happens under the picker (the Heal card), where the tree is
## paused and play() would drop it.
func _on_player_healed(_hp: int, _max_hp: int) -> void:
	play_ui("player_heal")


## The fall and the crowd's hush on the UI pool: the gate screen pauses the tree a couple of
## seconds later and a game sound would freeze under it.
func _on_player_fell(_at: Vector2, _attacker_id: String) -> void:
	play_ui("player_die")
	play_ui("crowd_hush")
	music("")


## The drum roll under the build-up (the camera's drift to the box and the held pause), on the
## UI pool like the hush; it runs until the thumb cuts it.
func _on_verdict_drum() -> void:
	play_ui("verdict_roll")


## The thumb's sound after a fall, on the UI pool for the same reason as the hush; the roll is
## cut first (the file outlasts the build-up).
func _on_verdict_given(up: bool) -> void:
	stop_ui("verdict_roll")
	play_ui("verdict_up" if up else "verdict_down")


func _on_player_dashed(_at: Vector2, _direction: Vector2) -> void:
	play("dash")


## The first round's start is the run's: its loop takes over from the grounds' (or the title's,
## which shares it, so Play never restarts it).
func _on_round_started(index: int, _total: int) -> void:
	play("room_enter")
	if index == 0:
		music("music_run")


func _on_wave_started(_index: int, _total: int) -> void:
	play("wave_start")


func _on_round_cleared() -> void:
	play("room_clear")


## The crowd's verdict on the UI pool: the picker pauses the tree a beat later and a game sound
## would freeze under it, while the crowd should still be heard over the cards.
func _on_round_ended(band: int) -> void:
	play_ui(CROWD_SOUNDS[band])


## The crowd's fourth card sliding into the picker: the roar again, on the UI pool under the pause.
func _on_card_revealed() -> void:
	play_ui("crowd_roar")


## The emperor's mercy: the crowd roars (the crowd's sounds live on the UI pool).
func _on_mercy_granted(_at: Vector2) -> void:
	play_ui("crowd_roar")


## A rerolled offer: the picker's open sound again, on the UI pool under the pause.
func _on_offer_rerolled() -> void:
	play_ui("ui_open")


## The win's fanfare (a win asks no emperor: no thumb, no verdict_given) and the loop's end.
func _on_run_won() -> void:
	music("")
	play_ui("verdict_up")


func _on_grounds_entered() -> void:
	music("music_grounds")


func _on_training_bought(_line: String, _rank: int) -> void:
	play("buy")


func _on_purchase_denied(_line: String) -> void:
	play("buy_denied")


func _on_upgrade_chosen(_card: UpgradeDef, _rank: int) -> void:
	play_ui("ui_pick")


func _on_menu_opened(name: String) -> void:
	match name:
		"upgrade", "build":
			play_ui("ui_open")
		"title":
			music("music_run")  # two loops in the game: the title shares the run's, so Play never restarts it


func _on_menu_closed(name: String) -> void:
	match name:
		"upgrade", "build":
			play_ui("ui_close")
		"title":
			play_ui("ui_play")
		"gate":
			play_ui("gate")  # the gate passed: the tree is paused under the screen


func _on_card_hovered() -> void:
	play_ui("ui_hover")


func _on_boss_spawned(_boss: Node2D) -> void:
	play("boss_spawn")
	music("music_boss")


func _on_boss_phase_changed(_phase: int) -> void:
	play("boss_phase")


func _on_boss_attacked(pattern: String, _at: Vector2) -> void:
	if BOSS_PATTERN_SOUNDS.has(pattern):
		play(str(BOSS_PATTERN_SOUNDS[pattern]))


## A flight's arrival at the counter; a volley of kills folds into the gap.
func _on_coin_landed() -> void:
	play("coin_get")


## One toss per throw, however many piles it makes.
func _on_coins_thrown(_at: Vector2, _total: int) -> void:
	play("coin_toss")


func _on_pile_collected(_at: Vector2, _value: int) -> void:
	play("coin_pickup")
