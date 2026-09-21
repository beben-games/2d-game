extends SceneSuite
## The Audio autoload: the buses and pools, the table, silent plays while a file is missing, the
## minimum gap, a real stream on a pool player, and the volumes on the buses. No scene: the base
## is for wall_msec and the after_test hygiene (unpause, Audio.reset).

## Every name the design lists; the table and the code must agree on them.
const LISTED: Array[String] = [
	"shot_handgun", "shot_crossbow", "shot_bounce", "shot_wall", "hit_enemy", "die_imp", "die_shaman",
	"status_burn", "status_shock", "status_chill", "telegraph", "bolt_fire",
	"player_hurt", "player_heal", "player_die", "dash",
	"door_seal", "door_open", "room_enter", "wave_start", "room_clear",
	"ui_open", "ui_close", "ui_hover", "ui_pick", "ui_play",
	"boss_spawn", "boss_telegraph", "boss_ring", "boss_volley", "boss_charge", "boss_summon", "boss_phase", "boss_die",
	"win", "lose", "music_run", "music_boss",
]


## A 0.5 s tone: a file stand-in, so the pool is tested before any file lands. Looping stands in
## for a music file (load_table sets the loop on a loaded stream; override_stream bypasses it).
func _tone(looping := false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := 22050 / 2
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		data.encode_s16(i * 2, int(sin(float(i) * 0.1) * 12000.0))
	wav.data = data
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples
	return wav


func test_buses_exist_and_the_pools_are_built() -> void:
	assert_int(AudioServer.get_bus_index("Sfx")).is_greater(0)
	assert_int(AudioServer.get_bus_index("Music")).is_greater(0)
	assert_int(Audio.get_child_count()).is_equal(Audio.GAME_POOL + Audio.UI_POOL + 2)
	var game: AudioStreamPlayer = Audio.get_node("Game0")
	assert_str(game.bus).is_equal("Sfx")
	assert_int(game.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)
	var ui: AudioStreamPlayer = Audio.get_node("Ui0")
	assert_int(ui.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	var music: AudioStreamPlayer = Audio.get_node("Music1")
	assert_str(music.bus).is_equal("Music")
	assert_int(Audio.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_the_table_lists_every_sound_under_its_folder() -> void:
	assert_array(Audio.names()).contains_exactly_in_any_order(LISTED)
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Audio.TABLE_PATH))
	for section: String in ["sfx", "music"]:
		var entries: Dictionary = parsed[section]
		for name: String in entries:
			var file: String = entries[name]["file"]
			var folder := "music/" if section == "music" else "sfx/"
			assert_str(file).override_failure_message("%s: %s" % [name, file]).starts_with(folder)
			assert_str(file.get_file().get_basename()).is_equal(name)
			assert_bool(name.begins_with("music_")).is_equal(section == "music")


func test_a_play_counts_whether_or_not_its_file_is_present() -> void:
	var previous := Audio.override_stream("hit_enemy", null, 0.0)  # explicitly missing
	Audio.play("hit_enemy")
	assert_int(Audio.plays.get("hit_enemy", 0)).is_equal(1)
	Audio.override_stream("hit_enemy", previous["stream"], float(previous["min_gap"]))
	Audio.play_ui("ui_open")
	assert_int(Audio.plays.get("ui_open", 0)).is_equal(1)
	Audio.music("music_run")
	assert_str(Audio.current_music).is_equal("music_run")
	assert_int(Audio.plays.get("music_run", 0)).is_equal(1)
	Audio.music("music_run")  # a repeat is a no-op
	assert_int(Audio.plays.get("music_run", 0)).is_equal(1)
	Audio.music("")
	assert_str(Audio.current_music).is_equal("")


func test_a_game_sound_under_a_pause_is_dropped() -> void:
	get_tree().paused = true
	Audio.play("dash")
	assert_bool(Audio.plays.has("dash")).is_false()
	get_tree().paused = false


func test_the_minimum_gap_folds_a_volley_into_one_play() -> void:
	Audio.play("shot_handgun")
	Audio.play("shot_handgun")
	Audio.play("shot_handgun")
	assert_int(Audio.plays["shot_handgun"]).is_equal(1)
	await wall_msec(60)
	Audio.play("shot_handgun")
	assert_int(Audio.plays["shot_handgun"]).is_equal(2)


func test_a_present_stream_plays_on_the_pool_and_a_full_pool_steals_the_oldest() -> void:
	var previous := Audio.override_stream("hit_enemy", _tone(), 0.0)
	for i in Audio.GAME_POOL:
		Audio.play("hit_enemy")
	for i in Audio.GAME_POOL:
		var p: AudioStreamPlayer = Audio.get_node("Game%d" % i)
		assert_bool(p.playing).override_failure_message("Game%d" % i).is_true()
	await wall_msec(100)  # at least one mix chunk lands on every player
	# Players started in the same frame drift apart by up to one mix buffer, so find the
	# furthest-along one the way the pool does instead of assuming it is Game0.
	var furthest: AudioStreamPlayer = Audio.get_node("Game0")
	for i in Audio.GAME_POOL:
		var p: AudioStreamPlayer = Audio.get_node("Game%d" % i)
		if p.get_playback_position() > furthest.get_playback_position():
			furthest = p
	var before := furthest.get_playback_position()
	assert_float(before).is_greater(0.05)
	Audio.play("hit_enemy")  # the ninth play restarts the furthest-along player
	assert_float(furthest.get_playback_position()).is_less(before)
	assert_int(Audio.plays["hit_enemy"]).is_equal(Audio.GAME_POOL + 1)
	Audio.override_stream("hit_enemy", previous["stream"], float(previous["min_gap"]))


func test_stop_game_sounds_silences_the_game_pool() -> void:
	var previous := Audio.override_stream("hit_enemy", _tone(), 0.0)
	Audio.play("hit_enemy")
	var playing := 0
	for i in Audio.GAME_POOL:
		if (Audio.get_node("Game%d" % i) as AudioStreamPlayer).playing:
			playing += 1
	assert_int(playing).is_greater_equal(1)
	Audio.stop_game_sounds()
	for i in Audio.GAME_POOL:
		assert_bool((Audio.get_node("Game%d" % i) as AudioStreamPlayer).playing).override_failure_message("Game%d" % i).is_false()
	Audio.override_stream("hit_enemy", previous["stream"], float(previous["min_gap"]))


func test_music_plays_a_present_loop_and_crossfades_to_the_next() -> void:
	var run_previous := Audio.override_stream("music_run", _tone(true), 0.0)
	var boss_previous := Audio.override_stream("music_boss", _tone(true), 0.0)
	Audio.music("music_run")
	var a: AudioStreamPlayer = Audio.get_node("Music1")
	assert_bool(a.playing).is_true()
	Audio.music("music_boss")
	var b: AudioStreamPlayer = Audio.get_node("Music0")
	assert_bool(b.playing).is_true()
	assert_bool(a.playing).is_true()  # still fading out
	await get_tree().create_timer(Audio.MUSIC_FADE + 0.1, true, false, true).timeout
	assert_bool(a.playing).is_false()
	assert_bool(b.playing).is_true()
	Audio.override_stream("music_run", run_previous["stream"], float(run_previous["min_gap"]))
	Audio.override_stream("music_boss", boss_previous["stream"], float(boss_previous["min_gap"]))


func test_a_crossfade_cancelled_mid_fade_still_stops_the_old_loop() -> void:
	var run_previous := Audio.override_stream("music_run", _tone(true), 0.0)
	var boss_previous := Audio.override_stream("music_boss", _tone(true), 0.0)
	Audio.music("music_run")
	Audio.music("music_boss")  # run is fading out on Music1
	Audio.music("")  # kills that fade before Music1's stop fires; boss fades out on Music0
	await get_tree().create_timer(Audio.MUSIC_FADE + 0.1, true, false, true).timeout
	assert_bool((Audio.get_node("Music0") as AudioStreamPlayer).playing).is_false()
	assert_bool((Audio.get_node("Music1") as AudioStreamPlayer).playing).is_false()
	Audio.override_stream("music_run", run_previous["stream"], float(run_previous["min_gap"]))
	Audio.override_stream("music_boss", boss_previous["stream"], float(boss_previous["min_gap"]))


func test_apply_puts_the_volumes_on_the_buses() -> void:
	var s := Settings.new()
	s.set_volume("master", 1.0)
	s.set_volume("sfx", 0.5)
	s.set_volume("music", 0.0)
	Audio.apply(s)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))).is_equal_approx(0.0, 0.01)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Sfx"))).is_equal_approx(-6.02, 0.05)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))).is_equal(Audio.SILENT_DB)


func test_reset_clears_the_counts_and_stops_the_music() -> void:
	Audio.play("dash")
	Audio.music("music_boss")
	Audio.reset()
	assert_bool(Audio.plays.is_empty()).is_true()
	assert_str(Audio.current_music).is_equal("")
	assert_bool((Audio.get_node("Music0") as AudioStreamPlayer).playing).is_false()
	assert_bool((Audio.get_node("Music1") as AudioStreamPlayer).playing).is_false()


## At quit the mixer must have stepped once after the players stop, or the streams playing at
## exit (the boot room's one-shots, the title's loop) are reported leaked: a mixer step moves a
## stopped playback to the server's graveyard, which the server empties on its next update and
## at its own teardown, never after a step that comes too late. A second Audio instance stands
## in for the autoload: leaving the tree runs its release, and after the next update the
## playback of the sound it played is gone. Without the wait it survives unless a step happened
## to land in the release's window.
func test_the_release_at_exit_waits_for_a_mixer_step() -> void:
	var audio: Node = load("res://scripts/autoload/audio.gd").new()
	add_child(audio)
	audio.override_stream("hit_enemy", _tone(), 0.0)
	audio.play("hit_enemy")
	var player: AudioStreamPlayer = audio.get_node("Game0")
	assert_bool(player.playing).is_true()
	var playback: WeakRef = weakref(player.get_stream_playback())  # a weak ref only: an assert on the object would hold it
	assert_bool(playback.get_ref() != null).is_true()
	remove_child(audio)
	audio.free()
	await get_tree().process_frame
	assert_bool(playback.get_ref() == null).override_failure_message("the playback outlived the release").is_true()
