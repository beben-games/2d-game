extends GdUnitTestSuite
## The shipped story (data/story) loads without an error: bad content fails the build. The one
## suite that reads data/story; it checks validity and the cast's ids, never a sentence. What the
## events say, and which events there are, is the writer's: nothing here asks for a placeholder,
## an event, or a shape of the set (the fixture suites prove the system).

## The actions whose keys a line must never name.
const KEYED_ACTIONS: Array[String] = ["interact", "dash", "pause", "build_screen", "restart", "ui_accept", "shoot"]


func test_the_shipped_story_loads_clean() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	assert_array(catalog.errors).is_empty()


func test_the_shipped_cast_is_the_seven() -> void:
	var catalog := StoryCatalog.load_dir(StoryCatalog.DATA_DIR)
	assert_array(catalog.cast.keys()).contains_exactly_in_any_order(["lanista", "armourer", "veteran", "doctor", "attendant", "narrator", "crowd"])


## Every member who speaks in the box (not timed) has a sprite the atlas knows (the body and the
## portrait) and a bleep that is a sound in data/audio.json; every room's people and keepers are
## cast ids.
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
		for station: String in GroundsRooms.room(room_id).keepers:
			var keeper := str(GroundsRooms.room(room_id).keepers[station])
			assert_bool(catalog.cast.has(keeper)).override_failure_message("%s: %s's keeper %s is not in the cast" % [room_id, station, keeper]).is_true()


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
