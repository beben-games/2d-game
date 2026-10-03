extends GdUnitTestSuite
## StoryEdit: the Story tab's edits over a catalog, each checked in the pools' written text; an
## edit that would leave the catalog invalid (a cycle, a duplicate, a name another event still
## names) is refused with the catalog's errors and changes nothing; only the touched pools are
## dirty; a save writes only those (StoryCatalog.save_dir). Pure: the story comes from texts, and
## the save goes to a per-process scratch directory under user://, removed after each test.

const CAST := {
	"veteran": {"name": "PLACEHOLDER Veteran"},
	"lanista": {"name": "PLACEHOLDER Lanista"},
	"doctor": {"name": "PLACEHOLDER Doctor"},
	"armourer": {"name": "PLACEHOLDER Armourer"},
}
const FLAGS := "met\n"
## Three pools that name lanista.first (its own pool, the veteran's requires, the doctor's
## unless); the armourer has no file.
const LANISTA := "# The lanista's pool.\n\n== first\n\nLANISTA: Welcome.\n\n== second\nrequires: lanista.first\n\nLANISTA: Again.\n\n# the footer\n"
const VETERAN := "== hello\nrequires: lanista.first\n\nVETERAN: Hello.\n\n# the later word\n== later\nrequires: veteran.hello\n\nVETERAN: Later.\n"
const DOCTOR := "== stitch\nunless: lanista.first\n\nDOCTOR: Hold still.\n"

var _scratch := ""


func before_test() -> void:
	_scratch = "user://story_edit_%d" % OS.get_process_id()


func after_test() -> void:
	var dir := DirAccess.open(_scratch)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(_scratch)


func _pools() -> Dictionary:
	return {"lanista": LANISTA, "veteran": VETERAN, "doctor": DOCTOR}


func _edit(pools := _pools()) -> StoryEdit:
	var catalog := StoryCatalog.from_texts(CAST, FLAGS, pools)
	assert_array(catalog.errors).is_empty()
	return StoryEdit.new(catalog)


## The edit refused: errors given, every pool's text as it was, nothing dirty.
func _refused(edit: StoryEdit, errors: Array[String], contains: String) -> void:
	assert_array(errors).override_failure_message("not refused").is_not_empty()
	if not errors.is_empty():
		assert_str("\n".join(errors)).contains(contains)
	assert_str(edit.catalog.text_of("lanista")).is_equal(LANISTA)
	assert_str(edit.catalog.text_of("veteran")).is_equal(VETERAN)
	assert_str(edit.catalog.text_of("doctor")).is_equal(DOCTOR)
	assert_str(edit.catalog.text_of("armourer")).is_equal("")
	assert_array(edit.dirty_pools()).is_empty()


func test_the_start_is_the_files_and_nothing_is_dirty() -> void:
	var edit := _edit()
	assert_str(edit.catalog.text_of("lanista")).is_equal(LANISTA)
	assert_str(edit.catalog.headers["lanista"]).is_equal("The lanista's pool.")
	assert_str(edit.catalog.footers["lanista"]).is_equal("the footer")
	assert_array(edit.dirty_pools()).is_empty()


## add_requires(from, to) is the graph's edge: `to` gains `from` in its requires.
func test_add_and_remove_requires() -> void:
	var edit := _edit()
	assert_array(edit.add_requires("veteran.hello", "doctor.stitch")).is_empty()
	assert_str(edit.catalog.text_of("doctor")).is_equal("== stitch\nrequires: veteran.hello\nunless: lanista.first\n\nDOCTOR: Hold still.\n")
	assert_array(edit.catalog.by_id["doctor.stitch"].requires).is_equal(["veteran.hello"])
	assert_array(edit.dirty_pools()).is_equal(["doctor"])
	assert_array(edit.remove_requires("veteran.hello", "doctor.stitch")).is_empty()
	assert_str(edit.catalog.text_of("doctor")).is_equal(DOCTOR)


func test_remove_requires_leaves_the_rest_of_the_list() -> void:
	var edit := _edit()
	assert_array(edit.add_requires("doctor.stitch", "veteran.later")).is_empty()
	assert_str(edit.catalog.text_of("veteran")).contains("== later\nrequires: veteran.hello, doctor.stitch\n")
	assert_array(edit.remove_requires("veteran.hello", "veteran.later")).is_empty()
	assert_str(edit.catalog.text_of("veteran")).contains("== later\nrequires: doctor.stitch\n")
	assert_array(edit.remove_requires("lanista.first", "lanista.second")).is_empty()
	assert_str(edit.catalog.text_of("lanista")).is_equal("# The lanista's pool.\n\n== first\n\nLANISTA: Welcome.\n\n== second\n\nLANISTA: Again.\n\n# the footer\n")
	assert_array(edit.dirty_pools()).is_equal(["veteran", "lanista"])


func test_add_and_remove_unless() -> void:
	var edit := _edit()
	assert_array(edit.add_unless("doctor.stitch", "veteran.hello")).is_empty()
	assert_str(edit.catalog.text_of("veteran")).is_equal("== hello\nrequires: lanista.first\nunless: doctor.stitch\n\nVETERAN: Hello.\n\n# the later word\n== later\nrequires: veteran.hello\n\nVETERAN: Later.\n")
	assert_array(edit.dirty_pools()).is_equal(["veteran"])
	assert_array(edit.remove_unless("lanista.first", "doctor.stitch")).is_empty()
	assert_str(edit.catalog.text_of("doctor")).is_equal("== stitch\n\nDOCTOR: Hold still.\n")
	assert_array(edit.dirty_pools()).is_equal(["veteran", "doctor"])


func test_a_link_already_there_or_not_there_or_to_nothing_is_refused() -> void:
	var edit := _edit()
	_refused(edit, edit.add_requires("lanista.first", "veteran.hello"), "already requires")
	_refused(edit, edit.remove_requires("doctor.stitch", "veteran.hello"), "does not require")
	_refused(edit, edit.add_unless("lanista.first", "doctor.stitch"), "already")
	_refused(edit, edit.remove_unless("veteran.hello", "doctor.stitch"), "does not")
	_refused(edit, edit.add_requires("lanista.nobody", "veteran.hello"), "unknown event 'lanista.nobody'")
	_refused(edit, edit.add_unless("veteran.hello", "veteran.nobody\n== injected"), "unknown event")


func test_a_cycle_is_refused_with_the_catalogs_error() -> void:
	var edit := _edit()
	_refused(edit, edit.add_requires("lanista.second", "lanista.first"), "a cycle of requires")
	_refused(edit, edit.add_requires("veteran.later", "lanista.first"), "a cycle of requires")
	_refused(edit, edit.add_requires("doctor.stitch", "doctor.stitch"), "a cycle of requires")


func test_add_event() -> void:
	var edit := _edit()
	assert_array(edit.add_event("doctor", "rinse")).is_empty()
	assert_str(edit.catalog.text_of("doctor")).is_equal(DOCTOR + "\n== rinse\n")
	assert_bool(edit.catalog.by_id.has("doctor.rinse")).is_true()
	assert_array(edit.dirty_pools()).is_equal(["doctor"])


## A pool with no file gets its first event (the file is written at the save).
func test_add_event_to_a_pool_without_a_file() -> void:
	var edit := _edit()
	assert_array(edit.add_event("armourer", "hello")).is_empty()
	assert_str(edit.catalog.text_of("armourer")).is_equal("== hello\n")
	assert_array(edit.dirty_pools()).is_equal(["armourer"])


func test_add_event_refuses_a_duplicate_a_bad_name_or_a_pool_not_in_the_cast() -> void:
	var edit := _edit()
	_refused(edit, edit.add_event("lanista", "second"), "duplicate event 'lanista.second'")
	_refused(edit, edit.add_event("lanista", "two words"), "not a name")
	_refused(edit, edit.add_event("lanista", "x\n== y"), "not a name")
	_refused(edit, edit.add_event("crowd", "boo"), "not in the cast")


func test_delete_event() -> void:
	var edit := _edit()
	assert_array(edit.delete_event("veteran.later")).is_empty()
	assert_str(edit.catalog.text_of("veteran")).is_equal("== hello\nrequires: lanista.first\n\nVETERAN: Hello.\n")
	assert_bool(edit.catalog.by_id.has("veteran.later")).is_false()
	assert_array(edit.dirty_pools()).is_equal(["veteran"])


## An event another event names (requires or unless) stays: the catalog's error says who.
func test_delete_event_refuses_a_named_event() -> void:
	var edit := _edit()
	_refused(edit, edit.delete_event("lanista.first"), "lanista.first")
	_refused(edit, edit.delete_event("veteran.hello"), "unknown event 'veteran.hello' in requires")
	_refused(edit, edit.delete_event("veteran.nobody"), "unknown event")


## A rename follows every requires and unless in every pool, and keeps the comments.
func test_a_rename_follows_through_three_pools() -> void:
	var edit := _edit()
	assert_array(edit.rename("lanista.first", "welcome")).is_empty()
	assert_str(edit.catalog.text_of("lanista")).is_equal("# The lanista's pool.\n\n== welcome\n\nLANISTA: Welcome.\n\n== second\nrequires: lanista.welcome\n\nLANISTA: Again.\n\n# the footer\n")
	assert_str(edit.catalog.text_of("veteran")).is_equal(VETERAN.replace("lanista.first", "lanista.welcome"))
	assert_str(edit.catalog.text_of("doctor")).is_equal("== stitch\nunless: lanista.welcome\n\nDOCTOR: Hold still.\n")
	assert_bool(edit.catalog.by_id.has("lanista.welcome")).is_true()
	assert_bool(edit.catalog.by_id.has("lanista.first")).is_false()
	# the cast's order
	assert_array(edit.dirty_pools()).is_equal(["veteran", "lanista", "doctor"])


func test_a_rename_touches_only_the_pools_that_name_it() -> void:
	var edit := _edit()
	assert_array(edit.rename("veteran.later", "last")).is_empty()
	assert_str(edit.catalog.text_of("veteran")).contains("# the later word\n== last\n")
	assert_array(edit.dirty_pools()).is_equal(["veteran"])
	assert_array(edit.rename("veteran.last", "last")).is_empty()
	assert_array(edit.dirty_pools()).is_equal(["veteran"])


func test_a_rename_to_a_name_taken_or_of_no_shape_is_refused() -> void:
	var edit := _edit()
	_refused(edit, edit.rename("lanista.first", "second"), "duplicate event 'lanista.second'")
	_refused(edit, edit.rename("lanista.first", "lanista.second"), "not a name")
	_refused(edit, edit.rename("lanista.nobody", "x"), "unknown event")


## The side panel's Apply: one event's text in the file's format replaces the event.
func test_replace_event() -> void:
	var edit := _edit()
	var text := "# a new note\n== later\nrequires: veteran.hello\nrepeat\n\nVETERAN: Later, again.\n? Nod.\n    set: met\n"
	assert_array(edit.replace_event("veteran.later", text)).is_empty()
	assert_str(edit.catalog.text_of("veteran")).is_equal("== hello\nrequires: lanista.first\n\nVETERAN: Hello.\n\n" + text)
	assert_bool(edit.catalog.by_id["veteran.later"].once).is_false()
	assert_array(edit.dirty_pools()).is_equal(["veteran"])


## The panel shows an event as StoryScript.write_event writes it; applying that changes nothing.
func test_replace_event_with_its_own_text_changes_nothing() -> void:
	var edit := _edit()
	var text := StoryScript.write_event(edit.catalog.by_id["veteran.later"])
	assert_str(text).is_equal("# the later word\n== later\nrequires: veteran.hello\n\nVETERAN: Later.")
	assert_array(edit.replace_event("veteran.later", text)).is_empty()
	assert_array(edit.dirty_pools()).is_empty()


func test_replace_event_returns_the_texts_errors_and_keeps_the_event() -> void:
	var edit := _edit()
	_refused(edit, edit.replace_event("veteran.later", "== later\n\nVETERAN: Fine.\nmood: grim\n"), "veteran.txt:4: unknown effect 'mood'")
	_refused(edit, edit.replace_event("veteran.later", "== later\n\nVETERAN: One.\n\n== more\n\nVETERAN: Two.\n"), "2 events")
	_refused(edit, edit.replace_event("veteran.later", ""), "0 events")
	_refused(edit, edit.replace_event("veteran.later", "== later\n\nVETERAN: One.\n# after the last line\n"), "after the event's last line")
	_refused(edit, edit.replace_event("veteran.later", "== later\n\nNOBODY: Hi.\n"), "unknown speaker 'NOBODY'")
	# a new name in the text while another event names the old one
	_refused(edit, edit.replace_event("veteran.hello", "== howdy\n\nVETERAN: Hi.\n"), "unknown event 'veteran.hello'")


## A block above the event's `==` across a blank line is still the event's comment.
func test_replace_event_keeps_a_comment_across_a_blank() -> void:
	var edit := _edit()
	assert_array(edit.replace_event("doctor.stitch", "# one\n\n# two\n== stitch\nunless: lanista.first\n\nDOCTOR: Hold still.\n")).is_empty()
	assert_str(edit.catalog.text_of("doctor")).is_equal("# one\n# two\n" + DOCTOR)


func test_a_catalog_with_errors_refuses_every_edit() -> void:
	var catalog := StoryCatalog.from_texts(CAST, FLAGS, {"veteran": "== hello\nrequires: lanista.nobody\n\nVETERAN: Hi.\n\n== fine\n\nVETERAN: Fine.\n"})
	assert_array(catalog.errors).is_not_empty()
	var edit := StoryEdit.new(catalog)
	var errors := edit.add_event("veteran", "more")
	assert_str("\n".join(errors)).contains("unknown event 'lanista.nobody'")
	assert_bool(edit.catalog.by_id.has("veteran.more")).is_false()
	assert_array(edit.dirty_pools()).is_empty()


func test_save_writes_only_the_dirty_pools() -> void:
	DirAccess.make_dir_recursive_absolute(_scratch)
	var edit := _edit()
	assert_array(edit.rename("veteran.later", "last")).is_empty()
	assert_array(edit.add_event("armourer", "hello")).is_empty()
	assert_array(edit.save(_scratch)).is_empty()
	assert_array(DirAccess.get_files_at(_scratch)).contains_exactly_in_any_order(["veteran.txt", "armourer.txt"])
	assert_str(FileAccess.get_file_as_string(_scratch.path_join("veteran.txt"))).is_equal(edit.catalog.text_of("veteran"))
	assert_str(FileAccess.get_file_as_string(_scratch.path_join("armourer.txt"))).is_equal("== hello\n")
	assert_array(edit.dirty_pools()).is_empty()


## save_dir writes the pools named, each as text_of; a catalog with errors writes nothing.
func test_save_dir_writes_the_named_pools_and_loads_back() -> void:
	DirAccess.make_dir_recursive_absolute(_scratch)
	var cast_file := FileAccess.open(_scratch.path_join(StoryCatalog.CAST_FILE), FileAccess.WRITE)
	cast_file.store_string(JSON.stringify(CAST))
	cast_file.close()
	var flags_file := FileAccess.open(_scratch.path_join(StoryCatalog.FLAGS_FILE), FileAccess.WRITE)
	flags_file.store_string(FLAGS)
	flags_file.close()
	var catalog := StoryCatalog.from_texts(CAST, FLAGS, _pools())
	assert_array(catalog.save_dir(_scratch, ["lanista", "veteran", "doctor"])).is_empty()
	var loaded := StoryCatalog.load_dir(_scratch)
	assert_array(loaded.errors).is_empty()
	for pool: String in ["lanista", "veteran", "doctor"]:
		assert_str(loaded.text_of(pool)).is_equal(catalog.text_of(pool))
	assert_str(FileAccess.get_file_as_string(_scratch.path_join("lanista.txt"))).is_equal(LANISTA)
	var broken := StoryCatalog.from_texts(CAST, FLAGS, {"veteran": "== hello\nrequires: lanista.nobody\n\nVETERAN: Hi.\n"})
	DirAccess.remove_absolute(_scratch.path_join("veteran.txt"))
	assert_array(broken.save_dir(_scratch, ["veteran"])).is_not_empty()
	assert_bool(FileAccess.file_exists(_scratch.path_join("veteran.txt"))).is_false()
	assert_array(catalog.save_dir(_scratch, ["crowd"])).is_not_empty()
	assert_bool(FileAccess.file_exists(_scratch.path_join("crowd.txt"))).is_false()
