extends GdUnitTestSuite
## The Story tab's controller (addons/story_graph/story_session.gd) without the scene: drafts that
## survive every edit elsewhere and follow a rename, a drag decided at its end (a move all or
## nothing, a click put back, a stale pick-up forgotten), the side panel's edits, the multi-delete,
## the saves (the editor's applying the drafts first). The story comes from texts; a save goes to
## a per-process scratch directory under user://, removed after each test.

const Session := preload("res://addons/story_graph/story_session.gd")
const CAST := {"lanista": {"name": "PLACEHOLDER Lanista"}, "veteran": {"name": "PLACEHOLDER Veteran"}}
const FLAGS := "met\n"
const LANISTA := "== first\n\nLANISTA: Welcome.\n\n== second\nrequires: lanista.first\n\nLANISTA: Again.\n"
const VETERAN := "== hello\nrequires: lanista.first\n\nVETERAN: Hello.\n? Nod.\n    set: met\n\n== later\nwhen: met\n\nVETERAN: Later.\n"
const DRAFT := "== later\nwhen: met\n\nVETERAN: Not yet.\n"

var _scratch := ""


func before_test() -> void:
	_scratch = "user://story_session_%d" % OS.get_process_id()


func after_test() -> void:
	var dir := DirAccess.open(_scratch)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(_scratch)


func _session() -> Session:
	var catalog := StoryCatalog.from_texts(CAST, FLAGS, {"lanista": LANISTA, "veteran": VETERAN})
	assert_array(catalog.errors).is_empty()
	return Session.new(catalog)


## A session on the story written to the scratch directory (a save's target).
func _saved_session() -> Session:
	DirAccess.make_dir_recursive_absolute(_scratch)
	_put("cast.json", JSON.stringify(CAST))
	_put("flags.txt", FLAGS)
	_put("lanista.txt", LANISTA)
	_put("veteran.txt", VETERAN)
	return Session.new(StoryCatalog.load_dir(_scratch))


func _put(file: String, text: String) -> void:
	var handle := FileAccess.open(_scratch.path_join(file), FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


func _read(file: String) -> String:
	return FileAccess.get_file_as_string(_scratch.path_join(file))


func _requires(session: Session, id: String) -> Array[String]:
	return (session.edit.catalog.by_id[id] as StoryEvent).requires


## A drag's signals in GraphEdit's order.
static func _drag(session: Session, kind: String, from_id: String, to_id: String) -> Session.Outcome:
	session.drag_started(from_id, kind, true)
	session.connection_requested(kind, from_id, to_id)
	return session.drag_ended(Vector2.ZERO)


## Bug 1: text not applied survives a link between two other events, an edge removed, an event
## added, another deleted; an edit of its own event keeps it and says so.
func test_a_draft_survives_edits_elsewhere() -> void:
	var session := _session()
	session.selected = "veteran.later"
	session.note_text("veteran.later", DRAFT)
	assert_bool(_drag(session, StoryLinks.REQUIRES, "veteran.hello", "lanista.second").made).is_true()
	assert_str(session.panel_text("veteran.later")).is_equal(DRAFT)
	assert_bool(session.link(StoryLinks.REQUIRES, "veteran.hello", "lanista.second", false).made).is_true()
	assert_bool(session.add_event("lanista", "third").made).is_true()
	assert_bool(session.delete(["lanista.third"] as Array[String]).made).is_true()
	assert_str(session.panel_text("veteran.later")).is_equal(DRAFT)
	var under := _drag(session, StoryLinks.REQUIRES, "lanista.first", "veteran.later")
	assert_bool(under.made).is_true()
	assert_str(session.panel_text("veteran.later")).is_equal(DRAFT)
	assert_str(under.notice).contains("veteran.later changed under its text not applied")
	# said once: the next edit elsewhere does not repeat it
	assert_str(session.link(StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true).notice).is_empty()
	# a draft equal to its event is none; a deleted event's draft goes with it
	session.note_text("veteran.later", session.model.text("veteran.later"))
	assert_bool(session.has_draft("veteran.later")).is_false()
	session.note_text("veteran.later", DRAFT)
	assert_bool(session.delete(["veteran.later"] as Array[String]).made).is_true()
	assert_dict(session.drafts).is_empty()
	assert_str(session.selected).is_empty()


## Bug 2: a picked-up edge dropped where the new link is refused: the old edge stays, the Outcome
## is the refusal, nothing is unsaved.
func test_a_refused_move_changes_nothing() -> void:
	var session := _session()
	session.disconnection_requested(StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2(10, 10))
	session.drag_started("lanista.first", StoryLinks.REQUIRES, true)
	session.connection_requested(StoryLinks.REQUIRES, "lanista.second", "lanista.first")
	var outcome := session.drag_ended(Vector2(300, 200))
	assert_bool(outcome.made).is_false()
	assert_str(outcome.notice).contains("Refused").contains("cycle")
	assert_array(_requires(session, "lanista.second")).is_equal(["lanista.first"])
	assert_array(_requires(session, "lanista.first")).is_empty()
	assert_array(session.dirty_pools()).is_empty()
	# a move that is allowed: the new link added, the old removed, one Outcome
	session.disconnection_requested(StoryLinks.REQUIRES, "lanista.first", "veteran.hello", Vector2(10, 10))
	session.drag_started("lanista.first", StoryLinks.REQUIRES, true)
	session.connection_requested(StoryLinks.REQUIRES, "lanista.first", "veteran.later")
	assert_bool(session.drag_ended(Vector2(300, 200)).made).is_true()
	assert_array(_requires(session, "veteran.hello")).is_empty()
	assert_array(_requires(session, "veteran.later")).is_equal(["lanista.first"])


## Bug 3: a draft follows a rename with its `==` line renamed, so Apply keeps the new name.
func test_apply_after_a_rename_keeps_the_new_name() -> void:
	var session := _session()
	session.selected = "veteran.later"
	session.note_text("veteran.later", DRAFT)
	assert_bool(session.rename("veteran.later", "afterwards").made).is_true()
	assert_str(session.selected).is_equal("veteran.afterwards")
	assert_str(session.panel_text("veteran.afterwards")).starts_with("== afterwards\n")
	assert_bool(session.apply().made).is_true()
	assert_bool(session.edit.catalog.by_id.has("veteran.afterwards")).is_true()
	assert_bool(session.edit.catalog.by_id.has("veteran.later")).is_false()
	assert_str(session.edit.catalog.text_of("veteran")).contains("== afterwards\nwhen: met\n\nVETERAN: Not yet.")


## Item 5: a pick-up released within the reach of where it began is a click: put back. Farther,
## it is removed.
func test_a_click_puts_the_edge_back() -> void:
	var session := _session()
	session.reach = 4.0
	session.disconnection_requested(StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2(100, 100))
	session.drag_started("lanista.first", StoryLinks.REQUIRES, true)
	assert_bool(session.drag_ended(Vector2(103, 101)).made).is_false()
	assert_array(_requires(session, "lanista.second")).is_equal(["lanista.first"])
	session.disconnection_requested(StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2(100, 100))
	session.drag_started("lanista.first", StoryLinks.REQUIRES, true)
	assert_bool(session.drag_ended(Vector2(100, 120)).made).is_true()
	assert_array(_requires(session, "lanista.second")).is_empty()


## Bug 6: a pick-up a new drag does not continue is forgotten; its end removes nothing.
func test_a_stale_pick_up_is_forgotten() -> void:
	var session := _session()
	session.disconnection_requested(StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2(100, 100))
	session.drag_started("veteran.hello", StoryLinks.REQUIRES, true)
	assert_bool(session.is_picking()).is_false()
	assert_bool(session.drag_ended(Vector2(500, 500)).made).is_false()
	assert_array(_requires(session, "lanista.second")).is_equal(["lanista.first"])
	# a drag that continues the pick-up keeps it
	session.disconnection_requested(StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2(100, 100))
	session.drag_started("lanista.first", StoryLinks.REQUIRES, true)
	assert_bool(session.is_picking()).is_true()


## Item 10: several events deleted as one gesture, all or nothing.
func test_a_multi_delete_is_one_gesture() -> void:
	var session := _session()
	var refused := session.delete(["lanista.first", "lanista.second"] as Array[String])
	assert_bool(refused.made).is_false()
	assert_str(refused.notice).contains("lanista.first is still named: veteran.hello requires it")
	assert_bool(session.edit.catalog.by_id.has("lanista.second")).is_true()
	assert_array(session.dirty_pools()).is_empty()
	var made := session.delete(["lanista.first", "lanista.second", "veteran.hello", "veteran.later"] as Array[String])
	assert_bool(made.made).is_true()
	assert_bool(made.redraw).is_true()
	assert_array(session.edit.catalog.events).is_empty()


## The side panel: a header field waits for the draft; a field's refusal and an Apply's go to the
## panel, never the notice; the when field's text not set is kept per event.
func test_the_panels_edits() -> void:
	var session := _session()
	session.selected = "veteran.later"
	session.note_text("veteran.later", DRAFT)
	var held := session.set_field("priority", "high")
	assert_str(" ".join(held.panel_errors)).contains("Apply or Revert")
	assert_bool(held.keep_notice).is_true()
	session.revert()
	assert_bool(session.set_field("priority", "high").made).is_true()
	session.note_when("veteran.later", "nobody_knows")
	var refused := session.set_field("when", "nobody_knows")
	assert_str(" ".join(refused.panel_errors)).contains("unknown name")
	assert_str(session.when_text("veteran.later")).is_equal("nobody_knows")
	assert_str(session.when_text("veteran.hello")).is_empty()
	assert_bool(session.set_field("when", "not met").made).is_true()
	assert_bool(session.has_when_draft("veteran.later")).is_false()
	session.note_text("veteran.later", "== later\n\nVETERAN: Fine.\nmood: grim\n")
	var bad := session.apply()
	assert_str(bad.panel_errors[0]).starts_with("veteran.txt:4: ")
	assert_bool(session.has_draft()).is_true()


## The panel always shows a selected event: the shown one while selected, else the first selected
## in the graph's order, else none.
func test_next_shown() -> void:
	var session := _session()
	session.selected = "veteran.later"
	assert_str(session.next_shown(["veteran.later", "lanista.first"] as Array[String])).is_equal("veteran.later")
	assert_str(session.next_shown(["veteran.hello", "lanista.second"] as Array[String])).is_equal("lanista.second")
	assert_str(session.next_shown([] as Array[String])).is_empty()


## The editor's save writes the unsaved pools and never applies a draft (the writer's to Apply):
## a draft whose event changed under it (a requires dragged in) stays as it is, the requires is
## kept in the session and the file, and the notice names the event whose text was not saved.
func test_the_editors_save_never_applies_a_draft() -> void:
	var session := _saved_session()
	session.selected = "veteran.later"
	session.note_text("veteran.later", DRAFT)
	var under := _drag(session, StoryLinks.REQUIRES, "lanista.first", "veteran.later")
	assert_str(under.notice).contains("changed under its text not applied")
	var outcome := session.save_external(_scratch)
	assert_array(_requires(session, "veteran.later")).is_equal(["lanista.first"])
	assert_str(_read("veteran.txt")).contains("== later\nrequires: lanista.first\nwhen: met\n\nVETERAN: Later.")
	assert_str(session.panel_text("veteran.later")).is_equal(DRAFT)
	assert_str(outcome.notice).contains("Saved veteran.txt").contains("not saved").contains("veteran.later")
	assert_bool(outcome.alert).is_false()
	assert_str(session.unsaved_status()).contains("veteran.later").contains("unapplied text will be lost")
	# a draft alone: nothing written, the notice says so
	var alone := session.save_external(_scratch)
	assert_str(alone.notice).contains("veteran.later")
	assert_str(session.panel_text("veteran.later")).is_equal(DRAFT)
	# a save refused (changed on disk) is listed, not a dialog
	assert_bool(session.link(StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true).made).is_true()
	_put("lanista.txt", LANISTA + "\n== by_hand\n\nLANISTA: Mine.\n")
	var refused := session.save_external(_scratch)
	assert_bool(refused.alert).is_false()
	assert_str(refused.notice).contains("changed on disk after the tab read it")
	assert_str(" ".join(session.save_errors)).contains("changed on disk since load")
	# the Save button's own save alerts
	assert_bool(session.save(_scratch).alert).is_true()


## A draft whose event changed under it stays flagged through every redraw until Apply or Revert;
## an Apply of a flagged draft still applies (the writer's act) and says the event had changed.
func test_a_draft_changed_under_stays_flagged_until_apply_or_revert() -> void:
	var session := _session()
	session.selected = "veteran.later"
	session.note_text("veteran.later", DRAFT)
	assert_bool(session.draft_changed("veteran.later")).is_false()
	_drag(session, StoryLinks.REQUIRES, "lanista.first", "veteran.later")
	assert_bool(session.draft_changed("veteran.later")).is_true()
	assert_bool(session.link(StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true).made).is_true()
	assert_bool(session.draft_changed("veteran.later")).is_true()
	session.note_text("veteran.later", DRAFT + "VETERAN: More.\n")
	assert_bool(session.draft_changed("veteran.later")).is_true()
	var applied := session.apply()
	assert_bool(applied.made).is_true()
	assert_str(applied.notice).contains("veteran.later changed since its text was opened")
	assert_bool(session.has_draft("veteran.later")).is_false()
	# Revert clears the flag too
	session.note_text("veteran.later", DRAFT)
	_drag(session, StoryLinks.REQUIRES, "veteran.hello", "veteran.later")
	assert_bool(session.draft_changed("veteran.later")).is_true()
	session.revert("veteran.later")
	session.note_text("veteran.later", DRAFT)
	assert_bool(session.draft_changed("veteran.later")).is_false()


## The lint runs with every graph (the load and each edit made), with the inputs handed in, its
## warnings on the model; the catalog's own warnings stay the load's list. It never dirties a pool.
func test_the_lint_runs_with_every_graph_and_dirties_nothing() -> void:
	var catalog := StoryCatalog.from_texts(CAST, "met\nnodded\n", {"lanista": LANISTA.replace("LANISTA: Welcome.\n", "LANISTA: Welcome.\nset: nodded   # why\n"), "veteran": VETERAN})
	var session := Session.new(catalog, {"words": ["again"] as Array[String], "game": {}})
	var kinds: Array[String] = []
	for warning in session.lint_warnings():
		kinds.append(warning["kind"])
	assert_array(kinds).is_equal([StoryLint.FLAG_UNREAD, StoryLint.WORD])
	assert_array(session.warnings).has_size(1)  # the inline comment: the load's list, not the lint's
	assert_int(session.model.badges("lanista.first")["lint"]).is_equal(1)
	assert_int(session.model.badges("lanista.second")["lint"]).is_equal(1)
	assert_bool(session.has_unsaved()).is_false()
	assert_array(session.dirty_pools()).is_empty()
	session.selected = "veteran.later"
	assert_bool(session.set_field("when", "met and nodded").made).is_true()
	kinds.clear()
	for warning in session.lint_warnings():
		kinds.append(warning["kind"])
	assert_array(kinds).is_equal([StoryLint.WORD])
	assert_int(session.model.badges("lanista.first")["lint"]).is_equal(0)
