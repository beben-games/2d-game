extends GdUnitTestSuite
## The shipped story (data/story) loads without an error: bad content fails the build. The one
## suite that reads data/story; it checks validity and the cast's ids, never a sentence.


func test_the_shipped_story_loads_clean() -> void:
	var catalog := StoryCatalog.load_dir("res://data/story")
	assert_array(catalog.errors).is_empty()


func test_the_shipped_cast_is_the_seven() -> void:
	var catalog := StoryCatalog.load_dir("res://data/story")
	assert_array(catalog.cast.keys()).contains_exactly_in_any_order(["lanista", "armourer", "veteran", "doctor", "attendant", "narrator", "crowd"])
