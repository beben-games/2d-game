extends GdUnitTestSuite
## The Story tab (addons/story_graph/story_tab.tscn) outside the editor, on the fixture story: a
## node per event in its character's lane, an edge per link on its kind's port, the filters and the
## search dimming what they leave out, the side panel's text, the error list selecting its event, and
## Reload reading a file edited on disk. The pure parts are StoryGraph's, StoryLayout's, and
## StoryLinks' suites; what needs eyes (the lanes' look, the colours) is the hand checklist.

const TAB := "res://addons/story_graph/story_tab.tscn"
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
	assert_bool((tab.get_node("%Text") as TextEdit).editable).is_false()
	var graph: GraphEdit = tab.get("graph")
	assert_bool((_nodes(tab)["veteran.hello"] as GraphNode).selected).is_true()
	graph.node_selected.emit(_nodes(tab)["lanista.bark"])
	assert_str(tab.get("selected")).is_equal("lanista.bark")


func test_the_errors_list_and_select_their_event() -> void:
	var tab := _tab()
	var errors: ItemList = tab.get_node("%Errors")
	assert_bool(errors.visible).is_false()
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
	for i in errors.item_count:
		errors.item_selected.emit(i)
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
		var tab := _tab(FIXTURE, node_floor)
		var nodes := _nodes(tab)
		var lanes: Dictionary = tab.get("lanes")
		var rects := {}
		for id: String in nodes:
			var node: GraphNode = nodes[id]
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
