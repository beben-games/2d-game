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


func _tab(story_dir := FIXTURE) -> Node:
	var tab: Node = (load(TAB) as PackedScene).instantiate()
	tab.set("dir", story_dir)
	add_child(auto_free(tab))
	return tab


func _nodes(tab: Node) -> Dictionary:
	return tab.get("nodes")


func _dimmed(tab: Node) -> Array[String]:
	var out: Array[String] = []
	var nodes := _nodes(tab)
	for id: String in nodes:
		if (nodes[id] as CanvasItem).modulate != Color.WHITE:
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
