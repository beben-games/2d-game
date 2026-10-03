extends GdUnitTestSuite
## The shipped story (data/story) loads without an error: bad content fails the build. The one
## suite that reads data/story; it checks validity and the cast's ids, never a sentence. What the
## events say, and which events there are, is the writer's: nothing here asks for a placeholder,
## an event, or a shape of the set (the fixture suites prove the system); the lint holds it to the
## writing rule (StoryLint: no warning on the shipped story).


func test_the_shipped_story_loads_clean() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	assert_array(catalog.errors).is_empty()


## The act cheat's presets (data/story/acts.json, placeholders until M9 defines the acts) load
## for every act the title's words name, each landing in the grounds: the catalog's validation
## holds them to the shipped flags and events (an unknown one is a load error, above).
func test_the_shipped_presets_load_for_every_act() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	var acts: Array = catalog.acts.keys()
	acts.sort()
	assert_array(acts).is_equal(StoryCatalog.PRESET_ACTS)
	for act: int in catalog.acts:
		assert_bool(catalog.acts[act]["flags"].get("returned", false)).override_failure_message("act %d returned" % act).is_true()


func test_the_shipped_cast_is_the_seven() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	assert_array(catalog.cast.keys()).contains_exactly_in_any_order(["lanista", "armourer", "veteran", "doctor", "attendant", "narrator", "crowd"])


## Every member who speaks in the box (not timed) has a sprite the atlas knows (the body and the
## portrait) and a bleep that is a sound in data/audio.json, and a timed member's sprite, if any,
## is the atlas's; every room's people and keepers are
## cast ids.
func test_every_speaker_has_a_sprite_and_a_bleep_and_every_person_is_in_the_cast() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	var sounds: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json")) as Dictionary)["sfx"]
	for id: String in catalog.cast:
		var member: Dictionary = catalog.cast[id]
		if member.get("timed", false) == true:
			# A timed member needs no portrait; one it names is the atlas's.
			if member.has("sprite"):
				assert_bool(SpriteAtlas.has(str(member["sprite"]))).override_failure_message("%s: no sprite" % id).is_true()
			continue
		assert_bool(SpriteAtlas.has(str(member.get("sprite", "")))).override_failure_message("%s: no sprite" % id).is_true()
		assert_bool(sounds.has(str(member.get("bleep", "")))).override_failure_message("%s: no bleep" % id).is_true()
	for room_id in GroundsRooms.ids():
		for person: String in GroundsRooms.room(room_id).people:
			assert_bool(catalog.cast.has(person)).override_failure_message("%s: %s is not in the cast" % [room_id, person]).is_true()
		for station: String in GroundsRooms.room(room_id).keepers:
			var keeper := str(GroundsRooms.room(room_id).keepers[station])
			assert_bool(catalog.cast.has(keeper)).override_failure_message("%s: %s's keeper %s is not in the cast" % [room_id, station, keeper]).is_true()


func _catalog() -> StoryCatalog:
	return StoryCatalog.load_dir(StoryCatalog.DATA_DIR)


## The shipped story lints clean (tools/story_lint.sh): no error and no warning, with the project's
## inputs (the word list in data/story, the stations' keepers, the enemy ids, the doors). The check
## that no line names a key lives in the word list now (data/story/lint_words.txt: whole words, any
## case, the writer's to edit).
func test_the_shipped_story_lints_clean() -> void:
	var result := StoryLintInputs.lint(_catalog())
	assert_array(result["errors"]).is_empty()
	var messages: Array[String] = []
	for warning: Dictionary in result["warnings"]:
		messages.append(warning["message"])
	assert_array(messages).is_empty()


## The lint counts the lines and choices still marked PLACEHOLDER (the writer's progress, printed by
## tools/story_lint.sh), as the Story tab's badges count them.
func test_the_lint_counts_the_placeholders_left() -> void:
	var catalog := _catalog()
	var result := StoryLintInputs.lint(catalog)
	var badged := 0
	for event in catalog.events:
		badged += StoryGraph.placeholder_count(event)
	assert_int(result["placeholders"]).is_equal(badged)
	assert_int(result["texts"]).is_greater_equal(result["placeholders"])
	assert_int(result["texts"]).is_greater(0)


## The project's inputs: the word list loads, in lower case; the merchants are the stations' keepers
## (who stand nowhere else); the enemy ids are data/enemies'; the word list is no pool.
func test_the_lints_inputs_from_the_project() -> void:
	var words := StoryLintInputs.words()
	assert_array(words).is_not_empty()
	for word in words:
		assert_str(word).is_equal(word.to_lower())
	var game := StoryLintInputs.game()
	assert_array(game["merchants"]).contains_exactly_in_any_order(["lanista", "armourer"])
	assert_array(game["enemies"]).contains(["boss", "chaser", "chaser_shield", "shooter"])
	assert_array((game["reads"] as Dictionary).values()).contains([["spoliarium_seen"]])
	var catalog := _catalog()
	assert_bool(catalog.cast.has(StoryLint.WORDS_FILE.get_basename())).is_false()
	for message in catalog.errors + catalog.warnings:
		assert_str(message).not_contains(StoryLint.WORDS_FILE)


## The actions whose input a line could name (the bindings the key cap and the title name).
const KEYED_ACTIONS: Array[String] = ["interact", "dash", "pause", "build_screen", "restart", "ui_accept", "shoot"]


## Every key bound to those actions is a `key:` entry of the shipped word list (a mouse button is
## `key: mouse`), named as the key cap names it headless (KeyCap.key_name: the keycode's string), so
## a new binding fails here until its name is added to data/story/lint_words.txt.
func test_the_word_list_names_every_bound_key() -> void:
	var words := StoryLintInputs.words()
	for action in KEYED_ACTIONS:
		for input in InputMap.action_get_events(action):
			var name := ""
			if input is InputEventKey:
				var key := input as InputEventKey
				name = OS.get_keycode_string(key.keycode if key.keycode != KEY_NONE else key.physical_keycode)
			elif input is InputEventMouseButton:
				name = "mouse"
			else:
				continue
			var entry := "%s %s" % [StoryLint.KEY_PREFIX, " ".join(name.to_lower().split(" ", false))]
			assert_bool(words.has(entry)).override_failure_message("%s: '%s' is not in %s" % [action, entry, StoryLint.WORDS_FILE]).is_true()
