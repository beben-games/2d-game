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
	_refused(edit, edit.delete_event("veteran.hello"), "veteran.hello is still named: veteran.later requires it")
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


## Writes the story's files into the scratch directory (cast.json, flags.txt, and each pool
## given) and loads it from there, as the Story tab loads data/story.
func _load_scratch(pools := _pools()) -> StoryCatalog:
	DirAccess.make_dir_recursive_absolute(_scratch)
	_put(StoryCatalog.CAST_FILE, JSON.stringify(CAST))
	_put(StoryCatalog.FLAGS_FILE, FLAGS)
	for pool: String in pools:
		_put("%s.txt" % pool, pools[pool])
	var catalog := StoryCatalog.load_dir(_scratch)
	assert_array(catalog.errors).is_empty()
	return catalog


func _put(file_name: String, text: String) -> void:
	var file := FileAccess.open(_scratch.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(file_name: String) -> String:
	return FileAccess.get_file_as_string(_scratch.path_join(file_name))


## A pool's text a save would rewrite (the defaults written out): a save of another pool leaves
## its file as it was.
const LANISTA_BY_HAND := "== first
once
trigger: talk

LANISTA: Welcome.

== second
requires: lanista.first

LANISTA: Again.
"


func test_save_writes_only_the_dirty_pools() -> void:
	var edit := StoryEdit.new(_load_scratch({"lanista": LANISTA_BY_HAND, "veteran": VETERAN, "doctor": DOCTOR}))
	assert_array(edit.dirty_pools()).is_empty()
	assert_array(edit.rename("veteran.later", "last")).is_empty()
	assert_array(edit.add_event("armourer", "hello")).is_empty()
	assert_array(edit.save(_scratch)).is_empty()
	assert_str(_read("veteran.txt")).is_equal(edit.catalog.text_of("veteran"))
	assert_str(_read("veteran.txt")).contains("== last\n")
	assert_str(_read("armourer.txt")).is_equal("== hello\n")
	assert_str(_read("lanista.txt")).is_equal(LANISTA_BY_HAND)
	assert_str(_read("doctor.txt")).is_equal(DOCTOR)
	assert_array(edit.dirty_pools()).is_empty()
	# no temporary file is left behind
	for file in DirAccess.get_files_at(_scratch):
		assert_str(file).not_contains(".tmp")
	# the save is the new baseline: a second edit and save of the same pool go through
	assert_array(edit.rename("veteran.last", "later")).is_empty()
	assert_array(edit.dirty_pools()).is_equal(["veteran"])
	assert_array(edit.save(_scratch)).is_empty()
	assert_str(_read("veteran.txt")).is_equal(VETERAN)


## Dirty is a difference from the text loaded or last saved: an edit undone is clean again.
func test_dirty_is_a_difference_from_the_saved_text() -> void:
	var edit := _edit()
	assert_array(edit.add_requires("veteran.hello", "doctor.stitch")).is_empty()
	assert_array(edit.dirty_pools()).is_equal(["doctor"])
	assert_array(edit.remove_requires("veteran.hello", "doctor.stitch")).is_empty()
	assert_array(edit.dirty_pools()).is_empty()
	assert_array(edit.rename("lanista.first", "welcome")).is_empty()
	assert_array(edit.rename("lanista.welcome", "first")).is_empty()
	assert_array(edit.dirty_pools()).is_empty()


## A pool whose comment the parser places after a choice's effect (an indented comment above the
## effect, last in the pool) stays clean and byte-identical through an edit of another pool.
func test_an_edit_leaves_every_untouched_pool_clean() -> void:
	var veteran := "== hello\nrequires: lanista.first\n\nVETERAN: Hello.\n? Nod.\n    VETERAN: Good.\n    # remember this\n    set: met\n"
	var edit := _edit({"lanista": LANISTA, "veteran": veteran, "doctor": DOCTOR})
	var before := {}
	for pool: String in CAST:
		before[pool] = edit.catalog.text_of(pool)
	assert_str(before["veteran"]).contains("# remember this")
	assert_array(edit.add_event("doctor", "more")).is_empty()
	assert_array(edit.dirty_pools()).is_equal(["doctor"])
	for pool: String in ["veteran", "lanista", "armourer"]:
		assert_str(edit.catalog.text_of(pool)).is_equal(before[pool])
	assert_str(edit.catalog.footers["veteran"]).is_equal("remember this")


func test_a_save_into_a_missing_directory_fails_and_keeps_the_pool_dirty() -> void:
	var edit := StoryEdit.new(_load_scratch())
	assert_array(edit.add_event("armourer", "hello")).is_empty()
	var errors := edit.save(_scratch.path_join("nowhere"))
	assert_array(errors).is_not_empty()
	assert_str("\n".join(errors)).contains("armourer.txt")
	assert_array(edit.dirty_pools()).is_equal(["armourer"])
	assert_array(edit.save(_scratch)).is_empty()
	assert_str(_read("armourer.txt")).is_equal("== hello\n")


## A file changed (or made) on disk since the load is not overwritten: reload first.
func test_a_pool_changed_on_disk_since_the_load_is_not_saved() -> void:
	var edit := StoryEdit.new(_load_scratch())
	assert_array(edit.rename("veteran.later", "last")).is_empty()
	_put("veteran.txt", VETERAN + "\n== by_another_hand\n\nVETERAN: Mine.\n")
	var errors := edit.save(_scratch)
	assert_str("\n".join(errors)).contains("veteran.txt").contains("changed on disk since load")
	assert_str(_read("veteran.txt")).contains("by_another_hand")
	assert_array(edit.dirty_pools()).is_equal(["veteran"])
	var fresh := StoryEdit.new(_load_scratch())
	assert_array(fresh.add_event("armourer", "hello")).is_empty()
	_put("armourer.txt", "== someone_elses\n")
	assert_str("\n".join(fresh.save(_scratch))).contains("changed on disk since load")
	assert_str(_read("armourer.txt")).is_equal("== someone_elses\n")


## save_dir writes the pools named, each as text_of; a catalog with errors writes nothing, but
## nothing to write is never an error.
func test_save_dir_writes_the_named_pools_and_loads_back() -> void:
	var catalog := _load_scratch({"lanista": LANISTA_BY_HAND, "veteran": VETERAN, "doctor": DOCTOR})
	assert_array(catalog.save_dir(_scratch, ["lanista", "veteran", "doctor"])).is_empty()
	var loaded := StoryCatalog.load_dir(_scratch)
	assert_array(loaded.errors).is_empty()
	for pool: String in ["lanista", "veteran", "doctor"]:
		assert_str(_read("%s.txt" % pool)).is_equal(catalog.text_of(pool))
		assert_str(loaded.text_of(pool)).is_equal(catalog.text_of(pool))
	assert_array(catalog.save_dir(_scratch, ["crowd"])).is_not_empty()
	assert_bool(FileAccess.file_exists(_scratch.path_join("crowd.txt"))).is_false()
	var broken := StoryCatalog.from_texts(CAST, FLAGS, {"veteran": "== hello\nrequires: lanista.nobody\n\nVETERAN: Hi.\n"})
	assert_array(broken.save_dir(_scratch, ["veteran"])).is_not_empty()
	assert_str(_read("veteran.txt")).is_equal(VETERAN)
	assert_array(broken.save_dir(_scratch, [])).is_empty()


## The panel's errors carry the panel's line numbers: an error the rebuilt catalog finds inside
## the applied event is numbered as in the text passed, like the text's own parse errors.
func test_replace_event_numbers_the_catalogs_errors_in_the_texts_lines() -> void:
	var edit := _edit()
	var errors := edit.replace_event("veteran.later", "# a note\n== later\nrequires: veteran.hello\n\nVETERAN: Fine.\nNOBODY: Hi.\n")
	assert_array(errors).is_equal(["veteran.txt:6: unknown speaker 'NOBODY'"])
	errors = edit.replace_event("veteran.later", "== later\nrequires: veteran.nobody\n\nVETERAN: Fine.\n")
	assert_str(errors[0]).starts_with("veteran.txt:2: unknown event 'veteran.nobody'")
	errors = edit.replace_event("veteran.later", "== later\n\n? Ask.\n    set: nobody_flag\n")
	assert_array(errors).is_equal(["veteran.txt:4: undeclared flag 'nobody_flag' (flags.txt)"])


## An inline comment a rewrite would drop refuses the text, naming its line: nothing is lost
## silently.
func test_replace_event_refuses_an_inline_comment() -> void:
	var edit := _edit()
	var errors := edit.replace_event("veteran.later", "== later\n\nVETERAN: Fine.\nset: met   # a note\n")
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).starts_with("veteran.txt:4: ").contains("inline comment")
	assert_str(edit.catalog.text_of("veteran")).is_equal(VETERAN)


## Two editors on one start catalog: each save moves only its own chain's record of the disk, so
## the second is refused rather than overwriting the first's event.
func test_two_editors_on_one_catalog_cannot_overwrite_each_other() -> void:
	var start := _load_scratch()
	var a := StoryEdit.new(start)
	var b := StoryEdit.new(start)
	assert_array(a.add_event("doctor", "one")).is_empty()
	assert_array(a.save(_scratch)).is_empty()
	assert_array(b.add_event("doctor", "two")).is_empty()
	assert_str("\n".join(b.save(_scratch))).contains("doctor.txt").contains("changed on disk since load")
	assert_str(_read("doctor.txt")).contains("== one\n").not_contains("== two")
	assert_array(b.dirty_pools()).is_equal(["doctor"])


## A comment last under the text's last choice (above the choice's effect in the text) is told
## apart from a comment after the event's last line: each refusal says what is true.
func test_replace_event_tells_a_comment_under_the_last_choice_from_a_trailing_one() -> void:
	var edit := _edit()
	var under := edit.replace_event("veteran.later", "== later\n\n? Nod.\n    # why we set it\n    set: met\n")
	assert_int(under.size()).is_equal(1)
	assert_str(under[0]).contains("last under the event's last choice").not_contains("after the event's last line")
	var after := edit.replace_event("veteran.later", "== later\n\nVETERAN: One.\n# after the last line\n")
	assert_int(after.size()).is_equal(1)
	assert_str(after[0]).contains("after the event's last line")
	assert_str(edit.catalog.text_of("veteran")).is_equal(VETERAN)


## The rebuilt catalog's errors outside the applied text name their event, never a line that
## could be read as the panel's; one inside carries the text's line.
func test_replace_event_names_the_event_of_an_error_outside_the_text() -> void:
	var edit := _edit()
	var errors := edit.replace_event("veteran.hello", "== howdy\nrequires: lanista.first\n\nVETERAN: Hi.\n")
	assert_array(errors).contains(["veteran.later: unknown event 'veteran.hello' in requires"])
	for error in errors:
		assert_str(error).not_contains("veteran.txt:")
	# the applied event is the second of a duplicate: its line, the first's line dropped
	errors = edit.replace_event("veteran.later", "# a note\n== hello\n\nVETERAN: Again.\n")
	assert_array(errors).contains(["veteran.txt:2: duplicate event 'veteran.hello'"])
	# the applied event is the first: the other is named, and the first's line is the text's
	errors = edit.replace_event("veteran.hello", "== later\nrequires: lanista.first\n\nVETERAN: Hi.\n")
	assert_array(errors).contains(["veteran.later: duplicate event 'veteran.later' (first at the text's line 1)"])


## The side panel's header controls: one field set from its value as the file writes it after the
## key ("" is the default, its line left out), in the canonical header order.
func test_set_header_writes_each_field_and_its_default_removes_it() -> void:
	var edit := _edit()
	assert_array(edit.set_header("veteran.later", "priority", "high")).is_empty()
	assert_array(edit.set_header("veteran.later", "repeat", "repeat")).is_empty()
	assert_array(edit.set_header("veteran.later", "trigger", "enter ludus")).is_empty()
	assert_array(edit.set_header("veteran.later", "act", "2")).is_empty()
	assert_array(edit.set_header("veteran.later", "when", "wins >= 1 and not met")).is_empty()
	assert_str(edit.catalog.text_of("veteran")).contains("# the later word\n== later\nrequires: veteran.hello\nwhen: wins >= 1 and not met\npriority: high\nrepeat\ntrigger: enter ludus\nact: 2\n\nVETERAN: Later.\n")
	var later: StoryEvent = edit.catalog.by_id["veteran.later"]
	assert_str(later.priority).is_equal("high")
	assert_bool(later.once).is_false()
	assert_str(later.trigger_arg).is_equal("ludus")
	assert_int(later.act).is_equal(2)
	assert_array(edit.dirty_pools()).is_equal(["veteran"])
	assert_array(edit.set_header("veteran.later", "priority", "normal")).is_empty()
	assert_array(edit.set_header("veteran.later", "repeat", "once")).is_empty()
	assert_array(edit.set_header("veteran.later", "trigger", "")).is_empty()
	assert_array(edit.set_header("veteran.later", "act", "")).is_empty()
	assert_array(edit.set_header("veteran.later", "when", "  ")).is_empty()
	assert_str(edit.catalog.text_of("veteran")).is_equal(VETERAN)
	assert_array(edit.dirty_pools()).is_empty()


## A value the parser or the catalog refuses is refused with its reason, named by the event, and
## changes nothing.
func test_set_header_refuses_a_bad_value_with_the_reason() -> void:
	var edit := _edit()
	_refused(edit, edit.set_header("veteran.later", "act", "4"), "veteran.later: act 4 is not 1 to 3")
	_refused(edit, edit.set_header("veteran.later", "priority", "urgent"), "veteran.later: unknown priority 'urgent'")
	_refused(edit, edit.set_header("veteran.later", "trigger", "enter forum"), "veteran.later: unknown room 'forum'")
	_refused(edit, edit.set_header("veteran.later", "repeat", "often"), "veteran.later: ")
	_refused(edit, edit.set_header("veteran.later", "when", "wins >="), "veteran.later: when: ")
	_refused(edit, edit.set_header("veteran.later", "when", "nobody_knows"), "veteran.later: when: unknown name 'nobody_knows'")
	_refused(edit, edit.set_header("veteran.later", "when", "met # why"), "inline comment")
	_refused(edit, edit.set_header("veteran.later", "when", "met\n\nVETERAN: Injected."), "one line")
	_refused(edit, edit.set_header("veteran.later", "requires", "lanista.first"), "not a header field")
	_refused(edit, edit.set_header("veteran.later", "colour", "red"), "not a header field")
	_refused(edit, edit.set_header("veteran.nobody", "act", "1"), "unknown event")
	# the catalog's own check: a timed trigger on an event with choices
	var with_choice := "== hello\n\nVETERAN: Hello.\n? Nod.\n"
	var choosy := _edit({"lanista": LANISTA, "veteran": with_choice})
	var errors: Array[String] = choosy.set_header("veteran.hello", "trigger", "pick")
	assert_str("\n".join(errors)).contains("veteran.hello: a timed event has no choices")
	assert_str(choosy.catalog.text_of("veteran")).is_equal(with_choice)


## header_value is what set_header takes back: setting each field to it changes nothing.
func test_header_value_round_trips_through_set_header() -> void:
	var catalog := StoryCatalog.load_dir("res://tests/support/story")
	assert_array(catalog.errors).is_empty()
	var edit := StoryEdit.new(catalog)
	var before := {}
	for pool: String in catalog.cast:
		before[pool] = edit.catalog.text_of(pool)
	for event in catalog.events:
		for key in StoryEdit.HEADER_FIELDS:
			assert_array(edit.set_header(event.id, key, StoryEdit.header_value(event, key))).override_failure_message("%s %s" % [event.id, key]).is_empty()
	for pool: String in catalog.cast:
		assert_str(edit.catalog.text_of(pool)).is_equal(before[pool])
	var warning: StoryEvent = catalog.by_id["veteran.the_warning"]
	assert_str(StoryEdit.header_value(warning, "when")).is_equal("deaths >= 1 and not veteran_distant")
	assert_str(StoryEdit.header_value(warning, "repeat")).is_equal("repeat")
	assert_str(StoryEdit.header_value(warning, "act")).is_equal("2")
	assert_str(StoryEdit.header_value(catalog.by_id["lanista.arrival"], "trigger")).is_equal("enter ludus")
	assert_str(StoryEdit.header_value(catalog.by_id["veteran.hello"], "act")).is_equal("")


## The graph's edge by its kind: requires and unless are made and removed; a flag link is derived
## from the events' set: and when:, never drawn, and says so.
func test_links_by_kind_and_a_flag_link_is_refused() -> void:
	var edit := _edit()
	assert_array(edit.add_link(StoryLinks.REQUIRES, "veteran.hello", "doctor.stitch")).is_empty()
	assert_array(edit.add_link(StoryLinks.UNLESS, "veteran.later", "doctor.stitch")).is_empty()
	assert_str(edit.catalog.text_of("doctor")).is_equal("== stitch\nrequires: veteran.hello\nunless: lanista.first, veteran.later\n\nDOCTOR: Hold still.\n")
	assert_array(edit.remove_link(StoryLinks.REQUIRES, "veteran.hello", "doctor.stitch")).is_empty()
	assert_array(edit.remove_link(StoryLinks.UNLESS, "veteran.later", "doctor.stitch")).is_empty()
	assert_str(edit.catalog.text_of("doctor")).is_equal(DOCTOR)
	_refused(edit, edit.add_link(StoryLinks.FLAG, "veteran.hello", "doctor.stitch"), "set:")
	_refused(edit, edit.remove_link(StoryLinks.FLAG, "veteran.hello", "doctor.stitch"), "when:")


## The line of a replace_event error in the text it was given (0 for none): the side panel marks
## that line.
func test_text_line_reads_the_line_of_a_texts_error() -> void:
	assert_int(StoryEdit.text_line("veteran.txt:6: unknown speaker 'NOBODY'")).is_equal(6)
	assert_int(StoryEdit.text_line("veteran.txt: the text holds 2 events: an Apply takes one")).is_equal(0)
	assert_int(StoryEdit.text_line("veteran.later: unknown event 'veteran.hello' in requires")).is_equal(0)
	assert_int(StoryEdit.text_line("the story has errors")).is_equal(0)
	var edit := _edit()
	var errors := edit.replace_event("veteran.later", "# a note\n== later\n\nVETERAN: Fine.\nNOBODY: Hi.\n")
	assert_int(StoryEdit.text_line(errors[0])).is_equal(5)


## A name the pool does not hold yet, for a new event: the stem, then the stem numbered.
func test_unused_name() -> void:
	var edit := _edit()
	assert_str(edit.unused_name("doctor")).is_equal("new_event")
	assert_array(edit.add_event("doctor", edit.unused_name("doctor"))).is_empty()
	assert_str(edit.unused_name("doctor")).is_equal("new_event_2")
	assert_array(edit.add_event("doctor", edit.unused_name("doctor"))).is_empty()
	assert_str(edit.unused_name("doctor")).is_equal("new_event_3")
	assert_str(edit.unused_name("veteran", "later")).is_equal("later_2")


## A refusal of a link, a rename, or a delete names events, never a line of the rewrite it tried
## (those lines are in no file the writer has), and a delete's cascade comes down to its first
## cause.
func test_a_refusal_names_events_not_the_rewrites_lines() -> void:
	var edit := _edit()
	var cycle := edit.add_requires("lanista.second", "lanista.first")
	assert_str("\n".join(cycle)).contains("a cycle of requires")
	_no_lines(cycle)
	var named := edit.delete_event("lanista.first")
	assert_int(named.size()).is_equal(1)
	assert_str(named[0]).starts_with("lanista.first is still named: ").contains(" it")
	_no_lines(named)
	assert_array(edit.delete_event("doctor.stitch")).is_empty()
	assert_array(edit.delete_event("veteran.hello")).is_equal(["veteran.hello is still named: veteran.later requires it"] as Array[String])
	var unless := _edit()
	assert_array(unless.add_unless("veteran.later", "doctor.stitch")).is_empty()
	assert_array(unless.delete_event("veteran.later")).is_equal(["veteran.later is still named: doctor.stitch has it in its unless"] as Array[String])
	_no_lines(edit.rename("lanista.first", "second"))


func _no_lines(errors: Array[String]) -> void:
	var at_line := RegEx.create_from_string("^[a-z][a-z0-9_]*\\.txt:\\d+:")
	for error in errors:
		assert_object(at_line.search(error)).override_failure_message("a rewrite's line in: " + error).is_null()


## Several events deleted as one: the dependants first whatever the order given, and all or
## nothing: one still named from outside the set refuses the lot, naming the blocker.
func test_delete_events_is_all_or_nothing() -> void:
	var edit := _edit()
	assert_array(edit.delete_events(["veteran.hello", "veteran.later"] as Array[String])).is_empty()
	assert_bool(edit.catalog.by_id.has("veteran.hello")).is_false()
	assert_bool(edit.catalog.by_id.has("veteran.later")).is_false()
	var blocked := _edit()
	_refused(blocked, blocked.delete_events(["lanista.second", "lanista.first"] as Array[String]), "lanista.first is still named: ")
	_refused(blocked, blocked.delete_events(["lanista.second", "lanista.nobody"] as Array[String]), "unknown event")


## A draft that follows a rename: its `==` line takes the new name when it still names the old.
func test_with_name_rewrites_the_events_head() -> void:
	assert_str(StoryEdit.with_name("# a note\n== later\nrequires: veteran.hello\n\nVETERAN: Later.\n", "later", "afterwards")).is_equal("# a note\n== afterwards\nrequires: veteran.hello\n\nVETERAN: Later.\n")
	assert_str(StoryEdit.with_name("  ==   later\n\nVETERAN: Later.", "later", "afterwards")).is_equal("  ==   afterwards\n\nVETERAN: Later.")
	assert_str(StoryEdit.with_name("== other\n\nVETERAN: Later.", "later", "afterwards")).is_equal("== other\n\nVETERAN: Later.")
	assert_str(StoryEdit.with_name("VETERAN: == later\n== later", "later", "afterwards")).is_equal("VETERAN: == later\n== afterwards")
