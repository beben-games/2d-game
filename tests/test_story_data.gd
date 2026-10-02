extends GdUnitTestSuite
## The shipped story (data/story) loads without an error: bad content fails the build. The one
## suite that reads data/story; it checks validity and the cast's ids, never a sentence.


func test_the_shipped_story_loads_clean() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	assert_array(catalog.errors).is_empty()


func test_the_shipped_cast_is_the_seven() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	assert_array(catalog.cast.keys()).contains_exactly_in_any_order(["lanista", "armourer", "veteran", "doctor", "attendant", "narrator", "crowd"])


## Every member who speaks in the box (not timed) has a sprite the atlas knows (the body and the
## portrait) and a bleep that is a sound in data/audio.json; every room's people are cast ids.
func test_every_speaker_has_a_sprite_and_a_bleep_and_every_person_is_in_the_cast() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	var sounds: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json")) as Dictionary)["sfx"]
	for id: String in catalog.cast:
		var member: Dictionary = catalog.cast[id]
		if member.get("timed", false) == true:
			continue
		assert_bool(SpriteAtlas.has(str(member.get("sprite", "")))).override_failure_message("%s: no sprite" % id).is_true()
		assert_bool(sounds.has(str(member.get("bleep", "")))).override_failure_message("%s: no bleep" % id).is_true()
	for room_id in GroundsRooms.ids():
		for person: String in GroundsRooms.room(room_id).people:
			assert_bool(catalog.cast.has(person)).override_failure_message("%s: %s is not in the cast" % [room_id, person]).is_true()


## The pools that speak in the box (every cast member but the timed ones).
const SPEAKERS: Array[String] = ["lanista", "armourer", "veteran", "doctor", "attendant"]
## The merchants: with nothing new, E opens their panel, so they need no bark.
const MERCHANTS: Array[String] = ["lanista", "armourer"]
## The actions whose keys a line must never name.
const KEYED_ACTIONS: Array[String] = ["interact", "dash", "pause", "build_screen", "restart", "ui_accept", "shoot"]


func _catalog() -> StoryCatalog:
	return StoryCatalog.load_dir(StoryCatalog.DATA_DIR)


## Every shown text of the event as written (the marker kept): its lines, its choices, and the
## lines under each choice.
func _texts(event: StoryEvent) -> Array[String]:
	var texts: Array[String] = []
	for entry: Dictionary in event.body:
		match entry["kind"]:
			"line":
				texts.append(entry["text"])
			"choice":
				texts.append(entry["text"])
				for line: Dictionary in entry["lines"]:
					if line["kind"] == "line":
						texts.append(line["text"])
	return texts


## Every line and every choice is a placeholder for the human writing, marked so the box strips
## it and the lint counts it.
func test_every_shipped_line_and_choice_is_a_placeholder() -> void:
	var catalog := _catalog()
	assert_array(catalog.events).is_not_empty()
	for event: StoryEvent in catalog.events:
		for text: String in _texts(event):
			assert_bool(text.begins_with(StoryScript.MARKER + " ")).override_failure_message("%s: '%s' is not marked" % [event.id, text]).is_true()


## No line or choice names a key the game binds (the key cap names it; a line never does): a
## word written as a key's name ("E", "Space", "Escape", "Tab", "R", "Enter", ...) or a mouse's.
func test_no_shipped_line_names_a_key() -> void:
	var names := {"Esc": true, "Click": true, "Mouse": true, "Key": true, "Button": true}
	for action in KEYED_ACTIONS:
		for input in InputMap.action_get_events(action):
			var key := input as InputEventKey
			if key != null:
				names[OS.get_keycode_string(key.keycode if key.keycode != KEY_NONE else key.physical_keycode)] = true
	var words := RegEx.create_from_string("[A-Za-z0-9]+")
	for event: StoryEvent in _catalog().events:
		for text: String in _texts(event):
			for found in words.search_all(StoryScript.strip_marker(text)):
				assert_bool(names.has(found.get_string())).override_failure_message("%s: '%s' names a key" % [event.id, text]).is_false()


## The placeholder set exercises the whole system: per speaker a first word (high, once, needing
## nothing) and a word gated on a win; a repeatable bark for each speaker who is not a merchant;
## the lanista's arrival on the first return (enter ludus, story, once); a word gated on another
## pool's; a choice setting a flag another event reads; a substitution; a line condition; an
## unless. Structure only, never a sentence.
func test_the_placeholder_set_exercises_the_system() -> void:
	var catalog := _catalog()
	for pool in SPEAKERS:
		var first_word := false
		var win_gated := false
		var bark := false
		for event: StoryEvent in catalog.pool(pool):
			if event.trigger != "talk":
				continue
			first_word = first_word or (event.priority == "high" and event.once and event.requires.is_empty() and event.when == null)
			win_gated = win_gated or (event.when != null and "wins" in event.when.names())
			bark = bark or (event.priority == "filler" and not event.once)
		assert_bool(first_word).override_failure_message("%s: no first word" % pool).is_true()
		assert_bool(win_gated).override_failure_message("%s: nothing gated on a win" % pool).is_true()
		assert_bool(bark).override_failure_message("%s: bark" % pool).is_equal(not pool in MERCHANTS)
	var arrival: StoryEvent = catalog.by_id.get("lanista.arrival")
	assert_object(arrival).is_not_null()
	assert_str("%s %s %s %s" % [arrival.trigger, arrival.trigger_arg, arrival.priority, arrival.once]).is_equal("enter ludus story true")
	var across := false
	var unless := false
	var substitution := false
	var line_condition := false
	var set_flags := {}
	var read_flags := {}
	for event: StoryEvent in catalog.events:
		for id in event.requires:
			across = across or not id.begins_with(event.pool + ".")
		unless = unless or not event.unless.is_empty()
		if event.when != null:
			for name in event.when.names():
				read_flags[name] = true
		for entry: Dictionary in event.body:
			if entry["kind"] == "choice":
				for effect: Dictionary in entry["effects"]:
					set_flags[effect["flag"]] = true
			elif entry["kind"] == "line":
				line_condition = line_condition or entry["when"] != null
		for text in _texts(event):
			substitution = substitution or not StoryContext.names_in(text).is_empty()
	var choice_read := false
	for flag: String in set_flags:
		choice_read = choice_read or read_flags.has(flag)
	assert_bool(across).override_failure_message("no word gated on another pool's").is_true()
	assert_bool(unless).override_failure_message("no unless").is_true()
	assert_bool(substitution).override_failure_message("no substitution").is_true()
	assert_bool(line_condition).override_failure_message("no line condition").is_true()
	assert_bool(choice_read).override_failure_message("no choice's flag read by another event").is_true()
