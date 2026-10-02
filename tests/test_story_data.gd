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
