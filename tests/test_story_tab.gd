extends GdUnitTestSuite
## The Story tab (addons/story_graph/story_tab.tscn) outside the editor, on the fixture story: a
## node per event in its character's lane, an edge per link on its kind's port, the filters and the
## search dimming what they leave out, the side panel's text, the error list selecting its event, and
## Reload reading a file edited on disk. Editing (Task 13) runs on a story written into a
## per-process scratch directory (never the fixture's or data/story), each gesture driven through
## the handler its GraphEdit or button signal is connected to. The pure parts are StoryEdit's,
## StoryGraph's, StoryLayout's, and StoryLinks' suites; what needs eyes and a mouse (the lanes' look,
## the colours, a real drag) is the hand checklist.

const TAB := "res://addons/story_graph/story_tab.tscn"
const EventNode := preload("res://addons/story_graph/event_node.gd")
const FIXTURE := "res://tests/support/story"
const CAST := {"lanista": {"name": "PLACEHOLDER Lanista"}, "veteran": {"name": "PLACEHOLDER Veteran"}}

var _scratch := ""


func before_test() -> void:
	_scratch = "user://story_tab_%d" % OS.get_process_id()


func after_test() -> void:
	var dir := DirAccess.open(_scratch)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(_scratch)


## The tab in the tree and built (the plugin builds it on its first showing).
func _tab(story_dir := FIXTURE, node_floor := Vector2.ZERO) -> Node:
	var tab: Node = (load(TAB) as PackedScene).instantiate()
	tab.set("dir", story_dir)
	tab.set("node_floor", node_floor)
	add_child(auto_free(tab))
	tab.call("ensure_built")
	return tab


func _nodes(tab: Node) -> Dictionary:
	return tab.get("nodes")


func _dimmed(tab: Node) -> Array[String]:
	var out: Array[String] = []
	var nodes := _nodes(tab)
	for id: String in nodes:
		if (nodes[id] as Node).call("is_dimmed"):
			assert_object((nodes[id] as CanvasItem).modulate).is_not_equal(Color.WHITE)
			out.append(id)
	out.sort()
	return out


func test_a_node_per_event_in_its_lane() -> void:
	var tab := _tab()
	var catalog := StoryCatalog.load_dir(FIXTURE)
	var nodes := _nodes(tab)
	assert_int(nodes.size()).is_equal(catalog.events.size())
	var lanes: Dictionary = tab.get("lanes")
	assert_array(lanes.keys()).is_equal(catalog.cast.keys())
	var seen := {}
	for id: String in nodes:
		var node: GraphNode = nodes[id]
		var frame: GraphFrame = lanes[(catalog.by_id[id] as StoryEvent).pool]
		assert_float(node.position_offset.y).is_greater_equal(frame.position_offset.y)
		assert_float(node.position_offset.y).is_less(frame.position_offset.y + frame.size.y)
		assert_bool(seen.has(node.position_offset)).is_false()
		seen[node.position_offset] = id
		assert_str(node.title).is_equal((catalog.by_id[id] as StoryEvent).name)


func test_an_edge_per_link_on_its_kinds_port() -> void:
	var tab := _tab()
	var events := StoryCatalog.load_dir(FIXTURE).events
	var graph: GraphEdit = tab.get("graph")
	var by_port := {}
	for connection: Dictionary in graph.get_connection_list():
		assert_int(connection["from_port"]).is_equal(connection["to_port"])
		by_port[connection["from_port"]] = int(by_port.get(connection["from_port"], 0)) + 1
	assert_int(by_port.get(0, 0)).is_equal(StoryLinks.requires_edges(events).size())
	assert_int(by_port.get(1, 0)).is_equal(StoryLinks.unless_edges(events).size())
	assert_int(by_port.get(2, 0)).is_equal(StoryLinks.flag_edges(events).size())
	assert_int(graph.get_connection_list().size()).is_equal(StoryLinks.edges(events).size())


func test_the_search_dims_what_does_not_match() -> void:
	var tab := _tab()
	assert_array(_dimmed(tab)).is_empty()
	(tab.get_node("%Search") as LineEdit).text = "carried"
	assert_int(tab.call("apply_filters")).is_equal(1)
	var dimmed := _dimmed(tab)
	assert_bool(dimmed.has("lanista.after_first_win")).is_false()
	assert_int(dimmed.size()).is_equal(_nodes(tab).size() - 1)


func test_the_character_and_act_filters_dim_the_rest() -> void:
	var tab := _tab()
	var character: OptionButton = tab.get_node("%Character")
	for i in character.item_count:
		if character.get_item_metadata(i) == "veteran":
			character.select(i)
	tab.call("apply_filters")
	for id: String in _nodes(tab):
		assert_bool(_dimmed(tab).has(id)).is_equal(not id.begins_with("veteran."))
	var act: OptionButton = tab.get_node("%Act")
	for i in act.item_count:
		if act.get_item_metadata(i) == 2:
			act.select(i)
	assert_int(tab.call("apply_filters")).is_equal(1)
	assert_bool(_dimmed(tab).has("veteran.the_warning")).is_false()


func test_selecting_shows_the_text() -> void:
	var tab := _tab()
	tab.call("select_event", "veteran.hello")
	var model: StoryGraph = tab.get("model")
	assert_str((tab.get_node("%Title") as Label).text).is_equal("veteran.hello")
	assert_str((tab.get_node("%Text") as TextEdit).text).is_equal(model.text("veteran.hello"))
	# a clean story's loaded event is editable (a story with errors is not: see the errors' test)
	assert_bool((tab.get_node("%Text") as TextEdit).editable).is_true()
	var graph: GraphEdit = tab.get("graph")
	assert_bool((_nodes(tab)["veteran.hello"] as GraphNode).selected).is_true()
	graph.node_selected.emit(_nodes(tab)["lanista.bark"])
	assert_str(tab.get("selected")).is_equal("lanista.bark")


func test_the_errors_list_and_select_their_event() -> void:
	var tab := _tab()
	var errors: ItemList = tab.get_node("%Errors")
	# the fixture loads clean: its list holds only the lint's warnings (Task 15)
	for i in errors.item_count:
		assert_str(errors.get_item_text(i)).starts_with("lint: ")
	var broken := StoryCatalog.from_texts(CAST, "", {
		"lanista": "== good\n\nLANISTA: Hm.\n\n== bad\n\nNOBODY: Hm.\n",
		"veteran": "== later\nrequires: lanista.bad\n\nVETERAN: Hm.\n",
	})
	tab.call("show_catalog", broken)
	assert_bool(errors.visible).is_true()
	# a stub says it was not parsed rather than showing a default's facts
	var stubbed := StoryCatalog.from_texts(CAST, "", {"lanista": "== odd\npriority: urgent\n\nLANISTA: Hm.\n"})
	tab.call("show_catalog", stubbed)
	tab.call("select_event", "lanista.odd")
	assert_str((tab.get_node("%Facts") as Label).text).contains("Not parsed")
	assert_str((tab.get_node("%Facts") as Label).text).not_contains("trigger talk")
	assert_str(_row_text(_nodes(tab)["lanista.odd"])).contains("not parsed")
	assert_str(_row_text(_nodes(tab)["lanista.odd"])).not_contains("talk")
	tab.call("show_catalog", broken)
	assert_int(errors.item_count).is_equal(broken.errors.size())
	assert_int(_nodes(tab).size()).is_equal(3)
	# a story with errors is read only: the text and the header controls wait for the files' fix
	tab.call("select_event", "lanista.good")
	assert_bool((tab.get_node("%Text") as TextEdit).editable).is_false()
	assert_bool((tab.get_node("%EventPriority") as OptionButton).disabled).is_true()
	# only item_clicked selects (item_selected too would select twice)
	assert_array(errors.item_selected.get_connections()).is_empty()
	for i in errors.item_count:
		errors.item_clicked.emit(i, Vector2.ZERO, MOUSE_BUTTON_LEFT)
		var target: String = errors.get_item_metadata(i)
		assert_str(tab.get("selected")).is_equal(target)
		assert_str((tab.get_node("%Facts") as Label).text).contains(errors.get_item_text(i))
	assert_array(StoryGraph.of(broken).errors_of.keys()).contains_exactly_in_any_order(["lanista.bad", "veteran.later"])


func test_reload_reads_a_file_edited_on_disk() -> void:
	DirAccess.make_dir_recursive_absolute(_scratch)
	_write("cast.json", JSON.stringify(CAST))
	_write("lanista.txt", "== first\n\nLANISTA: Hm.\n")
	var tab := _tab(_scratch)
	assert_array(_nodes(tab).keys()).is_equal(["lanista.first"])
	(tab.get_node("%Search") as LineEdit).text = "second"
	_write("lanista.txt", "== first\n\nLANISTA: Hm.\n\n== second\nrequires: lanista.first\n\nLANISTA: Again.\n")
	(tab.get_node("%Reload") as Button).pressed.emit()
	assert_array(_nodes(tab).keys()).is_equal(["lanista.first", "lanista.second"])
	assert_array(_dimmed(tab)).is_equal(["lanista.first"])
	assert_int((tab.get("graph") as GraphEdit).get_connection_list().size()).is_equal(1)


func _write(file: String, text: String) -> void:
	var handle := FileAccess.open(_scratch.path_join(file), FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


## The text of a node's rows (its trigger, once or repeat, its badges).
static func _row_text(node: Node) -> String:
	var texts: PackedStringArray = []
	for label in node.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return " | ".join(texts)


func test_it_builds_on_its_first_showing_only() -> void:
	var tab: Node = (load(TAB) as PackedScene).instantiate()
	tab.set("dir", FIXTURE)
	add_child(auto_free(tab))
	assert_dict(_nodes(tab)).is_empty()
	tab.call("ensure_built")
	var first: Node = _nodes(tab)["veteran.hello"]
	tab.call("ensure_built")
	assert_object(_nodes(tab)["veteran.hello"]).is_same(first)


## Laid out from measured sizes: with nodes far bigger than the defaults (as at a larger editor
## scale), no two nodes overlap and each sits inside its lane's frame, the frames apart too.
func test_big_nodes_never_overlap() -> void:
	for node_floor: Vector2 in [Vector2.ZERO, Vector2(640, 420)]:
		_assert_laid_out(_tab(FIXTURE, node_floor), node_floor)


## In What-if the title bars carry "next" and the played box: the layout is measured with them, so
## a long name with a neighbour in the next column still overlaps nothing, in and out of the mode.
func test_whatif_widgets_never_overlap() -> void:
	var long_name := "== a_very_long_event_name_to_widen_the_column\n\n== second\nrequires: lanista.a_very_long_event_name_to_widen_the_column\n"
	var tab := _editing_tab(long_name, "== hello\n")
	for on in [true, false, true]:
		tab.call("show_whatif", on)
		_assert_laid_out(tab, Vector2.ZERO)


func _assert_laid_out(tab: Node, node_floor: Vector2) -> void:
	if true:
		var nodes := _nodes(tab)
		var lanes: Dictionary = tab.get("lanes")
		var rects := {}
		for id: String in nodes:
			var node: GraphNode = nodes[id]
			node.update_minimum_size()  # GraphNode caches its size past a change in its title bar
			assert_float(node.get_combined_minimum_size().x).is_greater_equal(node_floor.x)
			rects[id] = Rect2(node.position_offset, node.size.max(node.get_combined_minimum_size()))
		for id: String in rects:
			var rect: Rect2 = rects[id]
			for other: String in rects:
				if other != id:
					assert_bool(rect.intersects(rects[other])).override_failure_message("%s overlaps %s (floor %s)" % [id, other, node_floor]).is_false()
			var frame: GraphFrame = lanes[id.get_slice(".", 0)]
			var lane := Rect2(frame.position_offset, frame.size)
			assert_bool(lane.encloses(rect)).override_failure_message("%s %s outside its lane %s" % [id, rect, lane]).is_true()
		var frames: Array = lanes.values()
		for i in frames.size():
			for j in range(i + 1, frames.size()):
				var a := Rect2((frames[i] as GraphFrame).position_offset, (frames[i] as GraphFrame).size)
				var b := Rect2((frames[j] as GraphFrame).position_offset, (frames[j] as GraphFrame).size)
				assert_bool(a.intersects(b)).override_failure_message("lanes %d and %d overlap" % [i, j]).is_false()


## The filter dims by its own reason: another reason (What-if's, later) holds through a filter
## change, and lifting the filter's leaves it.
func test_dimming_by_reasons() -> void:
	var tab := _tab()
	var hello: Node = _nodes(tab)["veteran.hello"]
	hello.call("set_dim", "other", true)
	assert_array(_dimmed(tab)).is_equal(["veteran.hello"])
	(tab.get_node("%Search") as LineEdit).text = "Another night"
	tab.call("apply_filters")
	assert_bool(_dimmed(tab).has("veteran.hello")).is_true()
	(tab.get_node("%Search") as LineEdit).text = ""
	tab.call("apply_filters")
	assert_array(_dimmed(tab)).is_equal(["veteran.hello"])
	hello.call("set_dim", "other", false)
	assert_array(_dimmed(tab)).is_empty()


func test_the_selection_survives_a_rebuild() -> void:
	var tab := _tab()
	tab.call("select_event", "veteran.hello")
	tab.call("reload")
	var node: GraphNode = _nodes(tab)["veteran.hello"]
	assert_bool(node.selected).is_true()
	assert_str(tab.get("selected")).is_equal("veteran.hello")
	assert_str((tab.get_node("%Title") as Label).text).is_equal("veteran.hello")
	await get_tree().process_frame
	assert_str(tab.get("selected")).is_equal("veteran.hello")
	# gone after a rebuild: the side panel clears
	tab.call("show_catalog", StoryCatalog.from_texts(CAST, "", {"lanista": "== first\n\nLANISTA: Hm.\n"}))
	assert_str(tab.get("selected")).is_empty()
	assert_str((tab.get_node("%Text") as TextEdit).text).is_empty()


func test_deselecting_clears_the_side_panel() -> void:
	var tab := _tab()
	tab.call("select_event", "veteran.hello")
	var node: GraphNode = _nodes(tab)["veteran.hello"]
	node.selected = false
	(tab.get("graph") as GraphEdit).node_deselected.emit(node)
	assert_str(tab.get("selected")).is_empty()
	assert_str((tab.get_node("%Title") as Label).text).is_equal("No event selected")


## A click on the error already selected selects its event again (item_selected fires only on a
## change; item_clicked on every click).
func test_clicking_the_selected_error_again_selects_its_event() -> void:
	var tab := _tab()
	tab.call("show_catalog", StoryCatalog.from_texts(CAST, "", {"lanista": "== good\n\nLANISTA: Hm.\n\n== bad\n\nNOBODY: Hm.\n"}))
	var errors: ItemList = tab.get_node("%Errors")
	errors.select(0)
	errors.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	assert_str(tab.get("selected")).is_equal("lanista.bad")
	tab.call("select_event", "lanista.good")
	errors.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	assert_str(tab.get("selected")).is_equal("lanista.bad")
	errors.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_RIGHT)
	assert_str(tab.get("selected")).is_equal("lanista.bad")


## A rebuild leaves only the new elements once the old are freed.
func test_a_rebuild_leaks_no_element() -> void:
	var tab := _tab()
	tab.call("reload")
	tab.call("reload")
	await get_tree().process_frame
	var elements := 0
	for child in (tab.get("graph") as GraphEdit).get_children():
		if child is GraphElement:
			elements += 1
	assert_int(elements).is_equal(_nodes(tab).size() + (tab.get("lanes") as Dictionary).size())


# --- editing (Task 13): a story written into the scratch directory -----------------------------

const FLAGS := "met\n"
const LANISTA_TEXT := "== first\n\nLANISTA: Welcome.\n\n== second\nrequires: lanista.first\n\nLANISTA: Again.\n"
## hello sets `met`, which later's when reads: a flag link.
const VETERAN_TEXT := "== hello\nrequires: lanista.first\n\nVETERAN: Hello.\n? Nod.\n    set: met\n\n== later\nwhen: met\n\nVETERAN: Later.\n"


## The tab on a story in the scratch directory (canonical texts unless given).
func _editing_tab(lanista := LANISTA_TEXT, veteran := VETERAN_TEXT, flags := FLAGS) -> Node:
	DirAccess.make_dir_recursive_absolute(_scratch)
	_write("cast.json", JSON.stringify(CAST))
	_write("flags.txt", flags)
	_write("lanista.txt", lanista)
	_write("veteran.txt", veteran)
	var tab := _tab(_scratch)
	assert_array((tab.get("edit") as StoryEdit).catalog.errors).is_empty()
	return tab


func _read(file: String) -> String:
	return FileAccess.get_file_as_string(_scratch.path_join(file))


func _node_name(tab: Node, id: String) -> StringName:
	return (_nodes(tab)[id] as Node).name


func _edit_of(tab: Node) -> StoryEdit:
	return tab.get("edit")


func _event(tab: Node, id: String) -> StoryEvent:
	return _edit_of(tab).catalog.by_id.get(id)


func _ports(tab: Node, port: int) -> int:
	var count := 0
	for connection: Dictionary in (tab.get("graph") as GraphEdit).get_connection_list():
		if connection["from_port"] == port:
			count += 1
	return count


func _notice(tab: Node) -> String:
	var notice: Label = tab.get_node("%Notice")
	return notice.text if notice.visible else ""


## The graph's drag (its connection request, from the node the drag leaves to the one it reaches):
## the requires row adds a requires to the reached event, the unless row an unless; the pool is
## unsaved, its lane says so, and nothing is written yet.
func test_a_drag_adds_a_link_of_its_rows_kind_and_marks_the_pool_unsaved() -> void:
	var tab := _editing_tab()
	var port := EventNode.port(StoryLinks.REQUIRES)
	await _drag(tab, StoryLinks.REQUIRES, "veteran.hello", "lanista.second")
	assert_array(_event(tab, "lanista.second").requires).is_equal(["lanista.first", "veteran.hello"])
	assert_array(_edit_of(tab).dirty_pools()).is_equal(["lanista"])
	var lanes: Dictionary = tab.get("lanes")
	assert_str((lanes["lanista"] as GraphFrame).title).contains("unsaved")
	assert_str((lanes["veteran"] as GraphFrame).title).not_contains("unsaved")
	assert_bool((tab.get_node("%Save") as Button).disabled).is_false()
	assert_int(_ports(tab, port)).is_equal(3)
	var unless := EventNode.port(StoryLinks.UNLESS)
	await _drag(tab, StoryLinks.UNLESS, "veteran.later", "lanista.first")
	assert_array(_event(tab, "lanista.first").unless).is_equal(["veteran.later"])
	assert_int(_ports(tab, unless)).is_equal(1)
	assert_str(_read("lanista.txt")).is_equal(LANISTA_TEXT)
	assert_str(_notice(tab)).is_empty()


## An edge's right end picked up and dropped off its port is removed when the drag ends (GraphEdit
## 4.7.2's order: disconnection_request, connection_drag_started, connection_drag_ended); dropped
## back on its port it stays; dropped on another event's port it moves.
func test_dragging_an_edge_off_removes_it() -> void:
	var tab := _editing_tab()
	var port := EventNode.port(StoryLinks.REQUIRES)
	var far := Vector2(400, 300)
	await _pick_up(tab, StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2.ZERO, far, "lanista.first", "lanista.second")
	assert_array(_edit_of(tab).dirty_pools()).is_empty()
	await _pick_up(tab, StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2.ZERO, far)
	assert_array(_event(tab, "lanista.second").requires).is_empty()
	assert_array(_edit_of(tab).dirty_pools()).is_equal(["lanista"])
	assert_int(_ports(tab, port)).is_equal(1)
	await _pick_up(tab, StoryLinks.REQUIRES, "lanista.first", "veteran.hello", Vector2.ZERO, far, "lanista.first", "veteran.later")
	assert_array(_event(tab, "veteran.hello").requires).is_empty()
	assert_array(_event(tab, "veteran.later").requires).is_equal(["lanista.first"])


## A flag link is derived from set: and when:: drawing or removing one is refused with why.
func test_a_flag_link_is_neither_drawn_nor_removed() -> void:
	var tab := _editing_tab()
	var port := EventNode.port(StoryLinks.FLAG)
	assert_int(_ports(tab, port)).is_equal(1)
	await _pick_up(tab, StoryLinks.FLAG, "veteran.hello", "veteran.later", Vector2.ZERO, Vector2(400, 300))
	assert_str(_notice(tab)).contains("flag link").contains("set:").contains("when:")
	assert_int(_ports(tab, port)).is_equal(1)
	await _drag(tab, StoryLinks.FLAG, "lanista.first", "lanista.second")
	assert_str(_notice(tab)).contains("flag link")
	assert_array(_edit_of(tab).dirty_pools()).is_empty()


## A drag that would close a cycle of requires shows the catalog's reason and changes nothing.
func test_a_refused_cycle_shows_its_reason_and_changes_nothing() -> void:
	var tab := _editing_tab()
	var port := EventNode.port(StoryLinks.REQUIRES)
	await _drag(tab, StoryLinks.REQUIRES, "lanista.second", "lanista.first")
	assert_str(_notice(tab)).contains("Refused").contains("cycle")
	assert_str(_notice(tab)).not_contains(".txt:")
	assert_str(_edit_of(tab).catalog.text_of("lanista")).is_equal(LANISTA_TEXT)
	assert_array(_edit_of(tab).dirty_pools()).is_empty()
	assert_bool((tab.get_node("%Save") as Button).disabled).is_true()
	assert_int(_ports(tab, port)).is_equal(2)


## Save writes the pools with unsaved edits in the canonical form, and only those.
func test_save_writes_the_pools_with_unsaved_edits() -> void:
	var tab := _editing_tab()
	assert_array(tab.call("link", StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true)).is_empty()
	(tab.get_node("%Save") as Button).pressed.emit()
	assert_str(_read("lanista.txt")).is_equal("== first\n\nLANISTA: Welcome.\n\n== second\nrequires: lanista.first, veteran.hello\n\nLANISTA: Again.\n")
	assert_str(_read("veteran.txt")).is_equal(VETERAN_TEXT)
	assert_array(_edit_of(tab).dirty_pools()).is_empty()
	assert_str(((tab.get("lanes") as Dictionary)["lanista"] as GraphFrame).title).not_contains("unsaved")
	assert_str(_notice(tab)).contains("Saved lanista.txt")
	assert_bool((tab.get_node("%Save") as Button).disabled).is_true()
	assert_str(tab.call("unsaved_status")).is_empty()


## A lane's button adds an event (named in a dialog); a node's menu renames it (the requires in the
## other pool follow) and deletes it (asked first; a named event is refused with the reason).
func test_add_rename_and_delete_through_the_tab() -> void:
	var tab := _editing_tab()
	var names: ConfirmationDialog = tab.get("_name_dialog")
	var field: LineEdit = tab.get("_name_field")
	var confirm: ConfirmationDialog = tab.get("_confirm")
	var lane: GraphFrame = (tab.get("lanes") as Dictionary)["veteran"]
	var add: Button = null
	for child in lane.get_titlebar_hbox().get_children():
		if child is Button:
			add = child
	add.pressed.emit()
	assert_bool(names.visible).is_true()
	assert_str(field.text).is_equal("new_event")
	names.confirmed.emit()
	names.hide()
	assert_bool(_edit_of(tab).catalog.by_id.has("veteran.new_event")).is_true()
	assert_str(tab.get("selected")).is_equal("veteran.new_event")
	assert_bool((_nodes(tab)["veteran.new_event"] as GraphNode).selected).is_true()
	(_nodes(tab)["lanista.first"] as Node).emit_signal("rename_requested", "lanista.first")
	assert_str(field.text).is_equal("first")
	field.text = "welcome"
	names.confirmed.emit()
	names.hide()
	assert_bool(_edit_of(tab).catalog.by_id.has("lanista.welcome")).is_true()
	assert_array(_event(tab, "veteran.hello").requires).is_equal(["lanista.welcome"])
	assert_array(_edit_of(tab).dirty_pools()).is_equal(["lanista", "veteran"])
	(_nodes(tab)["lanista.welcome"] as Node).emit_signal("delete_requested", "lanista.welcome")
	assert_bool(confirm.visible).is_true()
	confirm.confirmed.emit()
	confirm.hide()
	assert_str(_notice(tab)).contains("lanista.welcome")
	assert_bool(_edit_of(tab).catalog.by_id.has("lanista.welcome")).is_true()
	(_nodes(tab)["veteran.new_event"] as Node).emit_signal("delete_requested", "veteran.new_event")
	confirm.confirmed.emit()
	confirm.hide()
	assert_bool(_edit_of(tab).catalog.by_id.has("veteran.new_event")).is_false()
	assert_bool(_nodes(tab).has("veteran.new_event")).is_false()
	assert_str(tab.get("selected")).is_empty()


## The header controls set the shown event's fields; a value refused is listed in the panel and
## changes nothing, the when field keeping what was typed.
func test_the_header_controls_set_the_shown_event() -> void:
	var tab := _editing_tab()
	tab.call("select_event", "veteran.later")
	_choose(tab.get_node("%EventPriority"), "high")
	assert_str(_event(tab, "veteran.later").priority).is_equal("high")
	assert_str((tab.get_node("%Text") as TextEdit).text).contains("priority: high")
	_choose(tab.get_node("%EventRepeat"), "repeat")
	assert_bool(_event(tab, "veteran.later").once).is_false()
	_choose(tab.get_node("%EventTrigger"), "enter")
	assert_str(_event(tab, "veteran.later").trigger_arg).is_equal(StoryScript.ROOMS[0])
	assert_bool((tab.get_node("%EventRoom") as Control).visible).is_true()
	_choose(tab.get_node("%EventRoom"), "hypogeum")
	assert_str(_event(tab, "veteran.later").trigger_arg).is_equal("hypogeum")
	_choose(tab.get_node("%EventAct"), "act 2")
	assert_int(_event(tab, "veteran.later").act).is_equal(2)
	assert_str(tab.get("selected")).is_equal("veteran.later")
	var saved_text := _edit_of(tab).catalog.text_of("veteran")
	var when: LineEdit = tab.get_node("%EventWhen")
	when.text = "nobody_knows"
	when.text_submitted.emit(when.text)
	var errors: ItemList = tab.get_node("%EventErrors")
	assert_bool(errors.visible).is_true()
	assert_str(errors.get_item_text(0)).contains("unknown name 'nobody_knows'")
	assert_str(when.text).is_equal("nobody_knows")
	assert_str(_edit_of(tab).catalog.text_of("veteran")).is_equal(saved_text)
	when.text = "not met"
	(tab.get_node("%EventWhenSet") as Button).pressed.emit()
	assert_str(_event(tab, "veteran.later").when.source).is_equal("not met")
	assert_bool(errors.visible).is_false()
	assert_str(when.text).is_equal("not met")
	tab.call("select_event", "veteran.hello")
	assert_str(when.text).is_empty()


static func _choose(button: OptionButton, text: String) -> void:
	for i in button.item_count:
		if button.get_item_text(i) == text:
			button.select(i)
			button.item_selected.emit(i)
			return


## Apply with a syntax error keeps the old event, lists the error, and marks its line in the
## text; a good text replaces the event.
func test_apply_with_a_syntax_error_keeps_the_event_and_shows_the_line() -> void:
	var tab := _editing_tab()
	tab.call("select_event", "veteran.later")
	var text: CodeEdit = tab.get_node("%Text")
	text.text = "== later\nwhen: met\n\nVETERAN: Later.\nmood: grim\n"
	await get_tree().process_frame
	assert_bool((tab.get_node("%Apply") as Button).disabled).is_false()
	(tab.get_node("%Apply") as Button).pressed.emit()
	assert_str(_edit_of(tab).catalog.text_of("veteran")).is_equal(VETERAN_TEXT)
	assert_array(_edit_of(tab).dirty_pools()).is_empty()
	var errors: ItemList = tab.get_node("%EventErrors")
	assert_bool(errors.visible).is_true()
	assert_str(errors.get_item_text(0)).starts_with("veteran.txt:5: ")
	assert_array(tab.call("marked_lines")).is_equal([5])
	assert_str(text.text).contains("mood: grim")
	text.text = "== later\nwhen: met\nrepeat\n\nVETERAN: Later, again.\n"
	await get_tree().process_frame
	assert_array(tab.call("marked_lines")).is_empty()
	assert_array(tab.call("apply_text")).is_empty()
	assert_bool(_event(tab, "veteran.later").once).is_false()
	assert_array(_edit_of(tab).dirty_pools()).is_equal(["veteran"])
	assert_bool(errors.visible).is_false()
	assert_str(text.text).is_equal("== later\nwhen: met\nrepeat\n\nVETERAN: Later, again.")
	# a new name in the text renames the event (nothing names it); the selection follows
	text.text = "== afterwards\nwhen: met\n\nVETERAN: Later.\n"
	assert_array(tab.call("apply_text")).is_empty()
	assert_str(tab.get("selected")).is_equal("veteran.afterwards")
	assert_bool((_nodes(tab)["veteran.afterwards"] as GraphNode).selected).is_true()


## Text not applied is the event's draft: kept across selections, holding the header controls,
## dropped by Revert.
func test_a_draft_survives_another_selection_and_holds_the_header() -> void:
	var tab := _editing_tab()
	tab.call("select_event", "veteran.later")
	var text: CodeEdit = tab.get_node("%Text")
	var draft := "== later\nwhen: met\n\nVETERAN: Not yet.\n"
	text.text = draft
	var refused: Array = tab.call("set_field", "priority", "high")
	assert_str(" ".join(refused)).contains("Apply or Revert")
	assert_str(_event(tab, "veteran.later").priority).is_equal("normal")
	tab.call("select_event", "veteran.hello")
	assert_str(text.text).is_equal((tab.get("model") as StoryGraph).text("veteran.hello"))
	tab.call("select_event", "veteran.later")
	assert_str(text.text).is_equal(draft)
	assert_str(tab.call("unsaved_status")).contains("veteran.later")
	tab.call("revert_text")
	assert_str(text.text).is_equal((tab.get("model") as StoryGraph).text("veteran.later"))
	assert_dict(tab.get("drafts")).is_empty()


## With two nodes selected, deselecting the one the panel shows moves the panel to the other (it
## never shows an event that is not selected); none selected clears it, and Apply does nothing.
func test_the_panel_always_shows_a_selected_node() -> void:
	var tab := _editing_tab()
	var graph: GraphEdit = tab.get("graph")
	var hello: GraphNode = _nodes(tab)["veteran.hello"]
	var later: GraphNode = _nodes(tab)["veteran.later"]
	tab.call("select_event", "veteran.hello")
	later.selected = true
	graph.node_selected.emit(later)
	assert_str(tab.get("selected")).is_equal("veteran.later")
	later.selected = false
	graph.node_deselected.emit(later)
	assert_str(tab.get("selected")).is_equal("veteran.hello")
	assert_str((tab.get_node("%Title") as Label).text).is_equal("veteran.hello")
	# deselecting a node the panel does not show leaves it
	later.selected = true
	graph.node_selected.emit(later)
	hello.selected = false
	graph.node_deselected.emit(hello)
	assert_str(tab.get("selected")).is_equal("veteran.later")
	later.selected = false
	graph.node_deselected.emit(later)
	assert_str(tab.get("selected")).is_empty()
	(tab.get_node("%Text") as TextEdit).text = "== later\n\nVETERAN: Gone.\n"
	assert_array(tab.call("apply_text")).is_empty()
	assert_str(_edit_of(tab).catalog.text_of("veteran")).is_equal(VETERAN_TEXT)


## Reload with unsaved edits, or text not applied, asks first; its OK reloads from disk.
func test_reload_with_unsaved_edits_asks_first() -> void:
	var tab := _editing_tab()
	var confirm: ConfirmationDialog = tab.get("_confirm")
	assert_array(tab.call("link", StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true)).is_empty()
	assert_str(tab.call("unsaved_status")).contains("lanista.txt")
	(tab.get_node("%Reload") as Button).pressed.emit()
	assert_bool(confirm.visible).is_true()
	assert_str(confirm.dialog_text).contains("lanista.txt")
	assert_array(_event(tab, "lanista.second").requires).is_equal(["lanista.first", "veteran.hello"])
	confirm.confirmed.emit()
	confirm.hide()
	assert_array(_event(tab, "lanista.second").requires).is_equal(["lanista.first"])
	assert_array(_edit_of(tab).dirty_pools()).is_empty()
	assert_str(tab.call("unsaved_status")).is_empty()
	# a draft alone asks too
	tab.call("select_event", "veteran.later")
	(tab.get_node("%Text") as TextEdit).text = "== later\n\nVETERAN: Draft.\n"
	tab.call("reload")
	assert_bool(confirm.visible).is_true()
	assert_str(confirm.dialog_text).contains("veteran.later")
	confirm.hide()


## The load's warnings (an inline comment the first rewrite drops) are listed before any edit,
## select their event, and go once their pool is saved.
func test_the_loads_warnings_are_listed_until_their_pool_is_saved() -> void:
	var tab := _editing_tab(LANISTA_TEXT.replace("LANISTA: Welcome.\n", "LANISTA: Welcome.\nset: met   # why\n"))
	var errors: ItemList = tab.get_node("%Errors")
	assert_bool(errors.visible).is_true()
	assert_int(errors.item_count).is_equal(1)
	assert_str(errors.get_item_text(0)).contains("warning").contains("inline comment")
	errors.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	assert_str(tab.get("selected")).is_equal("lanista.first")
	assert_array(tab.call("link", StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true)).is_empty()
	assert_int(errors.item_count).is_equal(1)
	assert_array(tab.call("save")).is_empty()
	assert_bool(errors.visible).is_false()
	assert_str(_read("lanista.txt")).not_contains("# why")


## A save refused because the file changed on disk since the load says so plainly (the notice and
## a dialog) and writes nothing.
func test_a_save_refused_as_changed_on_disk_says_so_plainly() -> void:
	var tab := _editing_tab()
	assert_array(tab.call("link", StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true)).is_empty()
	var by_hand := LANISTA_TEXT + "\n== by_hand\n\nLANISTA: Mine.\n"
	_write("lanista.txt", by_hand)
	var refused: Array = tab.call("save")
	assert_str(" ".join(refused)).contains("changed on disk since load")
	var alert: AcceptDialog = tab.get("_alert")
	assert_bool(alert.visible).is_true()
	assert_str(alert.dialog_text).contains("Not saved").contains("changed on disk after the tab read it").contains("Reload")
	assert_str(_notice(tab)).contains("Not saved")
	assert_array(_edit_of(tab).dirty_pools()).is_equal(["lanista"])
	assert_str(_read("lanista.txt")).is_equal(by_hand)
	alert.hide()


## An edit draws the graph again: the selection and the scroll stay where they were.
func test_the_scroll_and_the_selection_survive_an_edit() -> void:
	var tab := _editing_tab()
	(tab as Control).set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	(tab as Control).size = Vector2(900, 600)
	await get_tree().process_frame
	var graph: GraphEdit = tab.get("graph")
	tab.call("select_event", "veteran.later")
	graph.scroll_offset = Vector2(40, 30)
	await get_tree().process_frame
	var offset := graph.scroll_offset
	assert_array(tab.call("link", StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true)).is_empty()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(graph.scroll_offset).is_equal(offset)
	assert_str(tab.get("selected")).is_equal("veteran.later")
	assert_bool((_nodes(tab)["veteran.later"] as GraphNode).selected).is_true()


## The plugin's hooks: the editor's save writes the unsaved pools.
func test_the_editors_save_writes_the_unsaved_pools() -> void:
	var tab := _editing_tab()
	tab.call("save_external")
	assert_str(_read("lanista.txt")).is_equal(LANISTA_TEXT)
	assert_array(tab.call("link", StoryLinks.UNLESS, "veteran.later", "lanista.second", true)).is_empty()
	tab.call("save_external")
	assert_str(_read("lanista.txt")).contains("unless: veteran.later")
	assert_str(tab.call("unsaved_status")).is_empty()


# --- Task 13's review: the gestures through GraphEdit's signals, in its order -------------------

## A drag as GraphEdit 4.7.2 emits it: started, ended on a port, over.
func _drag(tab: Node, kind: String, from_id: String, to_id: String) -> void:
	var graph: GraphEdit = tab.get("graph")
	var port := EventNode.port(kind)
	graph.connection_drag_started.emit(_node_name(tab, from_id), port, true)
	graph.connection_request.emit(_node_name(tab, from_id), port, _node_name(tab, to_id), port)
	graph.connection_drag_ended.emit()
	await get_tree().process_frame


## An edge's right end picked up at `at`, then released at `release` (on `drop_to`'s port when
## given, the same kind's link from `drop_from`).
func _pick_up(tab: Node, kind: String, from_id: String, to_id: String, at: Vector2, release: Vector2, drop_from := "", drop_to := "") -> void:
	var graph: GraphEdit = tab.get("graph")
	var port := EventNode.port(kind)
	var where := [at]
	tab.set("pointer", func() -> Vector2: return where[0])
	graph.disconnection_request.emit(_node_name(tab, from_id), port, _node_name(tab, to_id), port)
	graph.connection_drag_started.emit(_node_name(tab, from_id), port, true)
	if drop_to != "":
		graph.connection_request.emit(_node_name(tab, drop_from), port, _node_name(tab, drop_to), port)
	where[0] = release
	graph.connection_drag_ended.emit()
	await get_tree().process_frame


## Text not applied survives every edit elsewhere: a link between two other events, an edge
## removed, an event added, another event deleted.
func test_a_draft_survives_edits_elsewhere() -> void:
	var tab := _editing_tab()
	tab.call("select_event", "veteran.later")
	var text: CodeEdit = tab.get_node("%Text")
	var draft := "== later\nwhen: met\n\nVETERAN: Not yet, not yet.\n"
	text.text = draft
	await _drag(tab, StoryLinks.REQUIRES, "veteran.hello", "lanista.second")
	assert_array(_event(tab, "lanista.second").requires).contains(["veteran.hello"])
	assert_str(text.text).is_equal(draft)
	assert_array(tab.call("link", StoryLinks.REQUIRES, "veteran.hello", "lanista.second", false)).is_empty()
	assert_str(text.text).is_equal(draft)
	assert_array(tab.call("add_event", "lanista", "third")).is_empty()
	tab.call("select_event", "veteran.later")
	assert_str(text.text).is_equal(draft)
	assert_array(tab.call("delete_event", "lanista.third")).is_empty()
	assert_str(text.text).is_equal(draft)
	assert_str(tab.get("selected")).is_equal("veteran.later")
	# an edit of the event itself keeps the draft and says so
	await _drag(tab, StoryLinks.REQUIRES, "lanista.first", "veteran.later")
	assert_array(_event(tab, "veteran.later").requires).is_equal(["lanista.first"])
	assert_str(text.text).is_equal(draft)
	assert_str(_notice(tab)).contains("veteran.later changed under its text not applied")


## A picked-up edge dropped where the new link is refused (a cycle) changes nothing: the old edge
## stays, the refusal stays shown, nothing is unsaved.
func test_a_refused_move_keeps_the_old_edge_and_the_refusal() -> void:
	var tab := _editing_tab()
	await _pick_up(tab, StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2(10, 10), Vector2(300, 200), "lanista.second", "lanista.first")
	await get_tree().process_frame
	assert_array(_event(tab, "lanista.second").requires).is_equal(["lanista.first"])
	assert_array(_event(tab, "lanista.first").requires).is_empty()
	assert_str(_notice(tab)).contains("Refused").contains("cycle")
	assert_array(_edit_of(tab).dirty_pools()).is_empty()


## Apply after a rename keeps the new name: the draft followed the rename.
func test_apply_after_a_rename_keeps_the_new_name() -> void:
	var tab := _editing_tab()
	tab.call("select_event", "veteran.later")
	(tab.get_node("%Text") as CodeEdit).text = "== later\nwhen: met\n\nVETERAN: Later, then.\n"
	assert_array(tab.call("rename_event", "veteran.later", "afterwards")).is_empty()
	assert_str((tab.get_node("%Text") as CodeEdit).text).starts_with("== afterwards\n")
	assert_array(tab.call("apply_text")).is_empty()
	assert_bool(_edit_of(tab).catalog.by_id.has("veteran.afterwards")).is_true()
	assert_bool(_edit_of(tab).catalog.by_id.has("veteran.later")).is_false()
	assert_str(_edit_of(tab).catalog.text_of("veteran")).contains("VETERAN: Later, then.")


## A click on a connected input port (released where it was pressed) keeps its edge; released
## farther than the reach, the edge goes.
func test_a_click_on_a_port_keeps_its_edge() -> void:
	var tab := _editing_tab()
	await _pick_up(tab, StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2(100, 100), Vector2(102, 101))
	await get_tree().process_frame
	assert_array(_event(tab, "lanista.second").requires).is_equal(["lanista.first"])
	assert_array(_edit_of(tab).dirty_pools()).is_empty()
	await _pick_up(tab, StoryLinks.REQUIRES, "lanista.first", "lanista.second", Vector2(100, 100), Vector2(100, 160))
	await get_tree().process_frame
	assert_array(_event(tab, "lanista.second").requires).is_empty()


## A pick-up forgotten by a reload removes nothing at a later drag's end.
func test_a_stale_pick_up_removes_nothing() -> void:
	var tab := _editing_tab()
	var graph: GraphEdit = tab.get("graph")
	var port := EventNode.port(StoryLinks.REQUIRES)
	tab.set("pointer", func() -> Vector2: return Vector2(500, 500))
	graph.disconnection_request.emit(_node_name(tab, "lanista.first"), port, _node_name(tab, "lanista.second"), port)
	tab.call("reload")
	tab.set("pointer", func() -> Vector2: return Vector2(0, 0))
	graph.connection_drag_ended.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(_event(tab, "lanista.second").requires).is_equal(["lanista.first"])
	# and a new drag that does not continue the pick-up forgets it
	graph.disconnection_request.emit(_node_name(tab, "lanista.first"), port, _node_name(tab, "lanista.second"), port)
	graph.connection_drag_started.emit(_node_name(tab, "veteran.hello"), port, true)
	graph.connection_drag_ended.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(_event(tab, "lanista.second").requires).is_equal(["lanista.first"])


## The when field's text not set survives a selection change and back (tinted while pending); an
## Apply's listed errors and their line marks go together when the text changes.
func test_the_panels_leftovers() -> void:
	var tab := _editing_tab()
	tab.call("select_event", "veteran.later")
	var when: LineEdit = tab.get_node("%EventWhen")
	when.text = "met and wins >= 2"
	when.text_changed.emit(when.text)
	tab.call("select_event", "veteran.hello")
	assert_str(when.text).is_empty()
	tab.call("select_event", "veteran.later")
	assert_str(when.text).is_equal("met and wins >= 2")
	assert_bool(when.has_theme_color_override("font_color")).is_true()
	var text: CodeEdit = tab.get_node("%Text")
	text.text = "== later\n\nVETERAN: Fine.\nmood: grim\n"
	tab.call("apply_text")
	var errors: ItemList = tab.get_node("%EventErrors")
	assert_bool(errors.visible).is_true()
	assert_array(tab.call("marked_lines")).is_equal([4])
	text.text = "== later\n\nVETERAN: Fine, then.\nmood: grim\n"
	assert_bool(errors.visible).is_false()
	assert_array(tab.call("marked_lines")).is_empty()


## The Delete key on several selected events: one question, one gesture, all or nothing.
func test_the_delete_key_deletes_the_selection_as_one() -> void:
	var tab := _editing_tab()
	var confirm: ConfirmationDialog = tab.get("_confirm")
	var graph: GraphEdit = tab.get("graph")
	graph.delete_nodes_request.emit([_node_name(tab, "lanista.first"), _node_name(tab, "lanista.second")] as Array[StringName])
	assert_bool(confirm.visible).is_true()
	confirm.confirmed.emit()
	confirm.hide()
	assert_str(_notice(tab)).contains("lanista.first is still named: veteran.hello requires it")
	assert_bool(_edit_of(tab).catalog.by_id.has("lanista.second")).is_true()
	assert_array(_edit_of(tab).dirty_pools()).is_empty()
	graph.delete_nodes_request.emit([_node_name(tab, "veteran.later"), _node_name(tab, "veteran.hello"), _node_name(tab, "lanista.second"), _node_name(tab, "lanista.first")] as Array[StringName])
	confirm.confirmed.emit()
	confirm.hide()
	assert_dict(_nodes(tab)).is_empty()
	assert_array(_edit_of(tab).dirty_pools()).is_equal(["lanista", "veteran"])


## The editor's save never opens a dialog: a refusal is the notice and the error list.
func test_the_editors_save_refused_is_listed_not_a_dialog() -> void:
	var tab := _editing_tab()
	assert_array(tab.call("link", StoryLinks.REQUIRES, "veteran.hello", "lanista.second", true)).is_empty()
	_write("lanista.txt", LANISTA_TEXT + "\n== by_hand\n\nLANISTA: Mine.\n")
	tab.call("save_external")
	assert_bool((tab.get("_alert") as AcceptDialog).visible).is_false()
	assert_str(_notice(tab)).contains("changed on disk after the tab read it")
	var errors: ItemList = tab.get_node("%Errors")
	var listed := ""
	for i in errors.item_count:
		listed += errors.get_item_text(i)
	assert_str(listed).contains("changed on disk since load")


## With no pointer set, a drag's pointer is the last mouse event's position in the graph's pixels.
func test_the_pointer_is_read_from_the_mouse_events() -> void:
	var tab := _editing_tab()
	var graph: GraphEdit = tab.get("graph")
	var press := InputEventMouseButton.new()
	press.position = Vector2(37, 21)
	tab.call("_input", press)
	assert_vector(tab.call("_pointer")).is_equal(graph.get_global_transform_with_canvas().affine_inverse() * Vector2(37, 21))


# --- What-if (Task 14) ------------------------------------------------------------------------------

func _whatif_panel(tab: Node) -> Node:
	return tab.get("whatif_panel")


func _marked(tab: Node) -> Array[String]:
	var out: Array[String] = []
	var nodes := _nodes(tab)
	for id: String in nodes:
		if (nodes[id] as Node).call("is_marked_next"):
			out.append(id)
	out.sort()
	return out


## Only while its tab is shown: each pool's next marked, the events that would not play dimmed by
## the "whatif" reason, every node's played box; back on the Event tab, none of it.
func test_whatif_marks_and_dims_while_its_tab_is_shown() -> void:
	var tab := _tab()
	assert_bool(tab.call("whatif_active")).is_false()
	assert_array(_marked(tab)).is_empty()
	tab.call("show_whatif", true)
	assert_bool(tab.call("whatif_active")).is_true()
	assert_array(_marked(tab)).is_equal(["armourer.two_asks", "lanista.first_word", "veteran.hello"] as Array[String])
	var dimmed := _dimmed(tab)
	assert_bool(dimmed.has("lanista.after_first_win")).is_true()
	assert_bool(dimmed.has("narrator.wait")).is_true()
	assert_bool(dimmed.has("lanista.first_word")).is_false()
	assert_bool(((_nodes(tab)["lanista.first_word"] as Node).call("played_box") as CheckBox).visible).is_true()
	tab.call("show_whatif", false)
	assert_array(_marked(tab)).is_empty()
	assert_array(_dimmed(tab)).is_empty()
	assert_bool(((_nodes(tab)["lanista.first_word"] as Node).call("played_box") as CheckBox).visible).is_false()


## The filter's dimming and What-if's are separate reasons: neither lifts the other.
func test_whatif_dims_beside_the_filter() -> void:
	var tab := _tab()
	(tab.get_node("%Search") as LineEdit).text = "carried"
	tab.call("apply_filters")
	tab.call("show_whatif", true)
	assert_bool(_dimmed(tab).has("lanista.after_first_win")).is_true()
	(tab.get_node("%Search") as LineEdit).text = ""
	tab.call("apply_filters")
	assert_bool(_dimmed(tab).has("lanista.after_first_win")).is_true()
	assert_bool(_dimmed(tab).has("lanista.first_word")).is_false()
	(tab.get_node("%Search") as LineEdit).text = "carried"
	tab.call("apply_filters")
	tab.call("show_whatif", false)
	assert_bool(_dimmed(tab).has("lanista.after_first_win")).is_false()
	assert_bool(_dimmed(tab).has("lanista.first_word")).is_true()


## The panel's controls reach the controller and the graph follows: the moment, a count, the
## selected event's reasons, a node's played box, Return.
func test_the_panels_controls_reach_the_whatif() -> void:
	var tab := _tab()
	tab.call("show_whatif", true)
	var panel := _whatif_panel(tab)
	var whatif: RefCounted = tab.get("whatif")
	tab.call("select_event", "veteran.the_warning")
	assert_str(panel.call("reasons_text")).contains("requires lanista.first_word")
	var played: CheckBox = (_nodes(tab)["lanista.first_word"] as Node).call("played_box")
	played.button_pressed = true
	assert_bool(whatif.call("is_played", "lanista.first_word")).is_true()
	assert_array(_marked(tab)).contains(["lanista.bark"]).not_contains(["lanista.first_word"])
	assert_str(panel.call("reasons_text")).not_contains("requires").contains("deaths is 0")
	(panel.call("control_of", "deaths") as SpinBox).value = 1
	assert_str(panel.call("reasons_text")).is_equal("plays next at talk")
	assert_array(_marked(tab)).contains(["veteran.the_warning"])
	var hello: CheckBox = (_nodes(tab)["veteran.hello"] as Node).call("played_box")
	hello.button_pressed = true
	assert_str(panel.call("reasons_text")).is_equal("veteran has spoken this return")
	panel.call("new_return")
	assert_str(panel.call("reasons_text")).is_equal("plays next at talk")
	panel.call("set_moment_text", "enter ludus")
	assert_array(_marked(tab)).is_equal(["lanista.arrival"] as Array[String])
	assert_bool(_dimmed(tab).has("veteran.the_warning")).is_true()
	(panel.call("control_of", "veteran_distant") as CheckBox).button_pressed = true
	assert_that(whatif.call("story_flag", tab.get("catalog"), "veteran_distant")).is_equal(true)


## A click on a node's played box outside What-if (the box hidden) changes nothing.
func test_a_played_box_outside_whatif_does_nothing() -> void:
	var tab := _tab()
	var played: CheckBox = (_nodes(tab)["lanista.first_word"] as Node).call("played_box")
	played.button_pressed = true
	assert_bool((tab.get("whatif") as RefCounted).call("is_played", "lanista.first_word")).is_false()


## Load my save through the panel reads the copy into the controls; What-if never dirties a pool
## or writes a story file.
func test_whatif_loads_a_save_and_leaves_the_story_unsaved_free() -> void:
	var tab := _editing_tab()
	var source := _scratch.path_join("save.cfg")
	var save := Save.new()
	save.flags["deaths"] = 2
	save.mark_story_played("lanista.first")
	save.save_to(source)
	var whatif: RefCounted = tab.get("whatif")
	whatif.set("source_path", source)
	tab.call("show_whatif", true)
	var panel := _whatif_panel(tab)
	panel.call("load_save")
	assert_str(panel.call("message_text")).contains("Loaded a copy")
	assert_float((panel.call("control_of", "deaths") as SpinBox).value).is_equal(2.0)
	assert_array(_marked(tab)).is_equal(["lanista.second", "veteran.hello"] as Array[String])
	((_nodes(tab)["veteran.hello"] as Node).call("played_box") as CheckBox).button_pressed = true
	(panel.call("control_of", "met") as CheckBox).button_pressed = true
	panel.call("new_return")
	panel.call("blank")
	assert_bool(tab.call("has_unsaved")).is_false()
	assert_array(_edit_of(tab).dirty_pools()).is_empty()
	assert_str(_read("lanista.txt")).is_equal(LANISTA_TEXT)
	assert_str(_read("veteran.txt")).is_equal(VETERAN_TEXT)



## An emptied word flag's field shows the flag's declared default back once the edit ends, and the
## state holds that default throughout.
func test_an_emptied_word_flag_field_shows_its_default() -> void:
	var tab := _tab()
	tab.call("show_whatif", true)
	var panel := _whatif_panel(tab)
	var whatif: RefCounted = tab.get("whatif")
	var field: LineEdit = panel.call("control_of", "lanista_mood")
	assert_str(field.text).is_equal("calm")
	field.text = "pleased"
	field.text_changed.emit("pleased")
	assert_that(whatif.call("story_flag", tab.get("catalog"), "lanista_mood")).is_equal("pleased")
	field.text = ""
	field.text_changed.emit("")
	assert_that(whatif.call("story_flag", tab.get("catalog"), "lanista_mood")).is_equal("calm")
	assert_str(field.placeholder_text).is_equal("calm")
	field.text_submitted.emit("")
	assert_str(field.text).is_equal("calm")
	var killer: LineEdit = panel.call("control_of", "last_killer")
	killer.text = ""
	killer.text_changed.emit("")
	killer.focus_exited.emit()
	assert_str(killer.text).is_equal("none")


## The played box says what a mark does not do and how it is kept.
func test_the_played_box_says_what_it_does_not_do() -> void:
	var tab := _tab()
	var played: CheckBox = (_nodes(tab)["lanista.first_word"] as Node).call("played_box")
	assert_str(played.tooltip_text).contains("set:").contains("id")


# --- the lint (Task 15) ------------------------------------------------------------------------

## The lint's warnings: listed under the toolbar after the errors ("lint: ...", orange), a click
## selecting their event; a badge on the node; the side panel's facts; the status line's count. Run
## again after an edit (the warning goes with its cause), and never dirtying a pool.
func test_the_lints_warnings_are_listed_badged_and_select_their_event() -> void:
	var tab := _editing_tab(LANISTA_TEXT.replace("LANISTA: Welcome.\n", "LANISTA: Welcome.\nset: nodded\n"), VETERAN_TEXT, "met\nnodded\n")
	var errors: ItemList = tab.get_node("%Errors")
	assert_bool(errors.visible).is_true()
	assert_int(errors.item_count).is_equal(1)
	assert_str(errors.get_item_text(0)).is_equal("lint: lanista.first: sets nodded, which nothing reads")
	assert_object(errors.get_item_custom_fg_color(0)).is_equal(EventNode.LINT_COLOR)
	assert_str(_row_text(_nodes(tab)["lanista.first"])).contains("1 lint")
	assert_str(_row_text(_nodes(tab)["lanista.second"])).not_contains("lint")
	assert_str((tab.get_node("%Status") as Label).text).contains("1 lint")
	errors.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	assert_str(tab.get("selected")).is_equal("lanista.first")
	assert_str((tab.get_node("%Facts") as Label).text).contains("lint: lanista.first: sets nodded")
	assert_bool(tab.call("has_unsaved")).is_false()
	# an edit that reads the flag: the lint runs again on the edited story
	tab.call("select_event", "veteran.later")
	assert_array(tab.call("set_field", "when", "met and nodded")).is_empty()
	assert_int(errors.item_count).is_equal(0)
	assert_str(_row_text(_nodes(tab)["lanista.first"])).not_contains("lint")


## The word list is the story directory's, read again at Reload.
func test_the_word_list_is_read_from_the_story_at_each_load() -> void:
	var tab := _editing_tab()
	var errors: ItemList = tab.get_node("%Errors")
	assert_int(errors.item_count).is_equal(0)
	_write(StoryLint.WORDS_FILE, "# the writer's list\nwelcome\n")
	tab.call("reload")
	assert_int(errors.item_count).is_equal(1)
	assert_str(errors.get_item_text(0)).is_equal("lint: lanista.txt:3: says 'Welcome', a word on the lint list")
	errors.item_clicked.emit(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)
	assert_str(tab.get("selected")).is_equal("lanista.first")
	assert_bool(tab.call("has_unsaved")).is_false()


## The Flags tab is the lint's flag map: each flag, its setters and readers; an event selects.
func test_the_flags_tab_is_the_flag_map() -> void:
	var tab := _editing_tab()
	var tree: Tree = tab.get("flags_tree")
	var flag := tree.get_root().get_first_child()
	assert_str(flag.get_text(0)).is_equal("met = false")
	var set_by := flag.get_first_child()
	assert_str(set_by.get_text(0)).is_equal("set by: 1")
	assert_str(set_by.get_first_child().get_text(0)).is_equal("veteran.hello")
	var read_by := set_by.get_next()
	assert_str(read_by.get_text(0)).is_equal("read by: 1")
	var reader := read_by.get_first_child()
	assert_str(reader.get_text(0)).is_equal("veteran.later")
	reader.select(0)
	assert_str(tab.get("selected")).is_equal("veteran.later")
